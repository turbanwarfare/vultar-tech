--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")

local RecoilController = {}

local GUN_RECOIL = 0.5
local RECOIL_DECAY_SPEED = 18
local RECOIL_IMPULSE_STRENGTH = 1.0

local currentRecoil = 0
local grip: Motor6D? = nil
local baseGripC1: CFrame? = nil
local connection: RBXScriptConnection? = nil
local isActive = false

local function stopUpdate(): ()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	isActive = false
end

local function updateRecoil(dt: number): ()
	debug.profilebegin("WeaponService::recoilUpdate")
	currentRecoil *= math.exp(-RECOIL_DECAY_SPEED * dt)

	if currentRecoil < 0.001 then
		currentRecoil = 0
		if grip and baseGripC1 then
			grip.C1 = baseGripC1
		end
		stopUpdate()
		return
	end

	if grip and baseGripC1 then
		grip.C1 = baseGripC1 * CFrame.new(0, 0, currentRecoil * GUN_RECOIL)
	end
	debug.profileend()
end

local function startUpdate(): ()
	if isActive then
		return
	end
	isActive = true
	connection = RunService.RenderStepped:Connect(updateRecoil)
end

function RecoilController.setGrip(newGrip: Motor6D?): ()
	grip = newGrip
	if grip then
		baseGripC1 = grip.C1
	else
		baseGripC1 = nil
	end
	currentRecoil = 0
end

function RecoilController.applyPulse(strength: number?): ()
	local impulse = (strength or 1) * RECOIL_IMPULSE_STRENGTH
	currentRecoil = math.min(currentRecoil + impulse, 2)
	startUpdate()
end

function RecoilController.start(): ()
end

function RecoilController.stop(): ()
	stopUpdate()

	if grip and baseGripC1 then
		grip.C1 = baseGripC1
	end

	grip = nil
	baseGripC1 = nil
	currentRecoil = 0
end

function RecoilController.cleanup(): ()
	RecoilController.stop()
end

return RecoilController
