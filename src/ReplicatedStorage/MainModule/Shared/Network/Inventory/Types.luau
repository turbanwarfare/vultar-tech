--!strict
--!native
--!optimize 2

local Shared = script.Parent.Parent.Parent
local InventoryConfig = require(Shared.Config.Inventory.InventoryConfig)

export type InventoryItem = InventoryConfig.InventoryItem
export type InventoryState = InventoryConfig.InventoryState

export type InventoryUpdateData = {
	action: "add" | "remove" | "equip" | "unequip" | "swap" | "full",
	item: InventoryItem?,
	slot: number?,
	state: InventoryState?,
}

return nil
