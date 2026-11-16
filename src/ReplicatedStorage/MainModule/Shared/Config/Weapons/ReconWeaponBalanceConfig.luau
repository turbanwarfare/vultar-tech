--!strict
--!native
--!optimize 2

export type ReconWeaponBalanceConfigType = {
	BaseBoltCycleTime: number,
	MaxSwitchLockoutPenalty: number,
	SoftFrictionPenaltyIncrease: number,
	MinLockoutCharge: number,
	MaxLockoutCharge: number,
	ReconPairings: { [string]: string },
	ReconPistolToRifle: { [string]: string },
}

local ReconWeaponBalanceConfig: ReconWeaponBalanceConfigType = {
	BaseBoltCycleTime = 0.25,
	MaxSwitchLockoutPenalty = 3.20,
	SoftFrictionPenaltyIncrease = 0.40,
	MinLockoutCharge = 0.01,
	MaxLockoutCharge = 0.99,
	ReconPairings = {
		["BR-50"] = "BR-8",
		["H-50"] = "H-12",
	},
	ReconPistolToRifle = {
		["BR-8"] = "BR-50",
		["H-12"] = "H-50",
	},
}

return ReconWeaponBalanceConfig
