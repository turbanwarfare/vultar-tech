--!strict
--!native
--!optimize 2

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local Constants = require(MainModule.Shared.Config.Constants)
local RankCache = require(MainModule.Server.Cache.RankCache)
local LogBlacklist = require(MainModule.Shared.Config.LogBlacklist)

local LoggingService = {}
LoggingService.Name = "LoggingService"

local API_URL = "REPLACE_WITH_YOUR_API_URL"
local API_KEY = "REPLACE_WITH_YOUR_API_KEY"
local DISCORD_WEBHOOK = "REPLACE_WITH_YOUR_WEBHOOK_URL"

local MAX_LOG_PLAYERS = 50

local gameName: string = ""
local playerJoinTimes: { [number]: number } = {}
local serviceConnections: { RBXScriptConnection } = {}

local function getGameName(): string
	if gameName ~= "" then
		return gameName
	end

	local success, info = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)

	if success and info then
		gameName = info.Name or "Unknown"
	else
		gameName = "Unknown"
	end

	return gameName
end

local function sendFailureWebhook(host: Player, playerUsernames: { string }): ()
	local attendeesList = {}
	for _, username in playerUsernames do
		local player = Players:FindFirstChild(username)
		local odId = if player then tostring(player.UserId) else "Unknown"
		table.insert(attendeesList, username .. " | " .. odId)
	end

	local attendeesText = table.concat(attendeesList, "\n")
	if #attendeesText > 1024 then
		attendeesText = string.sub(attendeesText, 1, 1020) .. "..."
	end

	local webhookBody = HttpService:JSONEncode({
		embeds = {
			{
				title = "Session Log Failed",
				color = 15158332,
				fields = {
					{
						name = "Game",
						value = getGameName(),
						inline = true,
					},
					{
						name = "Host",
						value = host.Name .. " (" .. tostring(host.UserId) .. ")",
						inline = true,
					},
					{
						name = "Attendees (" .. tostring(#playerUsernames) .. ")",
						value = attendeesText,
						inline = false,
					},
				},
				timestamp = DateTime.now():ToIsoDate(),
			},
		},
	})

	local ok, err = pcall(function()
		HttpService:RequestAsync({
			Method = "POST",
			Url = DISCORD_WEBHOOK,
			Body = webhookBody,
			Headers = {
				["Content-Type"] = "application/json",
			},
		})
	end)
	if not ok then
		warn("[LoggingService] Discord webhook failed -", err)
	end
end

local function isPlayerAuthorized(player: Player): boolean
	local vultarRank = RankCache.getPlayerRank(player, Constants.GROUPS.VULTAR)
	if vultarRank >= Constants.MIN_RANK.NCO then
		return true
	end

	local viacomRank = RankCache.getPlayerRank(player, Constants.GROUPS.VIACOM)
	if viacomRank >= Constants.MIN_RANK.VIACOM_INSTRUCTOR then
		return true
	end

	return false
end

local function getLogPlayers(): { Network.LogPlayer }
	local logPlayers: { Network.LogPlayer } = {}
	local now = os.clock()

	for _, player in Players:GetPlayers() do
		local inVultar = RankCache.isInGroup(player, Constants.GROUPS.VULTAR)
		local inVia = RankCache.isInGroup(player, Constants.GROUPS.VIA)

		if inVultar or inVia then
			local joinTime = playerJoinTimes[player.UserId] or now
			local timeInServer = math.floor(now - joinTime)

			table.insert(logPlayers, {
				name = player.Name,
				userId = player.UserId,
				timeInServer = timeInServer,
			})
		end
	end

	return logPlayers
end

local function resolveLoggedUsernames(playerUsernames: { string }): { string }
	local resolved: { string } = {}
	local seen: { [string]: boolean } = {}

	for _, username in playerUsernames do
		if type(username) ~= "string" or seen[username] then
			continue
		end

		local candidate = Players:FindFirstChild(username)
		if not candidate or not candidate:IsA("Player") then
			continue
		end

		seen[username] = true
		table.insert(resolved, username)

		if #resolved >= MAX_LOG_PLAYERS then
			break
		end
	end

	return resolved
end

local function submitLog(host: Player, rawUsernames: { string }): Network.LogSubmitResult
	if LogBlacklist.isBlocked() then
		return { success = false, error = "Logging is disabled on this place" }
	end

	if not isPlayerAuthorized(host) then
		return { success = false, error = "Unauthorized" }
	end

	if type(rawUsernames) ~= "table" then
		return { success = false, error = "Invalid payload" }
	end

	local playerUsernames = resolveLoggedUsernames(rawUsernames)
	if #playerUsernames == 0 then
		return { success = false, error = "No players to log" }
	end

	local body = HttpService:JSONEncode({
		["playerUsernames"] = HttpService:JSONEncode(playerUsernames),
		["hostUsername"] = host.Name,
		["hostUserId"] = tostring(host.UserId),
		["gameName"] = getGameName(),
	})

	local success, response = pcall(function()
		return HttpService:RequestAsync({
			Method = "POST",
			Url = API_URL,
			Body = body,
			Headers = {
				["Content-Type"] = "application/json",
				["x-api-key"] = API_KEY,
			},
		})
	end)

	if not success then
		warn("[LoggingService] HTTP request failed:", response)
		sendFailureWebhook(host, playerUsernames)
		return { success = false, error = "Request failed" }
	end

	if response.Success then
		print("[LoggingService] Session log by", host.Name, "- SUCCESS")
		return { success = true }
	else
		warn("[LoggingService] Session log by", host.Name, "- FAILED (HTTP", response.StatusCode, ")")
		sendFailureWebhook(host, playerUsernames)
		return { success = false, error = "HTTP " .. tostring(response.StatusCode) }
	end
end

function LoggingService:init(): ()
	task.spawn(getGameName)

	local now = os.clock()
	for _, player in Players:GetPlayers() do
		playerJoinTimes[player.UserId] = now
	end
end

function LoggingService:start(): ()
	table.insert(
		serviceConnections,
		Players.PlayerAdded:Connect(function(player: Player)
			playerJoinTimes[player.UserId] = os.clock()
		end)
	)

	table.insert(
		serviceConnections,
		Players.PlayerRemoving:Connect(function(player: Player)
			playerJoinTimes[player.UserId] = nil
		end)
	)

	Network.Logging.onSubmitLog(function(player: Player, playerUsernames: { string })
		return submitLog(player, playerUsernames)
	end)

	Network.Logging.onGetLogPlayers(function(player: Player)
		if not isPlayerAuthorized(player) then
			return {}
		end
		return getLogPlayers()
	end)
end

function LoggingService:Cleanup(): ()
	for _, conn in serviceConnections do
		conn:Disconnect()
	end
	table.clear(serviceConnections)
	table.clear(playerJoinTimes)
	gameName = ""
end

return LoggingService
