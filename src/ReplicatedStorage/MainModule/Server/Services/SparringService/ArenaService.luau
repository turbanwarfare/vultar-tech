--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local MainModule = script.Parent.Parent.Parent.Parent
local SparConfig = require(MainModule.Shared.Config.SparConfig)
local Signal = require(MainModule.Shared.Utils.State.Signal)
local Network = require(MainModule.Shared.Network)
local sparringServiceFolder = script.Parent

export type ArenaSelections = {
	map: string,
	gun: string,
	health: string,
	rounds: string,
	showVersusGUI: boolean,
	instantRespawn: boolean,
	forcefield: string,
	leftPlayer: Player?,
	rightPlayer: Player?,
}

export type ArenaState = {
	selections: ArenaSelections,
	inMatch: boolean,
	countdownActive: boolean,
	countdownValue: number,
	leftPad: BasePart,
	rightPad: BasePart,
}

local ArenaService = {}

local arenaStates: { [number]: ArenaState } = {}
local activeArenas: { [number]: boolean } = {}
local playerPadStatus: { [Player]: { [number]: boolean } } = {}
local selectionChanged = Signal.new()
local countdownTick = Signal.new()
local padCheckConnection: RBXScriptConnection? = nil

local function buildValueLookup(values: { string }): { [string]: boolean }
	local lookup: { [string]: boolean } = {}
	for _, entry in values do
		lookup[entry] = true
	end
	return lookup
end

local VALID_MAP_VALUES = buildValueLookup(SparConfig.MAP_NAMES)
local VALID_GUN_VALUES = buildValueLookup(SparConfig.GUN_NAMES)
local VALID_FORCEFIELD_VALUES = buildValueLookup(SparConfig.FORCEFIELD_OPTIONS)

local function sanitizeCount(text: string, maxValue: number): string?
	local count = tonumber(text)
	if not count or count ~= math.floor(count) or count < 1 or count > maxValue then
		return nil
	end
	return tostring(count)
end

function ArenaService.sanitizeSelectionValue(optionType: string, value: unknown): string?
	if type(value) ~= "string" then
		return nil
	end
	local text: string = value

	if optionType == "map" or optionType == "maps" then
		return if VALID_MAP_VALUES[text] then text else nil
	elseif optionType == "gun" or optionType == "guns" then
		return if VALID_GUN_VALUES[text] then text else nil
	elseif optionType == "forcefield" then
		return if VALID_FORCEFIELD_VALUES[text] then text else nil
	elseif optionType == "health" then
		return sanitizeCount(text, SparConfig.MAX_CUSTOM_HEALTH)
	elseif optionType == "rounds" then
		return sanitizeCount(text, SparConfig.MAX_CUSTOM_ROUNDS)
	end

	return nil
end

local ArenaMatchService: any = nil

function ArenaService.setArenaMatchService(service: any)
	ArenaMatchService = service
end

local function defaultSelections(): ArenaSelections
	return {
		map = SparConfig.DEFAULT_MAP,
		gun = SparConfig.DEFAULT_GUN,
		health = SparConfig.DEFAULT_HEALTH,
		rounds = SparConfig.DEFAULT_ROUNDS,
		showVersusGUI = SparConfig.DEFAULT_VERSUS,
		instantRespawn = false,
		forcefield = SparConfig.DEFAULT_FORCEFIELD_DURATION,
		leftPlayer = nil,
		rightPlayer = nil,
	}
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	playerPadStatus[player] = nil
end)

function ArenaService.setupArena(arenaModel: Model, arenaNumber: number)
	local decor = arenaModel:WaitForChild("Decor", 5) :: Model
	if not decor then
		return
	end

	local leftPlayerModel = decor:FindFirstChild("LeftPlayer") :: Model?
	local rightPlayerModel = decor:FindFirstChild("RightPlayer") :: Model?

	local leftPad = leftPlayerModel and leftPlayerModel:FindFirstChild("Detection") :: BasePart
	local rightPad = rightPlayerModel and rightPlayerModel:FindFirstChild("Detection") :: BasePart

	if not (leftPad and rightPad) then
		warn("[ArenaService] Missing pad models in arena", arenaNumber)
		return
	end

	arenaStates[arenaNumber] = {
		selections = defaultSelections(),
		inMatch = false,
		countdownActive = false,
		countdownValue = SparConfig.COUNTDOWN_DURATION,
		leftPad = leftPad,
		rightPad = rightPad,
	}

	leftPad.BrickColor = BrickColor.new("Bright red")
	rightPad.BrickColor = BrickColor.new("Bright red")
end

function ArenaService.setPlayerPadStatus(player: Player, arenaNumber: number, isOnPad: boolean)
	playerPadStatus[player] = playerPadStatus[player] or {}
	playerPadStatus[player][arenaNumber] = isOnPad
	Network.Spar.firePadStatus(player, arenaNumber, isOnPad)

	if not isOnPad then
		local state = arenaStates[arenaNumber]
		if state and state.countdownActive then
			if state.selections.leftPlayer == player or state.selections.rightPlayer == player then
				ArenaService.cancelCountdown(arenaNumber)
			end
		end
	end

	task.spawn(function()
		local success, lobbyService = pcall(require, sparringServiceFolder:FindFirstChild("ArenaLobbyService"))
		if success and lobbyService and lobbyService.queueBroadcast then
			lobbyService.queueBroadcast()
		end
	end)
end

function ArenaService.isPlayerOnPad(player: Player, arenaNumber: number): boolean
	local status = playerPadStatus[player]
	return status and status[arenaNumber] == true
end

function ArenaService.getSelections(arenaNumber: number): ArenaSelections?
	local state = arenaStates[arenaNumber]
	return state and state.selections or nil
end

function ArenaService.handleSelectOption(player: Player, arenaNumber: number, optionType: string, value: string)
	local state = arenaStates[arenaNumber]
	if not state or state.inMatch then
		return
	end

	local validTypes = { map = true, gun = true, health = true, rounds = true, maps = true, guns = true, forcefield = true }
	if not validTypes[optionType] then
		return
	end

	if optionType == "maps" then
		optionType = "map"
	end
	if optionType == "guns" then
		optionType = "gun"
	end

	local sanitized = ArenaService.sanitizeSelectionValue(optionType, value)
	if not sanitized then
		return
	end

	(state.selections :: any)[optionType] = sanitized

	if state.countdownActive then
		local reason = player.Name .. " suddenly changed " .. optionType .. " to " .. sanitized .. ", countdown was cancelled"
		ArenaService.cancelCountdown(arenaNumber, reason)
	end

	selectionChanged:Fire(arenaNumber, player, optionType, sanitized)
	Network.Spar.broadcastArenaStatus(
		arenaNumber,
		"selectionChanged",
		HttpService:JSONEncode({
			type = optionType,
			value = sanitized,
			playerName = player.Name,
		})
	)
end

function ArenaService.handleToggleSetting(player: Player, arenaNumber: number, settingName: string)
	local state = arenaStates[arenaNumber]
	if not state or state.inMatch then
		return
	end

	local wasCountingDown = state.countdownActive

	if settingName == "showVersusGUI" then
		state.selections.showVersusGUI = not state.selections.showVersusGUI
		if wasCountingDown then
			local reason = player.Name .. " suddenly toggled " .. settingName .. ", countdown was cancelled"
			ArenaService.cancelCountdown(arenaNumber, reason)
		end
		selectionChanged:Fire(arenaNumber, player, settingName, state.selections.showVersusGUI)
		Network.Spar.broadcastArenaStatus(
			arenaNumber,
			"selectionChanged",
			HttpService:JSONEncode({
				type = settingName,
				value = state.selections.showVersusGUI,
				playerName = player.Name,
			})
		)
	elseif settingName == "instantRespawn" then
		local newVal = not state.selections.instantRespawn
		if newVal and (tonumber(state.selections.rounds) or 1) <= 1 then
			return
		end
		state.selections.instantRespawn = newVal
		if wasCountingDown then
			local reason = player.Name .. " suddenly toggled " .. settingName .. ", countdown was cancelled"
			ArenaService.cancelCountdown(arenaNumber, reason)
		end
		selectionChanged:Fire(arenaNumber, player, settingName, state.selections.instantRespawn)
		Network.Spar.broadcastArenaStatus(
			arenaNumber,
			"selectionChanged",
			HttpService:JSONEncode({
				type = settingName,
				value = state.selections.instantRespawn,
				playerName = player.Name,
			})
		)
	end
end

function ArenaService.canStartMatch(arenaNumber: number, player: Player): boolean
	local state = arenaStates[arenaNumber]
	if not state then
		return false
	end
	if activeArenas[arenaNumber] then
		return false
	end
	if state.countdownActive then
		return false
	end
	return ArenaService.isPlayerOnPad(player, arenaNumber)
end

function ArenaService.applySelectionsFromStart(
	_player: Player,
	arenaNumber: number,
	map: string,
	gun: string,
	health: string,
	rounds: string,
	showVersusGUI: boolean,
	instantRespawn: boolean,
	forcefield: string?
)
	local state = arenaStates[arenaNumber]
	if not state then
		warn("[ArenaService] applySelectionsFromStart: no state for arena", arenaNumber)
		return
	end

	local sanitizedMap = ArenaService.sanitizeSelectionValue("map", map)
	local sanitizedGun = ArenaService.sanitizeSelectionValue("gun", gun)
	local sanitizedHealth = ArenaService.sanitizeSelectionValue("health", health)
	local sanitizedRounds = ArenaService.sanitizeSelectionValue("rounds", rounds)
	if not sanitizedMap or not sanitizedGun or not sanitizedHealth or not sanitizedRounds then
		warn("[ArenaService] applySelectionsFromStart: rejected selections for arena", arenaNumber)
		return
	end

	state.selections.map = sanitizedMap
	state.selections.gun = sanitizedGun
	state.selections.health = sanitizedHealth
	state.selections.rounds = sanitizedRounds
	state.selections.showVersusGUI = showVersusGUI == true
	state.selections.instantRespawn = (tonumber(sanitizedRounds) or 1) > 1 and instantRespawn == true
	if forcefield then
		local sanitizedForcefield = ArenaService.sanitizeSelectionValue("forcefield", forcefield)
		if sanitizedForcefield then
			state.selections.forcefield = sanitizedForcefield
		end
	end
end

function ArenaService.cancelCountdown(arenaNumber: number, reason: string?)
	local state = arenaStates[arenaNumber]
	if not state or not state.countdownActive then
		return
	end
	state.countdownActive = false
	state.countdownValue = SparConfig.COUNTDOWN_DURATION
	
	local payload = {}
	if reason then
		payload.reason = reason
	end
	Network.Spar.broadcastArenaStatus(arenaNumber, "countdownCancel", HttpService:JSONEncode(payload))
end

function ArenaService.handleStartMatch(player: Player, arenaNumber: number, isSoloRequested: boolean?)
	if not ArenaMatchService then
		warn("[ArenaService] ArenaMatchService not injected")
		return
	end

	local state = arenaStates[arenaNumber]
	if not state then
		return
	end

	if activeArenas[arenaNumber] then
		return
	end

	if state.countdownActive then
		if state.selections.leftPlayer == player or state.selections.rightPlayer == player then
			ArenaService.cancelCountdown(arenaNumber)
		end
		return
	end

	if not ArenaService.isPlayerOnPad(player, arenaNumber) then
		return
	end

	local leftPlayer: Player? = nil
	local rightPlayer: Player? = nil

	local leftPad = state.leftPad
	local rightPad = state.rightPad

	for _, p in ipairs(game.Players:GetPlayers()) do
		local character = p.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local deltaL = hrp.Position - leftPad.Position
			local deltaR = hrp.Position - rightPad.Position
			if deltaL:Dot(deltaL) <= SparConfig.PAD_DISTANCE_THRESHOLD_SQ then
				leftPlayer = p
			elseif deltaR:Dot(deltaR) <= SparConfig.PAD_DISTANCE_THRESHOLD_SQ then
				rightPlayer = p
			end
		end
	end

	local isSolo = (isSoloRequested == true) and (RunService:IsStudio() or SparConfig.ALLOW_SOLO_MODE)

	if isSolo then
		if leftPlayer == nil and rightPlayer == nil then
			return
		end
		local soloPlayer = leftPlayer or rightPlayer
		state.selections.leftPlayer = soloPlayer
		state.selections.rightPlayer = soloPlayer
	else
		if not leftPlayer or not rightPlayer or leftPlayer == rightPlayer then
			return
		end
		state.selections.leftPlayer = leftPlayer
		state.selections.rightPlayer = rightPlayer
	end

	state.countdownActive = true
	state.countdownValue = SparConfig.COUNTDOWN_DURATION

	Network.Spar.broadcastArenaStatus(arenaNumber, "countdownStart", '{"value":' .. tostring(state.countdownValue) .. "}")

	task.spawn(function()
		while state.countdownActive and state.countdownValue > 0 do
			task.wait(1)
			if not state.countdownActive then
				break
			end
			state.countdownValue -= 1
			Network.Spar.broadcastArenaStatus(arenaNumber, "countdownTick", '{"value":' .. tostring(state.countdownValue) .. "}")
		end

		if state.countdownActive then
			state.countdownActive = false
			state.inMatch = true
			activeArenas[arenaNumber] = true
			Network.Spar.broadcastArenaStatus(arenaNumber, "countdownComplete", "{}")
			ArenaMatchService.startMatch(state.selections, arenaNumber)
		end
	end)
end

local function checkPads()
	for arenaNumber, state in arenaStates do
		if state.inMatch then
			continue
		end

		local leftPad = state.leftPad
		local rightPad = state.rightPad

		if not (leftPad and rightPad) then
			continue
		end

		local leftOccupied = false
		local rightOccupied = false

		for _, player in game.Players:GetPlayers() do
			local character = player.Character
			if not character then
				continue
			end
			local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp then
				continue
			end

			local deltaL = hrp.Position - leftPad.Position
			local deltaR = hrp.Position - rightPad.Position
			local onLeftPad = deltaL:Dot(deltaL) <= SparConfig.PAD_DISTANCE_THRESHOLD_SQ
			local onRightPad = deltaR:Dot(deltaR) <= SparConfig.PAD_DISTANCE_THRESHOLD_SQ

			if onLeftPad then
				leftOccupied = true
			end
			if onRightPad then
				rightOccupied = true
			end

			local isOnPad = onLeftPad or onRightPad
			local wasOnPad = playerPadStatus[player] and playerPadStatus[player][arenaNumber]

			if isOnPad ~= wasOnPad then
				ArenaService.setPlayerPadStatus(player, arenaNumber, isOnPad)
			end
		end

		leftPad.BrickColor = leftOccupied and BrickColor.new("Bright green") or BrickColor.new("Bright red")
		rightPad.BrickColor = rightOccupied and BrickColor.new("Bright green") or BrickColor.new("Bright red")
	end
end

function ArenaService.startCountdown(arenaNumber: number, onTick: (value: number) -> (), onComplete: () -> ())
	local state = arenaStates[arenaNumber]
	if not state or not state.countdownActive then
		return
	end

	state.countdownValue = SparConfig.COUNTDOWN_DURATION

	while state.countdownActive and state.countdownValue > 0 do
		if onTick then
			onTick(state.countdownValue)
		end
		countdownTick:Fire(arenaNumber, state.countdownValue)
		task.wait(0.1)
		state.countdownValue -= 0.1
	end

	if state.countdownActive then
		state.countdownActive = false
		if onComplete then
			onComplete()
		end
	end
end

function ArenaService.stopCountdown(arenaNumber: number)
	local state = arenaStates[arenaNumber]
	if not state then
		return
	end
	state.countdownActive = false
	state.countdownValue = SparConfig.COUNTDOWN_DURATION
end

function ArenaService.resetArena(arenaNumber: number)
	local state = arenaStates[arenaNumber]
	if not state then
		return
	end

	activeArenas[arenaNumber] = nil
	state.inMatch = false
	state.countdownActive = false
	state.countdownValue = SparConfig.COUNTDOWN_DURATION
	state.selections = defaultSelections()

	if state.leftPad and state.leftPad.Parent then
		state.leftPad.BrickColor = BrickColor.new("Bright red")
	end
	if state.rightPad and state.rightPad.Parent then
		state.rightPad.BrickColor = BrickColor.new("Bright red")
	end

	for _, player in game.Players:GetPlayers() do
		local wasOnPad = playerPadStatus[player] and playerPadStatus[player][arenaNumber]
		if wasOnPad ~= nil then
			playerPadStatus[player][arenaNumber] = nil
			Network.Spar.firePadStatus(player, arenaNumber, false)
		end
	end
end
function ArenaService.initAll()
	local arenasFolder = workspace:FindFirstChild("Arenas")
	if not arenasFolder then
		return
	end
	for i = 1, 8 do
		local arenaModel = arenasFolder:FindFirstChild(tostring(i))
		if arenaModel then
			ArenaService.setupArena(arenaModel :: Model, i)
		end
	end
end

function ArenaService.start()
	local timeElapsed = 0
	padCheckConnection = RunService.Heartbeat:Connect(function(dt)
		timeElapsed += dt
		if timeElapsed >= SparConfig.PAD_CHECK_INTERVAL then
			timeElapsed = 0
			checkPads()
		end
	end)
end

function ArenaService.cleanup()
	if padCheckConnection then
		padCheckConnection:Disconnect()
		padCheckConnection = nil
	end
	table.clear(arenaStates)
	table.clear(activeArenas)
	table.clear(playerPadStatus)
end

function ArenaService.setArenaActive(arenaNumber: number)
	activeArenas[arenaNumber] = true
end

function ArenaService.setArenaInactive(arenaNumber: number)
	activeArenas[arenaNumber] = nil
end

function ArenaService.isArenaActive(arenaNumber: number): boolean
	return activeArenas[arenaNumber] == true
end

function ArenaService.getSelection(arenaNumber: number): ArenaSelections?
	local state = arenaStates[arenaNumber]
	return state and state.selections or nil
end

function ArenaService.OnSelectionChanged(callback: (arenaNumber: number, player: Player, optionType: string, value: any) -> ()): Signal.Connection
	return selectionChanged:Connect(callback)
end

function ArenaService.OnCountdownTick(callback: (arenaNumber: number, value: number) -> ()): Signal.Connection
	return countdownTick:Connect(callback)
end

return ArenaService
