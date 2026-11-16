--!strict
--!native
--!optimize 2

local LoadingNetwork = {}

local NOOP_CONNECTION = { Disconnect = function() end }

function LoadingNetwork.notifyReady(): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Loading.Ready.Fire()
end

function LoadingNetwork.onClientReady(callback: (player: Player) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Loading.Ready.On(callback)
	return NOOP_CONNECTION
end

function LoadingNetwork.init(): ()
end

return LoadingNetwork
