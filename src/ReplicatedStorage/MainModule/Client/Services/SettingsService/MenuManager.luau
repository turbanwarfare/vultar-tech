--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5)) :: any
local scoped = Fusion.scoped

local SettingsMenu = require(script.Parent.Parent.Parent.Components.Menu.MenuRoot)
local Signal = require(MainModule.Shared.Utils.State.Signal)

export type MenuCallbacks = {
	OnSettingChange: (key: string, value: any) -> (),
	OnKeybindChange: (key: string, value: string) -> (),
	OnKeybindEditStart: (() -> ())?,
	OnKeybindEditEnd: (() -> ())?,
	OnResetSettings: (() -> ())?,
	OnImportSettings: ((any) -> ())?,
	OnClose: () -> (),
	OnCursorEquip: ((cursorId: number) -> ())?,
	OnCursorToggleRadial: ((cursorId: number) -> ())?,
	SettingChanged: Signal.Signal<string, any>?,
}

export type PersistedMenuState = {
	currentTab: number,
	shopCurrentPage: number,
	shopCurrentTab: string,
	inventoryCurrentTab: number,
	selectedBundleKey: string?,
	selectedPackId: string?,
	selectedSkinId: string?,
	selectedCardId: string?,
	settingsSearchQuery: string?,
}

local MenuManager = {}

local scope: any = nil
local settingsMenu: ScreenGui? = nil
local visibleState: any = nil

local persistedState: PersistedMenuState = {
	currentTab = 1,
	shopCurrentPage = 1,
	shopCurrentTab = "featured",
	inventoryCurrentTab = 1,
	selectedBundleKey = nil,
	selectedPackId = nil,
	selectedSkinId = nil,
	selectedCardId = nil,
	settingsSearchQuery = "",
}

function MenuManager.create(settings: any, callbacks: MenuCallbacks): ScreenGui?
	if settingsMenu then
		return settingsMenu
	end

	local success, err = pcall(function()
		scope = scoped(Fusion)
		visibleState = scope:Value(false)

		settingsMenu = SettingsMenu(scope, {
			Visible = visibleState,
			Settings = settings,
			OnSettingChange = callbacks.OnSettingChange,
			OnKeybindChange = callbacks.OnKeybindChange,
			OnKeybindEditStart = callbacks.OnKeybindEditStart,
			OnKeybindEditEnd = callbacks.OnKeybindEditEnd,
			OnResetSettings = callbacks.OnResetSettings,
			OnImportSettings = callbacks.OnImportSettings,
			OnClose = callbacks.OnClose,
			InitialState = persistedState,
			OnStateChange = function(newState: PersistedMenuState)
				persistedState = newState
			end,
			OnCursorEquip = callbacks.OnCursorEquip,
			OnCursorToggleRadial = callbacks.OnCursorToggleRadial,
			SettingChanged = callbacks.SettingChanged,
		})
	end)

	if not success then
		warn("[MenuManager] Failed to create settings menu:", err)
		return nil
	end

	return settingsMenu
end

function MenuManager.destroy(): ()
	if scope then
		Fusion.doCleanup(scope)
		scope = nil
	end
	settingsMenu = nil
	visibleState = nil
end

function MenuManager.setVisible(visible: boolean): ()
	if visibleState then
		visibleState:set(visible)
	end
end

function MenuManager.getMenu(): ScreenGui?
	return settingsMenu
end

function MenuManager.isCreated(): boolean
	return settingsMenu ~= nil
end

function MenuManager.resetState(): ()
	persistedState = {
		currentTab = 1,
		shopCurrentPage = 1,
		shopCurrentTab = "featured",
		inventoryCurrentTab = 1,
		selectedBundleKey = nil,
		selectedPackId = nil,
		selectedSkinId = nil,
		selectedCardId = nil,
		settingsSearchQuery = "",
	}
end

return MenuManager
