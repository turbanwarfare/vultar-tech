--!strict
--!native
--!optimize 2

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

type DiagnosticDump = Network.DiagnosticDump

local DiagnosticsService = {}
DiagnosticsService.Name = "DiagnosticsService"

local API_KEY = "REPLACE_WITH_YOUR_API_KEY"
local BASE_URL = "REPLACE_WITH_YOUR_API_URL"

local pendingDumps: { [number]: { requesterId: number, requesterName: string, timestamp: number } } = {}
local isInitialized = false
local serviceConnections: { RBXScriptConnection } = {}

local chatService: any = nil

local function httpRequest(options: {
	Url: string,
	Method: string,
	Body: string?,
	Headers: { [string]: string }?,
}): { Success: boolean, Body: string?, StatusCode: number?, Error: string? }
	local success, response = pcall(function()
		return HttpService:RequestAsync(options)
	end)

	if success and response then
		return {
			Success = response.Success,
			Body = response.Body,
			StatusCode = response.StatusCode,
		}
	end

	return { Success = false, Error = tostring(response) }
end

local function postDump(dump: DiagnosticDump): boolean
	local encodeSuccess, body = pcall(function()
		return HttpService:JSONEncode(dump)
	end)

	if not encodeSuccess then
		warn("[DiagnosticsService] Failed to encode dump JSON")
		return false
	end

	local response = httpRequest({
		Url = `{BASE_URL}/api/roblox/diagnostics/dump`,
		Method = "POST",
		Body = body,
		Headers = {
			["Content-Type"] = "application/json",
			["Accept"] = "application/json",
			["x-api-key"] = API_KEY,
		},
	})

	if not response.Success then
		warn(`[DiagnosticsService] Failed to POST dump: {response.Error or "Unknown error"}`)
		return false
	end

	if response.StatusCode and response.StatusCode >= 400 then
		warn(`[DiagnosticsService] POST returned error status {response.StatusCode}`)
		return false
	end

	return true
end

local function onDumpSubmitted(player: Player, dump: any): ()
	local pending = pendingDumps[player.UserId]
	if not pending then
		return
	end

	pendingDumps[player.UserId] = nil

	if dump.meta then
		dump.meta.requesterId = pending.requesterId
		dump.meta.requesterName = pending.requesterName
		dump.meta.serverId = tostring(game.JobId)
		dump.meta.placeId = game.PlaceId
		dump.meta.placeVersion = game.PlaceVersion
		dump.meta.serverUptime = math.floor(workspace.DistributedGameTime)
	end

	local requester = Players:GetPlayerByUserId(pending.requesterId)

	task.spawn(function()
		local success = postDump(dump)
		if success and requester and chatService then
			chatService:SendSystemMessage(nil, `[SYSTEM] Diagnostics dump for {player.DisplayName} uploaded successfully.`, Color3.fromRGB(100, 255, 150), requester)
		elseif requester and chatService then
			chatService:SendSystemMessage(nil, `[SYSTEM] Failed to upload diagnostics dump for {player.DisplayName}.`, Color3.fromRGB(255, 100, 100), requester)
		end
	end)
end

function DiagnosticsService:RequestDump(requester: Player, target: Player): boolean
	if pendingDumps[target.UserId] then
		if chatService then
			chatService:SendSystemMessage(nil, `[SYSTEM] A dump is already in progress for {target.DisplayName}.`, Color3.fromRGB(255, 200, 100), requester)
		end
		return false
	end

	pendingDumps[target.UserId] = {
		requesterId = requester.UserId,
		requesterName = requester.Name,
		timestamp = os.time(),
	}

	Network.Diagnostics.requestDump(target)

	if chatService then
		chatService:SendSystemMessage(nil, `[SYSTEM] Requesting diagnostics from {target.DisplayName}...`, Color3.fromRGB(100, 200, 255), requester)
	end

	task.delay(30, function()
		if pendingDumps[target.UserId] then
			pendingDumps[target.UserId] = nil
			local stillOnline = Players:GetPlayerByUserId(requester.UserId)
			if stillOnline and chatService then
				chatService:SendSystemMessage(nil, `[SYSTEM] Diagnostics request for {target.DisplayName} timed out.`, Color3.fromRGB(255, 100, 100), stillOnline)
			end
		end
	end)

	return true
end

function DiagnosticsService:init(): ()
	isInitialized = true
end

function DiagnosticsService:start(): ()
	if not isInitialized then
		self:init()
	end

	chatService = LazyService.create(MainModule, "ChatService")()

	Network.Diagnostics.onDumpSubmitted(onDumpSubmitted)

	table.insert(serviceConnections, Players.PlayerRemoving:Connect(function(player: Player)
		pendingDumps[player.UserId] = nil
	end))
end

function DiagnosticsService:Cleanup(): ()
	for _, conn in serviceConnections do
		conn:Disconnect()
	end
	table.clear(serviceConnections)
	table.clear(pendingDumps)
end

return DiagnosticsService
