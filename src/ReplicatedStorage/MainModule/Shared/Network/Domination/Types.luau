--!strict
--!native
--!optimize 2

local SharedTypes = require(script.Parent.Parent.Parent.Types)

export type Owner = "Defenders" | "Hostiles" | nil

export type DominationPointState = {
	Label: string,
	Owner: Owner,
	Progress: number,
	ProgressOwner: Owner,
	Contested: boolean,
}

export type DominationState = {
	Official: boolean,
	Paused: boolean,
	CountingDown: boolean,
	DefenderScore: number,
	HostileScore: number,
	MaxScore: number,
	Points: { DominationPointState },
}

export type AnnouncementType =
	"RAID_STARTING"
	| "RAID_STARTED"
	| "POINT_CAPTURED"
	| "LEAD_TAKEN"
	| "DEFENDERS_WON"
	| "HOSTILES_WON"

export type Announcement = {
	Type: AnnouncementType,
	Message: string,
	Team: Owner,
	Countdown: number?,
}

export type ControlAction =
	"start"
	| "pause"
	| "unpause"
	| "reset"
	| "setMaxScore"
	| "setScores"

export type ControlPayload = {
	action: ControlAction,
	maxScore: number?,
	defenderScore: number?,
	hostileScore: number?,
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

