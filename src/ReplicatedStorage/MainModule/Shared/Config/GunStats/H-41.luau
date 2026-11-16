--!strict
--!native
--!optimize 2

local Properties = {
	Mode = "Semi",
	GunImageId = 121612272092351,
	FireRate = 0.8,
	MaxAmmo = 7,
	Range = 75,
	RechargePerSecond = 3.5,
	Spread = 0.005,
	SpreadPerfectRange = 21,
	SpreadStartRange = 25,
	BaseDamage = 18,
	HeadDamage = 20,
	Pellets = 7,
	Animations = {
		Fire = 80213000805894,
		Sprint = 128473960557614,
		Idle = 85857290746761,
	},
	Sounds = {
		Fire = 88766777954581,
	},
	SkinReferenceGun = "BR-40",
	HolsterPart = "Torso",
	HolsterOffset = CFrame.new(0.660148621, -0.020160675, -0.35, 0, 0, -1.00000012, -0.707106829, 0.707106829, 0, 0.707106829, 0.707106829, 0),
}

return Properties
