--!strict
--!native
--!optimize 2

export type MouseBehaviorMode = "Default" | "LockCenter" | "LockCurrentPosition"

export type GhostEntry = {
	characterId: number,
	cframe: CFrame,
}

export type CameraPayload = {
	cframe: CFrame,
	fov: number,
	viewportSize: { X: number, Y: number } | Vector2,
	mouseHit: Vector3,
	timestamp: number,
	mouseBehavior: MouseBehaviorMode,
	isSprinting: boolean?,
	isCrouching: boolean?,
	ping: number?,
	avgPing: number?,
	pingSpikes: number?,
	matchAccuracy: number?,
}

export type CursorPayload = {
	position: { X: number, Y: number },
	timestamp: number,
	icon: string?,
}

export type GhostPayload = {
	ghosts: { GhostEntry },
	timestamp: number,
}

export type InputPayload = {
	inputName: string,
	isDown: boolean,
	timestamp: number,
}

export type KeyHistoryPayload = {
	keyName: string,
	isFlagged: boolean,
	isDown: boolean,
	timestamp: number,
	isFocusEvent: boolean?,
	isSettingsEvent: boolean?,
}

export type HitPayload = {
	targetUserId: number,
	victimId: number,
	victimName: string,
	damage: number,
	bodyPart: string,
	isHeadshot: boolean,
	weaponName: string,
	timestamp: number,
	hitOffset: Vector3?,
	targetTime: number?,
}

export type PreBufferChunk = {
	cameras: { CameraPayload },
	cursors: { CursorPayload },
	ghosts: { GhostPayload },
}

export type ConfigPayload = {
	cameraSampleHz: number,
	cursorSampleHz: number,
	ghostSampleHz: number,
	ghostRenderDistance: number,
	ghostMaxCount: number,
}

export type StateSyncPayload = {
	targetUserId: number,
	isWatching: boolean,
	targetName: string?,
}

return {}
