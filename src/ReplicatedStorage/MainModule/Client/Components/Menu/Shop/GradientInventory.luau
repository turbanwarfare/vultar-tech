--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CosmeticConfig = require(MainModule.Shared.Config.Cosmetics)
local GradientDriver = require(MainModule.Client.Components.Chat.Messages.GradientDriver)
local ChatPrefixCache = require(MainModule.Client.Cache.ChatPrefixCache)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type GradientInventoryProps = {
	Items: Types.FusionValue<{ CosmeticConfig.ResolvedCosmetic }>,
	EquippedId: Types.FusionValue<string?>,
	CategoryAccent: Color3,
	OnEquip: ((itemId: string) -> ())?,
	OnUnequip: (() -> ())?,
}

local CARD_HEIGHT = 115
local CARD_GAP = 6
local ACCENT_BAR_WIDTH = 3
local WHITE_COLOR_SEQUENCE = ColorSequence.new(Color3.new(1, 1, 1))

local function buildColorSequence(colors: { Color3 }): ColorSequence
	local count = #colors
	if count == 0 then
		return WHITE_COLOR_SEQUENCE
	end
	if count == 1 then
		return ColorSequence.new(colors[1])
	end

	local keypoints = {}
	for i, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / (count - 1), color))
	end
	return ColorSequence.new(keypoints)
end

local function createRegisteredGradient(scope: FusionScope, colorSeq: ColorSequence): UIGradient
	local uiGradient = scope:New("UIGradient")({
		Color = colorSeq,
		Rotation = 0,
		Offset = Vector2.new(GradientDriver.getCurrentOffset() - 1, 0),
	})
	GradientDriver.register(uiGradient :: any)
	return uiGradient :: any
end

local function createGradientCard(
	scope: FusionScope,
	item: CosmeticConfig.ResolvedCosmetic,
	equippedId: Types.FusionValue<string?>,
	fullPrefix: string,
	onEquip: (itemId: string) -> (),
	onUnequip: () -> ()
): Frame
	local isHovered = scope:Value(false)
	local colors = item.gradientColors or { Color3.new(1, 1, 1) }
	local colorSequence = buildColorSequence(colors)

	local isEquipped = scope:Computed(function(use: FusionUseFn)
		return use(equippedId) == item.id
	end)

	local cardBg = scope:Computed(function(use: FusionUseFn)
		if use(isEquipped) then
			return Color3.fromRGB(20, 24, 20)
		elseif use(isHovered) then
			return Color3.fromRGB(28, 28, 32)
		end
		return Color3.fromRGB(20, 20, 22)
	end)

	local borderColor = scope:Computed(function(use: FusionUseFn)
		if use(isEquipped) then
			return Theme.Colors.Success
		elseif use(isHovered) then
			return Theme.Colors.Gray[600]
		end
		return Theme.Colors.Gray[800]
	end)

	local function handleClick()
		if Fusion.peek(isEquipped) then
			onUnequip()
		else
			onEquip(item.id)
		end
	end

	return scope:New("Frame")({
		Name = item.id,
		Size = UDim2.new(0.5, 0, 0, CARD_HEIGHT),
		BackgroundColor3 = cardBg,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			scope:New("UIStroke")({
				Color = borderColor,
				Thickness = 1,
			}),

			scope:New("Frame")({
				Name = "AccentBar",
				Size = UDim2.new(0, ACCENT_BAR_WIDTH, 1, -20),
				Position = UDim2.new(0, 10, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				Visible = isEquipped,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 2) }),
					scope:New("UIGradient")({
						Color = colorSequence,
						Rotation = 90,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "Content",
				Size = UDim2.new(1, -48, 1, 0),
				Position = UDim2.fromOffset(24, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "TopRow",
						Size = UDim2.new(1, 0, 0, 26),
						Position = UDim2.fromOffset(0, 12),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("TextLabel")({
								Name = "GradientName",
								Size = UDim2.fromScale(0.7, 1),
								BackgroundTransparency = 1,
								Text = string.upper(item.name or "Gradient"),
								TextColor3 = Color3.new(1, 1, 1),
								TextSize = 20,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Center,

								[Fusion.Children] = {
									createRegisteredGradient(scope, colorSequence),
								},
							}),

							scope:New("Frame")({
								Name = "EquippedBadge",
								Size = UDim2.fromOffset(76, 22),
								Position = UDim2.fromScale(1, 0.5),
								AnchorPoint = Vector2.new(1, 0.5),
								BackgroundColor3 = Theme.Colors.Success,
								BackgroundTransparency = 0.85,
								Visible = isEquipped,

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
									scope:New("UIStroke")({
										Color = Theme.Colors.Success,
										Thickness = 1,
										Transparency = 0.5,
									}),
									scope:New("TextLabel")({
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = "EQUIPPED",
										TextColor3 = Theme.Colors.Success,
										TextSize = 11,
										Font = Theme.Text.Bold,
									}),
								},
							}),
						},
					}),

					scope:New("Frame")({
						Name = "GradientBar",
						Size = UDim2.new(1, 0, 0, 6),
						Position = UDim2.fromOffset(0, 44),
						BackgroundColor3 = Color3.new(1, 1, 1),

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
							scope:New("UIGradient")({
								Color = colorSequence,
								Rotation = 0,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "ChatPreview",
						Size = UDim2.new(1, 0, 0, 20),
						Position = UDim2.fromOffset(0, 62),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("TextLabel")({
								Name = "BaseText",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								RichText = true,
								Text = "<b>" .. fullPrefix .. "</b>  Hello World!",
								TextColor3 = Theme.Colors.Gray[400],
								TextSize = 14,
								Font = Enum.Font.GothamMedium,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),

							scope:New("TextLabel")({
								Name = "GradientOverlay",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = fullPrefix,
								TextColor3 = Color3.new(1, 1, 1),
								TextSize = 14,
								Font = Enum.Font.GothamBold,
								TextXAlignment = Enum.TextXAlignment.Left,

								[Fusion.Children] = {
									createRegisteredGradient(scope, colorSequence),
								},
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
				[Fusion.OnEvent("Activated")] = handleClick,
			}),
		},
	})
end

local function GradientInventory(scope: FusionScope, props: GradientInventoryProps): Frame
	local unsubscribe = GradientDriver.subscribe()
	table.insert(scope, unsubscribe)
	local fullPrefix = ChatPrefixCache.getPrefix()

	local function handleEquip(itemId: string)
		if props.OnEquip then
			props.OnEquip(itemId)
		end
	end

	local function handleUnequip()
		if props.OnUnequip then
			props.OnUnequip()
		end
	end

	return scope:New("Frame")({
		Name = "GradientInventory",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("TextLabel")({
				Name = "HelpText",
				Size = UDim2.new(1, 0, 0, 28),
				Position = UDim2.new(0.5, 0, 0, 6),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Text = "Click to equip/unequip",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 15,
				Font = Theme.Text.Medium,
			}),

			scope:New("ScrollingFrame")({
				Name = "CardList",
				Size = UDim2.new(1, 0, 1, -34),
				Position = UDim2.fromOffset(0, 34),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = Theme.Colors.Gray[700],
				CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,

				[Fusion.Children] = {
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, 4),
						PaddingBottom = UDim.new(0, 12),
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
					}),

					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, CARD_GAP),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					scope:ForValues(props.Items, function(_use: FusionUseFn, cardScope: FusionScope, item: CosmeticConfig.ResolvedCosmetic)
						return createGradientCard(
							cardScope,
							item,
							props.EquippedId,
							fullPrefix,
							handleEquip,
							handleUnequip
						)
					end),
				},
			}),
		},
	})
end

return {
	create = GradientInventory,
}
