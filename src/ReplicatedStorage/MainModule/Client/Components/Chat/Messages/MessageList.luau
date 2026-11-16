--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local ChatTypes = require(MainModule.Shared.Network.Chat.Types)
local ChatConstants = require(MainModule.Shared.Chat.Constants)

local MessageItem = require(script.Parent.MessageItem)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn
type ChatMessage = ChatTypes.ChatMessage

export type MessageListProps = {
	Messages: FusionCanBeState<{ ChatMessage }>,
	LayoutOrder: number?,
	OnUsernameClick: ((senderId: number, senderName: string) -> ())?,
	ViewportScale: FusionCanBeState<number>?,
}

local function MessageList(scope: FusionScope, props: MessageListProps): Frame
	local scrollFrameRef: ScrollingFrame? = nil
	local messageContainerRef: Frame? = nil

	local viewportHeight = scope:Value(0)
	local messagesHeight = scope:Value(0)

	local currentScale = scope:Computed(function(use: FusionUseFn)
		local scale = props.ViewportScale
		if scale then
			if typeof(scale) == "table" then
				return use(scale :: any)
			end
			return scale :: number
		end
		return 1
	end)

	local spacerHeight = scope:Computed(function(use: FusionUseFn)
		local viewport = use(viewportHeight)
		local messages = use(messagesHeight)
		local scale = use(currentScale)
		local actualSpacerNeeded = math.max(0, viewport - messages)
		return actualSpacerNeeded // math.max(0.1, scale)
	end)

	local function scrollToBottomSync()
		local frame = scrollFrameRef
		if not frame or not frame.Parent then
			return
		end

		local canvas = frame.AbsoluteCanvasSize.Y
		local frameHeight = frame.AbsoluteSize.Y
		if canvas > frameHeight then
			frame.CanvasPosition = Vector2.new(0, canvas - frameHeight)
		else
			frame.CanvasPosition = Vector2.zero
		end
	end

	local function updateViewport()
		local frame = scrollFrameRef
		if frame then
			viewportHeight:set(frame.AbsoluteSize.Y)
		end
	end

	local function updateMessagesHeight()
		local container = messageContainerRef
		if container then
			messagesHeight:set(container.AbsoluteSize.Y)
		end
	end

	local messagesState = scope:Computed(function(use: FusionUseFn)
		local msgs = props.Messages
		if typeof(msgs) == "table" and (msgs :: any).type == "State" then
			return use(msgs :: any)
		end
		return msgs :: { ChatMessage }
	end)

	local seenMessageIds: { [string]: boolean } = {}
	local lastMessageCount = 0

	local function buildOrderMap(messages: { ChatMessage }): { [string]: number }
		local map: { [string]: number } = {}
		for i, msg in messages do
			map[msg.id] = i
		end
		return map
	end

	local orderMap = scope:Value(buildOrderMap(Fusion.peek(messagesState) or {}))

	local initialMessages = Fusion.peek(messagesState)
	if initialMessages then
		for _, msg in initialMessages do
			seenMessageIds[msg.id] = true
		end
		lastMessageCount = #initialMessages
	end

	local messageItems = scope:ForValues(
		messagesState,
		function(_use: FusionUseFn, itemScope: FusionScope, message: ChatMessage)
			local messageId = message.id
			local currentMessages = Fusion.peek(messagesState)
			local isNew = not seenMessageIds[messageId] and #currentMessages > lastMessageCount

			if not seenMessageIds[messageId] then
				seenMessageIds[messageId] = true
			end

			local layoutOrder = itemScope:Computed(function(use: FusionUseFn)
				local map = use(orderMap)
				return map[messageId] or 0
			end)

			local success, item = pcall(function()
				return MessageItem(itemScope, {
					Message = message,
					LayoutOrder = layoutOrder,
					AnimateIn = isNew,
					OnUsernameClick = props.OnUsernameClick,
				})
			end)

			if success and item then
				return item
			end
			return nil :: any
		end
	)

	scope:Observer(messagesState):onChange(function()
		local messages = Fusion.peek(messagesState)
		orderMap:set(buildOrderMap(messages))

		local currentIds: { [string]: boolean } = {}
		for _, msg in messages do
			currentIds[msg.id] = true
		end
		for id in seenMessageIds do
			if not currentIds[id] then
				seenMessageIds[id] = nil
			end
		end

		lastMessageCount = #messages
		task.defer(function()
			task.wait(0.02)
			scrollToBottomSync()
		end)
	end)

	local messageContainer = scope:New("Frame")({
		Name = "MessageContainer",
		LayoutOrder = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				Name = "MessageLayout",
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 0),
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
			}),
			messageItems,
		},
	})

	local topSpacer = scope:New("Frame")({
		Name = "TopSpacer",
		LayoutOrder = 0,
		Size = scope:Computed(function(use: FusionUseFn)
			return UDim2.new(1, 0, 0, use(spacerHeight))
		end),
		BackgroundTransparency = 1,
	})

	local scrollFrame = scope:New("ScrollingFrame")({
		Name = "ScrollArea",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = ChatConstants.Colors.scrollBar,
		ScrollBarImageTransparency = 0.3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
		ElasticBehavior = Enum.ElasticBehavior.Never,
		TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				Name = "OuterLayout",
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 0),
			}),
			topSpacer,
			messageContainer,
		},
	})

	scrollFrameRef = scrollFrame :: ScrollingFrame
	messageContainerRef = messageContainer :: Frame

	table.insert(scope, (scrollFrame :: ScrollingFrame):GetPropertyChangedSignal("AbsoluteSize"):Connect(updateViewport))
	table.insert(scope, (messageContainer :: Frame):GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		updateMessagesHeight()
		task.defer(scrollToBottomSync)
	end))

	task.defer(function()
		task.wait(0.05)
		updateViewport()
		updateMessagesHeight()
		scrollToBottomSync()
	end)

	return scope:New("Frame")({
		Name = "MessageList",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		ClipsDescendants = true,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "SafeArea",
				Size = UDim2.new(1, -ChatConstants.UI.safeAreaPadding * 2, 1, -ChatConstants.UI.safeAreaPadding * 2),
				Position = UDim2.fromOffset(ChatConstants.UI.safeAreaPadding, ChatConstants.UI.safeAreaPadding),
				BackgroundTransparency = 1,
				ClipsDescendants = true,

				[Fusion.Children] = { scrollFrame },
			}),
		},
	})
end

return MessageList
