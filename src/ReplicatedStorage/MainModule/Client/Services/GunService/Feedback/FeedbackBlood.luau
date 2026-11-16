--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local ObjectPool = require(MainModule.Shared.Utils.State.ObjectPool)

local Constants = require(script.Parent.Parent.Constants)
local Cache = require(script.Parent.Parent.Cache)

local FeedbackBlood = {}

type BloodUnit = {
	attachment: Attachment,
	emitter: ParticleEmitter,
}

local bloodPool: ObjectPool.ObjectPool<BloodUnit>? = nil

local BLOOD_TEXTURE = "rbxassetid://243457340"
local BLOOD_COLOR_DARK = Color3.fromRGB(120, 15, 10)
local BLOOD_COLOR_MID = Color3.fromRGB(145, 20, 15)

local BLOOD_COLOR_SEQ = ColorSequence.new({
	ColorSequenceKeypoint.new(0, BLOOD_COLOR_MID),
	ColorSequenceKeypoint.new(1, BLOOD_COLOR_DARK),
})
local BLOOD_SIZE_SEQ = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.2),
	NumberSequenceKeypoint.new(0.3, 0.3),
	NumberSequenceKeypoint.new(1, 0.12),
})
local BLOOD_TRANSPARENCY_SEQ = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.25),
	NumberSequenceKeypoint.new(0.4, 0.4),
	NumberSequenceKeypoint.new(0.8, 0.65),
	NumberSequenceKeypoint.new(1, 1),
})
local BLOOD_LIFETIME = NumberRange.new(0.25, 0.45)
local BLOOD_SPEED = NumberRange.new(6, 12)
local BLOOD_SPREAD = Vector2.new(70, 70)
local BLOOD_ACCELERATION = Vector3.new(0, -25, 0)
local BLOOD_ROT_SPEED = NumberRange.new(-90, 90)
local BLOOD_ROTATION = NumberRange.new(0, 360)

local function createBloodUnit(): BloodUnit
	local att = Instance.new("Attachment")
	att.Name = "BloodAnchor"

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "BloodSplatter"
	emitter.Texture = BLOOD_TEXTURE
	emitter.Color = BLOOD_COLOR_SEQ
	emitter.Size = BLOOD_SIZE_SEQ
	emitter.Transparency = BLOOD_TRANSPARENCY_SEQ
	emitter.Lifetime = BLOOD_LIFETIME
	emitter.Speed = BLOOD_SPEED
	emitter.SpreadAngle = BLOOD_SPREAD
	emitter.Acceleration = BLOOD_ACCELERATION
	emitter.Drag = 3
	emitter.RotSpeed = BLOOD_ROT_SPEED
	emitter.Rotation = BLOOD_ROTATION
	emitter.LightEmission = 0.4
	emitter.LightInfluence = 0.2
	emitter.Brightness = 1.2
	emitter.Orientation = Enum.ParticleOrientation.FacingCamera
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Parent = att

	return { attachment = att, emitter = emitter }
end

function FeedbackBlood.init(): ()
	bloodPool = ObjectPool.new({
		factory = createBloodUnit,
		maxSize = Constants.BloodSplatter.PoolSize,
		onReset = function(unit: BloodUnit)
			unit.attachment.Parent = nil
			unit.attachment.CFrame = CFrame.identity
		end,
		onDestroy = function(unit: BloodUnit)
			unit.attachment:Destroy()
		end,
	})

	bloodPool:preWarm(10)
end

local function returnBloodUnit(unit: BloodUnit): ()
	if bloodPool then
		bloodPool:returnToPool(unit)
	end
end

function FeedbackBlood.show(hitPos: Vector3, normal: Vector3): ()
	if not Cache.getBloodIndicatorEnabled() then
		return
	end

	if not bloodPool then
		return
	end

	local unit = bloodPool:get()
	unit.attachment.Parent = workspace.Terrain
	unit.attachment.WorldCFrame = CFrame.lookAt(hitPos, hitPos + normal)
	unit.emitter:Emit(Constants.BloodSplatter.EmitCount)

	task.delay(Constants.BloodSplatter.CleanupDelay, returnBloodUnit, unit)
end

function FeedbackBlood.cleanup(): ()
	if bloodPool then
		bloodPool:clear()
		bloodPool = nil
	end
end

return FeedbackBlood
