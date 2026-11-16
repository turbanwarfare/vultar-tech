--!strict
--!native
--!optimize 2


local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Vultar = require(MainModule)
local Theme = require(MainModule.Shared.UI.Theme)
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)

local SettingsHelper = {}

function SettingsHelper.getSetting(key: string): any
	local SettingsService = Vultar.GetService("SettingsService")
	if SettingsService then
		local value = SettingsService:GetSetting(key)
		if value ~= nil then
			return value
		end
	end
	return SettingsConfig.DefaultSettings.Settings[key]
end

function SettingsHelper.getHitmarkerColor(isHeadshot: boolean): Color3
	local colorIndex = SettingsHelper.getSetting("HitColor") or 1
	local forceRedOnHeadshot = SettingsHelper.getSetting("HitHeadshotRed")

	if isHeadshot and forceRedOnHeadshot then
		return Color3.fromRGB(255, 50, 50)
	end

	return Theme.HighlightColors[colorIndex] or Theme.HighlightColors[1]
end

function SettingsHelper.getHighlightColor(isHeadshot: boolean): Color3
	local colorIndex = if isHeadshot
		then SettingsHelper.getSetting("HitHighlightHeadColor") or 3
		else SettingsHelper.getSetting("HitHighlightBodyColor") or 1
	return Theme.HighlightColors[colorIndex] or Theme.HighlightColors[1]
end

function SettingsHelper.getDamageColor(isHeadshot: boolean): Color3
	return if isHeadshot then Color3.fromRGB(255, 70, 70) else Color3.new(1, 1, 1)
end

local FONT_LOOKUP: { [string]: Enum.Font } = {}
do
	for _, item in Enum.Font:GetEnumItems() do
		FONT_LOOKUP[item.Name] = item
	end
end

function SettingsHelper.getDamageFont(): Enum.Font
	local fontVal = SettingsHelper.getSetting("DamageIndicatorFont")
	if fontVal and typeof(fontVal) == "string" then
		return FONT_LOOKUP[fontVal] or Enum.Font.GothamBold
	end
	return Enum.Font.GothamBold
end

function SettingsHelper.getHealFont(): Enum.Font
	local fontVal = SettingsHelper.getSetting("HealIndicatorFont")
	if fontVal and typeof(fontVal) == "string" then
		return FONT_LOOKUP[fontVal] or Enum.Font.GothamBold
	end
	return Enum.Font.GothamBold
end

function SettingsHelper.getKillIndicatorColor(): Color3
	local colorIndex = SettingsHelper.getSetting("KillIndicatorColor") or 1
	local colors = {
		Color3.new(1, 1, 1),
		Color3.fromRGB(255, 220, 50),
		Color3.fromRGB(255, 70, 70),
		Color3.fromRGB(80, 255, 120),
		Color3.fromRGB(255, 150, 50),
		Color3.fromRGB(100, 180, 255),
	}
	return colors[colorIndex] or colors[1]
end

return SettingsHelper
