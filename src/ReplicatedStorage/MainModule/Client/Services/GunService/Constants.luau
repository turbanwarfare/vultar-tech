--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local SettingsEnums = require(MainModule.Shared.Config.Settings.SettingsEnums)

local Constants = {}
Constants.Enums = SettingsEnums

Constants.Colors = {
	Ray = Color3.fromRGB(197, 36, 36),
	RayHostile = Color3.fromRGB(0, 85, 255),
	RayInner = Color3.fromRGB(255, 255, 255),
	Stroke = Color3.fromRGB(15, 15, 15),
	DamageNormal = Color3.new(1, 1, 1),
	DamageHead = Color3.fromRGB(255, 70, 70),
	Heal = Color3.fromRGB(80, 255, 120),
}

Constants.Ray = {
	Transparency = 0.3,
	DefaultSpeed = 3,
	SpeedMultiplier = 0.025,
	BeamTexture = "rbxassetid://2950987173",
	FadeDuration = 0.05,

	BeamGlowWidth = 0.8,
	BeamGlowTransparency = 0.7,
	BeamOuterWidth = 0.28,
	BeamInnerWidth = 0.12,

	PartWidth = 0.15,
}

Constants.Pool = {
	MaxSize = 100,
	InitialParts = 20,
	InitialBeams = 20,
	MaxBillboards = 200,
	MaxLabels = 200,
	MaxAttachments = 200,
	SoundPoolSize = 8,
}

Constants.Sounds = {
	Hit = "rbxassetid://6916371803",
	Headshot = "rbxassetid://3581383408",
	Kill = "rbxassetid://100457395545576",
	Heal = "rbxassetid://115465917311584",
}

Constants.KillIndicator = {
	CircleImage = "rbxassetid://6031068433",
	SkullImage = "rbxassetid://0",
	ExpandDuration = 0.3,
	FadeDuration = 0.3,
	TotalLifetime = 1.0,
	DefaultSize = 65,
}

Constants.KillIndicatorColors = {
	Color3.new(1, 1, 1),
	Color3.fromRGB(255, 220, 50),
	Color3.fromRGB(180, 30, 30),
	Color3.fromRGB(80, 255, 120),
	Color3.fromRGB(255, 150, 50),
	Color3.fromRGB(100, 180, 255),
}

Constants.Hitmarker = {
	SizeLarge = UDim2.fromOffset(40, 40),
	SizeNormal = UDim2.fromOffset(32, 32),
	AnimDuration = 0.15,
	PoolSize = 12,
	RotationSpeed = 180,
	FadeInDuration = 0.06,
	HoldDuration = 0.08,
	FadeOutDuration = 0.12,
	ScalePopIn = 1.25,
	ScalePopOut = 0.85,
}

Constants.Indicator = {
	ExpandDuration = 0.85,
	ExpandGrowEnd = 0.75,
	ExpandFadeStart = 0.7,
	CursorOffsetX = 12,
	CursorOffsetY = 35,
	CursorPopDuration = 0.25,
	CursorFadeDuration = 0.28,
	PulseUpDuration = 0.08,
	PulseDownDuration = 0.12,
	CombinedUpDuration = 0.08,
	CombinedDownDuration = 0.06,
	ShrinkDuration = 0.2,
	StackTimeout = 1.2,
}

Constants.Raycast = {
	MaxAimDistance = 2000,
}

Constants.Highlight = {
	PoolSize = 20,
}

Constants.BloodSplatter = {
	PoolSize = 30,
	EmitCount = 6,
	CleanupDelay = 2,
}

Constants.Defaults = {
	DamageIndicators = true,
	DamageIndicatorFont = "GothamBold",
	DamageIndicatorType = SettingsEnums.DamageIndicatorType.Expand,
	DamageIndicatorStickTo = SettingsEnums.StickTo.Player,
	StackKillFlash = true,
	DamageIndicatorSize = 18,
	DamageIndicatorOutline = 1.25,
	HitSounds = true,
	KillSounds = true,
	CustomKillSoundId = 0,
	WeaponSounds = true,
	HealSounds = true,
	CountdownSounds = true,
	RayType = SettingsEnums.RayType.Beam,
	RaySpeed = SettingsEnums.RaySpeed.Default,
	RayStickToBarrel = false,
	HitIndicators = true,
	HitPreset = 1,
	HitColor = SettingsEnums.Color.White,
	HitHeadshotRed = true,
	HitIndicatorSize = 1,
	HitmarkerRotation = SettingsEnums.HitmarkerRotation.Random,
	HitmarkerSpeed = SettingsEnums.HitmarkerSpeed.Normal,
	HitHighlights = true,
	HitHighlightTransparency = 0.65,
	HitHighlightThickness = 0.04,
	HitHighlightFadeIn = 0.12,
	HitHighlightDuration = 0.18,
	HitHighlightHeadColor = SettingsEnums.Color.Red,
	HitHighlightBodyColor = SettingsEnums.Color.White,
	HealHighlights = true,
	HealHighlightTransparency = 0.65,
	HealNumberIndicators = true,
	HealIndicatorFont = "GothamBold",
	HealIndicatorSize = 16,
	HealIndicatorType = SettingsEnums.HealIndicatorType.Expand,
	MuzzleFlash = true,
	HideClientRays = false,
	RayMaterial = SettingsEnums.RayMaterial.Neon,
	RaySize = 1,
	RayOpacity = 1,
	BloodIndicator = true,
	KillIndicators = true,
	KillIndicatorType = SettingsEnums.KillIndicatorType.Circle,
	KillIndicatorColor = SettingsEnums.Color.Red,
	KillIndicatorSize = 65,
	KillIndicatorTransparency = 0,
	KillIndicatorPosition = SettingsEnums.StickTo.Cursor,
	OOCIndicatorPosition = SettingsEnums.OOCIndicatorPosition.TeamESP,
	TeamESP_Overhead = SettingsEnums.TeamESPOverhead.Detailed,
}

Constants.HitmarkerSpeedMultipliers = {
	0.5,
	1.0,
	2.0,
}

return Constants
