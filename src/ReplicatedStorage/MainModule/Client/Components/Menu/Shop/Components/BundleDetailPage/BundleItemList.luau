--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)
local GradientDriver = require(MainModule.Client.Components.Chat.Messages.GradientDriver)

local BundleTypes = require(script.Parent.Types)
local Constants = require(script.Parent.Constants)
local Utils = require(script.Parent.Utils)

type FusionScope = BundleTypes.FusionScope
type FusionUseFn = BundleTypes.FusionUseFn
type FusionValue<T> = BundleTypes.FusionValue<T>
type BundleItem = BundleTypes.BundleItem
type BundleItemListProps = BundleTypes.BundleItemListProps

local TRANSPARENCY_NUM_SEQ = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.3), NumberSequenceKeypoint.new(0.75, 0.8), NumberSequenceKeypoint.new(1, 1), })

local function createSectionDivider(scope: FusionScope, label: string): Frame
	return scope:New("Frame")({
		Name = "Divider_" .. label,
		Size = UDim2.new(1, 0, 0, Constants.DIVIDER_HEIGHT),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("TextLabel")({
				Name = "Label",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = label,
				TextColor3 = Color3.fromRGB(155, 155, 165),
				TextSize = 10,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Bottom,
			}),
		},
	})
end

local function createListItem(
	scope: FusionScope,
	item: BundleItem,
	isHovered: FusionValue<boolean>,
	accentColor: Color3,
	onHover: () -> (),
	onLeave: () -> ()
): Frame
	local imageId = item.imageId or ""
	local hasImage = imageId ~= ""
	local hasGradient = item.gradientColors and #item.gradientColors >= 2

	local cardScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 1.01 else 1
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local bgTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0.88 else 0.95
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local displayName = string.upper(item.name)
	local subText = if item.type == "GunSkin" then item.gunName else nil

	return scope:New("Frame")({
		Name = item.id,
		Size = UDim2.new(1, 0, 0, Constants.ITEM_HEIGHT),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("CanvasGroup")({
				Name = "CardContainer",
				Size = scope:Computed(function(use: FusionUseFn)
					local scale = use(cardScale)
					return UDim2.new(scale, -8, scale, 0)
				end),
				Position = UDim2.new(0, 4, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = accentColor,
				BackgroundTransparency = bgTransparency,
				ClipsDescendants = true,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),

					scope:New("ImageLabel")({
						Name = "Stripes",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = Theme.Patterns.DiagonalStripes.Fat,
						ImageColor3 = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								return if use(isHovered)
									then Color3.fromRGB(50, 50, 55)
									else Color3.fromRGB(35, 35, 40)
							end),
							Theme.Spring.Snappy.Speed,
							Theme.Spring.Snappy.Damping
						),
						ImageTransparency = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								return if use(isHovered) then 0.85 else 1
							end),
							Theme.Spring.Snappy.Speed,
							Theme.Spring.Snappy.Damping
						),
						ScaleType = Enum.ScaleType.Tile,
						TileSize = UDim2.fromOffset(48, 48),
						ZIndex = 1,
					}),

					if hasImage
						then scope:New("ImageLabel")({
							Name = "ItemImage",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Image = imageId,
							ScaleType = Enum.ScaleType.Crop,
							ImageTransparency = scope:Spring(
								scope:Computed(function(use: FusionUseFn)
									return if use(isHovered) then 0 else 0.15
								end),
								Theme.Spring.Snappy.Speed,
								Theme.Spring.Snappy.Damping
							),
							ZIndex = 2,

							[Fusion.Children] = {
								scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
								scope:New("UIGradient")({
									Transparency = TRANSPARENCY_NUM_SEQ,
									Rotation = 0,
								}),
							},
						})
						else nil,

					scope:New("TextLabel")({
						Name = "ItemName",
						Size = UDim2.new(0.65, 0, 0, if subText then 16 else 18),
						Position = UDim2.new(1, -8, 0.5, if subText then -4 else 0),
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundTransparency = 1,
						Text = displayName,
						TextColor3 = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								return if use(isHovered)
									then Color3.fromRGB(255, 255, 255)
									else Color3.fromRGB(200, 200, 205)
							end),
							Theme.Spring.Snappy.Speed,
							Theme.Spring.Snappy.Damping
						),
						TextSize = 12,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Right,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 3,

						[Fusion.Children] = {
							if hasGradient then (function()
								local g = scope:New("UIGradient")({
									Color = Utils.convertGradientColors(item.gradientColors :: { Color3 }),
									Offset = Vector2.new(GradientDriver.getCurrentOffset() - 1, 0),
								})
								GradientDriver.register(g :: any)
								return g
							end)() else nil,

							scope:New("UIStroke")({
								Color = Color3.fromRGB(0, 0, 0),
								Thickness = 1.5,
								Transparency = 0.3,
							}),
						},
					}),

					if subText
						then scope:New("TextLabel")({
							Name = "SubText",
							Size = UDim2.new(0.5, 0, 0, 12),
							Position = UDim2.new(1, -8, 0.5, 8),
							AnchorPoint = Vector2.new(1, 0.5),
							BackgroundTransparency = 1,
							Text = subText,
							TextColor3 = Color3.fromRGB(140, 140, 145),
							TextSize = 10,
							Font = Theme.Text.Semibold,
							TextXAlignment = Enum.TextXAlignment.Right,
							ZIndex = 3,
						})
						else nil,

					scope:New("TextButton")({
						Name = "Hitbox",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 10,

						[Fusion.OnEvent("MouseEnter")] = onHover,
						[Fusion.OnEvent("MouseLeave")] = onLeave,
					}),
				},
			}),
		},
	})
end

local function BundleItemList(scope: FusionScope, props: BundleItemListProps): Frame
	local items = props.Items
	local selectedItem = props.SelectedItem
	local headerText = props.HeaderText or "BUNDLE CONTENTS"

	local playerCards: { BundleItem } = {}
	local gunSkins: { BundleItem } = {}
	local chatGradients: { BundleItem } = {}

	for _, item in items do
		if item.type == "PlayerCard" then
			table.insert(playerCards, item)
		elseif item.type == "GunSkin" then
			table.insert(gunSkins, item)
		elseif item.type == "ChatGradient" then
			table.insert(chatGradients, item)
		end
	end

	local listChildren: { Instance } = {
		scope:New("UIPadding")({
			PaddingTop = UDim.new(0, Constants.LIST_PADDING),
			PaddingLeft = UDim.new(0, Constants.LIST_PADDING),
			PaddingRight = UDim.new(0, Constants.LIST_PADDING + 6),
			PaddingBottom = UDim.new(0, Constants.LIST_PADDING),
		}),

		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, Constants.ITEM_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	local layoutOrder = 0

	if #playerCards > 0 then
		local divider = createSectionDivider(scope, "PLAYER CARDS")
		divider.LayoutOrder = layoutOrder
		layoutOrder += 1
		table.insert(listChildren, divider)

		for _, item in playerCards do
			local isHovered = scope:Value(false)
			local listItem = createListItem(scope, item, isHovered, Constants.ACCENT_COLOR, function()
				isHovered:set(true)
				selectedItem:set(item)
			end, function()
				isHovered:set(false)
			end)
			listItem.LayoutOrder = layoutOrder
			layoutOrder += 1
			table.insert(listChildren, listItem)
		end
	end

	if #gunSkins > 0 then
		local divider = createSectionDivider(scope, "GUN SKINS")
		divider.LayoutOrder = layoutOrder
		layoutOrder += 1
		table.insert(listChildren, divider)

		for _, item in gunSkins do
			local isHovered = scope:Value(false)
			local listItem = createListItem(scope, item, isHovered, Constants.GUN_SKIN_ACCENT, function()
				isHovered:set(true)
				selectedItem:set(item)
			end, function()
				isHovered:set(false)
			end)
			listItem.LayoutOrder = layoutOrder
			layoutOrder += 1
			table.insert(listChildren, listItem)
		end
	end

	if #chatGradients > 0 then
		local divider = createSectionDivider(scope, "CHAT GRADIENTS")
		divider.LayoutOrder = layoutOrder
		layoutOrder += 1
		table.insert(listChildren, divider)

		for _, item in chatGradients do
			local isHovered = scope:Value(false)
			local listItem =
				createListItem(scope, item, isHovered, Constants.CHAT_GRADIENT_ACCENT, function()
					isHovered:set(true)
					selectedItem:set(item)
				end, function()
					isHovered:set(false)
				end)
			listItem.LayoutOrder = layoutOrder
			layoutOrder += 1
			table.insert(listChildren, listItem)
		end
	end

	return scope:New("Frame")({
		Name = "ListSection",
		Size = UDim2.fromOffset(Constants.LIST_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,

		[Fusion.Children] = {
			scope:New("TextLabel")({
				Name = "ListHeader",
				Size = UDim2.new(1, 0, 0, Constants.LIST_HEADER_HEIGHT),
				BackgroundTransparency = 1,
				Text = headerText,
				TextColor3 = Color3.fromRGB(165, 165, 175),
				TextSize = 10,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Bottom,

				[Fusion.Children] = {
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 6) }),
				},
			}),

			scope:New("ScrollingFrame")({
				Name = "ItemList",
				Size = UDim2.new(1, 0, 0, 340),
				Position = UDim2.fromOffset(0, Constants.LIST_HEADER_HEIGHT),
				BackgroundTransparency = 1,
				ScrollBarThickness = 2,
				ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65),
				CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				BorderSizePixel = 0,
				ClipsDescendants = true,

				[Fusion.Children] = listChildren,
			}),
		},
	})
end

return BundleItemList
