--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)

local NetworkDispatcher = {}

type NetworkHealData = {
	targetId: number,
	healAmount: number,
	pos: Vector3,
}

type PendingShotHit = {
	targetId: number,
	damage: number,
	head: boolean,
	hitPos: Vector3,
	bodyPart: number,
	gunIndex: number,
	origin: Vector3,
	target: Vector3,
	clientFireTime: number,
}

local MAX_HEALS = 256
local HEAL_ENTRY_SIZE = 24
local healBuffer: buffer = buffer.create(MAX_HEALS * HEAL_ENTRY_SIZE)
local healQueueSize: number = 0

local healSendPool: { NetworkHealData } = {}

local heartbeatConnection: RBXScriptConnection? = nil

local pendingShotHit: PendingShotHit = {
	targetId = 0, damage = 0, head = false, hitPos = Vector3.zero,
	bodyPart = 2, gunIndex = 1, origin = Vector3.zero, target = Vector3.zero,
	clientFireTime = 0,
}
local hasPendingShotHit: boolean = false
local shotHitSent: boolean = false

local replicateSingle: { { origin: Vector3, target: Vector3, gunIndex: number } } = {
	{ origin = Vector3.zero, target = Vector3.zero, gunIndex = 0 },
}

local MAX_PELLET_REPLICATES = 12
local replicateBatch: { { origin: Vector3, target: Vector3, gunIndex: number } } = table.create(MAX_PELLET_REPLICATES)
for i = 1, MAX_PELLET_REPLICATES do
	replicateBatch[i] = { origin = Vector3.zero, target = Vector3.zero, gunIndex = 0 }
end
local replicateBatchSize: number = 0

local function ensureHeartbeatRunning(): ()
	if not heartbeatConnection and healQueueSize > 0 then
		heartbeatConnection = RunService.Heartbeat:Connect(function()
			debug.profilebegin("GunService::networkDispatch")
			NetworkDispatcher.flushHeals()
			if healQueueSize == 0 and heartbeatConnection then
				heartbeatConnection:Disconnect()
				heartbeatConnection = nil
			end
			debug.profileend()
		end)
	end
end

function NetworkDispatcher.init(): ()
end

function NetworkDispatcher.stageHit(hit: { target: Humanoid, damage: number, head: boolean, pos: Vector3, normal: Vector3, bodyPartIndex: number, localOffset: Vector3 }, gunIndex: number, clientFireTime: number): ()
	local targetChar = hit.target.Parent
	if not targetChar then return end

	local player = Players:GetPlayerFromCharacter(targetChar)
	local targetId = if player then player.UserId else 0

	pendingShotHit.targetId = targetId
	pendingShotHit.damage = hit.damage
	pendingShotHit.head = hit.head
	pendingShotHit.hitPos = hit.localOffset
	pendingShotHit.bodyPart = hit.bodyPartIndex
	pendingShotHit.gunIndex = gunIndex
	pendingShotHit.origin = Vector3.zero
	pendingShotHit.target = Vector3.zero
	pendingShotHit.clientFireTime = clientFireTime
	hasPendingShotHit = true
	shotHitSent = false
end

function NetworkDispatcher.queueReplicate(origin: Vector3, target: Vector3, gunIndex: number, _clientFireTime: number?): ()
	if hasPendingShotHit and not shotHitSent then
		pendingShotHit.origin = origin
		pendingShotHit.target = target
		Network.Gun.sendShotHit(
			pendingShotHit.targetId,
			pendingShotHit.damage,
			pendingShotHit.head,
			pendingShotHit.hitPos,
			pendingShotHit.bodyPart,
			pendingShotHit.gunIndex,
			origin,
			target,
			pendingShotHit.clientFireTime
		)
		shotHitSent = true
		hasPendingShotHit = false
		return
	end

	replicateSingle[1].origin = origin
	replicateSingle[1].target = target
	replicateSingle[1].gunIndex = gunIndex
	Network.Gun.sendReplicate(replicateSingle, 1)
end

function NetworkDispatcher.stagePelletReplicate(origin: Vector3, target: Vector3, gunIndex: number, _clientFireTime: number?): ()
	replicateBatchSize += 1
	local entry = replicateBatch[replicateBatchSize]
	entry.origin = origin
	entry.target = target
	entry.gunIndex = gunIndex
end

function NetworkDispatcher.flushPelletReplicates(): ()
	if replicateBatchSize == 0 then return end
	Network.Gun.sendReplicate(replicateBatch, replicateBatchSize)
	replicateBatchSize = 0
end

function NetworkDispatcher.queueHeal(targetId: number, healAmount: number, pos: Vector3): ()
	if healQueueSize >= MAX_HEALS then
		return
	end

	local offset = healQueueSize * HEAL_ENTRY_SIZE
	buffer.writef64(healBuffer, offset, targetId)
	buffer.writef32(healBuffer, offset + 8, healAmount)
	buffer.writef32(healBuffer, offset + 12, pos.X)
	buffer.writef32(healBuffer, offset + 16, pos.Y)
	buffer.writef32(healBuffer, offset + 20, pos.Z)
	healQueueSize += 1
	ensureHeartbeatRunning()
end

function NetworkDispatcher.flushHeals(): ()
	if healQueueSize == 0 then
		return
	end

	for i = 1, healQueueSize do
		local offset = (i - 1) * HEAL_ENTRY_SIZE
		local entry = healSendPool[i]
		if not entry then
			entry = { targetId = 0, healAmount = 0, pos = Vector3.zero }
			healSendPool[i] = entry
		end
		entry.targetId = buffer.readf64(healBuffer, offset)
		entry.healAmount = buffer.readf32(healBuffer, offset + 8)
		entry.pos = Vector3.new(
			buffer.readf32(healBuffer, offset + 12),
			buffer.readf32(healBuffer, offset + 16),
			buffer.readf32(healBuffer, offset + 20)
		)
	end

	Network.Gun.sendHeals(healSendPool, healQueueSize)
	healQueueSize = 0
end

function NetworkDispatcher.cleanup(): ()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	healQueueSize = 0
	replicateBatchSize = 0
	hasPendingShotHit = false
	shotHitSent = false

	table.clear(healSendPool)
end

return NetworkDispatcher
