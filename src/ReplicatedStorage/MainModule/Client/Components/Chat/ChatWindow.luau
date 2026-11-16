--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local ChatTypes = require(MainModule.Shared.Network.Chat.Types)
local ChatConstants = require(MainModule.Shared.Chat.Constants)
local Theme = require(MainModule.Shared.UI.Theme)
local Scale = require(MainModule.Client.Utils.Scaling.Scale)
local Shadow = require(MainModule.Client.Components.Shadow)

local Channels = require(script.Parent.Channels)
local Messages = require(script.Parent.Messages)
local Input = require(script.Parent.Input)
local MessageFormatter = require(script.Parent.Messages.MessageFormatter)

local ChannelSelector = Channels.ChannelSelector
local GlobalChatTabs = Channels.GlobalChatTabs
local MessageList = Messages
local MessageInput = Input

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn
type ChannelId = ChatTypes.ChannelId
type ChatMessage = ChatTypes.ChatMessage
type GlobalFilter = ChatTypes.GlobalFilter

export type ChatWindowProps = {
	Visible: FusionCanBeState<boolean>,
	ContentVisible: FusionCanBeState<boolean>?,
	Messages: FusionCanBeState<{ ChatMessage }>,
	CurrentChannel: FusionCanBeState<ChannelId>,
	CurrentFilter: FusionCanBeState<GlobalFilter>,
	VisibleChannels: FusionCanBeState<{ ChannelId }>,
	BubbleVisibility: FusionCanBeState<boolean>,
	UnreadCounts: FusionCanBeState<{ [ChannelId]: number }>?,
	ChannelAlerts: FusionCanBeState<{ [ChannelId]: boolean }>?,
	LocalPlayerTeam: FusionCanBeState<string?>,
	IsMuted: FusionCanBeState<boolean>?,
	WhisperTarget: FusionCanBeState<Player?>?,
	OnSendMessage: (content: string, isTeamOnly: boolean, whisperTarget: Player?) -> (),
	OnChannelChange: (channelId: ChannelId) -> (),
	OnFilterChange: (filter: GlobalFilter) -> (),
	OnFocusChanged: (focused: boolean) -> (),
	OnBubbleVisibilityToggle: () -> (),
	OnVisibilityToggle: () -> (),
	OnTextBoxCreated: ((textBox: TextBox) -> ())?,
	OnUsernameClick: ((senderId: number, senderName: string) -> ())?,
	OnWhisperTargetChange: ((target: Player?) -> ())?,
}

local UI = ChatConstants.UI
local Animation = ChatConstants.Animation

local SHADOW_SPREAD = 6
local SHADOW_OFFSET_Y = 2
local SHADOW_TRANSPARENCY = 0.65

local function buildToggleButton(scope: FusionScope, isVisible: any, onToggle: () -> ()): Frame
	local hovered = scope:Value(false)
	return scope:New("Frame")({
		Name = "ToggleButton",
		Size = UDim2.fromOffset(26, 26),
		LayoutOrder = 1,
		BackgroundColor3 = scope:Computed(function(use: FusionUseFn)
			return if use(hovered) then Theme.Chat.MicButton.BackgroundHover else Theme.Chat.MicButton.Background
		end),
		BackgroundTransparency = Theme.Chat.MicButton.BackgroundTransparency,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
			scope:New("UIStroke")({ Color = Theme.Chat.MicButton.Border, Thickness = 1, Transparency = 0.5 }),
			scope:New("Frame")({
				Name = "IconContainer",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					scope:New("UIListLayout")({ HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center }),
					scope:New("ImageLabel")({
						Name = "Icon",
						Size = UDim2.fromOffset(16, 16),
						BackgroundTransparency = 1,
						Image = scope:Computed(function(use: FusionUseFn)
							return if use(isVisible) then "rbxassetid://123792095850614" else "rbxassetid://81045999480314"
						end),
						ImageColor3 = Theme.Chat.MicButton.Icon,
					}),
				},
			}),
			scope:New("TextButton")({
				Name = "Hitbox",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 6,
				[Fusion.OnEvent("MouseEnter")] = function() hovered:set(true) end,
				[Fusion.OnEvent("MouseLeave")] = function() hovered:set(false) end,
				[Fusion.OnEvent("Activated")] = onToggle,
			}),
			scope:New("Frame")({
				Name = "Tooltip",
				Size = UDim2.fromOffset(0, 28),
				Position = scope:Computed(function(use: FusionUseFn)
					return if use(isVisible) then UDim2.new(0.5, 0, 0, -8) else UDim2.new(1, 8, 0.5, 0)
				end),
				AnchorPoint = scope:Computed(function(use: FusionUseFn)
					return if use(isVisible) then Vector2.new(0.5, 1) else Vector2.new(0, 0.5)
				end),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Theme.Chat.Tooltip.Background,
				BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
					return if use(hovered) then Theme.Chat.Tooltip.BackgroundTransparency else 1
				end),
				ZIndex = 10,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
					scope:New("UIStroke")({ Color = Theme.Chat.Tooltip.Border, Thickness = 1, Transparency = scope:Computed(function(use: FusionUseFn) return if use(hovered) then 0.4 else 1 end) }),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
					scope:New("TextLabel")({
						Name = "Text",
						Size = UDim2.fromScale(0, 1),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use: FusionUseFn)
							return if use(isVisible) then "CLOSE CHAT" else "OPEN CHAT"
						end),
						TextColor3 = Theme.Chat.Tooltip.Text,
						TextSize = 10,
						Font = Enum.Font.GothamMedium,
						TextTransparency = scope:Computed(function(use: FusionUseFn) return if use(hovered) then 0 else 1 end),
					}),
				},
			}),
		},
	})
end

local function buildMicButton(scope: FusionScope, isVisible: any, bubbleEnabled: any, onToggle: () -> (), successHex: string, destructiveHex: string): Frame
	local hovered = scope:Value(false)
	return scope:New("Frame")({
		Name = "MicButton",
		Size = UDim2.fromOffset(26, 26),
		LayoutOrder = 2,
		BackgroundColor3 = scope:Computed(function(use: FusionUseFn)
			return if use(hovered) then Theme.Chat.MicButton.BackgroundHover else Theme.Chat.MicButton.Background
		end),
		BackgroundTransparency = Theme.Chat.MicButton.BackgroundTransparency,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
			scope:New("UIStroke")({ Color = Theme.Chat.MicButton.Border, Thickness = 1, Transparency = 0.5 }),
			scope:New("Frame")({
				Name = "IconContainer",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					scope:New("UIListLayout")({ HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center }),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 2) }),
					scope:New("ImageLabel")({
						Name = "Icon",
						Size = UDim2.fromOffset(16, 16),
						BackgroundTransparency = 1,
						Image = scope:Computed(function(use: FusionUseFn)
							return if use(bubbleEnabled) then ChatConstants.Icons.micEveryone else ChatConstants.Icons.micTeamOnly
						end),
						ImageColor3 = Theme.Chat.MicButton.Icon,
					}),
				},
			}),
			scope:New("TextButton")({
				Name = "Hitbox",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 6,
				[Fusion.OnEvent("MouseEnter")] = function() hovered:set(true) end,
				[Fusion.OnEvent("MouseLeave")] = function() hovered:set(false) end,
				[Fusion.OnEvent("Activated")] = onToggle,
			}),
			scope:New("Frame")({
				Name = "Tooltip",
				Size = UDim2.fromOffset(0, 28),
				Position = scope:Computed(function(use: FusionUseFn)
					return if use(isVisible) then UDim2.new(0.5, 0, 1, 8) else UDim2.new(1, 8, 0.5, 0)
				end),
				AnchorPoint = scope:Computed(function(use: FusionUseFn)
					return if use(isVisible) then Vector2.new(0.5, 0) else Vector2.new(0, 0.5)
				end),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Theme.Chat.Tooltip.Background,
				BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
					return if use(hovered) then Theme.Chat.Tooltip.BackgroundTransparency else 1
				end),
				ZIndex = 10,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
					scope:New("UIStroke")({ Color = Theme.Chat.Tooltip.Border, Thickness = 1, Transparency = scope:Computed(function(use: FusionUseFn) return if use(hovered) then 0.4 else 1 end) }),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
					scope:New("TextLabel")({
						Name = "Text",
						Size = UDim2.fromScale(0, 1),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						RichText = true,
						Text = scope:Computed(function(use: FusionUseFn)
							if use(bubbleEnabled) then
								return string.format('TEAM ONLY CHAT BUBBLE: <font color="#%s"><b>OFF</b></font>', destructiveHex)
							end
							return string.format('TEAM ONLY CHAT BUBBLE: <font color="#%s"><b>ON</b></font>', successHex)
						end),
						TextColor3 = Theme.Chat.Tooltip.Text,
						TextSize = 10,
						Font = Enum.Font.GothamMedium,
						TextTransparency = scope:Computed(function(use: FusionUseFn) return if use(hovered) then 0 else 1 end),
					}),
				},
			}),
		},
	})
end

local function ChatWindow(scope: FusionScope, props: ChatWindowProps): Frame
	local viewportScale = Scale.scoped(scope)

	local isVisible = scope:Computed(function(use: FusionUseFn)
		local vis = props.Visible
		if typeof(vis) == "table" then
			return use(vis :: any)
		end
		return vis :: boolean
	end)

	local contentVisible = scope:Computed(function(use: FusionUseFn)
		local cv = props.ContentVisible
		if cv == nil then return true end
		if typeof(cv) == "table" then
			return use(cv :: any)
		end
		return cv :: boolean
	end)

	local bubbleEnabled = scope:Computed(function(use: FusionUseFn)
		local bubble = props.BubbleVisibility
		if typeof(bubble) == "table" then
			return use(bubble :: any)
		end
		return bubble :: boolean
	end)

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

	local localPlayerTeam = scope:Computed(function(use: FusionUseFn)
		local team = props.LocalPlayerTeam
		if typeof(team) == "table" then
			return use(team :: any)
		end
		return team :: string?
	end)

	local isMuted = scope:Computed(function(use: FusionUseFn)
		local muted = props.IsMuted
		if typeof(muted) == "table" then
			return use(muted :: any)
		end
		return muted :: boolean or false
	end)

	local isInputFocused = scope:Value(false)

	local focusGlow = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isInputFocused) then 1 else 0
		end),
		40,
		1
	)

	local isOnGlobal = scope:Computed(function(use: FusionUseFn)
		return use(currentChannel) == "GLOBAL"
	end)

	local showTabs = scope:Computed(function(use: FusionUseFn)
		return use(isOnGlobal)
	end)

	local filteredMessages = scope:Computed(function(use: FusionUseFn)
		local msgs = props.Messages
		local messageList: { ChatMessage }
		if typeof(msgs) == "table" and (msgs :: any).type == "State" then
			messageList = use(msgs :: any)
		else
			messageList = msgs :: { ChatMessage }
		end

		local channel = use(currentChannel)
		local filter = use(currentFilter)
		local playerTeam = use(localPlayerTeam)

		if channel ~= "GLOBAL" then
			return messageList
		end

		local filtered = {}

		if filter == "ALL" then
			for _, msg in messageList do
				if not msg.isTeamOnly then
					table.insert(filtered, msg)
				end
			end
		else
			for _, msg in messageList do
				if msg.isTeamOnly and msg.senderTeam == playerTeam then
					table.insert(filtered, msg)
				end
			end
		end

		return filtered
	end)

	local targetOffset = scope:Computed(function(use: FusionUseFn)
		if use(showTabs) then
			return UI.tabsHeight + UI.tabsGap
		end
		return 0
	end)

	local contentOffset = scope:Spring(targetOffset, 40, 1)

	local targetX = scope:Computed(function(use: FusionUseFn)
		if use(isVisible) then
			return Animation.visibleX
		else
			local scale = use(viewportScale)
			local buttonOffset = UI.chatWidth + 4
			local targetButtonX = 8
			return targetButtonX - (buttonOffset * scale)
		end
	end)

	local positionX = scope:Spring(targetX, Animation.speed, Animation.damping)

	local transparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then 0 else 1
		end),
		Animation.speed,
		Animation.damping
	)

	local successHex = MessageFormatter.colorToHex(Theme.Colors.Success)
	local destructiveHex = MessageFormatter.colorToHex(Theme.Colors.Destructive)

	return scope:New("Frame")({
		Name = "ChatContainer",
		Size = UDim2.fromOffset(460, 295),
		Position = scope:Computed(function(use: FusionUseFn)
			return UDim2.fromOffset(math.round(use(positionX)), 8)
		end),
		AnchorPoint = Vector2.zero,
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("UIScale")({
				Scale = viewportScale,
			}),

			scope:New("Frame")({
				Name = "ContentWrapper",
				Size = UDim2.fromOffset(460, 295),
				Position = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				Visible = contentVisible,
				[Fusion.Children] = {

			GlobalChatTabs(scope, {
				CurrentFilter = props.CurrentFilter,
				Visible = showTabs,
				OnFilterChange = props.OnFilterChange,
				Width = UI.chatWidth,
			}),

			scope:New("Frame")({
				Name = "ChatWindowWrapper",
				Size = UDim2.fromOffset(UI.chatWidth + SHADOW_SPREAD * 2, UI.chatHeight + SHADOW_SPREAD * 2),
				Position = scope:Computed(function(use: FusionUseFn)
					return UDim2.fromOffset(-SHADOW_SPREAD, math.round(use(contentOffset)) - SHADOW_SPREAD)
				end),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					Shadow(scope, {
						Size = UDim2.fromScale(1, 1),
						Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Spread = 0,
						Transparency = scope:Computed(function(use: FusionUseFn)
							return SHADOW_TRANSPARENCY + use(transparency) * (1 - SHADOW_TRANSPARENCY)
						end),
						ZIndex = 0,
					}),

					scope:New("Frame")({
						Name = "ChatWindow",
						Size = UDim2.fromOffset(UI.chatWidth, UI.chatHeight),
						Position = UDim2.fromOffset(SHADOW_SPREAD, SHADOW_SPREAD),
						BackgroundColor3 = Theme.Chat.Window.Background,
						BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
							return Theme.Chat.Window.BackgroundTransparency + use(transparency) * (1 - Theme.Chat.Window.BackgroundTransparency)
						end),
						BorderSizePixel = 0,
						ClipsDescendants = true,
						ZIndex = 1,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = Theme.Radius.Medium,
							}),

							scope:New("UIStroke")({
								Color = Theme.Chat.Window.Border,
								Thickness = 1,
								Transparency = scope:Computed(function(use: FusionUseFn)
									return Theme.Chat.Window.BorderTransparency + use(transparency) * (1 - Theme.Chat.Window.BorderTransparency)
								end),
							}),

							MessageList(scope, {
								Messages = filteredMessages,
								LayoutOrder = 0,
								OnUsernameClick = props.OnUsernameClick,
								ViewportScale = viewportScale,
							}),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "InputBarWrapper",
				Size = UDim2.fromOffset(UI.chatWidth + SHADOW_SPREAD * 2, UI.inputHeight + SHADOW_SPREAD * 2),
				Position = scope:Computed(function(use: FusionUseFn)
					return UDim2.fromOffset(-SHADOW_SPREAD, UI.chatHeight + UI.elementGap + use(contentOffset) - SHADOW_SPREAD)
				end),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					Shadow(scope, {
						Size = UDim2.fromScale(1, 1),
						Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Spread = 0,
						Transparency = scope:Computed(function(use: FusionUseFn)
							return SHADOW_TRANSPARENCY + use(transparency) * (1 - SHADOW_TRANSPARENCY)
						end),
						ZIndex = 0,
					}),

					scope:New("Frame")({
						Name = "InputBar",
						Size = UDim2.fromOffset(UI.chatWidth, UI.inputHeight),
						Position = UDim2.fromOffset(SHADOW_SPREAD, SHADOW_SPREAD),
						BackgroundColor3 = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								if use(isInputFocused) then
									return Theme.Chat.Input.BackgroundFocused
								end
								return Theme.Chat.Input.Background
							end),
							Theme.Spring.Default.Speed
						),
						BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
							local glow = use(focusGlow)
							local baseTransparency = Theme.Chat.Input.BackgroundTransparency - (Theme.Chat.Input.BackgroundTransparency - Theme.Chat.Input.BackgroundFocusedTransparency) * glow
							return baseTransparency + use(transparency) * (1 - baseTransparency)
						end),
						BorderSizePixel = 0,
						ZIndex = 1,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = Theme.Radius.Medium,
							}),

							scope:New("UIStroke")({
								Color = scope:Spring(
									scope:Computed(function(use: FusionUseFn)
										if use(isInputFocused) then
											return Theme.Chat.Input.BorderFocused
										end
										return Theme.Chat.Input.Border
									end),
									Theme.Spring.Default.Speed
								),
								Thickness = scope:Computed(function(use: FusionUseFn)
									local glow = use(focusGlow)
									return 1 + 0.5 * glow
								end),
								Transparency = scope:Computed(function(use: FusionUseFn)
									local glow = use(focusGlow)
									local baseTransparency = Theme.Chat.Input.BorderTransparency - (Theme.Chat.Input.BorderTransparency - Theme.Chat.Input.BorderFocusedTransparency) * glow
									return baseTransparency + use(transparency) * (1 - baseTransparency)
								end),
							}),

							MessageInput(scope, {
								CurrentChannel = props.CurrentChannel,
								CurrentFilter = props.CurrentFilter,
								IsMuted = isMuted,
								WhisperTarget = props.WhisperTarget,
								OnSendMessage = props.OnSendMessage,
								OnFilterChange = props.OnFilterChange,
								OnChannelChange = props.OnChannelChange,
								OnWhisperTargetChange = props.OnWhisperTargetChange,
								OnFocusChanged = function(focused: boolean)
									isInputFocused:set(focused)
									props.OnFocusChanged(focused)
								end,
								OnTextBoxCreated = props.OnTextBoxCreated,
							}),
						},
					}),
				},
			}),

			ChannelSelector(scope, {
				CurrentChannel = props.CurrentChannel,
				VisibleChannels = props.VisibleChannels,
				UnreadCounts = props.UnreadCounts,
				ChannelAlerts = props.ChannelAlerts,
				OnChannelChange = props.OnChannelChange,
				Position = scope:Computed(function(use: FusionUseFn)
					return UDim2.fromOffset(0, UI.chatHeight + UI.elementGap + UI.inputHeight + UI.elementGap + use(contentOffset))
				end),
			}),
		},
		}),

		scope:New("Frame")({
			Name = "ButtonContainer",
			Size = UDim2.fromOffset(26, 56),
			Position = scope:Computed(function(use: FusionUseFn)
				return UDim2.fromOffset(UI.chatWidth + 4, use(contentOffset))
			end),
			BackgroundTransparency = 1,
			ZIndex = 5,

			[Fusion.Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 4),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				buildToggleButton(scope, isVisible, props.OnVisibilityToggle),
				buildMicButton(scope, isVisible, bubbleEnabled, props.OnBubbleVisibilityToggle, successHex, destructiveHex),
			},
		}),
	},
})
end

return ChatWindow
