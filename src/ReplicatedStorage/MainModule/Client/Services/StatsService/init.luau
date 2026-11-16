--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local StatsConfig = require(MainModule.Shared.Config.Stats.StatsConfig)
local Signal = require(MainModule.Shared.Utils.State.Signal)

type PlayerStats = StatsConfig.PlayerStats
type LeaderboardEntry = StatsConfig.LeaderboardEntry
type SortField = StatsConfig.SortField
type LeaderboardResponse = Network.LeaderboardResponse

local StatsService = {}
StatsService.Name = "StatsService"

local player = Players.LocalPlayer
local isInitialized = false

local cachedStats: PlayerStats? = nil
local cachedLeaderboard: { LeaderboardEntry }? = nil
local cachedSortBy: SortField = "Kills"
local localLeaderboardEntry: LeaderboardEntry? = nil
local cachedLocalRank: number? = nil

local statsChanged = Signal.new()
local leaderboardChanged = Signal.new()
local updateConnection: { Disconnect: () -> () }? = nil
local deltaBatchConnection: { Disconnect: () -> () }? = nil

local function cacheLocalLeaderboardEntry(): ()
	localLeaderboardEntry = nil
	cachedLocalRank = nil
	if not cachedLeaderboard then return end
	for i, entry in cachedLeaderboard do
		if entry.UserId == player.UserId then
			localLeaderboardEntry = entry
			cachedLocalRank = i
			return
		end
	end
end

local function notifyStatsChanged(): ()
	if not cachedStats then
		return
	end
	statsChanged:Fire(cachedStats)
end

local function notifyLeaderboardChanged(): ()
	if not cachedLeaderboard then
		return
	end
	leaderboardChanged:Fire(cachedLeaderboard)
end

local function onLocalStatChanged(statType: string, newValue: number): ()
	if not cachedStats then
		cachedStats = StatsConfig.createDefaultStats()
	end
	(cachedStats :: any)[statType] = newValue
	notifyStatsChanged()

	if localLeaderboardEntry then
		(localLeaderboardEntry.Stats :: any)[statType] = newValue
		notifyLeaderboardChanged()
	end
end

function StatsService:init(): ()
	isInitialized = true
end

function StatsService:start(): ()
	if not isInitialized then
		self:init()
	end

	updateConnection = Network.Stats.onStatsUpdated(function(data)
		if data.resetAll then
			cachedStats = StatsConfig.createDefaultStats()
			if cachedLeaderboard then
				for _, entry in cachedLeaderboard do
					entry.Stats = StatsConfig.createDefaultStats()
				end
				notifyLeaderboardChanged()
			end
			notifyStatsChanged()
			return
		end

		if data.userId ~= player.UserId then
			return
		end

		if data.reset then
			cachedStats = StatsConfig.createDefaultStats()
			notifyStatsChanged()
			return
		end

		if data.stats then
			cachedStats = data.stats
			notifyStatsChanged()
		end
	end)

	deltaBatchConnection = Network.Stats.onStatDeltaBatch(function(userId: number, statType: string, newValue: number)
		if userId ~= player.UserId then return end
		onLocalStatChanged(statType, newValue)
	end)
end

function StatsService:GetStats(): PlayerStats
	if cachedStats then
		return cachedStats
	end
	return StatsConfig.createDefaultStats()
end

function StatsService:GetStatsAsync(): PlayerStats
	if cachedStats then
		return cachedStats
	end
	return StatsConfig.createDefaultStats()
end

function StatsService:GetStat(statType: string): number
	local stats = self:GetStats()
	if StatsConfig.isValidStatType(statType) then
		return (stats :: any)[statType] or 0
	end
	return 0
end

function StatsService:GetPlayerStats(userId: number): PlayerStats?
	return Network.Stats.getPlayerStats(userId)
end

function StatsService:GetLeaderboard(sortBy: SortField?): { LeaderboardEntry }
	local sort: SortField = sortBy or cachedSortBy

	local response = Network.Stats.getLeaderboard(sort)
	if response then
		cachedLeaderboard = response.entries
		cachedSortBy = response.sortedBy
		cacheLocalLeaderboardEntry()
		return response.entries
	end

	return cachedLeaderboard or {}
end

function StatsService:GetCachedLeaderboard(): { LeaderboardEntry }?
	return cachedLeaderboard
end

function StatsService:RefreshStats(): PlayerStats?
	return cachedStats
end

function StatsService:RefreshLeaderboard(sortBy: SortField?): { LeaderboardEntry }?
	Network.Stats.invalidateCache()
	local response = Network.Stats.getLeaderboard(sortBy or cachedSortBy)
	if response then
		cachedLeaderboard = response.entries
		cachedSortBy = response.sortedBy
		cacheLocalLeaderboardEntry()
		notifyLeaderboardChanged()
		return response.entries
	end
	return nil
end

function StatsService:OnStatsChanged(callback: (stats: PlayerStats) -> ()): () -> ()
	local connection = statsChanged:Connect(callback)

	if cachedStats then
		task.spawn(callback, cachedStats)
	end

	return function()
		connection:Disconnect()
	end
end

function StatsService:OnLeaderboardChanged(callback: (entries: { LeaderboardEntry }) -> ()): () -> ()
	local connection = leaderboardChanged:Connect(callback)

	if cachedLeaderboard then
		task.spawn(callback, cachedLeaderboard)
	end

	return function()
		connection:Disconnect()
	end
end

function StatsService:GetTotalScore(): number
	return StatsConfig.getTotal(self:GetStats())
end

function StatsService:GetRank(sortBy: SortField?): number?
	if (not sortBy or sortBy == cachedSortBy) and cachedLocalRank then
		return cachedLocalRank
	end
	local leaderboard = self:GetLeaderboard(sortBy)
	for i, entry in leaderboard do
		if entry.UserId == player.UserId then
			return i
		end
	end
	return nil
end

function StatsService:Cleanup(): ()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end
	if deltaBatchConnection then
		deltaBatchConnection:Disconnect()
		deltaBatchConnection = nil
	end
	statsChanged:Destroy()
	leaderboardChanged:Destroy()
	statsChanged = Signal.new()
	leaderboardChanged = Signal.new()
	cachedStats = nil
	cachedLeaderboard = nil
	localLeaderboardEntry = nil
	cachedLocalRank = nil
	isInitialized = false
end

return StatsService
