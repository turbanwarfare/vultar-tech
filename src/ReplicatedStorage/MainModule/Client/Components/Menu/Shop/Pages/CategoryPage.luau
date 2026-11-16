--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CosmeticConfig = require(MainModule.Shared.Config.Cosmetics)

local ShopConstants = require(script.Parent.Parent.ShopConstants)
local ShowcaseCard = require(script.Parent.Parent.Components.ShowcaseCard)
local SeasonHeader = require(script.Parent.Parent.Components.SeasonHeader)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

local TRANSPARENCY_NUM_SEQ = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.8), })

export type CategoryPageProps = {
	Category: CosmeticConfig.Category,
	OnBackClick: (() -> ())?,
	OwnedItems: Types.FusionValue<{ [string]: boolean }>?,
}

local CategoryPage = {}

function CategoryPage.create(scope: FusionScope, props: CategoryPageProps): Frame
	local items = CosmeticConfig.getItemsByCategory(props.Category)
	local backButtonHovered = scope:Value(false)

	local categoryConfig = ShopConstants.INVENTORY_CARDS[props.Category]
	local categoryLabel = categoryConfig and categoryConfig.label or props.Category
	local categoryAccent = categoryConfig and categoryConfig.accent or Color3.new(1, 1, 1)

	local seasonGroups: { [string]: { CosmeticConfig.ItemConfig } } = {}
	local totalVisible = 0

	for _, item in items do
		local resolved = CosmeticConfig.resolveItem(item)
		if resolved.imageId == "" or not resolved.visible then
			continue
		end

		local season = resolved.season or "Other"
		if not seasonGroups[season] then
			seasonGroups[season] = {}
		end
		table.insert(seasonGroups[season], item)
		totalVisible += 1
	end

	local sortedSeasons = {}
	for season in seasonGroups do
		table.insert(sortedSeasons, season)
	end
	table.sort(sortedSeasons, function(a, b)
		local orderA = ShopConstants.SEASON_CONFIG[a] and ShopConstants.SEASON_CONFIG[a].order or 99
		local orderB = ShopConstants.SEASON_CONFIG[b] and ShopConstants.SEASON_CONFIG[b].order or 99
		return orderA < orderB
	end)

	local allElements: { Frame } = {}
	local layoutOrder = 0

	for _, season in sortedSeasons do
		local seasonItems = seasonGroups[season]
		if #seasonItems == 0 then
			continue
		end

		layoutOrder += 1
		table.insert(allElements, SeasonHeader.create(scope, {
			SeasonKey = season,
			LayoutOrder = layoutOrder,
		}))

		for _, item in seasonItems do
			layoutOrder += 1
			table.insert(allElements, ShowcaseCard.create(scope, {
				Item = item,
				LayoutOrder = layoutOrder,
				CategoryAccent = categoryAccent,
				OwnedItems = props.OwnedItems,
			}))
		end
	end

	return scope:New("Frame")({
		Name = "CategoryPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 56),
				BackgroundColor3 = Theme.Shop.Header.Background,
				BackgroundTransparency = Theme.Shop.Header.BackgroundTransparency,
				ZIndex = 200,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 14) }),
					scope:New("UIStroke")({
						Color = categoryAccent,
						Thickness = 1,
						Transparency = 0.5,
					}),

					scope:New("Frame")({
						Name = "AccentBar",
						Size = UDim2.new(0.4, 0, 0, 3),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = categoryAccent,
						ZIndex = 201,
						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 2) }),
							scope:New("UIGradient")({
								Transparency = TRANSPARENCY_NUM_SEQ,
							}),
						},
					}),

					scope:New("TextButton")({
						Name = "BackButton",
						Size = UDim2.fromOffset(85, 36),
						Position = UDim2.new(0, 12, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundColor3 = Theme.Shop.Button.Background,
						BackgroundTransparency = Theme.Shop.Button.BackgroundTransparency,

						[Fusion.OnEvent("MouseEnter")] = function()
							backButtonHovered:set(true)
						end,
						[Fusion.OnEvent("MouseLeave")] = function()
							backButtonHovered:set(false)
						end,
						[Fusion.OnEvent("Activated")] = function()
							if props.OnBackClick then
								props.OnBackClick()
							end
						end,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
							scope:New("UIStroke")({
								Color = Theme.Shop.Button.Border,
								Thickness = 1,
								Transparency = Theme.Shop.Button.BorderTransparency,
							}),
							scope:New("TextLabel")({
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = "← BACK",
								TextColor3 = scope:Computed(function(use: FusionUseFn)
									return if use(backButtonHovered) then Color3.new(1, 1, 1) else Theme.Colors.Gray[400]
								end),
								TextSize = 13,
								Font = Theme.Text.Bold,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "TitleSection",
						Size = UDim2.new(1, -220, 1, 0),
						Position = UDim2.fromOffset(110, 0),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("TextLabel")({
								Name = "Title",
								Size = UDim2.new(1, 0, 0, 24),
								Position = UDim2.new(0, 0, 0.5, -4),
								AnchorPoint = Vector2.new(0, 0.5),
								BackgroundTransparency = 1,
								Text = categoryLabel,
								TextColor3 = categoryAccent,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextSize = 20,
								Font = Theme.Text.Bold,
							}),

							scope:New("TextLabel")({
								Name = "Stats",
								Size = UDim2.new(1, 0, 0, 16),
								Position = UDim2.new(0, 0, 0.5, 14),
								AnchorPoint = Vector2.new(0, 0.5),
								BackgroundTransparency = 1,
								Text = totalVisible .. " items • " .. #sortedSeasons .. " collections",
								TextColor3 = Theme.Colors.Gray[500],
								TextXAlignment = Enum.TextXAlignment.Left,
								TextSize = 12,
								Font = Theme.Text.Medium,
							}),
						},
					}),
				},
			}),

			scope:New("ScrollingFrame")({
				Name = "Content",
				Size = UDim2.new(1, 0, 1, -66),
				Position = UDim2.fromOffset(0, 66),
				BackgroundColor3 = Theme.Colors.Gray[950],
				BackgroundTransparency = 0.15,
				BorderSizePixel = 0,
				ScrollBarThickness = 0,
				CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 14) }),
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 14),
						PaddingRight = UDim.new(0, 14),
						PaddingTop = UDim.new(0, 14),
						PaddingBottom = UDim.new(0, 20),
					}),

					scope:New("Frame")({
						Name = "Grid",
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 14),
								Wraps = true,
							}),

							allElements,
						},
					}),
				},
			}),
		},
	})
end

return CategoryPage
