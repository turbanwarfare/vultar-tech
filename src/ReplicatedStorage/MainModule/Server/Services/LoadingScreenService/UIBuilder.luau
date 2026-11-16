--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Credits = require(MainModule.Shared.Config.Credits)
local CreditsPanel = require(script.Parent.CreditsPanel)

type FusionScope = Types.FusionScope

type Mote = {
	x: number,
	duration: number,
	offset: number,
	sway: number,
	size: number,
	twinkle: number,
	warm: boolean?,
}

type Shaft = {
	x: number,
	width: number,
	transparency: number,
}

local UIBuilder = {}

local LOGO_ID = "rbxassetid://0"

local WORDMARK_TEXT = "VULTAR"
local SUBTITLE_TEXT = "IMPERIUM OF VULTAR"
local LOADING_TEXT = "LOADING EXPERIENCE"

local DESIGN_WIDTH = 1920
local EDGE_MARGIN = 64
local BOTTOM_MARGIN = 68
local BRAND_TOP = 48
local INFO_TOP = 62
local BAR_WIDTH = 524
local BUTTON_HEIGHT = 56
local CREDITS_BUTTON_WIDTH = 180
local BUTTON_GAP = 12
local BASE_NAME_SIZE = 48
local INFO_TEXT_SIZE = 12
local WORDMARK_SIZE = 18
local SHOT_COUNT = 4
local SHAFT_ROTATION = 22
local SHAFT_LENGTH = 1500
local SHAFT_TOP = -200
local SHAFT_DRIFT = 20

local MUTED_COLOR = Color3.fromRGB(140, 140, 145)
local PLAYER_NAME_COLOR = Color3.fromRGB(225, 225, 225)
local TOP_TINT_COLOR = Color3.fromRGB(10, 14, 22)
local SHAFT_COLOR = Color3.fromRGB(205, 218, 255)
local HAZE_COLOR = Color3.fromRGB(200, 206, 218)
local MOTE_COLOR = Color3.fromRGB(235, 242, 255)
local MOTE_GLOW_COLOR = Color3.fromRGB(180, 205, 255)
local WARM_MOTE_COLOR = Color3.fromRGB(255, 190, 175)
local WARM_MOTE_GLOW_COLOR = Color3.fromRGB(255, 70, 60)
local SOFT_MOTE_COLOR = Color3.fromRGB(220, 230, 255)
local CREDITS_BUTTON_COLOR = Color3.fromRGB(32, 32, 32)
local DEPLOY_BUTTON_COLOR = Color3.fromRGB(30, 30, 30)

local CENTER_ANCHOR = Vector2.new(0.5, 0.5)
local TOP_CENTER_ANCHOR = Vector2.new(0.5, 0)

local CREDITS_BUTTON_GRADIENT = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(232, 232, 232))
local DEPLOY_BUTTON_GRADIENT = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(187, 187, 187))

local MOTES: { Mote } = {
	{ x = 874, duration = 21.3, offset = 21.5, sway = 5.7, size = 2, twinkle = 2.5, warm = true },
	{ x = 76, duration = 24.9, offset = 3.4, sway = 5.5, size = 3, twinkle = 5.0 },
	{ x = 347, duration = 19.7, offset = 3.9, sway = 6.6, size = 3, twinkle = 4.2 },
	{ x = 395, duration = 22.6, offset = 25.3, sway = 8.4, size = 2, twinkle = 2.7 },
	{ x = 566, duration = 26.8, offset = 27.7, sway = 5.9, size = 3, twinkle = 4.8 },
	{ x = 1386, duration = 27.5, offset = 13.9, sway = 8.1, size = 3, twinkle = 2.6, warm = true },
	{ x = 834, duration = 21.9, offset = 10.7, sway = 7.0, size = 3, twinkle = 3.7 },
	{ x = 343, duration = 22.3, offset = 0.6, sway = 6.2, size = 2, twinkle = 4.6 },
	{ x = 332, duration = 23.5, offset = 19.8, sway = 5.3, size = 2, twinkle = 3.2 },
	{ x = 950, duration = 23.1, offset = 16.0, sway = 8.4, size = 3, twinkle = 4.3 },
	{ x = 1295, duration = 24.1, offset = 12.0, sway = 5.6, size = 3, twinkle = 3.3, warm = true },
	{ x = 1606, duration = 25.8, offset = 8.4, sway = 6.6, size = 3, twinkle = 2.6 },
}

local SOFT_MOTES: { Mote } = {
	{ x = 948, duration = 39.3, offset = 12.9, sway = 12.1, size = 18, twinkle = 6.1 },
	{ x = 553, duration = 34.5, offset = 3.2, sway = 11.8, size = 28, twinkle = 8.1 },
	{ x = 168, duration = 33.1, offset = 8.0, sway = 8.2, size = 28, twinkle = 7.7 },
	{ x = 1610, duration = 32.2, offset = 36.4, sway = 8.1, size = 28, twinkle = 9.0 },
}

local SHAFTS: { Shaft } = {
	{ x = 980, width = 60, transparency = 0.9 },
	{ x = 1180, width = 140, transparency = 0.88 },
	{ x = 1320, width = 70, transparency = 0.84 },
	{ x = 1460, width = 220, transparency = 0.9 },
	{ x = 1600, width = 90, transparency = 0.86 },
}

local function transparencySequence(points: { { number } }): NumberSequence
	local keypoints = {}
	for _, point in points do
		table.insert(keypoints, NumberSequenceKeypoint.new(point[1], point[2]))
	end
	return NumberSequence.new(keypoints)
end

local SHAFT_MASK = transparencySequence({ { 0, 0 }, { 0.7, 1 }, { 1, 1 } })
local SHAFT_BEAM = transparencySequence({ { 0, 1 }, { 0.5, 0 }, { 1, 1 } })
local HAZE_MASK = transparencySequence({ { 0, 1 }, { 0.45, 1 }, { 0.82, 0 }, { 1, 0 } })
local HAZE_STRIP = transparencySequence({
	{ 0, 0.78 },
	{ 0.07, 0.9 },
	{ 0.13, 0.8 },
	{ 0.2, 0.93 },
	{ 0.28, 0.82 },
	{ 0.35, 0.9 },
	{ 0.42, 0.8 },
	{ 0.5, 0.78 },
	{ 0.57, 0.9 },
	{ 0.63, 0.8 },
	{ 0.7, 0.93 },
	{ 0.78, 0.82 },
	{ 0.85, 0.9 },
	{ 0.92, 0.8 },
	{ 1, 0.78 },
})
local VIGNETTE = transparencySequence({ { 0, 0.6 }, { 0.22, 1 }, { 0.78, 1 }, { 1, 0.6 } })
local TOP_TINT = transparencySequence({ { 0, 0.65 }, { 0.3, 1 }, { 1, 1 } })
local SIDE_SHADE = transparencySequence({ { 0, 0.45 }, { 0.3, 1 }, { 0.72, 1 }, { 1, 0.55 } })
local BOTTOM_SHADE = transparencySequence({ { 0, 1 }, { 0.55, 1 }, { 0.78, 0.6 }, { 1, 0.15 } })

local function createShots(scope: FusionScope): Frame
	local shots: { Instance } = {}
	for index = 1, SHOT_COUNT do
		table.insert(
			shots,
			scope:New("ImageLabel")({
				Name = `Shot{index}`,
				Size = UDim2.fromScale(1.05, 1.05),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = CENTER_ANCHOR,
				BackgroundTransparency = 1,
				Image = Credits.getLoadingScreenImage(),
				ImageTransparency = 1,
				ScaleType = Enum.ScaleType.Crop,
			})
		)
	end

	return scope:New("Frame")({
		Name = "Shots",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 1,

		[Fusion.Children] = shots,
	})
end

local function createShafts(scope: FusionScope): CanvasGroup
	local children: { Instance } = {
		scope:New("UIGradient")({
			Rotation = 90,
			Transparency = SHAFT_MASK,
		}),
	}
	for index, shaft in SHAFTS do
		table.insert(
			children,
			scope:New("Frame")({
				Name = `Beam{index}`,
				Size = UDim2.fromOffset(shaft.width, SHAFT_LENGTH),
				Position = UDim2.new(shaft.x / DESIGN_WIDTH, 0, 0, SHAFT_TOP),
				AnchorPoint = TOP_CENTER_ANCHOR,
				Rotation = SHAFT_ROTATION,
				BackgroundColor3 = SHAFT_COLOR,
				BackgroundTransparency = shaft.transparency,

				[Fusion.Children] = {
					scope:New("UIGradient")({
						Transparency = SHAFT_BEAM,
					}),
				},
			})
		)
	end

	return scope:New("CanvasGroup")({
		Name = "Shafts",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(-SHAFT_DRIFT, 0),
		BackgroundTransparency = 1,
		GroupTransparency = 0.65,
		ZIndex = 3,

		[Fusion.Children] = children,
	})
end

local function createHaze(scope: FusionScope): CanvasGroup
	return scope:New("CanvasGroup")({
		Name = "Haze",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 0.35,
		ZIndex = 4,

		[Fusion.Children] = {
			scope:New("UIGradient")({
				Rotation = 90,
				Transparency = HAZE_MASK,
			}),

			scope:New("Frame")({
				Name = "Strip",
				Size = UDim2.fromScale(2, 1),
				BackgroundColor3 = HAZE_COLOR,

				[Fusion.Children] = {
					scope:New("UIGradient")({
						Transparency = HAZE_STRIP,
					}),
				},
			}),
		},
	})
end

local function createMoteDot(scope: FusionScope, name: string, size: UDim2, color: Color3, baseTransparency: number, zIndex: number): Frame
	return scope:New("Frame")({
		Name = name,
		Size = size,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = CENTER_ANCHOR,
		BackgroundColor3 = color,
		BackgroundTransparency = 1,
		ZIndex = zIndex,
		[Fusion.Attribute("BaseTransparency")] = baseTransparency,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Full,
			}),
		},
	})
end

local function createMote(scope: FusionScope, name: string, mote: Mote, dots: { Frame }): Frame
	return scope:New("Frame")({
		Name = name,
		Size = UDim2.fromOffset(mote.size, mote.size),
		Position = UDim2.fromScale(mote.x / DESIGN_WIDTH, 1),
		AnchorPoint = CENTER_ANCHOR,
		BackgroundTransparency = 1,
		[Fusion.Attribute("X")] = mote.x / DESIGN_WIDTH,
		[Fusion.Attribute("Duration")] = mote.duration,
		[Fusion.Attribute("Offset")] = mote.offset,
		[Fusion.Attribute("Sway")] = mote.sway,
		[Fusion.Attribute("Twinkle")] = mote.twinkle,

		[Fusion.Children] = dots,
	})
end

local function createMotes(scope: FusionScope): Frame
	local motes: { Instance } = {}

	for index, mote in MOTES do
		local glowSize = UDim2.fromOffset(mote.size + 6, mote.size + 6)
		table.insert(
			motes,
			createMote(scope, `Mote{index}`, mote, {
				createMoteDot(scope, "Glow", glowSize, if mote.warm then WARM_MOTE_GLOW_COLOR else MOTE_GLOW_COLOR, 0.7, 1),
				createMoteDot(scope, "Core", UDim2.fromScale(1, 1), if mote.warm then WARM_MOTE_COLOR else MOTE_COLOR, 0.1, 2),
			})
		)
	end

	for index, mote in SOFT_MOTES do
		table.insert(
			motes,
			createMote(scope, `SoftMote{index}`, mote, {
				createMoteDot(scope, "Outer", UDim2.fromScale(0.8, 0.8), SOFT_MOTE_COLOR, 0.9, 1),
				createMoteDot(scope, "Inner", UDim2.fromScale(0.4, 0.4), SOFT_MOTE_COLOR, 0.82, 2),
			})
		)
	end

	return scope:New("Frame")({
		Name = "Motes",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,

		[Fusion.Children] = motes,
	})
end

local function createShade(scope: FusionScope, name: string, color: Color3, rotation: number, transparency: NumberSequence): Frame
	return scope:New("Frame")({
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		ZIndex = 7,

		[Fusion.Children] = {
			scope:New("UIGradient")({
				Rotation = rotation,
				Transparency = transparency,
			}),
		},
	})
end

local function createBrand(scope: FusionScope): Frame
	return scope:New("Frame")({
		Name = "Brand",
		Size = UDim2.fromOffset(320, 48),
		Position = UDim2.fromOffset(EDGE_MARGIN, BRAND_TOP),
		BackgroundTransparency = 1,
		ZIndex = 10,

		[Fusion.Children] = {
			scope:New("ImageLabel")({
				Name = "Crest",
				Size = UDim2.fromOffset(48, 48),
				BackgroundTransparency = 1,
				Image = LOGO_ID,
				ScaleType = Enum.ScaleType.Fit,
			}),

			scope:New("TextLabel")({
				Name = "Wordmark",
				Size = UDim2.fromOffset(0, 20),
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.fromOffset(62, 6),
				BackgroundTransparency = 1,
				Text = WORDMARK_TEXT,
				TextColor3 = Theme.Foreground.Primary,
				TextSize = WORDMARK_SIZE,
				Font = Theme.Text.Black,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			scope:New("TextLabel")({
				Name = "Subtitle",
				Size = UDim2.fromOffset(0, 14),
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.fromOffset(62, 29),
				BackgroundTransparency = 1,
				Text = SUBTITLE_TEXT,
				TextColor3 = MUTED_COLOR,
				TextSize = Theme.Text.XSmall,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		},
	})
end

local function createInfo(scope: FusionScope): Frame
	return scope:New("Frame")({
		Name = "Info",
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(1, -EDGE_MARGIN, 0, INFO_TOP),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		ZIndex = 10,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 12),
			}),

			scope:New("TextLabel")({
				Name = "Region",
				Size = UDim2.fromOffset(0, 16),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				TextColor3 = MUTED_COLOR,
				TextSize = INFO_TEXT_SIZE,
				Font = Theme.Text.Bold,
				Visible = false,
				LayoutOrder = 1,
			}),

			scope:New("Frame")({
				Name = "Divider",
				Size = UDim2.fromOffset(1, 14),
				BackgroundColor3 = Theme.Border.Default,
				Visible = false,
				LayoutOrder = 2,
			}),

			scope:New("TextLabel")({
				Name = "Players",
				Size = UDim2.fromOffset(0, 16),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				TextColor3 = MUTED_COLOR,
				TextSize = INFO_TEXT_SIZE,
				Font = Theme.Text.Bold,
				LayoutOrder = 3,
			}),
		},
	})
end

local function createNameBlock(scope: FusionScope): Frame
	return scope:New("Frame")({
		Name = "NameBlock",
		Size = UDim2.fromOffset(1200, 80),
		Position = UDim2.new(0, EDGE_MARGIN, 1, -BOTTOM_MARGIN),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		ZIndex = 10,

		[Fusion.Children] = {
			scope:New("TextLabel")({
				Name = "BaseName",
				Size = UDim2.fromOffset(0, 52),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Text = string.upper(Credits.getBaseName() or ""),
				TextColor3 = Theme.Foreground.Primary,
				TextSize = BASE_NAME_SIZE,
				Font = Theme.Text.Black,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			scope:New("TextLabel")({
				Name = "Quote",
				Size = UDim2.fromOffset(0, 18),
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.fromOffset(0, 62),
				BackgroundTransparency = 1,
				RichText = true,
				TextColor3 = Theme.Foreground.Secondary,
				TextSize = Theme.Text.Medium,
				Font = Theme.Text.Semibold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			scope:New("Frame")({
				Name = "PlayerRow",
				Size = UDim2.fromOffset(0, 24),
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.fromOffset(0, 56),
				BackgroundTransparency = 1,
				Visible = false,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Bottom,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 12),
					}),

					scope:New("TextLabel")({
						Name = "PlayerName",
						Size = UDim2.fromOffset(0, 24),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						TextColor3 = PLAYER_NAME_COLOR,
						TextSize = Theme.Text.XXLarge,
						Font = Theme.Text.Bold,
						LayoutOrder = 1,
					}),

					scope:New("TextLabel")({
						Name = "Rank",
						Size = UDim2.fromOffset(0, 19),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						TextColor3 = Theme.Foreground.Tertiary,
						TextSize = Theme.Text.Medium,
						Font = Theme.Text.Bold,
						LayoutOrder = 2,
					}),
				},
			}),
		},
	})
end

local function createLoadingBar(scope: FusionScope): Frame
	return scope:New("Frame")({
		Name = "LoadingBar",
		Size = UDim2.fromOffset(BAR_WIDTH, 26),
		Position = UDim2.new(1, -EDGE_MARGIN, 1, -BOTTOM_MARGIN),
		AnchorPoint = Vector2.one,
		BackgroundTransparency = 1,
		ZIndex = 10,

		[Fusion.Children] = {
			scope:New("TextLabel")({
				Name = "Status",
				Size = UDim2.fromOffset(0, 14),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Text = LOADING_TEXT,
				TextColor3 = Theme.Foreground.Tertiary,
				TextSize = Theme.Text.XSmall,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			scope:New("TextLabel")({
				Name = "Percent",
				Size = UDim2.fromOffset(0, 14),
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.fromScale(1, 0),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Text = "0%",
				TextColor3 = Theme.Foreground.Secondary,
				TextSize = Theme.Text.XSmall,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),

			scope:New("Frame")({
				Name = "Track",
				Size = UDim2.new(1, 0, 0, 6),
				Position = UDim2.fromOffset(0, 20),
				BackgroundColor3 = Theme.Progress.Background,
				BackgroundTransparency = Theme.Progress.BackgroundTransparency,
				ClipsDescendants = true,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Full,
					}),

					scope:New("UIStroke")({
						Color = Theme.Progress.Border,
						Thickness = 1,
						Transparency = Theme.Progress.BorderTransparency,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),

					scope:New("Frame")({
						Name = "Fill",
						Size = UDim2.fromScale(0, 1),
						BackgroundColor3 = Theme.Progress.Bar,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = Theme.Radius.Full,
							}),
						},
					}),
				},
			}),
		},
	})
end

local function createButton(
	scope: FusionScope,
	name: string,
	text: string,
	textSize: number,
	textColor: Color3,
	background: Color3,
	gradient: ColorSequence,
	border: Color3,
	size: UDim2,
	position: UDim2
): TextButton
	return scope:New("TextButton")({
		Name = name,
		Size = size,
		Position = position,
		BackgroundColor3 = background,
		AutoButtonColor = false,
		Text = text,
		TextColor3 = textColor,
		TextSize = textSize,
		Font = Theme.Text.Bold,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Large,
			}),

			scope:New("UIStroke")({
				Color = border,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),

			scope:New("UIGradient")({
				Rotation = 90,
				Color = gradient,
			}),
		},
	})
end

local function createButtons(scope: FusionScope): Frame
	local deployOffset = CREDITS_BUTTON_WIDTH + BUTTON_GAP

	return scope:New("Frame")({
		Name = "Buttons",
		Size = UDim2.fromOffset(BAR_WIDTH, BUTTON_HEIGHT),
		Position = UDim2.new(1, -EDGE_MARGIN, 1, -BOTTOM_MARGIN),
		AnchorPoint = Vector2.one,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,

		[Fusion.Children] = {
			createButton(
				scope,
				"CreditsButton",
				"CREDITS",
				Theme.Text.Medium,
				Theme.Foreground.Secondary,
				CREDITS_BUTTON_COLOR,
				CREDITS_BUTTON_GRADIENT,
				Theme.Border.Default,
				UDim2.new(0, CREDITS_BUTTON_WIDTH, 1, 0),
				UDim2.new()
			),

			createButton(
				scope,
				"DeployButton",
				"DEPLOY",
				Theme.Text.XLarge,
				Theme.Foreground.Primary,
				DEPLOY_BUTTON_COLOR,
				DEPLOY_BUTTON_GRADIENT,
				Theme.Border.Active,
				UDim2.new(1, -deployOffset, 1, 0),
				UDim2.fromOffset(deployOffset, 0)
			),
		},
	})
end

function UIBuilder.createLoadingScreen(): ScreenGui
	local scope = Fusion.scoped(Fusion)

	return scope:New("ScreenGui")({
		Name = "VultarLoadingScreen",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		DisplayOrder = 999999,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Canvas",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Colors.Black[900],
				ClipsDescendants = true,

				[Fusion.Children] = {
					scope:New("UIScale")({}),

					createShots(scope),

					scope:New("Frame")({
						Name = "ShotFade",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Theme.Colors.Black[950],
						BackgroundTransparency = 1,
						ZIndex = 2,
					}),

					createShafts(scope),
					createHaze(scope),
					createMotes(scope),

					createShade(scope, "Vignette", Theme.Colors.Black[950], 90, VIGNETTE),
					createShade(scope, "TopTint", TOP_TINT_COLOR, 90, TOP_TINT),
					createShade(scope, "SideShade", Theme.Colors.Black[950], 0, SIDE_SHADE),
					createShade(scope, "BottomShade", Theme.Colors.Black[950], 90, BOTTOM_SHADE),

					CreditsPanel.create(scope),

					createBrand(scope),
					createInfo(scope),
					createNameBlock(scope),
					createLoadingBar(scope),
					createButtons(scope),

					scope:New("Frame")({
						Name = "Blackout",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Theme.Colors.Black[950],
						BackgroundTransparency = 1,
						ZIndex = 20,
					}),
				},
			}),
		},
	})
end

return UIBuilder
