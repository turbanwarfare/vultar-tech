--!strict
--!native
--!optimize 2

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local MainModule = script.Parent.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local SparConfig = require(MainModule.Shared.Config.SparConfig)
local Constants = require(MainModule.Shared.Config.Constants)
local RankCache = require(MainModule.Server.Cache.RankCache)

local ArenaLeaderboardService = {}
local version = SparConfig.DATA_VERSION or ""



local leaderboardCache = {}
local CACHE_DURATION = 60

local usernameCache: { [number]: string } = {}

local function getUsername(userId: number): string
	if usernameCache[userId] then
		return usernameCache[userId]
	end
	local onlinePlayer = Players:GetPlayerByUserId(userId)
	if onlinePlayer then
		usernameCache[userId] = onlinePlayer.Name
		return onlinePlayer.Name
	end
	local success, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if success and name then
		usernameCache[userId] = name
		return name
	end
	return "Player"
end

local function normalizeScope(scope: string): string
	local s = scope:lower()
	if s == "all-time" or s == "alltime" then
		return "AllTime"
	elseif s == "monthly" then
		return "Monthly"
	elseif s == "daily" then
		return "Daily"
	end
	return "AllTime"
end

local function getMinScore(stat: string, scopeName: string): number
	if not SparConfig or not SparConfig.LeaderboardParts then
		return 0
	end
	local normalizedScope = normalizeScope(scopeName)
	for _, config in pairs(SparConfig.LeaderboardParts) do
		if config.Stat == stat then
			if config.MinimumScore and config.MinimumScore[normalizedScope] then
				return config.MinimumScore[normalizedScope]
			end
		end
	end
	return 0
end

function ArenaLeaderboardService.GetLeaderboard(stat: string, scopeName: string): { any }
	local normalizedStat = stat

	if stat ~= "Wins" and stat ~= "Kills" and stat ~= "Damage" then
		return {}
	end

	local normalizedScope = normalizeScope(scopeName)
	local storeName = "SparLeaderboard_" .. normalizedStat .. "_" .. normalizedScope
	if normalizedScope == "Monthly" then
		storeName = storeName .. "_" .. os.date("%Y_%m")
	elseif normalizedScope == "Daily" then
		storeName = storeName .. "_" .. os.date("%Y_%m_%d")
	end
	storeName = storeName .. version

	local cached = leaderboardCache[storeName]
	if cached and (os.time() - cached.timestamp < CACHE_DURATION) then
		return cached.data
	end

	local store = DataStoreService:GetOrderedDataStore(storeName)
	local success, pages = pcall(function()
		return store:GetSortedAsync(false, 100)
	end)

	local list = {}
	local minScore = getMinScore(stat, scopeName)

	if success and pages then
		local entries = pages:GetCurrentPage()
		local rank = 0
		for _, data in ipairs(entries) do
			local score = data.value
			if score >= minScore then
				rank += 1
				local userId = tonumber(data.key) or 0
				local username = getUsername(userId)
				table.insert(list, {
					Rank = rank,
					UserId = userId,
					Username = username,
					Score = score,
				})
			end
		end
	end

	if success then
		leaderboardCache[storeName] = {
			timestamp = os.time(),
			data = list,
		}
	end

	return list
end

local function isEligibleForLeaderboard(player: Player): boolean
	local isVultar = RankCache.isInGroup(player, Constants.GROUPS.VULTAR, 1)
	local isVia = RankCache.isInGroup(player, Constants.GROUPS.VIA, 1)
	return isVultar or isVia
end



function ArenaLeaderboardService.UpdatePlayerStats(player: Player, history: any)
	local userId = tostring(player.UserId)
	local isEligible = isEligibleForLeaderboard(player)
	local statsMap = {
		Wins = "MatchesWon",
		Kills = "Kills",
		Damage = "Damage",
	}

	for statKey, internalName in pairs(statsMap) do
		local allTimeVal = history.AllTime[internalName] or 0
		task.spawn(pcall, function()
			local store = DataStoreService:GetOrderedDataStore("SparLeaderboard_" .. statKey .. "_AllTime" .. version)
			pcall(function()
				if isEligible then
					store:SetAsync(userId, allTimeVal)
				else
					store:RemoveAsync(userId)
				end
			end)
		end)

		local monthlyVal = history.LastMonth[internalName] or 0
		task.spawn(pcall, function()
			local monthStr = os.date("%Y_%m")
			local store = DataStoreService:GetOrderedDataStore("SparLeaderboard_" .. statKey .. "_Monthly_" .. monthStr .. version)
			pcall(function()
				if isEligible then
					store:SetAsync(userId, monthlyVal)
				else
					store:RemoveAsync(userId)
				end
			end)
		end)

		local dailyVal = history.LastDay and history.LastDay[internalName] or 0
		task.spawn(pcall, function()
			local dayStr = os.date("%Y_%m_%d")
			local store = DataStoreService:GetOrderedDataStore("SparLeaderboard_" .. statKey .. "_Daily_" .. dayStr .. version)
			pcall(function()
				if isEligible then
					store:SetAsync(userId, dailyVal)
				else
					store:RemoveAsync(userId)
				end
			end)
		end)
	end
end

function ArenaLeaderboardService.start()
	Network.Spar.registerGetLeaderboard(function(_player: Player, stat: string, scopeName: string)
		return ArenaLeaderboardService.GetLeaderboard(stat, scopeName)
	end)
end

function ArenaLeaderboardService.stop() end

function ArenaLeaderboardService.cleanup()
	table.clear(usernameCache)
end

return ArenaLeaderboardService
