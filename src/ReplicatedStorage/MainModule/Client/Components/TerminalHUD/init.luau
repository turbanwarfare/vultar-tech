--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)

local TweenService = game:GetService("TweenService")

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type Owner = "Defenders" | "Hostiles" | nil

export type TerminalHUDProps = {
	DefenderScore: Types.FusionValue<number>,
	HostileScore: Types.FusionValue<number>,
	MaxPoints: Types.FusionValue<number>,
	Owner: Types.FusionValue<Owner>,
	Official: Types.FusionValue<boolean>,
	Visible: Types.FusionValue<boolean>,
	AnnouncementText: Types.FusionValue<string>,
	AnnouncementVisible: Types.FusionValue<boolean>,
}

local DEFENDER_COLOR = Color3.fromRGB(180, 50, 50)
local DEFENDER_COLOR_LIGHT = Color3.fromRGB(200, 70, 70)
local DEFENDER_EDGE = Color3.fromRGB(70, 18, 22)
local HOSTILE_COLOR = Color3.fromRGB(50, 110, 200)
local HOSTILE_COLOR_LIGHT = Color3.fromRGB(70, 130, 215)
local HOSTILE_EDGE = Color3.fromRGB(35, 75, 140)

local DEFENDER_BAR_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, DEFENDER_COLOR_LIGHT),
	ColorSequenceKeypoint.new(1, DEFENDER_COLOR),
})
local HOSTILE_BAR_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, HOSTILE_COLOR_LIGHT),
	ColorSequenceKeypoint.new(1, HOSTILE_COLOR),
})
local ANNOUNCEMENT_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
})
local NEUTRAL_INNER = Color3.fromRGB(70, 72, 80)
local ANNOUNCEMENT_COLOR = Color3.fromRGB(255, 180, 60)

local FILL_EDGE_SIZE = 2
local LABEL_TRANSPARENCY = 0.35
local ANNOUNCEMENT_BOX_WIDTH = 320
local ANNOUNCEMENT_BOX_PADDING = 16
local ANNOUNCEMENT_CORNER_RADIUS = 6
local BAR_WIDTH = 325
local BAR_HEIGHT = 24
local CENTER_BOX_SIZE = 42
local INNER_BOX_SIZE = 30
local GAP = 8
local TOP_PADDING = 12
local CORNER_RADIUS = 3
local SHADOW_OFFSET_Y = 1
local SHADOW_SPREAD = 2
local SHADOW_TRANSPARENCY = 0.8
local DEFENDER_LABEL = "VULTAR"
local HOSTILE_LABEL = "HOSTILES"
local VULTAR_ICON = "rbxassetid://98751546690059"
local HOSTILES_ICON = "rbxassetid://0"
local ICON_SIZE_DEFENDER = 24
local ICON_SIZE_HOSTILE = 20

local SLIDE_TWEEN_IN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SLIDE_TWEEN_OUT = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BAR_TWEEN = TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local COLOR_TWEEN = TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ANNOUNCE_TWEEN = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local CONTAINER_VISIBLE_POS = UDim2.fromOffset(0, TOP_PADDING)
local CONTAINER_HIDDEN_POS = UDim2.fromOffset(0, TOP_PADDING - 140)
local ANNOUNCE_VISIBLE_POS = UDim2.new(0.5, 0, 0, 100)
local ANNOUNCE_HIDDEN_POS = UDim2.new(0.5, 0, 0, -20)
local DISABLE_DELAY = 0.35

local function buildFillEdge(scope: FusionScope, edgeColor: Color3, gradient: ColorSequence, anchorX: number, initialPercent: number): Frame
	return scope:New("Frame")({
		Name = "FillEdge",
		Size = UDim2.fromScale(initialPercent, 1),
		Position = UDim2.fromScale(anchorX, 0),
		AnchorPoint = Vector2.new(anchorX, 0),
		BackgroundColor3 = edgeColor,
		ClipsDescendants = true,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER_RADIUS) }),
			scope:New("Frame")({
				Name = "FillInner",
				Size = UDim2.new(1, -FILL_EDGE_SIZE * 2, 1, -FILL_EDGE_SIZE * 2),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.Colors.White,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, math.max(1, CORNER_RADIUS - 1)) }),
					scope:New("UIGradient")({ Color = gradient, Rotation = 90 }),
				},
			}),
		},
	}) :: Frame
end

local function TerminalHUD(scope: FusionScope, props: TerminalHUDProps): ScreenGui
	local defenderPercent = scope:Computed(function(use: FusionUseFn)
		local max = use(props.MaxPoints)
		if max <= 0 then
			return 0
		end
		return math.clamp(use(props.DefenderScore) / max, 0, 1)
	end)

	local hostilePercent = scope:Computed(function(use: FusionUseFn)
		local max = use(props.MaxPoints)
		if max <= 0 then
			return 0
		end
		return math.clamp(use(props.HostileScore) / max, 0, 1)
	end)

	local innerBoxColor = scope:Computed(function(use: FusionUseFn)
		local owner = use(props.Owner)
		if owner == "Defenders" then
			return DEFENDER_COLOR
		elseif owner == "Hostiles" then
			return HOSTILE_COLOR
		end
		return NEUTRAL_INNER
	end)

	local defenderScoreText = scope:Computed(function(use: FusionUseFn)
		return tostring(use(props.DefenderScore))
	end)

	local hostileScoreText = scope:Computed(function(use: FusionUseFn)
		return tostring(use(props.HostileScore))
	end)

	local maxPointsText = scope:Computed(function(use: FusionUseFn)
		return tostring(use(props.MaxPoints))
	end)

	local hasOwner = scope:Computed(function(use: FusionUseFn)
		return use(props.Owner) ~= nil
	end)

	local ownerIcon = scope:Computed(function(use: FusionUseFn)
		local currentOwner = use(props.Owner)
		if currentOwner == "Defenders" then
			return VULTAR_ICON
		elseif currentOwner == "Hostiles" then
			return HOSTILES_ICON
		end
		return ""
	end)

	local announcementParsed = scope:Computed(function(use: FusionUseFn)
		local text = use(props.AnnouncementText)
		local isCD = string.match(text, "STARTING IN %d") ~= nil or string.match(text, "ROTATING IN %d") ~= nil
		local label = if isCD then string.match(text, "^(.+) %d+$") or text else text
		local num = if isCD then string.match(text, "(%d+)$") or "" else ""
		return { isCountdown = isCD, text = label, number = num }
	end)

	local isCountdown = scope:Computed(function(use: FusionUseFn)
		return use(announcementParsed).isCountdown
	end)

	local countdownText = scope:Computed(function(use: FusionUseFn)
		return use(announcementParsed).text
	end)

	local countdownNumber = scope:Computed(function(use: FusionUseFn)
		return use(announcementParsed).number
	end)

	local initialVisible = Fusion.peek(props.Visible)
	local initialAnnVisible = Fusion.peek(props.AnnouncementVisible)
	local initialDefPct = Fusion.peek(defenderPercent)
	local initialHostPct = Fusion.peek(hostilePercent)
	local initialInnerColor = Fusion.peek(innerBoxColor)

	local guiEnabled = scope:Value(initialVisible)
	local disableTask: thread? = nil

	local defenderFillEdge = buildFillEdge(scope, DEFENDER_EDGE, DEFENDER_BAR_GRADIENT, 1, initialDefPct)
	local hostileFillEdge = buildFillEdge(scope, HOSTILE_EDGE, HOSTILE_BAR_GRADIENT, 0, initialHostPct)

	local innerBox = scope:New("Frame")({
		Name = "InnerBox",
		Size = UDim2.fromOffset(INNER_BOX_SIZE, INNER_BOX_SIZE),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = initialInnerColor,
		BackgroundTransparency = 0.1,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
			scope:New("TextLabel")({
				Name = "PointLetter",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use: FusionUseFn)
					return not use(hasOwner)
				end),
				Text = "T",
				TextColor3 = Theme.Colors.White,
				TextSize = 18,
				Font = Theme.Text.Black,
			}),
			scope:New("ImageLabel")({
				Name = "OwnerIcon",
				Size = scope:Computed(function(use: FusionUseFn)
					local currentOwner = use(props.Owner)
					local size = if currentOwner == "Defenders" then ICON_SIZE_DEFENDER else ICON_SIZE_HOSTILE
					return UDim2.fromOffset(size, size)
				end),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Visible = hasOwner,
				Image = ownerIcon,
				ImageColor3 = Theme.Colors.White,
				ScaleType = Enum.ScaleType.Fit,
			}),
		},
	}) :: Frame

	local defenderBar = scope:New("Frame")({
		Name = "DefenderBarWrapper",
		Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT),
		Position = UDim2.new(0.5, -(CENTER_BOX_SIZE / 2 + GAP), 0, 4),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			Shadow(scope, {
				Size = UDim2.new(1, SHADOW_SPREAD * 2, 1, SHADOW_SPREAD * 2),
				Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = SHADOW_SPREAD,
				Transparency = SHADOW_TRANSPARENCY,
				ZIndex = 0,
			}),
			scope:New("Frame")({
				Name = "DefenderBar",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Chat.Window.Background,
				BackgroundTransparency = 0.6,
				ClipsDescendants = true,
				ZIndex = 1,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER_RADIUS) }),
					scope:New("UIStroke")({
						Color = Theme.Chat.Window.Border,
						Thickness = 1,
						Transparency = 0.5,
					}),
					defenderFillEdge,
					scope:New("TextLabel")({
						Name = "Score",
						Size = UDim2.new(0, 50, 1, 0),
						Position = UDim2.new(1, -6, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundTransparency = 1,
						Text = defenderScoreText,
						TextColor3 = Theme.Colors.White,
						TextSize = 12,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Right,
						ZIndex = 2,
					}),
				},
			}),
		},
	})

	local hostileBar = scope:New("Frame")({
		Name = "HostileBarWrapper",
		Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT),
		Position = UDim2.new(0.5, CENTER_BOX_SIZE / 2 + GAP, 0, 4),
		AnchorPoint = Vector2.zero,
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			Shadow(scope, {
				Size = UDim2.new(1, SHADOW_SPREAD * 2, 1, SHADOW_SPREAD * 2),
				Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = SHADOW_SPREAD,
				Transparency = SHADOW_TRANSPARENCY,
				ZIndex = 0,
			}),
			scope:New("Frame")({
				Name = "HostileBar",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Chat.Window.Background,
				BackgroundTransparency = 0.6,
				ClipsDescendants = true,
				ZIndex = 1,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER_RADIUS) }),
					scope:New("UIStroke")({
						Color = Theme.Chat.Window.Border,
						Thickness = 1,
						Transparency = 0.5,
					}),
					hostileFillEdge,
					scope:New("TextLabel")({
						Name = "Score",
						Size = UDim2.new(0, 50, 1, 0),
						Position = UDim2.new(0, 6, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						Text = hostileScoreText,
						TextColor3 = Theme.Colors.White,
						TextSize = 12,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 2,
					}),
				},
			}),
		},
	})

	local countdownTextLabel = scope:New("TextLabel")({
		Name = "CountdownText",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = scope:Computed(function(use: FusionUseFn)
			return if use(isCountdown) then use(countdownText) else use(props.AnnouncementText)
		end),
		TextColor3 = ANNOUNCEMENT_COLOR,
		TextTransparency = if initialAnnVisible then 0 else 1,
		TextSize = 16,
		Font = Theme.Text.Bold,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
	}) :: TextLabel

	local countdownNumberLabel = scope:New("TextLabel")({
		Name = "CountdownNumber",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = isCountdown,
		Text = countdownNumber,
		TextColor3 = ANNOUNCEMENT_COLOR,
		TextTransparency = if initialAnnVisible then 0 else 1,
		TextSize = 48,
		Font = Theme.Text.Black,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
	}) :: TextLabel

	local announcementBox = scope:New("Frame")({
		Name = "AnnouncementBox",
		Size = UDim2.fromOffset(ANNOUNCEMENT_BOX_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = if initialAnnVisible then ANNOUNCE_VISIBLE_POS else ANNOUNCE_HIDDEN_POS,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Background.Primary,
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, ANNOUNCEMENT_CORNER_RADIUS) }),
			scope:New("UIStroke")({
				Color = Theme.Border.Default,
				Thickness = 1,
				Transparency = 1,
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, ANNOUNCEMENT_BOX_PADDING),
				PaddingBottom = UDim.new(0, ANNOUNCEMENT_BOX_PADDING),
				PaddingLeft = UDim.new(0, ANNOUNCEMENT_BOX_PADDING),
				PaddingRight = UDim.new(0, ANNOUNCEMENT_BOX_PADDING),
			}),
			scope:New("UIGradient")({
				Color = ANNOUNCEMENT_GRADIENT,
				Rotation = 90,
			}),
			scope:New("Frame")({
				Name = "Content",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Top,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					countdownTextLabel,
					countdownNumberLabel,
				},
			}),
		},
	}) :: Frame

	local container = scope:New("Frame")({
		Name = "TerminalContainer",
		Size = UDim2.new(1, 0, 0, 70),
		Position = if initialVisible then CONTAINER_VISIBLE_POS else CONTAINER_HIDDEN_POS,
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			defenderBar,
			scope:New("TextLabel")({
				Name = "DefenderLabel",
				Size = UDim2.fromOffset(BAR_WIDTH, 18),
				Position = UDim2.new(0.5, -(CENTER_BOX_SIZE / 2 + GAP), 0, BAR_HEIGHT + 8),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Text = DEFENDER_LABEL,
				TextColor3 = Theme.Colors.White,
				TextTransparency = LABEL_TRANSPARENCY,
				TextSize = 12,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			scope:New("Frame")({
				Name = "CenterBox",
				Size = UDim2.fromOffset(CENTER_BOX_SIZE, CENTER_BOX_SIZE),
				Position = UDim2.new(0.5, 0, 0, 4),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Theme.Chat.Window.Background,
				BackgroundTransparency = Theme.Chat.Window.BackgroundTransparency,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
					scope:New("UIStroke")({
						Color = Theme.Chat.Window.Border,
						Thickness = 1,
						Transparency = 0.5,
					}),
					innerBox,
				},
			}),
			scope:New("TextLabel")({
				Name = "MaxPoints",
				Size = UDim2.fromOffset(CENTER_BOX_SIZE - 4, 16),
				Position = UDim2.new(0.5, 0, 0, CENTER_BOX_SIZE + 6),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Text = maxPointsText,
				TextColor3 = Theme.Foreground.Primary,
				TextSize = 12,
				Font = Theme.Text.Bold,
				TextScaled = true,
			}),
			scope:New("TextLabel")({
				Name = "UnofficialLabel",
				Size = UDim2.fromOffset(120, 20),
				Position = UDim2.new(0.5, 0, 0, CENTER_BOX_SIZE + 26),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use: FusionUseFn)
					return not use(props.Official)
				end),
				Text = "UNOFFICIAL",
				TextColor3 = Theme.Foreground.Secondary,
				TextSize = 18,
				Font = Theme.Text.Bold,
			}),
			hostileBar,
			scope:New("TextLabel")({
				Name = "HostileLabel",
				Size = UDim2.fromOffset(BAR_WIDTH, 18),
				Position = UDim2.new(0.5, CENTER_BOX_SIZE / 2 + GAP, 0, BAR_HEIGHT + 8),
				AnchorPoint = Vector2.zero,
				BackgroundTransparency = 1,
				Text = HOSTILE_LABEL,
				TextColor3 = Theme.Colors.White,
				TextTransparency = LABEL_TRANSPARENCY,
				TextSize = 12,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		},
	}) :: Frame

	local containerTween: Tween? = nil
	local defBarTween: Tween? = nil
	local hostBarTween: Tween? = nil
	local innerColorTween: Tween? = nil
	local announceTween: Tween? = nil
	local announceTextTween: Tween? = nil
	local announceNumTween: Tween? = nil

	scope:Observer(props.Visible):onBind(function()
		local visible = Fusion.peek(props.Visible)
		if visible then
			if disableTask then
				task.cancel(disableTask)
				disableTask = nil
			end
			guiEnabled:set(true)
		else
			disableTask = task.delay(DISABLE_DELAY, function()
				disableTask = nil
				if not Fusion.peek(props.Visible) then
					guiEnabled:set(false)
				end
			end)
		end
		if containerTween then
			containerTween:Cancel()
		end
		containerTween = TweenService:Create(
			container,
			if visible then SLIDE_TWEEN_IN else SLIDE_TWEEN_OUT,
			{ Position = if visible then CONTAINER_VISIBLE_POS else CONTAINER_HIDDEN_POS }
		)
		containerTween:Play()
	end)

	scope:Observer(defenderPercent):onBind(function()
		if defBarTween then
			defBarTween:Cancel()
		end
		defBarTween = TweenService:Create(defenderFillEdge, BAR_TWEEN, {
			Size = UDim2.fromScale(Fusion.peek(defenderPercent), 1),
		})
		defBarTween:Play()
	end)

	scope:Observer(hostilePercent):onBind(function()
		if hostBarTween then
			hostBarTween:Cancel()
		end
		hostBarTween = TweenService:Create(hostileFillEdge, BAR_TWEEN, {
			Size = UDim2.fromScale(Fusion.peek(hostilePercent), 1),
		})
		hostBarTween:Play()
	end)

	scope:Observer(innerBoxColor):onBind(function()
		if innerColorTween then
			innerColorTween:Cancel()
		end
		innerColorTween = TweenService:Create(innerBox, COLOR_TWEEN, {
			BackgroundColor3 = Fusion.peek(innerBoxColor),
		})
		innerColorTween:Play()
	end)

	scope:Observer(props.AnnouncementVisible):onBind(function()
		local visible = Fusion.peek(props.AnnouncementVisible)
		if announceTween then
			announceTween:Cancel()
		end
		if announceTextTween then
			announceTextTween:Cancel()
		end
		if announceNumTween then
			announceNumTween:Cancel()
		end
		announceTween = TweenService:Create(announcementBox, ANNOUNCE_TWEEN, {
			Position = if visible then ANNOUNCE_VISIBLE_POS else ANNOUNCE_HIDDEN_POS,
		})
		announceTween:Play()
		announceTextTween = TweenService:Create(countdownTextLabel, ANNOUNCE_TWEEN, {
			TextTransparency = if visible then 0 else 1,
		})
		announceTextTween:Play()
		announceNumTween = TweenService:Create(countdownNumberLabel, ANNOUNCE_TWEEN, {
			TextTransparency = if visible then 0 else 1,
		})
		announceNumTween:Play()
	end)

	table.insert(scope, function()
		if disableTask then
			task.cancel(disableTask)
		end
		if containerTween then
			containerTween:Cancel()
		end
		if defBarTween then
			defBarTween:Cancel()
		end
		if hostBarTween then
			hostBarTween:Cancel()
		end
		if innerColorTween then
			innerColorTween:Cancel()
		end
		if announceTween then
			announceTween:Cancel()
		end
		if announceTextTween then
			announceTextTween:Cancel()
		end
		if announceNumTween then
			announceNumTween:Cancel()
		end
	end)

	return scope:New("ScreenGui")({
		Name = "TerminalHUD",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		Enabled = guiEnabled,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		[Fusion.Children] = {
			container,
			announcementBox,
		},
	})
end

return TerminalHUD
