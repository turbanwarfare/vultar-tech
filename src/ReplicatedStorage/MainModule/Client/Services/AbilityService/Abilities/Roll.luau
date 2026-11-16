--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local AbilityConfig = require(MainModule.Shared.Config.AbilityConfig)
local WeaponConfig = require(MainModule.Shared.Config.Weapons.WeaponConfig)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

local Stats = AbilityConfig.Abilities.Roll.Stats
local WALK_SPEED = WeaponConfig.DefaultSpeeds.Walk
local LAUNCH_FORCE = 1e6

local getMovementService = LazyService.create(MainModule, "MovementService")
local getWeaponService = LazyService.create(MainModule, "WeaponService")

local Roll = {}

local rollAnimation: Animation? = nil
local rollTrack: AnimationTrack? = nil
local rolling = false
local rollSpeed = Stats.SPEED
local preRollSpeed = WALK_SPEED
local rollHumanoid: Humanoid? = nil
local activeRoll = 0
local speedGuard: RBXScriptConnection? = nil

local function releaseSpeedGuard(): ()
	local guard = speedGuard
	if guard then
		guard:Disconnect()
		speedGuard = nil
	end
end

local function playAnimation(humanoid: Humanoid): ()
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator or not rollAnimation then
		return
	end
	if not rollTrack then
		local ok, track = pcall(function()
			return animator:LoadAnimation(rollAnimation :: Animation)
		end)
		rollTrack = if ok then track else nil
	end
	local track = rollTrack
	if track then
		track.Priority = Enum.AnimationPriority.Action4
		track:Play(0.05)
	end
end

local function launch(character: Model, humanoid: Humanoid): ()
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local direction = humanoid.MoveDirection
	if direction:Dot(direction) < 0.01 then
		direction = root.CFrame.LookVector
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat:Dot(flat) < 0.01 then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "RollAttachment"
	attachment.Parent = root

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "RollLaunch"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.MaxAxesForce = Vector3.new(LAUNCH_FORCE, 0, LAUNCH_FORCE)
	velocity.VectorVelocity = flat.Unit * Stats.LAUNCH_SPEED
	velocity.Parent = root

	task.delay(Stats.LAUNCH_TIME, velocity.Destroy, velocity)
	task.delay(Stats.LAUNCH_TIME, attachment.Destroy, attachment)
end

local function finish(): ()
	rolling = false
	releaseSpeedGuard()
	local track = rollTrack
	if track then
		track:Stop(0.15)
	end
	local movement = getMovementService()
	local humanoid = rollHumanoid
	rollHumanoid = nil
	if movement then
		if movement:IsCrouching() then
			movement:SetCrouching(false)
		end
		movement:SetSprinting(movement:IsSprinting())
	elseif humanoid then
		humanoid.WalkSpeed = preRollSpeed
	end
end

function Roll.init(): ()
	local animation = Instance.new("Animation")
	animation.AnimationId = Stats.ANIMATION
	rollAnimation = animation
end

function Roll.getPayload(character: Model): boolean?
	if rolling then
		activeRoll += 1
		finish()
		return nil
	end
	if not character:FindFirstChildOfClass("Humanoid") then
		return nil
	end
	local weapon = getWeaponService()
	if weapon and (weapon:IsFiring() or weapon:IsZooming()) then
		return nil
	end
	return true
end

function Roll.onUsed(character: Model, humanoid: Humanoid): ()
	activeRoll += 1
	local id = activeRoll
	rolling = true

	launch(character, humanoid)

	preRollSpeed = humanoid.WalkSpeed
	rollHumanoid = humanoid
	rollSpeed = Stats.SPEED + math.max(preRollSpeed - WALK_SPEED, 0)
	humanoid.WalkSpeed = rollSpeed
	releaseSpeedGuard()
	speedGuard = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if humanoid.WalkSpeed ~= rollSpeed then
			humanoid.WalkSpeed = rollSpeed
		end
	end)
	playAnimation(humanoid)

	task.delay(Stats.DURATION, function()
		if activeRoll == id then
			finish()
		end
	end)
end

function Roll.onCharacterAdded(): ()
	rollTrack = nil
	rolling = false
	rollHumanoid = nil
	activeRoll += 1
	releaseSpeedGuard()
end

function Roll.cleanup(): ()
	rollTrack = nil
	rolling = false
	rollHumanoid = nil
	activeRoll += 1
	releaseSpeedGuard()
end

return Roll
