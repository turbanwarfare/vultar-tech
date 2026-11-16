--!strict

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)
local Types = require(MainModule.Shared.Types)
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
local MenuContent = require(script.Parent.Parent.Parent.MenuContent)

type FusionScope = Types.FusionScope
type FusionValue<T> = Types.FusionValue<T>

export type Props = {
	Visible: FusionValue<boolean>,
	Settings: SettingsConfig.SettingsTemplate,
	KeybindStates: { [string]: FusionValue<string> },
	OnKeybindClick: (name: string, state: FusionValue<string>) -> (),
}

local function KeybindsTab(scope: FusionScope, props: Props): ScrollingFrame
	local keybindsContent = MenuContent.createKeybindsContent(scope, props.Settings, props.KeybindStates, props.OnKeybindClick)

	local keybindsChildren: { Instance } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		scope:New("UIPadding")({
			PaddingRight = UDim.new(0, 8),
		}),
	}

	for _, row in keybindsContent do
		table.insert(keybindsChildren, row)
	end

	return scope:New("ScrollingFrame")({
		Name = "KeybindsContent",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Scrollbar.Thumb,
		CanvasSize = UDim2.fromOffset(0, #keybindsContent * 68),
		Visible = props.Visible,

		[Fusion.Children] = keybindsChildren,
	})
end

return KeybindsTab
