--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local ShopConstants = require(script.Parent.Parent.ShopConstants)

type FusionScope = Types.FusionScope

export type SectionHeaderProps = {
	Title: string,
	Subtitle: string?,
	LayoutOrder: number?,
}

local function SectionHeader(scope: FusionScope, props: SectionHeaderProps): Frame
	return scope:New("Frame")({
		Name = "SectionHeader",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			scope:New("TextLabel")({
				Name = "Title",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = props.Title,
				TextColor3 = ShopConstants.Section.TitleColor,
				TextSize = ShopConstants.Section.TitleSize,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				LayoutOrder = 1,
			}),

			if props.Subtitle
				then scope:New("TextLabel")({
					Name = "Subtitle",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = props.Subtitle,
					TextColor3 = ShopConstants.Section.SubtitleColor,
					TextSize = ShopConstants.Section.SubtitleSize,
					Font = Theme.Text.Regular,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					LayoutOrder = 2,
				})
				else nil,
		},
	})
end

return SectionHeader
