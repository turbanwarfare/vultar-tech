--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local Types = require(script.Types)

export type ChannelId = Types.ChannelId
export type ChannelConfig = Types.ChannelConfig
export type TagConfig = Types.TagConfig
export type ChatMessage = Types.ChatMessage
export type PlayerChatData = Types.PlayerChatData
export type SystemMessage = Types.SystemMessage
export type PlayerMeta = Types.PlayerMeta

local ChatNetwork = {}

local NOOP_CONNECTION = { Disconnect = function() end }

local cachedPlayerCount = 0
local lastPlayerCountCache = 0
local PLAYER_COUNT_CACHE_TTL = 1

local function getCachedPlayerCount(): number
	local now = os.clock()
	if now - lastPlayerCountCache > PLAYER_COUNT_CACHE_TTL then
		cachedPlayerCount = #Players:GetPlayers()
		lastPlayerCountCache = now
	end
	return cachedPlayerCount
end

local function fireToRecipients<T...>(recipients: { Player }, fireAll: (T...) -> (), fireOne: (Player, T...) -> (), ...: T...): ()
	local recipientCount = #recipients
	local totalPlayers = getCachedPlayerCount()

	if recipientCount >= totalPlayers and totalPlayers > 0 then
		fireAll(...)
	else
		for _, player in recipients do
			fireOne(player, ...)
		end
	end
end

function ChatNetwork.broadcastSystemChatMessage(recipients: { Player }, message: ChatMessage): ()
	local Blink = require(script.Parent.Generated.Server)
	fireToRecipients(recipients, Blink.Chat.SystemChatMessage.FireAll, Blink.Chat.SystemChatMessage.Fire, message)
end

function ChatNetwork.onSystemChatMessage(callback: (message: ChatMessage) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Chat.SystemChatMessage.On(callback)
	return NOOP_CONNECTION
end

function ChatNetwork.switchChannel(channelId: ChannelId): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Chat.SwitchChannel.Fire(channelId)
end

function ChatNetwork.onChannelSwitched(callback: (player: Player, channelId: ChannelId) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Chat.SwitchChannel.On(callback)
	return NOOP_CONNECTION
end

function ChatNetwork.sendCommand(text: string): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Chat.Command.Fire(text)
end

local commandCallbacks: { (player: Player, text: string) -> () } = {}
local commandHandlerRegistered = false

function ChatNetwork.onCommandReceived(callback: (player: Player, text: string) -> ()): { Disconnect: () -> () }
	table.insert(commandCallbacks, callback)

	if not commandHandlerRegistered then
		commandHandlerRegistered = true
		local Blink = require(script.Parent.Generated.Server)
		Blink.Chat.Command.On(function(player: Player, text: string)
			for _, cb in commandCallbacks do
				task.spawn(cb, player, text)
			end
		end)
	end

	return {
		Disconnect = function()
			local index = table.find(commandCallbacks, callback)
			if not index then
				return
			end
			local lastIndex = #commandCallbacks
			if index < lastIndex then
				commandCallbacks[index] = commandCallbacks[lastIndex]
			end
			commandCallbacks[lastIndex] = nil
		end,
	}
end

function ChatNetwork.getPlayerData(): PlayerChatData?
	local Blink = require(script.Parent.Generated.Client)
	return Blink.Chat.GetPlayerData.Invoke()
end

function ChatNetwork.onGetPlayerData(callback: (player: Player) -> PlayerChatData): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Chat.GetPlayerData.On(callback)
	return NOOP_CONNECTION
end

function ChatNetwork.getPlayerMeta(): { PlayerMeta }
	local Blink = require(script.Parent.Generated.Client)
	return Blink.Chat.GetPlayerMeta.Invoke() or {}
end

function ChatNetwork.onGetPlayerMeta(callback: (player: Player) -> { PlayerMeta }): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Chat.GetPlayerMeta.On(callback)
	return NOOP_CONNECTION
end

function ChatNetwork.broadcastPlayerMeta(recipients: { Player }, entries: { PlayerMeta }): ()
	local Blink = require(script.Parent.Generated.Server)
	fireToRecipients(recipients, Blink.Chat.PlayerMeta.FireAll, Blink.Chat.PlayerMeta.Fire, entries)
end

function ChatNetwork.onPlayerMeta(callback: (entries: { PlayerMeta }) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Chat.PlayerMeta.On(callback)
	return NOOP_CONNECTION
end

function ChatNetwork.requestWhisperChannel(targetUserId: number): string?
	local Blink = require(script.Parent.Generated.Client)
	return Blink.Chat.RequestWhisperChannel.Invoke(targetUserId)
end

function ChatNetwork.onWhisperChannelRequested(callback: (player: Player, targetUserId: number) -> string?): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Chat.RequestWhisperChannel.On(callback)
	return NOOP_CONNECTION
end

function ChatNetwork.getSystemHistory(channelId: ChannelId): { ChatMessage }
	local Blink = require(script.Parent.Generated.Client)
	return Blink.Chat.GetSystemHistory.Invoke(channelId) or {}
end

function ChatNetwork.onGetSystemHistory(callback: (player: Player, channelId: ChannelId) -> { ChatMessage }): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Chat.GetSystemHistory.On(callback)
	return NOOP_CONNECTION
end

function ChatNetwork.sendSystemMessage(recipients: { Player }, message: SystemMessage): ()
	local Blink = require(script.Parent.Generated.Server)
	fireToRecipients(recipients, Blink.Chat.SystemMessage.FireAll, Blink.Chat.SystemMessage.Fire, message)
end

function ChatNetwork.onSystemMessage(callback: (message: SystemMessage) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Chat.SystemMessage.On(callback)
	return NOOP_CONNECTION
end

function ChatNetwork.setBubbleVisibility(everyone: boolean): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Chat.SetBubbleVisibility.Fire(everyone)
end

function ChatNetwork.onBubbleVisibilityChanged(callback: (player: Player, everyone: boolean) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Chat.SetBubbleVisibility.On(callback)
	return NOOP_CONNECTION
end

function ChatNetwork.sendMuteStatus(player: Player, isMuted: boolean): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Chat.MuteStatus.Fire(player, isMuted)
end

function ChatNetwork.onMuteStatusChanged(callback: (isMuted: boolean) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Chat.MuteStatus.On(callback)
	return NOOP_CONNECTION
end

function ChatNetwork.sendChannelsUpdate(player: Player, channels: { ChannelId }, switchTo: ChannelId?): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Chat.ChannelsUpdated.Fire(player, channels, switchTo)
end

function ChatNetwork.onChannelsUpdated(callback: (channels: { ChannelId }, switchTo: ChannelId?) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Chat.ChannelsUpdated.On(callback)
	return NOOP_CONNECTION
end

function ChatNetwork.init(): () end

return ChatNetwork
