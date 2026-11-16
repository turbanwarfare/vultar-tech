--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

local BUTTON_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.new(0.9, 0.9, 0.9)),
})
local Shadow = require(MainModule.Client.Components.Shadow)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type DeployButtonProps = {
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
}

local SHADOW_SPREAD = 4
local SHADOW_OFFSET_Y = 2

local function DeployButton(scope: FusionScope, props: DeployButtonProps): Frame
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)

	local backgroundTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isPressed) then
				return 0.15
			elseif use(isHovered) then
				return 0.25
			end
			return 0.35
		end),
		Theme.Spring.Snappy.Speed
	)

	local shadowTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isPressed) then
				return 0.5
			elseif use(isHovered) then
				return 0.55
			end
			return 0.65
		end),
		Theme.Spring.Snappy.Speed
	)

	local borderTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isPressed) then
				return 0.2
			elseif use(isHovered) then
				return 0.3
			end
			return 0.4
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

	local buttonHeight = 55
	local wrapperHeight = buttonHeight + SHADOW_SPREAD * 2

	return scope:New("Frame")({
		Name = "DeployButton",
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
				BackgroundColor3 = Theme.Colors.Accent,
				BackgroundTransparency = backgroundTransparency,
				ZIndex = 1,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Medium,
					}),

					scope:New("UIStroke")({
						Color = Theme.Colors.Accent,
						Thickness = 1.5,
						Transparency = borderTransparency,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),

					scope:New("UIGradient")({
						Color = BUTTON_GRADIENT,
						Rotation = 90,
					}),

					scope:New("TextLabel")({
						Name = "Text",
						Size = UDim2.fromScale(1, 1),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Text = "DEPLOY",
						TextColor3 = Theme.Foreground.Primary,
						TextSize = 18,
						Font = Enum.Font.GothamBold,
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

return DeployButton
