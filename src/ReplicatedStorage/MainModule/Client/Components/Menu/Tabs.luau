--!strict
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

export type TabStyle = {
	TextSize: number,
	TextColor: Color3,
	TextColorSelected: Color3,
	TextColorHover: Color3,
	AccentColor: Color3,
	AccentHeight: number,
	AccentRadius: UDim,
	AccentBottomOffset: number?,
	PaddingRight: number,
	Uppercase: boolean?,
}

export type TabProps = {
	Text: string,
	IsSelected: FusionCanBeState<boolean>,
	OnClick: () -> (),
	LayoutOrder: number?,
	Style: TabStyle?,
}

local DEFAULT_STYLE: TabStyle = {
	TextSize = Theme.TopBar.Tab.TextSize,
	TextColor = Theme.TopBar.Tab.Text,
	TextColorSelected = Theme.TopBar.Tab.TextSelected,
	TextColorHover = Theme.TopBar.Tab.TextHover,
	AccentColor = Theme.TopBar.Tab.Accent,
	AccentHeight = Theme.TopBar.Tab.AccentHeight,
	AccentRadius = Theme.TopBar.Tab.AccentRadius,
	AccentBottomOffset = Theme.TopBar.Tab.AccentBottomOffset,
	PaddingRight = 16,
	Uppercase = true,
}

local Tabs = {}

Tabs.Styles = {
	TopBar = DEFAULT_STYLE,

	Category = {
		TextSize = Theme.Inventory.CategoryTab.TextSize,
		TextColor = Theme.Inventory.CategoryTab.Text,
		TextColorSelected = Theme.Inventory.CategoryTab.TextSelected,
		TextColorHover = Theme.Inventory.CategoryTab.TextHover,
		AccentColor = Theme.Inventory.CategoryTab.Accent,
		AccentHeight = Theme.Inventory.CategoryTab.AccentHeight,
		AccentRadius = Theme.Inventory.CategoryTab.AccentRadius,
		AccentBottomOffset = Theme.Inventory.CategoryTab.AccentBottomOffset,
		PaddingRight = Theme.Inventory.CategoryTab.PaddingRight,
		Uppercase = true,
	} :: TabStyle,

	Gun = {
		TextSize = Theme.Inventory.GunTab.TextSize,
		TextColor = Theme.Inventory.GunTab.Text,
		TextColorSelected = Theme.Inventory.GunTab.TextSelected,
		TextColorHover = Theme.Inventory.GunTab.TextHover,
		AccentColor = Theme.Inventory.GunTab.Accent,
		AccentHeight = Theme.Inventory.GunTab.AccentHeight,
		AccentRadius = Theme.Inventory.GunTab.AccentRadius,
		AccentBottomOffset = Theme.Inventory.GunTab.AccentBottomOffset,
		PaddingRight = Theme.Inventory.GunTab.PaddingRight,
		Uppercase = false,
	} :: TabStyle,
}

function Tabs.Tab(scope: FusionScope, props: TabProps): Frame
	local style = props.Style or DEFAULT_STYLE
	local isHovered = scope:Value(false)

	local textColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(props.IsSelected) then
				return style.TextColorSelected
			elseif use(isHovered) then
				return style.TextColorHover
			end
			return style.TextColor
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local accentWidth = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(props.IsSelected) then 1 else 0
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local accentTransparency = scope:Computed(function(use: FusionUseFn)
		return if use(props.IsSelected) then 0 else 1
	end)

	local displayText = if style.Uppercase then string.upper(props.Text) else props.Text

	return scope:New("Frame")({
		Name = props.Text,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,

		[Fusion.Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, style.PaddingRight),
				PaddingRight = UDim.new(0, style.PaddingRight),
			}),

			scope:New("Frame")({
				Name = "TabInner",
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "Label",
						Size = UDim2.fromScale(1, 1),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = displayText,
						TextColor3 = textColor,
						TextSize = style.TextSize,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),

					scope:New("Frame")({
						Name = "Accent",
						Size = scope:Computed(function(use: FusionUseFn)
							return UDim2.new(use(accentWidth), 0, 0, style.AccentHeight)
						end),
						Position = UDim2.new(0.5, 0, 1, -(style.AccentBottomOffset or 0)),
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundColor3 = style.AccentColor,
						BackgroundTransparency = accentTransparency,
						BorderSizePixel = 0,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = style.AccentRadius,
							}),
						},
					}),

					scope:New("TextButton")({
						Name = "Hitbox",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 2,

						[Fusion.OnEvent("MouseEnter")] = function()
							isHovered:set(true)
						end,

						[Fusion.OnEvent("MouseLeave")] = function()
							isHovered:set(false)
						end,

						[Fusion.OnEvent("Activated")] = function()
							props.OnClick()
						end,
					}),
				},
			}),
		},
	})
end

return Tabs
