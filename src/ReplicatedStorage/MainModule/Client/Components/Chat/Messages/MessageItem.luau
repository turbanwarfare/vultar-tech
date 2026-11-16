local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local GradientConfig = require(MainModule.Shared.Config.GradientConfig)
local ChatTypes = require(MainModule.Shared.Network.Chat.Types)
local TextSanitizer = require(MainModule.Shared.Utils.Text.TextSanitizer)
local LocalPlayerCache = require(MainModule.Client.Cache.LocalPlayerCache)
local ChatConstants = require(MainModule.Shared.Chat.Constants)
local Theme = require(MainModule.Shared.UI.Theme)

local MessageFormatter = require(script.Parent.MessageFormatter)
local GradientDriver = require(script.Parent.GradientDriver)

local MSG_HOVER_TWEEN_IN = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local MSG_HOVER_TWEEN_OUT = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SLIDE_ANIM_DURATION = 0.25

type FusionScope = Types.FusionScope
type MessageGradient = {
	colors: { Color3 },
	rotation: number?,
}

local function convertMessageGradient(gradient: MessageGradient): GradientConfig.GradientDefinition?
	if not gradient or not gradient.colors or #gradient.colors < 2 then
		return nil
	end

	local colors = gradient.colors
	local colorCount = #colors

	local keypoints: { ColorSequenceKeypoint } = {}

	if colorCount == 7 then
		keypoints = {
			ColorSequenceKeypoint.new(0, colors[1]),
			ColorSequenceKeypoint.new(0.18, colors[2]),
			ColorSequenceKeypoint.new(0.35, colors[3]),
			ColorSequenceKeypoint.new(0.50, colors[4]),
			ColorSequenceKeypoint.new(0.65, colors[5]),
			ColorSequenceKeypoint.new(0.82, colors[6]),
			ColorSequenceKeypoint.new(1, colors[7]),
		}
	else
		for i, color in ipairs(colors) do
			local position = (i - 1) / (colorCount - 1)
			table.insert(keypoints, ColorSequenceKeypoint.new(position, color))
		end
	end

	return {
		id = "MESSAGE_GRADIENT",
		colors = ColorSequence.new(keypoints),
		speed = 0.35,
	}
end
type FusionUseFn = Types.FusionUseFn
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type ChatMessage = ChatTypes.ChatMessage

export type MessageItemProps = {
	Message: ChatMessage,
	LayoutOrder: FusionCanBeState<number>?,
	AnimateIn: boolean?,
	OnUsernameClick: ((senderId: number, senderName: string) -> ())?,
}

local function createRegisteredGradient(scope: FusionScope, gradientColors: ColorSequence): UIGradient
	local uiGradient = scope:New("UIGradient")({
		Color = gradientColors,
		Rotation = 0,
		Offset = Vector2.new(GradientDriver.getCurrentOffset() - 1, 0),
	})
	GradientDriver.register(uiGradient :: any)
	return uiGradient :: any
end

local function buildIconContainer(scope: FusionScope, iconTags: { string }, animatedProgress: any, xOffset: number?): Frame
	local iconSize = ChatConstants.Text.messageTextSize
	local iconChildren: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 4),
		}),
	}

	for i, iconAsset in iconTags do
		table.insert(iconChildren, scope:New("ImageLabel")({
			Name = "IconTag_" .. i,
			Size = UDim2.fromOffset(iconSize, iconSize),
			BackgroundTransparency = 1,
			Image = iconAsset,
			ScaleType = Enum.ScaleType.Fit,
			LayoutOrder = i,
			ImageTransparency = scope:Computed(function(use: FusionUseFn)
				return 1 - use(animatedProgress)
			end),
		}))
	end

	local iconOffset = #iconTags * (iconSize + 4)
	return scope:New("Frame")({
		Name = "IconContainer",
		Size = UDim2.fromOffset(iconOffset, iconSize),
		Position = UDim2.fromOffset(xOffset or 0, 1),
		BackgroundTransparency = 1,
		[Fusion.Children] = iconChildren,
	})
end

local function buildWhisperTagPlain(message: ChatMessage, localUserId: number): string?
	if not message.isWhisper then return nil end
	if message.senderId == localUserId then
		local safeTargetName = TextSanitizer.sanitizeUsername(message.whisperTargetName or "Unknown")
		return "[To " .. safeTargetName .. "] "
	end
	local safeSenderName = TextSanitizer.sanitizeUsername(message.senderName)
	return "[From " .. safeSenderName .. "] "
end

local function measureWhisperTagWidth(text: string?): number
	if not text or text == "" then return 0 end
	local ok, size = pcall(TextService.GetTextSize, TextService, text, ChatConstants.Text.messageTextSize, Enum.Font.GothamBold, Vector2.new(10000, 10000))
	if not ok then return 0 end
	return math.ceil(size.X)
end

local function buildWhisperTagLabel(scope: FusionScope, text: string, width: number, animatedProgress: any, xOffset: number): TextLabel
	local whisperColor = ChatConstants.Colors.whisper
	return scope:New("TextLabel")({
		Name = "WhisperTag",
		Size = UDim2.fromOffset(width, ChatConstants.Text.messageTextSize),
		Position = UDim2.fromOffset(xOffset, 0),
		BackgroundTransparency = 1,
		RichText = false,
		Text = text,
		TextColor3 = Color3.fromHex(whisperColor),
		TextStrokeTransparency = 1,
		TextSize = ChatConstants.Text.messageTextSize,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = ChatConstants.Text.lineHeight,
		TextTransparency = scope:Computed(function(use: FusionUseFn)
			return 1 - use(animatedProgress)
		end),
		ZIndex = 3,
	})
end

local function createGradientMessageItem(
	scope: FusionScope,
	message: ChatMessage,
	animatedProgress: any,
	_playerName: string,
	_displayName: string,
	gradient: GradientConfig.GradientDefinition,
	isVultarEndures: boolean?,
	iconTags: { string },
	localUserId: number
): Frame
	local unsubscribe = GradientDriver.subscribe()
	table.insert(scope, unsubscribe)

	if message.isSystem then
		local plainContent = (TextSanitizer.decodeEntities(message.content):gsub("[\0-\8\11\12\14-\31]", ""))
		local fullText = "[SYSTEM]: " .. plainContent
		return scope:New("Frame")({
			Name = "GradientSystemMessage",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,

			[Fusion.Children] = {
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, 4),
					PaddingTop = UDim.new(0, 5),
					PaddingBottom = UDim.new(0, 5),
				}),

				scope:New("TextLabel")({
					Name = "GradientFullText",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					RichText = false,
					Text = fullText,
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = ChatConstants.Text.messageTextSize,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
					LineHeight = ChatConstants.Text.lineHeight,
					TextTransparency = scope:Computed(function(use: FusionUseFn)
						return 1 - use(animatedProgress)
					end),

					[Fusion.Children] = {
						createRegisteredGradient(scope, gradient.colors),
					},
				}),
			},
		})
	end

	local hasIcons = #iconTags > 0
	local iconOffset = if hasIcons then #iconTags * (ChatConstants.Text.messageTextSize + 4) else 0

	local prefixText = MessageFormatter.buildGradientPrefix(message)
	local safeContent = TextSanitizer.sanitizeForChat(message.content)

	local whisperTagText = buildWhisperTagPlain(message, localUserId)
	local whisperTagWidth = measureWhisperTagWidth(whisperTagText)
	local totalLeftOffset = whisperTagWidth + iconOffset

	if isVultarEndures then
		local enduresColor = MessageFormatter.getVultarEnduresColor(message)
		local boldPrefix = "<b>" .. prefixText .. "</b>"
		local contentText = string.format('<font color="#%s"><b>%s</b></font>', enduresColor, safeContent)
		local fullText = boldPrefix .. " " .. contentText

		local children: { any } = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 5),
				PaddingBottom = UDim.new(0, 5),
			}),
		}

		if whisperTagText then
			table.insert(children, buildWhisperTagLabel(scope, whisperTagText, whisperTagWidth, animatedProgress, 0))
		end

		if hasIcons then
			table.insert(children, buildIconContainer(scope, iconTags, animatedProgress, whisperTagWidth))
		end

		table.insert(children, scope:New("TextLabel")({
			Name = "MessageContent",
			Size = UDim2.new(1, -totalLeftOffset, 0, 0),
			Position = UDim2.fromOffset(totalLeftOffset, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			RichText = true,
			Text = fullText,
			TextColor3 = ChatConstants.Colors.messageText,
			TextStrokeTransparency = 1,
			TextSize = ChatConstants.Text.messageTextSize,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			LineHeight = ChatConstants.Text.lineHeight,
			TextTransparency = scope:Computed(function(use: FusionUseFn)
				return 1 - use(animatedProgress)
			end),
			ZIndex = 1,
		}))

		table.insert(children, scope:New("TextLabel")({
			Name = "GradientPrefix",
			Size = UDim2.new(1, -totalLeftOffset, 0, 0),
			Position = UDim2.fromOffset(totalLeftOffset, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			RichText = false,
			Text = prefixText,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 1,
			TextSize = ChatConstants.Text.messageTextSize,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			LineHeight = ChatConstants.Text.lineHeight,
			TextTransparency = scope:Computed(function(use: FusionUseFn)
				return 1 - use(animatedProgress)
			end),
			ZIndex = 2,

			[Fusion.Children] = {
				createRegisteredGradient(scope, gradient.colors),
			},
		}))

		return scope:New("Frame")({
			Name = "GradientMessageContent",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,

			[Fusion.Children] = children,
		})
	end

	local boldPrefix = "<b>" .. prefixText .. "</b>"
	local fullText = boldPrefix .. " " .. safeContent

	local children: { any } = {
		scope:New("UIPadding")({
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
		}),
	}

	if whisperTagText then
		table.insert(children, buildWhisperTagLabel(scope, whisperTagText, whisperTagWidth, animatedProgress, 0))
	end

	if hasIcons then
		table.insert(children, buildIconContainer(scope, iconTags, animatedProgress, whisperTagWidth))
	end

	table.insert(children, scope:New("TextLabel")({
		Name = "MessageContent",
		Size = UDim2.new(1, -totalLeftOffset, 0, 0),
		Position = UDim2.fromOffset(totalLeftOffset, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		RichText = true,
		Text = fullText,
		TextColor3 = ChatConstants.Colors.messageText,
		TextStrokeTransparency = 1,
		TextSize = ChatConstants.Text.messageTextSize,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		LineHeight = ChatConstants.Text.lineHeight,
		TextTransparency = scope:Computed(function(use: FusionUseFn)
			return 1 - use(animatedProgress)
		end),
		ZIndex = 1,
	}))

	table.insert(children, scope:New("TextLabel")({
		Name = "GradientPrefix",
		Size = UDim2.new(1, -totalLeftOffset, 0, 0),
		Position = UDim2.fromOffset(totalLeftOffset, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		RichText = false,
		Text = prefixText,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 1,
		TextSize = ChatConstants.Text.messageTextSize,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		LineHeight = ChatConstants.Text.lineHeight,
		TextTransparency = scope:Computed(function(use: FusionUseFn)
			return 1 - use(animatedProgress)
		end),
		ZIndex = 2,

		[Fusion.Children] = {
			createRegisteredGradient(scope, gradient.colors),
		},
	}))

	return scope:New("Frame")({
		Name = "GradientMessageContent",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,

		[Fusion.Children] = children,
	})
end

local function MessageItem(scope: FusionScope, props: MessageItemProps): Frame
	local message = props.Message
	local shouldAnimate = props.AnimateIn == true
	local animatedProgress = scope:Value(if shouldAnimate then 0 else 1)

	if shouldAnimate then
		task.defer(function()
			task.wait(0.015)
			local startTime = os.clock()
			while true do
				local t = math.min((os.clock() - startTime) / SLIDE_ANIM_DURATION, 1)
				animatedProgress:set(1 - (1 - t) * (1 - t) * (1 - t))
				if t >= 1 then break end
				task.wait()
			end
			animatedProgress:set(1)
		end)
	end

	local playerName = LocalPlayerCache.getName()
	local displayName = LocalPlayerCache.getDisplayName()
	local localUserId = LocalPlayerCache.getUserId()

	local isVultarEndures = MessageFormatter.isVultarEndures(message.content)
	local gradientDef: GradientConfig.GradientDefinition? = nil

	if message.gradient then
		gradientDef = convertMessageGradient(message.gradient :: MessageGradient)
	end

	local displayText: string
	if message.isSystem then
		displayText = MessageFormatter.formatSystemMessage(message)
	elseif message.isWhisper then
		displayText = MessageFormatter.formatWhisperMessage(message, localUserId, playerName, displayName)
	elseif isVultarEndures then
		displayText = MessageFormatter.formatVultarEnduresMessage(message)
	else
		displayText = MessageFormatter.formatStandardMessage(message, playerName, displayName)
	end

	local iconTags = MessageFormatter.getIconTags(message)
	local iconSize = ChatConstants.Text.messageTextSize

	local contentElement: Frame
	if gradientDef then
		contentElement = createGradientMessageItem(scope, message, animatedProgress, playerName, displayName, gradientDef, isVultarEndures, iconTags, localUserId)
	else
		local children: { any } = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 5),
				PaddingBottom = UDim.new(0, 5),
			}),
		}

		if #iconTags > 0 then
			local iconOffset = #iconTags * (iconSize + 4)

			local iconChildren: { any } = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					Padding = UDim.new(0, 4),
				}),
			}

			for i, iconAsset in iconTags do
				table.insert(iconChildren, scope:New("ImageLabel")({
					Name = "IconTag_" .. i,
					Size = UDim2.fromOffset(iconSize, iconSize),
					BackgroundTransparency = 1,
					Image = iconAsset,
					ScaleType = Enum.ScaleType.Fit,
					LayoutOrder = i,
					ImageTransparency = scope:Computed(function(use: FusionUseFn)
						return 1 - use(animatedProgress)
					end),
				}))
			end

			table.insert(children, scope:New("Frame")({
				Name = "IconContainer",
				Size = UDim2.fromOffset(iconOffset, iconSize),
				Position = UDim2.fromOffset(0, 1),
				BackgroundTransparency = 1,
				[Fusion.Children] = iconChildren,
			}))

			table.insert(children, scope:New("TextLabel")({
				Name = "Message",
				Size = UDim2.new(1, -iconOffset, 0, 0),
				Position = UDim2.fromOffset(iconOffset, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				RichText = true,
				Text = displayText,
				TextColor3 = ChatConstants.Colors.messageText,
				TextSize = ChatConstants.Text.messageTextSize,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				LineHeight = ChatConstants.Text.lineHeight,
				TextTransparency = scope:Computed(function(use: FusionUseFn)
					return 1 - use(animatedProgress)
				end),
			}))
		else
			table.insert(children, scope:New("TextLabel")({
				Name = "Message",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				RichText = true,
				Text = displayText,
				TextColor3 = ChatConstants.Colors.messageText,
				TextSize = ChatConstants.Text.messageTextSize,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				LineHeight = ChatConstants.Text.lineHeight,
				TextTransparency = scope:Computed(function(use: FusionUseFn)
					return 1 - use(animatedProgress)
				end),
			}))
		end

		contentElement = scope:New("Frame")({
			Name = "StandardMessageContent",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Fusion.Children] = children,
		})
	end

	local isClickable = not message.isSystem and message.senderId ~= localUserId

	local messageFrame = scope:New("Frame")({
		Name = "MessageItem_" .. message.id,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.White,
		BackgroundTransparency = 1,
		LayoutOrder = if props.LayoutOrder then props.LayoutOrder else 0,
		ClipsDescendants = true,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = UDim.new(0, 4),
			}),

			scope:New("Frame")({
				Name = "SlideContainer",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = scope:Computed(function(use: FusionUseFn)
					local progress = use(animatedProgress)
					local offsetX = (1 - progress) * -80
					return UDim2.fromOffset(offsetX, 0)
				end),
				BackgroundTransparency = 1,

				[Fusion.Children] = { contentElement },
			}),

			if isClickable then scope:New("TextButton")({
				Name = "ClickArea",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 10,

				[Fusion.OnEvent("MouseEnter")] = function()
					if messageFrame and messageFrame.Parent then
						TweenService:Create(messageFrame, MSG_HOVER_TWEEN_IN, { BackgroundTransparency = 0.85 }):Play()
					end
				end,

				[Fusion.OnEvent("MouseLeave")] = function()
					if messageFrame and messageFrame.Parent then
						TweenService:Create(messageFrame, MSG_HOVER_TWEEN_OUT, { BackgroundTransparency = 1 }):Play()
					end
				end,

				[Fusion.OnEvent("Activated")] = function()
					if props.OnUsernameClick then
						props.OnUsernameClick(message.senderId, message.senderName)
					end
				end,
			}) else nil,
		},
	})

	return messageFrame
end

return MessageItem
