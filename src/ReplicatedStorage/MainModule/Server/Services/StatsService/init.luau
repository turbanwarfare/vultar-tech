--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local StatsConfig = require(MainModule.Shared.Config.Stats.StatsConfig)
local Signal = require(MainModule.Shared.Utils.State.Signal)
local GlobalStatsDataStore = require(script.GlobalStatsDataStore)
local ServiceTrove = require(MainModule.Shared.Utils.Services.ServiceTrove)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local Core = require(MainModule.Shared.Network.Core)
local envEvent = Core.getOrCreateRemoteEvent("EnvironmentalKill")

type PlayerStats = StatsConfig.PlayerStats
type LeaderboardEntry = StatsConfig.LeaderboardEntry
type SortField = StatsConfig.SortField

local StatsService = {}
StatsService.Name = "StatsService"

local playerNames: { [number]: string } = {}
local playerUsernames: { [number]: string } = {}
local playerCardImageIds: { [number]: string? } = {}
local playerAnimatedCards: { [number]: boolean } = {}
local isInitialized = false

local playerStats: { [number]: PlayerStats } = {}

local sessionStatsCache: { [number]: PlayerStats } = {}
local playerLeftTimestamp: { [number]: number } = {}
local SESSION_STATS_TTL = 300

local cosmeticService: any = nil

local cachedLeaderboard: { LeaderboardEntry }? = nil
local cachedLeaderboardSortBy: SortField = "Kills"
local leaderboardDirty = true
local lastLeaderboardBuild: number = 0
local LEADERBOARD_CACHE_TTL: number = 0.5

local serviceTrove: ServiceTrove.ServiceTrove = nil :: any
local statChanged = Signal.new()
local SESSION_CLEANUP_INTERVAL = 60

type DeltaEntry = { userId: number, statType: number, value: number }

-- Deltas carry the absolute value, so only the latest value per (userId, statType) is sent.
-- pendingDeltas[userId][statTypeId] = latest value since the last flush.
local pendingDeltas: { [number]: { [number]: number } } = {}
local hasPendingDeltas = false
local DELTA_BATCH_CHUNK_SIZE = 50
local DELTA_FLUSH_INTERVAL = 0.1
local timeSinceFlush = 0

-- Entry tables are reused between flushes; Blink serializes them when FireAll is called.
local flushBatch: { DeltaEntry } = {}

local function queueDelta(userId: number, statTypeId: number, value: number): ()
	local perUser = pendingDeltas[userId]
	if not perUser then
		perUser = {}
		pendingDeltas[userId] = perUser
	end
	perUser[statTypeId] = value
	hasPendingDeltas = true
end

local function flushDeltas(): ()
	local count = 0
	for userId, perUser in pendingDeltas do
		for statTypeId, value in perUser do
			count += 1
			local entry = flushBatch[count]
			if entry then
				entry.userId = userId
				entry.statType = statTypeId
				entry.value = value
			else
				flushBatch[count] = { userId = userId, statType = statTypeId, value = value }
			end
		end
	end
	table.clear(pendingDeltas)
	hasPendingDeltas = false

	if count == 0 then
		return
	end

	for i = count + 1, #flushBatch do
		flushBatch[i] = nil
	end

	if count <= DELTA_BATCH_CHUNK_SIZE then
		Network.Stats.broadcastStatDeltaBatch(flushBatch)
	else
		for i = 1, count, DELTA_BATCH_CHUNK_SIZE do
			Network.Stats.broadcastStatDeltaBatch(table.move(flushBatch, i, math.min(i + DELTA_BATCH_CHUNK_SIZE - 1, count), 1, {}))
		end
	end
end

local function getPlayerCardInfo(player: Player): (string?, boolean)
	if not cosmeticService then
		return nil, false
	end

	local resolved = cosmeticService:GetEquippedItem(player, "PlayerCard")
	if resolved and resolved.imageId and resolved.imageId ~= "" then
		return resolved.imageId, resolved.isAnimated or false
	end
	return nil, false
end

local function invalidateLeaderboardCache(): ()
	leaderboardDirty = true
	cachedLeaderboard = nil
end

local function getPlayerStats(player: Player): PlayerStats
	local stats = playerStats[player.UserId]
	return if stats then stats else StatsConfig.createDefaultStats()
end

local function getStatsByUserId(userId: number): PlayerStats?
	return playerStats[userId]
end

local function incrementStat(player: Player, statType: string, amount: number): number
	local userId = player.UserId
	local stats = playerStats[userId]
	if not stats then
		return 0
	end

	local statTypeId = StatsConfig.getStatTypeId(statType)
	if not statTypeId then
		return 0
	end

	local oldValue = (stats :: any)[statType] :: number
	local newValue = oldValue + amount;
	(stats :: any)[statType] = newValue

	queueDelta(userId, statTypeId, newValue)

	statChanged:Fire(player, statType, oldValue, newValue)
	leaderboardDirty = true

	return newValue
end

local function setStat(player: Player, statType: string, value: number): ()
	local userId = player.UserId
	local stats = playerStats[userId]
	if not stats then
		return
	end

	local oldValue = (stats :: any)[statType] :: number
	if oldValue == value then
		return
	end

	local statTypeId = StatsConfig.getStatTypeId(statType)
	if not statTypeId then
		return
	end

	(stats :: any)[statType] = value

	queueDelta(userId, statTypeId, value)

	statChanged:Fire(player, statType, oldValue, value)
	leaderboardDirty = true
end

local function buildLeaderboard(sortBy: SortField): { LeaderboardEntry }
	local now = os.clock()
	local timeSinceLastBuild = now - lastLeaderboardBuild

	if cachedLeaderboard and cachedLeaderboardSortBy == sortBy and not leaderboardDirty then
		if timeSinceLastBuild < LEADERBOARD_CACHE_TTL then
			return cachedLeaderboard
		end
	end

	local entries: { LeaderboardEntry } = {}

	for _, player in Players:GetPlayers() do
		local userId = player.UserId
		local stats = getPlayerStats(player)
		local displayName = playerNames[userId] or player.DisplayName
		local username = playerUsernames[userId] or player.Name
		local teamName: string? = nil
		if player.Team then
			teamName = player.Team.Name
		end

		table.insert(entries, {
			UserId = userId,
			DisplayName = displayName,
			Username = username,
			Team = teamName,
			Stats = stats,
			CardImageId = playerCardImageIds[userId],
			IsAnimatedCard = playerAnimatedCards[userId] or false,
		})
	end

	if sortBy == "Total" then
		table.sort(entries, function(a, b)
			return StatsConfig.getTotal(a.Stats) > StatsConfig.getTotal(b.Stats)
		end)
	else
		table.sort(entries, function(a, b)
			return (a.Stats :: any)[sortBy] > (b.Stats :: any)[sortBy]
		end)
	end

	cachedLeaderboard = entries
	cachedLeaderboardSortBy = sortBy
	leaderboardDirty = false
	lastLeaderboardBuild = now

	return entries
end

local function onPlayerAdded(player: Player): ()
	local userId = player.UserId

	playerNames[userId] = player.DisplayName
	playerUsernames[userId] = player.Name

	GlobalStatsDataStore.loadPlayer(player)

	local initialStats: PlayerStats? = nil

	local leftTime = playerLeftTimestamp[userId]
	if leftTime and (os.clock() - leftTime) < SESSION_STATS_TTL then
		initialStats = sessionStatsCache[userId]
	end
	sessionStatsCache[userId] = nil
	playerLeftTimestamp[userId] = nil

	playerStats[userId] = initialStats or StatsConfig.createDefaultStats()
	invalidateLeaderboardCache()

	task.spawn(function()
		task.wait(0.1)
		local cardImageId, isAnimated = getPlayerCardInfo(player)
		if not cardImageId then
			task.wait(0.5)
			cardImageId, isAnimated = getPlayerCardInfo(player)
		end

		playerCardImageIds[userId] = cardImageId
		playerAnimatedCards[userId] = isAnimated

		Network.Stats.broadcastStatsUpdateAll({
			userId = userId,
			playerJoined = true,
			displayName = player.DisplayName,
			username = player.Name,
			team = if player.Team then player.Team.Name else nil,
			cardImageId = playerCardImageIds[userId],
			isAnimatedCard = playerAnimatedCards[userId],
			stats = playerStats[userId],
		})
	end)
end

local function onPlayerRemoving(player: Player): ()
	local userId = player.UserId

	local stats = playerStats[userId]
	if stats then
		sessionStatsCache[userId] = {
			Kills = stats.Kills,
			Damage = stats.Damage,
			Heals = stats.Heals,
			Captures = stats.Captures,
		}
		playerLeftTimestamp[userId] = os.clock()
		playerStats[userId] = nil
	end
	pendingDeltas[userId] = nil

	playerNames[userId] = nil
	playerUsernames[userId] = nil
	playerCardImageIds[userId] = nil
	playerAnimatedCards[userId] = nil

	invalidateLeaderboardCache()

	Network.Stats.broadcastStatsUpdateAll({
		userId = userId,
		playerLeft = true,
	})
end

local function onCosmeticChanged(player: Player, category: string, _itemId: string): ()
	if category ~= "PlayerCard" then
		return
	end

	local userId = player.UserId
	local cardImageId, isAnimated = getPlayerCardInfo(player)
	playerCardImageIds[userId] = cardImageId
	playerAnimatedCards[userId] = isAnimated
	Network.Stats.broadcastStatsUpdateAll({
		userId = userId,
		cardImageId = playerCardImageIds[userId],
		isAnimatedCard = playerAnimatedCards[userId],
		cardChanged = true,
	})
end

function StatsService:init(): ()
	GlobalStatsDataStore.create()
	isInitialized = true
end

function StatsService:start(): ()
	if not isInitialized then
		self:init()
	end

	serviceTrove = ServiceTrove.new()

	cosmeticService = LazyService.create(MainModule, "CosmeticService")()

	serviceTrove:Connect(Players.PlayerAdded, onPlayerAdded)
	serviceTrove:Connect(Players.PlayerRemoving, onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	if cosmeticService then
		serviceTrove:Add(cosmeticService:OnCosmeticChanged(onCosmeticChanged))
	end

	serviceTrove:Connect(RunService.Heartbeat, function(dt: number)
		timeSinceFlush += dt
		if not hasPendingDeltas or timeSinceFlush < DELTA_FLUSH_INTERVAL then
			return
		end
		timeSinceFlush = 0
		debug.profilebegin("StatsService::flush")
		flushDeltas()
		if leaderboardDirty then
			cachedLeaderboard = nil
		end
		debug.profileend()
	end)

	Network.Stats.onGetStats(function(player: Player)
		return getPlayerStats(player)
	end)

	Network.Stats.onGetPlayerStats(function(_player: Player, targetUserId: number)
		if type(targetUserId) ~= "number" then
			return nil
		end
		return getStatsByUserId(targetUserId)
	end)

	Network.Stats.onGetLeaderboard(function(_player: Player, sortBy: SortField)
		local validSort: SortField = "Kills"
		if sortBy == "Damage" or sortBy == "Heals" or sortBy == "Captures" or sortBy == "Total" then
			validSort = sortBy
		end

		return {
			entries = buildLeaderboard(validSort),
			sortedBy = validSort,
		}
	end)

	Network.GlobalStats.onGetPlayerGlobalStats(function(_player: Player, targetUserId: number)
		if type(targetUserId) ~= "number" then
			return nil
		end
		return GlobalStatsDataStore.getByUserId(targetUserId)
	end)

	serviceTrove:Add(task.spawn(function()
		while true do
			task.wait(SESSION_CLEANUP_INTERVAL)
			local now = os.clock()
			for userId, leftTime in playerLeftTimestamp do
				if (now - leftTime) >= SESSION_STATS_TTL then
					sessionStatsCache[userId] = nil
					playerLeftTimestamp[userId] = nil
				end
			end
		end
	end))
end

function StatsService:GetStats(player: Player): PlayerStats
	return getPlayerStats(player)
end

function StatsService:GetStatsByUserId(userId: number): PlayerStats?
	return getStatsByUserId(userId)
end

function StatsService:GetFinalStatsByUserId(userId: number): PlayerStats?
	return playerStats[userId] or sessionStatsCache[userId]
end

function StatsService:GetStat(player: Player, statType: string): number
	if not StatsConfig.isValidStatType(statType) then
		return 0
	end
	local stats = playerStats[player.UserId]
	return if stats then (stats :: any)[statType] else 0
end

function StatsService:SetStat(player: Player, statType: string, value: number): ()
	if not StatsConfig.isValidStatType(statType) then
		return
	end
	setStat(player, statType, value)
end

function StatsService:IncrementStat(player: Player, statType: string, amount: number?): number
	if not StatsConfig.isValidStatType(statType) then
		return 0
	end
	return incrementStat(player, statType, amount or 1)
end

function StatsService:AddDamage(player: Player, amount: number): number
	return incrementStat(player, "Damage", amount)
end

function StatsService:AddHeal(player: Player, amount: number): number
	return incrementStat(player, "Heals", amount)
end

function StatsService:AddKill(player: Player, amount: number?): number
	return incrementStat(player, "Kills", amount or 1)
end

function StatsService:AddCapture(player: Player, amount: number?): number
	local newValue = self:IncrementStat(player, "Captures", amount or 1)

	local teamColor = if player.Team and player.Team.TeamColor then player.Team.TeamColor.Color else Color3.fromRGB(140, 140, 140)

	envEvent:FireAllClients({
		killerName = player.Name,
		killerUserId = player.UserId,
		killerTeam = if player.Team then player.Team.Name else "Spectators",
		message = "captured the terminal",
		victimName = "",
		victimUserId = 0,
		victimTeam = "",
		killType = "terminal_capture",
		killerColor = teamColor,
	})

	return newValue
end

function StatsService:FlushPendingUpdates(): () end

function StatsService:GetLeaderboard(sortBy: SortField?): { LeaderboardEntry }
	return buildLeaderboard(sortBy or "Kills")
end

function StatsService:GetTopPlayers(sortBy: SortField?, limit: number?): { LeaderboardEntry }
	local entries = buildLeaderboard(sortBy or "Kills")
	local maxEntries = math.min(limit or 10, #entries)
	local result: { LeaderboardEntry } = {}

	for i = 1, maxEntries do
		table.insert(result, entries[i])
	end

	return result
end

function StatsService:ResetStats(player: Player): ()
	local userId = player.UserId
	local stats = playerStats[userId]
	if not stats then
		return
	end

	stats.Kills = 0
	stats.Damage = 0
	stats.Heals = 0
	stats.Captures = 0

	pendingDeltas[userId] = nil

	invalidateLeaderboardCache()

	Network.Stats.broadcastStatsUpdateAll({
		userId = userId,
		reset = true,
	})
end

function StatsService:ResetAllStats(): ()
	for _, player in Players:GetPlayers() do
		local stats = playerStats[player.UserId]
		if stats then
			stats.Kills = 0
			stats.Damage = 0
			stats.Heals = 0
			stats.Captures = 0
		end
	end

	table.clear(pendingDeltas)
	hasPendingDeltas = false

	invalidateLeaderboardCache()

	ServiceLocator.callIfExists("EconomyService", "ResetMatchParticipation")

	Network.Stats.broadcastStatsUpdateAll({
		resetAll = true,
	})
end

function StatsService:OnStatChanged(callback: (player: Player, statType: string, oldValue: number, newValue: number) -> ()): Signal.Connection
	return statChanged:Connect(callback)
end

function StatsService:GetTotalScore(player: Player): number
	return StatsConfig.getTotal(getPlayerStats(player))
end

function StatsService:AddKillGlobal(player: Player): ()
	GlobalStatsDataStore.incrementStat(player, "Kills", 1)
end

function StatsService:AddDamageGlobal(player: Player, amount: number): ()
	GlobalStatsDataStore.incrementStat(player, "Damage", amount)
end

function StatsService:AddHealGlobal(player: Player, amount: number): ()
	GlobalStatsDataStore.incrementStat(player, "Heals", amount)
end

function StatsService:AddCaptureGlobal(player: Player): ()
	GlobalStatsDataStore.incrementStat(player, "Caps", 1)
end

function StatsService:AddGamesPlayed(player: Player): ()
	GlobalStatsDataStore.incrementStat(player, "GamesPlayed", 1)
end

function StatsService:AddGamesWon(player: Player): ()
	GlobalStatsDataStore.incrementStat(player, "GamesWon", 1)
end

function StatsService:AddMVP(player: Player): ()
	GlobalStatsDataStore.incrementStat(player, "MVP", 1)
end

function StatsService:GetGlobalStats(player: Player): Network.PlayerGlobalStats?
	return GlobalStatsDataStore.get(player)
end

function StatsService:GetGlobalStatsByUserId(userId: number): Network.PlayerGlobalStats?
	return GlobalStatsDataStore.getByUserId(userId)
end

function StatsService:Cleanup(): ()
	if serviceTrove then
		serviceTrove:Destroy()
		serviceTrove = nil :: any
	end

	table.clear(pendingDeltas)
	hasPendingDeltas = false
	timeSinceFlush = 0
	table.clear(flushBatch)
	table.clear(playerStats)

	cachedLeaderboard = nil
	leaderboardDirty = true
	lastLeaderboardBuild = 0

	table.clear(playerNames)
	table.clear(playerUsernames)
	table.clear(playerCardImageIds)
	table.clear(playerAnimatedCards)
	table.clear(sessionStatsCache)
	table.clear(playerLeftTimestamp)
	GlobalStatsDataStore.cleanup()
end

return StatsService
