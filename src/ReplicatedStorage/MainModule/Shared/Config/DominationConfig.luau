--!strict
--!native
--!optimize 2

export type DominationConfig = {
	PointCount: number,
	CaptureTimeSeconds: number,
	SpeedBonusPerPlayer: number,
	SpeedBonusMaxPlayers: number,
	DeathCapEnabled: boolean,
	MaxScore: number,
}

local DominationConfig = {}

DominationConfig.DEFAULT = {
	PointCount = 2,
	CaptureTimeSeconds = 5,
	SpeedBonusPerPlayer = 0.5,
	SpeedBonusMaxPlayers = 3,
	DeathCapEnabled = false,
	MaxScore = 1000,
} :: DominationConfig

local LABEL_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

function DominationConfig.getLabel(index: number): string
	local clamped = math.clamp(index, 1, 26)
	return string.sub(LABEL_CHARS, clamped, clamped)
end

function DominationConfig.captureSpeed(aliveCount: number, config: DominationConfig): number
	if aliveCount <= 0 then
		return 0
	end
	local effective = math.min(aliveCount, config.SpeedBonusMaxPlayers)
	return 1 + (effective - 1) * config.SpeedBonusPerPlayer
end

return DominationConfig

