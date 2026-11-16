--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

export type GradientButtonProps = {
	Text: FusionCanBeState<string>,
	Size: FusionCanBeState<UDim2>?,
	Position: FusionCanBeState<UDim2>?,
	AnchorPoint: FusionCanBeState<Vector2>?,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
}

local BG_DEFAULT = 0.7
local BG_HOVER = 0.45
local BG_PRESS = 0.3

local function GradientButton(scope: FusionScope, props: GradientButtonProps): Frame
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)

	local backgroundTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isPressed) then
				return BG_PRESS
			elseif use(isHovered) then
				return BG_HOVER
			end
			return BG_DEFAULT
		end),
		Theme.Spring.Snappy.Speed
	)

	local displayText = scope:Computed(function(use: FusionUseFn)
		local text = props.Text
		if typeof(text) == "table" then
			return use(text :: any)
		end
		return text :: string
	end)

	return scope:New("Frame")({
		Name = "GradientButton",
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		Size = props.Size or UDim2.fromOffset(300, 50),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "ButtonShape",
				Size = UDim2.fromScale(1, 1),
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
						Transparency = 0,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),

					scope:New("TextLabel")({
						Name = "Text",
						Size = UDim2.fromScale(1, 1),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Text = displayText,
						TextColor3 = Theme.Foreground.Primary,
						TextSize = Theme.Text.XLarge,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						ZIndex = 2,
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

return GradientButton
