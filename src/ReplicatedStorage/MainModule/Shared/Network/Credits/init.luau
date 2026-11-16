--!strict
--!native
--!optimize 2

local CreditsNetwork = {}

local NOOP_CONNECTION = { Disconnect = function() end }

function CreditsNetwork.requestCredits(): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Credits.Request.Fire()
end

function CreditsNetwork.onCreditsRequested(callback: (player: Player) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Credits.Request.On(callback)
	return NOOP_CONNECTION
end

function CreditsNetwork.sendToggleCredits(player: Player, show: boolean): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Credits.Toggle.Fire(player, show)
end

function CreditsNetwork.onToggleCredits(callback: (show: boolean) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Credits.Toggle.On(callback)
	return NOOP_CONNECTION
end

function CreditsNetwork.init(): ()
end

return CreditsNetwork
