--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local ChatConfig = require(MainModule.Shared.Config.Chat.ChatConfig)
local ChatTypes = require(MainModule.Shared.Network.Chat.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn
type ChannelId = ChatTypes.ChannelId

export type ChannelSelectorProps = {
	CurrentChannel: FusionCanBeState<ChannelId>,
	VisibleChannels: FusionCanBeState<{ ChannelId }>,
	UnreadCounts: FusionCanBeState<{ [ChannelId]: number }>?,
	ChannelAlerts: FusionCanBeState<{ [ChannelId]: boolean }>?,
	OnChannelChange: (channelId: ChannelId) -> (),
	Position: FusionCanBeState<UDim2>?,
}

local SHADOW_SPREAD = 4
local SHADOW_OFFSET_Y = 2
local SHADOW_TRANSPARENCY = 0.7
local CARD_SIZE = 52
local CARD_GAP = -2
local DEFAULT_ICON_SIZE_X = 30
local DEFAULT_ICON_SIZE_Y = 30
local CARD_HOVER_BORDER_TRANSPARENCY = 0.3
local CARD_SELECTED_BORDER_TRANSPARENCY = 0
local BADGE_CORNER_RADIUS = 4
local BADGE_PADDING_H = 5
local BADGE_PADDING_V = 2
local BADGE_TEXT_SIZE = 10
local BADGE_ZINDEX = 20
local BADGE_TEXT_ZINDEX = 21

local PULSE_PERIOD = 1.4
local PULSE_STOP_DELAY = 0.5
local ALERT_ALPHA_THRESHOLD = 0.001
local ALERT_BORDER_MIN_THICKNESS = 1
local ALERT_BORDER_MAX_THICKNESS = 2
local ALERT_BORDER_MIN_TRANSPARENCY = 0
local ALERT_BORDER_MAX_TRANSPARENCY = 0.65
local HITBOX_ZINDEX = 10

local function NotificationBadge(scope: FusionScope, count: FusionCanBeState<number>): Frame
	local badgeVisible = scope:Computed(function(use: FusionUseFn)
		local c = count
		if typeof(c) == "table" then
			return use(c :: any) > 0
		end
		return (c :: number) > 0
	end)

	local badgeText = scope:Computed(function(use: FusionUseFn)
		local c = count
		local num: number
		if typeof(c) == "table" then
			num = use(c :: any)
		else
			num = c :: number
		end
		if num >= 10 then
			return "9+"
		end
		return tostring(num)
	end)

	return scope:New("Frame")({
		Name = "BadgeContainer",
		Position = UDim2.new(1, 0, 0, -2),
		AnchorPoint = Vector2.new(0.5, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		ZIndex = BADGE_ZINDEX,
		Visible = badgeVisible,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Badge",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Theme.Colors.Destructive,
				BorderSizePixel = 0,
				ZIndex = BADGE_ZINDEX,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, BADGE_CORNER_RADIUS),
					}),

					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, BADGE_PADDING_H),
						PaddingRight = UDim.new(0, BADGE_PADDING_H),
						PaddingTop = UDim.new(0, BADGE_PADDING_V),
						PaddingBottom = UDim.new(0, BADGE_PADDING_V),
					}),

					scope:New("TextLabel")({
						Name = "Count",
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						Text = badgeText,
						TextColor3 = Theme.Colors.White,
						TextSize = BADGE_TEXT_SIZE,
						Font = Enum.Font.GothamBold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						ZIndex = BADGE_TEXT_ZINDEX,
					}),
				},
			}),
		},
	})
end

local function ChannelCard(
	scope: FusionScope,
	channelId: ChannelId,
	currentChannel: FusionCanBeState<ChannelId>,
	unreadCount: FusionCanBeState<number>,
	isAlertActive: FusionCanBeState<boolean>?,
	onClick: () -> ()
): Frame
	local config = ChatConfig.getChannelConfig(channelId)
	if not config then
		return scope:New("Frame")({ Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 })
	end

	local isHovered = scope:Value(false)

	local isSelected = scope:Computed(function(use: FusionUseFn)
		local current = currentChannel
		if typeof(current) == "table" then
			return use(current :: any) == channelId
		end
		return current == channelId
	end)

	local isAlert = scope:Computed(function(use: FusionUseFn)
		if not isAlertActive then
			return false
		end
		local alert = isAlertActive
		if typeof(alert) == "table" and (alert :: any).type == "State" then
			return use(alert :: any) == true
		end
		if typeof(alert) == "table" then
			return use(alert :: any) == true
		end
		return alert == true
	end)

	local pulseProgress = scope:Value(0)
	local renderConn: RBXScriptConnection? = nil
	local stopDelayThread: thread? = nil
	local startTime = os.clock()

	local alertAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isAlert) then 1 else 0
		end),
		Theme.Spring.Default.Speed,
		Theme.Spring.Default.Damping
	)

	local function stopPulse(): ()
		if stopDelayThread then
			task.cancel(stopDelayThread)
			stopDelayThread = nil
		end
		if renderConn then
			renderConn:Disconnect()
			renderConn = nil
		end
		pulseProgress:set(0)
	end

	local function startPulse(): ()
		if stopDelayThread then
			task.cancel(stopDelayThread)
			stopDelayThread = nil
		end
		if renderConn then
			return
		end
		startTime = os.clock()
		renderConn = RunService.RenderStepped:Connect(function()
			local elapsed = os.clock() - startTime
			local sinVal = (math.sin(elapsed * (math.pi * 2 / PULSE_PERIOD)) + 1) * 0.5
			pulseProgress:set(sinVal)
		end)
	end

	local observer = scope:Observer(isAlert)
	observer:onChange(function()
		local active = Fusion.peek(isAlert)
		if active then
			startPulse()
		else
			if stopDelayThread then
				task.cancel(stopDelayThread)
			end
			stopDelayThread = task.delay(PULSE_STOP_DELAY, function()
				stopDelayThread = nil
				if not Fusion.peek(isAlert) then
					stopPulse()
				end
			end)
		end
	end)

	table.insert(scope, function()
		stopPulse()
	end)

	if Fusion.peek(isAlert) then
		startPulse()
	end

	local backgroundColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isSelected) then
				return Theme.Chat.Input.BackgroundFocused
			elseif use(isHovered) then
				return Theme.Chat.Input.Background
			end
			return Theme.Chat.Input.Background
		end),
		Theme.Spring.Default.Speed
	)

	local backgroundTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isSelected) then
				return Theme.Chat.Input.BackgroundFocusedTransparency
			end
			return Theme.Chat.Input.BackgroundTransparency
		end),
		Theme.Spring.Default.Speed,
		1
	)

	local borderColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isAlert) then
				return Theme.Colors.Destructive
			elseif use(isSelected) then
				return Theme.Chat.Input.BorderFocused
			elseif use(isHovered) then
				return Theme.Border.Default
			end
			return Theme.Border.Default
		end),
		Theme.Spring.Default.Speed
	)

	local borderThickness = scope:Computed(function(use: FusionUseFn)
		local alpha = use(alertAlpha)
		if alpha > ALERT_ALPHA_THRESHOLD then
			local pulse = use(pulseProgress)
			local targetThickness = ALERT_BORDER_MIN_THICKNESS + (pulse * (ALERT_BORDER_MAX_THICKNESS - ALERT_BORDER_MIN_THICKNESS))
			return 1 + (targetThickness - 1) * alpha
		end
		return 1
	end)

	local borderTransparency = scope:Computed(function(use: FusionUseFn)
		local alpha = use(alertAlpha)
		if alpha > ALERT_ALPHA_THRESHOLD then
			local pulse = use(pulseProgress)
			local alertTransparency = ALERT_BORDER_MIN_TRANSPARENCY + ((1 - pulse) * (ALERT_BORDER_MAX_TRANSPARENCY - ALERT_BORDER_MIN_TRANSPARENCY))
			local resting = if use(isSelected) then CARD_SELECTED_BORDER_TRANSPARENCY else CARD_HOVER_BORDER_TRANSPARENCY
			return resting + (alertTransparency - resting) * alpha
		elseif use(isSelected) then
			return CARD_SELECTED_BORDER_TRANSPARENCY
		end
		return CARD_HOVER_BORDER_TRANSPARENCY
	end)

	local textColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isSelected) then
				return Theme.Colors.White
			elseif use(isHovered) then
				return Theme.Foreground.Secondary
			end
			return Theme.Foreground.Muted
		end),
		Theme.Spring.Default.Speed,
		1
	)

	local iconTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isSelected) then
				return 0
			elseif use(isHovered) then
				return 0.1
			end
			return 0.25
		end),
		Theme.Spring.Default.Speed,
		1
	)

	local shadowTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isSelected) then
				return SHADOW_TRANSPARENCY - 0.15
			elseif use(isHovered) then
				return SHADOW_TRANSPARENCY - 0.1
			end
			return SHADOW_TRANSPARENCY
		end),
		Theme.Spring.Default.Speed,
		1
	)

	return scope:New("Frame")({
		Name = channelId,
		Size = UDim2.fromOffset(CARD_SIZE + SHADOW_SPREAD * 2, CARD_SIZE + SHADOW_SPREAD * 2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = config.order,

		[Fusion.Children] = {
			Shadow(scope, {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = 0,
				Transparency = shadowTransparency,
				ZIndex = 0,
			}),

			scope:New("Frame")({
				Name = "Card",
				Size = UDim2.fromOffset(CARD_SIZE, CARD_SIZE),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = backgroundColor,
				BackgroundTransparency = backgroundTransparency,
				BorderSizePixel = 0,
				ZIndex = 1,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Medium,
					}),

					scope:New("UIStroke")({
						Color = borderColor,
						Thickness = borderThickness,
						Transparency = borderTransparency,
					}),

					scope:New("ImageLabel")({
						Name = "Icon",
						Size = if config.iconSize
							then UDim2.fromOffset(config.iconSize.X, config.iconSize.Y)
							else UDim2.fromOffset(DEFAULT_ICON_SIZE_X, DEFAULT_ICON_SIZE_Y),
						Position = UDim2.new(0.5, 0, 0, 5),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Image = config.icon or "",
						ImageColor3 = Theme.Colors.White,
						ImageTransparency = iconTransparency,
						Visible = config.icon ~= nil and config.icon ~= "",
						ZIndex = 2,
					}),

					scope:New("TextLabel")({
						Name = "Label",
						Size = UDim2.new(1, -4, 0, 14),
						Position = UDim2.new(0.5, 0, 1, -16),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Text = string.upper(config.name),
						TextColor3 = textColor,
						TextSize = 11,
						Font = Enum.Font.GothamBold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextTruncate = Enum.TextTruncate.AtEnd,
						RichText = false,
						TextTransparency = 0,
						TextScaled = false,
						ZIndex = 2,
					}),

					NotificationBadge(scope, unreadCount),

					scope:New("TextButton")({
						Name = "Hitbox",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = HITBOX_ZINDEX,

						[Fusion.OnEvent("MouseEnter")] = function()
							isHovered:set(true)
						end,

						[Fusion.OnEvent("MouseLeave")] = function()
							isHovered:set(false)
						end,

						[Fusion.OnEvent("Activated")] = function()
							onClick()
						end,
					}),
				},
			}),
		},
	})
end

local function ChannelSelector(scope: FusionScope, props: ChannelSelectorProps): Frame
	local channelCount = scope:Computed(function(use: FusionUseFn)
		local channels = props.VisibleChannels
		if typeof(channels) == "table" and (channels :: any).type == "State" then
			return #use(channels :: any)
		end
		return #(channels :: { ChannelId })
	end)

	local shouldShow = scope:Computed(function(use: FusionUseFn)
		return use(channelCount) > 1
	end)

	local position = scope:Computed(function(use: FusionUseFn)
		local pos = props.Position
		if pos == nil then
			return UDim2.fromOffset(-SHADOW_SPREAD, 0)
		end
		if typeof(pos) == "table" then
			local p = use(pos :: any)
			return UDim2.new(p.X.Scale, p.X.Offset - SHADOW_SPREAD, p.Y.Scale, p.Y.Offset - SHADOW_SPREAD)
		end
		local p = pos :: UDim2
		return UDim2.new(p.X.Scale, p.X.Offset - SHADOW_SPREAD, p.Y.Scale, p.Y.Offset - SHADOW_SPREAD)
	end)

	return scope:New("Frame")({
		Name = "ChannelSelector",
		Size = UDim2.new(1, SHADOW_SPREAD * 2, 0, CARD_SIZE + SHADOW_SPREAD * 2),
		Position = position,
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use: FusionUseFn)
			return use(shouldShow)
		end),

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Channels",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, CARD_GAP),
						VerticalAlignment = Enum.VerticalAlignment.Center,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
					}),

					scope:ForValues(
						scope:Computed(function(use: FusionUseFn)
							local channels = props.VisibleChannels
							if typeof(channels) == "table" and (channels :: any).type == "State" then
								return use(channels :: any)
							end
							return channels :: { ChannelId }
						end),
						function(_use: FusionUseFn, cardScope: FusionScope, channelId: ChannelId)
							local unreadCount = cardScope:Computed(function(innerUse: FusionUseFn)
								if not props.UnreadCounts then
									return 0
								end
								local counts: { [ChannelId]: number }
								if typeof(props.UnreadCounts) == "table" and (props.UnreadCounts :: any).type == "State" then
									counts = innerUse(props.UnreadCounts :: any)
								else
									counts = props.UnreadCounts :: { [ChannelId]: number }
								end
								return counts[channelId] or 0
							end)

							local isAlertActive = cardScope:Computed(function(innerUse: FusionUseFn)
								if not props.ChannelAlerts then
									return false
								end
								local alerts: { [ChannelId]: boolean }
								if typeof(props.ChannelAlerts) == "table" and (props.ChannelAlerts :: any).type == "State" then
									alerts = innerUse(props.ChannelAlerts :: any)
								else
									alerts = props.ChannelAlerts :: { [ChannelId]: boolean }
								end
								return alerts[channelId] == true
							end)

							return ChannelCard(cardScope, channelId, props.CurrentChannel, unreadCount, isAlertActive, function()
								props.OnChannelChange(channelId)
							end)
						end
					),
				},
			}),
		},
	})
end

return ChannelSelector
