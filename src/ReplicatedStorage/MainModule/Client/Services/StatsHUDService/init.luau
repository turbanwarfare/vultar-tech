--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local StatsHUD = require(MainModule.Client.Components.StatsHUD)
local Network = require(MainModule.Shared.Network)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)

local StatsHUDService = {}
StatsHUDService.Name = "StatsHUDService"

local isInitialized = false
local settingEnabled = true
local hasDeployed = false

local hudScope: any = nil
local hudGui: ScreenGui? = nil
local hudVisible: any = nil
local hudKills: any = nil
local hudDamage: any = nil
local hudHeals: any = nil
local hudCaptures: any = nil

local statsUnsubscribe: (() -> ())? = nil
local settingsConnection: any = nil
local deployConnection: RBXScriptConnection? = nil

local function applyStats(stats: any): ()
	if hudKills then
		hudKills:set(math.floor(stats.Kills or 0))
	end
	if hudDamage then
		hudDamage:set(math.floor(stats.Damage or 0))
	end
	if hudHeals then
		hudHeals:set(math.floor(stats.Heals or 0))
	end
	if hudCaptures then
		hudCaptures:set(math.floor(stats.Captures or 0))
	end
end

local function updateStatsFromService(): ()
	local statsService = ServiceLocator.Stats()
	if not statsService then
		return
	end

	local stats = statsService:GetStats()
	if stats then
		applyStats(stats)
	end
end

local function updateVisibility(): ()
	if not hudVisible then
		return
	end
	hudVisible:set(settingEnabled and hasDeployed)
end

local function onDeployComplete(): ()
	hasDeployed = true
	updateVisibility()
end

function StatsHUDService:init(): ()
	hudScope = Fusion.scoped(Fusion)
	hudVisible = hudScope:Value(true)
	hudKills = hudScope:Value(0)
	hudDamage = hudScope:Value(0)
	hudHeals = hudScope:Value(0)
	hudCaptures = hudScope:Value(0)

	hudGui = StatsHUD(hudScope, {
		Visible = hudVisible,
		Kills = hudKills,
		Damage = hudDamage,
		Heals = hudHeals,
		Captures = hudCaptures,
	})

	local playerGui = PlayerGuiHelper.waitForPlayerGui()
	if playerGui then
		hudGui.Parent = playerGui
	end

	updateVisibility()

	isInitialized = true
end

function StatsHUDService:start(): ()
	local settingsService = ServiceLocator.Settings()
	if settingsService then
		local initialSetting = settingsService:GetSetting("StatsHUD")
		settingEnabled = initialSetting ~= false
	end

	if not isInitialized then
		self:init()
	end

	if settingsService and settingsService.SettingChanged then
		settingsConnection = settingsService.SettingChanged:Connect(function(key: string, value: any)
			if key == "StatsHUD" then
				settingEnabled = value ~= false
				updateVisibility()
			end
		end)
	end

	deployConnection = Network.Deploy.onDeployComplete(onDeployComplete)

	local statsService = ServiceLocator.Stats()
	if statsService then
		statsUnsubscribe = statsService:OnStatsChanged(applyStats)
		updateStatsFromService()
	else
		task.spawn(function()
			task.wait(1)
			local svc = ServiceLocator.Stats()
			if svc then
				statsUnsubscribe = svc:OnStatsChanged(applyStats)
				updateStatsFromService()
			end
		end)
	end
end

function StatsHUDService:Show(): ()
	if hudVisible then
		hudVisible:set(true)
	end
end

function StatsHUDService:Hide(): ()
	if hudVisible then
		hudVisible:set(false)
	end
end

function StatsHUDService:IsVisible(): boolean
	if hudVisible then
		return Fusion.peek(hudVisible)
	end
	return false
end

function StatsHUDService:Cleanup(): ()
	if statsUnsubscribe then
		statsUnsubscribe()
		statsUnsubscribe = nil
	end

	if settingsConnection then
		settingsConnection:Disconnect()
		settingsConnection = nil
	end

	if deployConnection then
		deployConnection:Disconnect()
		deployConnection = nil
	end

	hasDeployed = false

	if hudScope then
		hudScope:doCleanup()
		hudScope = nil
		hudGui = nil
		hudVisible = nil
		hudKills = nil
		hudDamage = nil
		hudHeals = nil
		hudCaptures = nil
	end

	isInitialized = false
	settingEnabled = true
end

return StatsHUDService
