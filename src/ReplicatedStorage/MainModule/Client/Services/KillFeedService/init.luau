--!strict

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local KillFeed = require(MainModule.Client.Components.KillFeed)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)
local Network = require(MainModule.Shared.Network)
local Core = require(MainModule.Shared.Network.Core)
local GunStats = require(MainModule.Shared.Config.GunStats)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local SettingsEnums = require(MainModule.Shared.Config.Settings.SettingsEnums)

type KillData = KillFeed.KillData
type EnvironmentalKillData = {
	killerName: string,
	killerUserId: number,
	killerTeam: string,
	message: string,
	victimName: string,
	victimUserId: number,
	victimTeam: string,
	killType: string?,
	killerColor: Color3?,
}

local KillFeedService = {}
KillFeedService.Name = "KillFeedService"

local KILL_DURATION = 3
local MAX_KILLS = 8
local GUN_INDEX_TO_NAME = GunStats.GUN_INDEX_TO_NAME

local REMOTE_NAMES = {
	ENVIRONMENTAL_KILL = "EnvironmentalKill",
}

local POSITION_MAP = {
	[SettingsEnums.KillFeedPosition.Left] = "Left",
	[SettingsEnums.KillFeedPosition.Middle] = "Middle",
	[SettingsEnums.KillFeedPosition.Right] = "Right",
}

local isInitialized = false
local hasDeployed = false
local hudScope: any = nil
local hudGui: ScreenGui? = nil
local hudVisible: any = nil
local killsState: any = nil
local textSizeState: any = nil
local positionState: any = nil
local connections: { RBXScriptConnection } = {}
local killRemovalThreads: { [number]: thread } = {}
local nextKillId = 1

local function getPlayerTeam(player: Player?): string
	if not player or not player.Team then
		return "Spectators"
	end
	return player.Team.Name
end

local function getGunName(gunIndex: number): string
	return GUN_INDEX_TO_NAME[gunIndex] or "Unknown"
end

local function executeKillRemoval(killId: number): ()
	killRemovalThreads[killId] = nil
	KillFeedService:RemoveKill(killId)
end

local function pushKill(kill: KillData): ()
	local currentKills = Fusion.peek(killsState)

	if #currentKills > 0 then
		local prevKill = currentKills[1]

		if prevKill.killerUserId == kill.victimUserId and prevKill.victimUserId == kill.killerUserId then
			kill.mutual = true

			local newKills = table.clone(currentKills)
			newKills[1] = kill
			killsState:set(newKills)
			if killRemovalThreads[prevKill.id] then
				task.cancel(killRemovalThreads[prevKill.id])
				killRemovalThreads[prevKill.id] = nil
			end
			killRemovalThreads[kill.id] = task.delay(KILL_DURATION, executeKillRemoval, kill.id)

			return
		end
	end

	local count = math.min(#currentKills, MAX_KILLS - 1)
	local newKills = table.create(count + 1)
	newKills[1] = kill
	if count > 0 then
		table.move(currentKills, 1, count, 2, newKills)
	end
	killsState:set(newKills)
	killRemovalThreads[kill.id] = task.delay(KILL_DURATION, executeKillRemoval, kill.id)
end

function KillFeedService:AddKill(
	killerName: string,
	killerUserId: number,
	killerTeam: string,
	killerHealth: number,
	weaponName: string,
	victimName: string,
	victimUserId: number,
	victimTeam: string,
	mutual: boolean?
): ()
	if not killsState or not hasDeployed then
		return
	end

	local killId = nextKillId
	nextKillId += 1

	local kill: KillData = {
		id = killId,
		killerName = killerName,
		killerUserId = killerUserId,
		killerTeam = killerTeam,
		killerHealth = killerHealth,
		weaponName = weaponName,
		victimName = victimName,
		victimUserId = victimUserId,
		victimTeam = victimTeam,
		mutual = mutual == true,
	}

	pushKill(kill)
end

local function getSettingValue(key: string, default: any): any
	local settings = ServiceLocator.Settings()
	if settings and settings.GetSetting then
		local value = settings:GetSetting(key)
		if value ~= nil then
			return value
		end
	end
	return default
end

function KillFeedService:AddEnvironmentalKill(
	killerName: string,
	killerUserId: number,
	killerTeam: string,
	message: string,
	victimName: string,
	victimUserId: number,
	victimTeam: string,
	killType: string?,
	killerColor: Color3?
): ()
	if not killsState or not hasDeployed then
		return
	end

	local killFeedEnabled = getSettingValue("KillFeed", true)
	if killFeedEnabled == false then
		return
	end

	local killId = nextKillId
	nextKillId += 1

	local kill: KillData = {
		id = killId,
		killerName = killerName,
		killerUserId = killerUserId,
		killerTeam = killerTeam,
		killerHealth = 0,
		weaponName = message,
		victimName = victimName,
		victimUserId = victimUserId,
		victimTeam = victimTeam,
		killType = killType,
		killerColor = killerColor,
	}

	pushKill(kill)
end

function KillFeedService:RemoveKill(killId: number): ()
	if not killsState then
		return
	end

	local currentKills = Fusion.peek(killsState)
	local newKills = {}

	for _, k in currentKills do
		if k.id ~= killId then
			newKills[#newKills + 1] = k
		end
	end

	killsState:set(newKills)
end

function KillFeedService:ClearAll(): ()
	if killsState then
		killsState:set({})
	end
end

local function updateFromSettings()
	if not hudScope then
		return
	end

	local enabled = getSettingValue("KillFeed", nil)
	if enabled == nil then
		return
	end
	local textSize = getSettingValue("KillFeedTextSize", 14)
	local positionEnum = getSettingValue("KillFeedPosition", SettingsEnums.KillFeedPosition.Middle)
	local positionStr = POSITION_MAP[positionEnum] or "Middle"

	if hudVisible then
		hudVisible:set(enabled == true and hasDeployed)
	end
	if not enabled then
		KillFeedService:ClearAll()
		for _, thread in killRemovalThreads do
			task.cancel(thread)
		end
		table.clear(killRemovalThreads)
	end
	if textSizeState then
		textSizeState:set(textSize)
	end
	if positionState then
		positionState:set(positionStr)
	end
end

local function onKillReceived(data: { killer: number, victim: number, headshot: boolean, weapon: number, killerHealth: number, mutual: boolean? })
	local killFeedEnabled = getSettingValue("KillFeed", true)
	if killFeedEnabled == false then
		return
	end

	local killerPlayer = Players:GetPlayerByUserId(data.killer)
	local victimPlayer = Players:GetPlayerByUserId(data.victim)
	local isZombie = (data.victim == -1) and (victimPlayer == nil)

	if not killerPlayer then
		return
	end
	if not victimPlayer and not isZombie then
		return
	end

	local killerName = killerPlayer.Name
	local victimName = if isZombie then "ZOMBIE" else victimPlayer.Name
	local killerTeam = getPlayerTeam(killerPlayer)
	local victimTeam = if isZombie then "Neutral" else getPlayerTeam(victimPlayer)
	local weaponName = getGunName(data.weapon)
	local killerHealth = data.killerHealth or 100

	KillFeedService:AddKill(killerName, data.killer, killerTeam, killerHealth, weaponName, victimName, data.victim, victimTeam, data.mutual)
end

local function onEnvironmentalKillReceived(data: EnvironmentalKillData): ()
	KillFeedService:AddEnvironmentalKill(
		data.killerName,
		data.killerUserId,
		data.killerTeam,
		data.message,
		data.victimName,
		data.victimUserId,
		data.victimTeam,
		data.killType,
		data.killerColor
	)
end

local function onAcakReceived()
	local killFeedEnabled = getSettingValue("KillFeed", true)
	if killFeedEnabled == false then
		return
	end

	local killId = nextKillId
	nextKillId += 1

	local kill: any = {
		id = killId,
		killerName = "[+1 KILL] ASSIST COUNTS AS KILL",
		killerUserId = Players.LocalPlayer and Players.LocalPlayer.UserId or 0,
		killerTeam = "",
		killerHealth = 0,
		weaponName = "",
		victimName = "",
		victimUserId = 0,
		victimTeam = "",
		isAcak = true,
	}

	pushKill(kill)
end

function KillFeedService:init(): ()
	hudScope = Fusion.scoped(Fusion)
	hudVisible = hudScope:Value(false)
	killsState = hudScope:Value({} :: { KillData })
	textSizeState = hudScope:Value(14)
	positionState = hudScope:Value("Middle")

	updateFromSettings()

	hudGui = KillFeed(hudScope, {
		Kills = killsState,
		Visible = hudVisible,
		TextSize = textSizeState,
		Position = positionState,
	})

	local playerGui = PlayerGuiHelper.waitForPlayerGui()
	if playerGui and hudGui then
		hudGui.Parent = playerGui
	end

	isInitialized = true
end

function KillFeedService:start(): ()
	if not isInitialized then
		self:init()
	end

	table.insert(
		connections,
		Network.Deploy.onDeployComplete(function()
			hasDeployed = true
			updateFromSettings()
		end)
	)

	table.insert(connections, Network.Gun.onKill(onKillReceived))

	local envEvent = Core.getOrCreateRemoteEvent(REMOTE_NAMES.ENVIRONMENTAL_KILL)
	table.insert(connections, envEvent.OnClientEvent:Connect(onEnvironmentalKillReceived))

	local acakEvent = Core.getOrCreateRemoteEvent("ACAK")
	table.insert(connections, acakEvent.OnClientEvent:Connect(onAcakReceived))

	local settings = ServiceLocator.Settings()
	if settings and settings.SettingChanged then
		table.insert(
			connections,
			settings.SettingChanged:Connect(function(key: string, _value: any)
				if key == "KillFeed" or key == "KillFeedTextSize" or key == "KillFeedPosition" then
					updateFromSettings()
				end
			end)
		)
	end
end

function KillFeedService:Cleanup(): ()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)

	for killId, thread in killRemovalThreads do
		task.cancel(thread)
		killRemovalThreads[killId] = nil
	end

	if hudScope then
		hudScope:doCleanup()
		hudScope = nil
		hudGui = nil
		hudVisible = nil
		killsState = nil
		textSizeState = nil
		positionState = nil
	end

	isInitialized = false
	hasDeployed = false
	nextKillId = 1
end

return KillFeedService
