--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent
local Constants = require(MainModule.Shared.Config.Constants)
local Maps = require(MainModule.Shared.Config.Maps)
local PhaseConfig = require(MainModule.Shared.Config.PhaseConfig)
local Network = require(MainModule.Shared.Network)
local RankCache = require(MainModule.Server.Cache.RankCache)
local PlayerCache = require(MainModule.Shared.Cache.PlayerCache)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
local DamageProcessor = require(MainModule.Server.Services.GunService.DamageProcessor)
local ServerUtils = require(MainModule.Shared.Utils.Game.ServerUtils)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)

local GameState = require(script.GameState)
local SpatialQuery = require(script.SpatialQuery)
local SpawnController = require(script.SpawnController)
local TerminalController = require(script.TerminalController)
local PayloadController = require(script.PayloadController)
local ConquestController = require(script.ConquestController)
local TrainController = require(script.TrainController)
local WorldController = require(script.WorldController)
local VictoryController = require(script.VictoryController)
local DoorController = require(script.DoorController)
local KillBrickController = require(script.KillBrickController)
local CoolantController = require(script.CoolantController)
local CannonController = require(script.CannonController)

local CONTROL_GROUP_ID = Constants.CONTROL.GROUP_ID
local CONTROL_MIN_RANK = Constants.CONTROL.MIN_RANK

type PhaseId = PhaseConfig.PhaseId
type Faction = PhaseConfig.Faction

local DEFENDER_TEAMS = Constants.FACTIONS.DEFENDER_TEAMS
local RAIDER_TEAMS = Constants.FACTIONS.RAIDER_TEAMS
local MIN_PLAYERS_FOR_STATS = Constants.STATS.MIN_PLAYERS

local PHASE_ID_TO_NUMBER: { [PhaseId]: number } = {
	idle = 0,
	phase1 = 1,
	phase2 = 2,
	phase3 = 3,
	ended = 0,
}

local PhaseService = {}
PhaseService.Name = "PhaseService"

local state: GameState.GameState
local isActive: boolean = false

local TeamService: any = nil
local StatsService: any = nil
local ModelsService: any = nil

local trainThread: thread? = nil

local stateDirty: boolean = false

local advancePhase: () -> ()
local transitionToPhase: (phaseId: PhaseId) -> ()
local startGameLoop: () -> ()

local function getPlayerFaction(player: Player): string?
	if not TeamService then
		return nil
	end
	return TeamService:GetPlayerFaction(player)
end

local function isDefenderTeam(teamName: string?): boolean
	return teamName ~= nil and DEFENDER_TEAMS[teamName] == true
end

local function isRaiderTeam(teamName: string?): boolean
	return teamName ~= nil and RAIDER_TEAMS[teamName] == true
end

local function getPhaseNumber(): number
	return PHASE_ID_TO_NUMBER[state.currentPhase] or 0
end

local function shouldCountStats(): boolean
	if not state.official then
		return false
	end
	local economySvc = ServiceLocator.Economy()
	local peak = if economySvc then economySvc:GetPeakPlayerCount() else 0
	return math.max(PlayerCache.getCount(), peak) >= MIN_PLAYERS_FOR_STATS
end

local function stopHeartbeat(): ()
	if state.heartbeatConnection then
		state.heartbeatConnection:Disconnect()
		state.heartbeatConnection = nil
	end
end

local function markDirty(): ()
	stateDirty = true
end

local function broadcastPhaseState(): ()
	stateDirty = false
	Network.Phase.broadcastUpdate({
		Phase = getPhaseNumber(),
		RaidTime = state.raidTimeRemaining,
		TermTime = state.termTimeRemaining,
		Official = state.official,
		CountingDown = state.countingDown,
		Owner = state.terminalOwner,
		PayloadProgress = state.payloadProgress,
		PayloadMax = state.payloadMaxProgress,
		Overtime = state.overtime,
		ConquestActive = state.conquestActive,
		CaptureProgress = state.conquestCaptureProgress,
		CaptureTeam = state.conquestOwner,
	})
end

local function broadcastPhaseStateIfDirty(): ()
	if stateDirty then
		broadcastPhaseState()
	end
end

local function broadcastMessage(message: string): ()
	Network.Phase.broadcastAnnouncement({
		Type = "PHASE_MESSAGE",
		Message = message,
	})
end

local function countFactions(position: Vector3, horizRange: number, vertRange: number, minVertRange: number?): (number, number)
	return SpatialQuery.countFactionsNearPosition(position, horizRange, vertRange, getPlayerFaction, minVertRange)
end

local function getStatsService(): any?
	return StatsService
end
local function getModelsService(): any?
	return ModelsService
end

local function awardCapture(player: Player): ()
	VictoryController.awardCapture(player, shouldCountStats, getStatsService)
end

local function destroyPhase1Map(): ()
	local phase1Folder = workspace:FindFirstChild("PHASE1")
	if not phase1Folder then
		return
	end
	phase1Folder:Destroy()
end

local function destroyPhase2Map(): ()
	local phase2Folder = workspace:FindFirstChild("PHASE2")
	if not phase2Folder then
		return
	end
	phase2Folder:Destroy()
end

local function endGame(winnerFaction: Faction): ()
	if not state.official then
		return
	end

	local defendersWon = winnerFaction == "Defenders"
	local countStats = shouldCountStats()
	state.official = false
	VictoryController.trackEndGameStats(defendersWon, function()
		return countStats
	end, getStatsService, getPlayerFaction)

	state.winner = winnerFaction
	DamageProcessor.invalidateStatsCache()

	state.countingDown = false
	state.overtime = false

	local gameLoopToCancel = state.gameLoopThread
	state.gameLoopThread = nil
	if gameLoopToCancel and gameLoopToCancel ~= coroutine.running() then
		task.cancel(gameLoopToCancel)
	end

	local trainToCancel = trainThread
	trainThread = nil
	if trainToCancel and trainToCancel ~= coroutine.running() then
		task.cancel(trainToCancel)
	end

	stopHeartbeat()
	ConquestController.resetConquestState(state)
	PayloadController.cleanupPayload(state)

	state.currentPhase = "ended"

	WorldController.setTerminalActionsOnEnd()
	WorldController.setTerminalBillboards(0)
	CoolantController.refill()
	CannonController.stop()
	DoorController.setAllPromptsEnabled(false)

	local victoryData = VictoryController.getVictoryData(defendersWon, getStatsService, isDefenderTeam, isRaiderTeam)
	Network.Phase.broadcastVictory(victoryData)
	Network.Phase.broadcastAnnouncement({
		Type = if defendersWon then "DEFENDERS_WON" else "RAIDERS_WON",
		Message = if defendersWon then "DEFENDERS WIN" else "RAIDERS WIN",
	})
end

local function buildConquestCallbacks(): ConquestController.ConquestCallbacks
	return {
		countFactionsNearPosition = countFactions,
		broadcastMessage = broadcastMessage,
		broadcastPhaseState = broadcastPhaseState,
		endGame = endGame,
		advancePhase = function()
			advancePhase()
		end,
		getPlayersNearPosition = SpatialQuery.getPlayersNearPosition,
		getPlayerFaction = getPlayerFaction,
		awardCapture = awardCapture,
	}
end

local function buildTerminalCallbacks(): TerminalController.TerminalCallbacks
	return {
		countFactionsNearPosition = countFactions,
		getPlayersNearPosition = SpatialQuery.getPlayersNearPosition,
		getPlayerFaction = getPlayerFaction,
		awardCapture = awardCapture,
		broadcastMessage = broadcastMessage,
		broadcastPhaseState = broadcastPhaseState,
		endGame = endGame,
		advancePhase = function()
			advancePhase()
		end,
		stopHeartbeat = stopHeartbeat,
	}
end

local function buildPayloadCallbacks(): PayloadController.PayloadCallbacks
	local conquestCallbacks = buildConquestCallbacks()
	return {
		getPlayerFaction = getPlayerFaction,
		countFactionsOnPayload = function(parts: { BasePart })
			return SpatialQuery.countFactionsOnParts(parts, getPlayerFaction)
		end,
		broadcastMessage = broadcastMessage,
		broadcastPhaseState = broadcastPhaseState,
		advancePhase = function()
			advancePhase()
		end,
		stopHeartbeat = stopHeartbeat,
		beginConquest = function(nodeName: string, config: PhaseConfig.PhaseDefinition)
			ConquestController.beginConquest(state, nodeName, config)
			broadcastPhaseState()
		end,
		resetConquestState = function()
			ConquestController.resetConquestState(state)
		end,
		updateConquest = function(dt: number, config: PhaseConfig.PhaseDefinition, nodePosition: Vector3)
			ConquestController.updateConquest(state, dt, config, nodePosition, conquestCallbacks)
		end,
	}
end

advancePhase = function()
	local nextPhase = PhaseConfig.getNextPhase(state.currentPhase)
	if not nextPhase then
		endGame("Raiders")
		return
	end
	transitionToPhase(nextPhase)
end

transitionToPhase = function(phaseId: PhaseId)
	if state.currentPhase == phaseId then
		return
	end

	local config = PhaseConfig.getPhase(phaseId)
	if not config then
		return
	end

	local previousPhase = state.currentPhase
	state.currentPhase = phaseId

	if previousPhase == "phase1" then
		local closeWall = workspace:FindFirstChild("CLOSEFORP1")
		if closeWall then
			closeWall.CFrame = CFrame.new(135.934, 153.706, -336.472)
		end

		destroyPhase1Map()
	end

	if previousPhase == "phase2" then
		local closeWall = workspace:FindFirstChild("CLOSEFORP2")
		if closeWall then
			closeWall.CFrame = CFrame.new(-52.648, 165.236, -744.16) * CFrame.Angles(0, math.rad(-90), 0)
		end
		destroyPhase2Map()
	end

	stopHeartbeat()
	ConquestController.resetConquestState(state)
	PayloadController.cleanupPayload(state)
	state.waitingForTrainDelivery = false
	state.terminalOwner = nil
	state.captureProgress = 0
	state.overtime = false

	SpawnController.setSpawnsForPhase(state, phaseId)
	WorldController.setTerminalBillboards(getPhaseNumber())

	if previousPhase ~= "idle" and config.TimeGift > 0 then
		state.raidTimeRemaining += config.TimeGift
	end

	if previousPhase ~= "idle" then
		startGameLoop()
	end

	Network.Phase.broadcastAnnouncement({
		Type = "PHASE_TRANSITION",
		Message = config.DisplayName,
	})

	SpawnController.respawnAllCombatants(getPlayerFaction)

	if phaseId == "phase1" then
		DoorController.toggleDoor("DoorGroupWithDoorV", true)
		DoorController.toggleDoor("BottomLobbyDoor", true)
	elseif phaseId == "phase2" then
		DoorController.toggleDoor("DoorGroupWithDoorV", true)
		DoorController.setPromptEnabled("DoorGroupWithDoorV", false)
		DoorController.toggleDoor("BigLobbyDoor", true)
		DoorController.setPromptEnabled("BigLobbyDoor", false)
		state.waitingForTrainDelivery = true
		trainThread = task.spawn(TrainController.runTrainSequence, state, getModelsService, broadcastMessage)

		CannonController.start()
		broadcastMessage("ESCORT THE PAYLOAD TO THE COMMUNICATIONS SATELLITE")
	elseif phaseId == "phase3" then
		DoorController.toggleDoor("BottomLobbyDoor", false)
		DoorController.toggleDoor("BigLobbyDoor", false)
		DoorController.setPromptEnabled("BigLobbyDoor", true)
		WorldController.enableSewerPrompts()
		CannonController.start()
		broadcastMessage("ESCORT THE PAYLOAD TO THE CANNON REACTOR")
	end

	if config.HasTerminal and not config.HasPayload then
		task.spawn(function()
			TerminalController.beginTerminalCapture(state, buildTerminalCallbacks())
		end)
	elseif config.HasPayload then
		task.spawn(function()
			PayloadController.beginPayloadEscort(state, buildPayloadCallbacks(), getModelsService)
		end)
	end

	markDirty()
	broadcastPhaseState()
end

local function resetAllStats(): ()
	if StatsService then
		StatsService:ResetAllStats()
	end
end

startGameLoop = function(): ()
	if state.gameLoopThread then
		task.cancel(state.gameLoopThread)
	end

	state.gameLoopThread = task.spawn(function()
		while state.official do
			task.wait(1)
			if not state.official then
				break
			end

			state.raidTimeRemaining -= 1
			markDirty()
			broadcastPhaseStateIfDirty()

			if state.raidTimeRemaining <= 0 then
				local defendersHoldTerminal = state.terminalOwner == "Defenders" and not state.conquestActive
				local defendersRecapping = state.conquestActive and state.conquestOwner == "Defenders" and state.terminalOwner == "Raiders"
				local defendersOwnTerminal = defendersHoldTerminal or defendersRecapping

				if not defendersOwnTerminal then
					state.overtime = true
					markDirty()
					Network.Phase.broadcastAnnouncement({
						Type = "OVERTIME",
						Message = "OVERTIME ACTIVE! RAIDERS HAVE THE TERMINAL",
					})
				else
					endGame("Defenders")
				end
				break
			end
		end

		if state.overtime then
			local overtimeElapsed = 0
			while state.official and state.overtime do
				task.wait(1)
				overtimeElapsed += 1

				if PlayerCache.getCount() == 0 then
					break
				end

				markDirty()
				broadcastPhaseStateIfDirty()
			end
		end

		state.gameLoopThread = nil
	end)
end

local function startGame(): ()
	if state.official or state.countingDown then
		return
	end

	state.countingDown = true
	state.winner = nil
	state.currentPhase = "idle"
	state.raidTimeRemaining = PhaseConfig.INITIAL_RAID_TIME
	state.overtime = false

	WorldController.setTerminalActionsOnOfficial()

	markDirty()
	broadcastPhaseState()

	for countdown = PhaseConfig.COUNTDOWN_TIME, 1, -1 do
		if not state.countingDown then
			state.official = false
			DamageProcessor.invalidateStatsCache()
			return
		end
		Network.Phase.broadcastAnnouncement({
			Type = "RAID_STARTING",
			Message = `STARTING IN {countdown}`,
			Countdown = countdown,
		})
		task.wait(1)
	end

	if not state.countingDown then
		state.official = false
		DamageProcessor.invalidateStatsCache()
		return
	end

	state.countingDown = false
	resetAllStats()
	state.official = true
	DamageProcessor.invalidateStatsCache()

	local economySvc = ServiceLocator.Economy()
	if economySvc then
		economySvc:OnMatchStarted()
	end

	DoorController.setAllPromptsEnabled(true)
	transitionToPhase("phase1")
	startGameLoop()
end

local function hasPhaseAccess(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end

	local mapConfig = Maps.getConfig()
	if mapConfig.GameType == "Raid" then
		return RankCache.isInGroup(player, CONTROL_GROUP_ID, CONTROL_MIN_RANK)
	end
	if ServerUtils.isPrivateServer() then
		return ServerUtils.isPrivateServerOwner(player)
	end
	return RankCache.isInGroup(player, CONTROL_GROUP_ID, CONTROL_MIN_RANK)
end

local function canUseOfficialCommand(player: Player): boolean
	return RankCache.isInGroup(player, CONTROL_GROUP_ID, CONTROL_MIN_RANK) or ServerUtils.isPrivateServerOwner(player)
end

local function handlePhaseControl(player: Player, payload: Network.PhaseControlPayload): ()
	if not hasPhaseAccess(player) then
		return
	end

	local action = payload.action
	if action == "start" then
		if not state.official and not state.countingDown then
			task.spawn(startGame)
		end
	elseif action == "skipPhase" then
		if not state.official or state.currentPhase == "idle" or state.currentPhase == "ended" or state.currentPhase == "phase3" then
			return
		end
		local economySvc = ServiceLocator.Economy()
		if economySvc then
			economySvc:FlagMatchTampered("Admin panel: Phase skipped")
		end
		advancePhase()
	elseif action == "end" then
		if not state.official then
			return
		end
		local economySvc = ServiceLocator.Economy()
		if economySvc then
			economySvc:FlagMatchTampered("Admin panel: Match force-ended")
		end
		endGame(if payload.winner == "Raiders" then "Raiders" else "Defenders")
	elseif action == "setTermTime" then
		if payload.termTime then
			if payload.termTime < 900 then
				local economySvc = ServiceLocator.Economy()
				if economySvc then
					economySvc:FlagMatchTampered(`Admin panel: Term time set to {payload.termTime}s (< 900s)`)
				end
			end
			state.termTimeRemaining = math.max(0, payload.termTime)
			markDirty()
			broadcastPhaseState()
		end
	elseif action == "setRaidTime" then
		if payload.raidTime then
			if payload.raidTime < 900 then
				local economySvc = ServiceLocator.Economy()
				if economySvc then
					economySvc:FlagMatchTampered(`Admin panel: Raid time set to {payload.raidTime}s (< 900s)`)
				end
			end
			state.raidTimeRemaining = math.max(0, payload.raidTime)
			markDirty()
			broadcastPhaseState()
		end
	end
end

local function handleGetState(_player: Player): Network.PhaseState
	return {
		Phase = getPhaseNumber(),
		RaidTime = state.raidTimeRemaining,
		TermTime = state.termTimeRemaining,
		Official = state.official,
		CountingDown = state.countingDown,
		Owner = state.terminalOwner,
		PayloadProgress = state.payloadProgress,
		PayloadMax = state.payloadMaxProgress,
		Overtime = state.overtime,
		ConquestActive = state.conquestActive,
		CaptureProgress = state.conquestCaptureProgress,
		CaptureTeam = state.conquestOwner,
	}
end

local function handleGetPermissions(player: Player): { HasAccess: boolean, IsPrivateServer: boolean, IsOwner: boolean }
	return {
		HasAccess = hasPhaseAccess(player),
		IsPrivateServer = ServerUtils.isPrivateServer(),
		IsOwner = ServerUtils.isPrivateServerOwner(player),
	}
end

local function handleChatCommand(player: Player, content: string): ()
	if not content:match("^:") then
		return
	end
	if content:lower() == ":official" then
		if not state.official and not state.countingDown and canUseOfficialCommand(player) then
			task.spawn(startGame)
		end
	end
end

function PhaseService:init(): ()
	local mapConfig = Maps.getConfig()
	isActive = mapConfig.RaidType == "Phase"
	if not isActive then
		return
	end

	state = GameState.new()
	SpatialQuery.init()
	SpawnController.cacheSpawnLocations(state)
	TerminalController.cacheTerminalPoints(state)
	PayloadController.cachePathNodes(state)
	DoorController.init()
	KillBrickController.init()
	CoolantController.start(broadcastMessage)
	SpawnController.setSpawnsForPhase(state, "phase1")
	WorldController.setTerminalBillboards(1)
end

function PhaseService:start(): ()
	if not isActive then
		return
	end

	TeamService = LazyService.create(MainModule, "TeamService")()
	StatsService = LazyService.create(MainModule, "StatsService")()
	ModelsService = LazyService.create(MainModule, "ModelsService")()

	table.insert(state.connections, Network.Chat.onCommandReceived(handleChatCommand))
	table.insert(state.connections, Network.Phase.onControl(handlePhaseControl))
	Network.Phase.onGetState(handleGetState)
	Network.Phase.onGetPermissions(handleGetPermissions)
	WorldController.setupTeleports(state.connections)
	WorldController.setupSewerSystem(state.connections, getPlayerFaction, broadcastMessage)
end

function PhaseService:StartGame(): ()
	if not isActive then
		return
	end
	task.spawn(startGame)
end

function PhaseService:SkipPhase(_player: Player): ()
	if not state then
		return
	end
	if not state.official or state.currentPhase == "idle" or state.currentPhase == "ended" or state.currentPhase == "phase3" then
		return
	end
	advancePhase()
end

function PhaseService:EndGame(winnerFaction: string?): ()
	if not state or not state.official then
		return
	end
	endGame(if winnerFaction == "Raiders" then "Raiders" else "Defenders")
end

function PhaseService:GetCurrentPhase(): PhaseId
	if not state then
		return "idle"
	end
	return state.currentPhase
end

function PhaseService:IsActive(): boolean
	return isActive
end

function PhaseService:IsOfficial(): boolean
	if not state then
		return false
	end
	return state.official
end

function PhaseService:GetRaidTimeRemaining(): number
	if not state then
		return 0
	end
	return state.raidTimeRemaining
end

function PhaseService:GetTermTimeRemaining(): number
	if not state then
		return 0
	end
	return state.termTimeRemaining
end

function PhaseService:GetWinner(): Faction?
	if not state then
		return nil
	end
	return state.winner
end

function PhaseService:OpenDoor(doorName: string): ()
	DoorController.toggleDoor(doorName, true)
end

function PhaseService:CloseDoor(doorName: string): ()
	DoorController.toggleDoor(doorName, false)
end

function PhaseService:Cleanup(): ()
	if not state then
		return
	end

	for _, conn in state.connections do
		conn:Disconnect()
	end
	table.clear(state.connections)

	local gameLoopToCancel = state.gameLoopThread
	state.gameLoopThread = nil
	if gameLoopToCancel and gameLoopToCancel ~= coroutine.running() then
		task.cancel(gameLoopToCancel)
	end

	local trainToCancel = trainThread
	trainThread = nil
	if trainToCancel and trainToCancel ~= coroutine.running() then
		task.cancel(trainToCancel)
	end

	stopHeartbeat()
	ConquestController.resetConquestState(state)
	PayloadController.cleanupPayload(state)
	DoorController.cleanup()
	CoolantController.stop()
	CannonController.stop()
	KillBrickController.cleanup()
	SpatialQuery.cleanup()
	SpawnController.cleanup(state)

	GameState.reset(state)

	TeamService = nil
	StatsService = nil
	ModelsService = nil
	stateDirty = false
end

return PhaseService
