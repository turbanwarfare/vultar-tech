--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local ShopConstants = require(script.Parent.ShopConstants)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

local TRANSPARENCY_NUM_SEQ = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 0.85), })

local ShopCard = {}

function ShopCard.create(
	scope: FusionScope,
	cardId: string,
	theme: ShopConstants.CardTheme,
	isLarge: boolean,
	onCardClick: ((cardId: string) -> ())?
): Frame
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)

	local cardScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isPressed) then
				return 0.995
			end
			if use(isHovered) then
				return 1.006
			end
			return 1
		end),
		40, 1
	)

	local borderOpacity = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isHovered) then
				return 0.15
			end
			return 0.55
		end),
		25, 0.8
	)

	local accentOpacity = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isHovered) then
				return 0.14
			end
			return 0.05
		end),
		20, 0.7
	)

	local textBrightness = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isHovered) then
				return 1
			end
			return 0.92
		end),
		25, 0.8
	)

	local accentLineWidth = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isHovered) then
				return if isLarge then 80 else 50
			end
			return if isLarge then 50 else 32
		end),
		30, 0.85
	)

	local textColor = scope:Computed(function(use: FusionUseFn)
		local brightness = use(textBrightness)
		return Color3.new(brightness, brightness, brightness)
	end)

	local textSize = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			local base = if isLarge then 38 else 26
			if use(isHovered) then
				return base + 3
			end
			return base
		end),
		25, 1
	)

	return scope:New("Frame")({
		Name = cardId .. "Card",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			}),

			scope:New("Frame")({
				Name = "ScaleContainer",
				Size = UDim2.fromScale(1, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIScale")({
						Scale = cardScale,
					}),

					scope:New("Frame")({
						Name = "CardBody",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Theme.Shop.Card.Background,
						BackgroundTransparency = Theme.Shop.Card.BackgroundTransparency,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0, 10),
							}),

							scope:New("UIStroke")({
								Color = theme.accent,
								Thickness = 1,
								Transparency = borderOpacity,
							}),

							if theme.backgroundImageId then scope:New("ImageLabel")({
								Name = "Background",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Image = "rbxassetid://" .. theme.backgroundImageId,
								ImageTransparency = 0.15,
								ScaleType = Enum.ScaleType.Crop,
								ZIndex = 0,

								[Fusion.Children] = {
									scope:New("UICorner")({
										CornerRadius = UDim.new(0, 10),
									}),
								},
							}) else nil,

							scope:New("Frame")({
								Name = "AccentOverlay",
								Size = UDim2.fromScale(1, 1),
								BackgroundColor3 = theme.accent,
								BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
									return 1 - use(accentOpacity)
								end),
								ZIndex = 1,

								[Fusion.Children] = {
									scope:New("UICorner")({
										CornerRadius = UDim.new(0, 10),
									}),

									scope:New("UIGradient")({
										Rotation = 135,
										Transparency = TRANSPARENCY_NUM_SEQ,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "AccentLine",
								Size = scope:Computed(function(use: FusionUseFn)
									return UDim2.fromOffset(use(accentLineWidth), 2)
								end),
								Position = UDim2.new(0.5, 0, 1, -12),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = theme.accent,
								ZIndex = 3,

								[Fusion.Children] = {
									scope:New("UICorner")({
										CornerRadius = UDim.new(0, 1),
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
									isPressed:set(false)
								end,

								[Fusion.OnEvent("MouseButton1Down")] = function()
									isPressed:set(true)
								end,

								[Fusion.OnEvent("MouseButton1Up")] = function()
									isPressed:set(false)
								end,

								[Fusion.OnEvent("Activated")] = function()
									if onCardClick then
										onCardClick(cardId)
									end
								end,
							}),
						},
					}),

					scope:New("TextLabel")({
						Name = "Label",
						Size = UDim2.new(1, -16, 0, 50),
						Position = UDim2.new(0.5, 0, 1, if isLarge then -12 else -8),
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						Text = theme.label,
						TextColor3 = textColor,
						TextSize = textSize,
						Font = Theme.Text.Bold,
						RichText = false,
						ZIndex = 20,

						[Fusion.Children] = {
							scope:New("UIStroke")({
								Color = Color3.fromRGB(25, 25, 25),
								Thickness = 1.5,
								Transparency = 0.25,
							}),
						},
					}),
				},
			}),
		},
	})
end

return ShopCard
