--!strict
--!native
--!optimize 2

local Properties = {
	Mode = "Auto",
	GunImageId = 73568923471331,
	FireRate = 0.1,
	MaxAmmo = 50,
	Range = 1000,
	RechargePerSecond = 20,
	Spread = 0.001,
	BaseDamage = 14,
	HeadDamage = 16,
	Animations = {
		Fire = 96663524793415,
		Sprint = 124471324749864,
		Idle = 96896749029991,
	},
	Sounds = {
		Fire = 86015039407710,
	},
	HolsterPart = "Torso",
	HolsterOffset = CFrame.new(0.660148621, -0.020160675, 0.0894508362, 0, 0, -1.00000012, -0.707106829, 0.707106829, 0, 0.707106829, 0.707106829, 0),
}

return Properties
