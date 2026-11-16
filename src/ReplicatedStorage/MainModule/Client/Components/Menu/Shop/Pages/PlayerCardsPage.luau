--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)

local PlayerCardsConfig = require(MainModule.Shared.Config.Cosmetics.Items.PlayerCards)
local Collections = require(MainModule.Shared.Config.Cosmetics.Collections)
local PlayerCardCard = require(script.Parent.Parent.Components.PlayerCardCard)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

local camera = workspace.CurrentCamera

local CARD_BASE_HEIGHT = 130
local GRID_GAP = 16
local SECTION_GAP = 40
local HEADER_HEIGHT = 38

local function getCardsPerRow(): number
	if not camera then return 3 end
	local width = camera.ViewportSize.X
	if width < 1400 then return 2 end
	if width < 1900 then return 3 end
	return 4
end

local function getScaledCardHeight(): number
	if not camera then return CARD_BASE_HEIGHT end
	local height = camera.ViewportSize.Y
	local scale = math.clamp((height - 600) / 500, 0.9, 1.2)
	return math.floor(CARD_BASE_HEIGHT * scale)
end

type CardData = {
	id: string,
	name: string,
	collection: string,
	imageId: string,
	gamepassId: number,
	season: string,
	isAnimated: boolean,
}

local function getVisibleCards(): { CardData }
	local cards: { CardData } = {}

	for _, cardConfig in PlayerCardsConfig do
		local isVisible = cardConfig.visible ~= false
		local hasPurchaseGamepass = cardConfig.purchaseGamepassId and cardConfig.purchaseGamepassId > 0
		local isDefault = cardConfig.id == "Default_PlayerCard"

		if isVisible and hasPurchaseGamepass and not isDefault then
			local collectionKey = cardConfig.collection or cardConfig.id
			local collectionData = Collections[collectionKey]

			if collectionData and collectionData.visible ~= false then
				local displayName = collectionData.name or cardConfig.id
				local season = collectionData.season or "1"
				local imageId = collectionData.imageId or ""
				local isAnimated = collectionData.animated or false

				table.insert(cards, {
					id = cardConfig.id,
					name = displayName,
					collection = collectionKey,
					imageId = imageId,
					gamepassId = cardConfig.purchaseGamepassId,
					season = season,
					isAnimated = isAnimated,
				})
			end
		end
	end

	return cards
end

local function groupCardsBySeason(cards: { CardData }): { [string]: { CardData } }
	local grouped: { [string]: { CardData } } = {}

	for _, card in cards do
		local season = card.season
		if not grouped[season] then
			grouped[season] = {}
		end
		table.insert(grouped[season], card)
	end

	return grouped
end

local SEASON_ORDER = { "4", "3", "2", "1" }
local SEASON_LABELS = {
	["4"] = "LATEST RELEASE",
	["3"] = "SEASON 3",
	["2"] = "SEASON 2",
	["1"] = "SEASON 1",
}

local function createSeasonHeader(scope: FusionScope, label: string): Frame
	return scope:New("Frame")({
		Name = "SeasonHeader_" .. label,
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("TextLabel")({
				Name = "Label",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = label,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 16,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		},
	})
end

type CardClickData = {
	id: string,
	name: string,
	imageId: string,
	gamepassId: number,
	isAnimated: boolean,
}

export type PlayerCardsPageProps = {
	Padding: Types.FusionValue<number>,
	OnCardClick: ((card: CardClickData) -> ())?,
}

local PlayerCardsPage = {}

function PlayerCardsPage.create(scope: FusionScope, props: PlayerCardsPageProps): Frame
	local allCards = getVisibleCards()
	local groupedCards = groupCardsBySeason(allCards)

	local cardsPerRow = getCardsPerRow()
	local cardHeight = getScaledCardHeight()

	local scrollContentChildren: { Instance } = {}

	table.insert(scrollContentChildren, scope:New("UIPadding")({
		PaddingLeft = scope:Computed(function(use: FusionUseFn)
			return UDim.new(0, use(props.Padding))
		end),
		PaddingRight = scope:Computed(function(use: FusionUseFn)
			return UDim.new(0, use(props.Padding))
		end),
		PaddingTop = UDim.new(0, 24),
		PaddingBottom = UDim.new(0, 50),
	}))

	table.insert(scrollContentChildren, scope:New("UIListLayout")({
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, SECTION_GAP),
	}))

	local layoutOrder = 0
	for _, seasonKey in SEASON_ORDER do
		local seasonCards = groupedCards[seasonKey]
		if seasonCards and #seasonCards > 0 then
			local seasonLabel = SEASON_LABELS[seasonKey] or ("SEASON " .. seasonKey)

			local sectionChildren: { Instance } = {}

			table.insert(sectionChildren, scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 14),
			}))

			local headerFrame = createSeasonHeader(scope, seasonLabel)
			headerFrame.LayoutOrder = 0
			table.insert(sectionChildren, headerFrame)

			local gridChildren: { Instance } = {}

			table.insert(gridChildren, scope:New("UIGridLayout")({
				CellSize = UDim2.new(1 / cardsPerRow, -GRID_GAP * (cardsPerRow - 1) / cardsPerRow, 0, cardHeight),
				CellPadding = UDim2.fromOffset(GRID_GAP, GRID_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
			}))

			for cardIndex, card in seasonCards do
				local cardComponent = PlayerCardCard(scope, {
					CardId = card.id,
					CardName = card.name,
					ImageId = card.imageId,
					GamepassId = card.gamepassId,
					LayoutOrder = cardIndex,
					IsAnimated = card.isAnimated,
					OnClick = function()
						if props.OnCardClick then
							props.OnCardClick({
								id = card.id,
								name = card.name,
								imageId = card.imageId,
								gamepassId = card.gamepassId,
								isAnimated = card.isAnimated,
							})
						end
					end,
				})
				table.insert(gridChildren, cardComponent)
			end

			local gridFrame = scope:New("Frame")({
				Name = "CardGrid",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 1,

				[Fusion.Children] = gridChildren,
			})

			table.insert(sectionChildren, gridFrame)

			local sectionFrame = scope:New("Frame")({
				Name = "Section_" .. seasonKey,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = layoutOrder,

				[Fusion.Children] = sectionChildren,
			})

			table.insert(scrollContentChildren, sectionFrame)
			layoutOrder = layoutOrder + 1
		end
	end

	return scope:New("ScrollingFrame")({
		Name = "PlayerCardsPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Color3.fromRGB(150, 150, 160),
		ScrollBarImageTransparency = 0.5,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,

		[Fusion.Children] = scrollContentChildren,
	})
end

return PlayerCardsPage
