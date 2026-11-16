--!strict
--!native
--!optimize 2

local Properties = {
	Mode = "Semi",
	GunImageId = 85019502268004,
	FireRate = 3,
	MaxAmmo = 3,
	Range = 1000,
	RechargePerSecond = 0.5,
	Spread = 0.001,
	BaseDamage = 60,
	HeadDamage = 60,
	Chargeable = true,
	ChargeTime = 6,
	MaxChargeMultiplier = 1.75,
	Animations = {
		Fire = 106184363699844,
		Sprint = 118878353649675,
		Idle = 75700328583771,
	},
	Sounds = {
		Fire = 88766777954581,
	},
	HolsterPart = "Torso",
	HolsterOffset = CFrame.new(0.660148621, -0.020160675, -0.35, 0, 0, -1.00000012, -0.707106829, 0.707106829, 0, 0.707106829, 0.707106829, 0),
}

return Properties
