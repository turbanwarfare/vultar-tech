--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Tabs = require(script.Parent.Parent.Parent.Tabs)
local ShopConstants = require(script.Parent.Parent.ShopConstants)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionValue<T> = Types.FusionValue<T>

export type StoreHeaderProps = {
	CurrentPage: FusionValue<string>,
	OnPageChange: (pageId: string) -> (),
}

local function StoreHeader(scope: FusionScope, props: StoreHeaderProps): Frame
	local tabButtons: { Instance } = {}

	for i, pageConfig in ShopConstants.PAGES do
		local isSelected = scope:Computed(function(use: FusionUseFn)
			return use(props.CurrentPage) == pageConfig.id
		end)

		local tab = Tabs.Tab(scope, {
			Text = pageConfig.label,
			IsSelected = isSelected,
			LayoutOrder = i,
			Style = Tabs.Styles.Category,
			OnClick = function()
				props.OnPageChange(pageConfig.id)
			end,
		})

		table.insert(tabButtons, tab)
	end

	return scope:New("Frame")({
		Name = "StoreHeader",
		Size = UDim2.new(1, 0, 0, ShopConstants.Header.Height),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("TextLabel")({
				Name = "Title",
				Size = UDim2.new(1, 0, 0, 50),
				Position = UDim2.fromOffset(0, 12),
				BackgroundTransparency = 1,
				Text = "STORE",
				TextColor3 = Theme.Inventory.Title.Text,
				TextSize = Theme.Inventory.Title.Size,
				Font = Theme.Inventory.Title.Font,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),

			scope:New("Frame")({
				Name = "TabsContainer",
				Size = UDim2.new(1, 0, 0, 32),
				Position = UDim2.fromOffset(0, 64),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					tabButtons,
				},
			}),
		},
	})
end

return StoreHeader
