--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)

local Validation = {}

local ARRAY_SETTINGS: { [string]: { maxLength: number } } = {
	CustomCursorHistory = { maxLength = SettingsConfig.MAX_CURSOR_HISTORY },
	RadialCursors = { maxLength = SettingsConfig.MAX_RADIAL_CURSORS },
	CursorSwitchHistory = { maxLength = SettingsConfig.MAX_CURSOR_SWITCH_HISTORY },
}

local function validateArraySetting(key: string, value: any): boolean
	local config = ARRAY_SETTINGS[key]
	if not config then
		return false
	end

	if type(value) ~= "table" then
		return false
	end

	if #value > config.maxLength then
		return false
	end

	for _, item in value do
		if type(item) ~= "number" or item <= 0 then
			return false
		end
	end

	return true
end

function Validation.validateSettingValue(key: string, value: any): boolean
	local defaults = SettingsConfig.DefaultSettings.Settings
	local defaultValue = defaults[key]

	if defaultValue == nil then
		return false
	end

	if ARRAY_SETTINGS[key] then
		return validateArraySetting(key, value)
	end

	return type(value) == type(defaultValue)
end

function Validation.validateKeybindValue(key: string, value: string): (boolean, string?)
	local defaults = SettingsConfig.DefaultSettings.Keybinds
	if defaults[key] == nil then
		return false, nil
	end

	if type(value) ~= "string" or #value == 0 then
		return false, defaults[key]
	end

	local success, keyEnum = pcall(function()
		return (Enum.KeyCode :: any)[value]
	end)

	if not success or typeof(keyEnum) ~= "EnumItem" then
		return false, defaults[key]
	end

	if SettingsConfig.KEYBINDS_BLACKLIST_SET[keyEnum] then
		return false, defaults[key]
	end

	return true, value
end

function Validation.checkDuplicateKeybind(currentKeybinds: { [string]: string }, key: string, newValue: string): boolean
	for existingKey, existingValue in currentKeybinds do
		if existingValue == newValue and existingKey ~= key then
			return true
		end
	end
	return false
end

return Validation
