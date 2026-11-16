--!strict
--!native
--!optimize 2

local Properties = {
	Mode = "Auto",
	GunImageId = 123078399540323,
	FireRate = 0.075,
	MaxAmmo = 100,
	Range = 1000,
	RechargePerSecond = 25,
	Spread = 0.010,
	BaseDamage = 18,
	HeadDamage = 20,
	Animations = {
		Fire = 85096676452543,
		Sprint = 94148949080250,
		Idle = 138285439235662,
	},
	Sounds = {
		Fire = 88766777954581,
	},
	HolsterPart = "Torso",
	HolsterOffset = CFrame.new(0.660148621, -0.020160675, -0.35, 0, 0, -1.00000012, -0.707106829, 0.707106829, 0, 0.707106829, 0.707106829, 0),
}

return Properties
