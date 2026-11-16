--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)

local ReplicationManager = {}

local MAX_QUEUE_SIZE = 512
local QUEUE_ENTRY_SIZE = 25
local queueBuffer: buffer = buffer.create(MAX_QUEUE_SIZE * QUEUE_ENTRY_SIZE)
local queueShooters: { Player } = {}
local queueSize: number = 0

local heartbeatConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil

local MAX_ORIGIN_DISTANCE = 50
local MAX_ORIGIN_DISTANCE_SQ = MAX_ORIGIN_DISTANCE * MAX_ORIGIN_DISTANCE
local playerRootCache: { [Player]: BasePart? } = {}
local characterConns: { [Player]: RBXScriptConnection } = {}

local function cachePlayerRoot(player: Player): ()
	local character = player.Character
	if not character then
		playerRootCache[player] = nil
		return
	end
	playerRootCache[player] = character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function watchPlayerCharacter(player: Player): ()
	local existing = characterConns[player]
	if existing then
		existing:Disconnect()
	end
	characterConns[player] = player.CharacterAdded:Connect(function()
		task.defer(cachePlayerRoot, player)
	end)
	cachePlayerRoot(player)
end

local function getValidatedOrigin(shooter: Player, origin: Vector3): Vector3
	local hrp = playerRootCache[shooter]
	if not hrp or not hrp.Parent then
		return origin
	end

	local delta = origin - hrp.Position
	if delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z > MAX_ORIGIN_DISTANCE_SQ then
		return hrp.Position + hrp.CFrame.LookVector * 2
	end

	return origin
end

function ReplicationManager.init(): ()
	for _, player in Players:GetPlayers() do
		watchPlayerCharacter(player)
	end

	playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		watchPlayerCharacter(player)
	end)

	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		playerRootCache[player] = nil
		local conn = characterConns[player]
		if conn then
			conn:Disconnect()
			characterConns[player] = nil
		end
	end)

	heartbeatConnection = RunService.Heartbeat:Connect(function()
		if queueSize > 0 then
			debug.profilebegin("ReplicationManager::flush")
			ReplicationManager.flush()
			debug.profileend()
		end
	end)
end

function ReplicationManager.queue(shooter: Player, origin: Vector3, target: Vector3, gunIndex: number): ()
	origin = getValidatedOrigin(shooter, origin)
	if queueSize >= MAX_QUEUE_SIZE then
		return
	end

	queueSize += 1
	local offset = (queueSize - 1) * QUEUE_ENTRY_SIZE

	buffer.writef32(queueBuffer, offset, origin.X)
	buffer.writef32(queueBuffer, offset + 4, origin.Y)
	buffer.writef32(queueBuffer, offset + 8, origin.Z)

	buffer.writef32(queueBuffer, offset + 12, target.X)
	buffer.writef32(queueBuffer, offset + 16, target.Y)
	buffer.writef32(queueBuffer, offset + 20, target.Z)

	buffer.writeu8(queueBuffer, offset + 24, gunIndex)

	queueShooters[queueSize] = shooter
end

local broadcastBatch: { { origin: Vector3, target: Vector3, gunIndex: number, shooterId: number } } = {}
local broadcastCount: number = 0

local MAX_POOL_SIZE = 128
local shotDataPool: { { origin: Vector3, target: Vector3, gunIndex: number, shooterId: number } } = {}
local shotDataPoolSize = 0

local function acquireShotData(
	origin: Vector3,
	target: Vector3,
	gunIndex: number,
	shooterId: number
): { origin: Vector3, target: Vector3, gunIndex: number, shooterId: number }
	if shotDataPoolSize > 0 then
		local data = shotDataPool[shotDataPoolSize]
		shotDataPoolSize -= 1
		data.origin = origin
		data.target = target
		data.gunIndex = gunIndex
		data.shooterId = shooterId
		return data
	end
	return { origin = origin, target = target, gunIndex = gunIndex, shooterId = shooterId }
end

local function releaseShotData(data: { origin: Vector3, target: Vector3, gunIndex: number, shooterId: number }): ()
	if shotDataPoolSize >= MAX_POOL_SIZE then
		return
	end
	shotDataPoolSize += 1
	shotDataPool[shotDataPoolSize] = data
end

function ReplicationManager.flush(): ()
	if queueSize == 0 then
		return
	end

	broadcastCount = 0

	for i = 1, queueSize do
		local offset = (i - 1) * QUEUE_ENTRY_SIZE

		local origin = Vector3.new(
			buffer.readf32(queueBuffer, offset),
			buffer.readf32(queueBuffer, offset + 4),
			buffer.readf32(queueBuffer, offset + 8)
		)

		local target = Vector3.new(
			buffer.readf32(queueBuffer, offset + 12),
			buffer.readf32(queueBuffer, offset + 16),
			buffer.readf32(queueBuffer, offset + 20)
		)

		local gunIndex = buffer.readu8(queueBuffer, offset + 24)
		local shooter = queueShooters[i]

		local shotData = acquireShotData(origin, target, gunIndex, shooter.UserId)
		broadcastCount += 1
		broadcastBatch[broadcastCount] = shotData

		queueShooters[i] = nil :: any
	end

	local MAX_SHOTS_PER_PACKET = 25
	if broadcastCount > 0 then
		local offset = 1
		while offset <= broadcastCount do
			local chunkSize = math.min(MAX_SHOTS_PER_PACKET, broadcastCount - offset + 1)
			local chunk = table.create(chunkSize)
			for j = 1, chunkSize do
				chunk[j] = broadcastBatch[offset + j - 1]
			end
			Network.Gun.broadcastReplicateAll(chunk, chunkSize)
			offset += chunkSize
		end

		for i = 1, broadcastCount do
			releaseShotData(broadcastBatch[i])
			broadcastBatch[i] = nil :: any
		end
	end

	queueSize = 0
end

function ReplicationManager.cleanup(): ()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	if playerAddedConnection then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end

	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end

	for player, conn in characterConns do
		conn:Disconnect()
		characterConns[player] = nil
	end

	table.clear(playerRootCache)

	for i = 1, queueSize do
		queueShooters[i] = nil :: any
	end
	queueSize = 0

	table.clear(broadcastBatch)
	broadcastCount = 0
	table.clear(shotDataPool)
	shotDataPoolSize = 0
end

return ReplicationManager
