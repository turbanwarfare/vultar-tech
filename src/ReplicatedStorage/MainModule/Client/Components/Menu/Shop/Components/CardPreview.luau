--!native
--!optimize 2

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local AnimatedCardService = require(MainModule.Client.Services.AnimatedCardService)

local PriceCache = require(script.Parent.Parent.Cache.PriceCache)
local PurchaseRedirectController = require(script.Parent.Parent.PurchaseRedirectController)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionValue<T> = Types.FusionValue<T>

local SEQUENCE_NUM_SEQ_2 = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0), NumberSequenceKeypoint.new(1, 0.7) })
local SEQUENCE_NUM_SEQ = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0), NumberSequenceKeypoint.new(1, 1) })
local COLOR_CLR_SEQ_3 =
	ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 120, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 80, 200)) })
local COLOR_CLR_SEQ_2 = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 140, 220)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 120, 200)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 100, 180)),
})
local COLOR_CLR_SEQ = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 210, 110)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 190, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 160, 70)),
})

local PREVIEW_MAX_WIDTH = 480

local KILL_CARD_HEIGHT = 120
local KILL_CARD_AVATAR_SIZE = 120
local KILL_CARD_BG = Color3.fromRGB(18, 18, 18)
local KILL_CARD_BORDER = Color3.fromRGB(200, 200, 210)
local BANNER_TRANSPARENCY = 0.3

local LB_ROW_HEIGHT = 42
local LB_USERNAME_END = 0.38
local LB_STAT_WIDTH = 0.155
local LB_STAT_START = LB_USERNAME_END
local LB_CORNER_RADIUS = 6
local LB_LOCAL_COLOR = Color3.fromRGB(219, 182, 87)

local rng = Random.new()

local function getPlayerAvatar(userId: number): string
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
end

local function generateRandomStats(): { Kills: number, Damage: number, Heals: number, Captures: number }
	return {
		Kills = rng:NextInteger(1, 150),
		Damage = rng:NextInteger(5000, 17500),
		Heals = rng:NextInteger(2000, 6000),
		Captures = rng:NextInteger(0, 20),
	}
end

local sessionRandomStats = generateRandomStats()

local function createCardBackground(
	scope: FusionScope,
	imageId: string,
	isAnimated: boolean,
	size: UDim2,
	transparency: number,
	gradientConfig: NumberSequence,
	cornerRadius: number
): Frame
	local registeredContainer: Frame? = nil

	local function cleanup()
		if registeredContainer then
			AnimatedCardService:UnregisterContainer(registeredContainer)
			registeredContainer = nil
		end
	end

	local container = scope:New("Frame")({
		Name = "CardBackgroundContainer",
		Size = size,
		BackgroundTransparency = 1,
		ClipsDescendants = true,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, cornerRadius) }),

			if not isAnimated
				then scope:New("ImageLabel")({
					Name = "StaticCardBackground",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Image = imageId,
					ImageTransparency = transparency,
					ScaleType = Enum.ScaleType.Crop,
					ZIndex = 1,

					[Fusion.Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0, cornerRadius) }),
					},
				})
				else nil,

			if isAnimated
				then scope:New("CanvasGroup")({
					Name = "AnimatedCardContainer",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					GroupTransparency = 0,
					ZIndex = 1,

					[Fusion.Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0, cornerRadius) }),
						scope:New("UIGradient")({
							Transparency = gradientConfig,
							Rotation = 0,
						}),

						scope:New("Frame")({
							Name = "ScrollingFrame",
							Position = UDim2.fromScale(0, 0),
							Size = UDim2.fromScale(2, 1),
							BackgroundTransparency = 1,

							[Fusion.Children] = {
								scope:New("ImageLabel")({
									Name = "CardImage1",
									Position = UDim2.fromScale(0, 0),
									Size = UDim2.fromScale(0.5, 1),
									BackgroundTransparency = 1,
									Image = imageId,
									ImageTransparency = transparency,
									ScaleType = Enum.ScaleType.Crop,
									ZIndex = 1,
								}),
								scope:New("ImageLabel")({
									Name = "CardImage2",
									Position = UDim2.fromScale(0.5, 0),
									Size = UDim2.fromScale(0.5, 1),
									BackgroundTransparency = 1,
									Image = imageId,
									ImageTransparency = transparency,
									ScaleType = Enum.ScaleType.Crop,
									ZIndex = 1,
								}),
							},
						}),
					},
				})
				else nil,
		},
	})

	if isAnimated and imageId ~= "" then
		task.defer(function()
			local animContainer = container:FindFirstChild("AnimatedCardContainer")
			if animContainer and animContainer.Parent then
				AnimatedCardService:RegisterContainer(animContainer :: Frame)
				registeredContainer = animContainer :: Frame
			end
		end)
	end

	table.insert(scope, cleanup)

	return container :: Frame
end

local function createKillCard(scope: FusionScope, imageId: string, isAnimated: boolean, playerName: string, playerAvatar: string): Frame
	return scope:New("Frame")({
		Name = "KillCardSection",
		Size = UDim2.fromOffset(PREVIEW_MAX_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),

			scope:New("TextLabel")({
				Name = "SectionLabel",
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				Text = "KILL CARD PREVIEW",
				TextColor3 = Color3.fromRGB(155, 155, 165),
				TextSize = 11,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = 1,
			}),

			scope:New("CanvasGroup")({
				Name = "KillCard",
				Size = UDim2.new(1, 0, 0, KILL_CARD_HEIGHT),
				BackgroundColor3 = KILL_CARD_BG,
				BackgroundTransparency = 0.1,
				LayoutOrder = 2,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 5) }),
					scope:New("UIStroke")({
						Color = KILL_CARD_BORDER,
						Thickness = 1,
						Transparency = 0.5,
					}),

					createCardBackground(scope, imageId, isAnimated, UDim2.fromScale(1, 1), BANNER_TRANSPARENCY, SEQUENCE_NUM_SEQ_2, 5),

					scope:New("ImageLabel")({
						Name = "Avatar",
						Size = UDim2.fromOffset(KILL_CARD_AVATAR_SIZE, KILL_CARD_AVATAR_SIZE),
						Position = UDim2.fromOffset(0, 0),
						BackgroundTransparency = 1,
						Image = playerAvatar,
						ZIndex = 5,
						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 5) }),
						},
					}),

					scope:New("Frame")({
						Name = "LeftInfo",
						Size = UDim2.fromOffset(140, 55),
						Position = UDim2.fromOffset(KILL_CARD_AVATAR_SIZE + 10, 10),
						BackgroundTransparency = 1,
						ZIndex = 5,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								VerticalAlignment = Enum.VerticalAlignment.Top,
								Padding = UDim.new(0, -2),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							scope:New("TextLabel")({
								Name = "PlayerName",
								Size = UDim2.new(1, 0, 0, 32),
								BackgroundTransparency = 1,
								Text = playerName,
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 26,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
								LayoutOrder = 1,
							}),

							scope:New("TextLabel")({
								Name = "HP",
								Size = UDim2.new(1, 0, 0, 18),
								BackgroundTransparency = 1,
								Text = "100 HP",
								TextColor3 = Color3.fromRGB(180, 180, 185),
								TextSize = 14,
								Font = Theme.Text.Semibold,
								TextXAlignment = Enum.TextXAlignment.Left,
								LayoutOrder = 2,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "RightInfo",
						Size = UDim2.fromOffset(90, 45),
						Position = UDim2.new(1, -10, 1, -10),
						AnchorPoint = Vector2.one,
						BackgroundTransparency = 1,
						ZIndex = 5,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								VerticalAlignment = Enum.VerticalAlignment.Bottom,
								HorizontalAlignment = Enum.HorizontalAlignment.Right,
								Padding = UDim.new(0, 0),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							scope:New("TextLabel")({
								Name = "GunName",
								Size = UDim2.new(1, 0, 0, 24),
								BackgroundTransparency = 1,
								Text = "H-82",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 18,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Right,
								LayoutOrder = 1,
							}),

							scope:New("TextLabel")({
								Name = "Range",
								Size = UDim2.new(1, 0, 0, 16),
								BackgroundTransparency = 1,
								Text = "100 STUDS",
								TextColor3 = Color3.fromRGB(140, 140, 145),
								TextSize = 11,
								Font = Theme.Text.Semibold,
								TextXAlignment = Enum.TextXAlignment.Right,
								LayoutOrder = 2,
							}),
						},
					}),
				},
			}),
		},
	})
end

local function createLeaderboardRow(scope: FusionScope, imageId: string, isAnimated: boolean, playerDisplayName: string, playerAvatar: string): Frame
	return scope:New("Frame")({
		Name = "LeaderboardSection",
		Size = UDim2.fromOffset(PREVIEW_MAX_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),

			scope:New("TextLabel")({
				Name = "SectionLabel",
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				Text = "LEADERBOARD PREVIEW",
				TextColor3 = Color3.fromRGB(155, 155, 165),
				TextSize = 11,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = 1,
			}),

			scope:New("Frame")({
				Name = "ColumnHeaders",
				Size = UDim2.new(1, 0, 0, 14),
				BackgroundTransparency = 1,
				LayoutOrder = 2,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "KillsHeader",
						Position = UDim2.fromScale(LB_STAT_START, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.fromScale(LB_STAT_WIDTH, 1),
						BackgroundTransparency = 1,
						Text = "K",
						TextColor3 = Color3.fromRGB(155, 155, 165),
						TextSize = 10,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),

					scope:New("TextLabel")({
						Name = "DamageHeader",
						Position = UDim2.fromScale(LB_STAT_START + LB_STAT_WIDTH, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.fromScale(LB_STAT_WIDTH, 1),
						BackgroundTransparency = 1,
						Text = "DMG",
						TextColor3 = Color3.fromRGB(155, 155, 165),
						TextSize = 10,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),

					scope:New("TextLabel")({
						Name = "HealsHeader",
						Position = UDim2.fromScale(LB_STAT_START + LB_STAT_WIDTH * 2, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.fromScale(LB_STAT_WIDTH, 1),
						BackgroundTransparency = 1,
						Text = "HEALS",
						TextColor3 = Color3.fromRGB(155, 155, 165),
						TextSize = 10,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),

					scope:New("TextLabel")({
						Name = "CapsHeader",
						Position = UDim2.fromScale(LB_STAT_START + LB_STAT_WIDTH * 3, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.fromScale(LB_STAT_WIDTH, 1),
						BackgroundTransparency = 1,
						Text = "CAPS",
						TextColor3 = Color3.fromRGB(155, 155, 165),
						TextSize = 10,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "PlayerRow",
				Size = UDim2.new(1, 0, 0, LB_ROW_HEIGHT),
				BackgroundTransparency = 1,
				LayoutOrder = 3,

				[Fusion.Children] = {
					createCardBackground(scope, imageId, isAnimated, UDim2.fromScale(1, 1), 0.45, SEQUENCE_NUM_SEQ, LB_CORNER_RADIUS),

					scope:New("ImageLabel")({
						Name = "Thumbnail",
						Position = UDim2.fromOffset(0, 0),
						Size = UDim2.fromOffset(LB_ROW_HEIGHT, LB_ROW_HEIGHT),
						BackgroundTransparency = 1,
						Image = playerAvatar,
						ZIndex = 2,
					}),

					scope:New("TextLabel")({
						Name = "Username",
						Position = UDim2.new(0, LB_ROW_HEIGHT + 8, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.new(LB_USERNAME_END, -(LB_ROW_HEIGHT + 12), 0, 18),
						BackgroundTransparency = 1,
						Text = playerDisplayName,
						TextColor3 = LB_LOCAL_COLOR,
						TextScaled = true,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
						ZIndex = 2,

						[Fusion.Children] = {
							scope:New("UITextSizeConstraint")({
								MaxTextSize = 14,
								MinTextSize = 9,
							}),
						},
					}),

					scope:New("TextLabel")({
						Name = "Kills",
						Position = UDim2.fromScale(LB_STAT_START, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.new(LB_STAT_WIDTH, 0, 0, 14),
						BackgroundTransparency = 1,
						Text = tostring(sessionRandomStats.Kills),
						TextColor3 = LB_LOCAL_COLOR,
						TextSize = 13,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						ZIndex = 2,
					}),

					scope:New("TextLabel")({
						Name = "Damage",
						Position = UDim2.fromScale(LB_STAT_START + LB_STAT_WIDTH, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.new(LB_STAT_WIDTH, 0, 0, 14),
						BackgroundTransparency = 1,
						Text = tostring(sessionRandomStats.Damage),
						TextColor3 = LB_LOCAL_COLOR,
						TextSize = 13,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						ZIndex = 2,
					}),

					scope:New("TextLabel")({
						Name = "Heals",
						Position = UDim2.fromScale(LB_STAT_START + LB_STAT_WIDTH * 2, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.new(LB_STAT_WIDTH, 0, 0, 14),
						BackgroundTransparency = 1,
						Text = tostring(sessionRandomStats.Heals),
						TextColor3 = LB_LOCAL_COLOR,
						TextSize = 13,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						ZIndex = 2,
					}),

					scope:New("TextLabel")({
						Name = "Captures",
						Position = UDim2.fromScale(LB_STAT_START + LB_STAT_WIDTH * 3, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.new(LB_STAT_WIDTH, 0, 0, 14),
						BackgroundTransparency = 1,
						Text = tostring(sessionRandomStats.Captures),
						TextColor3 = LB_LOCAL_COLOR,
						TextSize = 13,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						ZIndex = 2,
					}),
				},
			}),
		},
	})
end

export type CardPreviewProps = {
	CardId: string,
	CardName: string,
	ImageId: string,
	GamepassId: number,
	IsAnimated: boolean,
	OnBack: () -> (),
}

local function CardPreview(scope: FusionScope, props: CardPreviewProps): Frame
	local isButtonHovered = scope:Value(false)
	local price = scope:Value(0)

	PriceCache.getPriceAsync(props.GamepassId, price)

	local buttonScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isButtonHovered) then 1.02 else 1
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local priceText = scope:Computed(function(use: FusionUseFn)
		local p = use(price)
		if p == -1 then
			return "OWNED"
		elseif p > 0 then
			return tostring(p) .. " R$"
		else
			return "..."
		end
	end)

	local function promptPurchase()
		PurchaseRedirectController.promptPurchase(props.GamepassId)
	end

	local localPlayer = LocalPlayer
	local playerName = string.upper(localPlayer.DisplayName)
	local playerDisplayName = localPlayer.DisplayName
	local playerAvatar = getPlayerAvatar(localPlayer.UserId)

	return scope:New("Frame")({
		Name = "CardPreview",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 100),
				Position = UDim2.new(0.5, 0, 0, 20),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "CardName",
						Size = UDim2.new(1, 0, 0, 50),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Text = string.upper(props.CardName),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 42,
						Font = Enum.Font.GothamBlack,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),

					scope:New("TextLabel")({
						Name = "Price",
						Size = UDim2.new(1, 0, 0, 32),
						Position = UDim2.new(0.5, 0, 0, 52),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Text = priceText,
						TextColor3 = Color3.fromRGB(0, 200, 100),
						TextSize = 26,
						Font = Enum.Font.GothamBold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				},
			}),

			scope:New("ScrollingFrame")({
				Name = "ContentContainer",
				Size = UDim2.new(1, 0, 1, -210),
				Position = UDim2.fromOffset(0, 130),
				BackgroundTransparency = 1,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Color3.fromRGB(150, 150, 160),
				ScrollBarImageTransparency = 0.5,
				CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				BorderSizePixel = 0,

				[Fusion.Children] = {
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, 10),
						PaddingBottom = UDim.new(0, 10),
					}),

					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 24),
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					}),

					createKillCard(scope, props.ImageId, props.IsAnimated, playerName, playerAvatar),
					createLeaderboardRow(scope, props.ImageId, props.IsAnimated, playerDisplayName, playerAvatar),

					if props.IsAnimated
						then scope:New("Frame")({
							Name = "AnimatedBadgeContainer",
							Size = UDim2.fromOffset(PREVIEW_MAX_WIDTH, 32),
							BackgroundTransparency = 1,
							LayoutOrder = 3,

							[Fusion.Children] = {
								scope:New("Frame")({
									Name = "AnimatedBadge",
									Size = UDim2.fromOffset(110, 24),
									Position = UDim2.fromScale(0.5, 0.5),
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundColor3 = Color3.fromRGB(180, 100, 220),
									BorderSizePixel = 0,

									[Fusion.Children] = {
										scope:New("UICorner")({ CornerRadius = UDim.new(0, 5) }),
										scope:New("UIGradient")({
											Color = COLOR_CLR_SEQ_3,
											Rotation = 90,
										}),
										scope:New("TextLabel")({
											Size = UDim2.fromScale(1, 1),
											BackgroundTransparency = 1,
											Text = "ANIMATED CARD",
											TextColor3 = Color3.fromRGB(255, 255, 255),
											TextSize = 10,
											Font = Enum.Font.GothamBold,
										}),
									},
								}),
							},
						})
						else nil,
				},
			}),

			scope:New("Frame")({
				Name = "Footer",
				Size = UDim2.fromOffset(480, 70),
				Position = UDim2.new(0.5, 0, 1, -70),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("TextButton")({
						Name = "BackButton",
						Size = UDim2.fromOffset(140, 50),
						Position = UDim2.fromScale(0, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundColor3 = Color3.fromRGB(50, 120, 200),
						Text = "",

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
							scope:New("UIStroke")({
								Color = Color3.fromRGB(80, 150, 230),
								Thickness = 2,
								Transparency = 0.2,
							}),

							scope:New("UIGradient")({
								Color = COLOR_CLR_SEQ_2,
								Rotation = 90,
							}),

							scope:New("TextLabel")({
								Name = "Label",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = "< BACK",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 18,
								Font = Enum.Font.GothamBold,
							}),
						},

						[Fusion.OnEvent("Activated")] = props.OnBack,
					}),

					scope:New("Frame")({
						Name = "ButtonContainer",
						Size = UDim2.fromOffset(320, 50),
						Position = UDim2.fromScale(1, 0.5),
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIScale")({ Scale = buttonScale }),

							scope:New("TextButton")({
								Name = "PurchaseButton",
								Size = UDim2.fromScale(1, 1),
								BackgroundColor3 = Color3.fromRGB(45, 180, 80),
								Text = "",

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
									scope:New("UIStroke")({
										Color = Color3.fromRGB(80, 220, 120),
										Thickness = 2,
										Transparency = 0.2,
									}),

									scope:New("UIGradient")({
										Color = COLOR_CLR_SEQ,
										Rotation = 90,
									}),

									scope:New("TextLabel")({
										Name = "ButtonText",
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = "PURCHASE CARD",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextSize = 18,
										Font = Enum.Font.GothamBlack,
									}),
								},

								[Fusion.OnEvent("MouseEnter")] = function()
									isButtonHovered:set(true)
								end,
								[Fusion.OnEvent("MouseLeave")] = function()
									isButtonHovered:set(false)
								end,
								[Fusion.OnEvent("Activated")] = promptPurchase,
							}),
						},
					}),
				},
			}),
		},
	})
end

return CardPreview
