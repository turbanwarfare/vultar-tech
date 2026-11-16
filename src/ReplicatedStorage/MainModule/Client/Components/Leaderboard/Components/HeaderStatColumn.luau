--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)

local Constants = require(script.Parent.Parent.Constants)

local Types = require(script.Parent.Parent.Types)
type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type HeaderStatColumnProps = {
	Label: string,
	GetValue: () -> string,
	Position: number,
}

local LABEL_SPLIT = 0.38

local function HeaderStatColumn(scope: FusionScope, props: HeaderStatColumnProps): Frame
	return scope:New("Frame")({
		Name = props.Label .. "Stat",
		Position = UDim2.fromScale(props.Position, 0),
		Size = UDim2.fromScale(Constants.STAT_WIDTH, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("TextLabel")({
				Name = "Label",
				Size = UDim2.fromScale(1, LABEL_SPLIT),
				BackgroundTransparency = 1,
				Text = props.Label,
				TextColor3 = Constants.Colors.HeaderLabel,
				TextSize = Constants.HEADER_LABEL_SIZE,
				Font = Constants.Font.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Bottom,
			}),

			scope:New("TextLabel")({
				Name = "Value",
				Position = UDim2.fromScale(0, LABEL_SPLIT),
				Size = UDim2.fromScale(1, 1 - LABEL_SPLIT),
				BackgroundTransparency = 1,
				Text = scope:Computed(props.GetValue),
				TextColor3 = Theme.Colors.White,
				TextSize = Constants.HEADER_VALUE_SIZE,
				Font = Constants.Font.Title,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
		},
	})
end

return HeaderStatColumn
