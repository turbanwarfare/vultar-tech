--!strict
--!native
--!optimize 2

local Theme = require(script.Parent.Parent.UI.Theme)

local ChatConstants = {}

ChatConstants.Message = {
	maxLength = 200,
	historySize = 50,
}

ChatConstants.RateLimit = {
	messages = 60,
	window = 10,
}

ChatConstants.Input = {
	focusTriggerWindow = 0.15,
	minAutofillLength = 2,
}

ChatConstants.Cursor = {
	width = 1,
	height = 14,
	blinkInterval = 0.53,
}

ChatConstants.UI = {
	chatWidth = 420,
	chatHeight = 170,
	inputHeight = 34,
	elementGap = 8,
	tabsHeight = 30,
	tabsGap = 8,
	safeAreaPadding = 8,
	maxSeenIds = 200,
}

ChatConstants.Animation = {
	speed = 40,
	damping = 1,
	hiddenX = -375,
	visibleX = 8,
}

ChatConstants.Text = {
	size = 13,
	font = Enum.Font.GothamMedium,
	padding = 10,
	messageTextSize = 14,
	lineHeight = 1.3,
}

ChatConstants.Colors = {
	mention = Theme.Chat.Message.MentionHex,
	teamPrefix = Theme.Chat.Message.TeamPrefixHex,
	whisper = Theme.Chat.Message.WhisperHex,
	inputText = Theme.Chat.Input.Text,
	placeholder = Theme.Chat.Input.Placeholder,
	messageText = Theme.Chat.Message.Text,
	systemMessage = Theme.Chat.Message.SystemText,
	background = Theme.Chat.Window.Background,
	backgroundFocused = Theme.Chat.Input.BackgroundFocused,
	stroke = Theme.Chat.Input.Border,
	strokeFocused = Theme.Chat.Input.BorderFocused,
	scrollBar = Theme.Scrollbar.Thumb,
}

ChatConstants.Bubble = {
	duration = 6,
	fadeTime = 5,
	maxDistance = 50,
	studsOffset = Vector3.new(0, 2, 0),
}

ChatConstants.Patterns = {
	vultarEndures = "^%s*VULTAR%s+ENDURES!?%s*$",
	vultarEnduresInput = "^%s*[Vv][Uu][Ll][Tt][Aa][Rr]%s+[Ee][Nn][Dd][Uu][Rr][Ee][Ss]!?%s*$",
}

ChatConstants.Icons = {
	micEveryone = "rbxassetid://81091333882164",
	micTeamOnly = "rbxassetid://97652555645994",
}

return ChatConstants
