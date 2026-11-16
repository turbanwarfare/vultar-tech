--!strict
--!native
--!optimize 2

export type HalloweenCosmetics = {
	gunSkin: boolean?,
	leaderboardCard: boolean?,
}

export type EventCosmeticData = {
	halloween: HalloweenCosmetics?,
}

export type FacilityBanData = {
	isBanned: boolean,
	reason: string?,
	expires: string?,
}

export type RecordingPolicyData = {
	onRecordingPolicy: boolean,
}

export type UserGameState = {
	facilityBan: FacilityBanData?,
	recordingPolicy: RecordingPolicyData?,
}

return nil
