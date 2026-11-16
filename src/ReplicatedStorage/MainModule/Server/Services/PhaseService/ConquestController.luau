--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local PhaseConfig = require(MainModule.Shared.Config.PhaseConfig)
local Network = require(MainModule.Shared.Network)
local PhaseTypes = require(MainModule.Shared.Network.Phase.Types)

type PhaseOwner = PhaseTypes.PhaseOwner

local GameState = require(script.Parent.GameState)
type State = GameState.GameState

local PAYLOAD_HORIZ_RANGE = 9
local PAYLOAD_VERT_RANGE = 7
local CAPTURE_UPDATE_INTERVAL = 0.1
local FACTION_THROTTLE_INTERVAL = 0.1

export type ConquestCallbacks = {
	countFactionsNearPosition: (position: Vector3, horizRange: number, vertRange: number) -> (number, number),
	broadcastMessage: (message: string) -> (),
	broadcastPhaseState: () -> (),
	endGame: (winner: PhaseConfig.Faction) -> (),
	advancePhase: () -> (),
	getPlayersNearPosition: (position: Vector3, range: number) -> { Player },
	getPlayerFaction: (player: Player) -> string?,
	awardCapture: (player: Player) -> (),
}

local ConquestController = {}

local function sendCaptureUpdate(state: State, nodeName: string, phaseNum: number, config: PhaseConfig.PhaseDefinition, team: ("Defenders" | "Raiders")?, progress: number): ()
	Network.Phase.broadcastConquestUi({
		Action = "UpdateCaptureProgress",
		Node = nodeName,
		Progress = progress,
		Duration = config.CaptureTime,
		Team = team,
		Phase = phaseNum,
		TimeRemaining = state.termTimeRemaining,
	})
	state.conquestUpdateTimer = 0
end

local function sendCaptureComplete(state: State, nodeName: string, phaseNum: number, config: PhaseConfig.PhaseDefinition, team: ("Defenders" | "Raiders")?): ()
	Network.Phase.broadcastConquestUi({
		Action = "CaptureComplete",
		Node = nodeName,
		Progress = 1,
		Duration = config.CaptureTime,
		Team = team,
		Phase = phaseNum,
		TimeRemaining = state.termTimeRemaining,
	})
	state.conquestUpdateTimer = 0
end

local conquestFactionTimer: number = FACTION_THROTTLE_INTERVAL
local cachedConquestRaiders: number = 0
local restoredGraceTimer: number = 0
local RESTORED_GRACE_PERIOD = 0.5
local cachedConquestDefenders: number = 0

local function getTerminalDisplayName(config: PhaseConfig.PhaseDefinition): string
	return config.DisplayName:match("- (.+)") or "TERMINAL"
end

function ConquestController.resetConquestState(state: State): ()
	state.conquestActive = false
	state.conquestNode = nil
	state.conquestCaptureProgress = 0
	state.conquestOwner = nil
	state.conquestCaptureTeam = nil
	state.defendersPushbackEnabled = false
	state.conquestNodeCompleted = nil
	state.conquestUpdateTimer = 0
	state.conquestTimerRestored = false
	conquestFactionTimer = FACTION_THROTTLE_INTERVAL
	cachedConquestRaiders = 0
	cachedConquestDefenders = 0
	restoredGraceTimer = 0
end

function ConquestController.beginConquest(state: State, nodeName: string, config: PhaseConfig.PhaseDefinition): ()
	local phaseNum = if state.currentPhase == "phase1" then 1
		elseif state.currentPhase == "phase2" then 2
		elseif state.currentPhase == "phase3" then 3
		else 0

	state.conquestActive = true
	state.conquestNode = nodeName
	state.conquestCaptureProgress = 0
	state.conquestOwner = nil
	state.conquestCaptureTeam = nil
	state.terminalOwner = nil
	state.defendersPushbackEnabled = false
	state.conquestTimerRestored = false
	state.conquestUpdateTimer = CAPTURE_UPDATE_INTERVAL
	conquestFactionTimer = FACTION_THROTTLE_INTERVAL
	cachedConquestRaiders = 0
	cachedConquestDefenders = 0

	Network.Phase.broadcastConquestUi({
		Action = "UpdateCaptureProgress",
		Node = nodeName,
		Progress = 0,
		Duration = config.CaptureTime,
		Team = nil,
		Phase = phaseNum,
		TimeRemaining = state.termTimeRemaining,
	})
end

local function getPhaseNumber(state: State): number
	if state.currentPhase == "phase1" then return 1 end
	if state.currentPhase == "phase2" then return 2 end
	if state.currentPhase == "phase3" then return 3 end
	return 0
end

function ConquestController.updateConquest(
	state: State,
	dt: number,
	config: PhaseConfig.PhaseDefinition,
	nodePosition: Vector3,
	callbacks: ConquestCallbacks
): ()
	if not state.conquestActive then return end

	local phaseNum = getPhaseNumber(state)
	local nodeName = state.conquestNode :: string
	local displayName = getTerminalDisplayName(config)

	conquestFactionTimer += dt
	if conquestFactionTimer >= FACTION_THROTTLE_INTERVAL or state.conquestTimerRestored then
		conquestFactionTimer = 0
		local horizRange = if state.conquestTimerRestored then config.EscortRange or 15 else PAYLOAD_HORIZ_RANGE
		local vertRange = if state.conquestTimerRestored then PAYLOAD_VERT_RANGE + 4 else PAYLOAD_VERT_RANGE
		local termRaiders, termDefenders = callbacks.countFactionsNearPosition(nodePosition, horizRange, vertRange)

		local payloadRaiders, payloadDefenders = 0, 0
		if state.payloadModel then
			payloadRaiders, payloadDefenders = callbacks.countFactionsNearPosition(state.payloadModel.Position, horizRange, vertRange)
		end

		cachedConquestRaiders = math.max(termRaiders, payloadRaiders)
		cachedConquestDefenders = math.max(termDefenders, payloadDefenders)
	end

	local raiders = cachedConquestRaiders
	local defenders = cachedConquestDefenders

	local raidersLead = raiders > defenders
	local defendersLead = defenders > raiders

	state.conquestUpdateTimer += dt
	local shouldSendUpdate = state.conquestUpdateTimer >= CAPTURE_UPDATE_INTERVAL

	local attackingTeam: PhaseOwner = nil
	if raidersLead and state.conquestOwner ~= "Raiders" then
		attackingTeam = "Raiders"
	elseif defendersLead and (state.conquestOwner :: string?) ~= "Defenders" then
		attackingTeam = "Defenders"
	end

	if attackingTeam then
		if state.conquestCaptureTeam and state.conquestCaptureTeam ~= attackingTeam then
			state.conquestCaptureProgress = math.max(state.conquestCaptureProgress - dt, 0)
			if state.conquestCaptureProgress <= 0 then
				state.conquestCaptureTeam = nil
				state.conquestCaptureProgress = 0
			end
			if shouldSendUpdate then
				sendCaptureUpdate(state, nodeName, phaseNum, config, state.conquestCaptureTeam or attackingTeam, state.conquestCaptureProgress / config.CaptureTime)
			end
		else
			state.conquestCaptureTeam = attackingTeam
			state.conquestCaptureProgress = math.min(state.conquestCaptureProgress + dt, config.CaptureTime)

			if state.conquestCaptureProgress >= config.CaptureTime then
				state.conquestOwner = attackingTeam
				state.terminalOwner = attackingTeam
				state.conquestCaptureTeam = nil
				state.conquestCaptureProgress = 0

				local awardRange = PAYLOAD_HORIZ_RANGE
				local awarded: { [Player]: boolean } = {}
				for _, player in callbacks.getPlayersNearPosition(nodePosition, awardRange) do
					if callbacks.getPlayerFaction(player) == attackingTeam and not awarded[player] then
						awarded[player] = true
						callbacks.awardCapture(player)
					end
				end
				if state.payloadModel then
					for _, player in callbacks.getPlayersNearPosition(state.payloadModel.Position, awardRange) do
						if callbacks.getPlayerFaction(player) == attackingTeam and not awarded[player] then
							awarded[player] = true
							callbacks.awardCapture(player)
						end
					end
				end

				if attackingTeam == "Raiders" then
					state.conquestTimerRestored = false
					callbacks.broadcastMessage("HOSTILES HAVE CAPTURED THE " .. displayName .. "!")
				else
					if state.overtime then
						callbacks.broadcastMessage("OVERTIME ENDED! DEFENDERS CAPTURED THE " .. displayName)
						callbacks.endGame("Defenders")
						return
					end
					callbacks.broadcastMessage("DEFENDERS HAVE RECAPTURED THE " .. displayName .. "!")
				end

				sendCaptureComplete(state, nodeName, phaseNum, config, attackingTeam)
				callbacks.broadcastPhaseState()
			elseif shouldSendUpdate then
				sendCaptureUpdate(state, nodeName, phaseNum, config, attackingTeam, state.conquestCaptureProgress / config.CaptureTime)
			end
		end
	elseif (raiders > 0 or defenders > 0) and state.conquestCaptureProgress > 0 then
		state.conquestCaptureProgress = math.max(state.conquestCaptureProgress - dt, 0)
		state.conquestCaptureTeam = if state.conquestCaptureProgress <= 0 then nil else state.conquestCaptureTeam
		local displayTeam = state.conquestCaptureTeam or (if state.conquestOwner == "Raiders" then "Defenders" else "Raiders")
		if state.conquestCaptureProgress <= 0 then
			sendCaptureUpdate(state, nodeName, phaseNum, config, displayTeam, 0)
		elseif shouldSendUpdate then
			sendCaptureUpdate(state, nodeName, phaseNum, config, displayTeam, state.conquestCaptureProgress / config.CaptureTime)
		end
	end

	if state.conquestCaptureProgress > 0 then return end

	if state.conquestOwner == "Raiders" then
		state.termTimeRemaining = math.max(state.termTimeRemaining - dt, 0)
		if state.termTimeRemaining <= 0 then
			state.conquestActive = false
			callbacks.broadcastMessage("HOSTILES CONQUERED THE " .. displayName .. "!")
			callbacks.advancePhase()
			return
		end
	elseif state.conquestOwner == "Defenders" then
		if state.overtime then
			callbacks.broadcastMessage("OVERTIME ENDED! DEFENDERS HOLD THE " .. displayName)
			callbacks.endGame("Defenders")
			return
		end

		state.termTimeRemaining = math.min(state.termTimeRemaining + dt * config.RollbackRate, config.TermTime)

		if state.termTimeRemaining >= config.TermTime and not state.conquestTimerRestored then
			state.conquestTimerRestored = true
			restoredGraceTimer = RESTORED_GRACE_PERIOD
			cachedConquestRaiders = 0
			cachedConquestDefenders = 0
			conquestFactionTimer = FACTION_THROTTLE_INTERVAL
			callbacks.broadcastMessage("DEFENDERS FULLY RESTORED TIME AT THE " .. displayName .. "!")
			state.terminalOwner = "Defenders"
			sendCaptureComplete(state, nodeName, phaseNum, config, "Defenders")
			callbacks.broadcastPhaseState()
			return
		end

		if state.conquestTimerRestored then
			if restoredGraceTimer > 0 then
				restoredGraceTimer -= dt
				return
			end
			if defenders > 0 or raiders > 0 then
				state.conquestActive = false
				state.conquestOwner = nil
				state.conquestCaptureTeam = nil
				state.conquestCaptureProgress = 0
				state.defendersPushbackEnabled = defenders > 0
				state.terminalOwner = "Defenders"
				cachedConquestRaiders = 0
				cachedConquestDefenders = 0
				callbacks.broadcastPhaseState()
				return
			end
		end
	end
end

return ConquestController
