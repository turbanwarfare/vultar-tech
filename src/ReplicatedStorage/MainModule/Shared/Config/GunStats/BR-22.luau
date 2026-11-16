--!strict
--!native
--!optimize 2

local Properties = {
	Mode = "Auto",
	GunImageId = 105057366885200,
	FireRate = 0.08,
	MaxAmmo = 30,
	Range = 400,
	RechargePerSecond = 15,
	Spread = 0.0099,
	BaseDamage = 10,
	HeadDamage = 11,
	Animations = {
		Fire = 77465151388662,
		Sprint = 72704723906836,
		Idle = 114120210198223,
	},
	Sounds = {
		Fire = 86015039407710,
	},
	HolsterPart = "Torso",
	HolsterOffset = CFrame.new(-0.55, 0, -0.35, 0, 0, -1.00000012, -0.707106829, 0.707106829, 0, 0.707106829, 0.707106829, 0),
}

return Properties
