--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CosmeticConfig = require(MainModule.Shared.Config.Cosmetics)
local GradientDriver = require(MainModule.Client.Components.Chat.Messages.GradientDriver)
local ChatPrefixCache = require(MainModule.Client.Cache.ChatPrefixCache)

local SkinModelCache = require(script.Parent.Parent.Cache.SkinModelCache)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

local TRANSPARENCY_NUM_SEQ = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 1), })

export type InventoryItemSlotProps = {
	Item: CosmeticConfig.ResolvedCosmetic,
	IsEquipped: Types.FusionValue<boolean>,
	CategoryAccent: Types.FusionValue<Color3>,
	OnClick: () -> (),
}

local GunViewportFactory = require(MainModule.Client.Utils.GunViewportFactory)

local function getSkinModelForCollection(collectionId: string): Model?
	local model = SkinModelCache.getModel(collectionId, "H-82")
	if model then return model end
	return SkinModelCache.getModel("Default", "H-82")
end

local function createGunViewport(model: Model): ViewportFrame
	local viewport = GunViewportFactory.create(model, {
		fov = 70,
		distanceMultiplier = 0.55,
		cameraOffsetX = 0.15,
		cameraOffsetY = 0.05,
		ambient = Color3.fromRGB(180, 180, 180),
		lightDirection = Vector3.new(-1, -1, -1),
		deferCamera = false,
	})
	return viewport
end

local InventoryItemSlot = {}

function InventoryItemSlot.create(scope: FusionScope, props: InventoryItemSlotProps): Frame
	local item = props.Item
	local isEquipped = props.IsEquipped
	local catAccent = props.CategoryAccent

	local hovered = scope:Value(false)
	local isGradientItem = item.gradientColors and #item.gradientColors > 0
	local isGunSkin = item.category == "GunSkin"
	local isPlayerCard = item.category == "PlayerCard"

	local gradientColorSequence = if isGradientItem then (function()
		local colors = item.gradientColors
		local count = #colors
		if count == 7 then
			return ColorSequence.new({
				ColorSequenceKeypoint.new(0, colors[1]),
				ColorSequenceKeypoint.new(0.18, colors[2]),
				ColorSequenceKeypoint.new(0.35, colors[3]),
				ColorSequenceKeypoint.new(0.50, colors[4]),
				ColorSequenceKeypoint.new(0.65, colors[5]),
				ColorSequenceKeypoint.new(0.82, colors[6]),
				ColorSequenceKeypoint.new(1, colors[7]),
			})
		else
			local keypoints = {}
			for i, color in colors do
				table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / (count - 1), color))
			end
			return ColorSequence.new(keypoints)
		end
	end)() else nil

	local fullPrefix = ChatPrefixCache.getPrefix()

	if isGradientItem then
		local unsubscribe = GradientDriver.subscribe()
		table.insert(scope, unsubscribe)
	end

	local gunViewport: ViewportFrame? = nil
	if isGunSkin then
		local collectionId = item.id
		if collectionId == "Default" then
			collectionId = "Default"
		end
		local gunModel = getSkinModelForCollection(collectionId)
		if gunModel then
			gunViewport = createGunViewport(gunModel)
		end
	end

	return scope:New("Frame")({
		Name = item.id,
		Size = if isGradientItem then UDim2.new(1, -4, 0, 120) else UDim2.new(0.5, -4, 0, 70),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("CanvasGroup")({
				Name = "Card",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = if isGradientItem then Color3.fromRGB(18, 18, 18) else Theme.Colors.Gray[850],

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),

					scope:New("UIStroke")({
						Color = scope:Computed(function(use: FusionUseFn)
							if use(isEquipped) then
								return use(catAccent)
							end
							return Theme.Colors.Gray[700]
						end),
						Thickness = scope:Computed(function(use: FusionUseFn)
							return if use(isEquipped) then 2 else 1
						end),
					}),

					if isGunSkin and gunViewport then gunViewport else nil,

					if isGunSkin then scope:New("TextLabel")({
						Name = "SkinName",
						Size = UDim2.new(1, -8, 0, 16),
						Position = UDim2.new(0, 4, 1, -4),
						AnchorPoint = Vector2.new(0, 1),
						BackgroundTransparency = 1,
						Text = item.name or item.id,
						TextColor3 = Theme.Colors.Gray[300],
						TextSize = 10,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 3,
					}) else nil,

					if isPlayerCard and item.imageId and item.imageId ~= "" then scope:New("ImageLabel")({
						Name = "Img",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = item.imageId,
						ScaleType = Enum.ScaleType.Crop,
						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
						},
					}) else nil,

					if isGradientItem then scope:New("Frame")({
						Name = "ChatPreview",
						Size = UDim2.fromOffset(0, 0),
						Position = UDim2.new(0.5, 0, 0.5, -6),
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("TextLabel")({
								Name = "MessageContent",
								Size = UDim2.fromOffset(0, 0),
								Position = UDim2.fromOffset(0, 0),
								AutomaticSize = Enum.AutomaticSize.XY,
								BackgroundTransparency = 1,
								RichText = true,
								Text = "<b>" .. fullPrefix .. "</b> Hello World!",
								TextColor3 = Color3.fromRGB(200, 200, 200),
								TextSize = 18,
								Font = Enum.Font.GothamMedium,
								TextXAlignment = Enum.TextXAlignment.Left,
								LineHeight = 1.15,
								ZIndex = 1,
							}),

							scope:New("TextLabel")({
								Name = "GradientPrefix",
								Size = UDim2.fromOffset(0, 0),
								Position = UDim2.fromOffset(0, 0),
								AutomaticSize = Enum.AutomaticSize.XY,
								BackgroundTransparency = 1,
								RichText = false,
								Text = fullPrefix,
								TextColor3 = Color3.new(1, 1, 1),
								TextSize = 18,
								Font = Enum.Font.GothamBold,
								TextXAlignment = Enum.TextXAlignment.Left,
								LineHeight = 1.15,
								ZIndex = 2,

								[Fusion.Children] = {
(function()
										local g = scope:New("UIGradient")({
											Color = gradientColorSequence,
											Rotation = 0,
											Offset = Vector2.new(GradientDriver.getCurrentOffset() - 1, 0),
										})
										if isGradientItem then
											GradientDriver.register(g :: any)
										end
										return g
									end)(),
								},
							}),
						},
					}) else nil,

					if isGradientItem then scope:New("Frame")({
						Name = "NameBar",
						Size = UDim2.new(1, 0, 0, 28),
						Position = UDim2.fromScale(0, 1),
						AnchorPoint = Vector2.new(0, 1),
						BackgroundColor3 = Color3.fromRGB(12, 12, 12),
						ZIndex = 3,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),

							scope:New("Frame")({
								Name = "TopCover",
								Size = UDim2.new(1, 0, 0, 10),
								Position = UDim2.fromOffset(0, 0),
								BackgroundColor3 = Color3.fromRGB(12, 12, 12),
								BorderSizePixel = 0,
							}),

							scope:New("TextLabel")({
								Name = "ItemName",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = item.name or "Gradient",
								TextColor3 = Color3.fromRGB(160, 160, 160),
								TextSize = 12,
								Font = Theme.Text.Bold,
							}),
						},
					}) else nil,

					if not isGradientItem then scope:New("Frame")({
						Name = "Glow",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = catAccent,
						BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
							return if use(isEquipped) then 0.5 else 1
						end),
						ZIndex = 2,
						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
							scope:New("UIGradient")({
								Rotation = 0,
								Transparency = TRANSPARENCY_NUM_SEQ,
							}),
						},
					}) else nil,

					scope:New("Frame")({
						Name = "HoverDim",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
							return if use(hovered) then 0.9 else 1
						end),
						ZIndex = 4,
						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
						},
					}),

					scope:New("Frame")({
						Name = "Badge",
						Size = UDim2.fromOffset(64, 18),
						Position = UDim2.new(0.5, 0, 0, 6),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = catAccent,
						Visible = isEquipped,
						ZIndex = 5,
						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 5) }),
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
						Name = "Hit",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 10,
						[Fusion.OnEvent("MouseEnter")] = function()
							hovered:set(true)
						end,
						[Fusion.OnEvent("MouseLeave")] = function()
							hovered:set(false)
						end,
						[Fusion.OnEvent("Activated")] = props.OnClick,
					}),
				},
			}),
		},
	})
end

return InventoryItemSlot
