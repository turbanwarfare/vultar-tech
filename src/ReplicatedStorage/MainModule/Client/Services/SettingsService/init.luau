--!strict
--!native
--!optimize 2

local StarterGui = game:GetService("StarterGui")

local MainModule = script.Parent.Parent.Parent

local Network = require(MainModule.Shared.Network)
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
local DeepCopy = require(MainModule.Shared.Utils.Table.DeepCopy)
local TableMerge = require(MainModule.Shared.Utils.Table.TableMerge)
local Signal = require(MainModule.Shared.Utils.State.Signal)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)
local BlurEffectUtil = require(MainModule.Client.Utils.UI.BlurEffect)
local AvatarViewportLoader = require(MainModule.Client.Utils.AvatarViewportLoader)
local LoadingState = require(MainModule.Client.Utils.UI.LoadingState)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local MenuManager = require(script.MenuManager)
local InputHandler = require(script.InputHandler)
local WorldEffects = require(script.WorldEffects)

local LoadBenchmark: any = nil
pcall(function()
	LoadBenchmark = require(MainModule.Shared.Utils.Debug.LoadBenchmark)
end)

local function bench(name: string, fn: () -> ())
	if LoadBenchmark and LoadBenchmark.isEnabled() then
		LoadBenchmark.start("SettingsSvc:" .. name)
		fn()
		LoadBenchmark.stop()
	else
		fn()
	end
end

local function benchDetail(msg: string)
	if LoadBenchmark and LoadBenchmark.isEnabled() then
		LoadBenchmark.detail("[SettingsSvc] " .. msg)
	end
end

local CORE_GUI_TYPES = {
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.Chat,
	Enum.CoreGuiType.EmotesMenu,
}

local previousCoreGuiStates: { [Enum.CoreGuiType]: boolean } = {}
local previousScreenGuiStates: { [ScreenGui]: boolean } = {}

local function hideAllUI()
	local pg = PlayerGuiHelper.getPlayerGui()

	for _, coreGuiType in CORE_GUI_TYPES do
		previousCoreGuiStates[coreGuiType] = StarterGui:GetCoreGuiEnabled(coreGuiType)
		StarterGui:SetCoreGuiEnabled(coreGuiType, false)
	end

	pcall(function()
		StarterGui:SetCore("TopbarEnabled", false)
	end)

	if pg then
		for _, gui in pg:GetChildren() do
			if gui:IsA("ScreenGui") and gui.Name ~= "VultarSettingsMenu" then
				previousScreenGuiStates[gui] = gui.Enabled
				gui.Enabled = false
			end
		end
	end
end

local function restoreAllUI()
	local pg = PlayerGuiHelper.getPlayerGui()

	for coreGuiType, wasEnabled in previousCoreGuiStates do
		StarterGui:SetCoreGuiEnabled(coreGuiType, wasEnabled)
	end
	table.clear(previousCoreGuiStates)

	pcall(function()
		StarterGui:SetCore("TopbarEnabled", true)
	end)

	if pg then
		for gui, wasEnabled in previousScreenGuiStates do
			if gui and gui.Parent then
				gui.Enabled = wasEnabled
			end
		end
	end
	table.clear(previousScreenGuiStates)
end

local function keyNameToKeyCode(keyName: string): Enum.KeyCode?
	local success, keyCode = pcall(function()
		return Enum.KeyCode[keyName]
	end)
	if success and keyCode then
		return keyCode
	end
	return nil
end

local SettingsService = {}
SettingsService.Name = "SettingsService"

local playerGui: PlayerGui? = nil
local blurEffect: BlurEffect? = nil

local isVisible = false
local isInitialized = false
local menuCallbacks: MenuManager.MenuCallbacks? = nil
local menuStale = false

local settings: SettingsConfig.SettingsTemplate? = nil
local settingChangedSignal = Signal.new()

SettingsService.SettingChanged = settingChangedSignal

local keybindChangedSignal = Signal.new()
SettingsService.KeybindChanged = keybindChangedSignal

local menuVisibilityChangedSignal = Signal.new()
SettingsService.MenuVisibilityChanged = menuVisibilityChangedSignal

local function createMenuCallbacks(): MenuManager.MenuCallbacks
	return {
		OnSettingChange = function(key: string, value: any)
			SettingsService:UpdateSetting(key, value)
		end,
		OnKeybindChange = function(key: string, value: string)
			local result = Network.Settings.changeKeybind(key, value)
			if result and settings then
				settings.Keybinds[key] = result
				keybindChangedSignal:Fire(key, result)
				if key == "Menu" then
					local menuKeyCode = keyNameToKeyCode(result)
					if menuKeyCode then
						InputHandler.setMenuKey(menuKeyCode)
					end
				end
			end
		end,
		OnKeybindEditStart = function()
			InputHandler.setEnabled(false)
		end,
		OnKeybindEditEnd = function()
			InputHandler.setEnabled(true)
		end,
		OnResetSettings = function()
			SettingsService:ResetSettings()
		end,
		OnImportSettings = function(newSettings: any)
			if newSettings then
				settings = newSettings
				if settings.Settings then
					for settingKey, settingValue in settings.Settings do
						settingChangedSignal:Fire(settingKey, settingValue)
					end
				end
				SettingsService:RefreshMenu()
			end
		end,
		OnClose = function()
			SettingsService:Hide()
		end,
		OnCursorEquip = function(cursorId: number)
			local cursor = ServiceLocator.Cursor()
			if cursor then
				cursor:EquipCursor(cursorId)
			end
		end,
		OnCursorToggleRadial = function(cursorId: number)
			local cursor = ServiceLocator.Cursor()
			if cursor then
				cursor:ToggleRadial(cursorId)
			end
		end,
		SettingChanged = settingChangedSignal,
	}
end

local function ensureMenuCreated(): boolean
	if MenuManager.isCreated() then
		return true
	end

	if not playerGui then
		return false
	end

	if not menuCallbacks then
		menuCallbacks = createMenuCallbacks()
	end

	local menu = MenuManager.create(settings, menuCallbacks)
	if menu then
		menu.Parent = playerGui
		return true
	end

	return false
end

function SettingsService:init(): ()
	playerGui = PlayerGuiHelper.waitForPlayerGui()
	if not playerGui then
		return
	end

	blurEffect = BlurEffectUtil.create("SettingsBlur", 0)
	isInitialized = true
end

function SettingsService:start(): ()
	benchDetail("start() called")

	if not isInitialized then
		bench("init_fallback", function()
			self:init()
		end)
	end

	if not isInitialized then
		warn("[SettingsService] Failed to initialize, aborting start")
		return
	end

	bench("InputHandler.connect", function()
		InputHandler.connect({
			OnMenuToggle = function()
				self:Toggle()
			end,
			OnMenuClose = function()
				self:Hide()
			end,
		}, function()
			return isVisible
		end)
	end)

	bench("WorldEffects.init", function()
		pcall(WorldEffects.init)
	end)

	settings = DeepCopy.copy(SettingsConfig.DefaultSettings)

	benchDetail("start() sync complete, spawning async settings fetch")

	task.spawn(function()		bench("Network.Settings.getSettings", function()
			local serverData = Network.Settings.getSettings()
			if serverData then
				local prevSettings = if settings and settings.Settings then settings.Settings else nil
				settings = TableMerge.mergeWithDefaults(serverData, SettingsConfig.DefaultSettings)
				menuStale = MenuManager.isCreated()
				benchDetail("Got settings from server")

				if settings.Settings then
					bench("WorldEffects.applyAll", function()
						pcall(WorldEffects.applyAll, settings.Settings)
					end)

					for key, value in settings.Settings do
						if not prevSettings or prevSettings[key] ~= value then
							settingChangedSignal:Fire(key, value)
						end
					end
				end

				if settings.Keybinds then
					for key, value in settings.Keybinds do
						keybindChangedSignal:Fire(key, value)
					end
					
					if settings.Keybinds.Menu then
						bench("setMenuKey", function()
						local menuKeyCode = keyNameToKeyCode(settings.Keybinds.Menu)
						if menuKeyCode then
							InputHandler.setMenuKey(menuKeyCode)
							benchDetail("Menu keybind set to " .. settings.Keybinds.Menu)
						end
					end)
					end
				end

				local cursor = ServiceLocator.Cursor()
				if cursor and settings.Settings then
					local customId = tonumber(settings.Settings.CustomCursorId) or 0
					cursor:SetCustomCursorId(customId)
					local style = tonumber(settings.Settings.CursorStyle) or 1
					cursor:SetCursorStyle(style)
					local iffSetting = settings.Settings.IFF
					if iffSetting ~= nil then
						cursor:SetIFFEnabled(iffSetting == true)
					end
				end

			else
				benchDetail("Using default settings")
			end
		end)
	end)
end

local DEBUG_ENABLED = false
local function debugLog(msg: string)
	if DEBUG_ENABLED then
		print("[SETTINGS-SVC] " .. msg)
	end
end

function SettingsService:Show(): ()
	debugLog("Show() called")
	local showStart = os.clock()

	if not isInitialized then
		debugLog("Show() aborted: not initialized")
		return
	end
	if isVisible then
		debugLog("Show() aborted: already visible")
		return
	end

	if LoadingState.isLoadingActive(ServiceLocator.Loading(), playerGui) then
		debugLog("Show() aborted: loading active")
		return
	end

	if menuStale then
		menuStale = false
		MenuManager.destroy()
	end

	if not ensureMenuCreated() then
		debugLog("Show() aborted: failed to create menu")
		return
	end

	local gun = ServiceLocator.Gun()
	if gun then
		gun:SetFireBlocked(true)
	end

	isVisible = true

	debugLog("Hiding all UI...")
	local hideStart = os.clock()
	hideAllUI()
	debugLog(string.format("hideAllUI() took %.3fms", (os.clock() - hideStart) * 1000))

	debugLog("Setting menu visible...")
	local menuVisStart = os.clock()
	MenuManager.setVisible(true)
	debugLog(string.format("MenuManager.setVisible() took %.3fms", (os.clock() - menuVisStart) * 1000))

	if blurEffect then
		debugLog("Starting blur tween...")
		BlurEffectUtil.tweenTo(blurEffect, 24)
	end

	menuVisibilityChangedSignal:Fire(true)

	debugLog(string.format("Total Show() took %.3fms", (os.clock() - showStart) * 1000))
end

function SettingsService:Hide(): ()
	debugLog("Hide() called")
	if not isVisible then
		debugLog("Hide() aborted: not visible")
		return
	end

	isVisible = false

	local gun = ServiceLocator.Gun()
	if gun then
		gun:SetFireBlocked(false)
	end

	MenuManager.setVisible(false)

	debugLog("Restoring all UI...")
	restoreAllUI()

	if blurEffect then
		debugLog("Starting blur tween to 0...")
		BlurEffectUtil.tweenTo(blurEffect, 0)
	end

	menuVisibilityChangedSignal:Fire(false)
	debugLog("Hide() complete")
end

function SettingsService:Toggle(): ()
	debugLog("Toggle() called, isVisible=" .. tostring(isVisible))
	if isVisible then
		self:Hide()
	else
		self:Show()
	end
end

function SettingsService:IsVisible(): boolean
	return isVisible
end

function SettingsService:GetSettings(): SettingsConfig.SettingsTemplate?
	return settings
end

function SettingsService:GetSetting(key: string): any
	if settings and settings.Settings[key] ~= nil then
		return settings.Settings[key]
	end
	return nil
end

function SettingsService:GetKeybind(key: string): string?
	if settings and settings.Keybinds[key] then
		return settings.Keybinds[key]
	end
	return nil
end

function SettingsService:RefreshMenu(): ()
	if settings and settings.Keybinds and settings.Keybinds.Menu then
		local menuKeyCode = keyNameToKeyCode(settings.Keybinds.Menu)
		if menuKeyCode then
			InputHandler.setMenuKey(menuKeyCode)
		end
	end

	if settings and settings.Settings then
		pcall(WorldEffects.applyAll, settings.Settings)

		local cursor = ServiceLocator.Cursor()
		if cursor then
			local customId = tonumber(settings.Settings.CustomCursorId) or 0
			cursor:SetCustomCursorId(customId)
			local style = tonumber(settings.Settings.CursorStyle) or 1
			cursor:SetCursorStyle(style)
			local iffSetting = settings.Settings.IFF
			if iffSetting ~= nil then
				cursor:SetIFFEnabled(iffSetting == true)
			end
		end
	end

	menuStale = false
	MenuManager.destroy()
	menuCallbacks = createMenuCallbacks()
	local menu = MenuManager.create(settings, menuCallbacks)
	if menu and playerGui then
		menu.Parent = playerGui
	end

	if isVisible then
		MenuManager.setVisible(true)
	end
end

function SettingsService:ResetSettings(): ()
	local gunService = ServiceLocator.get("GunService")
	if gunService and gunService.ClearActiveRays then
		gunService:ClearActiveRays()
	end

	local newSettings = Network.Settings.resetSettings()
	if newSettings then
		settings = newSettings

		if settings.Settings then
			for key, value in settings.Settings do
				settingChangedSignal:Fire(key, value)
			end
		end

		self:RefreshMenu()
	end
end

function SettingsService:UpdateSetting(key: string, value: any): ()
	if settings then
		settings.Settings[key] = value
	end

	settingChangedSignal:Fire(key, value)

	local cursor = ServiceLocator.Cursor()
	if key == "CursorStyle" and cursor then
		cursor:SetCursorStyle(value)
	elseif key == "CustomCursorId" and cursor then
		local numValue = tonumber(value) or 0
		cursor:SetCustomCursorId(numValue)
	elseif key == "IFF" and cursor then
		cursor:SetIFFEnabled(value == true)
	end

	pcall(WorldEffects.applySetting, key, value)
	Network.Settings.changeSetting(key, value)
end

function SettingsService:Cleanup(): ()
	self:Hide()
	menuStale = false
	MenuManager.destroy()
	AvatarViewportLoader.clearCache()
	InputHandler.disconnect()
	pcall(WorldEffects.cleanup)
	if blurEffect then
		blurEffect:Destroy()
		blurEffect = nil
	end
	table.clear(previousCoreGuiStates)
	table.clear(previousScreenGuiStates)
	isInitialized = false
end

return SettingsService
