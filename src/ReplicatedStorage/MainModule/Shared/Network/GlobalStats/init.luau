--!strict
--!native
--!optimize 2

local Types = require(script.Types)

export type PlayerGlobalStats = Types.PlayerGlobalStats

local NOOP_CONNECTION = { Disconnect = function() end }

local GlobalStatsNetwork = {}

local statsCache: { [number]: PlayerGlobalStats } = {}
local statsCacheTime: { [number]: number } = {}
local cacheOrder: { number } = {}
local CACHE_TTL = 30
local MAX_CACHE_SIZE = 100

local function evictEntry(): ()
	local count = #cacheOrder
	if count > 0 then
		local evictedUserId = cacheOrder[1]
		if count > 1 then
			cacheOrder[1] = cacheOrder[count]
		end
		cacheOrder[count] = nil
		if evictedUserId then
			statsCache[evictedUserId] = nil
			statsCacheTime[evictedUserId] = nil
		end
	end
end

function GlobalStatsNetwork.getPlayerGlobalStats(userId: number): PlayerGlobalStats?
	local now = os.clock()
	local cached = statsCache[userId]
	local cacheTime = statsCacheTime[userId]

	if cached and cacheTime and (now - cacheTime) < CACHE_TTL then
		return cached
	end

	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.GlobalStats.GetPlayerStats.Invoke, userId)

	if success and result then
		if not statsCache[userId] then
			if #cacheOrder >= MAX_CACHE_SIZE then
				evictEntry()
			end
			table.insert(cacheOrder, userId)
		end
		statsCache[userId] = result
		statsCacheTime[userId] = now
		return result
	end

	return nil
end

function GlobalStatsNetwork.onGetPlayerGlobalStats(callback: (player: Player, targetUserId: number) -> PlayerGlobalStats?): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.GlobalStats.GetPlayerStats.On(callback)
	return NOOP_CONNECTION
end

function GlobalStatsNetwork.invalidateCache(userId: number?): ()
	if userId then
		statsCache[userId] = nil
		statsCacheTime[userId] = nil
		local count = #cacheOrder
		for i = count, 1, -1 do
			if cacheOrder[i] == userId then
				if i < count then
					cacheOrder[i] = cacheOrder[count]
				end
				cacheOrder[count] = nil
				break
			end
		end
	else
		table.clear(statsCache)
		table.clear(statsCacheTime)
		table.clear(cacheOrder)
	end
end

function GlobalStatsNetwork.init(): ()
end

return GlobalStatsNetwork
