--!strict
--!native
--!optimize 2

export type NetworkHitData = {
	targetId: number,
	damage: number,
	head: boolean,
	pos: Vector3,
}

export type ReplicateData = {
	origin: Vector3,
	target: Vector3,
	gunIndex: number,
	shooterId: number?,
}

export type KillData = {
	killer: number,
	victim: number,
	headshot: boolean,
	weapon: number,
	killerHealth: number,
}

return nil
