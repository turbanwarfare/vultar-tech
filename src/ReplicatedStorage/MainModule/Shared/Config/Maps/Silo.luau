--!strict
--!native
--!optimize 2

return {
	DT = {
		GameType = "DT",
		DefaultPoints = 500,
		Hardpoint = true,
		ClassSystem = false,
		ForceWeapon = {
			Defender = "H-22", -- SMG for defenders
			Raider = "BR-22", -- SMG for raiders
		},
		RespawnTime = 3,
	},

	Raid = {
		GameType = "Raid",
		DefaultPoints = 500,
		Hardpoint = true,
		ClassSystem = false,
		ForceWeapon = {
			Defender = "H-22", -- SMG for defenders
			Raider = "BR-22", -- SMG for raiders
		},
		RespawnTime = 3,
	},
	FeatureFlags = {},
}
