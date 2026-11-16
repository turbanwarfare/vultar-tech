--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local PhaseConfig = require(MainModule.Shared.Config.PhaseConfig)

type PhaseId = PhaseConfig.PhaseId
type Faction = PhaseConfig.Faction
type PhaseOwner = ("Defenders" | "Raiders")?

export type PathNode = {
	Name: string,
	Position: Vector3,
	Order: number,
}

export type GameState = {
	currentPhase: PhaseId,
	raidTimeRemaining: number,
	termTimeRemaining: number,
	official: boolean,
	countingDown: boolean,
	winner: Faction?,
	overtime: boolean,

	terminalOwner: PhaseOwner,
	captureProgress: number,

	payloadModel: BasePart?,
	payloadAlignPos: AlignPosition?,
	payloadAlignOri: AlignOrientation?,
	payloadProgress: number,
	payloadMaxProgress: number,
	sortedPathNodes: { PathNode },
	nodePositionByName: { [string]: Vector3 },

	conquestActive: boolean,
	conquestNode: string?,
	conquestCaptureProgress: number,
	conquestOwner: PhaseOwner,
	conquestCaptureTeam: PhaseOwner,
	defendersPushbackEnabled: boolean,
	conquestNodeCompleted: string?,
	conquestUpdateTimer: number,
	conquestTimerRestored: boolean,

	waitingForTrainDelivery: boolean,

	spawnCache: { [string]: { SpawnLocation } },
	allPhaseSpawns: { SpawnLocation },
	spectatorSpawns: { SpawnLocation },
	terminalPoints: { [number]: BasePart },
	connections: { any },
	gameLoopThread: thread?,
	heartbeatConnection: RBXScriptConnection?,
}

local GameState = {}

function GameState.new(): GameState
	return {
		currentPhase = "idle",
		raidTimeRemaining = 0,
		termTimeRemaining = 0,
		official = false,
		countingDown = false,
		winner = nil,
		overtime = false,

		terminalOwner = nil,
		captureProgress = 0,

		payloadModel = nil,
		payloadAlignPos = nil,
		payloadAlignOri = nil,
		payloadProgress = 0,
		payloadMaxProgress = 0,
		sortedPathNodes = {},
		nodePositionByName = {},

		conquestActive = false,
		conquestNode = nil,
		conquestCaptureProgress = 0,
		conquestOwner = nil,
		conquestCaptureTeam = nil,
		defendersPushbackEnabled = false,
		conquestNodeCompleted = nil,
		conquestUpdateTimer = 0,
		conquestTimerRestored = false,

		waitingForTrainDelivery = false,

		spawnCache = {},
		allPhaseSpawns = {},
		spectatorSpawns = {},
		terminalPoints = {},
		connections = {},
		gameLoopThread = nil,
		heartbeatConnection = nil,
	}
end

function GameState.reset(state: GameState): ()
	state.currentPhase = "idle"
	state.raidTimeRemaining = 0
	state.termTimeRemaining = 0
	state.official = false
	state.countingDown = false
	state.winner = nil
	state.overtime = false

	state.terminalOwner = nil
	state.captureProgress = 0

	state.payloadModel = nil
	state.payloadAlignPos = nil
	state.payloadAlignOri = nil
	state.payloadProgress = 0
	state.payloadMaxProgress = 0
	table.clear(state.sortedPathNodes)
	table.clear(state.nodePositionByName)

	state.conquestActive = false
	state.conquestNode = nil
	state.conquestCaptureProgress = 0
	state.conquestOwner = nil
	state.conquestCaptureTeam = nil
	state.defendersPushbackEnabled = false
	state.conquestNodeCompleted = nil
	state.conquestUpdateTimer = 0
	state.conquestTimerRestored = false

	state.waitingForTrainDelivery = false

	table.clear(state.spawnCache)
	table.clear(state.allPhaseSpawns)
	table.clear(state.spectatorSpawns)
	table.clear(state.terminalPoints)
	table.clear(state.connections)
	state.gameLoopThread = nil
	state.heartbeatConnection = nil
end

return GameState
