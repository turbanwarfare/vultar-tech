--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CosmeticConfig = require(MainModule.Shared.Config.Cosmetics)

local ShopCache = require(script.Parent.Parent.ShopCache)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

local TRANSPARENCY_NUM_SEQ_2 = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 0.85), })
local TRANSPARENCY_NUM_SEQ = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.5), NumberSequenceKeypoint.new(1, 0), })
local COLOR_CLR_SEQ = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 75, 75)), ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 40, 40)), })

export type ShowcaseCardProps = {
	Item: CosmeticConfig.ItemConfig,
	LayoutOrder: number,
	CategoryAccent: Color3,
	OwnedItems: Types.FusionValue<{ [string]: boolean }>?,
}

local ShowcaseCard = {}

function ShowcaseCard.create(scope: FusionScope, props: ShowcaseCardProps): Frame
	local item = props.Item
	local resolved = CosmeticConfig.resolveItem(item)
	local gradient = resolved.purchaseGradient
	local accentColor = gradient and gradient.colors[1] or props.CategoryAccent

	local isOwned = scope:Computed(function(use: FusionUseFn)
		if props.OwnedItems then
			local owned = use(props.OwnedItems)
			return owned[resolved.id] == true
		end
		return false
	end)

	local isHovered = scope:Value(false)

	local borderOpacity = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0.2 else 1
		end),
		20, 1
	)

	local accentOpacity = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0.14 else 0.05
		end),
		20, 1
	)

	local cardScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 1.012 else 1
		end),
		35, 1
	)

	return scope:New("Frame")({
		Name = resolved.id,
		Size = UDim2.new(0.5, -7, 0, 150),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,

		[Fusion.Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 3),
				PaddingRight = UDim.new(0, 3),
				PaddingTop = UDim.new(0, 3),
				PaddingBottom = UDim.new(0, 3),
			}),

			scope:New("Frame")({
				Name = "ScaleContainer",
				Size = UDim2.fromScale(1, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIScale")({ Scale = cardScale }),

					scope:New("Frame")({
						Name = "CardBody",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Theme.Colors.Gray[850],
						ClipsDescendants = true,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),

							scope:New("UIStroke")({
								Color = accentColor,
								Thickness = 1,
								Transparency = borderOpacity,
							}),

							scope:New("ImageLabel")({
								Name = "Banner",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Image = resolved.imageId or "",
								ScaleType = Enum.ScaleType.Crop,
								ZIndex = 1,
							}),

							scope:New("Frame")({
								Name = "AccentOverlay",
								Size = UDim2.fromScale(1, 1),
								BackgroundColor3 = accentColor,
								BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
									return 1 - use(accentOpacity)
								end),
								ZIndex = 2,

								[Fusion.Children] = {
									scope:New("UIGradient")({
										Rotation = 135,
										Transparency = TRANSPARENCY_NUM_SEQ_2,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "BottomGradient",
								Size = UDim2.fromScale(1, 0.6),
								Position = UDim2.fromScale(0, 1),
								AnchorPoint = Vector2.new(0, 1),
								BackgroundColor3 = Color3.new(0, 0, 0),
								BackgroundTransparency = 0.2,
								ZIndex = 3,

								[Fusion.Children] = {
									scope:New("UIGradient")({
										Rotation = 90,
										Transparency = TRANSPARENCY_NUM_SEQ,
									}),
								},
							}),

							if resolved.isNew then scope:New("Frame")({
								Name = "NewBadge",
								Size = UDim2.fromOffset(48, 24),
								Position = UDim2.fromOffset(10, 10),
								BackgroundColor3 = Color3.fromRGB(235, 55, 55),
								ZIndex = 12,
								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 5) }),
									scope:New("UIGradient")({
										Rotation = 90,
										Color = COLOR_CLR_SEQ,
									}),
									scope:New("TextLabel")({
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = "NEW",
										TextColor3 = Color3.new(1, 1, 1),
										TextSize = 14,
										Font = Enum.Font.GothamBlack,
									}),
								},
							}) else nil,

							scope:New("TextLabel")({
								Name = "Name",
								Size = UDim2.new(1, -20, 0, 32),
								Position = UDim2.new(0, 10, 1, -14),
								AnchorPoint = Vector2.new(0, 1),
								BackgroundTransparency = 1,
								Text = resolved.name,
								TextColor3 = Color3.new(1, 1, 1),
								TextSize = 22,
								Font = Enum.Font.GothamBlack,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
								ZIndex = 8,
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
								[Fusion.OnEvent("Activated")] = function()
									if not Fusion.peek(isOwned) and resolved.purchaseGamepassId > 0 then
										ShopCache.promptPurchase(resolved.purchaseGamepassId)
									end
								end,
							}),
						},
					}),
				},
			}),
		},
	})
end

return ShowcaseCard
