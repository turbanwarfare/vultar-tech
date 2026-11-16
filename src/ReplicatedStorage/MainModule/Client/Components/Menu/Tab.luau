--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Types = require(MainModule.Shared.Types)
local Tabs = require(script.Parent.Tabs)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>

export type TabProps = {
	Text: string,
	IsSelected: FusionCanBeState<boolean>,
	OnClick: (() -> ())?,
	LayoutOrder: number?,
	IsFirst: boolean?,
	IsLast: boolean?,
}

local function Tab(scope: FusionScope, props: TabProps): Frame
	return Tabs.Tab(scope, {
		Text = props.Text,
		IsSelected = props.IsSelected,
		OnClick = props.OnClick or function() end,
		LayoutOrder = props.LayoutOrder,
		Style = Tabs.Styles.TopBar,
	})
end

return Tab
