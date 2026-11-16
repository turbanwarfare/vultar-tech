--!strict
--!native
--!optimize 2

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local AimChamberConfig = require(MainModule.Shared.Config.AimChamberConfig)
local Network = require(MainModule.Shared.Network)

local AimChamberLeaderboardService = {}

local leaderboardCache: { [string]: { data: { any }, timestamp: number } } = {}
local CACHE_TTL = 60

local function getStoreForScope(scopeStr: string?)
	local base = AimChamberConfig.DATASTORE.LEADERBOARD_TIME_STORE
	local suffix = "AllTime"
	if scopeStr == "Monthly" or scopeStr == "MONTHLY" then
		suffix = "Monthly_" .. os.date("!%Y_%m")
	elseif scopeStr == "Daily" or scopeStr == "DAILY" then
		suffix = "Daily_" .. os.date("!%Y_%m_%d")
	end
	return DataStoreService:GetOrderedDataStore(base .. "_" .. suffix)
end

local usernameCache: { [number]: { name: string, timestamp: number } } = {}

task.spawn(function()
	while true do
		task.wait(600)
		local now = os.time()
		for id, data in usernameCache do
			if now - data.timestamp > 3600 then
				usernameCache[id] = nil
			end
		end
	end
end)

local function getUsername(userId: number): string
	local cached = usernameCache[userId]
	if cached and (os.time() - cached.timestamp) < 3600 then
		return cached.name
	end

	local online = Players:GetPlayerByUserId(userId)
	if online then
		usernameCache[userId] = { name = online.Name, timestamp = os.time() }
		return online.Name
	end

	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and name then
		usernameCache[userId] = { name = name, timestamp = os.time() }
		return name
	end
	return "Player"
end

local function formatTime(seconds: number): string
	local mins = seconds // 60
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", mins, secs)
end

function AimChamberLeaderboardService.IncrementTime(player: Player, seconds: number): ()
	if seconds <= 0 then
		return
	end
	local userId = tostring(player.UserId)
	task.spawn(function()
		local allTime = getStoreForScope("AllTime")
		local monthly = getStoreForScope("Monthly")
		local daily = getStoreForScope("Daily")
		
		pcall(function()
			allTime:IncrementAsync(userId, math.floor(seconds))
		end)
		pcall(function()
			monthly:IncrementAsync(userId, math.floor(seconds))
		end)
		pcall(function()
			daily:IncrementAsync(userId, math.floor(seconds))
		end)
		
		table.clear(leaderboardCache)
	end)
end

function AimChamberLeaderboardService.GetLeaderboard(scopeStr: string?): { any }
	local cacheKey = scopeStr or "AllTime"
	local now = os.time()
	local cached = leaderboardCache[cacheKey]
	if cached and (now - cached.timestamp) < CACHE_TTL then
		return cached.data
	end

	local store = getStoreForScope(scopeStr)
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, 100)
	end)

	local list: { any } = {}
	if ok and pages then
		local entries = pages:GetCurrentPage()
		local rank = 0
		for _, entry in ipairs(entries) do
			local raw = entry.value
			if raw and raw > 0 then
				rank += 1
				local userId = tonumber(entry.key) or 0
				local username = getUsername(userId)
				table.insert(list, {
					Rank = rank,
					UserId = userId,
					Username = username,
					Score = formatTime(raw),
				})
			end
		end
	end

	if ok then
		leaderboardCache[cacheKey] = { data = list, timestamp = now }
	end
	return list
end

function AimChamberLeaderboardService.start(): ()
	Network.AimChamber.registerGetLeaderboard(function(_player: Player, reqScope: string?)
		return AimChamberLeaderboardService.GetLeaderboard(reqScope)
	end)
end

function AimChamberLeaderboardService.cleanup(): ()
	table.clear(usernameCache)
	table.clear(leaderboardCache)
end

return AimChamberLeaderboardService
