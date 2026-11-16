--!strict
--!native
--!optimize 2

local Properties = {
	Mode = "Auto",
	GunImageId = 111956303169549,
	FireRate = 0.075,
	MaxAmmo = 100,
	Range = 1000,
	RechargePerSecond = 25,
	Spread = 0.010,
	BaseDamage = 18,
	HeadDamage = 20,
	Animations = {
		Fire = 101732679074520,
		Sprint = 85319656146703,
		Idle = 75677670797652,
	},
	Sounds = {
		Fire = 86015039407710,
	},
	HolsterPart = "Torso",
	HolsterOffset = CFrame.new(0.660148621, -0.020160675, -0.35, 0, 0, -1.00000012, -0.707106829, 0.707106829, 0, 0.707106829, 0.707106829, 0),
}

return Properties
