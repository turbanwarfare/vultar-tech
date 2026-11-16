--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ServerConfig = require(script.Parent.ServerConfig)

local CACHE_SECONDS = 60

local cache: { [number]: { allowed: boolean, t: number } } = {}

local Auth = {}

function Auth.isAuthorized(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(ServerConfig.StaffWhitelist, player.UserId) then
		return true
	end

	local now = os.clock()
	local cached = cache[player.UserId]
	if cached and now - cached.t < CACHE_SECONDS then
		return cached.allowed
	end

	local allowed = false
	for _, permission in ServerConfig.AllowedGroups do
		local ok, rank = pcall(player.GetRankInGroup, player, permission.GroupId)
		if ok and rank >= permission.MinRank then
			allowed = true
			break
		end
	end
	cache[player.UserId] = { allowed = allowed, t = now }
	return allowed
end

Players.PlayerRemoving:Connect(function(player)
	cache[player.UserId] = nil
end)

return Auth
