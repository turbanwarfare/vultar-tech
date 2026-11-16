--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent.Parent
local PhaseConfig = require(MainModule.Shared.Config.PhaseConfig)
local Network = require(MainModule.Shared.Network)

local GameState = require(script.Parent.GameState)
local DoorController = require(script.Parent.DoorController)

type State = GameState.GameState
type PathNode = GameState.PathNode

local NODE_ORDER: { [string]: number } = {
	Node1 = 1,
	Node2 = 2,
	Node3 = 3,
	Node4 = 4,
	Node5 = 5,
	Node6 = 6,
	Node7 = 7,
	Node8 = 8,
	Node9 = 9,
	Node10 = 10,
	Node11 = 11,
	Node12 = 12,
	Node13 = 13,
	Node14 = 14,
	TermNode1 = 15,
	Node15 = 16,
	Node16 = 17,
	Node17 = 18,
	Node18 = 19,
	Node19 = 20,
	Node20 = 21,
	Node21 = 22,
	Node22 = 23,
	TermNode2 = 24,
}

local DOOR_BLOCK_COOLDOWN = 10
local AT_NODE_DIST_SQ = 25
local DOOR_DOT_THRESHOLD = 0.3
local DOOR_HORIZ_PADDING = 8
local DIRECTION_MIN_MAGNITUDE_SQ = 0.01 * 0.01
local BROADCAST_INTERVAL = 0.1
local FACTION_COUNT_INTERVAL = 0.05
local PAYLOAD_POSITION_RESPONSIVENESS = 200
local PAYLOAD_ORIENTATION_RESPONSIVENESS = 10
local PAYLOAD_DENSITY = 100

type PathCache = {
	segmentLengths: { number },
	cumulativeDistances: { number },
	totalDistance: number,
}

export type PayloadCallbacks = {
	getPlayerFaction: (player: Player) -> string?,
	countFactionsOnPayload: (parts: { BasePart }) -> (number, number),
	broadcastMessage: (message: string) -> (),
	broadcastPhaseState: () -> (),
	advancePhase: () -> (),
	stopHeartbeat: () -> (),
	beginConquest: (nodeName: string, config: PhaseConfig.PhaseDefinition) -> (),
	resetConquestState: () -> (),
	updateConquest: (dt: number, config: PhaseConfig.PhaseDefinition, nodePosition: Vector3) -> (),
}

local PayloadController = {}

local function buildPathCache(nodes: { PathNode }, startIdx: number, endIdx: number): PathCache
	local segCount = endIdx - startIdx
	local segmentLengths = table.create(segCount)
	local cumulativeDistances = table.create(segCount + 1)
	cumulativeDistances[1] = 0
	local total = 0
	for i = 1, segCount do
		local len = (nodes[startIdx + i].Position - nodes[startIdx + i - 1].Position).Magnitude
		segmentLengths[i] = len
		total += len
		cumulativeDistances[i + 1] = total
	end
	return {
		segmentLengths = segmentLengths,
		cumulativeDistances = cumulativeDistances,
		totalDistance = total,
	}
end

local function findSegmentIndex(cumulativeDists: { number }, targetDist: number, segCount: number): number
	local lo, hi = 1, segCount
	while lo < hi do
		local mid = bit32.rshift(lo + hi, 1)
		if cumulativeDists[mid + 1] < targetDist then
			lo = mid + 1
		else
			hi = mid
		end
	end
	return lo
end

function PayloadController.cachePathNodes(state: State): ()
	local folder = workspace:FindFirstChild("PathNodes")
	if not folder then
		return
	end

	table.clear(state.sortedPathNodes)
	table.clear(state.nodePositionByName)

	for _, node in folder:GetChildren() do
		local order = NODE_ORDER[node.Name]
		if order and node:IsA("BasePart") then
			table.insert(state.sortedPathNodes, {
				Name = node.Name,
				Position = node.Position,
				Order = order,
			})
			state.nodePositionByName[node.Name] = node.Position
		end
	end

	table.sort(state.sortedPathNodes, function(a, b)
		return a.Order < b.Order
	end)
end

function PayloadController.getNodeIndexForPhase(state: State, phaseId: PhaseConfig.PhaseId): (number?, number?)
	local config = PhaseConfig.getPhase(phaseId)
	if not config or not config.PayloadStartNode or not config.PayloadEndNode then
		return nil, nil
	end

	local startOrder = NODE_ORDER[config.PayloadStartNode]
	local endOrder = NODE_ORDER[config.PayloadEndNode]
	if not startOrder or not endOrder then
		return nil, nil
	end

	local startIdx, endIdx = nil :: number?, nil :: number?
	for i, node in state.sortedPathNodes do
		if node.Order == startOrder then
			startIdx = i
		end
		if node.Order == endOrder then
			endIdx = i
		end
	end

	if not startIdx or not endIdx then
		return nil, nil
	end
	return startIdx, endIdx
end

function PayloadController.getPayloadCFrame(state: State, progress: number, startIdx: number, endIdx: number, pathCache: PathCache): CFrame
	if endIdx <= startIdx or pathCache.totalDistance <= 0 then
		return CFrame.new(state.sortedPathNodes[startIdx].Position)
	end

	local targetDist = math.clamp(progress, 0, 1) * pathCache.totalDistance
	local segCount = endIdx - startIdx
	local segIdx = findSegmentIndex(pathCache.cumulativeDistances, targetDist, segCount)

	local fromPos = state.sortedPathNodes[startIdx + segIdx - 1].Position
	local toPos = state.sortedPathNodes[startIdx + segIdx].Position
	local segLen = pathCache.segmentLengths[segIdx]
	local accumulated = pathCache.cumulativeDistances[segIdx]

	local alpha = if segLen > 0 then (targetDist - accumulated) / segLen else 0
	local pos = fromPos:Lerp(toPos, alpha)
	local direction = toPos - fromPos
	if direction.X * direction.X + direction.Y * direction.Y + direction.Z * direction.Z < DIRECTION_MIN_MAGNITUDE_SQ then
		return CFrame.new(pos)
	end
	return CFrame.lookAt(pos, pos + direction) * CFrame.Angles(0, math.pi, 0)
end

function PayloadController.isPayloadAtNode(state: State, nodeName: string): boolean
	if not state.payloadModel then
		return false
	end
	local nodePos = state.nodePositionByName[nodeName]
	if not nodePos then
		return false
	end
	local delta = state.payloadModel.Position - nodePos
	return delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z < AT_NODE_DIST_SQ
end

local function attachPayloadMarker(payloadInstance: Instance, enabled: boolean): ()
	local markerPart = payloadInstance:FindFirstChild("PayloadMarker") :: BasePart?
	if not markerPart then
		markerPart = if payloadInstance:IsA("Model") then payloadInstance.PrimaryPart else payloadInstance :: BasePart
	end
	if not markerPart then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PayloadMarkerBillboard"
	billboard.Size = UDim2.fromOffset(25, 25)
	billboard.StudsOffset = Vector3.new(0, 10, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Enabled = enabled
	billboard.MaxDistance = 1e6

	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.Image = "rbxassetid://107116062425826"
	icon.ImageColor3 = Color3.fromRGB(255, 93, 93)
	icon.ImageTransparency = 0.6
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = billboard

	billboard.Parent = markerPart
end

local COLLISION_GROUP_PAYLOAD = "Payload"

local function applyPayloadCollisionGroup(instance: Instance): ()
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = COLLISION_GROUP_PAYLOAD
			descendant.CanQuery = true
		end
	end
	if instance:IsA("BasePart") then
		instance.CollisionGroup = COLLISION_GROUP_PAYLOAD
		instance.CanQuery = true
	end
end

local function setupPayloadPhysics(state: State, rootPart: BasePart, targetCFrame: CFrame): ()
	rootPart.CanCollide = true
	rootPart.CanTouch = true
	rootPart.CanQuery = true
	rootPart.CFrame = targetCFrame
	rootPart.CustomPhysicalProperties = PhysicalProperties.new(PAYLOAD_DENSITY, 1, 0, 1, 0)

	local attachment = Instance.new("Attachment")
	attachment.Name = "PayloadAttachment"
	attachment.Parent = rootPart

	local alignPos = Instance.new("AlignPosition")
	alignPos.Attachment0 = attachment
	alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPos.MaxForce = math.huge
	alignPos.Responsiveness = PAYLOAD_POSITION_RESPONSIVENESS
	alignPos.Position = targetCFrame.Position
	alignPos.Parent = rootPart

	local alignOri = Instance.new("AlignOrientation")
	alignOri.Attachment0 = attachment
	alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOri.MaxTorque = math.huge
	alignOri.Responsiveness = PAYLOAD_ORIENTATION_RESPONSIVENESS
	alignOri.CFrame = targetCFrame
	alignOri.Parent = rootPart

	state.payloadAlignPos = alignPos
	state.payloadAlignOri = alignOri

	rootPart.Anchored = false
	rootPart:SetNetworkOwner(nil)
end

function PayloadController.spawnPayload(state: State, startIdx: number, endIdx: number, pathCache: PathCache, getModelsService: () -> any?): ()
	local modelsSvc = getModelsService()
	if not modelsSvc then
		warn("[PayloadController] ModelsService not available")
		return
	end

	local payloadClone = modelsSvc:Clone("Payload")
	if not payloadClone then
		warn("[PayloadController] Failed to clone Payload model")
		return
	end

	local initialCFrame = PayloadController.getPayloadCFrame(state, 0, startIdx, endIdx, pathCache)

	if payloadClone:IsA("Model") and not payloadClone.PrimaryPart then
		local firstPart = payloadClone:FindFirstChildWhichIsA("BasePart", true)
		if firstPart then
			payloadClone.PrimaryPart = firstPart
		end
	end

	local primaryPart = if payloadClone:IsA("Model") then payloadClone.PrimaryPart else nil
	if payloadClone:IsA("Model") and primaryPart then
		for _, descendant in payloadClone:GetDescendants() do
			if descendant:IsA("BasePart") and descendant ~= primaryPart then
				descendant.Anchored = false
				descendant.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primaryPart
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end

		payloadClone:PivotTo(initialCFrame)
		payloadClone.Parent = workspace
		applyPayloadCollisionGroup(payloadClone)
		setupPayloadPhysics(state, primaryPart, initialCFrame)
		state.payloadModel = primaryPart
		attachPayloadMarker(payloadClone, not state.waitingForTrainDelivery)
	elseif payloadClone:IsA("BasePart") then
		payloadClone.Parent = workspace
		applyPayloadCollisionGroup(payloadClone)
		setupPayloadPhysics(state, payloadClone, initialCFrame)
		state.payloadModel = payloadClone
		attachPayloadMarker(payloadClone, not state.waitingForTrainDelivery)
	end
end

function PayloadController.setMarkerEnabled(state: State, enabled: boolean): ()
	if not state.payloadModel then
		return
	end

	local parent = state.payloadModel.Parent
	local searchRoot = if parent and parent ~= workspace then parent else state.payloadModel

	local billboard = searchRoot:FindFirstChild("PayloadMarkerBillboard", true)
	if billboard and billboard:IsA("BillboardGui") then
		billboard.Enabled = enabled
	end
end

function PayloadController.cleanupPayload(state: State): ()
	state.payloadAlignPos = nil
	state.payloadAlignOri = nil

	if state.payloadModel then
		local parent = state.payloadModel.Parent
		if parent and parent ~= workspace then
			parent:Destroy()
		elseif state.payloadModel.Parent then
			state.payloadModel:Destroy()
		end
		state.payloadModel = nil
	end
	state.payloadProgress = 0
	state.payloadMaxProgress = 0
end

local function cacheDoorReference(): BasePart?
	local doorsFolder = workspace:FindFirstChild("Doors")
	if not doorsFolder then
		return nil
	end

	local bigDoor = doorsFolder:FindFirstChild("BigLobbyDoor")
	if not bigDoor then
		return nil
	end

	for _, child in bigDoor:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "Button" then
			return child :: BasePart
		end
	end
	return nil
end

local function isDoorBlockingCached(payloadPos: Vector3, forwardDir: Vector3, doorPart: BasePart): boolean
	if DoorController.isDoorOpen("BigLobbyDoor") then
		return false
	end

	local doorPos = doorPart.Position
	local dirToDoor = (doorPos - payloadPos).Unit
	if forwardDir:Dot(dirToDoor) < DOOR_DOT_THRESHOLD then
		return false
	end

	local dx = payloadPos.X - doorPos.X
	local dz = payloadPos.Z - doorPos.Z
	local horizDistSq = dx * dx + dz * dz
	local doorSize = doorPart.Size
	local doorRadius = math.max(doorSize.X, doorSize.Z) / 2
	local threshold = doorRadius + DOOR_HORIZ_PADDING
	return horizDistSq <= threshold * threshold
end

function PayloadController.beginPayloadEscort(state: State, callbacks: PayloadCallbacks, getModelsService: () -> any?): ()
	local config = PhaseConfig.getPhase(state.currentPhase)
	if not config or not config.HasPayload then
		return
	end

	local spawnedForPhase = state.currentPhase

	local startIdx, endIdx = PayloadController.getNodeIndexForPhase(state, state.currentPhase)
	if not startIdx or not endIdx then
		warn("[PayloadController] Path nodes not found for " .. state.currentPhase)
		return
	end

	local pathCache = buildPathCache(state.sortedPathNodes, startIdx, endIdx)
	if pathCache.totalDistance <= 0 then
		return
	end

	state.termTimeRemaining = config.TermTime
	state.payloadProgress = 0
	state.payloadMaxProgress = 1
	state.overtime = false
	callbacks.resetConquestState()

	while state.waitingForTrainDelivery do
		task.wait(0.5)
		if not state.official then
			return
		end
		if state.currentPhase ~= spawnedForPhase then
			return
		end
	end

	if state.currentPhase ~= spawnedForPhase then
		return
	end

	PayloadController.setMarkerEnabled(state, true)
	PayloadController.spawnPayload(state, startIdx, endIdx, pathCache, getModelsService)

	local payloadParts: { BasePart } = {}
	if state.payloadModel then
		local parent = state.payloadModel.Parent
		if parent and parent:IsA("Model") then
			for _, desc in parent:GetDescendants() do
				if desc:IsA("BasePart") then
					table.insert(payloadParts, desc)
				end
			end
		else
			table.insert(payloadParts, state.payloadModel)
		end
	end

	local payloadSpeed = config.PayloadSpeed or 7
	local termNodeName = config.PayloadEndNode
	local payloadStarted = false
	local lastDoorBlockMessage = 0
	local payloadBroadcastTimer = 0

	local cachedForwardDir: Vector3? = nil
	local cachedBigDoorPart = cacheDoorReference()

	local cachedRaiders = 0
	local cachedDefenders = 0
	local factionCountTimer = 0
	local wasConquestActive = false

	callbacks.stopHeartbeat()
	state.heartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
		debug.profilebegin("PayloadController::heartbeat")
		if not state.official or state.currentPhase == "idle" or state.currentPhase == "ended" then
			debug.profileend()
			return
		end
		if state.waitingForTrainDelivery then
			debug.profileend()
			return
		end

		if state.conquestActive then
			wasConquestActive = true
			local nodePos = state.nodePositionByName[state.conquestNode :: string]
			if nodePos then
				callbacks.updateConquest(dt, config, nodePos)
			end
			return
		end

		if not state.payloadModel then
			return
		end

		if wasConquestActive then
			wasConquestActive = false
			cachedRaiders = 0
			cachedDefenders = 0
			factionCountTimer = FACTION_COUNT_INTERVAL
		end

		factionCountTimer += dt
		if factionCountTimer >= FACTION_COUNT_INTERVAL then
			factionCountTimer = 0
			cachedRaiders, cachedDefenders = callbacks.countFactionsOnPayload(payloadParts)
		end

		local netPower = cachedRaiders - cachedDefenders

		local isAtConquestNode = termNodeName ~= nil and PayloadController.isPayloadAtNode(state, termNodeName)
		local canPushBack = state.defendersPushbackEnabled or not isAtConquestNode
		local wasPushbackEnabled = state.defendersPushbackEnabled

		if cachedBigDoorPart and cachedForwardDir and netPower > 0 then
			local payloadPos = state.payloadModel.Position
			if isDoorBlockingCached(payloadPos, cachedForwardDir, cachedBigDoorPart) then
				local now = os.clock()
				if now - lastDoorBlockMessage >= DOOR_BLOCK_COOLDOWN then
					lastDoorBlockMessage = now
					callbacks.broadcastMessage("PAYLOAD BLOCKED BY CLOSED DOOR!")
				end
				netPower = 0
			end
		end

		if netPower > 0 then
			local progressDelta = (payloadSpeed * dt) / pathCache.totalDistance
			state.payloadProgress = math.min(state.payloadProgress + progressDelta, 1)
			if state.defendersPushbackEnabled then
				state.defendersPushbackEnabled = false
				state.conquestTimerRestored = false
				callbacks.broadcastMessage("DEFENDERS LOST PUSHBACK ABILITY - HOSTILES ADVANCING!")
			end
		elseif netPower < 0 and canPushBack then
			local progressDelta = (payloadSpeed * dt) / pathCache.totalDistance
			state.payloadProgress = math.max(state.payloadProgress - progressDelta, 0)
		end

		if state.payloadProgress > 0 then
			payloadStarted = true
		end

		local targetCF = PayloadController.getPayloadCFrame(state, state.payloadProgress, startIdx, endIdx, pathCache)
		if state.payloadAlignPos then
			state.payloadAlignPos.Position = targetCF.Position
		end
		if state.payloadAlignOri then
			state.payloadAlignOri.CFrame = targetCF
		end
		cachedForwardDir = -targetCF.LookVector

		if termNodeName ~= nil then
			local nodePos = state.nodePositionByName[termNodeName]
			if nodePos then
				local delta = targetCF.Position - nodePos
				isAtConquestNode = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z < AT_NODE_DIST_SQ
			end
		end

		if isAtConquestNode and not wasPushbackEnabled then
			callbacks.beginConquest(termNodeName :: string, config)
		end

		if state.payloadProgress >= 1 and not state.conquestActive and not isAtConquestNode then
			callbacks.broadcastMessage("PAYLOAD REACHED THE END OF THE PATH!")
			Network.Phase.broadcastPayloadProgress(state.payloadProgress, state.payloadMaxProgress, netPower)
			callbacks.broadcastPhaseState()
			debug.profileend()
			callbacks.advancePhase()
			return
		elseif state.payloadProgress <= 0 and payloadStarted then
			payloadStarted = false
			callbacks.resetConquestState()
			state.defendersPushbackEnabled = false
			callbacks.broadcastMessage("PAYLOAD HAS BEEN ROLLED BACK TO THE START!")
			Network.Phase.broadcastPayloadProgress(state.payloadProgress, state.payloadMaxProgress, netPower)
			callbacks.broadcastPhaseState()
		elseif not state.conquestActive then
			payloadBroadcastTimer += dt
			if payloadBroadcastTimer >= BROADCAST_INTERVAL then
				payloadBroadcastTimer = 0
				Network.Phase.broadcastPayloadProgress(state.payloadProgress, state.payloadMaxProgress, netPower)
			end
		end
		debug.profileend()
	end)
end

return PayloadController
