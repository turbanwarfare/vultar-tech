--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")
local Types = require(script.Types)

export type DeathData = Types.DeathData
export type KillLogData = Types.KillLogData

local Death = {}

local NOOP_CONNECTION = { Disconnect = function() end }

function Death.sendDeathData(player: Player, data: DeathData): ()
	if not RunService:IsServer() then
		return
	end
	local Blink = require(script.Parent.Generated.Server)
	Blink.Death.Data.Fire(player, data)
end

function Death.onDeathData(callback: (data: DeathData) -> ()): { Disconnect: () -> () }
	if RunService:IsServer() then
		error("Death.onDeathData can only be called on the client")
	end
	local Blink = require(script.Parent.Generated.Client)
	Blink.Death.Data.On(callback)
	return NOOP_CONNECTION
end

function Death.requestRespawn(): ()
	if RunService:IsServer() then
		return
	end
	local Blink = require(script.Parent.Generated.Client)
	Blink.Death.RespawnReady.Fire()
end

function Death.onRespawnReady(callback: (player: Player) -> ()): { Disconnect: () -> () }
	if not RunService:IsServer() then
		error("Death.onRespawnReady can only be called on the server")
	end
	local Blink = require(script.Parent.Generated.Server)
	Blink.Death.RespawnReady.On(callback)
	return NOOP_CONNECTION
end

function Death.requestKillLog(): KillLogData?
	if RunService:IsServer() then return nil end
	local Blink = require(script.Parent.Generated.Client)
	return Blink.Death.RequestKillLog.Invoke()
end

function Death.onKillLogRequest(callback: (player: Player) -> KillLogData?): { Disconnect: () -> () }
	if not RunService:IsServer() then
		error("Death.onKillLogRequest can only be called on the server")
	end
	local Blink = require(script.Parent.Generated.Server)
	Blink.Death.RequestKillLog.On(callback)
	return NOOP_CONNECTION
end

function Death.init(): ()
end

return Death
