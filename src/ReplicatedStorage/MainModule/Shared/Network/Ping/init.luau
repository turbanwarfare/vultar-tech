--!strict
--!native
--!optimize 2

local Types = require(script.Types)

export type HighlightTarget = Types.HighlightTarget
export type PingData = Types.PingData

local PingNetwork = {}

local NOOP_CONNECTION = { Disconnect = function() end }

function PingNetwork.sendPing(position: Vector3): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Ping.Send.Fire(position)
end

function PingNetwork.onPingReceived(callback: (player: Player, position: Vector3) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Ping.Send.On(callback)
	return NOOP_CONNECTION
end

function PingNetwork.sendHighlight(player: Player, pingData: PingData): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Ping.Highlight.Fire(player, pingData)
end

function PingNetwork.broadcastHighlight(pingData: PingData): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Ping.Highlight.FireAll(pingData)
end

function PingNetwork.onHighlightReceived(callback: (pingData: PingData) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Ping.Highlight.On(callback)
	return NOOP_CONNECTION
end

function PingNetwork.notifyPinged(player: Player, senderName: string, duration: number): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Ping.Notify.Fire(player, senderName, duration)
end

function PingNetwork.onPinged(callback: (senderName: string, duration: number) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Ping.Notify.On(callback)
	return NOOP_CONNECTION
end

function PingNetwork.init(): ()
end

return PingNetwork
