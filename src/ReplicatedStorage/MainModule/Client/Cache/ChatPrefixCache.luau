--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local ChatConfig = require(MainModule.Shared.Config.Chat.ChatConfig)
local ChatTypes = require(MainModule.Shared.Network.Chat.Types)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

type PlayerChatData = ChatTypes.PlayerChatData

local ChatPrefixCache = {}

local getChatService = LazyService.create(MainModule, "ChatService")
local cachedPrefix: string? = nil

function ChatPrefixCache.get(): PlayerChatData?
	local chatSvc = getChatService()
	if chatSvc then
		return chatSvc:GetPlayerData()
	end
	return nil
end

function ChatPrefixCache.getPrefix(): string
	if cachedPrefix then
		return cachedPrefix
	end

	local data = ChatPrefixCache.get()

	local localPlayer = Players.LocalPlayer
	local displayName = localPlayer and localPlayer.DisplayName or "Player"

	if not data then
		return displayName .. ":"
	end

	local parts: { string } = {}

	for _, tagId in data.tags do
		local tagConfig = ChatConfig.getTagConfig(tagId)
		if tagConfig then
			table.insert(parts, `[{tagConfig.text}]`)
		end
	end

	if data.rolePrefix and data.rolePrefix ~= "" then
		table.insert(parts, `[{data.rolePrefix}]`)
	end

	table.insert(parts, `{displayName}:`)
	cachedPrefix = table.concat(parts, " ")

	return cachedPrefix
end

function ChatPrefixCache.clear(): ()
	cachedPrefix = nil
end

return ChatPrefixCache
