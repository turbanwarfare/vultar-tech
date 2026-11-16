--!strict
--!native
--!optimize 2

export type HitLogEntry = {
	attackerId: number,
	bodyPart: number,
	localX: number,
	localY: number,
	localZ: number,
	damage: number,
	gunIndex: number,
	headshot: boolean,
}

export type OutgoingHitEntry = {
	targetId: number,
	damage: number,
	gunIndex: number,
	headshot: boolean,
}

export type KillLogData = {
	hitLog: { HitLogEntry }?,
	outgoingLog: { OutgoingHitEntry }?,
}

export type DeathData = {
	killerUserId: number,
	killerName: string,
	gunName: string,
	range: number,
	killerHealth: number,
	playerCardImage: string?,
	isAnimatedCard: boolean?,
	wasReset: boolean,
	hasKillLog: boolean,
}

return nil
