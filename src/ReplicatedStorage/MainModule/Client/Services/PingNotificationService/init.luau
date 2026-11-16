--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local PingNotification = require(MainModule.Client.Components.PingNotification)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)
local Network = require(MainModule.Shared.Network)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

local PingNotificationService = {}
PingNotificationService.Name = "PingNotificationService"

local isInitialized = false

local hudScope: any = nil
local hudGui: ScreenGui? = nil
local hudVisible: any = nil
local hudPosition: any = nil
local connections: { RBXScriptConnection } = {}

local hideThread: thread? = nil
local SettingsService: any = nil

local function getPositionSetting(): number
	if SettingsService and SettingsService.GetSettings then
		local settings = SettingsService:GetSettings()
		if settings and settings.Settings and settings.Settings.PingNotificationPosition then
			return settings.Settings.PingNotificationPosition
		end
	end
	return 2
end

local function cancelHideThread(): ()
	if hideThread then
		task.cancel(hideThread)
		hideThread = nil
	end
end

local function scheduleHide(duration: number): ()
	cancelHideThread()

	hideThread = task.delay(duration, function()
		hideThread = nil
		if hudVisible then
			hudVisible:set(false)
		end
	end)
end

local function isNotificationEnabled(): boolean
	if SettingsService and SettingsService.GetSettings then
		local settings = SettingsService:GetSettings()
		if settings and settings.Settings then
			local enabled = settings.Settings.PingNotification
			if enabled == false then
				return false
			end
		end
	end
	return true
end

local function onPinged(_senderName: string, duration: number): ()
	if not hudVisible or not hudPosition then
		return
	end

	if not isNotificationEnabled() then
		return
	end

	hudPosition:set(getPositionSetting())
	hudVisible:set(true)
	scheduleHide(duration)
end

local function onSettingsChanged(): ()
	if hudPosition then
		hudPosition:set(getPositionSetting())
	end
end

function PingNotificationService:init(): ()
	hudScope = Fusion.scoped(Fusion)
	hudVisible = hudScope:Value(false)
	hudPosition = hudScope:Value(getPositionSetting())

	hudGui = PingNotification(hudScope, {
		Visible = hudVisible,
		Position = hudPosition,
	})

	local playerGui = PlayerGuiHelper.waitForPlayerGui()
	if playerGui then
		hudGui.Parent = playerGui
	end

	isInitialized = true
end

function PingNotificationService:start(): ()
	if not isInitialized then
		self:init()
	end

	SettingsService = LazyService.create(MainModule, "SettingsService")()

	table.insert(connections, Network.Ping.onPinged(onPinged))

	if SettingsService and SettingsService.OnSettingsChanged then
		table.insert(connections, SettingsService:OnSettingsChanged(onSettingsChanged))
	end
end

function PingNotificationService:Show(): ()
	if hudVisible then
		hudVisible:set(true)
	end
end

function PingNotificationService:Hide(): ()
	cancelHideThread()
	if hudVisible then
		hudVisible:set(false)
	end
end

function PingNotificationService:IsVisible(): boolean
	if hudVisible then
		return Fusion.peek(hudVisible)
	end
	return false
end

function PingNotificationService:Cleanup(): ()
	cancelHideThread()

	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)

	if hudScope then
		hudScope:doCleanup()
		hudScope = nil
		hudGui = nil
		hudVisible = nil
		hudPosition = nil
	end

	isInitialized = false
end

return PingNotificationService
