--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local LocalPlayerCache = {}

local cachedName: string = ""
local cachedDisplayName: string = ""
local cachedUserId: number = 0
local cachedLowerName: string = ""
local cachedLowerDisplayName: string = ""
local initialized = false

local function init()
	if initialized then
		return
	end

	local player = Players.LocalPlayer
	if player then
		cachedName = player.Name
		cachedDisplayName = player.DisplayName
		cachedUserId = player.UserId
		cachedLowerName = string.lower(player.Name)
		cachedLowerDisplayName = string.lower(player.DisplayName)
		initialized = true
	end
end

function LocalPlayerCache.getName(): string
	init()
	return cachedName
end

function LocalPlayerCache.getDisplayName(): string
	init()
	return cachedDisplayName
end

function LocalPlayerCache.getUserId(): number
	init()
	return cachedUserId
end

function LocalPlayerCache.getLowerName(): string
	init()
	return cachedLowerName
end

function LocalPlayerCache.getLowerDisplayName(): string
	init()
	return cachedLowerDisplayName
end

function LocalPlayerCache.getAll(): (string, string, number)
	init()
	return cachedName, cachedDisplayName, cachedUserId
end

init()

return LocalPlayerCache
