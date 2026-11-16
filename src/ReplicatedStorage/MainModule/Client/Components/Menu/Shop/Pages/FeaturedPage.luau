--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local ShopConstants = require(script.Parent.Parent.ShopConstants)
local SectionHeader = require(script.Parent.Parent.Components.SectionHeader)
local Packs = require(MainModule.Shared.Config.Cosmetics.Packs)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type FeaturedPageProps = {
	OwnedItems: Types.FusionValue<{ [string]: boolean }>?,
	EquippedItems: Types.FusionValue<{ [string]: any }>?,
}

local function createPackCard(scope: FusionScope, pack: Packs.PackConfig, layoutOrder: number): Frame
	local isHovered = scope:Value(false)

	local borderTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0.3 else 0.7
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local scale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 1.02 else 1
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	return scope:New("Frame")({
		Name = pack.id,
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,

		[Fusion.Children] = {
			scope:New("UIScale")({
				Scale = scale,
			}),

			scope:New("Frame")({
				Name = "Card",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Colors.Gray[850],
				ClipsDescendants = true,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, ShopConstants.Card.CornerRadius),
					}),

					scope:New("UIStroke")({
						Color = ShopConstants.Card.BorderAccent,
						Transparency = borderTransparency,
					}),

					scope:New("ImageLabel")({
						Name = "Preview",
						Size = UDim2.new(1, 0, 0, ShopConstants.Card.ImageHeight),
						BackgroundColor3 = Theme.Colors.Gray[800],
						BackgroundTransparency = 0.5,
						Image = "rbxassetid://" .. pack.imageId,
						ImageTransparency = 0,
						ScaleType = Enum.ScaleType.Crop,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0, ShopConstants.Card.CornerRadius),
							}),
						},
					}),

					scope:New("Frame")({
						Name = "Info",
						Size = UDim2.new(1, 0, 1, -ShopConstants.Card.ImageHeight),
						Position = UDim2.fromOffset(0, ShopConstants.Card.ImageHeight),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIPadding")({
								PaddingLeft = UDim.new(0, 12),
								PaddingRight = UDim.new(0, 12),
								PaddingTop = UDim.new(0, 10),
								PaddingBottom = UDim.new(0, 10),
							}),

							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, 4),
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Top,
							}),

							scope:New("TextLabel")({
								Name = "Name",
								Size = UDim2.fromScale(1, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								Text = pack.name,
								TextColor3 = Theme.Foreground.Primary,
								TextSize = 14,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
								LayoutOrder = 1,
							}),

							scope:New("TextLabel")({
								Name = "Type",
								Size = UDim2.fromScale(1, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								Text = "Skin Pack",
								TextColor3 = Theme.Foreground.Muted,
								TextSize = 12,
								Font = Theme.Text.Regular,
								TextXAlignment = Enum.TextXAlignment.Left,
								LayoutOrder = 2,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "PriceBar",
						Size = UDim2.new(1, 0, 0, 28),
						Position = UDim2.new(0, 0, 1, -28),
						BackgroundColor3 = ShopConstants.Card.PriceAccent,
						BackgroundTransparency = 0,

						[Fusion.Children] = {
							scope:New("UIPadding")({
								PaddingLeft = UDim.new(0, 10),
							}),

							scope:New("TextLabel")({
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = "200",
								TextColor3 = Theme.Foreground.Primary,
								TextSize = 14,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Center,
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

				[Fusion.OnEvent("MouseEnter")] = function()
					isHovered:set(true)
				end,

				[Fusion.OnEvent("MouseLeave")] = function()
					isHovered:set(false)
				end,
			}),
		},
	})
end

local FeaturedPage = {}

function FeaturedPage.create(scope: FusionScope, _props: FeaturedPageProps): Frame
	local featuredPacks = Packs.getFeaturedPacks()
	local allPacks = Packs.getAllPacks()

	local featuredCards: { Instance } = {}
	for i, pack in featuredPacks do
		table.insert(featuredCards, createPackCard(scope, pack, i))
	end

	local allCards: { Instance } = {}
	for i, pack in allPacks do
		table.insert(allCards, createPackCard(scope, pack, i))
	end

	return scope:New("Frame")({
		Name = "FeaturedContent",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("ScrollingFrame")({
				Name = "Scroll",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Theme.Scrollbar.Thumb,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.fromOffset(0, 0),

				[Fusion.Children] = {
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, 16),
						PaddingBottom = UDim.new(0, 24),
					}),

					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, ShopConstants.Layout.SectionGap),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					scope:New("Frame")({
						Name = "FeaturedSection",
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						LayoutOrder = 1,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, 16),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							SectionHeader(scope, {
								Title = "Featured",
								Subtitle = "A featured collection of packs and skins",
								LayoutOrder = 1,
							}),

							scope:New("Frame")({
								Name = "FeaturedGrid",
								Size = UDim2.fromScale(1, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								LayoutOrder = 2,

								[Fusion.Children] = {
									scope:New("UIGridLayout")({
										CellSize = UDim2.fromOffset(ShopConstants.Card.Width, ShopConstants.Card.Height),
										CellPadding = UDim2.fromOffset(ShopConstants.Card.Gap, ShopConstants.Card.Gap),
										SortOrder = Enum.SortOrder.LayoutOrder,
										HorizontalAlignment = Enum.HorizontalAlignment.Left,
									}),

									featuredCards,
								},
							}),
						},
					}),

					scope:New("Frame")({
						Name = "AllPacksSection",
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						LayoutOrder = 2,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, 16),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							SectionHeader(scope, {
								Title = "Skin Packs",
								Subtitle = "Bundles containing matching gun skin and player card",
								LayoutOrder = 1,
							}),

							scope:New("Frame")({
								Name = "AllPacksGrid",
								Size = UDim2.fromScale(1, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								LayoutOrder = 2,

								[Fusion.Children] = {
									scope:New("UIGridLayout")({
										CellSize = UDim2.fromOffset(ShopConstants.Card.Width, ShopConstants.Card.Height),
										CellPadding = UDim2.fromOffset(ShopConstants.Card.Gap, ShopConstants.Card.Gap),
										SortOrder = Enum.SortOrder.LayoutOrder,
										HorizontalAlignment = Enum.HorizontalAlignment.Left,
									}),

									allCards,
								},
							}),
						},
					}),
				},
			}),
		},
	})
end

return FeaturedPage
