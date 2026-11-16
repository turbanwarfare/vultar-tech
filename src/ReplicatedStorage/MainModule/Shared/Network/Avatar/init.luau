--!strict
--!native
--!optimize 2

local Types = require(script.Types)

export type AvatarState = Types.AvatarState

local AvatarNetwork = {}

local NOOP_CONNECTION = { Disconnect = function() end }

local cachedState: AvatarState? = nil
local stateCached = false

function AvatarNetwork.getState(): AvatarState?
	if stateCached and cachedState then
		return cachedState
	end
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Avatar.GetState.Invoke)
	if success and result then
		cachedState = result :: AvatarState
		stateCached = true
		return cachedState
	end
	return nil
end

function AvatarNetwork.toggleHats(showHats: boolean): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Avatar.ToggleHats.Fire(showHats)
end

function AvatarNetwork.equipUniform(uniformKey: string, variantKey: string?): ()
	local Blink = require(script.Parent.Generated.Client)
	local encoded = if variantKey then uniformKey .. ":" .. variantKey else uniformKey
	Blink.Avatar.EquipUniform.Fire(encoded)
end

function AvatarNetwork.unequipUniform(): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Avatar.UnequipUniform.Fire()
end

function AvatarNetwork.setNoobicSkinColor(enabled: boolean): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Avatar.SetNoobicSkinColor.Fire(enabled)
end

function AvatarNetwork.setTorsoColor(colorIndex: number): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Avatar.SetTorsoColor.Fire(colorIndex)
end

local stateUpdatedCallbacks: { (state: AvatarState) -> () } = {}
local stateUpdatedRegistered = false

function AvatarNetwork.onStateUpdated(callback: (state: AvatarState) -> ()): { Disconnect: () -> () }
	table.insert(stateUpdatedCallbacks, callback)

	if not stateUpdatedRegistered then
		stateUpdatedRegistered = true
		local Blink = require(script.Parent.Generated.Client)
		Blink.Avatar.StateUpdated.On(function(state: any)
			if state then
				cachedState = state :: AvatarState
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

function AvatarNetwork.onGetState(callback: (player: Player) -> AvatarState?): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Avatar.GetState.On(callback)
	return NOOP_CONNECTION
end

function AvatarNetwork.onToggleHats(callback: (player: Player, showHats: boolean) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Avatar.ToggleHats.On(callback)
	return NOOP_CONNECTION
end

function AvatarNetwork.onEquipUniform(callback: (player: Player, uniformKey: string, variantKey: string?) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Avatar.EquipUniform.On(function(player: Player, encoded: string)
		local colonPos = string.find(encoded, ":", 1, true)
		if colonPos then
			callback(player, string.sub(encoded, 1, colonPos - 1), string.sub(encoded, colonPos + 1))
		else
			callback(player, encoded, nil)
		end
	end)
	return NOOP_CONNECTION
end

function AvatarNetwork.onUnequipUniform(callback: (player: Player) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Avatar.UnequipUniform.On(callback)
	return NOOP_CONNECTION
end

function AvatarNetwork.onSetNoobicSkinColor(callback: (player: Player, enabled: boolean) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Avatar.SetNoobicSkinColor.On(callback)
	return NOOP_CONNECTION
end

function AvatarNetwork.onSetTorsoColor(callback: (player: Player, colorIndex: number) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Avatar.SetTorsoColor.On(callback)
	return NOOP_CONNECTION
end

function AvatarNetwork.sendStateUpdate(player: Player, state: AvatarState): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Avatar.StateUpdated.Fire(player, state)
end

function AvatarNetwork.invalidateCache(): ()
	stateCached = false
	cachedState = nil
end

function AvatarNetwork.init(): ()
end

return AvatarNetwork
