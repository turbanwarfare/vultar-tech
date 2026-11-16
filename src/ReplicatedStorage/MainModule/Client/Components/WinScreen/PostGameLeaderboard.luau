--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local AnimatedCardService = require(MainModule.Client.Services.AnimatedCardService)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)
local CreditsStrip = require(script.Parent.CreditsStrip)
local Types = require(MainModule.Shared.Types)
local StatsConfig = require(MainModule.Shared.Config.Stats.StatsConfig)
local LeaderboardConstants = require(MainModule.Client.Services.LeaderboardService.LeaderboardConstants)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

local Workspace = workspace

local DEFENDER_COLOR = Color3.fromRGB(220, 80, 80)
local HOSTILE_COLOR = Color3.fromRGB(80, 145, 235)
local GOLD_COLOR = Color3.fromRGB(255, 215, 0)
local SILVER_COLOR = Color3.fromRGB(192, 192, 192)
local BRONZE_COLOR = Color3.fromRGB(205, 127, 50)
local WIN_GLOW_COLOR = Color3.fromRGB(255, 230, 100)
local MVP_ACCENT = Color3.fromRGB(255, 200, 60)
local MVP_STRIP_STROKE_COLOR = Color3.fromRGB(110, 110, 110)
local CLOSE_STROKE_COLOR = Color3.fromRGB(180, 50, 50)
local CLOSE_TEXT_COLOR = Color3.fromRGB(255, 140, 140)

local CARD_FADE_GRADIENT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.6, 0),
	NumberSequenceKeypoint.new(1, 1),
})

local PANEL_WIDTH = 480
local PANEL_HEIGHT = 720
local HEADER_H = 64
local ROW_H = 40
local ROW_SPACING = 3
local INITIAL_ROW_BATCH = 10
local ROW_BATCH_SIZE = 6
local MAX_ANIMATED_CARD_ROWS_PER_PANEL = 6
local PANEL_PADDING = 12
local PANEL_GAP = 8
local CORNER = 8
local SMALL_CORNER = 5
local SHADOW_SPREAD = 4
local SHADOW_OFFSET_Y = 1
local SHADOW_TRANSP = 0.7

local MVP_STRIP_H = 84
local MVP_STRIP_GAP = 8
local MVP_TILE_SIZE = 60
local CREDITS_STRIP_H = 60

local SPRING_SPEED = 18
local SPRING_DAMP = 1
local DESIGN_TOTAL_WIDTH = PANEL_WIDTH * 2 + PANEL_GAP
local DESIGN_TOTAL_HEIGHT = MVP_STRIP_H + MVP_STRIP_GAP + PANEL_HEIGHT + CREDITS_STRIP_H + MVP_STRIP_GAP + 80
local SIDE_MARGIN = 40
local TOP_RESERVED = 130
local BOTTOM_MARGIN = 30

local VULTAR_ICON = "rbxassetid://98751546690059"
local HOSTILES_ICON = "rbxassetid://0"
local HEADER_TEXTURE = "rbxassetid://0"

local MVP_ICON_COLOR = Color3.fromRGB(236, 234, 239)
local MVP_LABEL_COLOR = Color3.fromRGB(166, 166, 166)
local MVP_TILE_COLOR = Color3.fromRGB(26, 26, 26)
local DEFENDER_HEADER_GRADIENT = ColorSequence.new(Color3.fromRGB(120, 40, 40), Color3.fromRGB(255, 65, 68))
local HOSTILE_HEADER_GRADIENT = ColorSequence.new(Color3.fromRGB(80, 145, 235), Color3.fromRGB(80, 140, 220))
local DEFENDER_HEADER_SHADOW = Color3.fromRGB(120, 40, 40)
local HOSTILE_HEADER_SHADOW = Color3.fromRGB(80, 145, 235)
local HEADER_SHADOW_BLUR = 8
local HEADER_SHADOW_TRANSP = 0.5

local RANK_COLORS = {
	[1] = GOLD_COLOR,
	[2] = SILVER_COLOR,
	[3] = BRONZE_COLOR,
}

local RANK_LABELS = { "1ST", "2ND", "3RD" }

local function rankColor(rank: number): Color3?
	return RANK_COLORS[rank]
end

local function formatStat(n: number): string
	return tostring(math.round(n))
end

type EntryType = StatsConfig.LeaderboardEntry
type RowEntry = {
	UserId: number,
	DisplayName: string,
	Username: string,
	Kills: number,
	Damage: number,
	Heals: number,
	Rank: number,
	CardImageId: string?,
	IsAnimatedCard: boolean?,
}

export type FactionData = {
	name: string,
	displayName: string,
	icon: string,
	entries: { EntryType },
	totals: StatsConfig.PlayerStats,
	playerCount: number,
}

local function buildRows(entries: { EntryType }?): { RowEntry }
	if not entries then
		return {}
	end

	local rows: { RowEntry } = {}
	for _, entry in entries do
		table.insert(rows, {
			UserId = entry.UserId,
			DisplayName = entry.DisplayName or ("Player " .. tostring(entry.UserId)),
			Username = entry.Username or entry.DisplayName or ("Player " .. tostring(entry.UserId)),
			Kills = math.round(entry.Stats.Kills or 0),
			Damage = math.round(entry.Stats.Damage or 0),
			Heals = math.round(entry.Stats.Heals or 0),
			Rank = 0,
			CardImageId = entry.CardImageId,
			IsAnimatedCard = entry.IsAnimatedCard,
		})
	end

	table.sort(rows, function(a, b)
		if a.Kills ~= b.Kills then
			return a.Kills > b.Kills
		end
		return a.Damage > b.Damage
	end)

	for i, row in rows do
		row.Rank = i
	end

	return rows
end

local function StatChip(scope: FusionScope, label: string, value: number, rowAlpha: any, layoutOrder: number): Frame
	return scope:New("Frame")({
		Name = "StatChip_" .. label,
		Size = UDim2.fromOffset(70, 22),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
			return 0.92 + (1 - use(rowAlpha)) * 0.08
		end),
		LayoutOrder = layoutOrder,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),

			scope:New("TextLabel")({
				Name = "Val",
				Size = UDim2.fromScale(1, 0.55),
				Position = UDim2.fromScale(0, 0),
				BackgroundTransparency = 1,
				Text = formatStat(value),
				TextColor3 = Theme.Colors.White,
				TextTransparency = scope:Computed(function(use: FusionUseFn)
					return 1 - use(rowAlpha)
				end),
				TextSize = 11,
				Font = Theme.Text.Bold,
			}),

			scope:New("TextLabel")({
				Name = "Lbl",
				Size = UDim2.fromScale(1, 0.45),
				Position = UDim2.fromScale(0, 0.55),
				BackgroundTransparency = 1,
				Text = label,
				TextColor3 = Color3.fromRGB(160, 160, 160),
				TextTransparency = scope:Computed(function(use: FusionUseFn)
					return 1 - use(rowAlpha)
				end),
				TextSize = 7,
				Font = Theme.Text.Bold,
			}),
		},
	})
end

local function PlayerRow(scope: FusionScope, entry: RowEntry, rowVisible: any, isWinSide: boolean, cardImageId: string?, isAnimatedCard: boolean?): Frame
	local medal = rankColor(entry.Rank)
	local isMedal = medal ~= nil

	local rowAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(rowVisible) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMP
	)

	local rowY = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(rowVisible) then 0 else 18
		end),
		SPRING_SPEED,
		SPRING_DAMP
	)

	local rankText = if isMedal then (RANK_LABELS[entry.Rank] or tostring(entry.Rank)) else tostring(entry.Rank)
	local rankColor3 = Color3.fromRGB(255, 255, 255)

	local winTeamColor = if isWinSide
		then (entry.Rank <= 3 and Color3.fromRGB(255, 230, 100) or Color3.fromRGB(255, 245, 180))
		else Color3.fromRGB(255, 255, 255)
	local rowBg = if isWinSide then winTeamColor else Color3.fromRGB(255, 255, 255)
	local rowBgAlpha = if isWinSide then 0.88 else 0.96

	local children: { any } = {
		scope:New("UICorner")({ CornerRadius = UDim.new(0, SMALL_CORNER) }),

		if cardImageId and cardImageId ~= ""
			then if isAnimatedCard
				then scope:New("CanvasGroup")({
					Name = "AnimatedCardContainer",
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.fromScale(0.7, 1),
					BackgroundTransparency = 1,
					GroupTransparency = scope:Computed(function(use: FusionUseFn)
						return 1 - use(rowAlpha)
					end),
					ZIndex = 1,

					[Fusion.Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0, SMALL_CORNER) }),
						scope:New("UIGradient")({
							Transparency = CARD_FADE_GRADIENT,
							Rotation = 0,
						}),
						scope:New("Frame")({
							Name = "ScrollingFrame",
							Position = UDim2.fromOffset(0, 0),
							Size = UDim2.fromScale(2, 1),
							BackgroundTransparency = 1,

							[Fusion.Children] = {
								scope:New("ImageLabel")({
									Name = "CardImage1",
									Position = UDim2.fromOffset(0, 0),
									Size = UDim2.fromScale(0.5, 1),
									BackgroundTransparency = 1,
									Image = cardImageId,
									ImageTransparency = 0.5,
									ScaleType = Enum.ScaleType.Crop,
									ZIndex = 1,
								}),
								scope:New("ImageLabel")({
									Name = "CardImage2",
									Position = UDim2.fromScale(0.5, 0),
									Size = UDim2.fromScale(0.5, 1),
									BackgroundTransparency = 1,
									Image = cardImageId,
									ImageTransparency = 0.5,
									ScaleType = Enum.ScaleType.Crop,
									ZIndex = 1,
								}),
							},
						}),
					},
				})
				else scope:New("ImageLabel")({
					Name = "CardBackground",
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.fromScale(0.7, 1),
					BackgroundTransparency = 1,
					Image = cardImageId,
					ImageTransparency = scope:Computed(function(use: FusionUseFn)
						return 0.5 + (1 - use(rowAlpha)) * 0.5
					end),
					ScaleType = Enum.ScaleType.Crop,
					ZIndex = 1,

					[Fusion.Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0, SMALL_CORNER) }),
						scope:New("UIGradient")({
							Transparency = CARD_FADE_GRADIENT,
							Rotation = 0,
						}),
					},
				})
			else nil,

		if isMedal
			then scope:New("Frame")({
				Name = "MedalStripe",
				Size = UDim2.new(0, 3, 1, -6),
				Position = UDim2.fromOffset(0, 3),
				BackgroundColor3 = medal :: Color3,
				BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
					return 1 - use(rowAlpha)
				end),
				ZIndex = 2,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 2) }),
				},
			})
			else nil,

		scope:New("Frame")({
			Name = "RankBadge",
			Size = UDim2.fromOffset(54, 24),
			Position = UDim2.new(0, 8, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = if isMedal then medal :: Color3 else Color3.fromRGB(40, 40, 40),
			BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
				return (if isMedal then 0.15 else 0.6) + (1 - use(rowAlpha)) * 0.85
			end),
			ZIndex = 3,

			[Fusion.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
				scope:New("TextLabel")({
					Name = "RankText",
					Size = UDim2.fromScale(0.45, 1),
					Position = UDim2.fromScale(0, 0),
					BackgroundTransparency = 1,
					Text = rankText,
					TextColor3 = rankColor3,
					TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
					TextStrokeTransparency = 0.7,
					TextTransparency = scope:Computed(function(use: FusionUseFn)
						return 1 - use(rowAlpha)
					end),
					TextSize = if isMedal then 12 else 10,
					Font = Theme.Text.Black,
					ZIndex = 4,
				}),
				scope:New("ImageLabel")({
					Name = "PlayerAvatar",
					Size = UDim2.fromOffset(20, 20),
					Position = UDim2.new(1, -2, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(entry.UserId) .. "&w=48&h=48",
					ImageTransparency = scope:Computed(function(use: FusionUseFn)
						return 1 - use(rowAlpha)
					end),
					ZIndex = 4,
					[Fusion.Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
					},
				}),
			},
		}),

		scope:New("TextLabel")({
			Name = "Username",
			Size = UDim2.new(1, -180, 0.55, 0),
			Position = UDim2.fromOffset(70, 2),
			BackgroundTransparency = 1,
			Text = string.upper(entry.Username or entry.DisplayName),
			TextColor3 = if isMedal then Color3.fromRGB(255, 255, 255) else Theme.Colors.White,
			TextTransparency = scope:Computed(function(use: FusionUseFn)
				return 1 - use(rowAlpha)
			end),
			TextSize = 12,
			Font = if isMedal then Theme.Text.Black else Theme.Text.Bold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
		}),

		scope:New("TextLabel")({
			Name = "DisplayName",
			Size = UDim2.new(1, -180, 0.45, 0),
			Position = UDim2.fromOffset(70, 15),
			BackgroundTransparency = 1,
			Text = "@ " .. entry.DisplayName,
			TextColor3 = Color3.fromRGB(160, 160, 160),
			TextTransparency = scope:Computed(function(use: FusionUseFn)
				return 0.4 + (1 - use(rowAlpha)) * 0.6
			end),
			TextSize = 9,
			Font = Theme.Text.Bold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
		}),

		scope:New("Frame")({
			Name = "Stats",
			Size = UDim2.fromOffset(225, ROW_H),
			Position = UDim2.fromScale(0.99, 0.5),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 3,

			[Fusion.Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 4),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				StatChip(scope, "KILLS", entry.Kills, rowAlpha, 1),
				StatChip(scope, "DMG", entry.Damage, rowAlpha, 2),
				StatChip(scope, "HEALS", entry.Heals, rowAlpha, 3),
			},
		}),
	}

	if cardImageId and cardImageId ~= "" and isAnimatedCard then
		task.spawn(function()
			task.wait()
			for _, child in children do
				if child:IsA("CanvasGroup") and child.Name == "AnimatedCardContainer" then
					AnimatedCardService:RegisterContainer(child :: Frame, entry.UserId)
					table.insert(scope, function()
						AnimatedCardService:UnregisterContainer(child :: Frame)
					end)
					break
				end
			end
		end)
	end

	return scope:New("Frame")({
		Name = "Row_" .. entry.Rank,
		Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundColor3 = rowBg,
		BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
			return rowBgAlpha + (1 - use(rowAlpha)) * (1 - rowBgAlpha)
		end),
		Position = scope:Computed(function(use: FusionUseFn)
			return UDim2.fromOffset(0, use(rowY))
		end),
		ClipsDescendants = false,

		[Fusion.Children] = children,
	})
end

local function fadeIn(scope: FusionScope, panelAlpha: any, base: number): any
	return scope:Computed(function(use: FusionUseFn)
		return base + (1 - use(panelAlpha)) * (1 - base)
	end)
end

local function IconBar(scope: FusionScope, panelAlpha: any, name: string, size: UDim2, position: UDim2, anchor: Vector2): Frame
	return scope:New("Frame")({
		Name = name,
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		BackgroundColor3 = MVP_ICON_COLOR,
		BackgroundTransparency = fadeIn(scope, panelAlpha, 0),
		BorderSizePixel = 0,
	})
end

local function IconRound(scope: FusionScope, panelAlpha: any, name: string, size: UDim2, children: { any }): Frame
	return scope:New("Frame")({
		Name = name,
		Size = size,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = MVP_ICON_COLOR,
		BackgroundTransparency = fadeIn(scope, panelAlpha, 0),
		BorderSizePixel = 0,

		[Fusion.Children] = children,
	})
end

local function SkullIcon(scope: FusionScope, panelAlpha: any): ImageLabel
	return scope:New("ImageLabel")({
		Name = "Icon",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = HOSTILES_ICON,
		ImageColor3 = MVP_ICON_COLOR,
		ImageTransparency = fadeIn(scope, panelAlpha, 0),
		ScaleType = Enum.ScaleType.Fit,
	})
end

local function CrosshairIcon(scope: FusionScope, panelAlpha: any): Frame
	return scope:New("Frame")({
		Name = "Icon",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Ring",
				Size = UDim2.fromOffset(22, 22),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					scope:New("UIStroke")({
						Color = MVP_ICON_COLOR,
						Thickness = 2,
						Transparency = fadeIn(scope, panelAlpha, 0.2),
					}),
				},
			}),
			IconBar(scope, panelAlpha, "TickTop", UDim2.fromOffset(2, 8), UDim2.fromScale(0.5, 0), Vector2.new(0.5, 0)),
			IconBar(scope, panelAlpha, "TickBottom", UDim2.fromOffset(2, 8), UDim2.fromScale(0.5, 1), Vector2.new(0.5, 1)),
			IconBar(scope, panelAlpha, "TickLeft", UDim2.fromOffset(8, 2), UDim2.fromScale(0, 0.5), Vector2.new(0, 0.5)),
			IconBar(scope, panelAlpha, "TickRight", UDim2.fromOffset(8, 2), UDim2.fromScale(1, 0.5), Vector2.new(1, 0.5)),
			IconRound(scope, panelAlpha, "Dot", UDim2.fromOffset(5, 5), {
				scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			}),
		},
	})
end

local function CrossIcon(scope: FusionScope, panelAlpha: any): Frame
	return scope:New("Frame")({
		Name = "Icon",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			IconRound(scope, panelAlpha, "Vertical", UDim2.fromOffset(10, 30), {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, 2) }),
			}),
			IconRound(scope, panelAlpha, "Horizontal", UDim2.fromOffset(30, 10), {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, 2) }),
			}),
		},
	})
end

local function CompactMVPStrip(scope: FusionScope, topPlayers: any, panelAlpha: any): Frame
	local totalWidth = PANEL_WIDTH * 2 + PANEL_GAP

	local function MVPSlot(label: string, title: string, player: any, valueSuffix: string, layoutOrder: number, icon: Instance): Frame
		local name = if player and player.DisplayName then string.upper(player.DisplayName) else "---"
		local value = if player and player.Value then formatStat(player.Value) .. " " .. valueSuffix else "-"

		return scope:New("Frame")({
			Name = "MVPSlot_" .. label,
			Size = UDim2.new(1 / 3, -8, 1, 0),
			BackgroundTransparency = 1,
			LayoutOrder = layoutOrder,

			[Fusion.Children] = {
				scope:New("Frame")({
					Name = "IconTile",
					Size = UDim2.fromOffset(MVP_TILE_SIZE, MVP_TILE_SIZE),
					Position = UDim2.new(0, 14, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = MVP_TILE_COLOR,
					BackgroundTransparency = fadeIn(scope, panelAlpha, 0.2),

					[Fusion.Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
						scope:New("UIStroke")({
							Color = MVP_STRIP_STROKE_COLOR,
							Thickness = 1,
							Transparency = fadeIn(scope, panelAlpha, 0.4),
						}),
						icon,
					},
				}),

				scope:New("TextLabel")({
					Name = "StatLabel",
					Size = UDim2.new(1, -96, 0, 14),
					Position = UDim2.fromOffset(88, 10),
					BackgroundTransparency = 1,
					Text = title,
					TextColor3 = MVP_LABEL_COLOR,
					TextTransparency = fadeIn(scope, panelAlpha, 0.1),
					TextSize = 10,
					Font = Theme.Text.Bold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				scope:New("TextLabel")({
					Name = "PlayerName",
					Size = UDim2.new(1, -96, 0, 20),
					Position = UDim2.fromOffset(88, 26),
					BackgroundTransparency = 1,
					Text = name,
					TextColor3 = Theme.Colors.White,
					TextTransparency = fadeIn(scope, panelAlpha, 0),
					TextSize = 14,
					Font = Theme.Text.Black,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				scope:New("TextLabel")({
					Name = "StatValue",
					Size = UDim2.new(1, -96, 0, 30),
					Position = UDim2.fromOffset(88, 46),
					BackgroundTransparency = 1,
					Text = value,
					TextColor3 = MVP_ACCENT,
					TextTransparency = fadeIn(scope, panelAlpha, 0.3),
					TextSize = 22,
					Font = Theme.Text.Black,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			},
		})
	end

	return scope:New("Frame")({
		Name = "CompactMVPStrip",
		Size = UDim2.fromOffset(totalWidth, MVP_STRIP_H),
		BackgroundColor3 = Theme.Chat.Window.Background,
		BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
			return Theme.Chat.Window.BackgroundTransparency + (1 - use(panelAlpha)) * (1 - Theme.Chat.Window.BackgroundTransparency)
		end),
		Visible = scope:Computed(function(use: FusionUseFn)
			return use(panelAlpha) > 0.02
		end),

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER) }),

			scope:New("UIStroke")({
				Color = MVP_STRIP_STROKE_COLOR,
				Thickness = 1,
				Transparency = scope:Computed(function(use: FusionUseFn)
					local a = use(panelAlpha)
					if a < 0.05 then
						return 1
					end
					return 0.3 + (1 - a) * 0.7
				end),
			}),

			Shadow(scope, {
				Size = UDim2.new(1, SHADOW_SPREAD * 2, 1, SHADOW_SPREAD * 2),
				Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = 0,
				Transparency = scope:Computed(function(use: FusionUseFn)
					return SHADOW_TRANSP + (1 - use(panelAlpha)) * (1 - SHADOW_TRANSP)
				end),
				ZIndex = 0,
			}),

			scope:New("Frame")({
				Name = "SlotsRow",
				Size = UDim2.new(1, -PANEL_PADDING * 2, 1, 0),
				Position = UDim2.fromOffset(PANEL_PADDING, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					MVPSlot("MOST DMG", "MOST DAMAGE", topPlayers and topPlayers.Damage, "DMG", 1, SkullIcon(scope, panelAlpha)),

					scope:New("Frame")({
						Name = "Divider1",
						Size = UDim2.new(0, 1, 0.6, 0),
						BackgroundColor3 = MVP_STRIP_STROKE_COLOR,
						BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
							return 0.4 + (1 - use(panelAlpha)) * 0.6
						end),
						BorderSizePixel = 0,
						LayoutOrder = 2,
					}),

					MVPSlot("MOST KILLS", "MOST KILLS", topPlayers and topPlayers.Kills, "KILLS", 3, CrosshairIcon(scope, panelAlpha)),

					scope:New("Frame")({
						Name = "Divider2",
						Size = UDim2.new(0, 1, 0.6, 0),
						BackgroundColor3 = MVP_STRIP_STROKE_COLOR,
						BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
							return 0.4 + (1 - use(panelAlpha)) * 0.6
						end),
						BorderSizePixel = 0,
						LayoutOrder = 4,
					}),

					MVPSlot("MOST HEALS", "MOST HEALS", topPlayers and topPlayers.Heals, "HEALS", 5, CrossIcon(scope, panelAlpha)),
				},
			}),
		},
	})
end

local function FactionLeaderboardPanel(
	scope: FusionScope,
	teamName: string,
	displayName: string,
	icon: string,
	accentColor: Color3,
	headerGradient: ColorSequence,
	headerShadowColor: Color3,
	rows: { RowEntry },
	isWinner: boolean,
	panelAlpha: any
): Frame
	local totalKills, totalDamage, totalHeals = 0, 0, 0
	for _, row in rows do
		totalKills += row.Kills
		totalDamage += row.Damage
		totalHeals += row.Heals
	end

	local rowVisibles: { any } = {}
	for i = 1, #rows do
		rowVisibles[i] = scope:Value(false)
	end

	local rowChildren: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, ROW_SPACING),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	local maxRowsWithoutScroll = 18
	local canvasHeight = math.max(#rows, maxRowsWithoutScroll) * (ROW_H + ROW_SPACING)
	local hasStartedStagger = false
	local rowsRendered = false
	local renderCancelled = false
	local playerList: ScrollingFrame? = nil

	local function renderRows()
		if rowsRendered or not playerList then
			return
		end
		rowsRendered = true

		task.spawn(function()
			for index, entry in rows do
				if renderCancelled or not playerList or not playerList.Parent then
					return
				end

				local animateCard = entry.IsAnimatedCard == true and entry.Rank <= MAX_ANIMATED_CARD_ROWS_PER_PANEL
				local row = PlayerRow(scope, entry, rowVisibles[entry.Rank], isWinner, entry.CardImageId, animateCard)
				row.LayoutOrder = entry.Rank
				row.Parent = playerList

				if index == INITIAL_ROW_BATCH or (index > INITIAL_ROW_BATCH and (index - INITIAL_ROW_BATCH) % ROW_BATCH_SIZE == 0) then
					task.wait()
				end
			end
		end)
	end

	table.insert(scope, function()
		renderCancelled = true
	end)

	scope:Observer(panelAlpha):onChange(function()
		local alpha = Fusion.peek(panelAlpha)
		if alpha > 0.5 and not hasStartedStagger then
			hasStartedStagger = true
			renderRows()
			task.spawn(function()
				task.wait(0.25)
				for _, vis in rowVisibles do
					vis:set(true)
					task.wait(0.045)
				end
			end)
		elseif alpha > 0.05 then
			renderRows()
		elseif alpha < 0.3 then
			hasStartedStagger = false
			for _, vis in rowVisibles do
				vis:set(false)
			end
		end
	end)

	local listOffsetY = HEADER_H + 8

	local scrollingFrame = scope:New("ScrollingFrame")({
		Name = "PlayerList",
		Size = UDim2.new(1, -(PANEL_PADDING * 2), 1, -(listOffsetY + 2)),
		Position = UDim2.fromOffset(PANEL_PADDING, listOffsetY),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		ScrollBarImageTransparency = 1,
		CanvasSize = UDim2.fromOffset(0, canvasHeight),
		BorderSizePixel = 0,
		ZIndex = 2,

		[Fusion.Children] = rowChildren,
	})
	playerList = scrollingFrame

	task.defer(renderRows)

	return scope:New("Frame")({
		Name = teamName .. "Panel",
		Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT),
		BackgroundColor3 = Theme.Chat.Window.Background,
		BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
			return Theme.Chat.Window.BackgroundTransparency + (1 - use(panelAlpha)) * (1 - Theme.Chat.Window.BackgroundTransparency)
		end),

		Visible = scope:Computed(function(use: FusionUseFn)
			return use(panelAlpha) > 0.02
		end),

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER) }),

			scope:New("UIStroke")({
				Color = Theme.Chat.Window.Border,
				Thickness = 1,
				Transparency = scope:Computed(function(use: FusionUseFn)
					local a = use(panelAlpha)
					if a < 0.05 then
						return 1
					end
					return 0
				end),
			}),

			Shadow(scope, {
				Size = UDim2.new(1, SHADOW_SPREAD * 2, 1, SHADOW_SPREAD * 2),
				Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = 0,
				Transparency = scope:Computed(function(use: FusionUseFn)
					return SHADOW_TRANSP + (1 - use(panelAlpha)) * (1 - SHADOW_TRANSP)
				end),
				ZIndex = 0,
			}),

			scope:New("Frame")({
				Name = "HeaderContainer",
				Size = UDim2.new(1, 0, 0, HEADER_H),
				BackgroundTransparency = 1,
				ZIndex = 2,
				ClipsDescendants = true,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "HeaderBackground",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = accentColor,
						BackgroundTransparency = 1,
						ClipsDescendants = false,

						[Fusion.Children] = {
							scope:New("ImageLabel")({
								Name = "Background",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								ClipsDescendants = true,
								Image = HEADER_TEXTURE,
								ImageTransparency = scope:Computed(function(use: FusionUseFn)
									return 0.3 + (1 - use(panelAlpha)) * 0.7
								end),
								ScaleType = Enum.ScaleType.Fit,

								[Fusion.Children] = {
									scope:New("UIGradient")({ Color = headerGradient }),
									scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER) }),
								},
							}),

							scope:New("UIStroke")({
								Color = accentColor,
								Thickness = 1.5,
								BorderOffset = UDim.new(0, -1),
								Transparency = scope:Computed(function(use: FusionUseFn)
									local a = use(panelAlpha)
									if a < 0.05 then
										return 1
									end
									return 0.4 + (1 - a) * 0.6
								end),
							}),
							scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER) }),
						},
					}),

					scope:New("ImageLabel")({
						Name = "Icon",
						Size = UDim2.fromOffset(36, 36),
						Position = UDim2.new(0, PANEL_PADDING, 0.5, -1),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						Image = icon,
						ImageTransparency = scope:Computed(function(use: FusionUseFn)
							return 1 - use(panelAlpha)
						end),
						ScaleType = Enum.ScaleType.Fit,
						ZIndex = 5,
					}),

					scope:New("TextLabel")({
						Name = "TeamName",
						Size = UDim2.new(1, -250, 1, 0),
						Position = UDim2.fromOffset(56, -1),
						BackgroundTransparency = 1,
						Text = displayName,
						TextColor3 = if isWinner then WIN_GLOW_COLOR else Theme.Colors.White,
						TextTransparency = scope:Computed(function(use: FusionUseFn)
							return 1 - use(panelAlpha)
						end),
						TextSize = 17,
						Font = Theme.Text.Black,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 4,
					}),

					if isWinner
						then scope:New("Frame")({
							Name = "WinnerBadge",
							Size = UDim2.fromOffset(65, 18),
							Position = UDim2.new(1, -16, 0, 9),
							AnchorPoint = Vector2.new(1, 0),
							BackgroundColor3 = accentColor,
							BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
								return 0.7 + (1 - use(panelAlpha)) * 0.3
							end),
							ZIndex = 4,

							[Fusion.Children] = {
								scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
								scope:New("UIStroke")({
									Color = GOLD_COLOR,
									Thickness = 1.5,
									Transparency = scope:Computed(function(use: FusionUseFn)
										local a = use(panelAlpha)
										if a < 0.05 then
											return 1
										end
										return 0.2 + (1 - a) * 0.8
									end),
								}),
								scope:New("TextLabel")({
									Size = UDim2.fromScale(1, 0.9),
									BackgroundTransparency = 1,
									Text = "WINNER",
									TextColor3 = GOLD_COLOR,
									TextTransparency = scope:Computed(function(use: FusionUseFn)
										return 1 - use(panelAlpha)
									end),
									TextSize = 10,
									Font = Theme.Text.Black,
									ZIndex = 5,
								}),
							},
						})
						else nil,

					scope:New("Frame")({
						Name = "TeamTotals",
						Size = UDim2.fromOffset(225, 22),
						Position = UDim2.new(1, -16, 0.7, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundTransparency = 1,
						ZIndex = 4,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Right,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 4),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							StatChip(scope, "KLS", totalKills, panelAlpha, 1),
							StatChip(scope, "DMG", totalDamage, panelAlpha, 2),
							StatChip(scope, "HLS", totalHeals, panelAlpha, 3),
						},
					}),

					scope:New("UIShadow")({
						BlurRadius = UDim.new(0, HEADER_SHADOW_BLUR),
						Color = headerShadowColor,
						Transparency = scope:Computed(function(use: FusionUseFn)
							return HEADER_SHADOW_TRANSP + (1 - use(panelAlpha)) * (1 - HEADER_SHADOW_TRANSP)
						end),
					}),
				},
			}),

			scrollingFrame,
		},
	})
end

export type PostGameLeaderboardProps = {
	DefendersData: FactionData,
	RaidersData: FactionData,
	DefendersWon: boolean,
	TopPlayers: any?,
	Visible: any,
	OnClose: () -> (),
	OnOpenMVP: () -> (),
	CreditsBalance: any?,
	CreditsEarned: any?,
	CreditsReward: any?,
	CreditsPurchasable: any?,
	OnBalanceClick: (() -> ())?,
}

local function PostGameLeaderboard(scope: FusionScope, props: PostGameLeaderboardProps): Frame
	local defendersData = props.DefendersData
	local raidersData = props.RaidersData
	local defendersWon = props.DefendersWon
	local topPlayers = props.TopPlayers
	local defRows = buildRows(defendersData.entries)

	local filteredRaiders = {}
	for _, entry in raidersData.entries do
		if not (entry.Team and LeaderboardConstants.NEUTRAL_TEAMS[entry.Team]) then
			table.insert(filteredRaiders, entry)
		end
	end

	local hostRows = buildRows(filteredRaiders)

	local isClosing = false

	local currentCamera = Workspace.CurrentCamera
	local viewportValue = scope:Value(currentCamera.ViewportSize)

	local vpConn = currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		viewportValue:set(currentCamera.ViewportSize)
	end)

	local camConn: RBXScriptConnection
	camConn = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		currentCamera = Workspace.CurrentCamera
		viewportValue:set(currentCamera.ViewportSize)
		if vpConn then
			vpConn:Disconnect()
		end
		vpConn = currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			viewportValue:set(currentCamera.ViewportSize)
		end)
	end)

	table.insert(scope, function()
		if vpConn then
			vpConn:Disconnect()
			vpConn = nil
		end
		if camConn then
			camConn:Disconnect()
			camConn = nil
		end
	end)

	local uiScale = scope:Computed(function(use: FusionUseFn)
		local vp = use(viewportValue)
		local availW = vp.X - SIDE_MARGIN * 2
		local availH = vp.Y - TOP_RESERVED - BOTTOM_MARGIN
		local sx = availW / DESIGN_TOTAL_WIDTH
		local sy = availH / DESIGN_TOTAL_HEIGHT
		return math.min(1, sx, sy)
	end)

	local containerAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(props.Visible) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMP
	)

	local containerY = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(props.Visible) then 0 else 40
		end),
		SPRING_SPEED,
		SPRING_DAMP
	)

	local actionButtonAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			local a = use(containerAlpha)
			local isVisible = use(props.Visible)
			return if isVisible and a > 0.85 then 1 else 0
		end),
		12,
		1
	)

	local totalWidth = PANEL_WIDTH * 2 + PANEL_GAP

	local function CloseButton(): TextButton
		return scope:New("TextButton")({
			Name = "CloseButton",
			Size = UDim2.fromOffset(160, 44),
			BackgroundColor3 = Theme.Chat.Window.Background,
			BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
				return Theme.Chat.Window.BackgroundTransparency + (1 - use(actionButtonAlpha)) * (1 - Theme.Chat.Window.BackgroundTransparency)
			end),
			Text = "CLOSE",
			TextColor3 = CLOSE_TEXT_COLOR,
			TextTransparency = scope:Computed(function(use: FusionUseFn)
				return 1 - use(actionButtonAlpha)
			end),
			TextSize = 14,
			Font = Theme.Text.Bold,
			AutoButtonColor = false,
			LayoutOrder = 1,
			ZIndex = 5,

			[Fusion.OnEvent("Activated")] = function()
				if isClosing then
					return
				end
				isClosing = true
				props.OnClose()
			end,

			[Fusion.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
				scope:New("UIStroke")({
					Color = CLOSE_STROKE_COLOR,
					Thickness = 1.5,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Transparency = scope:Computed(function(use: FusionUseFn)
						local a = use(actionButtonAlpha)
						if a < 0.05 then
							return 1
						end
						return 0.2 + (1 - a) * 0.8
					end),
				}),
			},
		})
	end

	return scope:New("Frame")({
		Name = "PostGameLeaderboard",
		Size = UDim2.fromOffset(totalWidth, DESIGN_TOTAL_HEIGHT),
		Position = scope:Computed(function(use: FusionUseFn)
			return UDim2.new(0.5, 0, 0.5, use(containerY) + (TOP_RESERVED - BOTTOM_MARGIN) / 2)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = props.Visible,
		ZIndex = 4,

		[Fusion.Children] = {
			scope:New("UIScale")({ Scale = uiScale }),

			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				Padding = UDim.new(0, MVP_STRIP_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			scope:New("Frame")({
				Name = "MVPStripWrapper",
				Size = UDim2.fromOffset(totalWidth, MVP_STRIP_H),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				[Fusion.Children] = {
					CompactMVPStrip(scope, topPlayers, containerAlpha),
				},
			}),

			scope:New("Frame")({
				Name = "PanelsRow",
				Size = UDim2.fromOffset(totalWidth, PANEL_HEIGHT),
				BackgroundTransparency = 1,
				LayoutOrder = 2,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, PANEL_GAP),
					}),

					FactionLeaderboardPanel(
						scope,
						"Defenders",
						"VULTARIANS",
						VULTAR_ICON,
						DEFENDER_COLOR,
						DEFENDER_HEADER_GRADIENT,
						DEFENDER_HEADER_SHADOW,
						defRows,
						defendersWon,
						containerAlpha
					),
					FactionLeaderboardPanel(
						scope,
						"Hostiles",
						"HOSTILES",
						HOSTILES_ICON,
						HOSTILE_COLOR,
						HOSTILE_HEADER_GRADIENT,
						HOSTILE_HEADER_SHADOW,
						hostRows,
						not defendersWon,
						containerAlpha
					),
				},
			}),

			CreditsStrip(scope, {
				Width = totalWidth,
				Alpha = containerAlpha,
				Balance = props.CreditsBalance or scope:Value(0),
				Earned = props.CreditsEarned or scope:Value(0),
				Reward = props.CreditsReward or scope:Value(nil),
				Purchasable = props.CreditsPurchasable or scope:Value(false),
				OnBalanceClick = props.OnBalanceClick,
			}),

			scope:New("Frame")({
				Name = "ButtonsRow",
				Size = UDim2.fromOffset(totalWidth, 44),
				BackgroundTransparency = 1,
				LayoutOrder = 4,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 12),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					CloseButton(),

					scope:New("TextButton")({
						Name = "MVPButton",
						Size = UDim2.fromOffset(160, 44),
						BackgroundColor3 = Color3.fromRGB(50, 38, 10),
						BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
							return 0.3 + (1 - use(actionButtonAlpha)) * 0.7
						end),
						Text = "VIEW MVPs",
						TextColor3 = MVP_ACCENT,
						TextTransparency = scope:Computed(function(use: FusionUseFn)
							return 1 - use(actionButtonAlpha)
						end),
						TextSize = 14,
						Font = Theme.Text.Bold,
						AutoButtonColor = false,
						LayoutOrder = 2,
						ZIndex = 5,

						[Fusion.OnEvent("Activated")] = function()
							if Fusion.peek(actionButtonAlpha) > 0.5 then
								props.OnOpenMVP()
							end
						end,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
							scope:New("UIStroke")({
								Color = MVP_ACCENT,
								Thickness = 1.5,
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Transparency = scope:Computed(function(use: FusionUseFn)
									local a = use(actionButtonAlpha)
									if a < 0.05 then
										return 1
									end
									return 0.25 + (1 - a) * 0.75
								end),
							}),
						},
					}),
				},
			}),
		},
	})
end

return PostGameLeaderboard
