--!strict
--!native
--!optimize 2

local VFXPool = {}

local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Constants)

export type BeamSet = {
	att0: Attachment,
	att1: Attachment,
	innerBeam: Beam,
	outerBeam: Beam,
	glowBeam: Beam,
}

local MAX_BEAM_SETS = 60
local MAX_PART_RAYS = 60
local PRE_ALLOCATE_COUNT = 28

local beamSetStack: { BeamSet } = {}
local partRayStack: { Part } = {}
local beamSetCount: number = 0
local partRayCount: number = 0

local poolFolder: Folder = nil :: any

local DEFAULT_BEAM_TEXTURE = Constants.Ray.BeamTexture
local IDENTITY_CFRAME = CFrame.identity
local OFFSCREEN_POS = Vector3.new(0, -1000, 0)

local function createPoolFolder(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "_VFXPool"
	folder.Parent = workspace.Terrain
	return folder
end

local function createBeamSetInstance(): BeamSet
	local anchor = workspace.Terrain

	local att0 = Instance.new("Attachment")
	att0.Name = "PoolAtt0"
	att0.WorldPosition = OFFSCREEN_POS
	att0.Parent = anchor

	local att1 = Instance.new("Attachment")
	att1.Name = "PoolAtt1"
	att1.WorldPosition = OFFSCREEN_POS
	att1.Parent = anchor

	local innerBeam = Instance.new("Beam")
	innerBeam.Name = "Inner"
	innerBeam.Enabled = false
	innerBeam.FaceCamera = true
	innerBeam.Segments = 1
	innerBeam.LightEmission = 1
	innerBeam.LightInfluence = 0
	innerBeam.Texture = DEFAULT_BEAM_TEXTURE
	innerBeam.Attachment0 = att0
	innerBeam.Attachment1 = att1
	innerBeam.Parent = anchor

	local outerBeam = Instance.new("Beam")
	outerBeam.Name = "Outer"
	outerBeam.Enabled = false
	outerBeam.FaceCamera = true
	outerBeam.Segments = 1
	outerBeam.LightEmission = 1
	outerBeam.LightInfluence = 0
	outerBeam.Texture = DEFAULT_BEAM_TEXTURE
	outerBeam.Attachment0 = att0
	outerBeam.Attachment1 = att1
	outerBeam.Parent = anchor

	local glowBeam = Instance.new("Beam")
	glowBeam.Name = "Glow"
	glowBeam.Enabled = false
	glowBeam.FaceCamera = true
	glowBeam.Segments = 1
	glowBeam.LightEmission = 1
	glowBeam.LightInfluence = 0
	glowBeam.ZOffset = -0.1
	glowBeam.Texture = DEFAULT_BEAM_TEXTURE
	glowBeam.Attachment0 = att0
	glowBeam.Attachment1 = att1
	glowBeam.Parent = anchor

	return {
		att0 = att0,
		att1 = att1,
		innerBeam = innerBeam,
		outerBeam = outerBeam,
		glowBeam = glowBeam,
	}
end

local function createPartRayInstance(): Part
	local part = Instance.new("Part")
	part.Name = "PoolRay"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = poolFolder
	return part
end

local function resetBeamSet(beamSet: BeamSet): ()
	beamSet.innerBeam.Enabled = false
	beamSet.outerBeam.Enabled = false
	beamSet.glowBeam.Enabled = false

	local anchor = workspace.Terrain
	if beamSet.att0.Parent ~= anchor then
		beamSet.att0.Parent = anchor
	end
	beamSet.att0.WorldPosition = OFFSCREEN_POS
	beamSet.att1.WorldPosition = OFFSCREEN_POS
end

local function resetPartRay(part: Part): ()
	part.Transparency = 1
	part.Size = Vector3.one
	part.CFrame = IDENTITY_CFRAME
	part.Color = Color3.new(0, 0, 0)
	part.Parent = poolFolder
end

local function destroyBeamSet(beamSet: BeamSet): ()
	beamSet.att0:Destroy()
	beamSet.att1:Destroy()
	beamSet.innerBeam:Destroy()
	beamSet.outerBeam:Destroy()
	beamSet.glowBeam:Destroy()
end

type ScheduledBeamSet = { beamSet: BeamSet, expiry: number }
type ScheduledPartRay = { part: Part, expiry: number }

local activeBeamSchedule: { ScheduledBeamSet } = {}
local activeBeamScheduleCount: number = 0
local activePartSchedule: { ScheduledPartRay } = {}
local activePartScheduleCount: number = 0

local beamEntryPool: { ScheduledBeamSet } = {}
local beamEntryPoolSize: number = 0
local partEntryPool: { ScheduledPartRay } = {}
local partEntryPoolSize: number = 0

local MAX_ENTRY_POOL = 64
local cleanupConnection: RBXScriptConnection? = nil

local function runScheduledCleanup()
	local now = os.clock()
	local i = 1
	while i <= activeBeamScheduleCount do
		local entry = activeBeamSchedule[i]
		if now >= entry.expiry then
			if beamSetCount >= MAX_BEAM_SETS then
				destroyBeamSet(entry.beamSet)
			else
				resetBeamSet(entry.beamSet)
				beamSetCount += 1
				beamSetStack[beamSetCount] = entry.beamSet
			end
			if beamEntryPoolSize < MAX_ENTRY_POOL then
				beamEntryPoolSize += 1
				beamEntryPool[beamEntryPoolSize] = entry
			end
			activeBeamSchedule[i] = activeBeamSchedule[activeBeamScheduleCount]
			activeBeamSchedule[activeBeamScheduleCount] = nil :: any
			activeBeamScheduleCount -= 1
		else
			i += 1
		end
	end
	local j = 1
	while j <= activePartScheduleCount do
		local entry = activePartSchedule[j]
		if now >= entry.expiry then
			if partRayCount >= MAX_PART_RAYS then
				entry.part:Destroy()
			else
				resetPartRay(entry.part)
				partRayCount += 1
				partRayStack[partRayCount] = entry.part
			end
			if partEntryPoolSize < MAX_ENTRY_POOL then
				partEntryPoolSize += 1
				partEntryPool[partEntryPoolSize] = entry
			end
			activePartSchedule[j] = activePartSchedule[activePartScheduleCount]
			activePartSchedule[activePartScheduleCount] = nil :: any
			activePartScheduleCount -= 1
		else
			j += 1
		end
	end
	if activeBeamScheduleCount == 0 and activePartScheduleCount == 0 and cleanupConnection then
		cleanupConnection:Disconnect()
		cleanupConnection = nil
	end
end

local function ensureCleanupRunning(): ()
	if not cleanupConnection then
		cleanupConnection = RunService.Heartbeat:Connect(runScheduledCleanup)
	end
end

function VFXPool.init(): ()
	poolFolder = createPoolFolder()
	beamSetCount = 0
	partRayCount = 0

	for _ = 1, PRE_ALLOCATE_COUNT do
		local beamSet = createBeamSetInstance()
		beamSetCount += 1
		beamSetStack[beamSetCount] = beamSet
	end

	for _ = 1, PRE_ALLOCATE_COUNT do
		local part = createPartRayInstance()
		partRayCount += 1
		partRayStack[partRayCount] = part
	end
end

function VFXPool.acquireBeamSet(): BeamSet
	if beamSetCount > 0 then
		local beamSet = beamSetStack[beamSetCount]
		beamSetStack[beamSetCount] = nil :: any
		beamSetCount -= 1
		return beamSet
	end
	return createBeamSetInstance()
end

function VFXPool.releaseBeamSet(beamSet: BeamSet): ()
	if beamSetCount >= MAX_BEAM_SETS then
		destroyBeamSet(beamSet)
		return
	end

	resetBeamSet(beamSet)
	beamSetCount += 1
	beamSetStack[beamSetCount] = beamSet
end

function VFXPool.acquirePartRay(): Part
	if partRayCount > 0 then
		local part = partRayStack[partRayCount]
		partRayStack[partRayCount] = nil :: any
		partRayCount -= 1
		return part
	end
	return createPartRayInstance()
end

function VFXPool.releasePartRay(part: Part): ()
	if partRayCount >= MAX_PART_RAYS then
		part:Destroy()
		return
	end

	resetPartRay(part)
	partRayCount += 1
	partRayStack[partRayCount] = part
end

function VFXPool.scheduleBeamSet(beamSet: BeamSet, duration: number): ()
	local entry: ScheduledBeamSet
	if beamEntryPoolSize > 0 then
		entry = beamEntryPool[beamEntryPoolSize]
		beamEntryPool[beamEntryPoolSize] = nil :: any
		beamEntryPoolSize -= 1
	else
		entry = { beamSet = beamSet, expiry = 0 }
	end
	entry.beamSet = beamSet
	entry.expiry = os.clock() + duration
	activeBeamScheduleCount += 1
	activeBeamSchedule[activeBeamScheduleCount] = entry
	ensureCleanupRunning()
end

function VFXPool.schedulePartRay(part: Part, duration: number): ()
	local entry: ScheduledPartRay
	if partEntryPoolSize > 0 then
		entry = partEntryPool[partEntryPoolSize]
		partEntryPool[partEntryPoolSize] = nil :: any
		partEntryPoolSize -= 1
	else
		entry = { part = part, expiry = 0 }
	end
	entry.part = part
	entry.expiry = os.clock() + duration
	activePartScheduleCount += 1
	activePartSchedule[activePartScheduleCount] = entry
	ensureCleanupRunning()
end

function VFXPool.cleanup(): ()
	if cleanupConnection then
		cleanupConnection:Disconnect()
		cleanupConnection = nil
	end

	for i = 1, activeBeamScheduleCount do
		destroyBeamSet(activeBeamSchedule[i].beamSet)
		activeBeamSchedule[i] = nil :: any
	end
	activeBeamScheduleCount = 0

	for i = 1, activePartScheduleCount do
		activePartSchedule[i].part:Destroy()
		activePartSchedule[i] = nil :: any
	end
	activePartScheduleCount = 0

	table.clear(beamEntryPool)
	beamEntryPoolSize = 0
	table.clear(partEntryPool)
	partEntryPoolSize = 0

	for i = 1, beamSetCount do
		destroyBeamSet(beamSetStack[i])
		beamSetStack[i] = nil :: any
	end
	beamSetCount = 0

	for i = 1, partRayCount do
		partRayStack[i]:Destroy()
		partRayStack[i] = nil :: any
	end
	partRayCount = 0

	if poolFolder then
		poolFolder:Destroy()
		poolFolder = nil :: any
	end
end

return VFXPool
