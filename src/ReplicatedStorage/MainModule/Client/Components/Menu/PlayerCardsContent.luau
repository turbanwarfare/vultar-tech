--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CosmeticConfig = require(MainModule.Shared.Config.Cosmetics)
local Network = require(MainModule.Shared.Network)
local AnimatedCardService = require(MainModule.Client.Services.AnimatedCardService)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionValue<T> = Types.FusionValue<T>

export type PlayerCardsContentProps = {
	OwnedItems: FusionValue<{ [string]: boolean }>?,
	EquippedItems: FusionValue<{ [string]: any }>?,
}

local LIST_WIDTH = 300
local CARD_HEIGHT = 58
local CARD_GAP = 4
local LIST_PADDING = 4
local ACCENT_COLOR = Color3.fromRGB(65, 145, 255)
local ACCENT_WIDTH = 4

local KILL_CARD_HEIGHT = 100
local KILL_CARD_AVATAR_SIZE = KILL_CARD_HEIGHT
local KILL_CARD_BG = Color3.fromRGB(18, 18, 18)
local KILL_CARD_BORDER = Color3.fromRGB(200, 200, 210)
local DEFAULT_CARD_GRADIENT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.6, 0),
	NumberSequenceKeypoint.new(1, 0.7),
})

local CARD_PREVIEW_GRADIENT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.45, 0.3),
	NumberSequenceKeypoint.new(0.75, 0.8),
	NumberSequenceKeypoint.new(1, 1),
})

local LARGE_CARD_GRADIENT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.6, 0),
	NumberSequenceKeypoint.new(1, 1),
})

local BANNER_TRANSPARENCY = 0.35

local LB_ROW_HEIGHT = 34
local LB_USERNAME_END = 0.38
local LB_STAT_WIDTH = 0.155
local LB_STAT_START = LB_USERNAME_END
local LB_CORNER_RADIUS = 6
local LB_LOCAL_COLOR = Color3.fromRGB(219, 182, 87)

local rng = Random.new()

local sessionRandomStats = {
	Kills = rng:NextInteger(1, 150),
	Damage = rng:NextInteger(5000, 17500),
	Heals = rng:NextInteger(2000, 6000),
	Captures = rng:NextInteger(0, 20),
}

local function getCardName(cardItem: CosmeticConfig.ItemConfig): string
	if cardItem.name then
		return cardItem.name
	end
	if cardItem.collection then
		local collection = CosmeticConfig.Collections[cardItem.collection]
		if collection and collection.name then
			return collection.name
		end
		return cardItem.collection
	end
	return cardItem.id
end

local function getCardImageId(cardItem: CosmeticConfig.ItemConfig): string
	if cardItem.imageId and cardItem.imageId ~= "" then
		return cardItem.imageId
	end
	if cardItem.collection then
		local collection = CosmeticConfig.Collections[cardItem.collection]
		if collection and collection.imageId and collection.imageId ~= "" then
			return collection.imageId
		end
	end
	return ""
end

local function getCardTextColor(cardItem: CosmeticConfig.ItemConfig): Color3
	if cardItem.textColor then
		return cardItem.textColor
	end
	if cardItem.collection then
		local collection = CosmeticConfig.Collections[cardItem.collection]
		if collection and collection.textColor then
			return collection.textColor
		end
	end
	return Color3.fromRGB(255, 255, 255)
end

local function isCardAnimated(cardId: string): boolean
	return AnimatedCardService:IsAnimated(cardId)
end

local function createCardBackground(
	scope: FusionScope,
	imageId: any,
	isAnimated: any,
	size: UDim2,
	transparency: number,
	gradientConfig: NumberSequence?,
	cornerRadius: number?
): (Frame, () -> ())
	local registeredContainer: Frame? = nil

	local function cleanup()
		if registeredContainer then
			AnimatedCardService:UnregisterContainer(registeredContainer)
			registeredContainer = nil
		end
	end

	local gradient = gradientConfig or DEFAULT_CARD_GRADIENT

	local radius = cornerRadius or 4

	local container = scope:New("Frame")({
		Name = "CardBackgroundContainer",
		Size = size,
		BackgroundTransparency = 1,
		ClipsDescendants = true,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, radius) }),

			scope:New("ImageLabel")({
				Name = "StaticCardBackground",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = imageId,
				ImageTransparency = transparency,
				ScaleType = Enum.ScaleType.Crop,
				ZIndex = 1,
				Visible = scope:Computed(function(use: FusionUseFn)
					local img = if typeof(imageId) == "string" then imageId else use(imageId :: any)
					local animated = if typeof(isAnimated) == "boolean" then isAnimated else use(isAnimated :: any)
					return img ~= "" and not animated
				end),

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, radius) }),
				},
			}),

			scope:New("CanvasGroup")({
				Name = "AnimatedCardContainer",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				GroupTransparency = 0,
				ZIndex = 1,
				Visible = scope:Computed(function(use: FusionUseFn)
					local img = if typeof(imageId) == "string" then imageId else use(imageId :: any)
					local animated = if typeof(isAnimated) == "boolean" then isAnimated else use(isAnimated :: any)
					return img ~= "" and animated
				end),

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, radius) }),
					scope:New("UIGradient")({
						Transparency = gradient,
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
			}),
		},
	})

	local function updateAnimation()
		local animated = if typeof(isAnimated) == "boolean" then isAnimated else Fusion.peek(isAnimated :: any)
		local img = if typeof(imageId) == "string" then imageId else Fusion.peek(imageId :: any)

		if animated and img ~= "" then
			task.defer(function()
				local animContainer = container:FindFirstChild("AnimatedCardContainer")
				if animContainer and animContainer.Parent then
					if registeredContainer and registeredContainer ~= animContainer then
						AnimatedCardService:UnregisterContainer(registeredContainer)
					end
					AnimatedCardService:RegisterContainer(animContainer :: Frame)
					registeredContainer = animContainer :: Frame
				end
			end)
		elseif registeredContainer then
			AnimatedCardService:UnregisterContainer(registeredContainer)
			registeredContainer = nil
		end
	end

	if typeof(isAnimated) == "table" then
		scope:Observer(isAnimated :: any):onBind(updateAnimation)
	else
		updateAnimation()
	end

	table.insert(scope, cleanup)

	return container :: Frame, cleanup
end

local function createCardListItem(
	scope: FusionScope,
	cardItem: CosmeticConfig.ItemConfig,
	isHovered: FusionValue<boolean>,
	isEquipped: FusionValue<boolean>,
	onHover: () -> (),
	onLeave: () -> (),
	onClick: () -> ()
): Frame
	local imageId = getCardImageId(cardItem)
	local cardName = getCardName(cardItem)
	local textColor = getCardTextColor(cardItem)
	local hasImage = imageId ~= ""

	local isActive = scope:Computed(function(use: FusionUseFn)
		return use(isHovered) or use(isEquipped)
	end)

	local accentWidth = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isEquipped) then
				return ACCENT_WIDTH
			elseif use(isHovered) then
				return ACCENT_WIDTH - 1
			end
			return 0
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local cardScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 1.015 else 1
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local bgTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isEquipped) then
				return 0.88
			elseif use(isHovered) then
				return 0.92
			end
			return 1
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local labelTextColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isActive) then
				return textColor
			end
			return Color3.fromRGB(200, 200, 205)
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local imageTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isEquipped) then
				return 0
			elseif use(isHovered) then
				return 0.05
			end
			return 0.2
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	return scope:New("Frame")({
		Name = cardItem.id,
		Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "AccentBar",
				Size = scope:Computed(function(use: FusionUseFn)
					return UDim2.new(0, use(accentWidth), 1, -8)
				end),
				Position = UDim2.fromOffset(0, 4),
				BackgroundColor3 = ACCENT_COLOR,
				BorderSizePixel = 0,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, 2),
					}),
				},
			}),

			scope:New("CanvasGroup")({
				Name = "CardContainer",
				Size = scope:Computed(function(use: FusionUseFn)
					local scale = use(cardScale)
					return UDim2.new(scale, -12, scale, 0)
				end),
				Position = UDim2.new(0, 10, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = ACCENT_COLOR,
				BackgroundTransparency = bgTransparency,
				ClipsDescendants = true,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, 6),
					}),

					scope:New("ImageLabel")({
						Name = "Stripes",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = Theme.Patterns.DiagonalStripes.Fat,
						ImageColor3 = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								if use(isEquipped) then
									return ACCENT_COLOR
								elseif use(isHovered) then
									return Color3.fromRGB(50, 50, 55)
								end
								return Color3.fromRGB(35, 35, 40)
							end),
							Theme.Spring.Snappy.Speed,
							Theme.Spring.Snappy.Damping
						),
						ImageTransparency = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								if use(isEquipped) then
									return 0.7
								elseif use(isHovered) then
									return 0.85
								end
								return 1
							end),
							Theme.Spring.Snappy.Speed,
							Theme.Spring.Snappy.Damping
						),
						ScaleType = Enum.ScaleType.Tile,
						TileSize = UDim2.fromOffset(48, 48),
						ZIndex = 1,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0, 6),
							}),
						},
					}),

					if hasImage
						then scope:New("ImageLabel")({
							Name = "CardImage",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Image = imageId,
							ScaleType = Enum.ScaleType.Crop,
							ImageTransparency = imageTransparency,
							ZIndex = 2,

							[Fusion.Children] = {
								scope:New("UICorner")({
									CornerRadius = UDim.new(0, 6),
								}),

								scope:New("UIGradient")({
									Transparency = CARD_PREVIEW_GRADIENT,
									Rotation = 0,
								}),
							},
						})
						else nil,

					scope:New("Frame")({
						Name = "ContentRow",
						Size = UDim2.new(1, -20, 1, 0),
						Position = UDim2.fromOffset(10, 0),
						BackgroundTransparency = 1,
						ZIndex = 3,

						[Fusion.Children] = {
							scope:New("TextLabel")({
								Name = "CardName",
								Size = UDim2.new(0.6, 0, 0, 20),
								Position = UDim2.new(1, -6, 0.5, 0),
								AnchorPoint = Vector2.new(1, 0.5),
								BackgroundTransparency = 1,
								Text = string.upper(cardName),
								TextColor3 = labelTextColor,
								TextSize = 13,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Right,
								TextYAlignment = Enum.TextYAlignment.Center,
								TextTruncate = Enum.TextTruncate.AtEnd,

								[Fusion.Children] = {
									scope:New("UIStroke")({
										Color = Color3.fromRGB(0, 0, 0),
										Thickness = 1.5,
										Transparency = scope:Spring(
											scope:Computed(function(use: FusionUseFn)
												return if use(isActive) then 0.3 else 0.5
											end),
											Theme.Spring.Snappy.Speed,
											Theme.Spring.Snappy.Damping
										),
									}),
								},
							}),

							scope:New("Frame")({
								Name = "EquippedBadge",
								Size = UDim2.fromOffset(70, 18),
								Position = UDim2.new(0, 0, 1, -4),
								AnchorPoint = Vector2.new(0, 1),
								BackgroundColor3 = ACCENT_COLOR,
								BackgroundTransparency = scope:Spring(
									scope:Computed(function(use: FusionUseFn)
										return if use(isEquipped) then 0.15 else 1
									end),
									Theme.Spring.Snappy.Speed,
									Theme.Spring.Snappy.Damping
								),
								Visible = isEquipped,

								[Fusion.Children] = {
									scope:New("UICorner")({
										CornerRadius = UDim.new(0, 4),
									}),

									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										VerticalAlignment = Enum.VerticalAlignment.Center,
										HorizontalAlignment = Enum.HorizontalAlignment.Center,
										Padding = UDim.new(0, 4),
									}),

									scope:New("ImageLabel")({
										Name = "CheckIcon",
										Size = UDim2.fromOffset(10, 10),
										BackgroundTransparency = 1,
										Image = "rbxassetid://10709791437",
										ImageColor3 = Color3.fromRGB(255, 255, 255),
									}),

									scope:New("TextLabel")({
										Name = "EquippedText",
										Size = UDim2.new(0, 48, 1, 0),
										BackgroundTransparency = 1,
										Text = "EQUIPPED",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextSize = 9,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
								},
							}),
						},
					}),

					scope:New("TextButton")({
						Name = "Hitbox",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 10,

						[Fusion.OnEvent("MouseEnter")] = onHover,
						[Fusion.OnEvent("MouseLeave")] = onLeave,
						[Fusion.OnEvent("Activated")] = onClick,
					}),
				},
			}),
		},
	})
end

local function PlayerCardsContent(scope: FusionScope, props: PlayerCardsContentProps): Frame
	local hoveredCardId = scope:Value(nil :: string?)

	local initialEquipped = "Default_PlayerCard"
	if props.EquippedItems then
		local equipped = Fusion.peek(props.EquippedItems)
		if equipped and equipped.PlayerCard and equipped.PlayerCard ~= "" then
			initialEquipped = equipped.PlayerCard
		end
	end
	local equippedCardId = scope:Value(initialEquipped)

	if props.EquippedItems then
		scope:Observer(props.EquippedItems):onBind(function()
			local equipped = Fusion.peek(props.EquippedItems)
			if equipped and equipped.PlayerCard and equipped.PlayerCard ~= "" then
				equippedCardId:set(equipped.PlayerCard)
			end
		end)
	end

	local playerCards = CosmeticConfig.getItemsByCategory("PlayerCard")

	local filteredCards = scope:Computed(function(use: FusionUseFn)
		local ownedItems = props.OwnedItems and use(props.OwnedItems)
		local result: { CosmeticConfig.ItemConfig } = {}
		local defaultCard: CosmeticConfig.ItemConfig? = nil

		for _, cardItem in playerCards do
			if cardItem.id == "Default_PlayerCard" then
				defaultCard = cardItem
				continue
			end

			local isOwned = ownedItems and ownedItems[cardItem.id]
			if cardItem.visible == false and not isOwned then
				continue
			end

			if isOwned then
				table.insert(result, cardItem)
			end
		end

		if defaultCard then
			local final = { defaultCard }
			table.move(result, 1, #result, 2, final)
			return final
		end

		return result
	end)

	local previewCardId = scope:Computed(function(use: FusionUseFn)
		return use(hoveredCardId) or use(equippedCardId)
	end)

	local previewImageId = scope:Computed(function(use: FusionUseFn)
		local cardId = use(previewCardId)
		for _, card in playerCards do
			if card.id == cardId then
				return getCardImageId(card)
			end
		end
		return ""
	end)

	local previewCardName = scope:Computed(function(use: FusionUseFn)
		local cardId = use(previewCardId)
		for _, card in playerCards do
			if card.id == cardId then
				return getCardName(card)
			end
		end
		return "Default"
	end)

	local cardCount = scope:Computed(function(use: FusionUseFn)
		return #use(filteredCards)
	end)

	local previewIsAnimated = scope:Computed(function(use: FusionUseFn)
		local cardId = use(previewCardId)
		return isCardAnimated(cardId)
	end)

	local localPlayer = Players.LocalPlayer
	local localPlayerName = string.upper(localPlayer.DisplayName)
	local localPlayerDisplayName = localPlayer.DisplayName
	local localPlayerAvatar = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", localPlayer.UserId)

	return scope:New("Frame")({
		Name = "PlayerCardsContent",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "ListSection",
				Size = UDim2.new(0, LIST_WIDTH, 1, 0),
				Position = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "Header",
						Size = UDim2.new(1, 0, 0, 32),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIPadding")({
								PaddingLeft = UDim.new(0, 4),
							}),

							scope:New("TextLabel")({
								Name = "Title",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = scope:Computed(function(use: FusionUseFn)
									return string.format("MY PLAYER CARDS [%d]", use(cardCount))
								end),
								TextColor3 = Color3.fromRGB(120, 120, 125),
								TextSize = 11,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Bottom,
							}),

							scope:New("Frame")({
								Name = "Underline",
								Size = UDim2.new(0.6, 0, 0, 1),
								Position = UDim2.new(0, 0, 1, 4),
								BackgroundColor3 = Color3.fromRGB(50, 50, 55),
								BorderSizePixel = 0,
							}),
						},
					}),

					scope:New("ScrollingFrame")({
						Name = "CardList",
						Size = UDim2.new(1, 0, 1, -48),
						Position = UDim2.fromOffset(0, 44),
						BackgroundTransparency = 1,
						ScrollBarThickness = 3,
						ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65),
						CanvasSize = UDim2.fromOffset(0, 0),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						ScrollingDirection = Enum.ScrollingDirection.Y,
						BorderSizePixel = 0,
						ClipsDescendants = true,

						[Fusion.Children] = {
							scope:New("UIPadding")({
								PaddingTop = UDim.new(0, LIST_PADDING),
								PaddingLeft = UDim.new(0, LIST_PADDING),
								PaddingRight = UDim.new(0, LIST_PADDING + 8),
								PaddingBottom = UDim.new(0, LIST_PADDING),
							}),

							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, CARD_GAP),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							scope:ForPairs(filteredCards, function(_use, innerScope, index, cardItem)
								local cardId = cardItem.id
								local isHovered = innerScope:Value(false)

								local isEquipped = innerScope:Computed(function(use: FusionUseFn)
									return use(equippedCardId) == cardId
								end)

								local card = createCardListItem(innerScope, cardItem, isHovered, isEquipped, function()
									isHovered:set(true)
									hoveredCardId:set(cardId)
								end, function()
									isHovered:set(false)
									hoveredCardId:set(nil)
								end, function()
									equippedCardId:set(cardId)
									Network.Cosmetic.equip("PlayerCard", cardId)
								end)

								card.LayoutOrder = index

								return index, card
							end),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "PreviewSection",
				Size = UDim2.new(1, -(LIST_WIDTH + 32), 1, 0),
				Position = UDim2.fromOffset(LIST_WIDTH + 32, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "PreviewHeader",
						Size = UDim2.new(1, 0, 0, 48),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("TextLabel")({
								Name = "PreviewTitle",
								Size = UDim2.new(1, 0, 0, 12),
								Position = UDim2.fromOffset(0, 4),
								BackgroundTransparency = 1,
								Text = "PREVIEW",
								TextColor3 = Color3.fromRGB(90, 90, 95),
								TextSize = 10,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),

							scope:New("TextLabel")({
								Name = "CardNameLabel",
								Size = UDim2.new(1, 0, 0, 24),
								Position = UDim2.fromOffset(0, 18),
								BackgroundTransparency = 1,
								Text = scope:Computed(function(use: FusionUseFn)
									return string.upper(use(previewCardName))
								end),
								TextColor3 = Color3.fromRGB(240, 240, 245),
								TextSize = 20,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
						},
					}),

					scope:New("ScrollingFrame")({
						Name = "PreviewContainer",
						Size = UDim2.new(1, 0, 1, -56),
						Position = UDim2.fromOffset(0, 52),
						BackgroundTransparency = 1,
						ScrollBarThickness = 3,
						ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65),
						CanvasSize = UDim2.fromOffset(0, 0),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						ScrollingDirection = Enum.ScrollingDirection.Y,
						BorderSizePixel = 0,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, 24),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							scope:New("UIPadding")({
								PaddingLeft = UDim.new(0, 4),
								PaddingRight = UDim.new(0, 8),
							}),

							scope:New("Frame")({
								Name = "KillCardSection",
								Size = UDim2.fromScale(1, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								LayoutOrder = 1,

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Vertical,
										Padding = UDim.new(0, 8),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),

									scope:New("TextLabel")({
										Name = "SectionLabel",
										Size = UDim2.new(1, 0, 0, 16),
										BackgroundTransparency = 1,
										Text = "KILL CARD",
										TextColor3 = Color3.fromRGB(100, 100, 105),
										TextSize = 11,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
										LayoutOrder = 1,
									}),

									scope:New("CanvasGroup")({
										Name = "KillCard",
										Size = UDim2.new(1, 0, 0, KILL_CARD_HEIGHT),
										BackgroundColor3 = KILL_CARD_BG,
										BackgroundTransparency = 0.15,
										LayoutOrder = 2,

										[Fusion.Children] = {
											scope:New("UICorner")({
												CornerRadius = UDim.new(0, 4),
											}),

											scope:New("UIStroke")({
												Color = KILL_CARD_BORDER,
												Thickness = 1,
												Transparency = 0.55,
											}),

											createCardBackground(
												scope,
												previewImageId,
												previewIsAnimated,
												UDim2.fromScale(1, 1),
												BANNER_TRANSPARENCY,
												DEFAULT_CARD_GRADIENT,
												4
											),

											scope:New("ImageLabel")({
												Name = "Avatar",
												Size = UDim2.fromOffset(KILL_CARD_AVATAR_SIZE, KILL_CARD_AVATAR_SIZE),
												Position = UDim2.fromOffset(0, 0),
												BackgroundTransparency = 1,
												Image = localPlayerAvatar,
												ZIndex = 5,

												[Fusion.Children] = {
													scope:New("UICorner")({
														CornerRadius = UDim.new(0, 4),
													}),
												},
											}),

											scope:New("Frame")({
												Name = "LeftInfo",
												Size = UDim2.fromOffset(180, 44),
												Position = UDim2.fromOffset(KILL_CARD_AVATAR_SIZE + 12, 10),
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
														Size = UDim2.new(1, 0, 0, 30),
														BackgroundTransparency = 1,
														Text = localPlayerName,
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextSize = 26,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Left,
														TextTruncate = Enum.TextTruncate.AtEnd,
														LayoutOrder = 1,
													}),

													scope:New("TextLabel")({
														Name = "HP",
														Size = UDim2.new(1, 0, 0, 16),
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
												Size = UDim2.fromOffset(100, 40),
												Position = UDim2.new(1, -12, 1, -10),
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
														Size = UDim2.new(1, 0, 0, 22),
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
														TextSize = 12,
														Font = Theme.Text.Semibold,
														TextXAlignment = Enum.TextXAlignment.Right,
														LayoutOrder = 2,
													}),
												},
											}),
										},
									}),
								},
							}),

							scope:New("Frame")({
								Name = "LeaderboardSection",
								Size = UDim2.fromScale(1, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								LayoutOrder = 2,

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Vertical,
										Padding = UDim.new(0, 8),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),

									scope:New("TextLabel")({
										Name = "SectionLabel",
										Size = UDim2.new(1, 0, 0, 16),
										BackgroundTransparency = 1,
										Text = "LEADERBOARD",
										TextColor3 = Color3.fromRGB(100, 100, 105),
										TextSize = 11,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
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
												TextColor3 = Color3.fromRGB(100, 100, 105),
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
												TextColor3 = Color3.fromRGB(100, 100, 105),
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
												TextColor3 = Color3.fromRGB(100, 100, 105),
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
												TextColor3 = Color3.fromRGB(100, 100, 105),
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
											createCardBackground(
												scope,
												previewImageId,
												previewIsAnimated,
												UDim2.fromScale(1, 1),
												0.5,
												LARGE_CARD_GRADIENT,
												LB_CORNER_RADIUS
											),

											scope:New("ImageLabel")({
												Name = "Thumbnail",
												Position = UDim2.fromOffset(0, 0),
												Size = UDim2.fromOffset(LB_ROW_HEIGHT, LB_ROW_HEIGHT),
												BackgroundTransparency = 1,
												Image = localPlayerAvatar,
												ZIndex = 2,
											}),

											scope:New("TextLabel")({
												Name = "Username",
												Position = UDim2.new(0, LB_ROW_HEIGHT + 6, 0.5, 0),
												AnchorPoint = Vector2.new(0, 0.5),
												Size = UDim2.new(LB_USERNAME_END, -(LB_ROW_HEIGHT + 12), 0, 18),
												BackgroundTransparency = 1,
												Text = localPlayerDisplayName,
												TextColor3 = LB_LOCAL_COLOR,
												TextScaled = true,
												Font = Theme.Text.Bold,
												TextXAlignment = Enum.TextXAlignment.Left,
												TextYAlignment = Enum.TextYAlignment.Center,
												ZIndex = 2,

												[Fusion.Children] = {
													scope:New("UITextSizeConstraint")({
														MaxTextSize = 16,
														MinTextSize = 10,
													}),
												},
											}),

											scope:New("TextLabel")({
												Name = "Kills",
												Position = UDim2.fromScale(LB_STAT_START, 0.5),
												AnchorPoint = Vector2.new(0, 0.5),
												Size = UDim2.new(LB_STAT_WIDTH, 0, 0, 16),
												BackgroundTransparency = 1,
												Text = tostring(sessionRandomStats.Kills),
												TextColor3 = LB_LOCAL_COLOR,
												TextSize = 15,
												Font = Theme.Text.Bold,
												TextXAlignment = Enum.TextXAlignment.Center,
												ZIndex = 2,
											}),

											scope:New("TextLabel")({
												Name = "Damage",
												Position = UDim2.fromScale(LB_STAT_START + LB_STAT_WIDTH, 0.5),
												AnchorPoint = Vector2.new(0, 0.5),
												Size = UDim2.new(LB_STAT_WIDTH, 0, 0, 16),
												BackgroundTransparency = 1,
												Text = tostring(sessionRandomStats.Damage),
												TextColor3 = LB_LOCAL_COLOR,
												TextSize = 15,
												Font = Theme.Text.Bold,
												TextXAlignment = Enum.TextXAlignment.Center,
												ZIndex = 2,
											}),

											scope:New("TextLabel")({
												Name = "Heals",
												Position = UDim2.fromScale(LB_STAT_START + LB_STAT_WIDTH * 2, 0.5),
												AnchorPoint = Vector2.new(0, 0.5),
												Size = UDim2.new(LB_STAT_WIDTH, 0, 0, 16),
												BackgroundTransparency = 1,
												Text = tostring(sessionRandomStats.Heals),
												TextColor3 = LB_LOCAL_COLOR,
												TextSize = 15,
												Font = Theme.Text.Bold,
												TextXAlignment = Enum.TextXAlignment.Center,
												ZIndex = 2,
											}),

											scope:New("TextLabel")({
												Name = "Captures",
												Position = UDim2.fromScale(LB_STAT_START + LB_STAT_WIDTH * 3, 0.5),
												AnchorPoint = Vector2.new(0, 0.5),
												Size = UDim2.new(LB_STAT_WIDTH, 0, 0, 16),
												BackgroundTransparency = 1,
												Text = tostring(sessionRandomStats.Captures),
												TextColor3 = LB_LOCAL_COLOR,
												TextSize = 15,
												Font = Theme.Text.Bold,
												TextXAlignment = Enum.TextXAlignment.Center,
												ZIndex = 2,
											}),
										},
									}),
								},
							}),
						},
					}),
				},
			}),
		},
	})
end

return PlayerCardsContent
