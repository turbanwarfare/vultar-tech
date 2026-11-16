--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type CreditsButtonProps = {
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
}

local SHADOW_SPREAD = 4
local SHADOW_OFFSET_Y = 1

local function CreditsButton(scope: FusionScope, props: CreditsButtonProps): Frame
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)

	local backgroundTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isPressed) then
				return 0.4
			elseif use(isHovered) then
				return 0.5
			end
			return 0.65
		end),
		Theme.Spring.Snappy.Speed
	)

	local shadowTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isPressed) then
				return 0.65
			elseif use(isHovered) then
				return 0.7
			end
			return 0.78
		end),
		Theme.Spring.Snappy.Speed
	)

	local textColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isHovered) then
				return Theme.Foreground.Primary
			end
			return Theme.Foreground.Secondary
		end),
		Theme.Spring.Default.Speed
	)

	local borderTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isPressed) then
				return 0.3
			elseif use(isHovered) then
				return 0.4
			end
			return 0.5
		end),
		Theme.Spring.Snappy.Speed
	)

	local positionY = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isPressed) then
				return SHADOW_SPREAD + 1
			end
			return SHADOW_SPREAD
		end),
		Theme.Spring.Snappy.Speed
	)

	local buttonHeight = 40
	local wrapperHeight = buttonHeight + SHADOW_SPREAD * 2

	return scope:New("Frame")({
		Name = "CreditsButton",
		Position = props.Position,
		Size = props.Size or UDim2.new(1, SHADOW_SPREAD * 2, 0, wrapperHeight),
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,

		[Fusion.Children] = {
			Shadow(scope, {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = 0,
				Transparency = shadowTransparency,
				ZIndex = 0,
			}),

			scope:New("Frame")({
				Name = "ButtonShape",
				Size = UDim2.new(1, -SHADOW_SPREAD * 2, 0, buttonHeight),
				Position = scope:Computed(function(use: FusionUseFn)
					return UDim2.fromOffset(SHADOW_SPREAD, use(positionY))
				end),
				BackgroundColor3 = Theme.Background.Secondary,
				BackgroundTransparency = backgroundTransparency,
				ZIndex = 1,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Medium,
					}),

					scope:New("UIStroke")({
						Color = Theme.Border.Default,
						Thickness = 1,
						Transparency = borderTransparency,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),

					scope:New("TextLabel")({
						Name = "Text",
						Size = UDim2.fromScale(1, 1),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Text = "CREDITS",
						TextColor3 = textColor,
						TextSize = 13,
						Font = Enum.Font.GothamMedium,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),

					scope:New("TextButton")({
						Name = "Hitbox",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 10,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = Theme.Radius.Medium,
							}),
						},

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
							if props.OnClick then
								props.OnClick()
							end
						end,
					}),
				},
			}),
		},
	})
end

return CreditsButton
