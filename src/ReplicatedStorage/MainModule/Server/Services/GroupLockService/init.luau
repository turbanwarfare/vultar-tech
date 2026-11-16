--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local GroupService = game:GetService("GroupService")
local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent
local Constants = require(MainModule.Shared.Config.Constants)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

local GroupLockService = {}
GroupLockService.Name = "GroupLockService"

local getChatService = LazyService.create(MainModule, "ChatService")

local lockedGroups: { [number]: string } = {}
local serviceConnections: { RBXScriptConnection } = {}

local function isColonelPlus(player: Player): boolean
	local ok, rank = pcall(player.GetRankInGroup, player, Constants.GROUPS.VULTAR)
	return ok and rank >= Constants.RANKS.COLONEL
end

local function canUseGroupLock(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	local isPrivateServer = game.PrivateServerId ~= ""
	if isPrivateServer then
		return game.PrivateServerOwnerId == player.UserId
	end
	return isColonelPlus(player)
end

local function sendSystemMessage(content: string, recipient: Player?): ()
	local chatService = getChatService()
	if chatService then
		chatService:SendSystemMessage(nil, content, nil, recipient)
	end
end

local function checkGroupLock(player: Player): ()
	if next(lockedGroups) == nil then
		return
	end

	if canUseGroupLock(player) or isColonelPlus(player) or RunService:IsStudio() then
		return
	end

	for groupId in lockedGroups do
		local ok, isIn = pcall(player.IsInGroup, player, groupId)
		if ok and isIn then
			return
		end
	end

	local requiredGroups: { string } = {}
	for _, name in lockedGroups do
		table.insert(requiredGroups, name)
	end
	player:Kick("This server is currently Group Locked to members of: " .. table.concat(requiredGroups, ", "))
end

function GroupLockService:HandleGroupLock(player: Player, args: string): boolean
	if not canUseGroupLock(player) then
		sendSystemMessage("[SYSTEM] Only the private server owner can use Group Lock.", player)
		return true
	end

	local groupNames: { string } = {}
	for idStr in args:gmatch("%d+") do
		local id = tonumber(idStr)
		if id then
			local success, info = pcall(GroupService.GetGroupInfoAsync, GroupService, id)
			if success and info then
				lockedGroups[id] = info.Name
				table.insert(groupNames, string.format("%s [%d]", info.Name, id))
			end
		end
	end

	if #groupNames > 0 then
		sendSystemMessage("[SYSTEM] Server has been locked to users in " .. table.concat(groupNames, ", "))
	else
		sendSystemMessage("[SYSTEM] Usage: :grouplock <groupId> [groupId2] ...", player)
	end
	return true
end

function GroupLockService:HandleUnGroupLock(player: Player, _args: string): boolean
	if not canUseGroupLock(player) then
		sendSystemMessage("[SYSTEM] Only the private server owner can use Group Lock.", player)
		return true
	end

	table.clear(lockedGroups)
	sendSystemMessage("[SYSTEM] Server has been unlocked.")
	return true
end

function GroupLockService:init(): () end

function GroupLockService:start(): ()
	table.insert(serviceConnections, Players.PlayerAdded:Connect(checkGroupLock))

	for _, player in Players:GetPlayers() do
		task.spawn(checkGroupLock, player)
	end
end

function GroupLockService:Cleanup(): ()
	for _, conn in serviceConnections do
		conn:Disconnect()
	end
	table.clear(serviceConnections)
	table.clear(lockedGroups)
end

return GroupLockService
