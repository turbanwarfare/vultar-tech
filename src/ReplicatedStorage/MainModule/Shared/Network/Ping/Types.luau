--!strict
--!native
--!optimize 2

export type HighlightTarget = {
	userId: number,
	characterName: string,
}

export type PingData = {
	position: Vector3,
	senderName: string,
	isSpecial: boolean,
	targets: { HighlightTarget },
}

return nil
