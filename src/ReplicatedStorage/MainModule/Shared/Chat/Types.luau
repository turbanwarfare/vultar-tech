--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local NetworkChatTypes = require(MainModule.Shared.Network.Chat.Types)

export type ChannelId = NetworkChatTypes.ChannelId
export type GlobalFilter = NetworkChatTypes.GlobalFilter
export type ChannelConfig = NetworkChatTypes.ChannelConfig
export type TagConfig = NetworkChatTypes.TagConfig
export type ChatMessage = NetworkChatTypes.ChatMessage
export type PlayerChatData = NetworkChatTypes.PlayerChatData
export type SystemMessage = NetworkChatTypes.SystemMessage

return nil
