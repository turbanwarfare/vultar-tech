--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Gun = {}

local NOOP_CONNECTION = { Disconnect = function() end }

local mediBeamState: { [number]: { action: string, targetId: number?, lastBroadcast: number } } = {}
local MEDI_BROADCAST_THROTTLE = 0.3
local connections: { RBXScriptConnection } = {}

function Gun.init(): ()
	if RunService:IsServer() then
		table.insert(connections, Players.PlayerRemoving:Connect(function(player)
			mediBeamState[player.UserId] = nil
		end))
	end
end

function Gun.Cleanup(): ()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	table.clear(mediBeamState)
end

function Gun.sendShotHit(targetId: number, damage: number, head: boolean, localOffset: Vector3, bodyPart: number, gunIndex: number, origin: Vector3, target: Vector3, clientFireTime: number): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Gun.ShotHit.Fire(targetId, damage, head, localOffset, bodyPart, gunIndex, origin, target, clientFireTime)
end

function Gun.onShotHit(callback: (player: Player, targetId: number, damage: number, head: boolean, localOffset: Vector3, bodyPart: number, gunIndex: number, origin: Vector3, target: Vector3, clientFireTime: number) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Gun.ShotHit.On(callback)
	return NOOP_CONNECTION
end

function Gun.sendHits(gunIndex: number, hits: { { targetId: number, damage: number, head: boolean, pos: Vector3, bodyPart: number } }, count: number?, clientFireTime: number?): ()
	local Blink = require(script.Parent.Generated.Client)
	if count then
		for i = count + 1, #hits do
			hits[i] = nil :: any
		end
	end
	Blink.Gun.Hits.Fire(gunIndex, hits, clientFireTime or 0)
end

function Gun.onHits(callback: (player: Player, hits: { { targetId: number, damage: number, head: boolean, pos: Vector3, bodyPart: number? } }, count: number, gunIndex: number, clientFireTime: number) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Gun.Hits.On(function(player: Player, receivedGunIndex: number, hits: any, clientFireTime: number)
		local count = if type(hits) == "table" then #hits else 0
		callback(player, hits, count, receivedGunIndex, clientFireTime)
	end)
	return NOOP_CONNECTION
end

function Gun.sendReplicate(replicateData: { { origin: Vector3, target: Vector3, gunIndex: number } }, count: number?): ()
	local Blink = require(script.Parent.Generated.Client)
	if count then
		for i = count + 1, #replicateData do
			replicateData[i] = nil :: any
		end
	end
	Blink.Gun.ReplicateToServer.Fire(replicateData)
end

function Gun.onReplicate(callback: (player: Player, data: { { origin: Vector3, target: Vector3, gunIndex: number } }, count: number) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Gun.ReplicateToServer.On(function(player: Player, data: any)
		local count = if type(data) == "table" then #data else 0
		callback(player, data, count)
	end)
	return NOOP_CONNECTION
end

function Gun.sendReplicateToClient(player: Player, data: { origin: Vector3, target: Vector3, gunIndex: number }): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Gun.ReplicateToClient.Fire(player, data)
end

function Gun.sendReplicateBatchToClient(player: Player, batch: { { origin: Vector3, target: Vector3, gunIndex: number, shooterId: number } }, count: number?): ()
	local Blink = require(script.Parent.Generated.Server)
	if count then
		for i = count + 1, #batch do
			batch[i] = nil :: any
		end
	end
	Blink.Gun.ReplicateToClient.Fire(player, batch)
end

function Gun.broadcastReplicateAll(batch: { { origin: Vector3, target: Vector3, gunIndex: number, shooterId: number } }, count: number?): ()
	local Blink = require(script.Parent.Generated.Server)
	if count then
		for i = count + 1, #batch do
			batch[i] = nil :: any
		end
	end
	Blink.Gun.ReplicateToClient.FireAll(batch)
end

function Gun.onReplicateReceived(callback: (data: { origin: Vector3, target: Vector3, gunIndex: number, shooterId: number? } | { { origin: Vector3, target: Vector3, gunIndex: number, shooterId: number } }, count: number?) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Gun.ReplicateToClient.On(function(data: any)
		if type(data) == "table" and data[1] then
			callback(data, #data)
		else
			callback(data, nil)
		end
	end)
	return NOOP_CONNECTION
end

function Gun.broadcastKill(killData: { killer: number, victim: number, headshot: boolean, weapon: number, killerHealth: number }): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Gun.Kill.FireAll(killData)
end

local killCallbacks: { (data: { killer: number, victim: number, headshot: boolean, weapon: number, killerHealth: number }) -> () } = {}
local killRegistered = false

function Gun.onKill(callback: (data: { killer: number, victim: number, headshot: boolean, weapon: number, killerHealth: number }) -> ()): { Disconnect: () -> () }
	table.insert(killCallbacks, callback)

	if not killRegistered then
		killRegistered = true
		local Blink = require(script.Parent.Generated.Client)
		Blink.Gun.Kill.On(function(data: any)
			for _, cb in killCallbacks do
				task.spawn(cb, data)
			end
		end)
	end

	return {
		Disconnect = function()
			local index = table.find(killCallbacks, callback)
			if not index then return end
			local lastIndex = #killCallbacks
			if index < lastIndex then
				killCallbacks[index] = killCallbacks[lastIndex]
			end
			killCallbacks[lastIndex] = nil
		end,
	}
end

function Gun.sendHeals(heals: { { targetId: number, healAmount: number, pos: Vector3 } }, count: number?): ()
	local Blink = require(script.Parent.Generated.Client)
	if count then
		for i = count + 1, #heals do
			heals[i] = nil :: any
		end
	end
	Blink.Gun.Heals.Fire(heals)
end

function Gun.onHeals(callback: (player: Player, heals: { { targetId: number, healAmount: number, pos: Vector3 } }, count: number) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Gun.Heals.On(function(player: Player, heals: any)
		local count = if type(heals) == "table" then #heals else 0
		callback(player, heals, count)
	end)
	return NOOP_CONNECTION
end

function Gun.sendMediBeamStart(targetId: number): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Gun.MediBeamToServer.Fire("start", targetId)
end

function Gun.sendMediBeamStop(): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Gun.MediBeamToServer.Fire("stop", nil)
end

function Gun.onMediBeam(callback: (player: Player, action: string, targetId: number?) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Gun.MediBeamToServer.On(callback)
	return NOOP_CONNECTION
end

function Gun.broadcastMediBeam(excludePlayer: Player, healerId: number, action: string, targetId: number?): ()
	local now = os.clock()
	local state = mediBeamState[healerId]

	local shouldBroadcast = not state
		or state.action ~= action
		or state.targetId ~= targetId
		or (now - state.lastBroadcast) >= MEDI_BROADCAST_THROTTLE

	if not shouldBroadcast then
		return
	end

	if state then
		state.action = action
		state.targetId = targetId
		state.lastBroadcast = now
	else
		mediBeamState[healerId] = { action = action, targetId = targetId, lastBroadcast = now }
	end

	local Blink = require(script.Parent.Generated.Server)
	local players = Players:GetPlayers()
	local playerCount = #players

	if playerCount <= 1 then
		return
	end

	if playerCount == 2 then
		for i = 1, 2 do
			local player = players[i]
			if player ~= excludePlayer then
				Blink.Gun.MediBeamToClient.Fire(player, healerId, action, targetId)
				return
			end
		end
		return
	end

	for i = 1, playerCount do
		local player = players[i]
		if player ~= excludePlayer then
			Blink.Gun.MediBeamToClient.Fire(player, healerId, action, targetId)
		end
	end
end

function Gun.clearMediBeamState(healerId: number): ()
	mediBeamState[healerId] = nil
end

function Gun.onMediBeamReceived(callback: (healerId: number, action: string, targetId: number?) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Gun.MediBeamToClient.On(callback)
	return NOOP_CONNECTION
end

function Gun.sendLowCharge(): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Gun.LowChargeToServer.Fire(nil)
end

function Gun.onLowCharge(callback: (player: Player) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Gun.LowChargeToServer.On(function(player: Player)
		callback(player)
	end)
	return NOOP_CONNECTION
end

function Gun.sendLowChargeToClient(player: Player, healerId: number): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Gun.LowChargeToClient.Fire(player, healerId)
end

function Gun.onLowChargeReceived(callback: (healerId: number) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Gun.LowChargeToClient.On(callback)
	return NOOP_CONNECTION
end

return Gun
