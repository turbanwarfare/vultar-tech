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
local BLACK = Color3.new(0, 0, 0)

local ShopSelector = {}

function ShopSelector.createDiagonalSelector(
	scope: FusionScope,
	onCategoryClick: ((categoryId: string) -> ())?,
	onBackClick: (() -> ())?
): Frame
	local shopCards = ShopConstants.SHOP_CARDS
	local totalCount = #shopCards
	local hoveredIndex: Types.FusionValue<number?> = scope:Value(nil)
	local backButtonHovered = scope:Value(false)

	local backButtonBrightness = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(backButtonHovered) then 1 else 0.7
		end),
		30, 0.9
	)

	local sectionElements: { Frame } = {}

	for i = 1, totalCount do
		local category = shopCards[i]

		local isHovered = scope:Computed(function(use: FusionUseFn)
			return use(hoveredIndex) == i
		end)

		local isAnyHovered = scope:Computed(function(use: FusionUseFn)
			return use(hoveredIndex) ~= nil
		end)

		local sectionWidth = scope:Spring(
			scope:Computed(function(use: FusionUseFn)
				local hovered = use(hoveredIndex)
				if hovered == nil then
					return 1 / totalCount
				elseif hovered == i then
					return 0.38
				else
					return 0.62 / (totalCount - 1)
				end
			end),
			25, 0.85
		)

		local borderOpacity = scope:Spring(
			scope:Computed(function(use: FusionUseFn)
				if use(isHovered) then
					return 0.15
				end
				if use(isAnyHovered) then
					return 0.7
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
				if use(isAnyHovered) then
					return 0.03
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
				if use(isAnyHovered) then
					return 0.7
				end
				return 0.92
			end),
			25, 0.8
		)

		local accentLineWidth = scope:Spring(
			scope:Computed(function(use: FusionUseFn)
				if use(isHovered) then
					return 70
				end
				return 40
			end),
			30, 0.85
		)

		table.insert(sectionElements, scope:New("Frame")({
			Name = category.id .. "Section",
			Size = scope:Computed(function(use: FusionUseFn)
				return UDim2.fromScale(use(sectionWidth), 1)
			end),
			BackgroundColor3 = Theme.Shop.Card.Background,
			BackgroundTransparency = Theme.Shop.Card.BackgroundTransparency,
			LayoutOrder = i,

			[Fusion.Children] = {
				scope:New("UIStroke")({
					Color = category.accent,
					Thickness = 1,
					Transparency = borderOpacity,
				}),

				if category.backgroundImageId then scope:New("ImageLabel")({
					Name = "Background",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Image = "rbxassetid://" .. category.backgroundImageId,
					ImageTransparency = 0.15,
					ScaleType = Enum.ScaleType.Crop,
					ZIndex = 0,
				}) else nil,

				scope:New("Frame")({
					Name = "AccentOverlay",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = category.accent,
					BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
						return 1 - use(accentOpacity)
					end),
					ZIndex = 1,

					[Fusion.Children] = {
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
					Position = UDim2.new(0.5, 0, 1, -14),
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundColor3 = category.accent,
					ZIndex = 3,

					[Fusion.Children] = {
						scope:New("UICorner")({
							CornerRadius = UDim.new(0, 1),
						}),
					},
				}),

				scope:New("TextLabel")({
					Name = "Label",
					Size = UDim2.new(1, 0, 0, 36),
					Position = UDim2.new(0, 0, 1, -16),
					AnchorPoint = Vector2.new(0, 1),
					BackgroundTransparency = 1,
					Text = category.label,
					TextColor3 = scope:Computed(function(use: FusionUseFn)
						local b = use(textBrightness)
						return Color3.new(b, b, b)
					end),
					TextSize = 28,
					Font = Theme.Text.Bold,
					ZIndex = 2,
					RichText = false,

					[Fusion.Children] = {
						scope:New("UIStroke")({
							Color = BLACK,
							Thickness = 1,
							Transparency = 0.4,
						}),
					},
				}),

				scope:New("TextButton")({
					Name = "Hitbox",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 20,

					[Fusion.OnEvent("MouseEnter")] = function()
						hoveredIndex:set(i)
					end,

					[Fusion.OnEvent("MouseLeave")] = function()
						if Fusion.peek(hoveredIndex) == i then
							hoveredIndex:set(nil)
						end
					end,

					[Fusion.OnEvent("Activated")] = function()
						if onCategoryClick then
							onCategoryClick(category.id)
						end
					end,
				}),
			},
		}))
	end

	return scope:New("Frame")({
		Name = "DiagonalSelector",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "BackHeader",
				Size = UDim2.new(1, 0, 0, 45),
				Position = UDim2.fromScale(0, 0),
				BackgroundColor3 = Theme.Shop.Header.Background,
				BackgroundTransparency = Theme.Shop.Header.BackgroundTransparency,
				ZIndex = 200,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, 10),
					}),

					scope:New("UIStroke")({
						Color = Theme.Shop.Header.Border,
						Thickness = 1,
						Transparency = Theme.Shop.Header.BorderTransparency,
					}),

					scope:New("TextButton")({
						Name = "BackButton",
						Size = UDim2.new(0, 100, 1, -10),
						Position = UDim2.new(0, 8, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundColor3 = Theme.Shop.Button.Background,
						BackgroundTransparency = Theme.Shop.Button.BackgroundTransparency,
						ZIndex = 2,

						[Fusion.OnEvent("MouseEnter")] = function()
							backButtonHovered:set(true)
						end,

						[Fusion.OnEvent("MouseLeave")] = function()
							backButtonHovered:set(false)
						end,

						[Fusion.OnEvent("Activated")] = function()
							if onBackClick then
								onBackClick()
							end
						end,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0, 8),
							}),

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
									local b = use(backButtonBrightness)
									return Color3.new(b, b, b)
								end),
								TextSize = 16,
								Font = Theme.Text.Bold,
							}),
						},
					}),

					scope:New("TextLabel")({
						Name = "Title",
						Size = UDim2.new(1, -120, 1, 0),
						Position = UDim2.fromOffset(115, 0),
						BackgroundTransparency = 1,
						Text = "SHOP CATEGORIES",
						TextColor3 = Theme.Foreground.Secondary,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextSize = 16,
						Font = Theme.Text.Bold,
					}),
				},
			}),

			scope:New("CanvasGroup")({
				Name = "SectionsContainer",
				Size = UDim2.new(1, 0, 1, -55),
				Position = UDim2.fromOffset(0, 55),
				BackgroundColor3 = Theme.Colors.Gray[850],

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, 12),
					}),

					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					sectionElements,
				},
			}),
		},
	})
end

return ShopSelector
