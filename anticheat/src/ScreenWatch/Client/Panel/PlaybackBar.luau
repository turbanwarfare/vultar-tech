--!strict
--!native
--!optimize 2

local UserInputService = game:GetService("UserInputService")

local Root = script:FindFirstAncestor("Client").Parent
local MainModule = require(Root.Shared.Game).get()
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)

type FusionScope = any
type FusionValue<T> = any
type FusionUseFn = any

export type PlaybackBarProps = {
	PlaybackStatus: FusionValue<string>,
	LagStatus: FusionValue<string>,
	AcReport: FusionValue<string>,
	FlickBars: { FusionValue<number> },
	FlickPeak: FusionValue<number>,
	PlaybackPaused: FusionValue<boolean>,
	PlaybackSpeed: FusionValue<number>,
	MarkersEnabled: FusionValue<boolean>,
	TimelineSpan: FusionValue<number>,
	TimelineRewind: FusionValue<number>,
	TimelineTicks: { FusionValue<number> },
	OnTogglePause: () -> (),
	OnCycleSpeed: () -> (),
	OnStepBack: () -> (),
	OnStepForward: () -> (),
	OnSeekBack: () -> (),
	OnSeekForward: () -> (),
	OnGoLive: () -> (),
	OnNextSuspect: () -> (),
	OnWatchVictim: () -> (),
	OnSeekFraction: (fraction: number) -> (),
	OnToggleMarkers: () -> (),
}

local STRIP_Y = 70
local TIMELINE_Y = STRIP_Y + 46
local AC_Y = TIMELINE_Y + 28
local TIMELINE_WIDTH = 620
local GRAPH_WIDTH = 120
local GRAPH_HEIGHT = 22
local LAG_COLOR = Color3.fromRGB(255, 90, 90)
local AC_COLOR = Color3.fromRGB(255, 140, 140)
local BAR_COLOR = Color3.fromRGB(0, 220, 200)
local BAR_HOT_COLOR = Color3.fromRGB(255, 80, 80)
local TICK_COLOR = Color3.fromRGB(255, 200, 60)

local function Button(scope: FusionScope, name: string, order: number, text: any, onClick: () -> (), textColor: any?): TextButton
	return scope:New("TextButton")({
		Name = name,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		BackgroundColor3 = Theme.Colors.Black[800],
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = textColor or Theme.Colors.White,
		TextSize = Theme.Text.Small,
		Font = Theme.Text.Bold,
		AutoButtonColor = false,
		LayoutOrder = order,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
			scope:New("UIStroke")({ Color = Theme.Colors.Black[650], Thickness = 1 }),
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		},
		[Fusion.OnEvent("Activated")] = onClick,
	})
end

local function Timeline(scope: FusionScope, props: PlaybackBarProps): Frame
	local playheadFraction = scope:Computed(function(use: FusionUseFn)
		local span = use(props.TimelineSpan)
		if span <= 0 then
			return 1
		end
		return math.clamp(1 - use(props.TimelineRewind) / span, 0, 1)
	end)

	local ticks = table.create(#props.TimelineTicks)
	for i, value in props.TimelineTicks do
		ticks[i] = scope:New("Frame")({
			Name = "Tick" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = scope:Computed(function(use: FusionUseFn)
				return UDim2.fromScale(math.max(use(value), 0), 0.5)
			end),
			Size = UDim2.fromOffset(2, 12),
			BackgroundColor3 = TICK_COLOR,
			BorderSizePixel = 0,
			Visible = scope:Computed(function(use: FusionUseFn)
				return use(value) >= 0
			end),
			ZIndex = 3,
		})
	end

	local track = scope:New("Frame")({
		Name = "Track",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -100, 0, 6),
		BackgroundColor3 = Theme.Colors.Black[650],
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			scope:New("Frame")({
				Name = "Fill",
				Size = scope:Computed(function(use: FusionUseFn)
					return UDim2.fromScale(use(playheadFraction), 1)
				end),
				BackgroundColor3 = BAR_COLOR,
				BorderSizePixel = 0,
				ZIndex = 2,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				},
			}),
			scope:New("Folder")({
				Name = "Ticks",
				[Fusion.Children] = ticks,
			}),
			scope:New("Frame")({
				Name = "Playhead",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = scope:Computed(function(use: FusionUseFn)
					return UDim2.fromScale(use(playheadFraction), 0.5)
				end),
				Size = UDim2.fromOffset(4, 16),
				BackgroundColor3 = Theme.Colors.White,
				BorderSizePixel = 0,
				ZIndex = 4,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 2) }),
				},
			}),
		},
	})

	local dragging = false
	local function seekFromInput(input: InputObject): ()
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		props.OnSeekFraction(math.clamp((input.Position.X - track.AbsolutePosition.X) / width, 0, 1))
	end

	local released = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	table.insert(scope, released)

	return scope:New("Frame")({
		Name = "Timeline",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TIMELINE_Y),
		Size = UDim2.fromOffset(TIMELINE_WIDTH, 24),
		BackgroundColor3 = Theme.Colors.Black[900],
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
			scope:New("UIStroke")({ Color = Theme.Colors.Black[650], Thickness = 1 }),

			scope:New("TextLabel")({
				Name = "Oldest",
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.fromOffset(40, 24),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use: FusionUseFn)
					return string.format("-%ds", math.round(use(props.TimelineSpan)))
				end),
				TextColor3 = Theme.Colors.Black[200],
				TextSize = Theme.Text.XSmall,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			scope:New("TextLabel")({
				Name = "Live",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 0),
				Size = UDim2.fromOffset(40, 24),
				BackgroundTransparency = 1,
				Text = "LIVE",
				TextColor3 = Theme.Colors.Black[200],
				TextSize = Theme.Text.XSmall,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),

			track,

			scope:New("TextButton")({
				Name = "Hit",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 5,
				[Fusion.OnEvent("InputBegan")] = function(input: InputObject)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						dragging = true
						seekFromInput(input)
					end
				end,
				[Fusion.OnEvent("InputChanged")] = function(input: InputObject)
					if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
						seekFromInput(input)
					end
				end,
			}),
		},
	})
end

local function PlaybackBar(scope: FusionScope, props: PlaybackBarProps): Frame
	local barCount = #props.FlickBars
	local barWidth = GRAPH_WIDTH / barCount
	local bars = table.create(barCount)
	for i, value in props.FlickBars do
		bars[i] = scope:New("Frame")({
			Name = "Bar" .. i,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, (i - 1) * barWidth, 1, 0),
			Size = scope:Computed(function(use: FusionUseFn)
				return UDim2.fromOffset(math.max(barWidth - 1, 1), math.max(1, math.round(use(value) * GRAPH_HEIGHT)))
			end),
			BackgroundColor3 = scope:Computed(function(use: FusionUseFn)
				return if use(value) >= 0.8 then BAR_HOT_COLOR else BAR_COLOR
			end),
			BorderSizePixel = 0,
		})
	end

	local pauseText = scope:Computed(function(use: FusionUseFn)
		return if use(props.PlaybackPaused) then "[P] RESUME" else "[P] PAUSE"
	end)
	local speedText = scope:Computed(function(use: FusionUseFn)
		return string.format("[O] %gX", use(props.PlaybackSpeed))
	end)
	local markersText = scope:Computed(function(use: FusionUseFn)
		return if use(props.MarkersEnabled) then "MARKERS: ON" else "MARKERS: OFF"
	end)
	local markersColor = scope:Computed(function(use: FusionUseFn)
		return if use(props.MarkersEnabled) then Theme.Colors.White else Theme.Colors.Black[400]
	end)

	return scope:New("Frame")({
		Name = "PlaybackBar",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Strip",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 40),
				Position = UDim2.new(0.5, 0, 0, STRIP_Y),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Theme.Colors.Black[900],
				BackgroundTransparency = 0.25,
				BorderSizePixel = 0,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
					scope:New("UIStroke")({ Color = Theme.Colors.Black[650], Thickness = 1 }),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),

					scope:New("TextLabel")({
						Name = "Status",
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, 24),
						BackgroundTransparency = 1,
						Text = props.PlaybackStatus,
						TextColor3 = Theme.Colors.White,
						TextSize = Theme.Text.Small,
						Font = Theme.Text.Bold,
						LayoutOrder = 1,
					}),

					scope:New("TextLabel")({
						Name = "Lag",
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, 24),
						BackgroundTransparency = 1,
						Text = props.LagStatus,
						TextColor3 = LAG_COLOR,
						TextSize = Theme.Text.Small,
						Font = Theme.Text.Bold,
						Visible = scope:Computed(function(use: FusionUseFn)
							return use(props.LagStatus) ~= ""
						end),
						LayoutOrder = 2,
					}),

					Button(scope, "PauseButton", 3, pauseText, props.OnTogglePause),
					Button(scope, "SpeedButton", 4, speedText, props.OnCycleSpeed),
					Button(scope, "StepBackButton", 5, "[,] ◀", props.OnStepBack),
					Button(scope, "StepForwardButton", 6, "▶ [.]", props.OnStepForward),
					Button(scope, "SeekBackButton", 7, "[[] -5S", props.OnSeekBack),
					Button(scope, "SeekForwardButton", 8, "+5S []]", props.OnSeekForward),
					Button(scope, "LiveButton", 9, "[H] LIVE", props.OnGoLive),
					Button(scope, "NextSuspectButton", 10, "[N] NEXT SUSPECT", props.OnNextSuspect),
					Button(scope, "VictimButton", 11, "[B] VICTIM", props.OnWatchVictim),
					Button(scope, "MarkersButton", 12, markersText, props.OnToggleMarkers, markersColor),

					scope:New("Frame")({
						Name = "FlickGraph",
						Size = UDim2.fromOffset(GRAPH_WIDTH, GRAPH_HEIGHT),
						BackgroundColor3 = Theme.Colors.Black[800],
						BorderSizePixel = 0,
						ClipsDescendants = true,
						LayoutOrder = 13,
						[Fusion.Children] = bars,
					}),

					scope:New("TextLabel")({
						Name = "FlickPeak",
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, 24),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use: FusionUseFn)
							return string.format("TURN %d°/s", use(props.FlickPeak))
						end),
						TextColor3 = Theme.Colors.Black[200],
						TextSize = Theme.Text.XSmall,
						Font = Theme.Text.Bold,
						LayoutOrder = 14,
					}),
				},
			}),

			Timeline(scope, props),

			scope:New("TextLabel")({
				Name = "AcReport",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 22),
				Position = UDim2.new(0.5, 0, 0, AC_Y),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Theme.Colors.Black[900],
				BackgroundTransparency = 0.25,
				BorderSizePixel = 0,
				Text = props.AcReport,
				TextColor3 = AC_COLOR,
				TextSize = Theme.Text.XSmall,
				Font = Theme.Text.Bold,
				Visible = scope:Computed(function(use: FusionUseFn)
					return use(props.AcReport) ~= ""
				end),
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
					scope:New("UIStroke")({ Color = Theme.Colors.Black[650], Thickness = 1 }),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
				},
			}),
		},
	})
end

return PlaybackBar
