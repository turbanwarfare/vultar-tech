--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local AvatarService = require(MainModule.Server.Services.AvatarService)
local Constants = require(MainModule.Shared.Config.Constants)
local Network = require(MainModule.Shared.Network)
local Maps = require(MainModule.Shared.Config.Maps)
local RankCache = require(MainModule.Server.Cache.RankCache)
local PlayerCache = require(MainModule.Shared.Cache.PlayerCache)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

local SharedTypes = require(MainModule.Shared.Types)
local ServerUtils = require(MainModule.Shared.Utils.Game.ServerUtils)

local DamageProcessor = require(MainModule.Server.Services.GunService.DamageProcessor)

local CONTROL_GROUP_ID = Constants.CONTROL.GROUP_ID
local CONTROL_MIN_RANK = Constants.CONTROL.MIN_RANK

type Owner = "Defenders" | "Hostiles" | nil
type Faction = SharedTypes.Faction

local HardpointService = {}
HardpointService.Name = "HardpointService"

local official: boolean = false
local paused: boolean = true
local countingDown: boolean = false
local timerStarted: boolean = false
local defenderScore: number = 0
local hostileScore: number = 0
local maxPoints: number = 1000
local currentPointIndex: number = 1
local owner: Owner = nil
local rotationDeadline: number = 0
local pauseAccumulator: number = 0
local rotationTimeMin: number = 60
local rotationTimeMax: number = 60
local isActive: boolean = false
local cachedTerminalCount: number = 0

local DEFAULT_ROTATION_TIME_MIN: number = 100
local DEFAULT_ROTATION_TIME_MAX: number = 120
local ROTATION_WARNING_TIME: number = 5
local COUNTDOWN_TIME: number = 10

local controlConnection: RBXScriptConnection? = nil

local DEFENDER_COLOR = Color3.fromRGB(170, 0, 0)
local HOSTILE_COLOR = Color3.fromRGB(0, 85, 255)
local NEUTRAL_COLOR = Color3.fromRGB(255, 255, 255)

local TeamService: any = nil
local StatsService: any = nil
local EconomyService: any = nil

local MIN_PLAYERS_FOR_STATS = Constants.STATS.MIN_PLAYERS
local TOUCH_DEBOUNCE_DURATION = 1
local CAPTURE_LOCK_DURATION = 0.5
local RAID_START_DELAY = 2
local RESPAWN_SETTLE_DELAY = 0.5

local gameLoopThread: thread? = nil
local touchConnections: { RBXScriptConnection } = {}
local touchDebounceMap: { [number]: boolean } = {}
local isCaptureInProgress: boolean = false
local chatConnection: RBXScriptConnection? = nil

local rng = Random.new()

local terminalPoints: Folder? = nil
local currentTerminal: BasePart? = nil
local lastWarnedRotationSecond: number = -1

local pauseStartTime: number? = nil

local function getTimeToRotate(): number
	if not timerStarted then
		return rotationTimeMax
	end

	local remaining = rotationDeadline - os.clock() + pauseAccumulator
	return math.max(0, math.ceil(remaining))
end

local function startRotationTimer(): ()
	local duration = if rotationTimeMin == rotationTimeMax then rotationTimeMin else rng:NextInteger(rotationTimeMin, rotationTimeMax)
	rotationDeadline = os.clock() + duration
	pauseAccumulator = 0
	lastWarnedRotationSecond = -1
end

local function getPlayerFaction(player: Player): Faction?
	if not TeamService then
		return nil
	end
	return TeamService:GetPlayerFaction(player)
end

local function shouldCountStats(): boolean
	if not official then
		return false
	end
	local peak = if EconomyService then EconomyService:GetPeakPlayerCount() else 0
	return math.max(PlayerCache.getCount(), peak) >= MIN_PLAYERS_FOR_STATS
end

local function checkPlayerPermissions(player: Player): Network.TerminalPermissions
	local mapConfig = Maps.getConfig()
	local isPrivate = ServerUtils.isPrivateServer()
	local hasAccess = false
	local isOwner = false

	if mapConfig.GameType == "Raid" then
		hasAccess = RankCache.isInGroup(player, CONTROL_GROUP_ID, CONTROL_MIN_RANK)
	else
		if isPrivate then
			isOwner = ServerUtils.isPrivateServerOwner(player)
			hasAccess = isOwner
		else
			hasAccess = RankCache.isInGroup(player, CONTROL_GROUP_ID, CONTROL_MIN_RANK)
		end
	end

	return {
		HasAccess = hasAccess,
		IsPrivateServer = isPrivate,
		IsOwner = isOwner,
	}
end

local function broadcastState(): ()
	Network.Hardpoint.broadcastUpdate({
		Official = official,
		Paused = paused,
		CountingDown = countingDown,
		DefenderScore = defenderScore,
		HostileScore = hostileScore,
		MaxPoints = maxPoints,
		CurrentPoint = currentPointIndex,
		CurrentPointName = if currentTerminal then currentTerminal.Name else nil,
		Owner = owner,
		TimeToRotate = getTimeToRotate(),
		RotationTimeMin = rotationTimeMin,
		RotationTimeMax = rotationTimeMax,
	})
end

local function broadcastAnnouncement(announcementType: string, message: string, team: Owner?, countdown: number?): ()
	Network.Hardpoint.broadcastAnnouncement({
		Type = announcementType :: any,
		Message = message,
		Team = team,
		Countdown = countdown,
	})
end

local function updateTerminalVisuals(action: string, color: Color3?): ()
	if not currentTerminal then
		return
	end
	Network.Hardpoint.broadcastTerminalVisual(currentTerminal.Name, action, color)
end

local function getTerminalPoints(): Folder?
	if terminalPoints then
		return terminalPoints
	end
	terminalPoints = workspace:FindFirstChild("TerminalPoints") :: Folder?
	return terminalPoints
end

local function configureTerminalPoints(): ()
	local points = getTerminalPoints()
	if not points then
		return
	end

	for _, point in points:GetChildren() do
		if point:IsA("BasePart") then
			point.CanQuery = false
		end
		for _, descendant in point:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanQuery = false
			end
		end
	end
end

local function getTerminalCount(): number
	if cachedTerminalCount > 0 then
		return cachedTerminalCount
	end
	local points = getTerminalPoints()
	if not points then
		return 0
	end
	cachedTerminalCount = #points:GetChildren()
	return cachedTerminalCount
end

local function setCurrentTerminal(index: number): ()
	local points = getTerminalPoints()
	if not points then
		return
	end

	local terminalPart = (points :: any)[index]
	if not terminalPart or not terminalPart:IsA("BasePart") then
		return
	end

	currentTerminal = terminalPart :: BasePart
	currentPointIndex = index
end

local function clearTouchDebounce(userId: number): ()
	touchDebounceMap[userId] = nil
end

local function clearCaptureInProgress(): ()
	isCaptureInProgress = false
end

local function disconnectTouchConnections(): ()
	for _, conn in touchConnections do
		conn:Disconnect()
	end
	table.clear(touchConnections)
	table.clear(touchDebounceMap)
	isCaptureInProgress = false
end

local function connectTerminalTouch(): ()
	disconnectTouchConnections()

	if not currentTerminal then
		return
	end

	local connection = currentTerminal.Touched:Connect(function(hit: BasePart)
		if paused then
			return
		end
		if isCaptureInProgress then
			return
		end

		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end

		local userId = player.UserId
		if touchDebounceMap[userId] then
			return
		end

		local character = player.Character
		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		local faction = getPlayerFaction(player)
		if not faction or faction == "Neutral" then
			return
		end

		if owner == "Defenders" and faction == "Defenders" then
			return
		end
		if owner == "Hostiles" and faction == "Raiders" then
			return
		end

		isCaptureInProgress = true
		touchDebounceMap[userId] = true
		task.delay(TOUCH_DEBOUNCE_DURATION, clearTouchDebounce, userId)

		if faction == "Defenders" then
			owner = "Defenders"

			if not timerStarted then
				timerStarted = true
				startRotationTimer()
			end

			broadcastAnnouncement("TERMINAL_CAPTURED", "DEFENDERS HAVE CAPTURED THE TERMINAL", "Defenders")
			updateTerminalVisuals("Capture", DEFENDER_COLOR)
		elseif faction == "Raiders" then
			owner = "Hostiles"

			if not timerStarted then
				timerStarted = true
				startRotationTimer()
			end

			broadcastAnnouncement("TERMINAL_CAPTURED", "HOSTILES HAVE CAPTURED THE TERMINAL", "Hostiles")
			updateTerminalVisuals("Capture", HOSTILE_COLOR)
		end

		local statsSvc = StatsService
		if statsSvc then
			statsSvc:AddCapture(player, 1)
			if shouldCountStats() then
				statsSvc:AddCaptureGlobal(player)
			end
		end

		broadcastState()

		task.delay(CAPTURE_LOCK_DURATION, clearCaptureInProgress)
	end)

	table.insert(touchConnections, connection)
end

local function rotateTerminal(): ()
	local totalPoints = getTerminalCount()
	if totalPoints <= 1 then
		return
	end

	updateTerminalVisuals("End", nil)

	local newIndex = currentPointIndex
	local attempts = 0
	while newIndex == currentPointIndex and attempts < 100 do
		newIndex = rng:NextInteger(1, totalPoints)
		attempts += 1
	end

	setCurrentTerminal(newIndex)
	owner = nil
	timerStarted = false

	updateTerminalVisuals("Start", NEUTRAL_COLOR)
	connectTerminalTouch()

	broadcastAnnouncement("TERMINAL_ROTATED", "TERMINAL HAS ROTATED", nil)
	broadcastState()
end

local function checkLeadChange(wasTied: boolean, previousDefenderLead: boolean): ()
	if wasTied then
		return
	end

	local defenderLead = defenderScore > hostileScore
	if defenderLead ~= previousDefenderLead then
		if defenderLead then
			broadcastAnnouncement("LEAD_TAKEN", "DEFENDERS HAVE TAKEN THE LEAD", "Defenders")
		else
			broadcastAnnouncement("LEAD_TAKEN", "HOSTILES HAVE TAKEN THE LEAD", "Hostiles")
		end
	end
end

local DEFENDER_TEAMS = Constants.FACTIONS.DEFENDER_TEAMS
local RAIDER_TEAMS = Constants.FACTIONS.RAIDER_TEAMS

local function isDefenderTeam(teamName: string?): boolean
	return teamName ~= nil and DEFENDER_TEAMS[teamName] == true
end

local function isRaiderTeam(teamName: string?): boolean
	return teamName ~= nil and RAIDER_TEAMS[teamName] == true
end

local function getTopPlayersByFaction(faction: string, statsSvc: any): Network.TeamTopPlayers
	local leaderboard = statsSvc:GetLeaderboard("Kills")
	local result: Network.TeamTopPlayers = { Kills = nil, Damage = nil, Heals = nil }

	local topKills, topDamage, topHeals = 0, 0, 0
	local isDefenderFaction = faction == "Defenders"

	for _, entry in leaderboard do
		local isMatchingFaction = if isDefenderFaction then isDefenderTeam(entry.Team) else isRaiderTeam(entry.Team)

		if isMatchingFaction then
			if entry.Stats.Kills > topKills then
				topKills = entry.Stats.Kills
				result.Kills = {
					UserId = entry.UserId,
					DisplayName = entry.DisplayName,
					Value = entry.Stats.Kills,
				}
			end
			if entry.Stats.Damage > topDamage then
				topDamage = entry.Stats.Damage
				result.Damage = {
					UserId = entry.UserId,
					DisplayName = entry.DisplayName,
					Value = entry.Stats.Damage,
				}
			end
			if entry.Stats.Heals > topHeals then
				topHeals = entry.Stats.Heals
				result.Heals = {
					UserId = entry.UserId,
					DisplayName = entry.DisplayName,
					Value = entry.Stats.Heals,
				}
			end
		end
	end

	return result
end

local function getVictoryData(defendersWon: boolean): Network.VictoryData
	local statsSvc = StatsService
	local defenderTop: Network.TeamTopPlayers = { Kills = nil, Damage = nil, Heals = nil }
	local hostileTop: Network.TeamTopPlayers = { Kills = nil, Damage = nil, Heals = nil }

	if statsSvc then
		statsSvc:FlushPendingUpdates()
		defenderTop = getTopPlayersByFaction("Defenders", statsSvc)
		hostileTop = getTopPlayersByFaction("Raiders", statsSvc)
	end

	return {
		WinningTeam = if defendersWon then "Defenders" else "Hostiles",
		DefenderTopPlayers = defenderTop,
		HostileTopPlayers = hostileTop,
		DefenderScore = defenderScore,
		HostileScore = hostileScore,
	}
end

local function findMVP(defendersWon: boolean): Player?
	local statsSvc = StatsService
	if not statsSvc then
		return nil
	end

	local leaderboard = statsSvc:GetLeaderboard("Total")
	local mvpPlayer: Player? = nil
	local mvpScore = 0
	local winningFaction = if defendersWon then "Defenders" else "Raiders"

	for _, entry in leaderboard do
		local player = Players:GetPlayerByUserId(entry.UserId)
		if player then
			local faction = getPlayerFaction(player)
			if faction == winningFaction then
				local score = entry.Stats.Kills + entry.Stats.Damage + entry.Stats.Heals + entry.Stats.Captures
				if score > mvpScore then
					mvpScore = score
					mvpPlayer = player
				end
			end
		end
	end

	return mvpPlayer
end

local function trackEndGameStats(defendersWon: boolean): ()
	local statsSvc = StatsService
	if not statsSvc then
		return
	end

	for _, player in Players:GetPlayers() do
		local faction = getPlayerFaction(player)
		if faction and faction ~= "Neutral" then
			statsSvc:AddGamesPlayed(player)

			local isWinner = (faction == "Defenders" and defendersWon) or (faction == "Raiders" and not defendersWon)
			if isWinner then
				statsSvc:AddGamesWon(player)
			end
			if EconomyService then
				EconomyService:AwardMatchOutcome(player, isWinner)
			end
		end
	end

	local mvpPlayer = findMVP(defendersWon)
	if mvpPlayer then
		statsSvc:AddMVP(mvpPlayer)
	end
end

local function endRaid(defendersWon: boolean, calledFromLoop: boolean?): ()
	local countStats = shouldCountStats()
	official = false
	if countStats then
		trackEndGameStats(defendersWon)
	end

	DamageProcessor.invalidateStatsCache()

	paused = true
	pauseStartTime = nil

	disconnectTouchConnections()

	if gameLoopThread and not calledFromLoop then
		task.cancel(gameLoopThread)
		gameLoopThread = nil
	end

	updateTerminalVisuals("End", nil)

	local victoryData = getVictoryData(defendersWon)
	Network.Hardpoint.broadcastVictory(victoryData)

	broadcastState()
end

local function startGameLoop(): ()
	if gameLoopThread then
		task.cancel(gameLoopThread)
	end

	gameLoopThread = task.spawn(function()
		local totalPoints = getTerminalCount()

		while official do
			if paused then
				if not pauseStartTime then
					pauseStartTime = os.clock()
				end
				task.wait(1)
				continue
			end

			if pauseStartTime then
				pauseAccumulator += os.clock() - pauseStartTime
				pauseStartTime = nil
			end

			local wasTied = defenderScore == hostileScore
			local previousDefenderLead = defenderScore > hostileScore

			if owner == "Defenders" then
				defenderScore += 1
			elseif owner == "Hostiles" then
				hostileScore += 1
			end

			if not wasTied then
				checkLeadChange(wasTied, previousDefenderLead)
			end

			if defenderScore >= maxPoints then
				endRaid(true, true)
				break
			elseif hostileScore >= maxPoints then
				endRaid(false, true)
				break
			end

			if totalPoints > 1 then
				local remaining = getTimeToRotate()

				if remaining > 0 and remaining <= ROTATION_WARNING_TIME then
					if remaining ~= lastWarnedRotationSecond then
						lastWarnedRotationSecond = remaining
						broadcastAnnouncement("ROTATION_WARNING", `TERMINAL ROTATING IN {remaining}`, nil, 1)
					end
				end

				if remaining <= 0 then
					rotateTerminal()
					task.wait(1)
					continue
				end
			end

			broadcastState()
			task.wait(1)
		end

		gameLoopThread = nil
	end)
end

local function resetAllStats(): ()
	local statsSvc = StatsService
	if statsSvc then
		statsSvc:ResetAllStats()
	end
end

local function respawnAllPlayers(): ()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			AvatarService:LoadCharacter(player)
		end)
	end
end

local function startCountdown(): boolean
	for i = COUNTDOWN_TIME, 1, -1 do
		if not countingDown then
			return false
		end

		broadcastAnnouncement("RAID_STARTING", `RAID STARTING IN {i}`, nil, i)

		local elapsed = 0
		while elapsed < 1 do
			task.wait(0.1)

			if not countingDown then
				return false
			end

			if not paused then
				elapsed += 0.1
			end
		end
	end
	return true
end

local function beginRaid(): ()
	paused = false
	pauseStartTime = nil

	timerStarted = false

	setCurrentTerminal(1)
	updateTerminalVisuals("Start", NEUTRAL_COLOR)
	connectTerminalTouch()

	broadcastAnnouncement("RAID_STARTED", "RAID HAS BEGUN", nil)
	broadcastState()

	startGameLoop()
end

local function invokeOfficial(): ()
	if official or countingDown then
		return
	end

	paused = false
	countingDown = true
	defenderScore = 0
	hostileScore = 0
	owner = nil
	pauseStartTime = nil
	lastWarnedRotationSecond = -1

	broadcastState()

	local countdownCompleted = startCountdown()

	if not countdownCompleted then
		return
	end

	countingDown = false
	broadcastState()

	task.wait(RAID_START_DELAY)

	respawnAllPlayers()
	task.wait(RESPAWN_SETTLE_DELAY)

	resetAllStats()
	official = true
	DamageProcessor.invalidateStatsCache()

	if EconomyService then
		EconomyService:OnMatchStarted()
	end

	beginRaid()
end

local function canUseOfficialCommand(player: Player): boolean
	if RankCache.isInGroup(player, CONTROL_GROUP_ID, CONTROL_MIN_RANK) then
		return true
	end
	if ServerUtils.isPrivateServerOwner(player) then
		return true
	end
	return false
end

local function handleChatCommand(player: Player, content: string): ()
	if not content:match("^:") then
		return
	end

	local msg = content:lower()

	if msg == ":official" then
		if not official and not countingDown and canUseOfficialCommand(player) then
			task.spawn(invokeOfficial)
		end
	end
end

local function handleControl(player: Player, payload: Network.ControlPayload): ()
	local permissions = checkPlayerPermissions(player)
	if not permissions.HasAccess then
		return
	end

	local action = payload.action

	if action == "start" then
		if not official and not countingDown then
			task.spawn(invokeOfficial)
		end
	elseif action == "pause" then
		if official and not paused then
			if EconomyService then
				EconomyService:FlagMatchTampered("Admin panel: Hardpoint match paused")
			end
			HardpointService:Pause()
		end
	elseif action == "unpause" then
		if official and paused then
			HardpointService:Unpause()
		end
	elseif action == "reset" then
		if official and EconomyService then
			EconomyService:FlagMatchTampered("Admin panel: Hardpoint match reset")
		end
		HardpointService:Reset(player.DisplayName)
	elseif action == "setMaxPoints" then
		if payload.maxPoints then
			if official and EconomyService then
				EconomyService:FlagMatchTampered("Admin panel: Hardpoint max points modified")
			end
			HardpointService:SetMaxPoints(payload.maxPoints)
		end
	elseif action == "setRotationRange" then
		if payload.rotationMin and payload.rotationMax then
			if official and EconomyService then
				EconomyService:FlagMatchTampered("Admin panel: Hardpoint rotation range modified")
			end
			HardpointService:SetRotationRange(payload.rotationMin, payload.rotationMax)
		end
	elseif action == "setScores" then
		if payload.defenderScore ~= nil or payload.hostileScore ~= nil then
			if official and EconomyService then
				EconomyService:FlagMatchTampered("Admin panel: Hardpoint scores modified")
			end
			HardpointService:SetScores(payload.defenderScore, payload.hostileScore)
		end
	end
end

local function handleGetPermissions(player: Player): Network.TerminalPermissions
	return checkPlayerPermissions(player)
end

local function handleGetState(_player: Player): Network.HardpointState
	return HardpointService:GetState()
end

function HardpointService:init(): ()
	local mapConfig = Maps.getConfig()
	isActive = mapConfig.Hardpoint == true
	if not isActive then
		return
	end

	maxPoints = mapConfig.DefaultPoints
	rotationTimeMin = DEFAULT_ROTATION_TIME_MIN
	rotationTimeMax = DEFAULT_ROTATION_TIME_MAX
	rotationDeadline = 0
	pauseAccumulator = 0
	pauseStartTime = nil
	lastWarnedRotationSecond = -1

	configureTerminalPoints()
end

function HardpointService:start(): ()
	if not isActive then
		return
	end

	TeamService = LazyService.create(MainModule, "TeamService")()
	StatsService = LazyService.create(MainModule, "StatsService")()
	EconomyService = LazyService.create(MainModule, "EconomyService")()

	chatConnection = Network.Chat.onCommandReceived(handleChatCommand)
	controlConnection = Network.Hardpoint.onControl(handleControl)
	Network.Hardpoint.onGetPermissions(handleGetPermissions)
	Network.Hardpoint.onGetState(handleGetState)
end

function HardpointService:IsOfficial(): boolean
	return official
end

function HardpointService:IsPaused(): boolean
	return paused
end

function HardpointService:GetState(): Network.HardpointState
	return {
		Official = official,
		Paused = paused,
		CountingDown = countingDown,
		DefenderScore = defenderScore,
		HostileScore = hostileScore,
		MaxPoints = maxPoints,
		CurrentPoint = currentPointIndex,
		CurrentPointName = if currentTerminal then currentTerminal.Name else nil,
		Owner = owner,
		TimeToRotate = getTimeToRotate(),
		RotationTimeMin = rotationTimeMin,
		RotationTimeMax = rotationTimeMax,
	}
end

function HardpointService:Pause(): ()
	if not official then
		return
	end
	paused = true

	if not pauseStartTime then
		pauseStartTime = os.clock()
	end
	if countingDown then
		broadcastAnnouncement("RAID_STARTING", "COUNTDOWN PAUSED", nil)
	else
		broadcastAnnouncement("RAID_STARTING", "RAID HAS BEEN PAUSED", nil)
	end
	broadcastState()
end

function HardpointService:Unpause(): ()
	if not official then
		return
	end

	if pauseStartTime then
		pauseAccumulator += os.clock() - pauseStartTime
		pauseStartTime = nil
	end
	paused = false

	if countingDown then
		broadcastAnnouncement("RAID_STARTING", "COUNTDOWN RESUMED", nil)
	else
		broadcastAnnouncement("RAID_STARTED", "RAID HAS BEEN UNPAUSED", nil)
	end

	broadcastState()
end

function HardpointService:Reset(playerName: string?): ()
	official = false
	DamageProcessor.invalidateStatsCache()

	paused = true
	countingDown = false
	defenderScore = 0
	hostileScore = 0
	owner = nil
	currentPointIndex = 1
	rotationDeadline = 0
	pauseAccumulator = 0
	pauseStartTime = nil
	lastWarnedRotationSecond = -1

	disconnectTouchConnections()

	if gameLoopThread then
		task.cancel(gameLoopThread)
		gameLoopThread = nil
	end

	updateTerminalVisuals("End", nil)
	respawnAllPlayers()
	task.wait(RESPAWN_SETTLE_DELAY)
	resetAllStats()

	if playerName then
		broadcastAnnouncement("RAID_STARTING", `{playerName} HAS RESET THE TERMINAL`, nil)
	end

	broadcastState()
end

function HardpointService:SetMaxPoints(points: number): ()
	maxPoints = math.clamp(points, 100, 10000)
	broadcastState()
end

function HardpointService:SetRotationRange(minTime: number, maxTime: number): ()
	rotationTimeMin = math.clamp(minTime, 10, 300)
	rotationTimeMax = math.clamp(maxTime, rotationTimeMin, 300)
	broadcastState()
end

function HardpointService:SetScores(newDefenderScore: number?, newHostileScore: number?): ()
	if newDefenderScore ~= nil then
		defenderScore = math.clamp(newDefenderScore, 0, maxPoints)
	end
	if newHostileScore ~= nil then
		hostileScore = math.clamp(newHostileScore, 0, maxPoints)
	end
	broadcastState()
end

function HardpointService:GetDefaults(): { maxPoints: number, rotationTimeMin: number, rotationTimeMax: number }
	local mapConfig = Maps.getConfig()
	return {
		maxPoints = mapConfig.DefaultPoints,
		rotationTimeMin = DEFAULT_ROTATION_TIME_MIN,
		rotationTimeMax = DEFAULT_ROTATION_TIME_MAX,
	}
end

function HardpointService:ResetToDefaults(): ()
	local mapConfig = Maps.getConfig()
	maxPoints = mapConfig.DefaultPoints
	rotationTimeMin = DEFAULT_ROTATION_TIME_MIN
	rotationTimeMax = DEFAULT_ROTATION_TIME_MAX
	broadcastState()
end

function HardpointService:Cleanup(): ()
	if chatConnection then
		chatConnection:Disconnect()
		chatConnection = nil
	end

	if controlConnection then
		controlConnection:Disconnect()
		controlConnection = nil
	end

	disconnectTouchConnections()

	if gameLoopThread then
		task.cancel(gameLoopThread)
		gameLoopThread = nil
	end
end

return HardpointService
