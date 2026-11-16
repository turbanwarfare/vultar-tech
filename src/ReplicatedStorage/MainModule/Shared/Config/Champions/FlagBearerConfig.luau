--!strict
--!native
--!optimize 2

local FlagBearerConfig = {
	AuraHeal = {
		Key = Enum.KeyCode.E,
		Cooldown = 10,
		Duration = 10,
		HealPerTick = 3,
		TickInterval = 0.12,
		Radius = 20,
		RadiusSquared = 20 * 20,
	},

	Shield = {
		Key = Enum.KeyCode.G,
		Cooldown = 15,
		Duration = 10,
		Health = 500,
		Radius = 8,
		RadiusSquared = 8 * 8,
	},

	FlagAnimationId = "rbxassetid://83507017217677",
}

return FlagBearerConfig
