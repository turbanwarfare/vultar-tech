--!strict

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Inventory = require(script.Parent.Parent.Parent.Inventory)

type FusionScope = Types.FusionScope
type FusionValue<T> = Types.FusionValue<T>

export type Props = {
	Visible: FusionValue<boolean>,
	OwnedItems: FusionValue<{ [string]: boolean }>,
	EquippedItems: FusionValue<{ [string]: any }>,
	CurrentTab: FusionValue<number>?,
}

local function InventoryTab(scope: FusionScope, props: Props): Frame
	return scope:New("Frame")({
		Name = "InventoryContent",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = props.Visible,

		[Fusion.Children] = {
			Inventory(scope, {
				OwnedItems = props.OwnedItems,
				EquippedItems = props.EquippedItems,
				CurrentTab = props.CurrentTab,
			}),
		},
	})
end

return InventoryTab
