--!strict
--!native
--!optimize 2

local ClassConfig = require(script.Parent.Classes.ClassConfig)
local FeatureFlags = require(script.Parent.FeatureFlags)

export type AbilityDefinition = {
	Icon: string,
	IconSize: number?,
	Key: string,
	FeatureFlag: FeatureFlags.FeatureFlagName?,
	Charges: number?,
	Cooldown: number,
	Windup: number,
}

local STICKY = true

local AbilityConfig = {}

AbilityConfig.ClassAbilities = {
	Assault = { "Grenade", "Roll" },
	Shocktrooper = {},
	Devastator = {},
	Recon = { "Roll" },
} :: { [ClassConfig.ClassName]: { string } }

AbilityConfig.Abilities = {
	Grenade = {
		Icon = "rbxassetid://85012617711318",
		Key = "G",
		FeatureFlag = "Nades",
		Charges = 2,
		Cooldown = 15,
		Windup = 0.5,
		Stats = {
			INDICATOR_IMAGE = "rbxassetid://85012617711318",
			INDICATOR_DISTANCE = 50,
			STICKY = STICKY,
			FUSE_TIME = if STICKY then 2 else 1.5,
			THROW_SPEED = 80,
			MIN_FLIGHT_TIME = 0.2,
			MAX_FLIGHT_TIME = 1.4,
			MAX_RANGE = 40,
			AIM_SPREAD = 0.12,
			BOUNCE = 0.4,
			BOUNCE_KEEP = 0.4,
			BOUNCE_MIN_SPEED = 4,
			ROLL_FRICTION = 55,
			GRAVITY = Vector3.new(0, -80, 0),
			FRAME_TIME = 1 / 60,
			RADIUS = 0.4,
			REST_SPEED = 3,
			MAX_DAMAGE = 150,
			KILL_RADIUS = 5,
			DAMAGE_RADIUS = 18,
			MAX_WALL_THICKNESS = 3,
			THROW_ANIMATION = "rbxassetid://114761700782970",
			PIN_SOUND = "rbxassetid://4550595378",
			BEEP_SOUND = "rbxassetid://139657844452550",
		},
	},
	Roll = {
		Icon = "rbxassetid://114979452412047",
		IconSize = 40,
		Key = "LeftControl",
		FeatureFlag = "Roll",
		Cooldown = 5,
		Windup = 0,
		Stats = {
			SPEED = 30,
			DURATION = 0.5,
			LAUNCH_SPEED = 45,
			LAUNCH_TIME = 0.2,
			TRAIL_LIFETIME = 0.3,
			TRAIL_WIDTH = 0.1,
			ANIMATION = "rbxassetid://107659410180691",
		},
	},
}

local abilities: { [string]: AbilityDefinition } = AbilityConfig.Abilities :: any
local noAbilities: { string } = {}
local classlessAbilities: { string } = { "Grenade", "Roll" }

function AbilityConfig.get(name: string): AbilityDefinition?
	return abilities[name]
end

function AbilityConfig.getAll(): { [string]: AbilityDefinition }
	return abilities
end

function AbilityConfig.isActive(name: string): boolean
	local definition = abilities[name]
	if not definition then
		return false
	end
	return definition.FeatureFlag == nil or FeatureFlags.isEnabled(definition.FeatureFlag)
end

function AbilityConfig.forClass(className: any): { string }
	if className == nil then
		return classlessAbilities
	end
	return AbilityConfig.ClassAbilities[className] or noAbilities
end

function AbilityConfig.classHas(className: any, name: string): boolean
	return table.find(AbilityConfig.forClass(className), name) ~= nil
end

return AbilityConfig
