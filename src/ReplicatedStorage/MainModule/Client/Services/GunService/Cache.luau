--!strict
--!native
--!optimize 2

local Constants = require(script.Parent.Constants)

local Cache = {}

local values: { [string]: any } = {}
local isInitialized = false
local settingsConnection: any = nil
local SettingsService: any = nil

local FONT_LOOKUP: { [string]: Enum.Font } = {}
do
	for _, item in Enum.Font:GetEnumItems() do
		FONT_LOOKUP[item.Name] = item
	end
end

local customKillSoundCallback: (() -> ())? = nil

local cachedDamageIndicatorFont: Enum.Font = Enum.Font.GothamBold
local cachedHealIndicatorFont: Enum.Font = Enum.Font.GothamBold

local function updateCachedFont()
	local fontName = values.DamageIndicatorFont
	if fontName and typeof(fontName) == "string" then
		cachedDamageIndicatorFont = FONT_LOOKUP[fontName] or Enum.Font.GothamBold
	else
		cachedDamageIndicatorFont = Enum.Font.GothamBold
	end

	local healFontName = values.HealIndicatorFont
	if healFontName and typeof(healFontName) == "string" then
		cachedHealIndicatorFont = FONT_LOOKUP[healFontName] or Enum.Font.GothamBold
	else
		cachedHealIndicatorFont = Enum.Font.GothamBold
	end
end

local function loadFromSettings()
	if not SettingsService then return end

	for key, default in Constants.Defaults do
		local value = SettingsService:GetSetting(key)
		values[key] = if value ~= nil then value else default
	end
	updateCachedFont()
	if customKillSoundCallback then
		customKillSoundCallback()
	end
end

local function onSettingChanged(key: string, value: any)
	if Constants.Defaults[key] ~= nil then
		values[key] = value
		if key == "DamageIndicatorFont" or key == "HealIndicatorFont" then
			updateCachedFont()
		elseif key == "CustomKillSoundId" and customKillSoundCallback then
			customKillSoundCallback()
		end
	end
end

function Cache.init()
	if isInitialized then return end

	for key, default in Constants.Defaults do
		values[key] = default
	end
	updateCachedFont()

	task.spawn(function()
		local success, result = pcall(require, script.Parent.Parent.SettingsService)

		if success and result then
			SettingsService = result

			if SettingsService.SettingChanged then
				settingsConnection = SettingsService.SettingChanged:Connect(onSettingChanged)
			end

			loadFromSettings()
		end
	end)

	isInitialized = true
end

function Cache.get(key: string): any
	return values[key]
end

function Cache.getDamageIndicatorsEnabled(): boolean
	local val = values.DamageIndicators
	return if val ~= nil then val else Constants.Defaults.DamageIndicators
end

function Cache.getDamageIndicatorType(): number
	return values.DamageIndicatorType or Constants.Defaults.DamageIndicatorType
end

function Cache.getDamageIndicatorStickTo(): number
	return values.DamageIndicatorStickTo or Constants.Defaults.DamageIndicatorStickTo
end

function Cache.getStackKillFlash(): boolean
	local val = values.StackKillFlash
	return if val ~= nil then val else Constants.Defaults.StackKillFlash
end

function Cache.getDamageIndicatorFontName(): string
	local fontName = values.DamageIndicatorFont
	if fontName and typeof(fontName) == "string" then
		return fontName
	end
	return Constants.Defaults.DamageIndicatorFont or "GothamBold"
end

function Cache.getDamageIndicatorFont(): Enum.Font
	return cachedDamageIndicatorFont
end

function Cache.getDamageIndicatorSize(): number
	return values.DamageIndicatorSize or Constants.Defaults.DamageIndicatorSize
end

function Cache.getDamageIndicatorOutline(): number
	return values.DamageIndicatorOutline or Constants.Defaults.DamageIndicatorOutline
end

function Cache.getHitSoundsEnabled(): boolean
	local val = values.HitSounds
	return if val ~= nil then val else Constants.Defaults.HitSounds
end

function Cache.onCustomKillSoundChanged(callback: (() -> ())?): ()
	customKillSoundCallback = callback
end

function Cache.getCustomKillSoundId(): number
	local val = values.CustomKillSoundId
	return if type(val) == "number" then val else Constants.Defaults.CustomKillSoundId
end

function Cache.getKillSoundsEnabled(): boolean
	local val = values.KillSounds
	return if val ~= nil then val else Constants.Defaults.KillSounds
end

function Cache.getWeaponSoundsEnabled(): boolean
	local val = values.WeaponSounds
	return if val ~= nil then val else Constants.Defaults.WeaponSounds
end

function Cache.getHealSoundsEnabled(): boolean
	local val = values.HealSounds
	return if val ~= nil then val else Constants.Defaults.HealSounds
end

function Cache.getCountdownSoundsEnabled(): boolean
	local val = values.CountdownSounds
	return if val ~= nil then val else Constants.Defaults.CountdownSounds
end

function Cache.getRayType(): number
	return values.RayType or Constants.Defaults.RayType
end

function Cache.getRaySpeed(): number
	return values.RaySpeed or Constants.Defaults.RaySpeed
end

function Cache.useBeamRay(): boolean
	return Cache.getRayType() == 2
end

function Cache.getRayDuration(): number
	return Cache.getRaySpeed() * Constants.Ray.SpeedMultiplier
end

function Cache.getRayStickToBarrel(): boolean
	local val = values.RayStickToBarrel
	return if val ~= nil then val else Constants.Defaults.RayStickToBarrel
end

function Cache.getHitIndicatorsEnabled(): boolean
	local val = values.HitIndicators
	return if val ~= nil then val else Constants.Defaults.HitIndicators
end

function Cache.getHitPreset(): number
	return values.HitPreset or Constants.Defaults.HitPreset
end

function Cache.getHitIndicatorSize(): number
	return values.HitIndicatorSize or 1
end

function Cache.getHitColor(): number
	return values.HitColor or Constants.Defaults.HitColor
end

function Cache.getHitHeadshotRed(): boolean
	local val = values.HitHeadshotRed
	return if val ~= nil then val else Constants.Defaults.HitHeadshotRed
end

function Cache.getHitmarkerRotation(): number
	return values.HitmarkerRotation or Constants.Defaults.HitmarkerRotation
end

function Cache.getHitmarkerSpeedMultiplier(): number
	local speed = values.HitmarkerSpeed or Constants.Defaults.HitmarkerSpeed
	return Constants.HitmarkerSpeedMultipliers[speed] or 1.0
end

function Cache.getHitHighlightsEnabled(): boolean
	local val = values.HitHighlights
	return if val ~= nil then val else Constants.Defaults.HitHighlights
end

function Cache.getHitHighlightTransparency(): number
	return values.HitHighlightTransparency or Constants.Defaults.HitHighlightTransparency
end

function Cache.getHitHighlightThickness(): number
	return values.HitHighlightThickness or Constants.Defaults.HitHighlightThickness
end

function Cache.getHitHighlightFadeIn(): number
	return values.HitHighlightFadeIn or Constants.Defaults.HitHighlightFadeIn
end

function Cache.getHitHighlightDuration(): number
	return values.HitHighlightDuration or Constants.Defaults.HitHighlightDuration
end

function Cache.getHitHighlightHeadColor(): number
	return values.HitHighlightHeadColor or Constants.Defaults.HitHighlightHeadColor
end

function Cache.getHitHighlightBodyColor(): number
	return values.HitHighlightBodyColor or Constants.Defaults.HitHighlightBodyColor
end

function Cache.getHealHighlightsEnabled(): boolean
	local val = values.HealHighlights
	return if val ~= nil then val else Constants.Defaults.HealHighlights
end

function Cache.getHealHighlightTransparency(): number
	return values.HealHighlightTransparency or Constants.Defaults.HealHighlightTransparency
end

function Cache.getHealNumberIndicatorsEnabled(): boolean
	local val = values.HealNumberIndicators
	return if val ~= nil then val else Constants.Defaults.HealNumberIndicators
end

function Cache.getHealIndicatorFontName(): string
	local fontName = values.HealIndicatorFont
	if fontName and typeof(fontName) == "string" then
		return fontName
	end
	return Constants.Defaults.HealIndicatorFont or "GothamBold"
end

function Cache.getHealIndicatorFont(): Enum.Font
	return cachedHealIndicatorFont
end

function Cache.getHealIndicatorSize(): number
	return values.HealIndicatorSize or Constants.Defaults.HealIndicatorSize
end

function Cache.getHealIndicatorType(): number
	return values.HealIndicatorType or Constants.Defaults.HealIndicatorType
end

function Cache.getHideClientRays(): boolean
	local val = values.HideClientRays
	return if val ~= nil then val else Constants.Defaults.HideClientRays
end

function Cache.getRayMaterial(): number
	return values.RayMaterial or Constants.Defaults.RayMaterial
end

function Cache.getRaySize(): number
	return values.RaySize or Constants.Defaults.RaySize
end

function Cache.getRayOpacity(): number
	return values.RayOpacity or Constants.Defaults.RayOpacity
end

function Cache.getMuzzleFlashEnabled(): boolean
	local val = values.MuzzleFlash
	return if val ~= nil then val else Constants.Defaults.MuzzleFlash
end

function Cache.getBloodIndicatorEnabled(): boolean
	local val = values.BloodIndicator
	return if val ~= nil then val else Constants.Defaults.BloodIndicator
end

function Cache.getKillIndicatorsEnabled(): boolean
	local val = values.KillIndicators
	return if val ~= nil then val else Constants.Defaults.KillIndicators
end

function Cache.getKillIndicatorType(): number
	return values.KillIndicatorType or Constants.Defaults.KillIndicatorType
end

function Cache.getKillIndicatorColor(): number
	return values.KillIndicatorColor or Constants.Defaults.KillIndicatorColor
end

function Cache.getKillIndicatorSize(): number
	return values.KillIndicatorSize or Constants.Defaults.KillIndicatorSize
end

function Cache.getKillIndicatorTransparency(): number
	return values.KillIndicatorTransparency or Constants.Defaults.KillIndicatorTransparency
end

function Cache.getKillIndicatorPosition(): number
	return values.KillIndicatorPosition or Constants.Defaults.KillIndicatorPosition
end

function Cache.getOOCIndicatorPosition(): number
	return values.OOCIndicatorPosition or Constants.Defaults.OOCIndicatorPosition
end

function Cache.getTeamESPOverheadMode(): number
	return values.TeamESP_Overhead or Constants.Defaults.TeamESP_Overhead
end

function Cache.cleanup()
	if settingsConnection then
		settingsConnection:Disconnect()
		settingsConnection = nil
	end
	SettingsService = nil
	table.clear(values)
	isInitialized = false
end

return Cache
