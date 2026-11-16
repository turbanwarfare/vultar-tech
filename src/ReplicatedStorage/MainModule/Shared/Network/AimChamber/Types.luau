--!strict
--!native
--!optimize 2

export type AimChamberConfigState = {
	Settings: AimChamberSettings,
	ActivePreset: string,
	Locked: boolean,
}

export type AimChamberSettings = {
	MaxZombies: number,
	ZombieSpeed: number,
	ZombieDamageEnabled: boolean,
	ZombieDamageAmount: number,
	ZombieSpawnRate: number,
	ZombieDodgeInterval: number,
	ZombieCrouchChance: number,
	AssessmentValidation: boolean,
	SelectedGun: string,
	AiDifficulty: string?,
	AiNpcAccuracy: number?,
}

export type AimChamberMatchStartPayload = {
	Settings: AimChamberSettings,
	PresetId: string,
	GunName: string,
}

export type AimChamberMatchTick = {
	ElapsedTime: number,
}

export type AimChamberDeathReason = "Zombie" | "EndOnTouch" | "LeftMidMatch"

export type AimChamberValidationPayload = {
	PlayerName: string,
	UserId: number,
	AvatarUrl: string,
	PresetId: string,
	Settings: AimChamberSettings,
	GunName: string,
	FormattedDateTime: string,
	DeathReason: AimChamberDeathReason,
	ElapsedTime: number,
	ZombieSpawnRate: number,
}

export type AimChamberMatchEndPayload = {
	DeathReason: AimChamberDeathReason,
	ElapsedTime: number,
	ShowAssessmentUI: boolean,
	Validation: AimChamberValidationPayload?,
}

export type AimChamberApplyResult = {
	Success: boolean,
	Error: string?,
}

export type AimChamberNpcShotPayload = {
	origin: Vector3,
	target: Vector3,
	gunName: string?,
}

return {}
