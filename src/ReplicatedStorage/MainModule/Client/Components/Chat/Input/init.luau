--!native
--!optimize 2

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local ChatConfig = require(MainModule.Shared.Config.Chat.ChatConfig)
local ChatConstants = require(MainModule.Shared.Chat.Constants)
local ChatCommands = require(MainModule.Shared.Chat.Commands)
local Theme = require(MainModule.Shared.UI.Theme)
local ChatTypes = require(MainModule.Shared.Network.Chat.Types)
local PlayerCache = require(MainModule.Shared.Cache.PlayerCache)

local LocalPlayer = Players.LocalPlayer

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn
type ChannelId = ChatTypes.ChannelId
type GlobalFilter = ChatTypes.GlobalFilter

local peek: <T>(state: FusionCanBeState<T>) -> T = Fusion.peek

export type MessageInputProps = {
	CurrentChannel: FusionCanBeState<ChannelId>,
	CurrentFilter: FusionCanBeState<GlobalFilter>,
	IsMuted: FusionCanBeState<boolean>,
	WhisperTarget: FusionCanBeState<Player?>?,
	OnSendMessage: (content: string, isTeamOnly: boolean, whisperTarget: Player?) -> (),
	OnFilterChange: (filter: GlobalFilter) -> (),
	OnChannelChange: ((channelId: ChannelId) -> ())?,
	OnWhisperTargetChange: ((target: Player?) -> ())?,
	OnFocusChanged: (focused: boolean) -> (),
	OnTextBoxCreated: ((textBox: TextBox) -> ())?,
}

local Constants = ChatConstants
local CHANNEL_NAME_CACHE: { [ChannelId]: string } = {}
local MIN_AUTOFILL_LENGTH = 1

local BADGE_PADDING = 20
local BADGE_GAP = 6
local BADGE_CLOSE_SIZE = 14
local BADGE_LABEL_SIZE = 11
local BADGE_WHISPERING_WIDTH = TextService:GetTextSize(
	"Whispering", BADGE_LABEL_SIZE, Enum.Font.GothamMedium, Vector2.new(math.huge, math.huge)
).X

local function computeBadgeWidth(displayName: string): number
	local nameWidth = TextService:GetTextSize(
		displayName, BADGE_LABEL_SIZE, Enum.Font.GothamBold, Vector2.new(math.huge, math.huge)
	).X
	return BADGE_PADDING + BADGE_WHISPERING_WIDTH + BADGE_GAP + nameWidth + BADGE_GAP + BADGE_CLOSE_SIZE
end

local function getChannelName(channelId: ChannelId): string
	local cached = CHANNEL_NAME_CACHE[channelId]
	if cached then
		return cached
	end

	for _, channel in ChatConfig.Channels do
		if channel.id == channelId then
			CHANNEL_NAME_CACHE[channelId] = channel.name
			return channel.name
		end
	end

	CHANNEL_NAME_CACHE[channelId] = channelId
	return channelId
end

local function findPlayerByPartial(name: string): Player?
	local cached = PlayerCache.findByPartial(name)
	if cached and cached.player ~= LocalPlayer then
		return cached.player
	end
	return nil
end

local function findUniquePlayerByPrefix(name: string): Player?
	local cached, matchedName = PlayerCache.findByUniquePrefix(name)
	if not cached or not matchedName or cached.player == LocalPlayer then
		return nil
	end
	return cached.player
end

local function parseWhisperCommand(text: string): (boolean, string?, string?, Player?)
	local firstChar = string.sub(text, 1, 1)
	if firstChar ~= "/" then
		return false, nil, nil, nil
	end

	local spacePos = string.find(text, " ", 2, true)
	if not spacePos then
		return false, nil, nil, nil
	end

	local command = string.lower(string.sub(text, 2, spacePos - 1))
	if not ChatCommands.isWhisperCommand(command) then
		return false, nil, nil, nil
	end

	local afterCommand = string.sub(text, spacePos + 1)
	if #afterCommand == 0 then
		return true, nil, nil, nil
	end

	local nextSpace = string.find(afterCommand, " ", 1, true)
	local targetName: string
	local messageContent: string?

	if nextSpace then
		targetName = string.sub(afterCommand, 1, nextSpace - 1)
		messageContent = string.sub(afterCommand, nextSpace + 1)
		if #messageContent == 0 then
			messageContent = nil
		end
	else
		targetName = afterCommand
		messageContent = nil
	end

	if #targetName < MIN_AUTOFILL_LENGTH then
		return true, targetName, messageContent, nil
	end

	local targetPlayer = findUniquePlayerByPrefix(targetName)
	return true, targetName, messageContent, targetPlayer
end

local function MessageInput(scope: FusionScope, props: MessageInputProps): Frame
	local inputText = scope:Value("")
	local isFocused = scope:Value(false)
	local lastFocusTime = 0
	local justFocused = false
	local cursorBlinkThread: thread? = nil
	local previousTextLength = 0
	local whisperExitPrimed = false

	local currentChannel = scope:Computed(function(use: FusionUseFn)
		local channel = props.CurrentChannel
		if typeof(channel) == "table" then
			return use(channel :: any)
		end
		return channel :: ChannelId
	end)

	local currentFilter = scope:Computed(function(use: FusionUseFn)
		local filter = props.CurrentFilter
		if typeof(filter) == "table" then
			return use(filter :: any)
		end
		return filter :: GlobalFilter
	end)

	local isMuted = scope:Computed(function(use: FusionUseFn)
		local muted = props.IsMuted
		if typeof(muted) == "table" then
			return use(muted :: any)
		end
		return muted :: boolean
	end)

	local whisperTarget = scope:Computed(function(use: FusionUseFn)
		local target = props.WhisperTarget
		if target and typeof(target) == "table" then
			return use(target :: any)
		end
		return nil :: Player?
	end)

	local isWhispering = scope:Computed(function(use: FusionUseFn)
		return use(whisperTarget) ~= nil
	end)

	local whisperDisplayName = scope:Computed(function(use: FusionUseFn)
		local target = use(whisperTarget)
		if target then
			return target.DisplayName
		end
		return ""
	end)

	local placeholderText = scope:Computed(function(use: FusionUseFn)
		if use(isWhispering) then
			return "Type your message..."
		end

		local channel = use(currentChannel)
		local filter = use(currentFilter)

		if channel == "GLOBAL" then
			if filter == "TEAM" then
				return "TEAM: Press / or click here to chat"
			else
				return "ALL: Press / or click here to chat"
			end
		end

		return getChannelName(channel) .. ": Press / or click here to chat"
	end)

	local textBox: TextBox

	local whisperBadgeWidth = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			local target = use(whisperTarget)
			if target then
				return computeBadgeWidth(target.DisplayName)
			end
			return 0
		end),
		40, 1
	)

	local whisperBadgeTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isWhispering) then 0 else 1
		end),
		40,
		1
	)

	local function setWhisperTarget(target: Player?)
		whisperExitPrimed = false
		if props.OnWhisperTargetChange then
			props.OnWhisperTargetChange(target)
		end
	end

	local function clearWhisperTarget()
		setWhisperTarget(nil)
	end

	local function handleTextChange(newText: string)
		newText = string.gsub(newText, "[\r\n]", "")

		local timeSinceFocus = os.clock() - lastFocusTime
		local isDeleting = #newText < previousTextLength
		previousTextLength = #newText

		if justFocused then
			if #newText == 0 then
				return
			end
			justFocused = false
		end

		local isKeybindChar = timeSinceFocus < 0.035 and #newText == 1 and not newText:match("^%w$")
		if isKeybindChar then
			inputText:set("")
			textBox.Text = ""
			previousTextLength = 0
			return
		end

		if #newText > Constants.Message.maxLength then
			newText = string.sub(newText, 1, Constants.Message.maxLength)
		end

		if not isDeleting and not peek(isWhispering) then
			local isWhisperCmd, _, messageContent, targetPlayer = parseWhisperCommand(newText)

			if isWhisperCmd and targetPlayer then
				setWhisperTarget(targetPlayer)
				inputText:set(messageContent or "")
				previousTextLength = #(messageContent or "")
				task.defer(function()
					textBox.Text = messageContent or ""
					textBox.CursorPosition = #(messageContent or "") + 1
				end)
				return
			end
		end

		if #newText > 0 then
			whisperExitPrimed = false
		end
		inputText:set(newText)
	end

	local function handleFocused()
		lastFocusTime = os.clock()
		justFocused = true
		isFocused:set(true)
		props.OnFocusChanged(true)

		if cursorBlinkThread then
			task.cancel(cursorBlinkThread)
		end
	end

	local inputConnection: RBXScriptConnection? = nil
	local function setupInputHandler()
		if inputConnection then
			inputConnection:Disconnect()
		end
		inputConnection = UserInputService.InputBegan:Connect(function(input, _)
			if not peek(isFocused) then
				return
			end

			if input.KeyCode == Enum.KeyCode.Escape then
				if peek(isWhispering) then
					clearWhisperTarget()
				end
				return
			end

			if input.KeyCode == Enum.KeyCode.Backspace then
				task.defer(function()
					if #peek(inputText) == 0 and peek(isWhispering) then
						if whisperExitPrimed then
							clearWhisperTarget()
						else
							whisperExitPrimed = true
						end
					end
				end)
			end
		end)
	end

	table.insert(scope, function()
		if inputConnection then
			inputConnection:Disconnect()
			inputConnection = nil
		end
		if cursorBlinkThread then
			task.cancel(cursorBlinkThread)
			cursorBlinkThread = nil
		end
	end)

	local function handleFocusLost(enterPressed: boolean)
		props.OnFocusChanged(false)
		isFocused:set(false)
		justFocused = false

		if cursorBlinkThread then
			task.cancel(cursorBlinkThread)
			cursorBlinkThread = nil
		end

		if not enterPressed then
			return
		end

		local text = peek(inputText)
		if #text == 0 then
			return
		end

		local currentWhisperTarget = peek(whisperTarget)

		if currentWhisperTarget then
			local messageToSend = text
			if string.match(text, Constants.Patterns.vultarEnduresInput) then
				messageToSend = "VULTAR ENDURES!"
			end
			props.OnSendMessage(messageToSend, false, currentWhisperTarget)
			inputText:set("")
			previousTextLength = 0
			return
		end

		local channel = peek(currentChannel)
		local filter = peek(currentFilter)
		local commandResult = ChatCommands.parse(text, findPlayerByPartial)

		if commandResult.handled then
			if commandResult.whisperTarget then
				setWhisperTarget(commandResult.whisperTarget)
				if commandResult.message and #commandResult.message > 0 then
					local messageToSend = commandResult.message
					if string.match(messageToSend, Constants.Patterns.vultarEnduresInput) then
						messageToSend = "VULTAR ENDURES!"
					end
					props.OnSendMessage(messageToSend, false, commandResult.whisperTarget)
				end
				inputText:set("")
				previousTextLength = 0
				return
			end

			if commandResult.channelId and props.OnChannelChange then
				props.OnChannelChange(commandResult.channelId :: ChannelId)
			end

			if commandResult.filter then
				props.OnFilterChange(commandResult.filter :: GlobalFilter)
			end

			if commandResult.message and #commandResult.message > 0 then
				local messageToSend = commandResult.message
				if string.match(messageToSend, Constants.Patterns.vultarEnduresInput) then
					messageToSend = "VULTAR ENDURES!"
				end
				props.OnSendMessage(messageToSend, commandResult.isTeamOnly, nil)
			end

			inputText:set("")
			previousTextLength = 0
			return
		end

		local messageToSend = text
		if string.match(text, Constants.Patterns.vultarEnduresInput) then
			messageToSend = "VULTAR ENDURES!"
		end

		local isTeamOnly = channel == "GLOBAL" and filter == "TEAM"
		props.OnSendMessage(messageToSend, isTeamOnly, nil)
		inputText:set("")
		previousTextLength = 0
	end

	local whisperBadge = scope:New("Frame")({
		Name = "WhisperBadge",
		Size = scope:Computed(function(use: FusionUseFn)
			return UDim2.new(0, use(whisperBadgeWidth), 1, 0)
		end),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Color3.fromRGB(216, 160, 255),
		BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
			return 0.85 + use(whisperBadgeTransparency) * 0.15
		end),
		ClipsDescendants = true,
		ZIndex = 2,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Medium,
			}),

			scope:New("UIStroke")({
				Color = Color3.fromRGB(216, 160, 255),
				Thickness = 1,
				Transparency = scope:Computed(function(use: FusionUseFn)
					return 0.5 + use(whisperBadgeTransparency) * 0.5
				end),
			}),

			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),

			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			scope:New("TextLabel")({
				Name = "Label",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Text = "Whispering",
				TextColor3 = Color3.fromRGB(216, 160, 255),
				TextSize = 11,
				Font = Enum.Font.GothamMedium,
				TextTransparency = whisperBadgeTransparency,
			}),

			scope:New("TextLabel")({
				Name = "Username",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Text = whisperDisplayName,
				TextColor3 = Theme.Colors.White,
				TextSize = 11,
				Font = Enum.Font.GothamBold,
				TextTransparency = whisperBadgeTransparency,
			}),

			scope:New("TextButton")({
				Name = "CloseButton",
				LayoutOrder = 3,
				Size = UDim2.fromOffset(BADGE_CLOSE_SIZE, BADGE_CLOSE_SIZE),
				BackgroundColor3 = Color3.fromRGB(216, 160, 255),
				BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
					return 0.55 + use(whisperBadgeTransparency) * 0.45
				end),
				Text = "×",
				TextColor3 = Theme.Colors.White,
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				TextTransparency = whisperBadgeTransparency,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Radius.Full }),
				},

				[Fusion.OnEvent("Activated")] = function()
					clearWhisperTarget()
				end,
			}),
		},
	})

	textBox = scope:New("TextBox")({
		Name = "Input",
		Size = scope:Computed(function(use: FusionUseFn)
			local badgeW = use(whisperBadgeWidth)
			local gap = if badgeW > 1 then 8 else 0
			return UDim2.new(1, -(badgeW + gap), 1, 0)
		end),
		Position = scope:Computed(function(use: FusionUseFn)
			local badgeW = use(whisperBadgeWidth)
			local gap = if badgeW > 1 then 8 else 0
			return UDim2.fromOffset(badgeW + gap, 0)
		end),
		BackgroundTransparency = 1,
		Text = inputText,
		PlaceholderText = placeholderText,
		PlaceholderColor3 = Constants.Colors.placeholder,
		TextColor3 = Constants.Colors.inputText,
		TextSize = Constants.Text.size,
		Font = Constants.Text.font,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		TextEditable = scope:Computed(function(use: FusionUseFn)
			return not use(isMuted)
		end),
		Visible = scope:Computed(function(use: FusionUseFn)
			return not use(isMuted)
		end),

		[Fusion.Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, Constants.Text.padding),
				PaddingRight = UDim.new(0, Constants.Text.padding),
			}),
		},

		[Fusion.OnChange("Text")] = handleTextChange,
		[Fusion.OnEvent("Focused")] = handleFocused,
		[Fusion.OnEvent("FocusLost")] = handleFocusLost,
	}) :: TextBox

	if props.OnTextBoxCreated then
		task.defer(function()
			props.OnTextBoxCreated(textBox)
		end)
	end

	setupInputHandler()

	local mutedLabel = scope:New("TextLabel")({
		Name = "MutedLabel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "You are muted",
		TextColor3 = Theme.Colors.Destructive,
		TextSize = Constants.Text.size,
		Font = Constants.Text.font,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = isMuted,

		[Fusion.Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, Constants.Text.padding),
				PaddingRight = UDim.new(0, Constants.Text.padding),
			}),
		},
	})

	return scope:New("Frame")({
		Name = "MessageInput",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			}),
			whisperBadge,
			textBox,
			mutedLabel,
		},
	})
end

return MessageInput
