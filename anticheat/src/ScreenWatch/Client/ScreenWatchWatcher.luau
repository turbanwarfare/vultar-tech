--!strict
--!native
--!optimize 2

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Root = script:FindFirstAncestor("Client").Parent
local MainModule = require(Root.Shared.Game).get()
local SWTypes = require(Root.Shared.Network.Types)
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Trove = require(Packages:WaitForChild("Trove", 5))
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local Network = { ScreenWatch = require(Root.Shared.Network) }
local FactionUtils = require(MainModule.Shared.Utils.Game.FactionUtils)

local function getCurrentCamera(): Camera?
	return workspace.CurrentCamera
end

local DEFAULT_CURSOR_ID = "rbxassetid://131581677"
local NUM_TRAIL_NODES = 24
local COLOR_GHOST_TEAMMATE = Color3.fromRGB(50, 230, 90)
local COLOR_GHOST_ENEMY = Color3.fromRGB(255, 55, 55)
local PLAYBACK_DELAY = 0.06
local SNAPSHOT_CAPACITY = 2400
local TELEPORT_DISTANCE_SQ = 30 * 30
local CLOCK_OFFSET_RELAX = 0.001
local LAG_THRESHOLD = 0.3
local STATUS_UPDATE_INTERVAL = 0.1
local FLICK_BARS = 60
local TIMELINE_TICKS = 32
local FLICK_SAMPLE_INTERVAL = 1 / 30
local FLICK_MAX_DEG_PER_SEC = 1500
local HIT_MARKER_LIFETIME = 1.5
local HIT_MARKER_MAX_AGE = 0.5
local HIT_MARKER_HISTORY = 200
local INPUT_EVENT_CAPACITY = 4000
local PRE_BUFFER_SLACK = 1
local PRE_BUFFER_TIMEOUT = 4
local SEEK_SECONDS = 5
local SUSPECTS_REMOTE_NAME = "VultarACSuspects"
local BEAM_TRANSPARENCY = NumberSequence.new(0.2)
local BEAM_COLOR = ColorSequence.new(Color3.fromRGB(255, 220, 60))

type FusionValue<T> = any
type FusionUseFn = any

export type CameraSample = {
	cframe: CFrame,
	timestamp: number,
	mouseBehavior: SWTypes.MouseBehaviorMode,
	isSprinting: boolean?,
	isCrouching: boolean?,
}

export type CursorSample = {
	position: Vector2,
	timestamp: number,
	icon: string?,
}

export type KeyHistoryEntry = {
	keyName: string,
	isFlagged: boolean,
	isDown: boolean,
	timestamp: number,
	formattedTime: string,
	isFocusEvent: boolean?,
	isSettingsEvent: boolean?,
}

export type HitHistoryEntry = {
	victimName: string,
	damage: number,
	bodyPart: string,
	isHeadshot: boolean,
	weaponName: string,
	timestamp: number,
	formattedTime: string,
}

export type TrailNodeState = {
	position: FusionValue<UDim2>,
	size: FusionValue<UDim2>,
	visible: FusionValue<boolean>,
	transparency: FusionValue<number>,
}

export type WatcherState = {
	isWatching: FusionValue<boolean>,
	targetUserId: FusionValue<number>,
	targetName: FusionValue<string>,
	cursorPosition: FusionValue<Vector2>,
	cursorIcon: FusionValue<string>,
	cursorSize: FusionValue<Vector2?>,
	playbackStatus: FusionValue<string>,
	playbackPaused: FusionValue<boolean>,
	playbackSpeed: FusionValue<number>,
	timelineSpan: FusionValue<number>,
	timelineRewind: FusionValue<number>,
	timelineTicks: { FusionValue<number> },
	lagStatus: FusionValue<string>,
	acReport: FusionValue<string>,
	flickBars: { FusionValue<number> },
	flickPeak: FusionValue<number>,
	isCursorFree: FusionValue<boolean>,
	isSprinting: FusionValue<boolean>,
	isCrouching: FusionValue<boolean>,
	trailEnabled: FusionValue<boolean>,
	ghostsEnabled: FusionValue<boolean>,
	markersEnabled: FusionValue<boolean>,
	espMode: FusionValue<string>,
	inputsVisible: FusionValue<boolean>,
	hitsVisible: FusionValue<boolean>,
	targetPing: FusionValue<number>,
	targetAvgPing: FusionValue<number>,
	targetPingSpikes: FusionValue<number>,
	targetMatchAccuracy: FusionValue<number>,
	targetFOV: FusionValue<number>,
	targetResolution: FusionValue<Vector2>,
	trailNodes: { TrailNodeState },
	keyStates: { [string]: FusionValue<boolean> },
	mouseStates: { [string]: FusionValue<boolean> },
	keyHistory: FusionValue<{ KeyHistoryEntry }>,
	hitHistory: FusionValue<{ HitHistoryEntry }>,
}

local ScreenWatchWatcher = {}

local scope = Fusion:scoped()

local isWatchingValue = scope:Value(false)
local targetUserIdValue = scope:Value(0)
local targetNameValue = scope:Value("")
local cursorPositionValue = scope:Value(Vector2.zero)
local cursorIconValue = scope:Value(DEFAULT_CURSOR_ID)
local cursorSizeValue = scope:Value(nil :: Vector2?)
local playbackStatusValue = scope:Value("LIVE")
local playbackPausedValue = scope:Value(false)
local playbackSpeedValue = scope:Value(1)
local timelineSpanValue = scope:Value(0)
local timelineRewindValue = scope:Value(0)
local timelineTickValues: { FusionValue<number> } = table.create(TIMELINE_TICKS)
for i = 1, TIMELINE_TICKS do
	timelineTickValues[i] = scope:Value(-1)
end
local lagStatusValue = scope:Value("")
local acReportValue = scope:Value("")
local flickPeakValue = scope:Value(0)
local flickBarValues: { FusionValue<number> } = table.create(FLICK_BARS)
for i = 1, FLICK_BARS do
	flickBarValues[i] = scope:Value(0)
end
local isCursorFreeValue = scope:Value(false)
local isSprintingValue = scope:Value(false)
local isCrouchingValue = scope:Value(false)
local trailEnabledValue = scope:Value(true)
local ghostsEnabledValue = scope:Value(true)
local markersEnabledValue = scope:Value(true)
local espModeValue = scope:Value("TEAM")
local inputsVisibleValue = scope:Value(true)
local hitsVisibleValue = scope:Value(true)
local targetPingValue = scope:Value(0)
local targetAvgPingValue = scope:Value(0)
local targetPingSpikesValue = scope:Value(0)
local targetMatchAccuracyValue = scope:Value(0)
local targetFOVValue = scope:Value(70)
local targetResolutionValue = scope:Value(Vector2.new(1920, 1080))

local trailNodes: { TrailNodeState } = table.create(NUM_TRAIL_NODES)
for i = 1, NUM_TRAIL_NODES do
	trailNodes[i] = {
		position = scope:Value(UDim2.fromOffset(0, 0)),
		size = scope:Value(UDim2.fromOffset(4, 4)),
		visible = scope:Value(false),
		transparency = scope:Value(0),
	}
end

local keyStates: { [string]: FusionValue<boolean> } = {
	["W"] = scope:Value(false),
	["A"] = scope:Value(false),
	["S"] = scope:Value(false),
	["D"] = scope:Value(false),
	["SPRINT"] = scope:Value(false),
	["CROUCH"] = scope:Value(false),
	["ZOOM"] = scope:Value(false),
	["RELOAD"] = scope:Value(false),
	["SPACE"] = scope:Value(false),
}

local mouseStates: { [string]: FusionValue<boolean> } = {
	["LMB"] = scope:Value(false),
	["RMB"] = scope:Value(false),
}

local isSprintingComputed = scope:Computed(function(use: FusionUseFn)
	return use(isSprintingValue) or use(keyStates["SPRINT"])
end)

local isCrouchingComputed = scope:Computed(function(use: FusionUseFn)
	return use(isCrouchingValue) or use(keyStates["CROUCH"])
end)

local keyHistoryValue = scope:Value({})
local hitHistoryValue = scope:Value({})

local activeTrove: any = nil
local savedCameraType: Enum.CameraType? = nil
local savedCameraFOV: number? = nil

local latestMouseBehavior: SWTypes.MouseBehaviorMode = "Default"
local latestIsSprinting: boolean = false
local latestIsCrouching: boolean = false
local latestCursorPos: Vector2 = Vector2.new(0.5, 0.5)
local latestCursorIcon: string = DEFAULT_CURSOR_ID


type CameraSnapshot = { t: number, cframe: CFrame, fov: number, mouseHit: Vector3? }
type CursorSnapshot = { t: number, position: Vector2, icon: string }
local cameraSnapshots: { CameraSnapshot } = {}
local cursorSnapshots: { CursorSnapshot } = {}
local clockOffset: number? = nil
local nativeIconSizes: { [string]: Vector2 | false } = {}
local lastReportedCursorSize: Vector2? = nil

local rewind = 0
local lastRenderTime: number? = nil
local playbackSpeed = 1
local playbackPaused = false
local pendingRewind: number? = nil
local lastCameraReceivedAt = 0
local lastStatusUpdate = 0
local flickAccum = 0
local flickHead = 0
local flickRecent: { number } = table.create(FLICK_BARS, 0)
local hitMarkers: { { t: number, victimId: number, offset: Vector3, head: boolean } } = {}
local activeMarkerVisuals: { { t: number, parts: { BasePart } } } = {}
local markerFolder: Folder? = nil
local inputEvents: { { t: number, name: string, isDown: boolean } } = {}
local inputCursor = 0
local lastInputSampleTime: number? = nil
local pendingRewindAt = 0
local pausedAt: number? = nil
local suspectList: { any } = {}
local suspectById: { [number]: any } = {}
local lastReportedSprinting: boolean? = nil
local lastReportedCrouching: boolean? = nil
local lastReportedFree: boolean? = nil
local lastReportedCursorIcon: string? = nil
local lastReportedFOV: number? = nil
local lastReportedRes: Vector2? = nil
local lastReportedPing: number? = nil
local lastReportedAvgPing: number? = nil
local lastReportedSpikes: number? = nil
local lastReportedAcc: number? = nil

local trailPositions: { Vector2 } = table.create(NUM_TRAIL_NODES, Vector2.zero)
local trailTimestamps: { number } = table.create(NUM_TRAIL_NODES, 0)
local trailHead = 0
local trailCount = 0

local playerTeamCache: { [number]: { isTeammate: boolean, lastChecked: number, player: Player? } } = {}
local activeGhostIds: { [number]: boolean } = {}

local sessionStartTime = 0

local ghostRigFolder: Folder? = nil
local activeGhostModels: { [number]: Model } = {}
local activeGhostColors: { [number]: Color3 } = {}
local hiddenGhosts: { [number]: boolean } = {}
local NO_GHOSTS: { SWTypes.GhostEntry } = table.freeze({})

type BufferedGhostFrame = {
	t: number,
	timestamp: number,
	receivedAt: number,
	ghosts: { SWTypes.GhostEntry },
}
local GHOST_BUFFER_CAPACITY = 2048
local ghostFrames: { BufferedGhostFrame } = {}

local fullSessionKeyHistory: { KeyHistoryEntry } = {}
local fullSessionHitHistory: { HitHistoryEntry } = {}

local pendingKeyEntries: { KeyHistoryEntry } = {}
local keyUpdateScheduled = false

local pendingHitEntries: { HitHistoryEntry } = {}
local hitUpdateScheduled = false

local function applyGhostColor(visual: Model, color: Color3): ()
	for _, desc in visual:GetDescendants() do
		if desc:IsA("BasePart") then
			if desc.Name == "HumanoidRootPart" then
				desc.Transparency = 1
			else
				desc.Color = color
				desc.Transparency = 0.65
			end
		end
	end
end

local function isGhostTeammate(targetPlayer: Player?, ghostPlayer: Player?): boolean
	if not targetPlayer or not ghostPlayer then
		return false
	end
	if targetPlayer == ghostPlayer then
		return true
	end

	if targetPlayer.Team ~= nil and ghostPlayer.Team ~= nil then
		if targetPlayer.Team == ghostPlayer.Team then
			return true
		end
		if targetPlayer.TeamColor == ghostPlayer.TeamColor and ghostPlayer.TeamColor ~= BrickColor.new("Medium stone grey") then
			return true
		end
	end

	return FactionUtils.areSameFaction(targetPlayer, ghostPlayer)
end

local function getOrCreateGhostFolder(): Folder
	if ghostRigFolder and ghostRigFolder.Parent then
		return ghostRigFolder
	end

	local folder = Instance.new("Folder")
	folder.Name = "ScreenWatchGhosts"
	folder.Parent = workspace
	ghostRigFolder = folder
	return folder
end

local function createProceduralR6Ghost(): Model
	local model = Instance.new("Model")
	model.Name = "GhostsModelFallback"

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.CFrame = CFrame.new(0, 0, 0)
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.CanTouch = false
	hrp.CanQuery = false
	hrp.Massless = true
	hrp.Anchored = true
	hrp.CollisionGroup = "Default"
	hrp.Parent = model
	model.PrimaryPart = hrp

	local function addLimb(name: string, size: Vector3, offset: Vector3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = CFrame.new(offset)
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Massless = true
		part.Anchored = true
		part.CollisionGroup = "Default"
		part.Material = Enum.Material.Neon
		part.Color = COLOR_GHOST_ENEMY
		part.Transparency = 0.65
		part.Parent = model

		if name == "Head" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Head
			mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
			mesh.Parent = part
		end
		return part
	end

	addLimb("Torso", Vector3.new(2, 2, 1), Vector3.zero)
	addLimb("Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0))
	addLimb("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0))
	addLimb("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0))
	addLimb("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0))
	addLimb("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0))

	return model
end

local ghostTemplateCached: Model? = nil

local function getGhostTemplate(): Model
	if ghostTemplateCached then
		return ghostTemplateCached
	end

	local modelsSvc = ServiceLocator.Models()
	local model: Model? = nil
	if modelsSvc and typeof(modelsSvc.Clone) == "function" then
		model = modelsSvc:Clone("GhostsModel")
	end

	if not model then
		local modelsFolder = MainModule:FindFirstChild("Models")
		if modelsFolder then
			local found = modelsFolder:FindFirstChild("GhostsModel")
			if found and found:IsA("Model") then
				model = found:Clone()
			end
		end
	end

	if not model then
		model = createProceduralR6Ghost()
	end

	if not model.PrimaryPart then
		local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			or model:FindFirstChild("Torso") :: BasePart?
			or model:FindFirstChildWhichIsA("BasePart")
		if hrp then
			model.PrimaryPart = hrp
		end
	end

	model.Name = "GhostTemplate"
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
			desc.CastShadow = false
			desc.Massless = true
			desc.Anchored = true
			desc.CollisionGroup = "Default"
			desc.Material = Enum.Material.Neon
			if desc.Name == "HumanoidRootPart" then
				desc.Transparency = 1
			else
				desc.Color = COLOR_GHOST_ENEMY
				desc.Transparency = 0.65
			end
		elseif desc:IsA("Humanoid") or desc:IsA("Highlight") or desc:IsA("Script") or desc:IsA("LocalScript") then
			desc:Destroy()
		elseif desc:IsA("Decal") or desc:IsA("Texture") then
			desc.Transparency = 1
		end
	end

	ghostTemplateCached = model
	return model
end

local function clearGhostVisuals(): ()
	for _, model in activeGhostModels do
		model:Destroy()
	end
	table.clear(activeGhostModels)
	table.clear(activeGhostColors)
	table.clear(hiddenGhosts)
	table.clear(playerTeamCache)

	if ghostRigFolder then
		ghostRigFolder:Destroy()
		ghostRigFolder = nil
	end
end

local function getOrCreateGhostVisual(characterId: number): Model
	local existing = activeGhostModels[characterId]
	if existing then
		if existing.Parent then
			return existing
		end
		if hiddenGhosts[characterId] then
			hiddenGhosts[characterId] = nil
			existing.Parent = getOrCreateGhostFolder()
			return existing
		end
	end

	activeGhostColors[characterId] = nil
	local folder = getOrCreateGhostFolder()
	local template = getGhostTemplate()
	local clone = template:Clone()
	clone.Name = "Ghost_" .. tostring(characterId)

	for _, desc in clone:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
			desc.Massless = true
			desc.Anchored = true
			desc.CollisionGroup = "Default"
			if desc.Name == "HumanoidRootPart" then
				desc.Transparency = 1
			else
				desc.Transparency = 0.65
			end
		elseif desc:IsA("Humanoid") then
			desc:Destroy()
		end
	end

	clone.Parent = folder
	activeGhostModels[characterId] = clone
	return clone
end

local function getPlayerFromIdOrName(id: any, name: any): Player?
	local numId = tonumber(id)
	if numId and numId ~= 0 then
		local p = Players:GetPlayerByUserId(numId)
		if p then
			return p
		end
		for _, player in Players:GetPlayers() do
			if player.UserId == numId then
				return player
			end
		end
	end
	if typeof(name) == "string" and #name > 0 then
		local p = Players:FindFirstChild(name)
		if p and p:IsA("Player") then
			return p
		end
	end
	return nil
end

local function getCachedTeammateStatus(targetPlayer: Player?, ghostId: number, now: number): (boolean, Player?)
	local cached = playerTeamCache[ghostId]
	if cached and (now - cached.lastChecked < 1.0) then
		return cached.isTeammate, cached.player
	end

	local ghostPlayer = getPlayerFromIdOrName(ghostId, nil)
	local isTeammate = isGhostTeammate(targetPlayer, ghostPlayer)
	playerTeamCache[ghostId] = { isTeammate = isTeammate, lastChecked = now, player = ghostPlayer }
	return isTeammate, ghostPlayer
end

local function findSegment(snapshots: { any }, t: number): number
	local low, high = 1, #snapshots
	while low < high do
		local mid = (low + high + 1) // 2
		if snapshots[mid].t <= t then
			low = mid
		else
			high = mid - 1
		end
	end
	return low
end

local ghostMapFrame: BufferedGhostFrame? = nil
local ghostMap: { [number]: CFrame } = {}
local interpolatedGhosts: { SWTypes.GhostEntry } = {}

local function getReconciledGhostData(targetTimestamp: number): { SWTypes.GhostEntry }?
	local ghostBufferCount = #ghostFrames
	if ghostBufferCount == 0 then
		return nil
	end

	local newest = ghostFrames[ghostBufferCount]
	if os.clock() - newest.receivedAt > 1.5 then
		return nil
	end

	local oldest = ghostFrames[1]
	if targetTimestamp <= oldest.timestamp then
		if math.abs(oldest.timestamp - targetTimestamp) <= 0.25 then
			return oldest.ghosts
		end
		return nil
	end

	if targetTimestamp >= newest.timestamp then
		if (targetTimestamp - newest.timestamp) <= 0.25 then
			return newest.ghosts
		end
		return nil
	end

	local index = findSegment(ghostFrames, targetTimestamp)
	local f0 = ghostFrames[index]
	local f1 = ghostFrames[index + 1]
	local span = f1.timestamp - f0.timestamp
	if span < 0.0001 then
		return f1.ghosts
	end
	local alpha = math.clamp((targetTimestamp - f0.timestamp) / span, 0, 1)
	if alpha <= 0.02 then
		return f0.ghosts
	elseif alpha >= 0.98 then
		return f1.ghosts
	end

	if ghostMapFrame ~= f0 then
		ghostMapFrame = f0
		table.clear(ghostMap)
		for _, g0 in f0.ghosts do
			ghostMap[g0.characterId] = g0.cframe
		end
	end

	local count = 0
	for _, g1 in f1.ghosts do
		count += 1
		local entry = interpolatedGhosts[count]
		if not entry then
			entry = { characterId = 0, cframe = CFrame.identity }
			interpolatedGhosts[count] = entry
		end
		local cf0 = ghostMap[g1.characterId]
		entry.characterId = g1.characterId
		entry.cframe = if cf0 then cf0:Lerp(g1.cframe, alpha) else g1.cframe
	end
	for i = #interpolatedGhosts, count + 1, -1 do
		interpolatedGhosts[i] = nil
	end
	return interpolatedGhosts
end

local function updateGhostSilhouettes(ghosts: { SWTypes.GhostEntry }?): ()
	if not Fusion.peek(ghostsEnabledValue) then
		clearGhostVisuals()
		return
	end

	local currentActiveIds = activeGhostIds
	table.clear(currentActiveIds)
	local now = os.clock()
	local targetPlayer = if ghosts and #ghosts > 0 then getPlayerFromIdOrName(Fusion.peek(targetUserIdValue), Fusion.peek(targetNameValue)) else nil
	for _, ghost in ghosts or NO_GHOSTS do
		currentActiveIds[ghost.characterId] = true
		local isTeammate = getCachedTeammateStatus(targetPlayer, ghost.characterId, now)
		local color = if isTeammate then COLOR_GHOST_TEAMMATE else COLOR_GHOST_ENEMY
		local visual = getOrCreateGhostVisual(ghost.characterId)

		if activeGhostColors[ghost.characterId] ~= color then
			activeGhostColors[ghost.characterId] = color
			applyGhostColor(visual, color)
		end

		visual:PivotTo(ghost.cframe)
	end

	for id, visual in activeGhostModels do
		if not currentActiveIds[id] and not hiddenGhosts[id] then
			if visual.Parent then
				hiddenGhosts[id] = true
				visual.Parent = nil
			else
				activeGhostModels[id] = nil
				activeGhostColors[id] = nil
			end
		end
	end
end

local function observeClock(timestamp: number): ()
	local sample = os.clock() - timestamp
	local current = clockOffset
	clockOffset = if current then math.min(sample, current + CLOCK_OFFSET_RELAX) else sample
end

local function pushSnapshot(snapshots: { any }, snapshot: any, capacity: number?): ()
	local limit = capacity or SNAPSHOT_CAPACITY
	local count = #snapshots
	if count >= limit then
		local drop = limit // 4
		table.move(snapshots, drop + 1, count, 1)
		for i = count - drop + 1, count do
			snapshots[i] = nil
		end
		count -= drop
	end
	if count == 0 or snapshot.t > snapshots[count].t then
		snapshots[count + 1] = snapshot
		return
	end
	local low, high = 1, count
	while low <= high do
		local mid = (low + high) // 2
		local midT = snapshots[mid].t
		if midT < snapshot.t then
			low = mid + 1
		elseif midT > snapshot.t then
			high = mid - 1
		else
			return
		end
	end
	table.move(snapshots, low, count, low + 1)
	snapshots[low] = snapshot
end

local function pushInputEvent(event: { t: number, name: string, isDown: boolean }): ()
	local count = #inputEvents
	if count >= INPUT_EVENT_CAPACITY then
		local drop = INPUT_EVENT_CAPACITY // 4
		table.move(inputEvents, drop + 1, count, 1)
		for i = count - drop + 1, count do
			inputEvents[i] = nil
		end
		count -= drop
		inputCursor = math.max(0, inputCursor - drop)
	end
	inputEvents[count + 1] = event
end

local function setInputState(name: string, isDown: boolean): ()
	local kState = keyStates[name]
	if kState and Fusion.peek(kState) ~= isDown then
		kState:set(isDown)
	end
	local mState = mouseStates[name]
	if mState and Fusion.peek(mState) ~= isDown then
		mState:set(isDown)
	end
end

local pendingInputStates: { [string]: boolean } = {}

local function syncInputsTo(sampleTime: number): ()
	local cursor = inputCursor
	if lastInputSampleTime and sampleTime < lastInputSampleTime - 0.001 then
		cursor = 0
		for name in keyStates do
			pendingInputStates[name] = false
		end
		for name in mouseStates do
			pendingInputStates[name] = false
		end
	end
	lastInputSampleTime = sampleTime
	local count = #inputEvents
	while cursor < count do
		local event = inputEvents[cursor + 1]
		if event.t > sampleTime then
			break
		end
		pendingInputStates[event.name] = event.isDown
		cursor += 1
	end
	inputCursor = cursor
	if next(pendingInputStates) == nil then
		return
	end
	for name, isDown in pendingInputStates do
		setInputState(name, isDown)
	end
	table.clear(pendingInputStates)
end

local function ingestCameraPayload(payload): ()
	local lastCamera = cameraSnapshots[#cameraSnapshots]
	local fov = if payload.fov and payload.fov > 10 and payload.fov < 130 then payload.fov elseif lastCamera then lastCamera.fov else 70
	pushSnapshot(cameraSnapshots, { t = payload.timestamp, cframe = payload.cframe, fov = fov, mouseHit = payload.mouseHit })
end

local function ingestGhostPayload(payload): ()
	pushSnapshot(ghostFrames, { t = payload.timestamp, timestamp = payload.timestamp, receivedAt = os.clock(), ghosts = payload.ghosts }, GHOST_BUFFER_CAPACITY)
end

local function refreshAcReport(): ()
	local entry = suspectById[Fusion.peek(targetUserIdValue)]
	acReportValue:set(if entry then string.format("AC %.0f%% · %s", entry.score * 100, entry.reason) else "")
end

local function resetPlayback(): ()
	rewind = 0
	lastRenderTime = nil
	playbackSpeed = 1
	playbackPaused = false
	pendingRewind = nil
	lastCameraReceivedAt = 0
	flickAccum = 0
	flickHead = 0
	table.clear(flickRecent)
	for i = 1, FLICK_BARS do
		flickRecent[i] = 0
		flickBarValues[i]:set(0)
	end
	flickPeakValue:set(0)
	table.clear(hitMarkers)
	table.clear(activeMarkerVisuals)
	table.clear(inputEvents)
	inputCursor = 0
	lastInputSampleTime = nil
	pausedAt = nil
	if markerFolder then
		markerFolder:Destroy()
		markerFolder = nil
	end
	playbackStatusValue:set("LIVE")
	playbackPausedValue:set(false)
	playbackSpeedValue:set(1)
	timelineSpanValue:set(0)
	timelineRewindValue:set(0)
	for i = 1, TIMELINE_TICKS do
		timelineTickValues[i]:set(-1)
	end
	lagStatusValue:set("")
end

local function sampleSnapshots(snapshots: { any }, t: number): (any?, any?, number)
	local count = #snapshots
	if count == 0 then
		return nil, nil, 0
	end
	local index = findSegment(snapshots, t)
	local a = snapshots[index]
	if index >= count or t <= a.t then
		return a, nil, 0
	end
	local b = snapshots[index + 1]
	local span = b.t - a.t
	return a, b, if span > 0 then (t - a.t) / span else 1
end

local function makeMarkerPart(position: Vector3, color: Color3, size: number, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.15
	part.Parent = parent
	return part
end

local function spawnHitMarker(marker: { t: number, victimId: number, offset: Vector3, head: boolean }): ()
	local camera = getCurrentCamera()
	if not camera then
		return
	end

	local hitFrame: CFrame? = nil
	local ghosts = getReconciledGhostData(marker.t)
	if ghosts then
		for _, ghost in ghosts do
			if ghost.characterId == marker.victimId then
				hitFrame = ghost.cframe
				break
			end
		end
	end
	if not hitFrame then
		local victim = Players:GetPlayerByUserId(marker.victimId)
		local character = victim and victim.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			hitFrame = root.CFrame
		end
	end
	if not hitFrame then
		return
	end

	local folder = markerFolder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ScreenWatchHitMarkers"
		folder.Parent = camera
		markerFolder = folder
	end

	local hitPoint = hitFrame:PointToWorldSpace(marker.offset)
	local hitPart = makeMarkerPart(hitPoint, if marker.head then Color3.fromRGB(255, 70, 70) else Color3.fromRGB(255, 255, 255), 0.35, folder)
	local created = { hitPart }

	local camA, camB, alpha = sampleSnapshots(cameraSnapshots, marker.t)
	local cursorPoint = if camB and alpha >= 0.5 then camB.mouseHit elseif camA then camA.mouseHit else nil
	if cursorPoint then
		local cursorPart = makeMarkerPart(cursorPoint, Color3.fromRGB(255, 220, 60), 0.3, folder)
		table.insert(created, cursorPart)
		local a0 = Instance.new("Attachment")
		a0.Parent = hitPart
		local a1 = Instance.new("Attachment")
		a1.Parent = cursorPart
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 0.08
		beam.Width1 = 0.08
		beam.FaceCamera = true
		beam.Color = BEAM_COLOR
		beam.Transparency = BEAM_TRANSPARENCY
		beam.Parent = hitPart
	end

	table.insert(activeMarkerVisuals, { t = marker.t, parts = created })
end

local function requestNativeIconSize(icon: string): ()
	if nativeIconSizes[icon] ~= nil then
		return
	end
	nativeIconSizes[icon] = false
	task.spawn(function()
		local ok, image = pcall(function()
			return AssetService:CreateEditableImageAsync(Content.fromUri(icon))
		end)
		if ok and image then
			nativeIconSizes[icon] = image.Size
			image:Destroy()
		end
	end)
end

function ScreenWatchWatcher.getState(): WatcherState
	return {
		isWatching = isWatchingValue,
		targetUserId = targetUserIdValue,
		targetName = targetNameValue,
		cursorPosition = cursorPositionValue,
		cursorIcon = cursorIconValue,
		cursorSize = cursorSizeValue,
		playbackStatus = playbackStatusValue,
		playbackPaused = playbackPausedValue,
		playbackSpeed = playbackSpeedValue,
		timelineSpan = timelineSpanValue,
		timelineRewind = timelineRewindValue,
		timelineTicks = timelineTickValues,
		lagStatus = lagStatusValue,
		acReport = acReportValue,
		flickBars = flickBarValues,
		flickPeak = flickPeakValue,
		isCursorFree = isCursorFreeValue,
		isSprinting = isSprintingComputed,
		isCrouching = isCrouchingComputed,
		trailEnabled = trailEnabledValue,
		ghostsEnabled = ghostsEnabledValue,
		markersEnabled = markersEnabledValue,
		espMode = espModeValue,
		inputsVisible = inputsVisibleValue,
		hitsVisible = hitsVisibleValue,
		targetPing = targetPingValue,
		targetAvgPing = targetAvgPingValue,
		targetPingSpikes = targetPingSpikesValue,
		targetMatchAccuracy = targetMatchAccuracyValue,
		targetFOV = targetFOVValue,
		targetResolution = targetResolutionValue,
		trailNodes = trailNodes,
		keyStates = keyStates,
		mouseStates = mouseStates,
		keyHistory = keyHistoryValue,
		hitHistory = hitHistoryValue,
	}
end

local function setPaused(paused: boolean): ()
	playbackPaused = paused
	playbackPausedValue:set(paused)
	if not paused then
		pausedAt = nil
	end
end

local function setSpeed(speed: number): ()
	playbackSpeed = speed
	playbackSpeedValue:set(speed)
end

function ScreenWatchWatcher.togglePause(): ()
	setPaused(not playbackPaused)
end

function ScreenWatchWatcher.cycleSpeed(): ()
	setSpeed(if playbackSpeed == 1 then 0.5 elseif playbackSpeed == 0.5 then 0.25 else 1)
	setPaused(false)
end

local function getLiveTime(): number
	return os.clock() - (clockOffset or 0) - PLAYBACK_DELAY
end

function ScreenWatchWatcher.seek(seconds: number?): ()
	local delta = seconds or SEEK_SECONDS
	if playbackPaused then
		pausedAt = (pausedAt or (getLiveTime() - rewind)) + delta
	else
		rewind = math.max(0, rewind - delta)
	end
end

function ScreenWatchWatcher.seekToFraction(fraction: number): ()
	if #cameraSnapshots == 0 then
		return
	end
	local liveTime = getLiveTime()
	local span = math.max(0, liveTime - cameraSnapshots[1].t)
	rewind = (1 - math.clamp(fraction, 0, 1)) * span
	if playbackPaused then
		pausedAt = liveTime - rewind
	end
end

function ScreenWatchWatcher.goLive(): ()
	rewind = 0
	pendingRewind = nil
	pausedAt = nil
	setPaused(false)
	setSpeed(1)
end

function ScreenWatchWatcher.step(direction: number): ()
	setPaused(true)
	local liveTime = getLiveTime()
	local current = pausedAt or (liveTime - rewind)
	if direction > 0 then
		for i = 1, #cameraSnapshots do
			if cameraSnapshots[i].t > current + 0.0001 then
				pausedAt = cameraSnapshots[i].t
				return
			end
		end
	else
		for i = #cameraSnapshots, 1, -1 do
			if cameraSnapshots[i].t < current - 0.0001 then
				pausedAt = cameraSnapshots[i].t
				return
			end
		end
	end
end

function ScreenWatchWatcher.getSuspects(): { any }
	return suspectList
end

function ScreenWatchWatcher.getLastVictimId(): number?
	for i = #fullSessionHitHistory, 1, -1 do
		local entry = fullSessionHitHistory[i] :: any
		if entry.victimId and entry.victimId > 0 then
			return entry.victimId
		end
	end
	return nil
end

function ScreenWatchWatcher.toggleTrail(): ()
	trailEnabledValue:set(not Fusion.peek(trailEnabledValue))
end

function ScreenWatchWatcher.toggleGhosts(): ()
	ghostsEnabledValue:set(not Fusion.peek(ghostsEnabledValue))
end

function ScreenWatchWatcher.toggleMarkers(): ()
	local enabled = not Fusion.peek(markersEnabledValue)
	markersEnabledValue:set(enabled)
	if not enabled and markerFolder then
		markerFolder:ClearAllChildren()
		table.clear(activeMarkerVisuals)
	end
end

function ScreenWatchWatcher.getESPMode(): string
	return Fusion.peek(espModeValue) or "TEAM"
end

function ScreenWatchWatcher.cycleESPMode(): ()
	local current = Fusion.peek(espModeValue)
	local nextMode = if current == "TEAM" then "ENEMIES" elseif current == "ENEMIES" then "ALL" elseif current == "ALL" then "OFF" else "TEAM"
	espModeValue:set(nextMode)

	local teamESPOverhead = ServiceLocator.TeamESPOverhead()
	if teamESPOverhead and typeof(teamESPOverhead.RefreshAll) == "function" then
		teamESPOverhead:RefreshAll()
	end
end

function ScreenWatchWatcher.toggleInputs(): ()
	inputsVisibleValue:set(not Fusion.peek(inputsVisibleValue))
end

function ScreenWatchWatcher.toggleHits(): ()
	hitsVisibleValue:set(not Fusion.peek(hitsVisibleValue))
end

function ScreenWatchWatcher.startWatching(targetUserId: number, targetName: string): ()
	if Fusion.peek(isWatchingValue) then
		ScreenWatchWatcher.stopWatching()
	end

	sessionStartTime = os.clock()
	table.clear(cameraSnapshots)
	table.clear(cursorSnapshots)
	clockOffset = nil
	lastReportedCursorSize = nil
	cursorSizeValue:set(nil)
	resetPlayback()
	lastReportedSprinting = nil
	lastReportedCrouching = nil
	lastReportedFree = nil
	lastReportedCursorIcon = nil
	lastReportedFOV = nil
	lastReportedRes = nil
	lastReportedPing = nil
	lastReportedAvgPing = nil
	lastReportedSpikes = nil
	lastReportedAcc = nil
	trailHead = 0
	trailCount = 0
	table.clear(playerTeamCache)
	table.clear(fullSessionKeyHistory)
	table.clear(fullSessionHitHistory)
	table.clear(pendingKeyEntries)
	keyUpdateScheduled = false
	table.clear(pendingHitEntries)
	hitUpdateScheduled = false
	latestMouseBehavior = "Default"
	latestIsSprinting = false
	latestIsCrouching = false
	latestCursorPos = Vector2.new(0.5, 0.5)
	latestCursorIcon = DEFAULT_CURSOR_ID
	table.clear(ghostFrames)
	ghostMapFrame = nil

	keyHistoryValue:set({})
	hitHistoryValue:set({})
	targetPingValue:set(0)
	targetAvgPingValue:set(0)
	targetPingSpikesValue:set(0)
	targetMatchAccuracyValue:set(0)
	targetFOVValue:set(70)
	targetResolutionValue:set(Vector2.new(1920, 1080))

	for _, kVal in keyStates do
		kVal:set(false)
	end
	for _, mVal in mouseStates do
		mVal:set(false)
	end

	for _, node in trailNodes do
		node.visible:set(false)
	end

	targetUserIdValue:set(targetUserId)
	targetNameValue:set(targetName)
	isWatchingValue:set(true)
	cursorIconValue:set(DEFAULT_CURSOR_ID)
	refreshAcReport()

	task.defer(function()
		local pingService = ServiceLocator.Ping()
		if pingService then
			if typeof(pingService.ClearAllHighlights) == "function" then
				pingService:ClearAllHighlights()
			end
			if typeof(pingService.ClearAllMarkers) == "function" then
				pingService:ClearAllMarkers()
			end
		end
		local teamESP = ServiceLocator.TeamESP()
		if teamESP and typeof(teamESP.RefreshAll) == "function" then
			teamESP:RefreshAll()
		end
		local teamESPOverhead = ServiceLocator.TeamESPOverhead()
		if teamESPOverhead and typeof(teamESPOverhead.RefreshAll) == "function" then
			teamESPOverhead:RefreshAll()
		end
	end)

	local cam = getCurrentCamera()
	if cam then
		savedCameraType = cam.CameraType
		savedCameraFOV = cam.FieldOfView
		cam.CameraType = Enum.CameraType.Scriptable
	end

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true

	local trove = Trove.new()
	activeTrove = trove

	trove:Add(RunService.RenderStepped:Connect(function(dt: number)
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		if not UserInputService.MouseIconEnabled then
			UserInputService.MouseIconEnabled = true
		end

		local currentCam = getCurrentCamera()
		if not currentCam then
			return
		end

		local now = os.clock()

		local liveTime = now - (clockOffset or 0) - PLAYBACK_DELAY
		local oldestTime = if #cameraSnapshots > 0 then cameraSnapshots[1].t else liveTime
		local sampleTime: number
		if playbackPaused and not pendingRewind then
			local frozen = pausedAt or (liveTime - rewind)
			sampleTime = math.clamp(frozen, math.min(oldestTime, liveTime), liveTime)
			pausedAt = sampleTime
			rewind = liveTime - sampleTime
		else
			if pendingRewind then
				local available = liveTime - oldestTime
				if available >= pendingRewind - PRE_BUFFER_SLACK or now - pendingRewindAt > PRE_BUFFER_TIMEOUT then
					rewind = math.min(pendingRewind, math.max(available, 0))
					pendingRewind = nil
				end
			elseif playbackSpeed < 1 then
				rewind += dt * (1 - playbackSpeed)
			end
			rewind = math.clamp(rewind, 0, math.max(0, liveTime - oldestTime))
			sampleTime = liveTime - rewind
		end

		local camA, camB, camAlpha = sampleSnapshots(cameraSnapshots, sampleTime)
		if camA then
			currentCam.CameraType = Enum.CameraType.Scriptable
			local camDelta = if camB then camB.cframe.Position - camA.cframe.Position else Vector3.zero
			if camB and camDelta:Dot(camDelta) < TELEPORT_DISTANCE_SQ then
				currentCam.CFrame = camA.cframe:Lerp(camB.cframe, camAlpha)
				currentCam.FieldOfView = camA.fov + (camB.fov - camA.fov) * camAlpha
			else
				local snap = if camB and camAlpha >= 0.5 then camB else camA
				currentCam.CFrame = snap.cframe
				currentCam.FieldOfView = snap.fov
			end
		end

		if camA and camB and not playbackPaused then
			flickAccum += dt
			if flickAccum >= FLICK_SAMPLE_INTERVAL then
				flickAccum = 0
				local span = camB.t - camA.t
				local turn = math.deg(math.acos(math.clamp(camA.cframe.LookVector:Dot(camB.cframe.LookVector), -1, 1)))
				local speed = if span > 0 then turn / span else 0
				flickHead = flickHead % FLICK_BARS + 1
				flickRecent[flickHead] = speed
				flickBarValues[flickHead]:set(math.min(speed / FLICK_MAX_DEG_PER_SEC, 1))
				local peak = 0
				for _, value in flickRecent do
					peak = math.max(peak, value)
				end
				peak = math.round(peak)
				if peak ~= Fusion.peek(flickPeakValue) then
					flickPeakValue:set(peak)
				end
			end
		end

		if lastRenderTime and sampleTime > lastRenderTime and Fusion.peek(markersEnabledValue) then
			for _, marker in hitMarkers do
				if marker.t > lastRenderTime and marker.t <= sampleTime and sampleTime - marker.t <= HIT_MARKER_MAX_AGE then
					spawnHitMarker(marker)
				end
			end
		end
		lastRenderTime = sampleTime
		for i = #activeMarkerVisuals, 1, -1 do
			local visual = activeMarkerVisuals[i]
			if sampleTime - visual.t > HIT_MARKER_LIFETIME or sampleTime < visual.t then
				for _, part in visual.parts do
					part:Destroy()
				end
				local last = #activeMarkerVisuals
				activeMarkerVisuals[i] = activeMarkerVisuals[last]
				activeMarkerVisuals[last] = nil
			end
		end
		syncInputsTo(sampleTime)

		if now - lastStatusUpdate >= STATUS_UPDATE_INTERVAL then
			lastStatusUpdate = now
			local behind = liveTime - sampleTime
			local delayMs = math.round((PLAYBACK_DELAY + behind) * 1000)
			local status
			if pendingRewind then
				status = string.format("LOADING LAST %ds", math.round(pendingRewind))
			elseif playbackPaused then
				status = string.format("PAUSED · %.1fs behind", behind)
			elseif playbackSpeed < 1 then
				status = string.format("%.2gx · %.1fs behind", playbackSpeed, behind)
			elseif behind > 0.25 then
				status = string.format("REWIND · %.1fs behind", behind)
			else
				status = string.format("LIVE · %dms delay", delayMs)
			end
			if status ~= Fusion.peek(playbackStatusValue) then
				playbackStatusValue:set(status)
			end
			local lag = if lastCameraReceivedAt > 0 then now - lastCameraReceivedAt else 0
			local lagText = if lag > LAG_THRESHOLD then string.format("LAG %.1fs", lag) else ""
			if lagText ~= Fusion.peek(lagStatusValue) then
				lagStatusValue:set(lagText)
			end

			local span = math.max(0, liveTime - oldestTime)
			timelineSpanValue:set(span)
			timelineRewindValue:set(rewind)
			local tickIndex = 0
			if span > 0 then
				for i = #hitMarkers, 1, -1 do
					if tickIndex >= TIMELINE_TICKS then
						break
					end
					local fraction = 1 - (liveTime - hitMarkers[i].t) / span
					if fraction < 0 then
						break
					end
					tickIndex += 1
					timelineTickValues[tickIndex]:set(fraction)
				end
			end
			for i = tickIndex + 1, TIMELINE_TICKS do
				if Fusion.peek(timelineTickValues[i]) >= 0 then
					timelineTickValues[i]:set(-1)
				end
			end
		end

		if latestIsSprinting ~= lastReportedSprinting then
			lastReportedSprinting = latestIsSprinting
			isSprintingValue:set(latestIsSprinting)
		end
		if latestIsCrouching ~= lastReportedCrouching then
			lastReportedCrouching = latestIsCrouching
			isCrouchingValue:set(latestIsCrouching)
		end

		local isFree = latestMouseBehavior == "Default"
		if isFree ~= lastReportedFree then
			lastReportedFree = isFree
			isCursorFreeValue:set(isFree)
		end

		local vpSize = currentCam.ViewportSize
		local curA, curB, curAlpha = sampleSnapshots(cursorSnapshots, sampleTime)
		local cursorNorm = latestCursorPos
		if curA then
			cursorNorm = if curB then curA.position:Lerp(curB.position, curAlpha) else curA.position
			latestCursorIcon = curA.icon
		end
		local activeCursorPos = Vector2.new(cursorNorm.X * vpSize.X, cursorNorm.Y * vpSize.Y)

		local nativeSize = nativeIconSizes[latestCursorIcon]
		local targetRes = Fusion.peek(targetResolutionValue)
		local cursorSize = if nativeSize then nativeSize * (vpSize.Y / math.max(targetRes.Y, 1)) else nil
		if cursorSize ~= lastReportedCursorSize then
			lastReportedCursorSize = cursorSize
			cursorSizeValue:set(cursorSize)
		end

		cursorPositionValue:set(activeCursorPos)

		if Fusion.peek(ghostsEnabledValue) then
			local reconciledGhosts = if camA then getReconciledGhostData(sampleTime) else nil
			updateGhostSilhouettes(reconciledGhosts)
		else
			if next(activeGhostModels) ~= nil then
				clearGhostVisuals()
			end
		end

		if Fusion.peek(trailEnabledValue) then
			trailHead = (trailHead % NUM_TRAIL_NODES) + 1
			trailPositions[trailHead] = activeCursorPos
			trailTimestamps[trailHead] = now
			trailCount = math.min(trailCount + 1, NUM_TRAIL_NODES)

			local cutoff = now - 0.35
			for i = 1, NUM_TRAIL_NODES do
				local nodeState = trailNodes[i]
				if i <= trailCount then
					local idx = ((trailHead - trailCount + i - 1) % NUM_TRAIL_NODES) + 1
					local t = trailTimestamps[idx]
					if t and t >= cutoff then
						local pt = trailPositions[idx]
						local progress = i / trailCount
						local nodeSize = math.floor(4 + progress * 2)
						local nodeAlpha = math.clamp(0.2 + progress * 0.75, 0.2, 0.95)

						nodeState.position:set(UDim2.fromOffset(pt.X, pt.Y))
						nodeState.size:set(UDim2.fromOffset(nodeSize, nodeSize))
						nodeState.transparency:set(1 - nodeAlpha)
						nodeState.visible:set(true)
					else
						nodeState.visible:set(false)
					end
				else
					nodeState.visible:set(false)
				end
			end
		else
			if trailCount > 0 then
				trailCount = 0
				trailHead = 0
				for i = 1, NUM_TRAIL_NODES do
					trailNodes[i].visible:set(false)
				end
			end
		end

		if latestCursorIcon and latestCursorIcon ~= "" and latestCursorIcon ~= lastReportedCursorIcon then
			lastReportedCursorIcon = latestCursorIcon
			cursorIconValue:set(latestCursorIcon)
		end
	end))
end

function ScreenWatchWatcher.stopWatching(): ()
	if not Fusion.peek(isWatchingValue) then
		return
	end

	isWatchingValue:set(false)
	targetUserIdValue:set(0)
	targetNameValue:set("")
	isSprintingValue:set(false)
	isCrouchingValue:set(false)
	hitHistoryValue:set({})
	targetPingValue:set(0)
	targetAvgPingValue:set(0)
	targetPingSpikesValue:set(0)
	targetMatchAccuracyValue:set(0)
	espModeValue:set("TEAM")
	table.clear(cameraSnapshots)
	table.clear(cursorSnapshots)
	clockOffset = nil
	resetPlayback()
	acReportValue:set("")
	lastReportedSprinting = nil
	lastReportedCrouching = nil
	lastReportedFree = nil
	lastReportedCursorIcon = nil
	lastReportedFOV = nil
	lastReportedRes = nil
	lastReportedPing = nil
	lastReportedAvgPing = nil
	lastReportedSpikes = nil
	lastReportedAcc = nil
	trailHead = 0
	trailCount = 0
	table.clear(ghostFrames)
	ghostMapFrame = nil
	table.clear(pendingKeyEntries)
	keyUpdateScheduled = false
	table.clear(pendingHitEntries)
	hitUpdateScheduled = false
	clearGhostVisuals()

	for _, node in trailNodes do
		node.visible:set(false)
	end

	if activeTrove then
		activeTrove:Destroy()
		activeTrove = nil
	end

	task.defer(function()
		local pingService = ServiceLocator.Ping()
		if pingService then
			if typeof(pingService.ClearAllHighlights) == "function" then
				pingService:ClearAllHighlights()
			end
			if typeof(pingService.ClearAllMarkers) == "function" then
				pingService:ClearAllMarkers()
			end
		end
		local teamESP = ServiceLocator.TeamESP()
		if teamESP and typeof(teamESP.RefreshAll) == "function" then
			teamESP:RefreshAll()
		end
		local teamESPOverhead = ServiceLocator.TeamESPOverhead()
		if teamESPOverhead and typeof(teamESPOverhead.RefreshAll) == "function" then
			teamESPOverhead:RefreshAll()
		end
	end)

	local cam = getCurrentCamera()
	if cam then
		local restoredType = if savedCameraType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else (savedCameraType or Enum.CameraType.Custom)
		cam.CameraType = restoredType
		cam.FieldOfView = savedCameraFOV or 70
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.Character then
			local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				cam.CameraSubject = humanoid
			end
		end
		savedCameraType = nil
		savedCameraFOV = nil
	end

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

function ScreenWatchWatcher.init(): ()
	Network.ScreenWatch.onWatchStateSync(function(payload)
		if payload.isWatching then
			ScreenWatchWatcher.startWatching(payload.targetUserId, payload.targetName or "Target")
		else
			ScreenWatchWatcher.stopWatching()
		end
	end)

	Network.ScreenWatch.onCameraStreamWatcher(function(payload)
		if not Fusion.peek(isWatchingValue) then
			return
		end

		observeClock(payload.timestamp)
		ingestCameraPayload(payload)
		lastCameraReceivedAt = os.clock()

		latestMouseBehavior = payload.mouseBehavior or "Default"
		latestIsSprinting = payload.isSprinting or false
		latestIsCrouching = payload.isCrouching or false

		if payload.fov and payload.fov > 10 and payload.fov < 130 then
			local roundedFOV = math.round(payload.fov)
			if roundedFOV ~= lastReportedFOV then
				lastReportedFOV = roundedFOV
				targetFOVValue:set(roundedFOV)
			end
		end

		if payload.viewportSize and payload.viewportSize.X > 0 then
			local vp = Vector2.new(payload.viewportSize.X, payload.viewportSize.Y)
			if vp ~= lastReportedRes then
				lastReportedRes = vp
				targetResolutionValue:set(vp)
			end
		end

		if payload.ping and payload.ping ~= lastReportedPing then
			lastReportedPing = payload.ping
			targetPingValue:set(payload.ping)
		end
		if payload.avgPing and payload.avgPing ~= lastReportedAvgPing then
			lastReportedAvgPing = payload.avgPing
			targetAvgPingValue:set(payload.avgPing)
		end
		if payload.pingSpikes and payload.pingSpikes ~= lastReportedSpikes then
			lastReportedSpikes = payload.pingSpikes
			targetPingSpikesValue:set(payload.pingSpikes)
		end
		if payload.matchAccuracy ~= nil and payload.matchAccuracy ~= lastReportedAcc then
			lastReportedAcc = payload.matchAccuracy
			targetMatchAccuracyValue:set(payload.matchAccuracy)
		end
	end)

	Network.ScreenWatch.onGhostStreamWatcher(function(payload)
		if not Fusion.peek(isWatchingValue) then
			return
		end

		ingestGhostPayload(payload)
	end)

	Network.ScreenWatch.onPreBufferStart(function(seconds)
		if not Fusion.peek(isWatchingValue) then
			return
		end
		pendingRewind = math.max(0, seconds)
		pendingRewindAt = os.clock()
		lastRenderTime = nil
	end)

	Network.ScreenWatch.onPreBufferChunk(function(chunk)
		if not Fusion.peek(isWatchingValue) then
			return
		end
		for _, payload in chunk.cameras do
			ingestCameraPayload(payload)
		end
		for _, payload in chunk.cursors do
			pushSnapshot(cursorSnapshots, { t = payload.timestamp, position = Vector2.new(payload.position.X, payload.position.Y), icon = payload.icon or DEFAULT_CURSOR_ID })
		end
		for _, payload in chunk.ghosts do
			ingestGhostPayload(payload)
		end
	end)

	task.spawn(function()
		local remote = ReplicatedStorage:WaitForChild(SUSPECTS_REMOTE_NAME, 120)
		if not remote or not remote:IsA("RemoteEvent") then
			return
		end
		remote.OnClientEvent:Connect(function(list)
			table.clear(suspectList)
			table.clear(suspectById)
			if type(list) == "table" then
				for _, suspect in list do
					if type(suspect) == "table" and type(suspect.userId) == "number" then
						local entry = { userId = suspect.userId, name = tostring(suspect.name or ""), score = tonumber(suspect.score) or 0, reason = tostring(suspect.reason or "") }
						table.insert(suspectList, entry)
						suspectById[entry.userId] = entry
					end
				end
			end
			refreshAcReport()
		end)
	end)

	Network.ScreenWatch.onCursorStreamWatcher(function(payload)
		if not Fusion.peek(isWatchingValue) then
			return
		end

		local cam = getCurrentCamera()
		local vpSize = if cam then cam.ViewportSize else Vector2.new(1920, 1080)
		local normX = if payload.position.X > 1 then payload.position.X / math.max(vpSize.X, 1) else payload.position.X
		local normY = if payload.position.Y > 1 then payload.position.Y / math.max(vpSize.Y, 1) else payload.position.Y

		local pos = Vector2.new(normX, normY)
		latestCursorPos = pos
		local icon = if payload.icon and payload.icon ~= "" then payload.icon else latestCursorIcon
		requestNativeIconSize(icon)
		observeClock(payload.timestamp)
		pushSnapshot(cursorSnapshots, { t = payload.timestamp, position = pos, icon = icon })
		if #cameraSnapshots == 0 then
			latestCursorIcon = icon
		end
	end)

	Network.ScreenWatch.onInputEventWatcher(function(payload)
		if not Fusion.peek(isWatchingValue) then
			return
		end
		pushInputEvent({ t = payload.timestamp, name = payload.inputName, isDown = payload.isDown })
	end)

	Network.ScreenWatch.onKeyHistoryEventWatcher(function(payload)
		if not Fusion.peek(isWatchingValue) then
			return
		end

		local timeOffset = os.clock() - sessionStartTime
		local formatted = string.format("%.1fs", math.max(timeOffset, 0))

		local entry = {
			keyName = payload.keyName,
			isFlagged = payload.isFlagged,
			isDown = payload.isDown,
			timestamp = payload.timestamp,
			formattedTime = formatted,
			isFocusEvent = payload.isFocusEvent,
			isSettingsEvent = payload.isSettingsEvent,
		}
		table.insert(fullSessionKeyHistory, entry)
		table.insert(pendingKeyEntries, entry)

		if not keyUpdateScheduled then
			keyUpdateScheduled = true
			task.defer(function()
				keyUpdateScheduled = false
				if not Fusion.peek(isWatchingValue) then
					table.clear(pendingKeyEntries)
					return
				end

				local count = #pendingKeyEntries
				if count == 0 then
					return
				end

				local prevList = Fusion.peek(keyHistoryValue) or {}
				local maxLiveEntries = 25
				local added = math.min(count, maxLiveEntries)
				local newList = table.create(math.min(#prevList + count, maxLiveEntries))

				for i = 1, added do
					newList[i] = pendingKeyEntries[count - i + 1]
				end

				local remaining = maxLiveEntries - added
				if remaining > 0 and #prevList > 0 then
					table.move(prevList, 1, math.min(#prevList, remaining), added + 1, newList)
				end

				table.clear(pendingKeyEntries)
				keyHistoryValue:set(newList)
			end)
		end
	end)

	Network.ScreenWatch.onHitEventWatcher(function(payload)
		if not Fusion.peek(isWatchingValue) then
			return
		end

		local timeOffset = os.clock() - sessionStartTime
		local formatted = string.format("%.1fs", math.max(timeOffset, 0))

		if payload.hitOffset and payload.victimId > 0 then
			table.insert(hitMarkers, { t = payload.targetTime or (os.clock() - (clockOffset or 0)), victimId = payload.victimId, offset = payload.hitOffset, head = payload.isHeadshot })
			if #hitMarkers > HIT_MARKER_HISTORY then
				table.move(hitMarkers, 2, #hitMarkers, 1)
				hitMarkers[#hitMarkers] = nil
			end
		end

		local hitEntry = {
			victimId = payload.victimId,
			victimName = payload.victimName,
			damage = payload.damage,
			bodyPart = payload.bodyPart,
			isHeadshot = payload.isHeadshot,
			weaponName = payload.weaponName,
			timestamp = payload.timestamp,
			formattedTime = formatted,
		}
		table.insert(fullSessionHitHistory, hitEntry)
		table.insert(pendingHitEntries, hitEntry)

		if not hitUpdateScheduled then
			hitUpdateScheduled = true
			task.defer(function()
				hitUpdateScheduled = false
				if not Fusion.peek(isWatchingValue) then
					table.clear(pendingHitEntries)
					return
				end

				local count = #pendingHitEntries
				if count == 0 then
					return
				end

				local prevList = Fusion.peek(hitHistoryValue) or {}
				local maxLiveEntries = 25
				local added = math.min(count, maxLiveEntries)
				local newList = table.create(math.min(#prevList + count, maxLiveEntries))

				for i = 1, added do
					newList[i] = pendingHitEntries[count - i + 1]
				end

				local remaining = maxLiveEntries - added
				if remaining > 0 and #prevList > 0 then
					table.move(prevList, 1, math.min(#prevList, remaining), added + 1, newList)
				end

				table.clear(pendingHitEntries)
				hitHistoryValue:set(newList)
			end)
		end
	end)
end

function ScreenWatchWatcher.exportLogs(): ()
	local targetId = Fusion.peek(targetUserIdValue)
	local targetName = Fusion.peek(targetNameValue)
	if not targetId or targetId == 0 then
		warn("[ScreenWatch] Cannot export as no target is currently being watched.")
		return
	end

	local localPlayer = Players.LocalPlayer
	local watcherName = if localPlayer then localPlayer.Name else "Staff"
	local watcherId = if localPlayer then localPlayer.UserId else 0

	local keys = fullSessionKeyHistory
	local hits = fullSessionHitHistory
	local ping = Fusion.peek(targetPingValue) or 0
	local avgPing = Fusion.peek(targetAvgPingValue) or 0
	local spikes = Fusion.peek(targetPingSpikesValue) or 0
	local acc = Fusion.peek(targetMatchAccuracyValue) or 0

	local sessionDuration = os.clock() - sessionStartTime
	local rng = Random.new()
	local serialId = string.format("VDI-%04X-%04X", rng:NextInteger(0, 0xFFFF), rng:NextInteger(0, 0xFFFF))

	local lines: { string } = {}
	table.insert(lines, "================================================================================")
	table.insert(lines, string.format("           VULTARIAN DEFENSE INDUSTRIES REPORT - %s", serialId))
	table.insert(lines, "================================================================================")
	table.insert(lines, string.format("Target Player     : %s (User ID: %d)", targetName, targetId))
	table.insert(lines, string.format("Watcher           : %s (User ID: %d)", watcherName, watcherId))
	table.insert(lines, string.format("Export Timestamp  : %s", os.date("!%Y-%m-%d %H:%M:%S UTC")))
	table.insert(lines, string.format("Session Duration  : %.2f seconds", math.max(sessionDuration, 0)))
	table.insert(lines, string.format("Target Latency    : %d ms (Avg: %d ms, Spikes: %d)", ping, avgPing, spikes))
	table.insert(lines, string.format("Match Accuracy    : %.1f%%", acc))
	table.insert(lines, "================================================================================")
	table.insert(lines, "")

	table.insert(lines, string.format("[--- INPUT & KEY LOG HISTORY (%d entries) ---]", #keys))
	table.insert(lines, string.format("%-12s | %-6s | %-24s | %s", "Time Offset", "Action", "Key / Event Name", "Classification"))
	table.insert(lines, string.rep("-", 80))
	if #keys == 0 then
		table.insert(lines, "No input events recorded during this session.")
	else
		for _, entry in keys do
			local action = if entry.isDown then "DOWN" else "UP"
			local classification = if entry.isSettingsEvent
				then "SETTINGS_EVENT"
				elseif entry.isFocusEvent then "FOCUS_EVENT"
				elseif entry.isFlagged then "[SUSPICIOUS_KEY]"
				else "NORMAL_INPUT"
			table.insert(lines, string.format("%-12s | %-6s | %-24s | %s", entry.formattedTime, action, entry.keyName, classification))
		end
	end
	table.insert(lines, "")

	table.insert(lines, string.format("[--- AUTHORITATIVE HIT LOG HISTORY (%d entries) ---]", #hits))
	table.insert(lines, string.format("%-12s | %-12s | %-20s | %-10s | %-8s | %s", "Time Offset", "Weapon", "Victim", "Part", "Damage", "Headshot"))
	table.insert(lines, string.rep("-", 80))
	if #hits == 0 then
		table.insert(lines, "No hit events recorded during this session.")
	else
		for _, hit in hits do
			local hs = if hit.isHeadshot then "[HEADSHOT]" else "NO"
			table.insert(
				lines,
				string.format(
					"%-12s | %-12s | %-20s | %-10s | %-8s | %s",
					hit.formattedTime,
					hit.weaponName,
					hit.victimName,
					hit.bodyPart,
					string.format("%d HP", hit.damage),
					hs
				)
			)
		end
	end
	table.insert(lines, "")
	table.insert(lines, "================================================================================")
	table.insert(lines, "                                  END OF REPORT                                 ")
	table.insert(lines, "================================================================================")

	local fullReport = table.concat(lines, "\n")
	local chunkSize = 40000
	local chunks: { string } = {}
	if #fullReport <= chunkSize then
		chunks = { fullReport }
	else
		for i = 1, #fullReport, chunkSize do
			table.insert(chunks, string.sub(fullReport, i, i + chunkSize - 1))
		end
	end

	Network.ScreenWatch.sendExportLogs(chunks, targetId, targetName, serialId)
end

return ScreenWatchWatcher
