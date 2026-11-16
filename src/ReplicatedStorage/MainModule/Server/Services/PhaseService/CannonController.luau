--!strict
--!native
--!optimize 2


local ROTATE_INTERVAL = 60
local SHOOT_DELAY = 2
local ROTATE_TIME = 10

local MAX_ROTATION_DEGREES = 45
local INITIAL_YAW_DEGREES = 0

local backwardPos = Vector3.new(922.523, 548.404, -913.717)
local forwardPos = Vector3.new(904.693, 569.293, -882.834)
local worldOffset = backwardPos - forwardPos
local studioOrientation = CFrame.Angles(math.rad(0), math.rad(60), math.rad(-30.362))
local RECOIL_OFFSET = studioOrientation:VectorToObjectSpace(worldOffset)

local RECOIL_TIME = 0.15
local RETURN_TIME = 0.35

local maxRotationRad = math.rad(MAX_ROTATION_DEGREES)
local initialYawRad = math.rad(INITIAL_YAW_DEGREES)

local rng = Random.new()

local CannonController = {}

local cannon: Model? = nil
local actualCannon: Model? = nil
local running: boolean = false
local cannonThread: thread? = nil

local function tweenPivot(model: Model, startCFrame: CFrame, endCFrame: CFrame, duration: number): ()
	local elapsed = 0
	while elapsed < duration and running do
		local alpha = elapsed / duration
		model:PivotTo(startCFrame:Lerp(endCFrame, alpha))
		elapsed += task.wait(1 / 15)
	end
	model:PivotTo(endCFrame)
end

local function playSound(sound: Sound?): ()
	if not sound then return end
	sound.TimePosition = 0
	sound:Play()
	task.delay(5, function()
		if sound.IsPlaying then
			sound:Stop()
		end
	end)
end

local function setInitialOrientation(): ()
	if not cannon then return end
	local currentPivot = cannon:GetPivot()
	local initialPivot = CFrame.new(currentPivot.Position) * CFrame.Angles(0, initialYawRad, 0)
	cannon:PivotTo(initialPivot)
end

local function rotateCannon(): ()
	if not cannon then return end
	local currentPivot = cannon:GetPivot()
	local minYaw = initialYawRad - maxRotationRad
	local maxYaw = initialYawRad + maxRotationRad
	local randomYaw = minYaw + rng:NextNumber() * (maxYaw - minYaw)
	local newPivot = CFrame.new(currentPivot.Position) * CFrame.Angles(0, randomYaw, 0)
	tweenPivot(cannon, currentPivot, newPivot, ROTATE_TIME)
end

local function shootCannon(): ()
	if not actualCannon then return end
	local startPivot = actualCannon:GetPivot()
	local recoilPivot = startPivot * CFrame.new(RECOIL_OFFSET)
	tweenPivot(actualCannon, startPivot, recoilPivot, RECOIL_TIME)
	playSound(actualCannon:FindFirstChild("Fire") :: Sound?)
	tweenPivot(actualCannon, recoilPivot, startPivot, RETURN_TIME)
end

local function cannonLoop(): ()
	setInitialOrientation()
	while running do
		rotateCannon()
		if not running then break end

		task.wait(SHOOT_DELAY)
		if not running then break end
		shootCannon()

		task.wait(ROTATE_INTERVAL - SHOOT_DELAY)
	end
end

function CannonController.start(): ()
	if running then return end

	local cannonRoot = workspace:FindFirstChild("Cannon")
	if not cannonRoot then return end

	local cannonModel = cannonRoot:FindFirstChild("CannonModel") :: Model?
	if not cannonModel or not cannonModel.PrimaryPart then return end

	local actual = cannonModel:FindFirstChild("ActualCannon") :: Model?
	if not actual or not actual.PrimaryPart then return end

	cannon = cannonModel
	actualCannon = actual
	running = true
	cannonThread = task.spawn(cannonLoop)
end

function CannonController.stop(): ()
	if not running then return end
	running = false
	if cannonThread then
		task.cancel(cannonThread)
		cannonThread = nil
	end
	cannon = nil
	actualCannon = nil
end

return CannonController
