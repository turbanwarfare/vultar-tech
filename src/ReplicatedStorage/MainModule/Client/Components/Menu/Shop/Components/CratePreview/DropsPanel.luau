--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local CratesConfig = require(MainModule.Shared.Config.Cosmetics.Crates)

local Constants = require(script.Parent.Constants)
local PanelHeader = require(script.Parent.PanelHeader)
local DropCard = require(script.Parent.DropCard)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type CrateConfig = CratesConfig.CrateConfig

local CARD_BASE_HEIGHT = 140
local RARITY_INDEX: { [string]: number } = {}
for index, rarity in CratesConfig.RarityOrder do
	RARITY_INDEX[rarity] = index
end

export type DropsPanelProps = {
	Crate: CrateConfig,
	LayoutOrder: number?,
	OwnedItems: Types.FusionValue<{ [string]: boolean }>?,
}

local function DropsPanel(scope: FusionScope, props: DropsPanelProps): Frame
	local crate = props.Crate

	local sortedDrops = table.clone(crate.drops)
	table.sort(sortedDrops, function(a, b)
		local rankA = RARITY_INDEX[a.rarity] or 0
		local rankB = RARITY_INDEX[b.rarity] or 0
		if rankA ~= rankB then
			return rankA > rankB
		end
		return a.id < b.id
	end)

	local camera = workspace.CurrentCamera
	local viewportWidth = scope:Value(if camera then camera.ViewportSize.X else 1920)
	local viewportHeight = scope:Value(if camera then camera.ViewportSize.Y else 1080)

	if camera then
		local conn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			viewportWidth:set(camera.ViewportSize.X)
			viewportHeight:set(camera.ViewportSize.Y)
		end)
		table.insert(scope, function()
			conn:Disconnect()
		end)
	end

	local gap = Constants.DROP_CARD_GAP

	local cardsPerRow = scope:Computed(function(use: FusionUseFn)
		local w = use(viewportWidth)
		if w < 1400 then
			return 3
		elseif w < 1920 then
			return 4
		elseif w < 2400 then
			return 5
		else
			return 6
		end
	end)

	local cardHeight = scope:Computed(function(use: FusionUseFn)
		local h = use(viewportHeight)
		local scale = math.clamp((h - 600) / 500, 0.85, 1.15)
		return math.floor(CARD_BASE_HEIGHT * scale)
	end)

	local cellSize = scope:Computed(function(use: FusionUseFn)
		local cols = use(cardsPerRow)
		local h = use(cardHeight)
		local widthOffset = -(gap * (cols - 1) // cols)
		return UDim2.new(1 / cols, widthOffset, 0, h)
	end)

	local gridChildren: { Instance } = {
		scope:New("UIGridLayout")({
			CellSize = cellSize,
			CellPadding = UDim2.fromOffset(gap, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		}),
	}

	for index, drop in sortedDrops do
		local isOwnedVal = scope:Computed(function(use: FusionUseFn)
			if not props.OwnedItems then
				return false
			end
			local owned = use(props.OwnedItems)
			if not owned then
				return false
			end
			if drop.category == "GunSkin" then
				if drop.rarity == "Mythic" then
					local sepPos = string.find(drop.id, ":", 1, true)
					local baseSkinId = drop.skinId or (sepPos and string.sub(drop.id, 1, sepPos - 1)) or drop.id
					return owned[baseSkinId] == true or owned[drop.id] == true
				else
					return owned[drop.id] == true
				end
			else
				return owned[drop.id] == true
			end
		end)

		table.insert(
			gridChildren,
			DropCard(scope, {
				Drop = drop,
				LayoutOrder = index,
				IsOwned = isOwnedVal,
			})
		)
	end

	return scope:New("Frame")({
		Name = "Drops",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 2,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),

			PanelHeader(scope, {
				Title = "DROPS",
				Detail = string.format("%d ITEMS", #crate.drops),
				LayoutOrder = 0,
			}),

			scope:New("Frame")({
				Name = "DropGrid",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 1,

				[Fusion.Children] = gridChildren,
			}),
		},
	})
end

return DropsPanel
