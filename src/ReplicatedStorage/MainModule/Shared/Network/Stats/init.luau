--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local Types = require(script.Types)

local Shared = script.Parent.Parent
local StatsConfig = require(Shared.Config.Stats.StatsConfig)

export type PlayerStats = Types.PlayerStats
export type LeaderboardEntry = Types.LeaderboardEntry
export type LeaderboardResponse = Types.LeaderboardResponse
export type StatsUpdateData = Types.StatsUpdateData
export type StatsUpdateDataCompact = Types.StatsUpdateDataCompact
export type SortField = Types.SortField
export type StatTypeId = Types.StatTypeId

local StatsNetwork = {}
local NOOP_CONNECTION = { Disconnect = function() end }

local cachedStats: PlayerStats? = nil
local statsCached = false
local leaderboardCache: LeaderboardResponse? = nil
local leaderboardCacheTime = 0
local LEADERBOARD_CACHE_TTL = 2

local deltaBatchCallbacks: { (userId: number, statType: string, newValue: number) -> () } = {}
local deltaBatchRegistered = false

function StatsNetwork.getStats(): PlayerStats?
	if statsCached and cachedStats then
		return cachedStats
	end

	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Stats.GetStats.Invoke)
	if success and result then
		cachedStats = result
		statsCached = true
		return result
	end
	return nil
end

function StatsNetwork.onGetStats(callback: (player: Player) -> PlayerStats?): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Stats.GetStats.On(callback)
	return NOOP_CONNECTION
end

function StatsNetwork.getPlayerStats(userId: number): PlayerStats?
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Stats.GetPlayerStats.Invoke, userId)
	if success and result then
		return result
	end
	return nil
end

function StatsNetwork.onGetPlayerStats(callback: (player: Player, targetUserId: number) -> PlayerStats?): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Stats.GetPlayerStats.On(callback)
	return NOOP_CONNECTION
end

function StatsNetwork.getLeaderboard(sortBy: SortField?): LeaderboardResponse?
	local now = os.clock()
	if leaderboardCache and (now - leaderboardCacheTime) < LEADERBOARD_CACHE_TTL then
		return leaderboardCache
	end

	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Stats.GetLeaderboard.Invoke, sortBy or "Kills")
	if success and result then
		leaderboardCache = result
		leaderboardCacheTime = now
		return result
	end
	return nil
end

function StatsNetwork.onGetLeaderboard(callback: (player: Player, sortBy: SortField) -> LeaderboardResponse?): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Stats.GetLeaderboard.On(callback)
	return NOOP_CONNECTION
end

function StatsNetwork.broadcastStatsUpdate(player: Player, data: StatsUpdateData): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Stats.Updated.Fire(player, data)
end

function StatsNetwork.broadcastStatsUpdateAll(data: { [string]: any }): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Stats.Updated.FireAll(data)
end

function StatsNetwork.broadcastStatDeltaCompact(userId: number, statTypeId: StatTypeId, newValue: number): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Stats.Delta.FireAll(userId, statTypeId, newValue)
end

function StatsNetwork.onStatDeltaCompact(callback: (userId: number, statType: string, newValue: number) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	local localPlayer = Players.LocalPlayer
	Blink.Stats.Delta.On(function(userId: number, statTypeId: number, newValue: number)
		local statType = StatsConfig.getStatTypeName(statTypeId)
		if statType and cachedStats and localPlayer and userId == localPlayer.UserId then
			(cachedStats :: any)[statType] = newValue
		end
		if statType then
			callback(userId, statType, newValue)
		end
	end)
	return NOOP_CONNECTION
end

function StatsNetwork.broadcastStatDeltaBatch(batch: { { userId: number, statType: number, value: number } }): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Stats.DeltaBatch.FireAll(batch)
end

function StatsNetwork.onStatDeltaBatch(callback: (userId: number, statType: string, newValue: number) -> ()): { Disconnect: () -> () }
	table.insert(deltaBatchCallbacks, callback)

	if not deltaBatchRegistered then
		deltaBatchRegistered = true
		local Blink = require(script.Parent.Generated.Client)
		local localPlayer = Players.LocalPlayer
		Blink.Stats.DeltaBatch.On(function(batch: any)
			for _, entry in batch do
				local statType = StatsConfig.getStatTypeName(entry.statType)
				if not statType then continue end
				if cachedStats and localPlayer and entry.userId == localPlayer.UserId then
					(cachedStats :: any)[statType] = entry.value
				end
				for _, cb in deltaBatchCallbacks do
					cb(entry.userId, statType, entry.value)
				end
			end
		end)
	end

	return {
		Disconnect = function()
			local index = table.find(deltaBatchCallbacks, callback)
			if not index then return end
			local lastIndex = #deltaBatchCallbacks
			if index < lastIndex then
				deltaBatchCallbacks[index] = deltaBatchCallbacks[lastIndex]
			end
			deltaBatchCallbacks[lastIndex] = nil
		end,
	}
end

local statsUpdatedCallbacks: { (data: any) -> () } = {}
local statsUpdatedRegistered = false

function StatsNetwork.onStatsUpdated(callback: (data: any) -> ()): { Disconnect: () -> () }
	table.insert(statsUpdatedCallbacks, callback)

	if not statsUpdatedRegistered then
		statsUpdatedRegistered = true
		local Blink = require(script.Parent.Generated.Client)
		local localPlayer = Players.LocalPlayer
		Blink.Stats.Updated.On(function(data: any)
			if data and data.stats and localPlayer and data.userId == localPlayer.UserId then
				cachedStats = data.stats
			end
			for _, cb in statsUpdatedCallbacks do
				cb(data)
			end
		end)
	end

	return {
		Disconnect = function()
			local index = table.find(statsUpdatedCallbacks, callback)
			if not index then return end
			local lastIndex = #statsUpdatedCallbacks
			if index < lastIndex then
				statsUpdatedCallbacks[index] = statsUpdatedCallbacks[lastIndex]
			end
			statsUpdatedCallbacks[lastIndex] = nil
		end,
	}
end

function StatsNetwork.invalidateCache(): ()
	statsCached = false
	cachedStats = nil
	leaderboardCache = nil
end

function StatsNetwork.init(): ()
end

return StatsNetwork
