--!strict

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Types = require(MainModule.Shared.Types)
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)

export type FusionScope = Types.FusionScope
export type FusionValue<T> = Types.FusionValue<T>
export type FusionCanBeState<T> = Types.FusionCanBeState<T>
export type FusionUseFn = Types.FusionUseFn

export type MenuProps = {
	Visible: FusionCanBeState<boolean>,
	Settings: SettingsConfig.SettingsTemplate?,
	OnSettingChange: ((string, any) -> ())?,
	OnKeybindChange: ((string, string) -> ())?,
	OnKeybindEditStart: (() -> ())?,
	OnKeybindEditEnd: (() -> ())?,
	OnResetSettings: (() -> ())?,
	OnImportSettings: ((any) -> ())?,
	OnClose: (() -> ())?,
}

export type SettingsTabProps = {
	Scope: FusionScope,
	Settings: SettingsConfig.SettingsTemplate,
	SearchQuery: FusionValue<string>,
	PreviewOnRight: FusionValue<boolean>,
	SharingModalVisible: FusionValue<boolean>,
	OnSettingChange: (string, any) -> (),
	OnResetSettings: (() -> ())?,
}

export type SidebarItemProps = {
	Index: number,
	Name: string,
	IsPreview: boolean?,
	ActiveSectionIndex: FusionValue<number>,
	SectionPositions: FusionValue<{ [number]: number }>,
	ScrollFrame: ScrollingFrame?,
	CategoryCount: number,
}

export type ActionButtonProps = {
	Text: string,
	LayoutOrder: number,
	Color: Color3,
	HoverColor: Color3,
	StrokeColor: Color3,
	StrokeHoverColor: Color3,
	OnClick: () -> (),
}

export type RightSidebarProps = {
	PreviewOnRight: FusionValue<boolean>,
	Width: Types.FusionCanBeState<number>,
	OnResetSettings: (() -> ())?,
	OnShareClick: () -> (),
}

return nil
