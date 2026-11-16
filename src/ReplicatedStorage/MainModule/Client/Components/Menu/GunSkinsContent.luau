--!strict
--!native
--!optimize 2


local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CosmeticConfig = require(MainModule.Shared.Config.Cosmetics)
local Network = require(MainModule.Shared.Network)
local GunViewportFactory = require(MainModule.Client.Utils.GunViewportFactory)
local GunSkinUtils = require(script.Parent.GunSkinUtils)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionValue<T> = Types.FusionValue<T>

local getSkinModel = GunSkinUtils.getSkinModel
local skinHasGun = GunSkinUtils.skinHasGun

export type GunSkinsContentProps = {
	CurrentGunName: FusionValue<string>,
	CurrentClassName: FusionValue<string>,
	OwnedItems: FusionValue<{ [string]: boolean }>?,
	EquippedItems: FusionValue<{ [string]: any }>?,
	CardWidth: number?,
	CardHeight: number?,
	CardGap: number?,
}

local cameraTemplate: Camera = Instance.new("Camera")
cameraTemplate.CameraType = Enum.CameraType.Scriptable
cameraTemplate.FieldOfView = 35

local function getCollectionImageId(collectionName: string?): string?
	if not collectionName then
		return nil
	end
	local collection = CosmeticConfig.Collections[collectionName]
	if collection and collection.imageId and collection.imageId ~= "" then
		return collection.imageId
	end
	return nil
end

local function getSkinName(skinItem: CosmeticConfig.ItemConfig): string
	if skinItem.name then
		return skinItem.name
	end
	if skinItem.collection then
		local collection = CosmeticConfig.Collections[skinItem.collection]
		if collection and collection.name then
			return collection.name
		end
		return skinItem.collection
	end
	return skinItem.id
end

local function createSkinCard(
	scope: FusionScope,
	skinItem: CosmeticConfig.ItemConfig,
	isHovered: FusionValue<boolean>,
	isEquipped: FusionValue<boolean>,
	onHover: () -> (),
	onLeave: () -> (),
	onClick: () -> ()
): Frame
	local imageId = getCollectionImageId(skinItem.collection)
	local skinName = getSkinName(skinItem)
	local hasImage = imageId ~= nil and imageId ~= ""

	local borderColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isEquipped) then
				return Color3.fromRGB(255, 140, 0)
			elseif use(isHovered) then
				return Color3.fromRGB(120, 120, 125)
			end
			return Color3.fromRGB(75, 75, 80)
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local textColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isHovered) or use(isEquipped) then
				return Color3.fromRGB(230, 230, 235)
			end
			return Color3.fromRGB(180, 180, 190)
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local strokeColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isHovered) or use(isEquipped) then
				return Color3.fromRGB(40, 40, 45)
			end
			return Color3.fromRGB(20, 20, 22)
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	return scope:New("Frame")({
		Name = skinItem.id,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("CanvasGroup")({
				Name = "Card",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(22, 22, 26),

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, 4),
					}),

					scope:New("UIStroke")({
						Color = borderColor,
						Thickness = scope:Computed(function(use: FusionUseFn)
							return if use(isEquipped) then 3 else 2
						end),
					}),

					if hasImage then scope:New("ImageLabel")({
						Name = "Background",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = imageId,
						ScaleType = Enum.ScaleType.Crop,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0, 4),
							}),
						},
					}) else nil,

					scope:New("TextLabel")({
						Name = "SkinName",
						Size = UDim2.new(1, -16, 0, 24),
						Position = UDim2.new(0, 8, 1, -8),
						AnchorPoint = Vector2.new(0, 1),
						BackgroundTransparency = 1,
						Text = skinName,
						TextColor3 = textColor,
						TextSize = 14,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Bottom,
						TextTruncate = Enum.TextTruncate.AtEnd,

						[Fusion.Children] = {
							scope:New("UIStroke")({
								Color = strokeColor,
								Thickness = 1.5,
								Transparency = 0.3,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "EquippedBadge",
						Size = UDim2.fromOffset(68, 18),
						Position = UDim2.new(1, -6, 0, 6),
						AnchorPoint = Vector2.new(1, 0),
						BackgroundColor3 = Color3.fromRGB(255, 140, 0),
						Visible = isEquipped,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0, 3),
							}),

							scope:New("TextLabel")({
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = "EQUIPPED",
								TextColor3 = Color3.new(1, 1, 1),
								TextSize = 9,
								Font = Theme.Text.Bold,
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

local function GunSkinsContent(scope: FusionScope, props: GunSkinsContentProps): Frame
	local hoveredSkinId = scope:Value(nil :: string?)
	local equippedSkinId = scope:Value("Default")

	local function refreshEquippedSkin(): ()
		local gunName = Fusion.peek(props.CurrentGunName)
		local equipped = props.EquippedItems and Fusion.peek(props.EquippedItems)
		if equipped and equipped.GunSkins and type(equipped.GunSkins) == "table" then
			local skinForGun = equipped.GunSkins[gunName]
			equippedSkinId:set(if skinForGun and skinForGun ~= "" then skinForGun else "Default")
		else
			equippedSkinId:set("Default")
		end
	end

	refreshEquippedSkin()

	if props.EquippedItems then
		scope:Observer(props.EquippedItems):onBind(refreshEquippedSkin)
	end
	scope:Observer(props.CurrentGunName):onChange(refreshEquippedSkin)

	local gunSkins = CosmeticConfig.getItemsByCategory("GunSkin")

	local previewModel = scope:Computed(function(use: FusionUseFn)
		local gunName = use(props.CurrentGunName)
		local skinId = use(hoveredSkinId) or use(equippedSkinId)
		return getSkinModel(skinId or "Default", gunName)
	end)

	local previewSkinName = scope:Computed(function(use: FusionUseFn)
		local skinId = use(hoveredSkinId) or use(equippedSkinId) or "Default"
		for _, skin in gunSkins do
			if skin.id == skinId then
				return getSkinName(skin)
			end
		end
		return "Default"
	end)

	local previewTitle = scope:Computed(function(use: FusionUseFn)
		local gunName = use(props.CurrentGunName)
		return string.upper(gunName) .. " PREVIEW"
	end)

	local filteredSkins = scope:Computed(function(use: FusionUseFn)
		local gunName = use(props.CurrentGunName)
		local ownedItems = props.OwnedItems and use(props.OwnedItems)
		local result = {}

		local defaultSkin = {
			id = "Default",
			collection = "Default",
			category = "GunSkin",
			gamepassId = 0,
		}
		table.insert(result, defaultSkin)

		for _, skinItem in gunSkins do
			if skinItem.id == "Default" then
				continue
			end
			local isOwned = ownedItems and (ownedItems[skinItem.id] == true or ownedItems[skinItem.id .. ":" .. gunName] == true)
			if skinItem.visible == false and not isOwned then
				continue
			end
			if isOwned and skinHasGun(skinItem.id, gunName) then
				table.insert(result, skinItem)
			end
		end
		return result
	end)

	local viewportKey = scope:Value(0)

	scope:Observer(previewModel):onChange(function()
		viewportKey:set(Fusion.peek(viewportKey) + 1)
	end)

	local CARD_WIDTH = props.CardWidth or 217
	local CARD_HEIGHT = props.CardHeight or 115
	local CARD_GAP = props.CardGap or 10
	local PREVIEW_HEIGHT = 150

	return scope:New("Frame")({
		Name = "GunSkinsContent",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "ContentWrapper",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "SkinsSection",
						Size = UDim2.new(1, 0, 1, -(PREVIEW_HEIGHT + 12)),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("ScrollingFrame")({
								Name = "SkinsGrid",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								ScrollBarThickness = 3,
								ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65),
								CanvasSize = UDim2.fromOffset(0, 0),
								AutomaticCanvasSize = Enum.AutomaticSize.Y,
								ScrollingDirection = Enum.ScrollingDirection.Y,
								BorderSizePixel = 0,

								[Fusion.Children] = {
									scope:New("UIPadding")({
										PaddingTop = UDim.new(0, 8),
										PaddingLeft = UDim.new(0, 8),
										PaddingRight = UDim.new(0, 8),
										PaddingBottom = UDim.new(0, 8),
									}),

									scope:New("Frame")({
										Name = "GridContainer",
										Size = UDim2.fromScale(1, 0),
										AutomaticSize = Enum.AutomaticSize.Y,
										BackgroundTransparency = 1,

										[Fusion.Children] = {
											scope:New("UIGridLayout")({
												CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP),
												CellSize = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
												FillDirection = Enum.FillDirection.Horizontal,
												HorizontalAlignment = Enum.HorizontalAlignment.Left,
												SortOrder = Enum.SortOrder.LayoutOrder,
												FillDirectionMaxCells = 4,
											}),

											scope:ForPairs(filteredSkins, function(_use, innerScope, index, skinItem)
												local skinId = skinItem.id
												local isHovered = innerScope:Value(false)

												local isEquipped = innerScope:Computed(function(use: FusionUseFn)
													return use(equippedSkinId) == skinId
												end)

												local card = createSkinCard(
													innerScope,
													skinItem,
													isHovered,
													isEquipped,
													function()
														isHovered:set(true)
														hoveredSkinId:set(skinId)
													end,
													function()
														isHovered:set(false)
														hoveredSkinId:set(nil)
													end,
													function()
														equippedSkinId:set(skinId)
														local gunName = Fusion.peek(props.CurrentGunName)
														Network.Cosmetic.equip("GunSkin", skinId .. ":" .. gunName)
													end
												)

												card.LayoutOrder = index

												return index, card
											end),
										},
									}),
								},
							}),
						},
					}),

					scope:New("Frame")({
						Name = "PreviewSection",
						Size = UDim2.new(1, 0, 0, PREVIEW_HEIGHT),
						Position = UDim2.fromScale(0, 1),
						AnchorPoint = Vector2.new(0, 1),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("Frame")({
								Name = "PreviewLabels",
								Size = UDim2.new(0, 120, 1, 0),
								Position = UDim2.fromOffset(0, 0),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									scope:New("TextLabel")({
										Name = "PreviewTitle",
										Size = UDim2.new(1, 0, 0, 12),
										Position = UDim2.fromOffset(0, 8),
										BackgroundTransparency = 1,
										Text = previewTitle,
										TextColor3 = Color3.fromRGB(90, 90, 95),
										TextSize = 10,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),

									scope:New("TextLabel")({
										Name = "SkinNameLabel",
										Size = UDim2.new(1, 0, 0, 18),
										Position = UDim2.fromOffset(0, 22),
										BackgroundTransparency = 1,
										Text = previewSkinName,
										TextColor3 = Color3.fromRGB(200, 200, 205),
										TextSize = 15,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "ViewportContainer",
								Size = UDim2.new(1, -130, 1, 0),
								Position = UDim2.fromOffset(130, 0),
								BackgroundTransparency = 1,
								ClipsDescendants = true,

								[Fusion.Children] = {
									scope:Computed(function(use: FusionUseFn)
										use(viewportKey)
										local model = use(previewModel)
										if not model then return nil end
									local viewport = GunViewportFactory.create(model, {
										backgroundColor = Color3.fromRGB(30, 30, 30),
										backgroundTransparency = 0,
									})
									return viewport
									end),
								},
							}),
						},
					}),
				},
			}),
		},
	})
end

return GunSkinsContent
