--!strict
--!native
--!optimize 2

export type WeaponState = "Idle" | "Sprinting" | "Crouching" | "Saluting"
export type WeaponClass = "Assault" | "Medic"

export type AnimationSet = {
	Idle: string,
	Sprint: string,
	Crouch: string,
	Salute: string,
}

export type SpeedConfig = {
	Walk: number,
	Sprint: number,
	Crouch: number,
	Zoom: number,
}

export type KeybindConfig = {
	Sprint: Enum.KeyCode,
	Crouch: Enum.KeyCode,
	Salute: Enum.KeyCode,
	Zoom: Enum.KeyCode,
}

export type ClassConfig = {
	Tools: { string },
	Animations: AnimationSet,
	Speeds: SpeedConfig?,
	CanSprintWhileFiring: boolean?,
}

local WeaponConfig = {}

WeaponConfig.Classes = {
	Assault = {
		Tools = {
			"H-82",
			"H-82 INF",
			"BR-16",
			"H-22",
			"BR-22",
			"H-12",
			"BR-8",
			"H-41",
			"BR-40",
			"H-94",
			"H-94-DEV",
			"BR-56",
			"H-50",
			"BR-50",
			"GPR",
		},
		Animations = {
			Idle = "rbxassetid://96896749029991",
			Sprint = "rbxassetid://124471324749864",
			Crouch = "rbxassetid://101785625813335",
			Salute = "rbxassetid://92409640158033",
		},
	},
	Medic = {
		Tools = { "Medi+" },
		Animations = {
			Idle = "rbxassetid://96896749029991",
			Sprint = "rbxassetid://117462778726792",
			Crouch = "rbxassetid://101785625813335",
			Salute = "rbxassetid://92409640158033",
		},
		CanSprintWhileFiring = true,
	},
} :: { [WeaponClass]: ClassConfig }

WeaponConfig.DefaultSpeeds = {
	Walk = 16,
	Sprint = 24,
	Crouch = 14,
	Zoom = 14,
} :: SpeedConfig

WeaponConfig.DefaultKeybinds = {
	Sprint = Enum.KeyCode.F,
	Crouch = Enum.KeyCode.C,
	Salute = Enum.KeyCode.E,
	Zoom = Enum.KeyCode.Q,
} :: KeybindConfig

WeaponConfig.ZoomSettings = {
	FOV = 50,
	TweenIn = 0.5,
	TweenOut = 0.5,
	EasingIn = Enum.EasingStyle.Quad,
	EasingOut = Enum.EasingStyle.Quad,
}

WeaponConfig.AnimationFadeTime = 0.15

local toolClassCache: { [string]: WeaponClass } = {}

local function buildToolClassCache(): ()
	for className, config in WeaponConfig.Classes do
		for _, toolName in config.Tools do
			toolClassCache[toolName] = className :: WeaponClass
		end
	end
end

function WeaponConfig.getToolClass(toolName: string): WeaponClass?
	if not next(toolClassCache) then
		buildToolClassCache()
	end
	return toolClassCache[toolName]
end

function WeaponConfig.getClassConfig(className: WeaponClass): ClassConfig?
	return WeaponConfig.Classes[className]
end

function WeaponConfig.getToolConfig(toolName: string): ClassConfig?
	local class = WeaponConfig.getToolClass(toolName)
	if not class then
		return nil
	end
	return WeaponConfig.getClassConfig(class)
end

function WeaponConfig.isWeaponTool(toolName: string): boolean
	return WeaponConfig.getToolClass(toolName) ~= nil
end

function WeaponConfig.getSpeeds(toolName: string): SpeedConfig
	local config = WeaponConfig.getToolConfig(toolName)
	if config and config.Speeds then
		return config.Speeds
	end
	return WeaponConfig.DefaultSpeeds
end

function WeaponConfig.canSprintWhileFiring(toolName: string): boolean
	local config = WeaponConfig.getToolConfig(toolName)
	return if config and config.CanSprintWhileFiring then true else false
end

return WeaponConfig
