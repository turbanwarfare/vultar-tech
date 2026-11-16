--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local RankCache = {}

local CACHE_TTL = 300

local playerRankCache: { [Player]: { [number]: { rank: number, timestamp: number } } } = {}
local cleanupConnection: RBXScriptConnection? = nil

function RankCache.getPlayerRank(player: Player, groupId: number): number
	local playerCache = playerRankCache[player]
	if not playerCache then
		playerCache = {}
		playerRankCache[player] = playerCache
	end

	local cached = playerCache[groupId]
	local now = os.clock()

	if cached and (now - cached.timestamp) < CACHE_TTL then
		return cached.rank
	end

	local success, rank = pcall(function()
		return player:GetRankInGroupAsync(groupId)
	end)

	local result = if success then rank else 0

	if success then
		playerCache[groupId] = { rank = result, timestamp = now }
	end

	return result
end

function RankCache.isInGroup(player: Player, groupId: number, minRank: number?): boolean
	local rank = RankCache.getPlayerRank(player, groupId)
	if rank == 0 then
		return false
	end
	if minRank and minRank > 0 then
		return rank >= minRank
	end
	return true
end

function RankCache.clearPlayerCache(player: Player): ()
	playerRankCache[player] = nil
end

function RankCache.refreshPlayerRank(player: Player, groupId: number): number
	local playerCache = playerRankCache[player]
	if playerCache then
		playerCache[groupId] = nil
	end
	return RankCache.getPlayerRank(player, groupId)
end

cleanupConnection = Players.PlayerRemoving:Connect(function(player: Player)
	RankCache.clearPlayerCache(player)
end)

function RankCache.cleanup(): ()
	if cleanupConnection then
		cleanupConnection:Disconnect()
		cleanupConnection = nil
	end
	table.clear(playerRankCache)
end

return RankCache
