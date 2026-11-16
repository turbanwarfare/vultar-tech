--!strict
--!native
--!optimize 2

export type HitData = {
	target: Humanoid,
	damage: number,
	head: boolean,
	pos: Vector3,
	normal: Vector3,
}

export type NetworkHitData = {
	targetId: number,
	damage: number,
	head: boolean,
	pos: Vector3,
}

export type ShotData = {
	origin: Vector3,
	target: Vector3,
	hit: HitData?,
	gunName: string,
}

return nil
