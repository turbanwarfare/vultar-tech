--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local Theme = require(MainModule.Shared.UI.Theme)
local Constants = require(MainModule.Shared.Config.Constants)
local Maps = require(MainModule.Shared.Config.Maps)
local SparConfig = require(MainModule.Shared.Config.SparConfig)
local RankCache = require(MainModule.Server.Cache.RankCache)
local ChatService = require(script.Parent.ChatService)
local TeamService = require(script.Parent.TeamService)
local ServerUtils = require(MainModule.Shared.Utils.Game.ServerUtils)
local EventCosmeticsAPI = require(script.Parent.CosmeticService.EventCosmeticsAPI)
local ChatTypes = require(MainModule.Shared.Network.Chat.Types)

type FacilityBanData = Network.FacilityBanData
type ChannelId = ChatTypes.ChannelId

local FacilityBanService = {}
FacilityBanService.Name = "FacilityBanService"

local connections: { RBXScriptConnection } = {}
local recordingPolicyPlayers: { [number]: boolean } = {}

local BAN_ALERT_CHANNEL: ChannelId = "RAID"
local BAN_ALERT_TAG = "BAN_ALERT"
local BAN_ALERT_MESSAGE_FORMAT = "[ALERT] Facility banned player %s (%d) is in the server."
local RECORDING_POLICY_DELAY = 2

local isDTMode = false
local isSparMode = false
local isAimMode = false
local DT_REQUIRED_GROUPS = { Constants.GROUPS.VIA, Constants.GROUPS.VULTAR, Constants.GROUPS.SNOW_CORE }

local DT_KICK_MESSAGE = table.concat({
	"Public DT servers are for Vultarians only.",
	"Create a free private server to join the game.",
}, "\n")

local function isNCOPlus(player: Player): boolean
	local mainRank = RankCache.getPlayerRank(player, Constants.GROUPS.VULTAR)
	local vwcRank = RankCache.getPlayerRank(player, Constants.GROUPS.VWC)
	return mainRank >= Constants.MIN_RANK.NCO or vwcRank >= 1
end

local function formatWarningMessage(text: string): string
	local r = math.floor(Theme.Colors.Warning.R * 255)
	local g = math.floor(Theme.Colors.Warning.G * 255)
	local b = math.floor(Theme.Colors.Warning.B * 255)
	return string.format("<font color='rgb(%d, %d, %d)'><b>%s</b></font>", r, g, b, text)
end

local function sendRecordingReminder(player: Player): ()
	ChatService:SendSystemMessage(nil, formatWarningMessage("REMINDER: You are required to record this session"), Theme.Colors.Warning, player)

	local policyMessage = formatWarningMessage(player.Name .. " is on recording policy for this session")
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player and isNCOPlus(otherPlayer) then
			ChatService:SendSystemMessage(nil, policyMessage, Theme.Colors.Warning, otherPlayer)
		end
	end
end

local function isVultarianOrInitiate(player: Player): boolean
	for _, groupId in DT_REQUIRED_GROUPS do
		local ok, inGroup = pcall(player.IsInGroup, player, groupId)
		if ok and inGroup then
			return true
		end
	end
	return false
end

local function checkPlayer(player: Player): ()
	if isDTMode and not isVultarianOrInitiate(player) and not RunService:IsStudio() then
		player:Kick(DT_KICK_MESSAGE)
		return
	end

	if (isSparMode or isAimMode) and not RunService:IsStudio() then
		local isExempt = false
		local bypassList = SparConfig.BYPASS_USER_IDS
		if bypassList then
			for _, id in bypassList do
				if player.UserId == id then
					isExempt = true
					break
				end
			end
		end

		if not isExempt and not isVultarianOrInitiate(player) then
			local serverType = "sparring"
			player:Kick("Public " .. serverType .. " servers are restricted to Vultarians and Initiates.")
			return
		end
	end

	local gameState = EventCosmeticsAPI.getUserGameState(player.UserId)
	if not gameState then
		return
	end

	if gameState.facilityBan and gameState.facilityBan.isBanned then
		local alertMessage = string.format(BAN_ALERT_MESSAGE_FORMAT, player.Name, player.UserId)
		ChatService:SendSystemMessage(BAN_ALERT_CHANNEL, alertMessage, Theme.Colors.Destructive, nil, { BAN_ALERT_TAG })
	end

	if gameState.recordingPolicy and gameState.recordingPolicy.onRecordingPolicy then
		recordingPolicyPlayers[player.UserId] = true
		task.wait(RECORDING_POLICY_DELAY)

		if player.Parent then
			sendRecordingReminder(player)
		end
	end
end

local function onPlayerAdded(player: Player): ()
	task.spawn(checkPlayer, player)
end

local function onPlayerRemoving(player: Player): ()
	recordingPolicyPlayers[player.UserId] = nil
end

function FacilityBanService:init(): () end

function FacilityBanService:start(): ()
	if ServerUtils.isPrivateServer() then
		return
	end

	local mapConfig = Maps.getConfig()
	local gameMode = TeamService:GetGameMode()
	local isRaid = gameMode == "RAID"
	isDTMode = mapConfig.GameType == "DT"
	isSparMode = mapConfig.GameType == "Spar"
	isAimMode = mapConfig.GameType == "Aim"

	if not isRaid and not isDTMode and not isSparMode and not isAimMode then
		return
	end

	table.insert(connections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(connections, Players.PlayerRemoving:Connect(onPlayerRemoving))

	for _, player in Players:GetPlayers() do
		task.spawn(checkPlayer, player)
	end
end

function FacilityBanService:Cleanup(): ()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	table.clear(recordingPolicyPlayers)
end

return FacilityBanService
