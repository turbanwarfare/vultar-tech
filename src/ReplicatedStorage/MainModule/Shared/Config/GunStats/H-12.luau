--!strict
--!native
--!optimize 2

local Properties = {
	Mode = "Semi",
	GunImageId = 102998024319858,
	FireRate = 0.18,
	MaxAmmo = 12,
	Range = 600,
	RechargePerSecond = 8,
	Spread = 0,
	BaseDamage = 12,
	HeadDamage = 19,
	Animations = {
		Fire = 122234633656173,
		Sprint = 78826606733782,
		Idle = 76224662017576,
	},
	Sounds = {
		Fire = 88766777954581,
	},
	HolsterPart = "Right Leg",
	HolsterOffset = CFrame.new(-0.6, 0, -0.9, 1, 0, 0, 0, 0, -1, 0, 1, 0),
}

return Properties
