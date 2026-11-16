--!strict

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)
local Types = require(MainModule.Shared.Types)
local Constants = require(script.Parent.Constants)

type FusionScope = Types.FusionScope

export type Props = {
	Text: string,
	LayoutOrder: number,
	ColorConfig: {
		Background: Color3,
		BackgroundHover: Color3,
		Stroke: Color3,
		StrokeHover: Color3,
	},
	OnClick: () -> (),
}

local function ActionButton(scope: FusionScope, props: Props): Frame
	local isHovered = scope:Value(false)

	local bgColor = scope:Spring(
		scope:Computed(function(use)
			return if use(isHovered) then props.ColorConfig.BackgroundHover else props.ColorConfig.Background
		end),
		Constants.SPRING_SPEED,
		Constants.SMOOTH_DAMPING
	)

	local strokeColor = scope:Spring(
		scope:Computed(function(use)
			return if use(isHovered) then props.ColorConfig.StrokeHover else props.ColorConfig.Stroke
		end),
		Constants.SPRING_SPEED,
		Constants.SMOOTH_DAMPING
	)

	return scope:New("Frame")({
		Name = props.Text .. "Button",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = bgColor,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		ClipsDescendants = true,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = UDim.new(0, 4),
			}),

			scope:New("UIStroke")({
				Color = strokeColor,
				Thickness = 1,
			}),

			scope:New("TextLabel")({
				Name = "Label",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = props.Text,
				TextColor3 = Theme.Colors.White,
				TextSize = 11,
				Font = Theme.Text.Bold,
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

				[Fusion.OnEvent("Activated")] = props.OnClick,
			}),
		},
	})
end

return ActionButton
