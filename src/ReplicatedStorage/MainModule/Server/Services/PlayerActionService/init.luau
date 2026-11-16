--!strict
--!native
--!optimize 2

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local LogBlacklist = require(MainModule.Shared.Config.LogBlacklist)

local PlayerActionService = {}
PlayerActionService.Name = "PlayerActionService"

local WEBHOOK_URL =
	"REPLACE_WITH_YOUR_WEBHOOK_URL"

local flaggedPlayers: { [number]: boolean } = {}
local serviceConnections: { RBXScriptConnection } = {}

local function sendWebhook(player: Player, actionName: string): ()
	if LogBlacklist.isBlocked() then
		return
	end

	local body = HttpService:JSONEncode({
		embeds = {
			{
				title = "Honeypot Triggered",
				color = 15158332,
				fields = {
					{
						name = "Player",
						value = player.Name,
						inline = true,
					},
					{
						name = "UserId",
						value = tostring(player.UserId),
						inline = true,
					},
					{
						name = "Action",
						value = actionName,
						inline = true,
					},
					{
						name = "Account Age",
						value = tostring(player.AccountAge) .. " days",
						inline = true,
					},
					{
						name = "PlaceId",
						value = tostring(game.PlaceId),
						inline = true,
					},
					{
						name = "JobId",
						value = game.JobId,
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
			Url = WEBHOOK_URL,
			Body = body,
			Headers = {
				["Content-Type"] = "application/json",
			},
		})
	end)
	if not ok then
		warn("[PlayerActionService] Webhook failed -", err)
	end
end

local function handleTrigger(player: Player, actionName: string): ()
	if typeof(actionName) ~= "string" then
		return
	end

	if flaggedPlayers[player.UserId] then
		return
	end

	flaggedPlayers[player.UserId] = true

	warn("[PlayerActionService]", player.Name, "(" .. tostring(player.UserId) .. ") triggered:", actionName)

	task.spawn(sendWebhook, player, actionName)
end

function PlayerActionService:init(): () end

function PlayerActionService:start(): ()
	Network.PlayerAction.onTrigger(handleTrigger)

	table.insert(
		serviceConnections,
		Players.PlayerRemoving:Connect(function(player: Player)
			flaggedPlayers[player.UserId] = nil
		end)
	)
end

function PlayerActionService:Cleanup(): ()
	for _, conn in serviceConnections do
		conn:Disconnect()
	end
	table.clear(serviceConnections)
	table.clear(flaggedPlayers)
end

return PlayerActionService
