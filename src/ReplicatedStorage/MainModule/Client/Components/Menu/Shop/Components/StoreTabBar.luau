--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionValue<T> = Types.FusionValue<T>

local TAB_SELECTED_COLOR = Color3.fromRGB(255, 140, 0)
local TAB_HOVERED_COLOR = Color3.fromRGB(255, 200, 150)
local TAB_DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)

export type TabConfig = {
	id: string,
	label: string,
}

export type StoreTabBarProps = {
	Tabs: { TabConfig },
	CurrentTab: FusionValue<string>,
	OnTabChange: (tabId: string) -> (),
}

local function StoreTabBar(scope: FusionScope, props: StoreTabBarProps): Frame
	local tabs = props.Tabs
	local currentTab = props.CurrentTab
	local onTabChange = props.OnTabChange

	local tabButtons: { Instance } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for i, tab in tabs do
		local isSelected = scope:Computed(function(use: FusionUseFn)
			return use(currentTab) == tab.id
		end)

		local isHovered = scope:Value(false)

		local textColor = scope:Spring(
			scope:Computed(function(use: FusionUseFn)
				if use(isSelected) then
					return TAB_SELECTED_COLOR
				elseif use(isHovered) then
					return TAB_HOVERED_COLOR
				else
					return TAB_DEFAULT_COLOR
				end
			end),
			Theme.Spring.Responsive.Speed,
			Theme.Spring.Responsive.Damping
		)

		local underlineWidth = scope:Spring(
			scope:Computed(function(use: FusionUseFn)
				return if use(isSelected) then 1 else 0
			end),
			Theme.Spring.Snappy.Speed,
			Theme.Spring.Snappy.Damping
		)

		local underlineTransparency = scope:Spring(
			scope:Computed(function(use: FusionUseFn)
				return if use(isSelected) then 0 else 1
			end),
			Theme.Spring.Snappy.Speed,
			Theme.Spring.Snappy.Damping
		)

		local tabButton = scope:New("Frame")({
			Name = "Tab_" .. tab.id,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Visible = true,
			LayoutOrder = i,

			[Fusion.Children] = {
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				}),

				scope:New("TextButton")({
					Name = "Button",
					Size = UDim2.new(0, 0, 1, -6),
					AutomaticSize = Enum.AutomaticSize.X,
					Position = UDim2.fromOffset(0, 0),
					BackgroundTransparency = 1,
					Text = tab.label,
					TextColor3 = textColor,
					TextSize = 25,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,

					[Fusion.OnEvent("MouseEnter")] = function()
						isHovered:set(true)
					end,
					[Fusion.OnEvent("MouseLeave")] = function()
						isHovered:set(false)
					end,
					[Fusion.OnEvent("Activated")] = function()
						onTabChange(tab.id)
					end,
				}),

				scope:New("Frame")({
					Name = "Underline",
					Size = scope:Computed(function(use: FusionUseFn)
						return UDim2.new(use(underlineWidth), 0, 0, 3)
					end),
					Position = UDim2.new(0.5, 0, 1, -8),
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundColor3 = TAB_SELECTED_COLOR,
					BackgroundTransparency = underlineTransparency,
					BorderSizePixel = 0,

					[Fusion.Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					},
				}),
			},
		})

		table.insert(tabButtons, tabButton)
	end

	return scope:New("Frame")({
		Name = "StoreTabBar",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "TabsContainer",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,

				[Fusion.Children] = tabButtons,
			}),
		},
	})
end

return StoreTabBar
