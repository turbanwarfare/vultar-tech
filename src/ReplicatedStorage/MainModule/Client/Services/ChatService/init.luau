--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local ChatConfig = require(MainModule.Shared.Config.Chat.ChatConfig)
local Constants = require(MainModule.Shared.Config.Constants)
local ChatTypes = require(MainModule.Shared.Network.Chat.Types)
local ChatCommands = require(MainModule.Shared.Chat.Commands)
local ChatUIManager = require(script.ChatUIManager)
local TextChannelClient = require(script.TextChannelClient)
local Signal = require(MainModule.Shared.Utils.State.Signal)

local LoadBenchmark: any = nil
pcall(function()
	LoadBenchmark = require(MainModule.Shared.Utils.Debug.LoadBenchmark)
end)

local function bench(name: string, fn: () -> ())
	if LoadBenchmark and LoadBenchmark.isEnabled() then
		LoadBenchmark.start("ChatSvc:" .. name)
		fn()
		LoadBenchmark.stop()
	else
		fn()
	end
end

local function benchDetail(msg: string)
	if LoadBenchmark and LoadBenchmark.isEnabled() then
		LoadBenchmark.detail("[ChatSvc] " .. msg)
	end
end

type ChannelId = ChatTypes.ChannelId
type ChatMessage = ChatTypes.ChatMessage
type PlayerChatData = ChatTypes.PlayerChatData
type SystemMessage = ChatTypes.SystemMessage
type PlayerMeta = ChatTypes.PlayerMeta

local ChatService = {}
ChatService.Name = "ChatService"

local playerData: PlayerChatData? = nil
local currentChannel: ChannelId = "GLOBAL"
local messages: { [ChannelId]: { ChatMessage } } = {}
local messageIdSets: { [ChannelId]: { [string]: boolean } } = {}
local isVisible = true
local isFocused = false
local bubbleVisibilityEveryone = true
local isMuted = false
local whisperTarget: Player? = nil

local onMessage = Signal.new()
local onSystemMessage = Signal.new()
local onVisibility = Signal.new()
local onChannel = Signal.new()
local onBubble = Signal.new()
local onFocusRequest = Signal.new()
local onMuteStatus = Signal.new()
local onVisibleChannelsChanged = Signal.new()
local onWhisperTargetChanged = Signal.new()

local inputConnection: RBXScriptConnection? = nil
local networkConnections: { RBXScriptConnection } = {}
local SettingsService: any = nil

local STATUS_ERROR_MESSAGES: { [Enum.TextChatMessageStatus]: { content: string, color: Color3 } } = {
	[Enum.TextChatMessageStatus.InvalidPrivacySettings] = {
		content = "[SYSTEM] Your privacy settings prevent you from chatting.",
		color = Color3.fromRGB(255, 100, 100),
	},
	[Enum.TextChatMessageStatus.InvalidTextChannelPermissions] = {
		content = "[SYSTEM] You are muted and cannot send messages.",
		color = Color3.fromRGB(255, 100, 100),
	},
	[Enum.TextChatMessageStatus.TextFilterFailed] = {
		content = "[SYSTEM] Your message could not be sent. Please try again.",
		color = Color3.fromRGB(255, 100, 100),
	},
	[Enum.TextChatMessageStatus.Floodchecked] = {
		content = "[SYSTEM] You are sending messages too quickly.",
		color = Color3.fromRGB(255, 200, 100),
	},
	[Enum.TextChatMessageStatus.MessageTooLong] = {
		content = "[SYSTEM] That message is too long.",
		color = Color3.fromRGB(255, 200, 100),
	},
	[Enum.TextChatMessageStatus.ModerationTimeout] = {
		content = "[SYSTEM] You are temporarily timed out from chatting.",
		color = Color3.fromRGB(255, 100, 100),
	},
	[Enum.TextChatMessageStatus.Unknown] = {
		content = "[SYSTEM] Your message could not be sent.",
		color = Color3.fromRGB(255, 100, 100),
	},
}

local lastErrorShownTime: number = 0
local ERROR_COOLDOWN = 1

local playerMeta: { [number]: PlayerMeta } = {}

local function reportSystemError(content: string, color: Color3?): ()
	local now = os.clock()
	if now - lastErrorShownTime < ERROR_COOLDOWN then
		return
	end
	lastErrorShownTime = now

	onSystemMessage:Fire({
		content = content,
		color = color or Color3.fromRGB(255, 100, 100),
	})
end

local function reportStatus(status: Enum.TextChatMessageStatus): ()
	local errorInfo = STATUS_ERROR_MESSAGES[status]
	if not errorInfo then
		return
	end
	reportSystemError(errorInfo.content, errorInfo.color)
end

local function configureBubbleChat(): ()
	pcall(function()
		local bubbleConfig = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
		if bubbleConfig then
			bubbleConfig.Enabled = true
			bubbleConfig.VerticalStudsOffset = 1
			bubbleConfig.BubbleDuration = 8
			bubbleConfig.MaxBubbles = 3
		end
	end)
end

local function disableDefaultChat(): ()
	pcall(function()
		local chatWindowConfig = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		if chatWindowConfig then
			chatWindowConfig.Enabled = false
		end
	end)

	pcall(function()
		local chatInputBarConfig = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
		if chatInputBarConfig then
			chatInputBarConfig.Enabled = false
		end
	end)

	configureBubbleChat()
end

local function addMessage(message: ChatMessage): boolean
	local channelId = message.channelId
	if not messages[channelId] then
		messages[channelId] = {}
		messageIdSets[channelId] = {}
	end

	local idSet = messageIdSets[channelId]
	if idSet[message.id] then
		return false
	end

	idSet[message.id] = true
	local channelMessages = messages[channelId]
	table.insert(channelMessages, message)

	local maxSize = ChatConfig.Settings.messageHistorySize
	local overflow = #channelMessages - maxSize
	if overflow > 0 then
		for i = 1, overflow do
			local removed = channelMessages[i]
			if removed then
				idSet[removed.id] = nil
			end
		end

		table.move(channelMessages, overflow + 1, #channelMessages, 1)

		for i = maxSize + 1, #channelMessages do
			channelMessages[i] = nil
		end
	end

	return true
end

local function getFactionOf(player: Player): string?
	local team = player.Team
	if not team then
		return nil
	end
	if Constants.FACTIONS.DEFENDER_TEAMS[team.Name] then
		return "Defenders"
	end
	if Constants.FACTIONS.RAIDER_TEAMS[team.Name] then
		return "Raiders"
	end
	return nil
end

local function getLocalFaction(): string?
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return nil
	end
	return getFactionOf(localPlayer)
end

local function sendToChannel(channel: TextChannel, content: string): ()
	task.spawn(function()
		local ok, result = pcall(function()
			return channel:SendAsync(content)
		end)

		if not ok then
			reportSystemError("[SYSTEM] Your message could not be sent.")
			return
		end

		if typeof(result) == "Instance" and result:IsA("TextChatMessage") then
			local status = result.Status
			if status ~= Enum.TextChatMessageStatus.Success and status ~= Enum.TextChatMessageStatus.Sending then
				reportStatus(status)
			end
		end
	end)
end

local function shouldShowBubbleFor(senderId: number): boolean
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return false
	end
	if senderId == localPlayer.UserId then
		return true
	end

	local meta = playerMeta[senderId]
	if meta and meta.bubbleEveryone == false then
		local sender = Players:GetPlayerByUserId(senderId)
		if not sender then
			return false
		end
		return getFactionOf(sender) == getFactionOf(localPlayer)
	end

	return true
end

local function messageTimestamp(textChatMessage: TextChatMessage): number
	local ok, seconds = pcall(function()
		return textChatMessage.Timestamp.UnixTimestamp
	end)
	if ok and typeof(seconds) == "number" then
		return seconds
	end
	return os.time()
end

local function buildChatMessage(textChatMessage: TextChatMessage, binding: TextChannelClient.Binding): ChatMessage?
	local source = textChatMessage.TextSource
	if not source then
		return nil
	end

	local senderId = source.UserId
	local sender = Players:GetPlayerByUserId(senderId)
	if not sender then
		return nil
	end

	local meta = playerMeta[senderId]

	local channelId: ChannelId = "GLOBAL"
	local isTeamOnly = false
	local isWhisper = false
	local whisperTargetId: number? = nil
	local whisperTargetName: string? = nil

	if binding.kind == "game" then
		channelId = (binding.channelId :: any) or "GLOBAL"
	elseif binding.kind == "team" then
		channelId = "GLOBAL"
		isTeamOnly = true
	elseif binding.kind == "whisper" then
		channelId = "GLOBAL"
		isWhisper = true

		local participants = binding.participants
		if participants then
			for _, participantId in participants do
				if participantId ~= senderId then
					whisperTargetId = participantId
					local targetPlayer = Players:GetPlayerByUserId(participantId)
					whisperTargetName = if targetPlayer then targetPlayer.DisplayName else nil
					break
				end
			end
			if not whisperTargetId then
				whisperTargetId = senderId
				whisperTargetName = sender.DisplayName
			end
		end
	end

	return {
		id = textChatMessage.MessageId,
		channelId = channelId,
		senderId = senderId,
		senderName = sender.Name,
		senderDisplayName = sender.DisplayName,
		content = textChatMessage.Text,
		timestamp = messageTimestamp(textChatMessage),
		tags = if meta then meta.tags else {},
		nameColor = if meta then meta.nameColor else nil,
		rolePrefix = if meta then meta.rolePrefix else nil,
		roleColor = if meta then meta.roleColor else nil,
		isTeamOnly = isTeamOnly,
		senderTeam = getFactionOf(sender),
		isWhisper = isWhisper,
		whisperTargetId = whisperTargetId,
		whisperTargetName = whisperTargetName,
		gradient = if meta then meta.gradient else nil,
	}
end

local function onTextChannelMessage(textChatMessage: TextChatMessage, binding: TextChannelClient.Binding): ()
	local status = textChatMessage.Status

	if status == Enum.TextChatMessageStatus.Sending then
		return
	end

	if status ~= Enum.TextChatMessageStatus.Success then
		local localPlayer = Players.LocalPlayer
		local source = textChatMessage.TextSource
		if localPlayer and source and source.UserId == localPlayer.UserId then
			reportStatus(status)
		end
		return
	end

	if #textChatMessage.Text == 0 then
		return
	end

	local message = buildChatMessage(textChatMessage, binding)
	if not message then
		return
	end

	if addMessage(message) then
		onMessage:Fire(message)
	end

	if shouldShowBubbleFor(message.senderId) then
		onBubble:Fire(message.senderId, textChatMessage.Text, message.nameColor)
	end
end

local function onSystemChatMessage(message: ChatMessage): ()
	if addMessage(message) then
		onMessage:Fire(message)
	end
end

local function handleSystemMessage(message: SystemMessage): ()
	onSystemMessage:Fire(message)
end

local function applyPlayerMeta(entries: { PlayerMeta }): ()
	for _, entry in entries do
		playerMeta[entry.userId] = entry
	end
end

local localCanChat: boolean? = nil

local function canLocalPlayerChat(): boolean
	if localCanChat ~= nil then
		return localCanChat
	end
	local ok, result = pcall(function()
		return TextChatService:CanUserChatAsync(Players.LocalPlayer.UserId)
	end)
	if not ok then
		return false
	end
	localCanChat = result == true
	return localCanChat
end

local function getChatKeybind(): Enum.KeyCode
	if SettingsService and SettingsService.GetSettings then
		local settings = SettingsService:GetSettings()
		if settings and settings.Keybinds and settings.Keybinds.Chat then
			local keyName = settings.Keybinds.Chat
			local keyCode = Enum.KeyCode[keyName]
			if keyCode then
				return keyCode
			end
		end
	end
	return Enum.KeyCode.Z
end

local function onInputBegan(input: InputObject, gameProcessed: boolean): ()
	if gameProcessed then
		return
	end

	if input.KeyCode == getChatKeybind() then
		ChatService:ToggleVisibility()
	end

	if input.KeyCode == Enum.KeyCode.Slash then
		if not isVisible then
			ChatService:SetVisibility(true)
		end
		onFocusRequest:Fire()
	end
end

function ChatService:GetPlayerData(): PlayerChatData?
	return playerData
end

function ChatService:GetCurrentChannel(): ChannelId
	return currentChannel
end

function ChatService:GetVisibleChannels(): { ChannelId }
	if playerData then
		return playerData.visibleChannels
	end
	return { "GLOBAL" }
end

function ChatService:GetMessages(channelId: ChannelId?): { ChatMessage }
	local channel = channelId or currentChannel
	local msgs = messages[channel]
	if not msgs then
		return {}
	end
	return table.clone(msgs)
end

function ChatService:SwitchChannel(channelId: ChannelId): boolean
	if not playerData then
		return false
	end

	if not table.find(playerData.visibleChannels, channelId) then
		return false
	end

	currentChannel = channelId
	Network.Chat.switchChannel(channelId)

	onChannel:Fire(channelId)

	return true
end

function ChatService:CanAccessChannel(channelId: ChannelId): boolean
	if not playerData then
		return false
	end
	return table.find(playerData.visibleChannels, channelId) ~= nil
end

function ChatService:RefreshPlayerData(): ()
	task.spawn(function()
		local newData = Network.Chat.getPlayerData()
		if newData then
			playerData = newData
			currentChannel = newData.visibleChannels[1] or "GLOBAL"
			onChannel:Fire(currentChannel)
		end
	end)
end

function ChatService:SendMessage(content: string, isTeamOnly: boolean?): ()
	if #content == 0 then
		return
	end

	if #content > ChatConfig.Settings.maxMessageLength then
		content = string.sub(content, 1, ChatConfig.Settings.maxMessageLength)
	end

	if ChatCommands.isAdminCommand(content) or ChatCommands.looksLikeCommand(content) then
		Network.Chat.sendCommand(content)
		return
	end

	local channel: TextChannel?
	if isTeamOnly and currentChannel == "GLOBAL" then
		local faction = getLocalFaction()
		if not faction then
			reportSystemError("[SYSTEM] You are not on a team yet.")
			return
		end
		channel = TextChannelClient.forTeam(faction)
	else
		channel = TextChannelClient.forChannel(currentChannel)
	end

	if not channel then
		reportSystemError("[SYSTEM] Chat is still connecting. Try again in a moment.")
		return
	end

	sendToChannel(channel, content)
end

function ChatService:SendWhisper(target: Player, content: string): ()
	if #content == 0 then
		return
	end

	if #content > ChatConfig.Settings.maxMessageLength then
		content = string.sub(content, 1, ChatConfig.Settings.maxMessageLength)
	end

	task.spawn(function()
		local channelName = Network.Chat.requestWhisperChannel(target.UserId)
		if not channelName then
			return
		end

		local channel = TextChannelClient.await(channelName, 5)
		if not channel then
			reportSystemError("[SYSTEM] Could not open a private channel with that player.")
			return
		end

		sendToChannel(channel, content)
	end)
end

function ChatService:GetWhisperTarget(): Player?
	return whisperTarget
end

function ChatService:SetWhisperTarget(target: Player?): ()
	if whisperTarget == target then
		return
	end
	whisperTarget = target
	onWhisperTargetChanged:Fire(target)
end

function ChatService:ClearWhisperTarget(): ()
	ChatService:SetWhisperTarget(nil)
end

function ChatService:IsVisible(): boolean
	return isVisible
end

function ChatService:SetVisibility(visible: boolean): ()
	isVisible = visible
	onVisibility:Fire(visible)
end

function ChatService:ToggleVisibility(): ()
	ChatService:SetVisibility(not isVisible)
end

function ChatService:IsFocused(): boolean
	return isFocused
end

function ChatService:SetFocused(focused: boolean): ()
	isFocused = focused
end

function ChatService:GetBubbleVisibility(): boolean
	return bubbleVisibilityEveryone
end

function ChatService:SetBubbleVisibility(everyone: boolean): ()
	bubbleVisibilityEveryone = everyone
	Network.Chat.setBubbleVisibility(everyone)
end

function ChatService:OnMessage(callback: (message: ChatMessage) -> ()): () -> ()
	local connection = onMessage:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

function ChatService:OnSystemMessage(callback: (message: SystemMessage) -> ()): () -> ()
	local connection = onSystemMessage:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

function ChatService:OnVisibilityChanged(callback: (visible: boolean) -> ()): () -> ()
	local connection = onVisibility:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

function ChatService:OnChannelChanged(callback: (channelId: ChannelId) -> ()): () -> ()
	local connection = onChannel:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

function ChatService:OnBubble(callback: (senderId: number, content: string, nameColor: Color3?) -> ()): () -> ()
	local connection = onBubble:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

function ChatService:OnFocusRequest(callback: () -> ()): () -> ()
	local connection = onFocusRequest:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

function ChatService:IsMuted(): boolean
	return isMuted
end

function ChatService:OnMuteStatusChanged(callback: (muted: boolean) -> ()): () -> ()
	local connection = onMuteStatus:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

function ChatService:OnVisibleChannelsChanged(callback: (channels: { ChannelId }) -> ()): () -> ()
	local connection = onVisibleChannelsChanged:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

function ChatService:OnWhisperTargetChanged(callback: (target: Player?) -> ()): () -> ()
	local connection = onWhisperTargetChanged:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

function ChatService:GetTagConfig(tagId: string): { text: string, textColor: Color3, backgroundColor: Color3 }?
	return ChatConfig.getTagConfig(tagId)
end

function ChatService:GetChannelConfig(channelId: ChannelId): { name: string, color: Color3, icon: string?, order: number }?
	return ChatConfig.getChannelConfig(channelId)
end

function ChatService:init(): ()
	benchDetail("init() called")

	bench("disableDefaultChat", function()
		disableDefaultChat()
	end)

	bench("initChannelMessages", function()
		for _, channel in ChatConfig.Channels do
			messages[channel.id :: ChannelId] = {}
			messageIdSets[channel.id :: ChannelId] = {}
			benchDetail("Initialized channel: " .. channel.id)
		end
	end)

	bench("bindTextChannels", function()
		TextChannelClient.start(onTextChannelMessage)
	end)

	bench("ChatUIManager.init", function()
		ChatUIManager.init()
	end)

	benchDetail("init() complete")
end

function ChatService:start(): ()
	benchDetail("start() called")

	local Vultar = require(MainModule)
	SettingsService = Vultar.GetService("SettingsService")

	bench("setupNetworkListeners", function()
		table.insert(networkConnections, Network.Chat.onSystemChatMessage(onSystemChatMessage))
		table.insert(networkConnections, Network.Chat.onSystemMessage(handleSystemMessage))
		table.insert(networkConnections, Network.Chat.onPlayerMeta(applyPlayerMeta))
		table.insert(
			networkConnections,
			Network.Chat.onMuteStatusChanged(function(muted: boolean)
				isMuted = muted
				onMuteStatus:Fire(muted)
			end)
		)

		table.insert(
			networkConnections,
			Network.Chat.onChannelsUpdated(function(channels: { ChannelId }, switchTo: ChannelId?)
				if playerData then
					playerData.visibleChannels = channels
				end

				if switchTo then
					currentChannel = switchTo
					onChannel:Fire(switchTo)
				end

				onVisibleChannelsChanged:Fire(channels)
			end)
		)
	end)

	bench("connectInputHandler", function()
		inputConnection = UserInputService.InputBegan:Connect(onInputBegan)
	end)

	table.insert(
		networkConnections,
		Network.Deploy.onDeployComplete(function()
			if not canLocalPlayerChat() then
				return
			end
			benchDetail("Deploy complete, creating chat UI")
			bench("ChatUIManager.createUI", function()
				ChatUIManager.createUI()
			end)
			bench("ChatUIManager.connectToService", function()
				ChatUIManager.connectToService()
			end)
		end)
	)

	benchDetail("Spawning async data loader")
	task.spawn(function()
		bench("getPlayerData", function()
			playerData = Network.Chat.getPlayerData()
			if playerData then
				benchDetail("Got player data with " .. #playerData.visibleChannels .. " visible channels")
			else
				benchDetail("No player data received")
			end
		end)

		if playerData and #playerData.visibleChannels > 0 then
			currentChannel = playerData.visibleChannels[1]
			benchDetail("Set current channel to: " .. currentChannel)
		end

		bench("getPlayerMeta", function()
			applyPlayerMeta(Network.Chat.getPlayerMeta())
		end)

		bench("loadSystemHistory", function()
			local channels = playerData and playerData.visibleChannels or {}

			for _, channelId in channels do
				local history = Network.Chat.getSystemHistory(channelId)
				benchDetail(string.format("Got %d system messages for channel %s", #history, channelId))
				for _, message in history do
					if addMessage(message) then
						onMessage:Fire(message)
					end
				end
			end
		end)
	end)

	benchDetail("start() sync portion complete")
end

function ChatService:Cleanup(): ()
	if inputConnection then
		inputConnection:Disconnect()
		inputConnection = nil
	end
	for _, conn in networkConnections do
		conn:Disconnect()
	end
	table.clear(networkConnections)
	TextChannelClient.cleanup()
	onMessage:Destroy()
	onSystemMessage:Destroy()
	onVisibility:Destroy()
	onChannel:Destroy()
	onBubble:Destroy()
	onFocusRequest:Destroy()
	onMuteStatus:Destroy()
	onVisibleChannelsChanged:Destroy()
	onWhisperTargetChanged:Destroy()
	table.clear(messages)
	table.clear(messageIdSets)
	table.clear(playerMeta)
	playerData = nil
	whisperTarget = nil
end

return ChatService
