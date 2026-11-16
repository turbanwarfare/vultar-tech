--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

type FusionScope = Types.FusionScope

export type PlayerTagProps = {
	Text: string,
	TextColor: Color3,
	BackgroundColor: Color3,
	LayoutOrder: number?,
}

local function PlayerTag(scope: FusionScope, props: PlayerTagProps): Frame
	return scope:New("Frame")({
		Name = "Tag_" .. props.Text,
		Size = UDim2.fromOffset(0, 14),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = props.BackgroundColor,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = UDim.new(0, 2),
			}),

			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			}),

			scope:New("TextLabel")({
				Name = "Text",
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Text = props.Text,
				TextColor3 = props.TextColor,
				TextSize = 9,
				Font = Theme.Text.Bold,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		},
	})
end

return PlayerTag
