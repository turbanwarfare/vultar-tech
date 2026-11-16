--!strict
--!native
--!optimize 2

local Types = require(script.Types)

export type ClassSelectResult = Types.ClassSelectResult
export type ClassSlotData = Types.ClassSlotData
export type ClassSlotsState = Types.ClassSlotsState

local ClassNetwork = {}

local NOOP_CONNECTION = { Disconnect = function() end }

function ClassNetwork.selectClass(className: string): ClassSelectResult
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Class.Select.Invoke, className)
	if success and result then
		return result
	end
	return { success = false, error = "Network error" }
end

function ClassNetwork.onSelectClass(callback: (player: Player, className: string) -> ClassSelectResult): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Class.Select.On(callback)
	return NOOP_CONNECTION
end

function ClassNetwork.getSlotsState(): ClassSlotsState?
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Class.GetSlots.Invoke)
	if success then
		return result
	end
	return nil
end

function ClassNetwork.onGetSlotsState(callback: (player: Player) -> ClassSlotsState): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Class.GetSlots.On(callback)
	return NOOP_CONNECTION
end

function ClassNetwork.onSlotsUpdated(callback: (teamKey: string, state: ClassSlotsState) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Class.SlotsUpdate.On(callback)
	return NOOP_CONNECTION
end

function ClassNetwork.broadcastSlotsUpdate(teamKey: string, state: ClassSlotsState): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Class.SlotsUpdate.FireAll(teamKey, state)
end

function ClassNetwork.getPlayerClass(): string?
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Class.GetPlayerClass.Invoke)
	if success then
		return result
	end
	return nil
end

function ClassNetwork.onGetPlayerClass(callback: (player: Player) -> string?): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Class.GetPlayerClass.On(callback)
	return NOOP_CONNECTION
end

function ClassNetwork.init(): ()
end

return ClassNetwork
