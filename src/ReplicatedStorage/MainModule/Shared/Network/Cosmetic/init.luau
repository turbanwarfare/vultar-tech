--!strict
--!native
--!optimize 2

local Types = require(script.Types)

export type Category = Types.Category
export type OwnedCosmetics = Types.OwnedCosmetics
export type EquippedCosmetics = Types.EquippedCosmetics
export type CosmeticState = Types.CosmeticState
local CosmeticNetwork = {}

local NOOP_CONNECTION = { Disconnect = function() end }

local cachedState: CosmeticState? = nil
local stateCached = false

function CosmeticNetwork.getState(): CosmeticState?
	if stateCached and cachedState then
		return cachedState
	end

	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Cosmetic.GetState.Invoke)

	if success and result then
		cachedState = result
		stateCached = true
		return result
	end

	return nil
end

function CosmeticNetwork.equip(category: Category, itemId: string): boolean
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Cosmetic.Equip.Invoke, category, itemId)
	return success and result == true
end

function CosmeticNetwork.unequip(category: Category): boolean
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Cosmetic.Unequip.Invoke, category)
	return success and result == true
end

function CosmeticNetwork.refreshOwnership(): CosmeticState?
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Cosmetic.RefreshOwnership.Invoke)

	if success and result then
		cachedState = result
		stateCached = true
		return result
	end

	return nil
end

local stateUpdatedCallbacks: { (state: CosmeticState) -> () } = {}
local stateUpdatedRegistered = false

function CosmeticNetwork.onStateUpdated(callback: (state: CosmeticState) -> ()): { Disconnect: () -> () }
	table.insert(stateUpdatedCallbacks, callback)

	if not stateUpdatedRegistered then
		stateUpdatedRegistered = true
		local Blink = require(script.Parent.Generated.Client)
		Blink.Cosmetic.StateUpdated.On(function(state: any)
			if state then
				cachedState = state
				stateCached = true
			end
			for _, cb in stateUpdatedCallbacks do
				task.spawn(cb, state)
			end
		end)
	end

	return {
		Disconnect = function()
			local index = table.find(stateUpdatedCallbacks, callback)
			if not index then return end
			local lastIndex = #stateUpdatedCallbacks
			if index < lastIndex then
				stateUpdatedCallbacks[index] = stateUpdatedCallbacks[lastIndex]
			end
			stateUpdatedCallbacks[lastIndex] = nil
		end,
	}
end

function CosmeticNetwork.onGetState(callback: (player: Player) -> CosmeticState?): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Cosmetic.GetState.On(callback)
	return NOOP_CONNECTION
end

function CosmeticNetwork.onEquip(callback: (player: Player, category: Category, itemId: string) -> boolean): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Cosmetic.Equip.On(callback)
	return NOOP_CONNECTION
end

function CosmeticNetwork.onUnequip(callback: (player: Player, category: Category) -> boolean): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Cosmetic.Unequip.On(callback)
	return NOOP_CONNECTION
end

function CosmeticNetwork.onRefreshOwnership(callback: (player: Player) -> CosmeticState?): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Cosmetic.RefreshOwnership.On(callback)
	return NOOP_CONNECTION
end

function CosmeticNetwork.sendStateUpdate(player: Player, state: CosmeticState): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Cosmetic.StateUpdated.Fire(player, state)
end

function CosmeticNetwork.getCachedState(): CosmeticState?
	return cachedState
end

function CosmeticNetwork.updateCache(state: CosmeticState): ()
	cachedState = state
	stateCached = true
end

function CosmeticNetwork.invalidateCache(): ()
	stateCached = false
	cachedState = nil
end

function CosmeticNetwork.init(): ()
end

return CosmeticNetwork
