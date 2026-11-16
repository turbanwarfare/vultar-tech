--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local ScoreTicker = require(script.Parent.ScoreTicker)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type TeamPanelProps = {
	TeamName: string,
	TeamIcon: string,
	TeamColorBright: Color3,
	Score: number,
	IsWinner: boolean,
	Visible: any,
	StartScoreCounting: any,
	WinnerRevealed: any,
	SlideDirection: number,
	FadeOut: any?,
}

local PANEL_WIDTH = 320
local PANEL_HEIGHT = 420
local LOGO_SIZE = 150
local SPRING_SPEED = 20
local SPRING_DAMPING = 1

local function TeamPanel(scope: FusionScope, props: TeamPanelProps): Frame
	local teamName = props.TeamName
	local teamIcon = props.TeamIcon
	local teamColorBright = props.TeamColorBright
	local score = props.Score
	local isWinner = props.IsWinner
	local visible = props.Visible
	local startScoreCounting = props.StartScoreCounting
	local winnerRevealed = props.WinnerRevealed
	local slideDirection = props.SlideDirection
	local fadeOut = props.FadeOut

	local panelAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if fadeOut and use(fadeOut) then
				return 0
			end
			return if use(visible) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local panelOffset = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(visible) then 0 else slideDirection * 60
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local winnerScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if not isWinner then
				return 1
			end
			return if use(winnerRevealed) then 1.05 else 1
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local logoColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if not isWinner then
				return Theme.Colors.White
			end
			return if use(winnerRevealed) then teamColorBright else Theme.Colors.White
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local teamNameColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if not isWinner then
				return Theme.Colors.White
			end
			return if use(winnerRevealed) then teamColorBright else Theme.Colors.White
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local scoreTextColor = scope:Computed(function(use: FusionUseFn)
		if not isWinner then
			return Theme.Colors.White
		end
		return if use(winnerRevealed) then teamColorBright else Theme.Colors.White
	end)

	return scope:New("Frame")({
		Name = teamName .. "Panel",
		Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT),
		BackgroundTransparency = 1,
		Position = scope:Computed(function(use: FusionUseFn)
			return UDim2.new(0.5, use(panelOffset), 0.5, 0)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),

		[Fusion.Children] = {
			scope:New("UIScale")({
				Scale = winnerScale,
			}),

			scope:New("Frame")({
				Name = "Content",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 24),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					scope:New("TextLabel")({
						Name = "TeamName",
						Size = UDim2.new(1, 0, 0, 36),
						BackgroundTransparency = 1,
						Text = string.upper(teamName),
						TextColor3 = teamNameColor,
						TextTransparency = scope:Computed(function(use: FusionUseFn)
							return 1 - use(panelAlpha)
						end),
						TextSize = 26,
						Font = Theme.Text.Black,
						LayoutOrder = 1,
					}),

					scope:New("ImageLabel")({
						Name = "Logo",
						Size = UDim2.fromOffset(LOGO_SIZE, LOGO_SIZE),
						BackgroundTransparency = 1,
						Image = teamIcon,
						ImageColor3 = logoColor,
						ImageTransparency = scope:Computed(function(use: FusionUseFn)
							return 1 - use(panelAlpha)
						end),
						ScaleType = Enum.ScaleType.Fit,
						LayoutOrder = 2,
					}),

					scope:New("Frame")({
						Name = "ScoreContainer",
						Size = UDim2.new(1, 0, 0, 100),
						BackgroundTransparency = 1,
						LayoutOrder = 3,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 6),
							}),

							ScoreTicker(scope, {
								TargetValue = score,
								StartCounting = startScoreCounting,
								Duration = 2.2,
								TextSize = 58,
								TextColor = scoreTextColor,
								TextTransparency = scope:Computed(function(use: FusionUseFn)
									return 1 - use(panelAlpha)
								end),
							}),

							scope:New("TextLabel")({
								Name = "PointsLabel",
								Size = UDim2.new(1, 0, 0, 24),
								BackgroundTransparency = 1,
								Text = "POINTS",
								TextColor3 = Theme.Colors.Black[400],
								TextTransparency = scope:Computed(function(use: FusionUseFn)
									return 0.2 + (1 - use(panelAlpha)) * 0.8
								end),
								TextSize = 14,
								Font = Theme.Text.Bold,
							}),
						},
					}),
				},
			}),
		},
	})
end

return TeamPanel
