--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)

local ArenaHUD = {}

local SPRING_SPEED = 18
local SPRING_DAMP = 1

local SCORE_FONT = Theme.Text.Black
local LABEL_FONT = Theme.Text.Bold
local REGULAR_FONT = Theme.Text.Semibold

local AVATAR_SIZE = 72
local AVATAR_CORNER = UDim.new(0, 6)
local AVATAR_STROKE_W = 1

local CENTER_W = 160
local HUD_H = AVATAR_SIZE + 16
local HUD_W = AVATAR_SIZE + CENTER_W + AVATAR_SIZE + 48

local PANEL_BG = Theme.Chat.Window.Background
local PANEL_BG_TRANSPARENCY = Theme.Chat.Window.BackgroundTransparency
local SCORE_COLOR = Theme.Colors.White
local TIMER_COLOR = Theme.Foreground.Secondary

local P1_ACCENT = Theme.Leaderboard.Defenders.Accent
local P2_ACCENT = Theme.Leaderboard.Raiders.Accent

type FusionCanBeState<T> = T | { get: () -> T }

export type ArenaHUDProps = {
	Player1: Player,
	Player2: Player,
	Player1Score: FusionCanBeState<number>?,
	Player2Score: FusionCanBeState<number>?,
	FirstTo: FusionCanBeState<number>?,
	ModeLabel: FusionCanBeState<string>?,
	TimerText: FusionCanBeState<string>?,
	Visible: FusionCanBeState<boolean>?,
	IsSuddenDeath: FusionCanBeState<boolean>?,
}

local function Avatar(scope: any, player: Player, accentColor: Color3, alpha: any): Frame
	local thumbUrl = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"

	return scope:New("Frame")({
		Name = "Avatar_" .. player.Name,
		Size = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = AVATAR_CORNER }),
			scope:New("ImageLabel")({
				Name = "Portrait",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = PANEL_BG,
				BackgroundTransparency = scope:Computed(function(use)
					return PANEL_BG_TRANSPARENCY + (1 - use(alpha)) * (1 - PANEL_BG_TRANSPARENCY)
				end),
				Image = thumbUrl,
				ImageTransparency = scope:Computed(function(use)
					return 1 - use(alpha)
				end),
				ScaleType = Enum.ScaleType.Crop,
				ZIndex = 2,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = AVATAR_CORNER }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = accentColor,
						Thickness = AVATAR_STROKE_W,
						Transparency = scope:Computed(function(use)
							return 1 - use(alpha)
						end),
					}),
				},
			}),
		},
	})
end

function ArenaHUD.createVersusHUD(props: ArenaHUDProps): ScreenGui
	local scope = Fusion.scoped(Fusion)

	local p1Score = props.Player1Score or scope:Value(0)
	local p2Score = props.Player2Score or scope:Value(0)
	local timerText = props.TimerText or scope:Value("0:00")

	local firstToValue: any = if props.FirstTo ~= nil then props.FirstTo else scope:Value(5)
	local visible = props.Visible or scope:Value(true)

	local hudAlpha = scope:Spring(
		scope:Computed(function(use)
			return if use(visible) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMP
	)

	local hudY = scope:Spring(
		scope:Computed(function(use)
			return if use(visible) then 0 else -16
		end),
		SPRING_SPEED,
		SPRING_DAMP
	)

	local scoreText = scope:Computed(function(use)
		return tostring(math.floor(use(p1Score))) .. "  –  " .. tostring(math.floor(use(p2Score)))
	end)

	local centerColumn = scope:New("Frame")({
		Name = "CenterColumn",
		Size = UDim2.fromOffset(CENTER_W, HUD_H - 16),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 1),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			scope:New("TextLabel")({
				Name = "Score",
				Size = UDim2.fromOffset(CENTER_W, 40),
				BackgroundTransparency = 1,
				Text = scoreText,
				TextColor3 = SCORE_COLOR,
				TextStrokeTransparency = 0.9,
				TextTransparency = scope:Computed(function(use)
					return 1 - use(hudAlpha)
				end),
				TextSize = 34,
				Font = SCORE_FONT,
				LayoutOrder = 1,
			}),

			scope:New("TextLabel")({
				Name = "InfoLabel",
				Size = UDim2.fromOffset(CENTER_W, 24),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use)
					local suddenDeath = props.IsSuddenDeath and use(props.IsSuddenDeath) or false
					if suddenDeath then
						return "SUDDEN DEATH"
					end
					local rounds = use(firstToValue)
					local roundsNum = tonumber(rounds) or 1
					return "FIRST TO: " .. tostring(roundsNum)
				end),
				TextColor3 = scope:Spring(
					scope:Computed(function(use)
						local suddenDeath = props.IsSuddenDeath and use(props.IsSuddenDeath) or false
						return if suddenDeath then Theme.Colors.Warning else Theme.Colors.White
					end),
					Theme.Spring.Responsive.Speed
				),
				TextStrokeTransparency = 0.9,
				TextTransparency = scope:Computed(function(use)
					return 1 - use(hudAlpha)
				end),
				TextSize = 20,
				Font = LABEL_FONT,
				LayoutOrder = 2,
			}),

			scope:New("TextLabel")({
				Name = "Timer",
				Size = UDim2.fromOffset(CENTER_W, 20),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use)
					return use(timerText)
				end),
				TextColor3 = TIMER_COLOR,
				TextStrokeTransparency = 0.9,
				TextTransparency = scope:Computed(function(use)
					return 1 - use(hudAlpha)
				end),
				TextSize = 18,
				Font = REGULAR_FONT,
				LayoutOrder = 3,
			}),
		},
	})

	local hudFrame = scope:New("Frame")({
		Name = "HUDPill",
		Size = UDim2.fromOffset(HUD_W, HUD_H),
		Position = scope:Computed(function(use)
			return UDim2.new(0.5, 0, 0, 20 + use(hudY))
		end),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = PANEL_BG,
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use)
			return use(hudAlpha) > 0.02
		end),
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			}),
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			scope:New("Frame")({
				Name = "P1AvatarWrapper",
				Size = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				[Fusion.Children] = {
					scope:New("ImageLabel")({
						Name = "Shadow",
						Size = UDim2.fromScale(1.2, 1.2),
						Position = UDim2.new(0.5, 0, 0.5, 1),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://1316045217",
						ImageColor3 = Color3.fromRGB(0, 0, 0),
						ImageTransparency = scope:Computed(function(use)
							return 0.7 + (1 - use(hudAlpha)) * 0.3
						end),
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = Rect.new(32, 32, 96, 96),
						ZIndex = 0,
					}),
					Avatar(scope, props.Player1, P1_ACCENT, hudAlpha),
				},
			}),

			scope:New("Frame")({
				Name = "CenterWrapper",
				Size = UDim2.fromOffset(CENTER_W, HUD_H - 16),
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				[Fusion.Children] = { centerColumn },
			}),

			scope:New("Frame")({
				Name = "P2AvatarWrapper",
				Size = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE),
				BackgroundTransparency = 1,
				LayoutOrder = 3,
				[Fusion.Children] = {
					scope:New("ImageLabel")({
						Name = "Shadow",
						Size = UDim2.fromScale(1.2, 1.2),
						Position = UDim2.new(0.5, 0, 0.5, 1),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://1316045217",
						ImageColor3 = Color3.fromRGB(0, 0, 0),
						ImageTransparency = scope:Computed(function(use)
							return 0.7 + (1 - use(hudAlpha)) * 0.3
						end),
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = Rect.new(32, 32, 96, 96),
						ZIndex = 0,
					}),
					Avatar(scope, props.Player2, P2_ACCENT, hudAlpha),
				},
			}),
		},
	})

	local screenGui = scope:New("ScreenGui")({
		Name = "ArenaVersusHUD",
		AutoLocalize = false,
		ResetOnSpawn = false,
		DisplayOrder = 150,
		Enabled = true,
		IgnoreGuiInset = true,
		[Fusion.Children] = { hudFrame },
	})

	return screenGui :: ScreenGui
end

function ArenaHUD.cleanup() end

return ArenaHUD
