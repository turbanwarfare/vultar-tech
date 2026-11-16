--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)

local GunSkinsConfig = require(MainModule.Shared.Config.Cosmetics.Items.GunSkins)
local Collections = require(MainModule.Shared.Config.Cosmetics.Collections)
local SkinCard = require(script.Parent.Parent.Components.SkinCard)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

local camera = workspace.CurrentCamera

local CARD_BASE_HEIGHT = 160
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
	local scale = math.clamp((height - 600) / 500, 0.85, 1.15)
	return math.floor(CARD_BASE_HEIGHT * scale)
end

type SkinData = {
	id: string,
	name: string,
	collection: string,
	gamepassId: number,
	season: string,
}

local function getVisibleSkins(): { SkinData }
	local skins: { SkinData } = {}

	for _, skinConfig in GunSkinsConfig do
		local isVisible = skinConfig.visible ~= false
		local hasPurchaseGamepass = skinConfig.purchaseGamepassId and skinConfig.purchaseGamepassId > 0
		local isDefault = skinConfig.id == "Default"

		if isVisible and hasPurchaseGamepass and not isDefault then
			local collectionKey = skinConfig.collection or skinConfig.id
			local collectionData = Collections[collectionKey]
			local displayName = if collectionData then collectionData.name else skinConfig.id
			local season = if collectionData then (collectionData.season or "1") else "1"

			table.insert(skins, {
				id = skinConfig.id,
				name = displayName,
				collection = collectionKey,
				gamepassId = skinConfig.purchaseGamepassId,
				season = season,
			})
		end
	end

	return skins
end

local function groupSkinsBySeason(skins: { SkinData }): { [string]: { SkinData } }
	local grouped: { [string]: { SkinData } } = {}

	for _, skin in skins do
		local season = skin.season
		if not grouped[season] then
			grouped[season] = {}
		end
		table.insert(grouped[season], skin)
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

type SkinClickData = {
	id: string,
	name: string,
	gamepassId: number,
}

export type GunSkinsPageProps = {
	Padding: Types.FusionValue<number>,
	OnSkinClick: ((skin: SkinClickData) -> ())?,
}

local GunSkinsPage = {}

function GunSkinsPage.create(scope: FusionScope, props: GunSkinsPageProps): Frame
	local allSkins = getVisibleSkins()
	local groupedSkins = groupSkinsBySeason(allSkins)

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
		local seasonSkins = groupedSkins[seasonKey]
		if seasonSkins and #seasonSkins > 0 then
			local seasonLabel = SEASON_LABELS[seasonKey] or `SEASON {seasonKey}`

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

			for skinIndex, skin in seasonSkins do
				local card = SkinCard(scope, {
					SkinId = skin.id,
					SkinName = skin.name,
					GamepassId = skin.gamepassId,
					LayoutOrder = skinIndex,
					OnClick = function()
						if props.OnSkinClick then
							props.OnSkinClick({
								id = skin.id,
								name = skin.name,
								gamepassId = skin.gamepassId,
							})
						end
					end,
				})
				table.insert(gridChildren, card)
			end

			local gridFrame = scope:New("Frame")({
				Name = "SkinGrid",
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
		Name = "GunSkinsPage",
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

return GunSkinsPage
