--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5)) :: any
local scoped = Fusion.scoped

local ChatWindow = require(MainModule.Client.Components.Chat)
local ChatTypes = require(MainModule.Shared.Network.Chat.Types)
local ChatConfig = require(MainModule.Shared.Config.Chat.ChatConfig)
local Constants = require(MainModule.Shared.Config.Constants)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

type ChannelId = ChatTypes.ChannelId
type ChatMessage = ChatTypes.ChatMessage
type GlobalFilter = ChatTypes.GlobalFilter

local ChatUIManager = {}

local LocalPlayer = Players.LocalPlayer
local scope: any = nil
local chatUI: Frame? = nil
local getChatService = LazyService.create(MainModule, "ChatService")
local chatTextBox: TextBox? = nil

local CHAT_SETTLE_TIME = 0.5
local BAN_ALERT_DISMISS_SECONDS = 30
local BAN_ALERT_TAG = "BAN_ALERT"
local BAN_ALERT_CHANNEL: ChannelId = "RAID"

local isVisible: any = nil
local chatContentVisible: any = nil
local chatSettleThread: thread? = nil
local channelMessages: { [ChannelId]: any } = {}
local channelMessageIds: { [ChannelId]: { [string]: boolean } } = {}
local currentChannel: any = nil
local currentFilter: any = nil
local visibleChannels: any = nil
local bubbleVisibility: any = nil
local unreadCounts: any = nil
local channelAlerts: any = nil
local channelAlertThreads: { [ChannelId]: thread } = {}
local localPlayerTeam: any = nil
local currentChannelMessagesComputed: any = nil
local isMuted: any = nil
local whisperTarget: any = nil
local serviceCallbackCleanups: { () -> () } = {}
local teamConnection: RBXScriptConnection? = nil

local function getLocalPlayerFaction(): string?
	if not LocalPlayer or not LocalPlayer.Team then return nil end
	local teamName = LocalPlayer.Team.Name
	if Constants.FACTIONS.DEFENDER_TEAMS[teamName] then return "Defenders" end
	if Constants.FACTIONS.RAIDER_TEAMS[teamName] then return "Raiders" end
	return nil
end

local function triggerChannelAlert(channelId: ChannelId, durationSeconds: number): ()
	if not channelAlerts or durationSeconds <= 0 then
		return
	end

	local existingThread = channelAlertThreads[channelId]
	if existingThread then
		task.cancel(existingThread)
		channelAlertThreads[channelId] = nil
	end

	local current = Fusion.peek(channelAlerts)
	if not current[channelId] then
		local updated = table.clone(current)
		updated[channelId] = true
		channelAlerts:set(updated)
	end

	channelAlertThreads[channelId] = task.delay(durationSeconds, function()
		channelAlertThreads[channelId] = nil
		if channelAlerts then
			local curr = Fusion.peek(channelAlerts)
			if curr[channelId] then
				local newMap = table.clone(curr)
				newMap[channelId] = false
				channelAlerts:set(newMap)
			end
		end
	end)
end

local function isBanAlertMessage(message: ChatMessage): boolean
	if message.channelId ~= BAN_ALERT_CHANNEL then
		return false
	end

	for _, tag in message.tags do
		if tag == BAN_ALERT_TAG then
			return true
		end
	end

	return false
end

function ChatUIManager.init(): ()
	scope = scoped(Fusion)

	isVisible = scope:Value(true)
	chatContentVisible = scope:Value(true)
	currentChannel = scope:Value("GLOBAL" :: ChannelId)
	currentFilter = scope:Value("ALL" :: GlobalFilter)
	visibleChannels = scope:Value({ "GLOBAL" :: ChannelId })
	bubbleVisibility = scope:Value(true)
	unreadCounts = scope:Value({} :: { [ChannelId]: number })
	channelAlerts = scope:Value({} :: { [ChannelId]: boolean })
	localPlayerTeam = scope:Value(getLocalPlayerFaction())
	isMuted = scope:Value(false)
	whisperTarget = scope:Value(nil :: Player?)

	for _, channel in ChatConfig.Channels do
		channelMessages[channel.id :: ChannelId] = scope:Value({})
		channelMessageIds[channel.id :: ChannelId] = {}
	end

	currentChannelMessagesComputed = scope:Computed(function(use)
		local channel = use(currentChannel)
		local msgs = channelMessages[channel]
		if msgs then
			return use(msgs)
		end
		return {}
	end)

	if LocalPlayer then
		teamConnection = LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
			if localPlayerTeam then
				localPlayerTeam:set(getLocalPlayerFaction())
			end
		end)
	end
end

local function applyChatVisibility(visible: boolean): ()
	if not isVisible or not chatContentVisible then return end
	if visible then
		if chatSettleThread then
			task.cancel(chatSettleThread)
			chatSettleThread = nil
		end
		chatContentVisible:set(true)
		isVisible:set(true)
	else
		isVisible:set(false)
		if chatSettleThread then
			task.cancel(chatSettleThread)
		end
		chatSettleThread = task.delay(CHAT_SETTLE_TIME, function()
			chatSettleThread = nil
			if not Fusion.peek(isVisible) then
				chatContentVisible:set(false)
			end
		end)
	end
end

function ChatUIManager.createUI(): ()
	if not scope or chatUI then
		return
	end

	local playerGui = LocalPlayer:WaitForChild("PlayerGui", 5) :: PlayerGui

	local screenGui = scope:New("ScreenGui")({
		Name = "ChatUI",
		AutoLocalize = false,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = false,
		Parent = playerGui,
	})

	chatUI = ChatWindow(scope, {
		Visible = isVisible,
		ContentVisible = chatContentVisible,
		Messages = currentChannelMessagesComputed,
		CurrentChannel = currentChannel,
		CurrentFilter = currentFilter,
		VisibleChannels = visibleChannels,
		BubbleVisibility = bubbleVisibility,
		UnreadCounts = unreadCounts,
		ChannelAlerts = channelAlerts,
		LocalPlayerTeam = localPlayerTeam,
		IsMuted = isMuted,
		WhisperTarget = whisperTarget,
		OnSendMessage = function(content: string, isTeamOnly: boolean, whisperTargetPlayer: Player?)
			local svc = getChatService()
			if svc then
				if whisperTargetPlayer then
					svc:SendWhisper(whisperTargetPlayer, content)
				else
					svc:SendMessage(content, isTeamOnly)
				end
			end
		end,
		OnChannelChange = function(channelId: ChannelId)
			local svc = getChatService()
			if svc then
				local success = svc:SwitchChannel(channelId)
				if not success then
					return
				end
			end
			if currentChannel then
				currentChannel:set(channelId)
			end
			if currentFilter and channelId ~= "GLOBAL" then
				currentFilter:set("ALL")
			end
		end,
		OnFilterChange = function(filter: GlobalFilter)
			if currentFilter then
				currentFilter:set(filter)
			end
		end,
		OnFocusChanged = function(focused: boolean)
			local svc = getChatService()
			if svc then
				svc:SetFocused(focused)
			end
		end,
		OnBubbleVisibilityToggle = function()
			if bubbleVisibility then
				local current = Fusion.peek(bubbleVisibility)
				bubbleVisibility:set(not current)
				local svc = getChatService()
				if svc and svc.SetBubbleVisibility then
					svc:SetBubbleVisibility(not current)
				end
			end
		end,
		OnVisibilityToggle = function()
			if isVisible then
				applyChatVisibility(not Fusion.peek(isVisible))
			end
		end,
		OnTextBoxCreated = function(textBox: TextBox)
			chatTextBox = textBox
		end,
		OnUsernameClick = function(_senderId: number, senderName: string)
			local player = Players:FindFirstChild(senderName) :: Player?
			if player and player ~= LocalPlayer then
				local svc = getChatService()
				if svc then
					svc:SetWhisperTarget(player)
				end
				if whisperTarget then
					whisperTarget:set(player)
				end
				if chatTextBox then
					chatTextBox:CaptureFocus()
				end
			end
		end,
		OnWhisperTargetChange = function(target: Player?)
			local svc = getChatService()
			if svc then
				svc:SetWhisperTarget(target)
			end
			if whisperTarget then
				whisperTarget:set(target)
			end
		end,
	})

	chatUI.Parent = screenGui
end

function ChatUIManager.connectToService(): ()
	local ChatService = getChatService()
	if not ChatService then
		return
	end

	for _, cleanup in serviceCallbackCleanups do
		cleanup()
	end
	table.clear(serviceCallbackCleanups)

	local messageCleanup = ChatService:OnMessage(function(message: ChatMessage)
		local channelId = message.channelId
		local msgs = channelMessages[channelId]
		local idSet = channelMessageIds[channelId]
		if not msgs or not idSet then
			return
		end

		if idSet[message.id] then
			return
		end

		idSet[message.id] = true

		local currentMessages = Fusion.peek(msgs)
		local newMessages = table.clone(currentMessages)

		local insertIndex = #newMessages + 1
		for i = #newMessages, 1, -1 do
			if newMessages[i].timestamp <= message.timestamp then
				insertIndex = i + 1
				break
			end
			if i == 1 then
				insertIndex = 1
			end
		end
		table.insert(newMessages, insertIndex, message)

		while #newMessages > ChatConfig.Settings.messageHistorySize do
			local removed = newMessages[1]
			if removed then
				idSet[removed.id] = nil
			end
			table.move(newMessages, 2, #newMessages, 1)
			newMessages[#newMessages] = nil
		end

		msgs:set(newMessages)

		if isBanAlertMessage(message) then
			local elapsed = os.time() - message.timestamp
			local remaining = BAN_ALERT_DISMISS_SECONDS - elapsed
			if remaining > 0 then
				triggerChannelAlert(channelId, remaining)
			end
		end

		if unreadCounts and currentChannel then
			local activeChannel = Fusion.peek(currentChannel)
			if channelId ~= activeChannel then
				local wouldBeVisible = true
				if channelId == "GLOBAL" and message.isTeamOnly then
					local filter = Fusion.peek(currentFilter)
					local playerTeam = Fusion.peek(localPlayerTeam)
					if filter == "ALL" or message.senderTeam ~= playerTeam then
						wouldBeVisible = false
					end
				end
				if wouldBeVisible then
					local counts = Fusion.peek(unreadCounts)
					local newCounts = table.clone(counts)
					newCounts[channelId] = (newCounts[channelId] or 0) + 1
					unreadCounts:set(newCounts)
				end
			end
		end
	end)
	table.insert(serviceCallbackCleanups, messageCleanup)

	local visibilityCleanup = ChatService:OnVisibilityChanged(function(visible: boolean)
		applyChatVisibility(visible)
	end)
	table.insert(serviceCallbackCleanups, visibilityCleanup)

	local channelCleanup = ChatService:OnChannelChanged(function(channelId: ChannelId)
		if currentChannel then
			currentChannel:set(channelId)
		end

		if unreadCounts then
			local counts = Fusion.peek(unreadCounts)
			if counts[channelId] and counts[channelId] > 0 then
				local newCounts = table.clone(counts)
				newCounts[channelId] = 0
				unreadCounts:set(newCounts)
			end
		end
	end)
	table.insert(serviceCallbackCleanups, channelCleanup)

	local focusCleanup = ChatService:OnFocusRequest(function()
		if chatTextBox then
			task.defer(function()
				if chatTextBox then
					chatTextBox:CaptureFocus()
				end
			end)
		end
	end)
	table.insert(serviceCallbackCleanups, focusCleanup)

	local muteCleanup = ChatService:OnMuteStatusChanged(function(muted: boolean)
		if isMuted then
			isMuted:set(muted)
		end
	end)
	table.insert(serviceCallbackCleanups, muteCleanup)

	local channelsChangedCleanup = ChatService:OnVisibleChannelsChanged(function(channels: { ChannelId })
		if visibleChannels then
			visibleChannels:set(channels)
		end
	end)
	table.insert(serviceCallbackCleanups, channelsChangedCleanup)

	local whisperCleanup = ChatService:OnWhisperTargetChanged(function(target: Player?)
		if whisperTarget then
			whisperTarget:set(target)
		end
	end)
	table.insert(serviceCallbackCleanups, whisperCleanup)

	if isMuted then
		isMuted:set(ChatService:IsMuted())
	end

	task.spawn(function()
		local playerData = ChatService:GetPlayerData()
		if playerData and visibleChannels then
			visibleChannels:set(playerData.visibleChannels)

			if #playerData.visibleChannels > 0 and currentChannel then
				currentChannel:set(playerData.visibleChannels[1])
			end
		end

		for channelId, msgs in channelMessages do
			local history = ChatService:GetMessages(channelId)
			if #history > 0 then
				local idSet = channelMessageIds[channelId]
				if idSet then
					table.clear(idSet)
					local maxRemaining = 0
					for _, msg in history do
						idSet[msg.id] = true
						if isBanAlertMessage(msg) then
							local elapsed = os.time() - msg.timestamp
							local remaining = BAN_ALERT_DISMISS_SECONDS - elapsed
							if remaining > maxRemaining then
								maxRemaining = remaining
							end
						end
					end
					if maxRemaining > 0 then
						triggerChannelAlert(channelId, maxRemaining)
					end
				end
				msgs:set(history)
			end
		end
	end)
end

function ChatUIManager.setVisibility(visible: boolean): ()
	applyChatVisibility(visible)
end

function ChatUIManager.getBubbleVisibility(): boolean
	if bubbleVisibility then
		return Fusion.peek(bubbleVisibility)
	end
	return true
end

function ChatUIManager.destroy(): ()
	if teamConnection then
		teamConnection:Disconnect()
		teamConnection = nil
	end

	for _, cleanup in serviceCallbackCleanups do
		cleanup()
	end
	table.clear(serviceCallbackCleanups)

	for _, threadObj in channelAlertThreads do
		task.cancel(threadObj)
	end
	table.clear(channelAlertThreads)

	if chatSettleThread then
		task.cancel(chatSettleThread)
		chatSettleThread = nil
	end

	if scope then
		Fusion.doCleanup(scope)
		scope = nil
	end

	chatUI = nil
	chatTextBox = nil
	isVisible = nil
	chatContentVisible = nil
	channelMessages = {}
	channelMessageIds = {}
	currentChannel = nil
	currentFilter = nil
	visibleChannels = nil
	bubbleVisibility = nil
	unreadCounts = nil
	channelAlerts = nil
	localPlayerTeam = nil
	currentChannelMessagesComputed = nil
	isMuted = nil
	whisperTarget = nil
end

return ChatUIManager
