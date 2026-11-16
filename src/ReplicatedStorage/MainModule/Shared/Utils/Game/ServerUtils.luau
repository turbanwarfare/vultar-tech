--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerUtils = {}

if RunService:IsServer() then
	local isPrivate = game.PrivateServerId ~= "" and game.PrivateServerId ~= nil
	local ownerId = game.PrivateServerOwnerId
	ReplicatedStorage:SetAttribute("IsPrivateServer", isPrivate)
	ReplicatedStorage:SetAttribute("PrivateServerOwnerId", ownerId)
end

function ServerUtils.isPrivateServer(): boolean
	if RunService:IsServer() then
		return game.PrivateServerId ~= "" and game.PrivateServerId ~= nil
	else
		local attr = ReplicatedStorage:GetAttribute("IsPrivateServer")
		if attr ~= nil then
			return attr == true
		end
		return game.PrivateServerId ~= "" and game.PrivateServerId ~= nil
	end
end

function ServerUtils.getPrivateServerOwnerId(): number
	if RunService:IsServer() then
		return game.PrivateServerOwnerId
	else
		local attr = ReplicatedStorage:GetAttribute("PrivateServerOwnerId")
		if attr ~= nil and typeof(attr) == "number" then
			return attr
		end
		return game.PrivateServerOwnerId
	end
end

function ServerUtils.isPrivateServerOwner(player: Player): boolean
	if not ServerUtils.isPrivateServer() then
		return false
	end
	return ServerUtils.getPrivateServerOwnerId() == player.UserId
end

return ServerUtils
