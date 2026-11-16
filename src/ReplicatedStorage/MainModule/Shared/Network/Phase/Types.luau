--!strict
--!native
--!optimize 2

local SharedTypes = require(script.Parent.Parent.Parent.Types)

export type PhaseOwner = "Defenders" | "Raiders" | nil

export type PhaseAnnouncementType =
	"RAID_STARTING"
	| "PHASE_TRANSITION"
	| "PHASE_MESSAGE"
	| "OVERTIME"
	| "DEFENDERS_WON"
	| "RAIDERS_WON"

export type ConquestAction =
	"UpdateCaptureProgress"
	| "CaptureComplete"
	| "RollbackComplete"
	| "StartHold"
	| "UpdateHoldProgress"
	| "EndHold"

export type PhaseState = {
	Phase: number,
	RaidTime: number,
	TermTime: number,
	Official: boolean,
	CountingDown: boolean,
	Owner: PhaseOwner,
	PayloadProgress: number,
	PayloadMax: number,
	Overtime: boolean,
	ConquestActive: boolean,
	CaptureProgress: number,
	CaptureTeam: PhaseOwner,
}

export type PhaseAnnouncement = {
	Type: PhaseAnnouncementType,
	Message: string,
	Countdown: number?,
}

export type ConquestUpdate = {
	Action: ConquestAction,
	Node: string,
	Progress: number,
	Duration: number,
	Team: PhaseOwner,
	Phase: number,
	TimeRemaining: number,
}

export type TrainMovementData = {
	StartPosition: CFrame,
	TargetPosition: CFrame,
	Delay: number,
	TravelTime: number,
}

export type DoorStateData = {
	DoorName: string,
	IsOpen: boolean,
}

export type TopPlayer = SharedTypes.TopPlayer
export type TeamTopPlayers = SharedTypes.TeamTopPlayers
export type VictoryData = SharedTypes.VictoryData

export type PhaseControlAction = "start" | "skipPhase" | "end" | "setTermTime" | "setRaidTime"

export type PhaseControlPayload = {
	action: PhaseControlAction,
	termTime: number?,
	raidTime: number?,
	winner: string?,
}

return {}
