--!strict
--!native
--!optimize 2

local SharedTypes = require(script.Parent.Parent.Parent.Types)

export type Owner = "Defenders" | "Hostiles" | nil

export type HardpointState = {
	Official: boolean,
	Paused: boolean,
	CountingDown: boolean,
	DefenderScore: number,
	HostileScore: number,
	MaxPoints: number,
	CurrentPoint: number,
	CurrentPointName: string?,
	Owner: Owner,
	TimeToRotate: number,
	RotationTimeMin: number,
	RotationTimeMax: number,
}

export type ControlAction = "start" | "pause" | "unpause" | "reset" | "setMaxPoints" | "setRotationRange" | "setScores"

export type ControlPayload = {
	action: ControlAction,
	maxPoints: number?,
	rotationMin: number?,
	rotationMax: number?,
	defenderScore: number?,
	hostileScore: number?,
}

export type AnnouncementType =
	"RAID_STARTING"
	| "RAID_STARTED"
	| "TERMINAL_CAPTURED"
	| "LEAD_TAKEN"
	| "ROTATION_WARNING"
	| "TERMINAL_ROTATED"
	| "DEFENDERS_WON"
	| "HOSTILES_WON"

export type Announcement = {
	Type: AnnouncementType,
	Message: string,
	Team: Owner,
	Countdown: number?,
}

export type TerminalPermissions = {
	HasAccess: boolean,
	IsPrivateServer: boolean,
	IsOwner: boolean,
}

export type TopPlayer = SharedTypes.TopPlayer
export type TeamTopPlayers = SharedTypes.TeamTopPlayers
export type VictoryData = SharedTypes.VictoryData

return {}
