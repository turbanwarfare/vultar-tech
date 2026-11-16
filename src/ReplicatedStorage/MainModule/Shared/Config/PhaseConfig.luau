--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local SharedTypes = require(MainModule.Shared.Types)

export type PhaseId = "idle" | "phase1" | "phase2" | "phase3" | "ended"
export type Faction = SharedTypes.Faction

export type PhaseDefinition = {
	DisplayName: string,
	SpawnFolder: string,
	TermTime: number,
	CaptureTime: number,
	RollbackRate: number,
	TimeGift: number,
	HasPayload: boolean,
	HasTerminal: boolean,
	PayloadSpeed: number?,
	EscortRange: number?,
	PayloadStartNode: string?,
	PayloadEndNode: string?,
}

local PhaseConfig = {}

PhaseConfig.PHASE_ORDER = { "phase1", "phase2", "phase3" } :: { PhaseId }

PhaseConfig.INITIAL_RAID_TIME = 1800
PhaseConfig.COUNTDOWN_TIME = 10

PhaseConfig.PHASES = {
	phase1 = {
		DisplayName = "PHASE 1 - ENERGY FACILITY",
		SpawnFolder = "Phase 1",
		TermTime = 360,
		CaptureTime = 4,
		RollbackRate = 2,
		TimeGift = 900,
		HasPayload = false,
		HasTerminal = true,
	},
	phase2 = {
		DisplayName = "PHASE 2 - COMMUNICATIONS SATELLITE",
		SpawnFolder = "Phase 2",
		TermTime = 420,
		CaptureTime = 4,
		RollbackRate = 3,
		TimeGift = 900,
		HasPayload = true,
		HasTerminal = true,
		PayloadSpeed = 7,
		EscortRange = 15,
		PayloadStartNode = "Node1",
		PayloadEndNode = "TermNode1",
	},
	phase3 = {
		DisplayName = "PHASE 3 - CANNON REACTOR",
		SpawnFolder = "Phase 3",
		TermTime = 600,
		CaptureTime = 4,
		RollbackRate = 3,
		TimeGift = 900,
		HasPayload = true,
		HasTerminal = true,
		PayloadSpeed = 7,
		EscortRange = 15,
		PayloadStartNode = "TermNode1",
		PayloadEndNode = "TermNode2",
	},
}

local phaseIndexMap: { [PhaseId]: number } = {}
for i, phaseId: PhaseId in PhaseConfig.PHASE_ORDER do
	phaseIndexMap[phaseId] = i
end

function PhaseConfig.getPhase(phaseId: PhaseId): PhaseDefinition?
	return PhaseConfig.PHASES[phaseId]
end

function PhaseConfig.getNextPhase(phaseId: PhaseId): PhaseId?
	local index = phaseIndexMap[phaseId]
	if not index then
		return nil
	end

	local nextIndex = index + 1
	if nextIndex > #PhaseConfig.PHASE_ORDER then
		return nil
	end

	return PhaseConfig.PHASE_ORDER[nextIndex] :: PhaseId
end

function PhaseConfig.getSpawnFolder(phaseId: PhaseId): string?
	local phase = PhaseConfig.PHASES[phaseId]
	if not phase then
		return nil
	end
	return phase.SpawnFolder
end

function PhaseConfig.isValidPhase(phaseId: PhaseId): boolean
	return phaseIndexMap[phaseId] ~= nil
end

return PhaseConfig
