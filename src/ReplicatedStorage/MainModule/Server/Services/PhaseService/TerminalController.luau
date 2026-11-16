--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent.Parent
local PhaseConfig = require(MainModule.Shared.Config.PhaseConfig)
local Network = require(MainModule.Shared.Network)
local PhaseTypes = require(MainModule.Shared.Network.Phase.Types)

type PhaseOwner = PhaseTypes.PhaseOwner

local GameState = require(script.Parent.GameState)
type State = GameState.GameState

local TERMINAL_HORIZ_RANGE = 15
local TERMINAL_VERT_RANGE = 10
local TERMINAL_MIN_VERT_RANGE = -2

export type TerminalCallbacks = {
	countFactionsNearPosition: (position: Vector3, horizRange: number, vertRange: number, minVertRange: number?) -> (number, number),
	getPlayersNearPosition: (position: Vector3, range: number, vertRange: number?, minVertRange: number?) -> { Player },
	getPlayerFaction: (player: Player) -> string?,
	awardCapture: (player: Player) -> (),
	broadcastMessage: (message: string) -> (),
	broadcastPhaseState: () -> (),
	endGame: (winner: PhaseConfig.Faction) -> (),
	advancePhase: () -> (),
	stopHeartbeat: () -> (),
}

local TerminalController = {}

function TerminalController.cacheTerminalPoints(state: State): ()
	local folder = workspace:FindFirstChild("TerminalPoints")
	if not folder then
		return
	end

	for _, pt in folder:GetChildren() do
		local num = tonumber(pt.Name)
		if num and pt:IsA("BasePart") then
			state.terminalPoints[num] = pt
		end
	end
end

function TerminalController.beginTerminalCapture(state: State, callbacks: TerminalCallbacks): ()
	local config = PhaseConfig.getPhase(state.currentPhase)
	if not config or not config.HasTerminal then
		return
	end

	local phaseNum = if state.currentPhase == "phase1" then 1 elseif state.currentPhase == "phase2" then 2 elseif state.currentPhase == "phase3" then 3 else 0

	local termPoint = state.terminalPoints[1]
	if not termPoint then
		return
	end

	local displayName = config.DisplayName:match("- (.+)") or "TERMINAL"

	state.termTimeRemaining = config.TermTime
	state.captureProgress = 0
	state.terminalOwner = "Defenders"
	state.overtime = false

	local horizRange = TERMINAL_HORIZ_RANGE
	local vertRange = TERMINAL_VERT_RANGE
	local raidersTouched = false

	local CAPTURE_UPDATE_INTERVAL = 0.1
	local captureUpdateTimer = CAPTURE_UPDATE_INTERVAL

	local FACTION_THROTTLE_INTERVAL = 0.1
	local factionTimer = FACTION_THROTTLE_INTERVAL
	local cachedRaiders, cachedDefenders = 0, 0

	local function sendCaptureUpdate(team: ("Defenders" | "Raiders")?, progress: number): ()
		Network.Phase.broadcastConquestUi({
			Action = "UpdateCaptureProgress",
			Node = tostring(phaseNum),
			Progress = progress,
			Duration = config.CaptureTime,
			Team = team,
			Phase = phaseNum,
			TimeRemaining = state.termTimeRemaining,
		})
	end

	local function sendCaptureComplete(team: ("Defenders" | "Raiders")?): ()
		Network.Phase.broadcastConquestUi({
			Action = "CaptureComplete",
			Node = tostring(phaseNum),
			Progress = 1,
			Duration = config.CaptureTime,
			Team = team,
			Phase = phaseNum,
			TimeRemaining = state.termTimeRemaining,
		})
	end

	callbacks.stopHeartbeat()
	state.heartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
		debug.profilebegin("TerminalController::heartbeat")
		if not state.official or state.currentPhase == "idle" or state.currentPhase == "ended" then
			debug.profileend()
			return
		end
		if config.HasPayload then
			debug.profileend()
			return
		end

		factionTimer += dt
		if factionTimer >= FACTION_THROTTLE_INTERVAL then
			factionTimer = 0
			cachedRaiders, cachedDefenders = callbacks.countFactionsNearPosition(termPoint.Position, horizRange, vertRange, TERMINAL_MIN_VERT_RANGE)
		end
		local raiders, defenders = cachedRaiders, cachedDefenders

		if raiders > 0 then
			raidersTouched = true
		end

		local defenderPower = if raidersTouched then defenders else 0
		local raidersOnly = raiders > 0 and defenderPower == 0
		local defendersOnly = defenderPower > 0 and raiders == 0

		captureUpdateTimer += dt
		local shouldSendUpdate = captureUpdateTimer >= CAPTURE_UPDATE_INTERVAL

		if raidersOnly and state.terminalOwner ~= "Raiders" then
			state.conquestCaptureTeam = "Raiders"
			state.captureProgress = math.min(state.captureProgress + dt, config.CaptureTime)
			if state.captureProgress >= config.CaptureTime then
				state.terminalOwner = "Raiders"
				state.captureProgress = 0
				state.conquestCaptureTeam = nil
				callbacks.broadcastMessage("HOSTILES HAVE CAPTURED THE " .. displayName .. "!")

				for _, player in callbacks.getPlayersNearPosition(termPoint.Position, horizRange, vertRange, TERMINAL_MIN_VERT_RANGE) do
					if callbacks.getPlayerFaction(player) == "Raiders" then
						callbacks.awardCapture(player)
					end
				end

				sendCaptureComplete("Raiders")
				callbacks.broadcastPhaseState()
				captureUpdateTimer = 0
			elseif shouldSendUpdate then
				sendCaptureUpdate("Raiders", state.captureProgress / config.CaptureTime)
				captureUpdateTimer = 0
			end
		elseif defendersOnly and (state.terminalOwner :: string?) ~= "Defenders" then
			state.conquestCaptureTeam = nil
			state.captureProgress = math.min(state.captureProgress + dt, config.CaptureTime)
			if state.captureProgress >= config.CaptureTime then
				state.terminalOwner = "Defenders"
				state.captureProgress = 0

				for _, player in callbacks.getPlayersNearPosition(termPoint.Position, horizRange, vertRange, TERMINAL_MIN_VERT_RANGE) do
					if callbacks.getPlayerFaction(player) == "Defenders" then
						callbacks.awardCapture(player)
					end
				end

				if state.overtime then
					callbacks.broadcastMessage("OVERTIME ENDED! DEFENDERS CAPTURED THE " .. displayName)
					callbacks.endGame("Defenders")
					return
				end

				callbacks.broadcastMessage("DEFENDERS HAVE RECAPTURED THE " .. displayName .. "!")

				sendCaptureComplete("Defenders")
				callbacks.broadcastPhaseState()
				captureUpdateTimer = 0
			elseif shouldSendUpdate then
				sendCaptureUpdate("Defenders", state.captureProgress / config.CaptureTime)
				captureUpdateTimer = 0
			end
		elseif (raidersOnly or defendersOnly) and state.captureProgress > 0 then
			state.conquestCaptureTeam = nil
			state.captureProgress = math.max(state.captureProgress - dt, 0)
			local attackingTeam: PhaseOwner = if state.terminalOwner == "Raiders" then "Defenders" else "Raiders"
			if state.captureProgress <= 0 then
				sendCaptureUpdate(attackingTeam, 0)
				captureUpdateTimer = 0
			elseif shouldSendUpdate then
				sendCaptureUpdate(attackingTeam, state.captureProgress / config.CaptureTime)
				captureUpdateTimer = 0
			end
		else
			if state.overtime and state.captureProgress > 0 then
				state.captureProgress = math.max(state.captureProgress - dt, 0)
				if shouldSendUpdate then
					local decayTeam: PhaseOwner = if state.terminalOwner == "Raiders" then "Defenders" else "Raiders"
					sendCaptureUpdate(decayTeam, state.captureProgress / config.CaptureTime)
					captureUpdateTimer = 0
				end
			end
			state.conquestCaptureTeam = nil
		end

		if state.captureProgress <= 0 then
			if state.terminalOwner == "Raiders" then
				state.termTimeRemaining = math.max(state.termTimeRemaining - dt, 0)
				if state.termTimeRemaining <= 0 then
					debug.profileend()
					callbacks.advancePhase()
					return
				end
			elseif state.terminalOwner == "Defenders" then
				if not state.overtime then
					state.termTimeRemaining = math.min(state.termTimeRemaining + dt * config.RollbackRate, config.TermTime)
				end
			end
		end
		debug.profileend()
	end)
end

return TerminalController
