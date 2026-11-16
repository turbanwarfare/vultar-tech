--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MainModule = script.Parent.Parent.Parent
local AvatarService = require(MainModule.Server.Services.AvatarService)
local Constants = require(MainModule.Shared.Config.Constants)
local Network = require(MainModule.Shared.Network)
local Maps = require(MainModule.Shared.Config.Maps)
local RankCache = require(MainModule.Server.Cache.RankCache)
local PlayerCache = require(MainModule.Shared.Cache.PlayerCache)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
local ServerUtils = require(MainModule.Shared.Utils.Game.ServerUtils)
local DominationConfig = require(MainModule.Shared.Config.DominationConfig)
local DamageProcessor = require(MainModule.Server.Services.GunService.DamageProcessor)

local CONTROL_GROUP_ID = Constants.CONTROL.GROUP_ID
local CONTROL_MIN_RANK = Constants.CONTROL.MIN_RANK
local MIN_PLAYERS_FOR_STATS = Constants.STATS.MIN_PLAYERS

type Owner = "Defenders" | "Hostiles" | nil
type Faction = "Defenders" | "Raiders" | "Neutral"
type Config = DominationConfig.DominationConfig

type PointState = {
	label: string,
	part: BasePart,

	owner: Owner,
	progress: number,
	progressOwner: Owner,

	aliveDefenders: number,
	aliveRaiders: number,
	deadDefenders: { [Player]: boolean },
	deadRaiders: { [Player]: boolean },

	contested: boolean,
	lastBroadcastProgress: number,
}

local DominationService = {}
DominationService.Name = "DominationService"

local isActive: boolean = false
local official: boolean = false
local paused: boolean = true
local countingDown: boolean = false
local defenderScore: number = 0
local hostileScore: number = 0
local config: Config = DominationConfig.DEFAULT

local points: { PointState } = {}

local heartbeatConnection: RBXScriptConnection? = nil
local gameLoopThread: thread? = nil
local chatConnection: RBXScriptConnection? = nil
local controlConnection: RBXScriptConnection? = nil
local deathConnections: { [Player]: RBXScriptConnection } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}



local TeamService: any = nil
local StatsService: any = nil
local EconomyService: any = nil

local COUNTDOWN_TIME = 10
local RAID_START_DELAY = 2
local RESPAWN_SETTLE_DELAY = 0.5
local CAPTURE_HORIZ_RANGE = 12
local CAPTURE_VERT_RANGE = 10

local function getPlayerFaction(player: Player): Faction?
	if not TeamService then return nil end
	return TeamService:GetPlayerFaction(player) :: Faction?
end

local function shouldCountStats(): boolean
	if not official then return false end
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

local function buildNetworkPoints(): { Network.DominationPointState }
	local result: { Network.DominationPointState } = table.create(#points)
	local captureTime = config.CaptureTimeSeconds
	for _, pt in points do
		local pct = if captureTime > 0 then math.clamp(pt.progress / captureTime, 0, 1) else 0
		table.insert(result, {
			Label = pt.label,
			Owner = (if pt.owner == "Raiders" then "Hostiles" else pt.owner) :: any,
			Progress = pct,
			ProgressOwner = (if pt.progressOwner == "Raiders" then "Hostiles" else pt.progressOwner) :: any,
			Contested = pt.contested,
		})
	end
	return result
end

local function broadcastState(): ()
	Network.Domination.broadcastUpdate({
		Official = official,
		Paused = paused,
		CountingDown = countingDown,
		DefenderScore = defenderScore,
		HostileScore = hostileScore,
		MaxScore = config.MaxScore,
		Points = buildNetworkPoints(),
	})
end

local function broadcastAnnouncement(announcementType: string, message: string, team: Owner?, countdown: number?): ()
	Network.Domination.broadcastAnnouncement({
		Type = announcementType :: any,
		Message = message,
		Team = (if team == "Raiders" then "Hostiles" else team) :: any,
		Countdown = countdown,
	})
end

local function clearDeadPresence(player: Player): ()
	for _, pt in points do
		pt.deadDefenders[player] = nil
		pt.deadRaiders[player] = nil
	end
end

local function onHumanoidDied(player: Player): ()
	if not config.DeathCapEnabled then
		return
	end

	local faction = getPlayerFaction(player)
	if not faction or faction == "Neutral" then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	for _, pt in points do
		local delta = rootPart.Position - pt.part.Position
		local horizDistSq = delta.X * delta.X + delta.Z * delta.Z
		local withinHoriz = horizDistSq <= CAPTURE_HORIZ_RANGE * CAPTURE_HORIZ_RANGE
		local withinVert = math.abs(delta.Y) <= CAPTURE_VERT_RANGE

		if withinHoriz and withinVert then
			if faction == "Defenders" then
				pt.deadDefenders[player] = true
			else
				pt.deadRaiders[player] = true
			end
		end
	end
end

local function watchCharacter(player: Player, character: Model): ()
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		return
	end

	if deathConnections[player] then
		deathConnections[player]:Disconnect()
	end

	deathConnections[player] = humanoid.Died:Connect(function()
		onHumanoidDied(player)
	end)

	clearDeadPresence(player)
end

local function connectPlayer(player: Player): ()
	if characterConnections[player] then
		characterConnections[player]:Disconnect()
	end

	characterConnections[player] = player.CharacterAdded:Connect(function(character: Model)
		watchCharacter(player, character)
	end)

	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
end

local function disconnectPlayer(player: Player): ()
	clearDeadPresence(player)

	if deathConnections[player] then
		deathConnections[player]:Disconnect()
		deathConnections[player] = nil
	end

	if characterConnections[player] then
		characterConnections[player]:Disconnect()
		characterConnections[player] = nil
	end
end

local function countAlivePresence(pt: PointState): (number, number)
	debug.profilebegin("Domination::countAlivePresence")

	local defCount = 0
	local raidCount = 0

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then continue end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then continue end

		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then continue end

		local delta = root.Position - pt.part.Position
		local horizSq = delta.X * delta.X + delta.Z * delta.Z
		
		if horizSq <= CAPTURE_HORIZ_RANGE * CAPTURE_HORIZ_RANGE and math.abs(delta.Y) <= CAPTURE_VERT_RANGE then
			local faction = getPlayerFaction(player)
			if faction == "Defenders" then
				defCount += 1
			elseif faction == "Raiders" then
				raidCount += 1
			end
		end
	end

	debug.profileend()
	return defCount, raidCount
end

local function updatePoint(pt: PointState, dt: number): ()
	local aliveDefenders, aliveRaiders = countAlivePresence(pt)
	pt.aliveDefenders = aliveDefenders
	pt.aliveRaiders = aliveRaiders

	local deadDef = 0
	local deadRaid = 0
	if config.DeathCapEnabled then
		for _ in pt.deadDefenders do
			deadDef += 1
		end
		for _ in pt.deadRaiders do
			deadRaid += 1
		end
	end

	local presenceDef = aliveDefenders + deadDef
	local presenceRaid = aliveRaiders + deadRaid

	if presenceDef == 0 and presenceRaid == 0 then
		pt.contested = false
		return
	end

	local function buildSpeed(aliveCount: number): number
		return DominationConfig.captureSpeed(aliveCount, config) * dt
	end

	if presenceDef > 0 and presenceRaid > 0 and aliveDefenders == aliveRaiders then
		pt.contested = true
		return
	end

	local attackingFaction: "Defenders" | "Raiders" | nil = nil
	local attackingAlive: number = 0
	local undoingAlive: number = 0

	if presenceDef > 0 and presenceRaid == 0 then
		attackingFaction = "Defenders"
		attackingAlive = aliveDefenders
	elseif presenceRaid > 0 and presenceDef == 0 then
		attackingFaction = "Raiders"
		attackingAlive = aliveRaiders
	elseif aliveDefenders > aliveRaiders then
		attackingFaction = "Defenders"
		attackingAlive = aliveDefenders
		undoingAlive = aliveRaiders
	elseif aliveRaiders > aliveDefenders then
		attackingFaction = "Raiders"
		attackingAlive = aliveRaiders
		undoingAlive = aliveDefenders
	end

	if not attackingFaction then
		pt.contested = true
		return
	end

	local isContested = undoingAlive > 0 or (presenceDef > 0 and presenceRaid > 0)
	pt.contested = isContested

	local captureTime = config.CaptureTimeSeconds
	local attackSpeed = buildSpeed(attackingAlive)

	local opposingFaction: "Defenders" | "Raiders" | nil = if attackingFaction == "Defenders" then "Raiders" else "Defenders"
	local barOwnerIsOpposing = pt.progressOwner == opposingFaction

	if barOwnerIsOpposing and pt.progress > 0 then
		pt.progress = math.max(pt.progress - attackSpeed, 0)
		if pt.progress <= 0 then
			if pt.owner == opposingFaction then
				pt.owner = nil
			end
			pt.progressOwner = nil
		end
		return
	end

	if pt.owner == attackingFaction and pt.progress >= captureTime then
		return
	end

	if pt.progressOwner ~= attackingFaction then
		pt.progressOwner = attackingFaction
	end

	pt.progress = math.min(pt.progress + attackSpeed, captureTime)

	if pt.progress >= captureTime and pt.owner ~= attackingFaction then
		pt.owner = attackingFaction
		if StatsService then
			for _, player in Players:GetPlayers() do
				local character = player.Character
				if not character then continue end
				local faction = getPlayerFaction(player)
				if faction ~= attackingFaction then continue end
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if not humanoid or humanoid.Health <= 0 then continue end
				local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not root then continue end
				local delta = root.Position - pt.part.Position
				local horizSq = delta.X * delta.X + delta.Z * delta.Z
				if horizSq <= CAPTURE_HORIZ_RANGE * CAPTURE_HORIZ_RANGE and math.abs(delta.Y) <= CAPTURE_VERT_RANGE then
					StatsService:AddCapture(player, 1)
					if shouldCountStats() then
						StatsService:AddCaptureGlobal(player)
					end
				end
			end
		end

		local teamLabel = if attackingFaction == "Defenders" then "DEFENDERS" else "HOSTILES"
		broadcastAnnouncement("POINT_CAPTURED", teamLabel .. " CAPTURED POINT " .. pt.label, attackingFaction)
		broadcastState()
	end
end

local function tickScoring(dt: number): boolean
	local defPoints = 0
	local raidPoints = 0

	for _, pt in points do
		if pt.owner == "Defenders" and not pt.contested and pt.progress >= config.CaptureTimeSeconds then
			defPoints += 1
		elseif pt.owner == "Raiders" and not pt.contested and pt.progress >= config.CaptureTimeSeconds then
			raidPoints += 1
		end
	end

	local prevDefInt = math.floor(defenderScore)
	local prevRaidInt = math.floor(hostileScore)

	defenderScore = math.min(defenderScore + defPoints * dt, config.MaxScore)
	hostileScore = math.min(hostileScore + raidPoints * dt, config.MaxScore)

	local newDefInt = math.floor(defenderScore)
	local newRaidInt = math.floor(hostileScore)

	return newDefInt ~= prevDefInt or newRaidInt ~= prevRaidInt
end

local function checkWin(): boolean
	if defenderScore >= config.MaxScore then
		return true
	end
	if hostileScore >= config.MaxScore then
		return true
	end
	return false
end

local function getTopPlayersByFaction(faction: "Defenders" | "Raiders"): Network.TeamTopPlayers
	if not StatsService then
		return { Kills = nil, Damage = nil, Heals = nil }
	end

	local DEFENDER_TEAMS = Constants.FACTIONS.DEFENDER_TEAMS
	local RAIDER_TEAMS = Constants.FACTIONS.RAIDER_TEAMS

	local leaderboard = StatsService:GetLeaderboard("Kills")
	local result: Network.TeamTopPlayers = { Kills = nil, Damage = nil, Heals = nil }
	local topKills, topDamage, topHeals = 0, 0, 0
	local isDefenderFaction = faction == "Defenders"

	for _, entry in leaderboard do
		local isMatch = if isDefenderFaction then DEFENDER_TEAMS[entry.Team] == true else RAIDER_TEAMS[entry.Team] == true
		if isMatch then
			if entry.Stats.Kills > topKills then
				topKills = entry.Stats.Kills
				result.Kills = { UserId = entry.UserId, DisplayName = entry.DisplayName, Value = entry.Stats.Kills }
			end
			if entry.Stats.Damage > topDamage then
				topDamage = entry.Stats.Damage
				result.Damage = { UserId = entry.UserId, DisplayName = entry.DisplayName, Value = entry.Stats.Damage }
			end
			if entry.Stats.Heals > topHeals then
				topHeals = entry.Stats.Heals
				result.Heals = { UserId = entry.UserId, DisplayName = entry.DisplayName, Value = entry.Stats.Heals }
			end
		end
	end

	return result
end

local function endGame(defendersWon: boolean, calledFromLoop: boolean?): ()
	if not official then return end

	local countStats = shouldCountStats()
	official = false
	if countStats and StatsService then
		StatsService:FlushPendingUpdates()
		for _, player in Players:GetPlayers() do
			local faction = getPlayerFaction(player)
			if faction and faction ~= "Neutral" then
				StatsService:AddGamesPlayed(player)
				local isWinner = (faction == "Defenders" and defendersWon) or (faction == "Raiders" and not defendersWon)
				if isWinner then
					StatsService:AddGamesWon(player)
				end
				if EconomyService then
					EconomyService:AwardMatchOutcome(player, isWinner)
				end
			end
		end
	end

	DamageProcessor.invalidateStatsCache()
	paused = true

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	if gameLoopThread and not calledFromLoop then
		task.cancel(gameLoopThread)
		gameLoopThread = nil
	end

	local defTop = getTopPlayersByFaction("Defenders")
	local raidTop = getTopPlayersByFaction("Raiders")

	Network.Domination.broadcastVictory({
		WinningTeam = if defendersWon then "Defenders" else "Hostiles",
		DefenderTopPlayers = defTop,
		HostileTopPlayers = raidTop,
		DefenderScore = math.floor(defenderScore),
		HostileScore = math.floor(hostileScore),
	})

	broadcastState()
end

local function startHeartbeat(): ()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
	end

	heartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
		if paused or not official then return end

		local stateChanged = false
		for _, pt in points do
			local oldOwner = pt.owner
			local oldContested = pt.contested
			local oldProgressOwner = pt.progressOwner
			local wasPresent = pt.aliveDefenders > 0 or pt.aliveRaiders > 0

			updatePoint(pt, dt)

			local isPresent = pt.aliveDefenders > 0 or pt.aliveRaiders > 0

			if pt.owner ~= oldOwner or pt.contested ~= oldContested or pt.progressOwner ~= oldProgressOwner then
				stateChanged = true
			elseif wasPresent ~= isPresent or math.abs(pt.progress - pt.lastBroadcastProgress) >= config.CaptureTimeSeconds * 0.02 then
				pt.lastBroadcastProgress = pt.progress
				stateChanged = true
			elseif pt.progress == 0 and pt.lastBroadcastProgress > 0 then
				pt.lastBroadcastProgress = 0
				stateChanged = true
			elseif pt.progress >= config.CaptureTimeSeconds and pt.lastBroadcastProgress < config.CaptureTimeSeconds then
				pt.lastBroadcastProgress = config.CaptureTimeSeconds
				stateChanged = true
			end
		end

		if tickScoring(dt) then
			stateChanged = true
		end

		if stateChanged then
			broadcastState()
		end

		if checkWin() then
			local defendersWon = defenderScore >= config.MaxScore
			endGame(defendersWon, false)
		end
	end)
end

local function buildPoints(): ()
	points = {}
	local folder = workspace:FindFirstChild("DominationPoints") :: Folder?
	if not folder then
		warn("[DominationService] No DominationPoints folder found in workspace")
		return
	end

	for i = 1, config.PointCount do
		local label = DominationConfig.getLabel(i)
		local part = (folder :: any)[label] or (folder :: any)[tostring(i)]
		if not part or not part:IsA("BasePart") then
			warn("[DominationService] Missing capture point part: " .. label)
			continue
		end

		part.CanQuery = false
		for _, desc in part:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.CanQuery = false
			end
		end

		table.insert(points, {
			label = label,
			part = part,
			owner = nil,
			progress = 0,
			progressOwner = nil,
			aliveDefenders = 0,
			aliveRaiders = 0,
			deadDefenders = {},
			deadRaiders = {},
			contested = false,
			lastBroadcastProgress = 0,
		})
	end
end

local function resetPoints(): ()
	for _, pt in points do
		pt.owner = nil
		pt.progress = 0
		pt.progressOwner = nil
		pt.aliveDefenders = 0
		pt.aliveRaiders = 0
		table.clear(pt.deadDefenders)
		table.clear(pt.deadRaiders)
		pt.contested = false
		pt.lastBroadcastProgress = 0
	end
end

local playerAddedConn: RBXScriptConnection? = nil
local playerRemovingConn: RBXScriptConnection? = nil

local function setupPlayerConnections(): ()
	for _, player in Players:GetPlayers() do
		connectPlayer(player)
	end

	playerAddedConn = Players.PlayerAdded:Connect(function(player: Player)
		connectPlayer(player)
	end)

	playerRemovingConn = Players.PlayerRemoving:Connect(function(player: Player)
		disconnectPlayer(player)
	end)
end

local function teardownPlayerConnections(): ()
	if playerAddedConn then
		playerAddedConn:Disconnect()
		playerAddedConn = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	for player in deathConnections do
		disconnectPlayer(player)
	end
	table.clear(deathConnections)
	table.clear(characterConnections)
end

local function respawnAllPlayers(): ()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			AvatarService:LoadCharacter(player)
		end)
	end
end

local function resetAllStats(): ()
	if StatsService then
		StatsService:ResetAllStats()
	end
end

local function startCountdown(): boolean
	for i = COUNTDOWN_TIME, 1, -1 do
		if not countingDown then
			return false
		end
		broadcastAnnouncement("RAID_STARTING", "DOMINATION STARTING IN " .. i, nil, i)

		local elapsed = 0
		while elapsed < 1 do
			task.wait(0.1)
			if not countingDown then return false end
			if not paused then
				elapsed += 0.1
			end
		end
	end
	return true
end

local function beginGame(): ()
	paused = false

	resetPoints()

	setupPlayerConnections()
	startHeartbeat()

	broadcastAnnouncement("RAID_STARTED", "DOMINATION HAS BEGUN", nil)
	broadcastState()
end

local function invokeOfficial(): ()
	if official or countingDown then return end

	paused = false
	countingDown = true
	defenderScore = 0
	hostileScore = 0

	broadcastState()

	local completed = startCountdown()
	if not completed then return end

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

	beginGame()
end

local function canUseOfficialCommand(player: Player): boolean
	if RankCache.isInGroup(player, CONTROL_GROUP_ID, CONTROL_MIN_RANK) then return true end
	if ServerUtils.isPrivateServerOwner(player) then return true end
	return false
end

local function handleChatCommand(player: Player, content: string): ()
	if not content:match("^:") then return end
	local msg = content:lower()
	if msg == ":official" then
		if not official and not countingDown and canUseOfficialCommand(player) then
			task.spawn(invokeOfficial)
		end
	end
end

local function handleControl(player: Player, payload: Network.DominationControlPayload): ()
	local permissions = checkPlayerPermissions(player)
	if not permissions.HasAccess then return end

	local action = payload.action

	if action == "start" then
		if not official and not countingDown then
			task.spawn(invokeOfficial)
		end
	elseif action == "pause" then
		if official and not paused then
			if EconomyService then
				EconomyService:FlagMatchTampered("Admin panel: Domination match paused")
			end
			DominationService:Pause()
		end
		if official and paused then
			DominationService:Unpause()
		end
	elseif action == "reset" then
		if official and EconomyService then
			EconomyService:FlagMatchTampered("Admin panel: Domination match reset")
		end
		DominationService:Reset(player.DisplayName)
	elseif action == "setMaxScore" then
		if payload.maxScore then
			if official and EconomyService then
				EconomyService:FlagMatchTampered("Admin panel: Domination max score modified")
			end
			DominationService:SetMaxScore(payload.maxScore)
		end
	elseif action == "setScores" then
		if payload.defenderScore ~= nil or payload.hostileScore ~= nil then
			if official and EconomyService then
				EconomyService:FlagMatchTampered("Admin panel: Domination scores modified")
			end
			DominationService:SetScores(payload.defenderScore, payload.hostileScore)
		end
	end
end

local function handleGetPermissions(player: Player): Network.TerminalPermissions
	return checkPlayerPermissions(player)
end

local function handleGetState(_player: Player): Network.DominationState
	return {
		Official = official,
		Paused = paused,
		CountingDown = countingDown,
		DefenderScore = math.floor(defenderScore),
		HostileScore = math.floor(hostileScore),
		MaxScore = config.MaxScore,
		Points = buildNetworkPoints(),
	}
end

function DominationService:init(): ()
	isActive = Maps.isDominationMap()
	if not isActive then
		return
	end

	config = DominationConfig.DEFAULT
	
	local configRemote = Instance.new("RemoteEvent")
	configRemote.Name = "DominationConfigRemote"
	configRemote.Parent = ReplicatedStorage

	buildPoints()
end

function DominationService:start(): ()
	if not isActive then return end

	TeamService = LazyService.create(MainModule, "TeamService")()
	StatsService = LazyService.create(MainModule, "StatsService")()
	EconomyService = LazyService.create(MainModule, "EconomyService")()

	chatConnection = Network.Chat.onCommandReceived(handleChatCommand)
	controlConnection = Network.Domination.onControl(handleControl)
	Network.Domination.onGetPermissions(handleGetPermissions)
	Network.Domination.onGetState(handleGetState)
	
	local configRemote = ReplicatedStorage:FindFirstChild("DominationConfigRemote") :: RemoteEvent?
	if configRemote then
		configRemote.OnServerEvent:Connect(function(player: Player, payload: any)
			if typeof(payload) ~= "table" then return end
			
			local permissions = checkPlayerPermissions(player)
			if not permissions.HasAccess then return end

			if official and EconomyService then
				EconomyService:FlagMatchTampered("Admin remote: Domination point timings modified")
			end

			if typeof(payload.CaptureTimeSeconds) == "number" then
				config.CaptureTimeSeconds = payload.CaptureTimeSeconds
			end
			if typeof(payload.SpeedBonusPerPlayer) == "number" then
				config.SpeedBonusPerPlayer = payload.SpeedBonusPerPlayer
			end
			if typeof(payload.SpeedBonusMaxPlayers) == "number" then
				config.SpeedBonusMaxPlayers = payload.SpeedBonusMaxPlayers
			end
		end)
	end
end

function DominationService:IsOfficial(): boolean
	return official
end

function DominationService:IsPaused(): boolean
	return paused
end

function DominationService:GetState(): Network.DominationState
	return {
		Official = official,
		Paused = paused,
		CountingDown = countingDown,
		DefenderScore = math.floor(defenderScore),
		HostileScore = math.floor(hostileScore),
		MaxScore = config.MaxScore,
		Points = buildNetworkPoints(),
	}
end

function DominationService:Pause(): ()
	if not official then return end
	paused = true
	broadcastAnnouncement("RAID_STARTING", "DOMINATION HAS BEEN PAUSED", nil)
	broadcastState()
end

function DominationService:Unpause(): ()
	if not official then return end
	paused = false
	broadcastAnnouncement("RAID_STARTED", "DOMINATION HAS BEEN UNPAUSED", nil)
	broadcastState()
end

function DominationService:Reset(playerName: string?): ()
	official = false
	DamageProcessor.invalidateStatsCache()

	paused = true
	countingDown = false
	defenderScore = 0
	hostileScore = 0

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if gameLoopThread then
		task.cancel(gameLoopThread)
		gameLoopThread = nil
	end

	teardownPlayerConnections()
	resetPoints()
	respawnAllPlayers()
	task.wait(RESPAWN_SETTLE_DELAY)
	resetAllStats()

	if playerName then
		broadcastAnnouncement("RAID_STARTING", playerName .. " HAS RESET DOMINATION", nil)
	end

	broadcastState()
end

function DominationService:SetMaxScore(newMax: number): ()
	config = {
		PointCount = config.PointCount,
		CaptureTimeSeconds = config.CaptureTimeSeconds,
		SpeedBonusPerPlayer = config.SpeedBonusPerPlayer,
		SpeedBonusMaxPlayers = config.SpeedBonusMaxPlayers,
		DeathCapEnabled = config.DeathCapEnabled,
		MaxScore = math.clamp(newMax, 100, 100000),
	}
	broadcastState()
end

function DominationService:SetScores(newDef: number?, newRaid: number?): ()
	if newDef ~= nil then
		defenderScore = math.clamp(newDef, 0, config.MaxScore)
	end
	if newRaid ~= nil then
		hostileScore = math.clamp(newRaid, 0, config.MaxScore)
	end
	broadcastState()
end

function DominationService:Cleanup(): ()
	if chatConnection then
		chatConnection:Disconnect()
		chatConnection = nil
	end
	if controlConnection then
		controlConnection:Disconnect()
		controlConnection = nil
	end
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if gameLoopThread then
		task.cancel(gameLoopThread)
		gameLoopThread = nil
	end
	teardownPlayerConnections()

	isActive = false
end

return DominationService

