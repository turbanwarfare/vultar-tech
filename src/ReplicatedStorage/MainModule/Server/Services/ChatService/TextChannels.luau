--!strict
--!native
--!optimize 2

local TextChatService = game:GetService("TextChatService")

local MainModule = script.Parent.Parent.Parent.Parent
local ChatConfig = require(MainModule.Shared.Config.Chat.ChatConfig)
local ChannelNames = require(MainModule.Shared.Chat.ChannelNames)

export type ChannelKind = "game" | "team" | "whisper"

export type Descriptor = {
	kind: ChannelKind,
	name: string,
	channelId: string?,
	faction: string?,
	participants: { number }?,
}

export type DeliverFn = (message: TextChatMessage, target: TextSource, descriptor: Descriptor) -> boolean

local TextChannels = {}

local gameChannels: { [string]: TextChannel } = {}
local teamChannels: { [string]: TextChannel } = {}
local whisperChannels: { [string]: TextChannel } = {}
local descriptors: { [TextChannel]: Descriptor } = {}
local sourcesByUser: { [number]: { [TextChannel]: TextSource } } = {}
local boundChannels: { [TextChannel]: boolean } = {}

local shouldDeliver: DeliverFn? = nil

local container: Instance? = nil

local function getContainer(): Instance
	local current = container
	if current and current.Parent then
		return current
	end

	local existing = TextChatService:FindFirstChild("TextChannels")
	if not existing then
		local folder = Instance.new("Folder")
		folder.Name = "TextChannels"
		folder.Parent = TextChatService
		existing = folder
	end

	container = existing
	return existing
end

local function bindChannel(channel: TextChannel, descriptor: Descriptor): ()
	descriptors[channel] = descriptor

	if boundChannels[channel] then
		return
	end
	boundChannels[channel] = true

	channel.ShouldDeliverCallback = function(message: TextChatMessage, target: TextSource): boolean
		local info = descriptors[channel]
		if not info then
			return false
		end

		local deliver = shouldDeliver
		if not deliver then
			return false
		end

		local ok, result = pcall(deliver, message, target, info)
		if not ok then
			return false
		end
		return result == true
	end
end

local function createChannel(name: string): TextChannel?
	local parent = getContainer()
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("TextChannel") then
		return existing
	end

	local ok, channel = pcall(function()
		local instance = Instance.new("TextChannel")
		instance.Name = name
		instance.Parent = parent
		return instance
	end)

	if not ok then
		return nil
	end
	return channel
end

local function trackSource(userId: number, channel: TextChannel, source: TextSource): ()
	local perUser = sourcesByUser[userId]
	if not perUser then
		perUser = {}
		sourcesByUser[userId] = perUser
	end
	perUser[channel] = source
end

local function addUser(channel: TextChannel, userId: number): TextSource?
	local perUser = sourcesByUser[userId]
	local existing = perUser and perUser[channel]
	if existing and existing.Parent then
		return existing
	end

	local ok, source = pcall(function()
		return channel:AddUserAsync(userId)
	end)

	if not ok or typeof(source) ~= "Instance" or not source:IsA("TextSource") then
		return nil
	end

	local textSource = source :: TextSource
	trackSource(userId, channel, textSource)
	return textSource
end

function TextChannels.setDeliveryPolicy(fn: DeliverFn): ()
	shouldDeliver = fn
end

function TextChannels.ensure(): ()
	for _, channel in ChatConfig.Channels do
		local channelId = channel.id
		local name = ChannelNames.forChannel(channelId)
		local instance = createChannel(name)
		if instance then
			gameChannels[channelId] = instance
			bindChannel(instance, { kind = "game", name = name, channelId = channelId })
		end
	end

	for _, faction in ChannelNames.Factions do
		local name = ChannelNames.forTeam(faction)
		local instance = createChannel(name)
		if instance then
			teamChannels[faction] = instance
			bindChannel(instance, { kind = "team", name = name, faction = faction })
		end
	end
end

function TextChannels.addPlayer(userId: number): ()
	for _, channel in gameChannels do
		addUser(channel, userId)
	end
	for _, channel in teamChannels do
		addUser(channel, userId)
	end
end

function TextChannels.ensureWhisper(requester: Player, targetUserId: number): string?
	local name = ChannelNames.forWhisper(requester.UserId, targetUserId)

	local existing = whisperChannels[name]
	if existing and existing.Parent then
		if addUser(existing, requester.UserId) and addUser(existing, targetUserId) then
			return name
		end
		return nil
	end

	local channel = createChannel(name)
	if not channel then
		return nil
	end

	pcall(function()
		channel:SetDirectChatRequester(requester)
	end)

	if not addUser(channel, requester.UserId) then
		return nil
	end
	if not addUser(channel, targetUserId) then
		return nil
	end

	whisperChannels[name] = channel
	bindChannel(channel, {
		kind = "whisper",
		name = name,
		participants = { requester.UserId, targetUserId },
	})

	return name
end

function TextChannels.setCanSend(userId: number, canSend: boolean): ()
	local perUser = sourcesByUser[userId]
	if not perUser then
		return
	end
	for _, source in perUser do
		if source.Parent then
			pcall(function()
				source.CanSend = canSend
			end)
		end
	end
end

function TextChannels.applyPermissions(userId: number, resolver: (Descriptor) -> boolean): ()
	local perUser = sourcesByUser[userId]
	if not perUser then
		return
	end
	for channel, source in perUser do
		if source.Parent then
			local descriptor = descriptors[channel]
			local allowed = descriptor ~= nil and resolver(descriptor)
			pcall(function()
				source.CanSend = allowed
			end)
		end
	end
end

function TextChannels.getSources(userId: number): { TextSource }
	local result: { TextSource } = {}
	local perUser = sourcesByUser[userId]
	if not perUser then
		return result
	end
	for _, source in perUser do
		if source.Parent then
			table.insert(result, source)
		end
	end
	return result
end

function TextChannels.getDescriptor(channel: TextChannel): Descriptor?
	return descriptors[channel]
end

function TextChannels.removePlayer(userId: number): ()
	local perUser = sourcesByUser[userId]
	if not perUser then
		return
	end
	for _, source in perUser do
		pcall(function()
			source:Destroy()
		end)
	end
	sourcesByUser[userId] = nil
end

function TextChannels.cleanup(): ()
	for channel in boundChannels do
		pcall(function()
			channel.ShouldDeliverCallback = nil :: any
		end)
	end
	table.clear(boundChannels)
	table.clear(descriptors)
	table.clear(sourcesByUser)
	table.clear(gameChannels)
	table.clear(teamChannels)
	table.clear(whisperChannels)
	shouldDeliver = nil
end

return TextChannels
