--!strict
--!native
--!optimize 2

local Types = require(script.Types)

export type ExportResult = Types.ExportResult
export type ImportResult = Types.ImportResult

local SettingsNetwork = {}

local NOOP_CONNECTION = { Disconnect = function() end }

local cachedSettings: any? = nil
local settingsCached = false

function SettingsNetwork.getSettings(): any?
	if settingsCached then
		return cachedSettings
	end

	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Settings.GetSettings.Invoke)
	if success then
		cachedSettings = result
		settingsCached = true
		return result
	end
	return nil
end

function SettingsNetwork.onGetSettings(callback: (player: Player) -> any): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Settings.GetSettings.On(callback)
	return NOOP_CONNECTION
end

function SettingsNetwork.changeSetting(key: string, value: any): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Settings.ChangeSetting.Fire(key, value)
	if settingsCached and cachedSettings then
		cachedSettings[key] = value
	end
end

function SettingsNetwork.onChangeSetting(callback: (player: Player, key: string, value: any) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Settings.ChangeSetting.On(callback)
	return NOOP_CONNECTION
end

function SettingsNetwork.changeKeybind(key: string, value: string): string?
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Settings.ChangeKeybind.Invoke, key, value)
	if success then
		return result
	end
	return nil
end

function SettingsNetwork.onChangeKeybind(callback: (player: Player, key: string, value: string) -> string?): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Settings.ChangeKeybind.On(callback)
	return NOOP_CONNECTION
end

function SettingsNetwork.resetSettings(): any?
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Settings.ResetSettings.Invoke)
	if success then
		cachedSettings = result
		settingsCached = true
		return result
	end
	return nil
end

function SettingsNetwork.onResetSettings(callback: (player: Player) -> any): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Settings.ResetSettings.On(callback)
	return NOOP_CONNECTION
end

function SettingsNetwork.exportSettings(): ExportResult
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Settings.ExportSettings.Invoke)
	if success and result then
		return result
	end
	return { success = false }
end

function SettingsNetwork.onExportSettings(callback: (player: Player) -> ExportResult): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Settings.ExportSettings.On(callback)
	return NOOP_CONNECTION
end

function SettingsNetwork.importSettings(code: string): ImportResult
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Settings.ImportSettings.Invoke, code)
	if success and result then
		if result.success and result.settings then
			cachedSettings = result.settings
			settingsCached = true
		end
		return result
	end
	return { success = false, error = "Network error" }
end

function SettingsNetwork.onImportSettings(callback: (player: Player, code: string) -> ImportResult): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Settings.ImportSettings.On(callback)
	return NOOP_CONNECTION
end

function SettingsNetwork.checkCursor(assetId: number): number
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Settings.CheckCursor.Invoke, assetId)
	if success and result then
		return result
	end
	return 0
end

function SettingsNetwork.onCheckCursor(callback: (player: Player, assetId: number) -> number): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Settings.CheckCursor.On(callback)
	return NOOP_CONNECTION
end

function SettingsNetwork.init(): ()
end

return SettingsNetwork
