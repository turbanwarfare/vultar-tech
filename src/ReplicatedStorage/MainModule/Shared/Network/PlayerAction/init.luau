--!strict
--!native
--!optimize 2

local Core = require(script.Parent.Core)
local Types = require(script.Types)

export type PlayerActionTrigger = Types.PlayerActionTrigger

local PlayerActionNetwork = {}

local ACTION_EVENTS = {
	"FireShot",
	"EquipCosmetic",
	"GetCosmetics",
	"GetAllCosmetics",
	"KillPlayer",
	"SetGunDamage",
	"UpdatePlayerServerState",
}

local NOOP_CONNECTION = { Disconnect = function() end }

local triggerCallback: ((player: Player, actionName: string) -> ())? = nil
local connections: { RBXScriptConnection } = {}

function PlayerActionNetwork.onTrigger(callback: (player: Player, actionName: string) -> ()): { Disconnect: () -> () }
	triggerCallback = callback
	return NOOP_CONNECTION
end

function PlayerActionNetwork.init(): ()
	if not Core.isServer() then
		return
	end

	for _, name in ACTION_EVENTS do
		local event = Core.getOrCreateRemoteEvent(name)
		table.insert(connections, event.OnServerEvent:Connect(function(player: Player)
			if triggerCallback then
				triggerCallback(player, name)
			end
		end))

		local funcName = name .. "Request"
		local func = Core.getOrCreateRemoteFunction(funcName)
		func.OnServerInvoke = function(player: Player)
			if triggerCallback then
				triggerCallback(player, funcName)
			end
			return nil
		end
	end
end

function PlayerActionNetwork.Cleanup(): ()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	triggerCallback = nil
end

return PlayerActionNetwork
