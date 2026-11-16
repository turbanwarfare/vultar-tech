--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local MainModule = script.Parent.Parent.Parent.Parent
local ChatConfig = require(MainModule.Shared.Config.Chat.ChatConfig)
local ChannelNames = require(MainModule.Shared.Chat.ChannelNames)

export type Binding = {
	kind: "game" | "team" | "whisper",
	name: string,
	channelId: string?,
	faction: string?,
	participants: { number }?,
}

export type MessageHandler = (message: TextChatMessage, binding: Binding) -> ()

local TextChannelClient = {}

local CHANNEL_WAIT_TIMEOUT = 20

local bindings: { [TextChannel]: Binding } = {}
local byName: { [string]: TextChannel } = {}
local connections: { [TextChannel]: RBXScriptConnection } = {}
local handler: MessageHandler? = nil
local containerConnection: RBXScriptConnection? = nil
local gameChannelIds: { [string]: boolean } = {}

for _, channel in ChatConfig.Channels do
	gameChannelIds[channel.id] = true
end

local function describe(name: string): Binding?
	local channelId = ChannelNames.gameChannelId(name)
	if channelId and gameChannelIds[channelId] then
		return { kind = "game", name = name, channelId = channelId }
	end

	local faction = ChannelNames.teamFaction(name)
	if faction then
		return { kind = "team", name = name, faction = faction }
	end

	local a, b = ChannelNames.whisperParticipants(name)
	if a and b then
		local localPlayer = Players.LocalPlayer
		if not localPlayer then
			return nil
		end
		if a ~= localPlayer.UserId and b ~= localPlayer.UserId then
			return nil
		end
		return { kind = "whisper", name = name, participants = { a, b } }
	end

	return nil
end

local function bind(instance: Instance): ()
	if not instance:IsA("TextChannel") then
		return
	end
	if connections[instance] then
		return
	end

	local binding = describe(instance.Name)
	if not binding then
		return
	end

	bindings[instance] = binding
	byName[instance.Name] = instance

	connections[instance] = instance.MessageReceived:Connect(function(message: TextChatMessage)
		local active = handler
		if active then
			active(message, binding)
		end
	end)
end

local function getContainer(): Instance?
	return TextChatService:FindFirstChild("TextChannels")
end

function TextChannelClient.start(onMessage: MessageHandler): ()
	handler = onMessage

	task.spawn(function()
		local container = TextChatService:WaitForChild("TextChannels", CHANNEL_WAIT_TIMEOUT)
		if not container then
			return
		end

		for _, child in container:GetChildren() do
			bind(child)
		end

		containerConnection = container.ChildAdded:Connect(bind)
	end)
end

function TextChannelClient.get(name: string): TextChannel?
	local cached = byName[name]
	if cached and cached.Parent then
		return cached
	end

	local container = getContainer()
	if not container then
		return nil
	end

	local instance = container:FindFirstChild(name)
	if instance and instance:IsA("TextChannel") then
		bind(instance)
		return instance
	end

	return nil
end

function TextChannelClient.await(name: string, timeout: number?): TextChannel?
	local existing = TextChannelClient.get(name)
	if existing then
		return existing
	end

	local container = TextChatService:WaitForChild("TextChannels", CHANNEL_WAIT_TIMEOUT)
	if not container then
		return nil
	end

	local instance = container:WaitForChild(name, timeout or CHANNEL_WAIT_TIMEOUT)
	if instance and instance:IsA("TextChannel") then
		bind(instance)
		return instance
	end

	return nil
end

function TextChannelClient.forChannel(channelId: string): TextChannel?
	return TextChannelClient.get(ChannelNames.forChannel(channelId))
end

function TextChannelClient.forTeam(faction: string): TextChannel?
	return TextChannelClient.get(ChannelNames.forTeam(faction))
end

function TextChannelClient.cleanup(): ()
	if containerConnection then
		containerConnection:Disconnect()
		containerConnection = nil
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(bindings)
	table.clear(byName)
	handler = nil
end

return TextChannelClient
