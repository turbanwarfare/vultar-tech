--!strict
--!native
--!optimize 2

export type InventoryItem = {
	Id: string,
	Name: string,
	Tool: Tool?,
	Slot: number,
	Icon: string?,
}

export type InventoryState = {
	Items: { InventoryItem },
	EquippedSlot: number?,
	MaxSlots: number,
}

local InventoryConfig = {}

InventoryConfig.MaxSlots = 9
InventoryConfig.SlotSize = 64
InventoryConfig.SlotGap = 6
InventoryConfig.BottomPadding = 24

InventoryConfig.DefaultState = {
	Items = {},
	EquippedSlot = nil,
	MaxSlots = 9,
} :: InventoryState

function InventoryConfig.createDefaultState(): InventoryState
	return {
		Items = {},
		EquippedSlot = nil,
		MaxSlots = InventoryConfig.MaxSlots,
	}
end

function InventoryConfig.getNextAvailableSlot(items: { InventoryItem }): number?
	local usedSlots: { [number]: boolean } = {}
	for _, item in items do
		usedSlots[item.Slot] = true
	end

	for slot = 1, InventoryConfig.MaxSlots do
		if not usedSlots[slot] then
			return slot
		end
	end

	return nil
end

function InventoryConfig.findItemBySlot(items: { InventoryItem }, slot: number): InventoryItem?
	for _, item in items do
		if item.Slot == slot then
			return item
		end
	end
	return nil
end

function InventoryConfig.findItemById(items: { InventoryItem }, id: string): InventoryItem?
	for _, item in items do
		if item.Id == id then
			return item
		end
	end
	return nil
end

return InventoryConfig
