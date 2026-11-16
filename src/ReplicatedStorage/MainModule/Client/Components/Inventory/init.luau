--!strict

local Slot = require(script.Slot)
local Hotbar = require(script.Hotbar)

export type SlotProps = Slot.SlotProps
export type HotbarProps = Hotbar.HotbarProps

return {
	Slot = Slot,
	Hotbar = Hotbar,
}
