--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CosmeticConfig = require(MainModule.Shared.Config.Cosmetics)

local ShopCache = require(script.Parent.Parent.ShopCache)
local ShopConstants = require(script.Parent.Parent.ShopConstants)
local GradientInventory = require(script.Parent.Parent.GradientInventory)
local InventoryItemSlot = require(script.Parent.Parent.Components.InventoryItemSlot)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type InventoryPageProps = {
	Category: Types.FusionValue<CosmeticConfig.Category?>,
	OnBackClick: (() -> ())?,
	OwnedItems: Types.FusionValue<{ [string]: boolean }>?,
	EquippedItems: Types.FusionValue<{ [string]: any }>?,
	OnShopClick: ((category: CosmeticConfig.Category) -> ())?,
}

local InventoryPage = {}

function InventoryPage.create(scope: FusionScope, props: InventoryPageProps): Frame
	local category = props.Category
	local localEquipped: Types.FusionValue<string?> = scope:Value(nil)

	local catAccent = scope:Computed(function(use: FusionUseFn)
		local cat = use(category)
		if not cat then
			return Theme.Colors.Gray[500]
		end
		local config = ShopConstants.INVENTORY_CARDS[cat]
		return config and config.accent or Theme.Colors.Gray[500]
	end)

	local catLabel = scope:Computed(function(use: FusionUseFn)
		local cat = use(category)
		if not cat then
			return ""
		end
		local config = ShopConstants.INVENTORY_CARDS[cat]
		return config and config.label or cat
	end)

	local itemList = scope:Computed(function(use: FusionUseFn)
		local cat = use(category)
		if not cat then
			return {}
		end
		local owned = props.OwnedItems and use(props.OwnedItems) or {}
		local result: { CosmeticConfig.ResolvedCosmetic } = {}

		for _, item in ShopCache.getCachedCategoryItems(cat) do
			if owned[item.id] then
				local resolved = ShopCache.getCachedResolvedItem(item.id)
				if resolved then
					table.insert(result, resolved)
				end
			end
		end

		return result
	end)

	local isEmpty = scope:Computed(function(use: FusionUseFn)
		return #use(itemList) == 0
	end)

	local function doEquipOrUnequip(itemId: string)
		local cat = Fusion.peek(category)
		if not cat then
			return
		end

		local currentEquipped = Fusion.peek(localEquipped)
		if currentEquipped == nil and props.EquippedItems then
			currentEquipped = Fusion.peek(props.EquippedItems)[cat]
		end

		if currentEquipped == itemId then
			localEquipped:set("")
			task.spawn(function()				Network.Cosmetic.unequip(cat)
			end)
		else
			localEquipped:set(itemId)
			task.spawn(function()				Network.Cosmetic.equip(cat, itemId)
			end)
		end
	end

	scope:Observer(category):onBind(function()
		localEquipped:set(nil)
	end)

	local function createItemSlot(_use: FusionUseFn, itemScope: FusionScope, item: CosmeticConfig.ResolvedCosmetic): Frame
		local isEquipped = itemScope:Computed(function(use: FusionUseFn)
			local localId = use(localEquipped)
			if localId ~= nil then
				return localId == item.id
			end
			local cat = use(category)
			if not cat or not props.EquippedItems then
				return false
			end
			return use(props.EquippedItems)[cat] == item.id
		end)

		return InventoryItemSlot.create(itemScope, {
			Item = item,
			IsEquipped = isEquipped,
			CategoryAccent = catAccent,
			OnClick = function()
				doEquipOrUnequip(item.id)
			end,
		})
	end

	local isChatGradient = scope:Computed(function(use: FusionUseFn)
		return use(category) == "ChatGradient"
	end)

	local gradientItemList = scope:Computed(function(use: FusionUseFn)
		local cat = use(category)
		if cat ~= "ChatGradient" then
			return {}
		end
		return use(itemList)
	end)

	local equippedGradientId = scope:Computed(function(use: FusionUseFn)
		if not props.EquippedItems then
			return nil
		end
		local localId = use(localEquipped)
		if localId ~= nil then
			return if localId == "" then nil else localId
		end
		return use(props.EquippedItems)["ChatGradient"]
	end)

	local function handleGradientEquip(itemId: string)
		localEquipped:set(itemId)
		task.spawn(function()			Network.Cosmetic.equip("ChatGradient", itemId)
		end)
	end

	local function handleGradientUnequip()
		localEquipped:set("")
		task.spawn(function()			Network.Cosmetic.unequip("ChatGradient")
		end)
	end

	local backButtonHovered = scope:Value(false)
	local backButtonColor = scope:Computed(function(use: FusionUseFn)
		return if use(backButtonHovered) then Theme.Colors.Gray[650] else Theme.Shop.Button.Background
	end)

	return scope:New("Frame")({
		Name = "InventoryPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 45),
				BackgroundColor3 = Theme.Shop.Header.Background,
				BackgroundTransparency = Theme.Shop.Header.BackgroundTransparency,
				ZIndex = 10,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
					scope:New("UIStroke")({
						Color = Theme.Shop.Header.Border,
						Thickness = 1,
						Transparency = Theme.Shop.Header.BorderTransparency,
					}),

					scope:New("TextButton")({
						Name = "Back",
						Size = UDim2.fromOffset(100, 32),
						Position = UDim2.new(0, 8, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundColor3 = backButtonColor,
						BackgroundTransparency = Theme.Shop.Button.BackgroundTransparency,
						Text = "",

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
								TextColor3 = Theme.Colors.Gray[400],
								TextSize = 14,
								Font = Theme.Text.Bold,
							}),
						},
					}),

					scope:New("TextLabel")({
						Name = "Title",
						Size = UDim2.new(1, -220, 1, 0),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Text = catLabel,
						TextColor3 = catAccent,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextSize = 16,
						Font = Theme.Text.Bold,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "GradientContent",
				Size = UDim2.new(1, 0, 1, -55),
				Position = UDim2.fromOffset(0, 55),
				BackgroundTransparency = 1,
				Visible = isChatGradient,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "Empty",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Visible = scope:Computed(function(use: FusionUseFn)
							return #use(gradientItemList) == 0
						end),

						[Fusion.Children] = {
							scope:New("TextLabel")({
								Size = UDim2.fromScale(1, 0.4),
								Position = UDim2.fromScale(0.5, 0.4),
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Text = "No gradients owned",
								TextColor3 = Theme.Colors.Gray[500],
								TextSize = 14,
								Font = Theme.Text.Medium,
							}),

							scope:New("TextButton")({
								Name = "Shop",
								Size = UDim2.fromOffset(140, 36),
								Position = UDim2.fromScale(0.5, 0.55),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Fusion.peek(catAccent),
								Text = "",

								[Fusion.OnEvent("Activated")] = function()
									if props.OnShopClick then
										props.OnShopClick("ChatGradient")
									end
								end,

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
									scope:New("TextLabel")({
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = "Browse Shop",
										TextColor3 = Color3.new(1, 1, 1),
										TextSize = 14,
										Font = Theme.Text.Bold,
									}),
								},
							}),
						},
					}),

					GradientInventory.create(scope, {
						Items = gradientItemList,
						EquippedId = equippedGradientId,
						CategoryAccent = Fusion.peek(catAccent),
						OnEquip = handleGradientEquip,
						OnUnequip = handleGradientUnequip,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "ListWrap",
				Size = UDim2.new(0.5, 0, 1, -55),
				Position = UDim2.new(0.5, 0, 0, 55),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use: FusionUseFn)
					return not use(isChatGradient)
				end),

				[Fusion.Children] = {
					scope:New("ScrollingFrame")({
						Name = "List",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 3,
						ScrollBarImageColor3 = Theme.Colors.Gray[600],
						CanvasSize = UDim2.fromOffset(0, 0),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						ScrollingDirection = Enum.ScrollingDirection.Y,
						Visible = scope:Computed(function(use: FusionUseFn)
							return not use(isEmpty)
						end),

						[Fusion.Children] = {
							scope:New("UIPadding")({
								PaddingTop = UDim.new(0, 4),
								PaddingBottom = UDim.new(0, 4),
								PaddingRight = UDim.new(0, 8),
							}),

							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = UDim.new(0, 8),
								SortOrder = Enum.SortOrder.LayoutOrder,
								Wraps = true,
							}),

							scope:ForValues(itemList, createItemSlot),
						},
					}),

					scope:New("Frame")({
						Name = "Empty",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Visible = isEmpty,

						[Fusion.Children] = {
							scope:New("TextLabel")({
								Size = UDim2.fromScale(1, 0.4),
								Position = UDim2.fromScale(0.5, 0.4),
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Text = "No items owned",
								TextColor3 = Theme.Colors.Gray[500],
								TextSize = 14,
								Font = Theme.Text.Medium,
							}),

							scope:New("TextButton")({
								Name = "Shop",
								Size = UDim2.fromOffset(140, 36),
								Position = UDim2.fromScale(0.5, 0.55),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = catAccent,
								Text = "",

								[Fusion.OnEvent("Activated")] = function()
									if props.OnShopClick then
										local cat = Fusion.peek(category)
										if cat then
											props.OnShopClick(cat)
										end
									end
								end,

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
									scope:New("TextLabel")({
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = "Browse Shop",
										TextColor3 = Color3.new(1, 1, 1),
										TextSize = 14,
										Font = Theme.Text.Bold,
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

return InventoryPage
