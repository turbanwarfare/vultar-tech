--!strict
--!native
--!optimize 2

local Types = require(script.Types)

export type InventoryItem = Types.InventoryItem
export type InventoryState = Types.InventoryState
export type InventoryUpdateData = Types.InventoryUpdateData

local InventoryNetwork = {}

local NOOP_CONNECTION = { Disconnect = function() end }

local cachedInventory: InventoryState? = nil
local inventoryCached = false

function InventoryNetwork.getInventory(): InventoryState?
	if inventoryCached and cachedInventory then
		return cachedInventory
	end

	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Inventory.GetInventory.Invoke)
	if success and result then
		cachedInventory = result
		inventoryCached = true
		return result
	end
	return nil
end

function InventoryNetwork.onGetInventory(callback: (player: Player) -> InventoryState?): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Inventory.GetInventory.On(callback)
	return NOOP_CONNECTION
end

function InventoryNetwork.equipSlot(slot: number): boolean
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Inventory.EquipSlot.Invoke, slot)
	return success and result == true
end

function InventoryNetwork.onEquipSlot(callback: (player: Player, slot: number) -> boolean): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Inventory.EquipSlot.On(callback)
	return NOOP_CONNECTION
end

function InventoryNetwork.unequip(): boolean
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Inventory.Unequip.Invoke)
	return success and result == true
end

function InventoryNetwork.onUnequip(callback: (player: Player) -> boolean): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Inventory.Unequip.On(callback)
	return NOOP_CONNECTION
end

function InventoryNetwork.swapSlots(slotA: number, slotB: number): boolean
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Inventory.SwapSlots.Invoke, slotA, slotB)
	return success and result == true
end

function InventoryNetwork.onSwapSlots(callback: (player: Player, slotA: number, slotB: number) -> boolean): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Inventory.SwapSlots.On(callback)
	return NOOP_CONNECTION
end

function InventoryNetwork.dropItem(slot: number): boolean
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Inventory.DropItem.Invoke, slot)
	return success and result == true
end

function InventoryNetwork.onDropItem(callback: (player: Player, slot: number) -> boolean): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Inventory.DropItem.On(callback)
	return NOOP_CONNECTION
end

function InventoryNetwork.broadcastInventoryUpdate(player: Player, data: InventoryUpdateData): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Inventory.Updated.Fire(player, data)
end

function InventoryNetwork.onInventoryUpdated(callback: (data: InventoryUpdateData) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Inventory.Updated.On(function(data: any)
		if data and data.state then
			cachedInventory = data.state
		end
		callback(data)
	end)
	return NOOP_CONNECTION
end

function InventoryNetwork.updateCache(state: InventoryState): ()
	cachedInventory = state
	inventoryCached = true
end

function InventoryNetwork.invalidateCache(): ()
	inventoryCached = false
	cachedInventory = nil
end

function InventoryNetwork.equipSlotOptimistic(slot: number): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Inventory.EquipOptimistic.Fire(slot)
end

function InventoryNetwork.onEquipSlotOptimistic(callback: (player: Player, slot: number) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Inventory.EquipOptimistic.On(callback)
	return NOOP_CONNECTION
end

function InventoryNetwork.unequipOptimistic(): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Inventory.UnequipOptimistic.Fire()
end

function InventoryNetwork.onUnequipOptimistic(callback: (player: Player) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Inventory.UnequipOptimistic.On(callback)
	return NOOP_CONNECTION
end

function InventoryNetwork.init(): ()
end

return InventoryNetwork
