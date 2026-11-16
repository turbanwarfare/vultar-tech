--!strict

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)
local Types = require(MainModule.Shared.Types)
local MenuContent = require(script.Parent.Parent.Parent.MenuContent)

type FusionScope = Types.FusionScope
type FusionValue<T> = Types.FusionValue<T>

export type Props = {
	Visible: FusionValue<boolean>,
}

local function RulesTab(scope: FusionScope, props: Props): ScrollingFrame
	local rulesContent = MenuContent.createRulesContent(scope)

	local rulesChildren: { Instance } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		scope:New("UIPadding")({
			PaddingRight = UDim.new(0, 8),
		}),
	}

	for _, row in rulesContent do
		table.insert(rulesChildren, row)
	end

	return scope:New("ScrollingFrame")({
		Name = "RulesContent",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Scrollbar.Thumb,
		CanvasSize = UDim2.fromOffset(0, #rulesContent * 78),
		Visible = props.Visible,

		[Fusion.Children] = rulesChildren,
	})
end

return RulesTab
