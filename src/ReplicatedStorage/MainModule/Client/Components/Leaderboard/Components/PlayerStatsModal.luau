--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Constants = require(MainModule.Shared.Config.Constants)
local Theme = require(MainModule.Shared.UI.Theme)
local Network = require(MainModule.Shared.Network)
local Shadow = require(MainModule.Client.Components.Shadow)
local AnimatedCardService = require(MainModule.Client.Services.AnimatedCardService)

local CARD_GRADIENT_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.85, 1),
	NumberSequenceKeypoint.new(1, 1),
})

local LeaderboardConstants = require(script.Parent.Parent.Constants)

local Types = require(script.Parent.Parent.Types)
type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>

export type StatCardProps = {
	UserId: FusionCanBeState<number?>,
	CardImageId: FusionCanBeState<string?>,
	IsAnimatedCard: FusionCanBeState<boolean>,
	GroupTransparency: FusionCanBeState<number>?,
}

local CARD_GAP = 6
local PADDING_Y = 14
local USERNAME_HEIGHT = 30
local USERNAME_GAP = 10
local STAT_ROW_HEIGHT = 50
local STAT_GAP = 8
local AVATAR_SIZE = STAT_ROW_HEIGHT * 2 + STAT_GAP
local AVATAR_STATS_GAP = 12
local STAT_CELL_RADIUS = 6

local ICON_SIZE = 28
local USERNAME_ICON_GAP = 5

local ROW1_CELL_WIDTH = 160
local ROW2_CELL_WIDTH = 216
local STATS_WIDTH = 4 * ROW1_CELL_WIDTH + 3 * STAT_GAP
local PADDING_X = 20
local CONTENT_WIDTH = AVATAR_SIZE + AVATAR_STATS_GAP + STATS_WIDTH
local CONTENT_HEIGHT = USERNAME_HEIGHT + USERNAME_GAP + AVATAR_SIZE
local CARD_WIDTH = CONTENT_WIDTH + PADDING_X * 2
local CARD_HEIGHT = PADDING_Y + CONTENT_HEIGHT + PADDING_Y

local SHADOW_SPREAD = 6
local SHADOW_OFFSET_Y = 2
local SHADOW_TRANSPARENCY = 0.65

local TITLE_COLOR = Color3.fromRGB(191, 194, 197)

local VULTAR_GROUP_ID = Constants.GROUPS.VULTAR
local DREADTROOPERS_GROUP_ID = Constants.GROUPS.DREADTROOPERS

local CHANNEL_ICON_CONFIG = {
	{
		id = "HICOM",
		icon = "rbxassetid://85345278524858",
		order = 1,
		check = function(vultarRank: number, _dtRank: number, _playerId: number)
			return vultarRank >= 200
		end,
	},
	{
		id = "OFFICER",
		icon = "rbxassetid://105485886032455",
		order = 2,
		check = function(vultarRank: number, _dtRank: number, _playerId: number)
			return vultarRank >= 80
		end,
	},
	{
		id = "DREAD",
		icon = "rbxassetid://105801552657804",
		order = 3,
		size = Vector2.new(35, 28),
		check = function(_vultarRank: number, dtRank: number, _playerId: number)
			return dtRank > 0
		end,
	},
}

local function StatCard(scope: FusionScope, props: StatCardProps): CanvasGroup
	local userId = props.UserId
	local cardImageId = props.CardImageId
	local isAnimatedCard = props.IsAnimatedCard

	local isVisible = scope:Computed(function(use)
		return use(userId) ~= nil
	end)

	local displayName = scope:Value("")
	local channelIcons = scope:Value({} :: { [string]: { icon: string, size: Vector2?, order: number } })

	local globalStats = scope:Value({
		Kills = 0,
		Damage = 0,
		Heals = 0,
		Caps = 0,
		GamesPlayed = 0,
		GamesWon = 0,
		MVP = 0,
	})

	local isLoading = scope:Value(true)

	local animatedContainer: CanvasGroup? = nil

	local function updateAnimationState()
		local id = Fusion.peek(userId)
		local animated = Fusion.peek(isAnimatedCard)
		if animatedContainer then
			AnimatedCardService:UnregisterContainer(animatedContainer)
		end
		if id and animated and animatedContainer then
			task.spawn(function()
				task.wait()
				if animatedContainer and (animatedContainer :: Instance).Parent then
					AnimatedCardService:RegisterContainer(animatedContainer :: Frame, id)
				end
			end)
		end
	end

	scope:Observer(isAnimatedCard):onChange(updateAnimationState)

	scope:Observer(userId):onBind(function()
		local id = Fusion.peek(userId)
		if not id then
			isLoading:set(false)
			channelIcons:set({})
			return
		end

		isLoading:set(true)
		updateAnimationState()

		task.spawn(function()
			local player = Players:GetPlayerByUserId(id)
			displayName:set(if player then player.Name else "Unknown")

			local stats = Network.GlobalStats.getPlayerGlobalStats(id)
			if stats then
				globalStats:set(stats)
			else
				globalStats:set({
					Kills = 0,
					Damage = 0,
					Heals = 0,
					Caps = 0,
					GamesPlayed = 0,
					GamesWon = 0,
					MVP = 0,
				})
			end

			local icons: { [string]: { icon: string, size: Vector2?, order: number } } = {}
			if player and player:IsDescendantOf(game) then
				local ok1, vultarRank = pcall(player.GetRankInGroup, player, VULTAR_GROUP_ID)
				local ok2, dtRank = pcall(player.GetRankInGroup, player, DREADTROOPERS_GROUP_ID)

				if ok1 and ok2 then
					for _, config in CHANNEL_ICON_CONFIG do
						if config.check(vultarRank, dtRank, id) then
							icons[config.id] = { icon = config.icon, size = config.size, order = config.order }
						end
					end
				end
			end
			channelIcons:set(icons)

			isLoading:set(false)
		end)
	end)

	local function createStatCell(statKey: string, label: string, width: number, layoutOrder: number): Frame
		local value = scope:Computed(function(use)
			local stats = use(globalStats)
			return (stats :: any)[statKey] or 0
		end)

		return scope:New("Frame")({
			Name = statKey,
			Size = UDim2.new(0, width, 1, 0),
			BackgroundColor3 = Theme.Colors.Black[800],
			BackgroundTransparency = 0.5,
			LayoutOrder = layoutOrder,

			[Fusion.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, STAT_CELL_RADIUS) }),

				scope:New("TextLabel")({
					Name = "Label",
					Position = UDim2.new(0.5, 0, 0, 6),
					AnchorPoint = Vector2.new(0.5, 0),
					Size = UDim2.new(1, -8, 0, 14),
					BackgroundTransparency = 1,
					Text = label,
					TextColor3 = Theme.Colors.Black[200],
					TextSize = 11,
					Font = LeaderboardConstants.Font.Label,
					TextXAlignment = Enum.TextXAlignment.Center,
				}),

				scope:New("TextLabel")({
					Name = "Value",
					Position = UDim2.fromScale(0.5, 0.62),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.new(1, -8, 0, 24),
					BackgroundTransparency = 1,
					Text = value,
					TextColor3 = Theme.Colors.White,
					TextSize = 20,
					Font = LeaderboardConstants.Font.Bold,
					TextXAlignment = Enum.TextXAlignment.Center,
				}),
			},
		})
	end

	local statsOffsetX = AVATAR_SIZE + AVATAR_STATS_GAP
	local statsOffsetY = USERNAME_HEIGHT + USERNAME_GAP

	local cardGradientKeys = CARD_GRADIENT_TRANSPARENCY

	local hasStaticCard = scope:Computed(function(use)
		local img = use(cardImageId)
		local animated = use(isAnimatedCard)
		return img ~= nil and img ~= "" and not animated
	end)

	local hasAnimatedCard = scope:Computed(function(use)
		local img = use(cardImageId)
		local animated = use(isAnimatedCard)
		return img ~= nil and img ~= "" and animated
	end)

	local animatedCanvasGroup = scope:New("CanvasGroup")({
		Name = "AnimatedCardContainer",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 0,
		Visible = hasAnimatedCard,
		ZIndex = 1,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, LeaderboardConstants.CORNER_RADIUS) }),

			scope:New("UIGradient")({
				Transparency = cardGradientKeys,
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
						Image = scope:Computed(function(use)
							return use(cardImageId) or ""
						end),
						ImageTransparency = 0.5,
						ScaleType = Enum.ScaleType.Crop,
						ZIndex = 1,
					}),
					scope:New("ImageLabel")({
						Name = "CardImage2",
						Position = UDim2.fromScale(0.5, 0),
						Size = UDim2.fromScale(0.5, 1),
						BackgroundTransparency = 1,
						Image = scope:Computed(function(use)
							return use(cardImageId) or ""
						end),
						ImageTransparency = 0.5,
						ScaleType = Enum.ScaleType.Crop,
						ZIndex = 1,
					}),
				},
			}),
		},
	})

	animatedContainer = animatedCanvasGroup :: any

	return scope:New("CanvasGroup")({
		Name = "StatCardWrapper",
		Position = UDim2.new(0.5, 0, 1, CARD_GAP - SHADOW_SPREAD),
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(CARD_WIDTH + SHADOW_SPREAD * 2, CARD_HEIGHT + SHADOW_SPREAD * 2),
		BackgroundTransparency = 1,
		GroupTransparency = props.GroupTransparency or 0,
		Visible = isVisible,
		ZIndex = 2,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "ClickBlocker",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 50,
			}),

			Shadow(scope, {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = 0,
				Transparency = SHADOW_TRANSPARENCY,
				ZIndex = 0,
			}),

			scope:New("Frame")({
				Name = "StatCard",
				Position = UDim2.fromOffset(SHADOW_SPREAD, SHADOW_SPREAD),
				Size = UDim2.new(1, -SHADOW_SPREAD * 2, 1, -SHADOW_SPREAD * 2),
				BackgroundColor3 = LeaderboardConstants.Colors.PanelBackground,
				BackgroundTransparency = LeaderboardConstants.LIST_BG_TRANSPARENCY,
				ClipsDescendants = true,
				ZIndex = 1,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, LeaderboardConstants.CORNER_RADIUS) }),
					scope:New("UIStroke")({
						Color = Theme.Border.Default,
						Thickness = LeaderboardConstants.BORDER_THICKNESS,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),

					scope:New("ImageLabel")({
						Name = "StaticCardBackground",
						Position = UDim2.fromOffset(0, 0),
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Visible = hasStaticCard,
						Image = scope:Computed(function(use)
							return use(cardImageId) or ""
						end),
						ImageTransparency = scope:Computed(function(use)
							local img = use(cardImageId)
							return if img == nil or img == "" then 0.5 else 0
						end),
						ScaleType = Enum.ScaleType.Crop,
						ZIndex = 1,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, LeaderboardConstants.CORNER_RADIUS) }),
						},
					}),

					animatedCanvasGroup,

					scope:New("Frame")({
						Name = "Content",
						Position = UDim2.new(0.5, 0, 0, PADDING_Y),
						AnchorPoint = Vector2.new(0.5, 0),
						Size = UDim2.fromOffset(CONTENT_WIDTH, CONTENT_HEIGHT),
						BackgroundTransparency = 1,
						ZIndex = 2,

						[Fusion.Children] = {
							scope:New("Frame")({
								Name = "UsernameRow",
								Position = UDim2.fromOffset(0, 0),
								Size = UDim2.fromOffset(CONTENT_WIDTH, USERNAME_HEIGHT),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										VerticalAlignment = Enum.VerticalAlignment.Center,
										Padding = UDim.new(0, USERNAME_ICON_GAP),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),

									scope:New("TextLabel")({
										Name = "DisplayName",
										AutomaticSize = Enum.AutomaticSize.X,
										Size = UDim2.fromScale(0, 1),
										BackgroundTransparency = 1,
										Text = displayName,
										TextColor3 = TITLE_COLOR,
										TextSize = 24,
										Font = LeaderboardConstants.Font.Title,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Center,
										LayoutOrder = 1,
									}),

									scope:ForPairs(channelIcons, function(_use: any, iconScope: any, iconId: string, iconData: any)
										local iconSize = iconData.size or Vector2.new(ICON_SIZE, ICON_SIZE)
										return iconId,
											iconScope:New("ImageLabel")({
												Name = iconId,
												Size = UDim2.fromOffset(iconSize.X, iconSize.Y),
												BackgroundTransparency = 1,
												Image = iconData.icon,
												ImageColor3 = Color3.fromRGB(255, 255, 255),
												ScaleType = Enum.ScaleType.Fit,
												LayoutOrder = 1 + iconData.order,
											})
									end),
								},
							}),

							scope:New("ImageLabel")({
								Name = "Headshot",
								Position = UDim2.fromOffset(0, statsOffsetY),
								Size = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE),
								BackgroundColor3 = Theme.Colors.Black[800],
								BackgroundTransparency = 0.5,
								Image = scope:Computed(function(use)
									local id = use(userId)
									if id then
										return "rbxthumb://type=AvatarHeadShot&id=" .. id .. "&w=150&h=150"
									end
									return ""
								end),

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, STAT_CELL_RADIUS) }),
								},
							}),

							scope:New("Frame")({
								Name = "StatsRow1",
								Position = UDim2.fromOffset(statsOffsetX, statsOffsetY),
								Size = UDim2.fromOffset(STATS_WIDTH, STAT_ROW_HEIGHT),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Left,
										Padding = UDim.new(0, STAT_GAP),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),

									createStatCell("Kills", "KILLS", ROW1_CELL_WIDTH, 1),
									createStatCell("Damage", "DAMAGE", ROW1_CELL_WIDTH, 2),
									createStatCell("Heals", "HEALS", ROW1_CELL_WIDTH, 3),
									createStatCell("Caps", "CAPTURES", ROW1_CELL_WIDTH, 4),
								},
							}),

							scope:New("Frame")({
								Name = "StatsRow2",
								Position = UDim2.fromOffset(statsOffsetX, statsOffsetY + STAT_ROW_HEIGHT + STAT_GAP),
								Size = UDim2.fromOffset(STATS_WIDTH, STAT_ROW_HEIGHT),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Left,
										Padding = UDim.new(0, STAT_GAP),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),

									createStatCell("GamesPlayed", "GAMES PLAYED", ROW2_CELL_WIDTH, 1),
									createStatCell("GamesWon", "WINS", ROW2_CELL_WIDTH, 2),
									createStatCell("MVP", "MVP", ROW2_CELL_WIDTH, 3),
								},
							}),
						},
					}),

					scope:New("Frame")({
						Name = "LoadingOverlay",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = LeaderboardConstants.Colors.PanelBackground,
						BackgroundTransparency = scope:Computed(function(use)
							return if use(isLoading) then LeaderboardConstants.LIST_BG_TRANSPARENCY else 1
						end),
						Visible = isLoading,
						ZIndex = 10,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, LeaderboardConstants.CORNER_RADIUS) }),

							scope:New("TextLabel")({
								Position = UDim2.fromScale(0.5, 0.5),
								AnchorPoint = Vector2.new(0.5, 0.5),
								Size = UDim2.new(0.6, 0, 0, 18),
								BackgroundTransparency = 1,
								Text = "Loading...",
								TextColor3 = Theme.Colors.Black[300],
								TextSize = 14,
								Font = LeaderboardConstants.Font.Label,
							}),
						},
					}),
				},
			}),
		},
	})
end

return StatCard
