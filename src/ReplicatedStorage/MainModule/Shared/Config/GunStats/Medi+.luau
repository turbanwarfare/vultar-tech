--!strict
--!native
--!optimize 2

local Properties = {
	Mode = "Medi",
	GunImageId = 0,
	FireRate = 0.12,
	MaxAmmo = 100,
	Range = 20,
	RechargePerSecond = 1 / 1.5,
	Spread = 0,
	BaseDamage = 0,
	HeadDamage = 0,
	HealAmount = 3,
	Animations = {
		Sprint = 117462778726792,
		Idle = 91636304203179,
	},
	HolsterPart = "Right Leg",
	HolsterOffset = CFrame.new(1.61, 0, -0.9, 1, 0, 0, 0, 0, -1, 0, 1, 0),
}

return Properties
