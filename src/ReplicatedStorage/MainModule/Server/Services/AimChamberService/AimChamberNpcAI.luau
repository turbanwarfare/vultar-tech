--!strict
--!native
--!optimize 2

local Workspace = workspace
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local AimChamberConfig = require(MainModule.Shared.Config.AimChamberConfig)
local Network = require(MainModule.Shared.Network)
local AimChamberRecordedPaths = require(MainModule.Shared.Config.AimChamberRecordedPaths)
local StatsService = require(MainModule.Server.Services.StatsService)
local GunStats = require(MainModule.Shared.Config.GunStats)
local AimChamberMatchManagerRef = nil

type AimChamberSettings = AimChamberConfig.AimChamberSettings
type AiDifficultyConfig = AimChamberConfig.AiDifficultyConfig

local AI_K = AimChamberConfig.AI_PRESET_CONSTANTS

local MAX_PREDICTION_OFFSET_STUDS = 12

export type NpcInstance = {
	Model: Model,
	Humanoid: Humanoid,
	RootPart: BasePart,
	GunModel: Model?,
	IdleTrack: AnimationTrack?,
	CrouchTrack: AnimationTrack?,
	IsAlive: boolean,
	StrafeDirection: number,
	NextDecisionTime: number,
	NextShootTime: number,
	NextJumpTime: number,
	NextCrouchEndTime: number,
	NextFlipTime: number,
	IsJumping: boolean,
	IsCrouching: boolean,
	IsFrozen: boolean,
	FreezeEndTime: number,
	AimLerpTarget: Vector3,
	OriginalHipHeight: number,
	JumpConnection: RBXScriptConnection?,
	DiedConnection: RBXScriptConnection?,
	IdleConnection: RBXScriptConnection?,
	ActiveModifiers: {
		spin: boolean,
		bunnyhop: boolean,
		strafe: boolean,
		randomJump: boolean,
		freeze: boolean,
		crouch: boolean,
	},
	PlaybackPath: { any }?,
	PlaybackStartTime: number?,
	SpawnAnchor: CFrame?,
	CursorEvading: boolean,
	CursorEvasionStartTime: number,
	CursorEvasionEndTime: number,
	CursorEvasionCooldownEnd: number,
	CursorEvasionStartAnchor: CFrame?,
	CursorEvasionTargetAnchor: CFrame?,
	HealthConnection: RBXScriptConnection?,
}

export type NpcManager = {
	Settings: AimChamberSettings,
	Difficulty: string,
	TargetPlayer: Player,
	Npc: NpcInstance?,
	UpdateThread: thread?,
	SpawnThread: thread?,
	SpawnPoints: { BasePart },
	IsRunning: boolean,
	OnPlayerDamaged: ((damage: number) -> ())?,
	OnNpcKilled: (() -> ())?,
}

local AimChamberNpcAI = {}

local rng = Random.new()

local descriptionCache: { [number]: HumanoidDescription } = {}

local function getOrCreateHumanoidDescription(userId: number, config: any): HumanoidDescription?
	local baseDesc = descriptionCache[userId]
	if not baseDesc then
		local success, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(userId)
		end)
		if success and desc then
			descriptionCache[userId] = desc
			baseDesc = desc
		end
	end
	if not baseDesc then
		return nil
	end

	local descClone = baseDesc:Clone()
	if config.ForceShirt then
		descClone.Shirt = config.ForceShirt
	end
	if config.ForcePants then
		descClone.Pants = config.ForcePants
	end
	if config.IgnoreHats then
		descClone.HatAccessory = ""
	end
	if config.ForceHat then
		if descClone.HatAccessory == "" then
			descClone.HatAccessory = tostring(config.ForceHat)
		else
			descClone.HatAccessory = descClone.HatAccessory .. "," .. tostring(config.ForceHat)
		end
	end
	if config.IgnoreHair then
		descClone.HairAccessory = ""
	end
	if config.IgnoreAccessories then
		descClone.FaceAccessory = ""
		descClone.NeckAccessory = ""
		descClone.ShoulderAccessory = ""
		descClone.FrontAccessory = ""
		descClone.BackAccessory = ""
		descClone.WaistAccessory = ""
	end
	return descClone
end

task.spawn(function()
	if AimChamberConfig.TIER_AVATAR_CONFIG then
		for _, cfg in AimChamberConfig.TIER_AVATAR_CONFIG do
			if cfg.UserId and cfg.UserId > 1 and not descriptionCache[cfg.UserId] then
				pcall(function()
					local desc = Players:GetHumanoidDescriptionFromUserId(cfg.UserId)
					if desc then
						descriptionCache[cfg.UserId] = desc
					end
				end)
			end
		end
	end
end)

local function getEffectiveConstants(manager: NpcManager): typeof(AimChamberConfig.AI_PRESET_CONSTANTS)
	local base = AimChamberConfig.AI_PRESET_CONSTANTS
	local profile = manager.Settings and manager.Settings.AiMovementProfile
	if not profile then
		return base
	end
	local overrides = AimChamberConfig.AI_TIER_OVERRIDES and AimChamberConfig.AI_TIER_OVERRIDES[profile]
	if not overrides then
		return base
	end
	local merged = table.clone(base) :: any
	for k, v in overrides do
		merged[k] = v
	end
	return merged
end

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getRandomSpawnPosition(spawnPoints: { BasePart }): Vector3
	if #spawnPoints > 0 then
		local spawnPart = spawnPoints[rng:NextInteger(1, #spawnPoints)]
		local offset = Vector3.new(rng:NextNumber(-AI_K.SPAWN_JITTER, AI_K.SPAWN_JITTER), 0, rng:NextNumber(-AI_K.SPAWN_JITTER, AI_K.SPAWN_JITTER))
		return spawnPart.Position + offset
	end
	return Vector3.new(rng:NextNumber(-AI_K.SPAWN_RADIUS, AI_K.SPAWN_RADIUS), AI_K.SPAWN_HEIGHT_OFFSET, rng:NextNumber(-AI_K.SPAWN_RADIUS, AI_K.SPAWN_RADIUS))
end

local function equipGun(npcModel: Model, humanoid: Humanoid): (Model?, AnimationTrack?)
	local gunModel = npcModel:FindFirstChild(AI_K.GUN_ASSET_NAME) :: Model?

	if not gunModel then
		local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
		if assetsFolder then
			local gunTemplate = assetsFolder:FindFirstChild(AI_K.GUN_ASSET_NAME)
			if gunTemplate and gunTemplate:IsA("Model") then
				local clonedGun = gunTemplate:Clone() :: Model
				local rightArm = npcModel:FindFirstChild("Right Arm") :: BasePart?
				if not rightArm then
					rightArm = npcModel:FindFirstChild("RightHand") :: BasePart?
				end
				local bodyAttach = clonedGun:FindFirstChild("BodyAttach") :: BasePart?
				if rightArm and bodyAttach then
					local motor = Instance.new("Motor6D")
					motor.Name = "GunGrip"
					motor.Part0 = rightArm
					motor.Part1 = bodyAttach
					motor.C0 = CFrame.new(0, -1, 0)
					motor.C1 = CFrame.identity
					motor.Parent = rightArm

					clonedGun.Parent = npcModel
					gunModel = clonedGun
				else
					clonedGun:Destroy()
				end
			end
		end
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local idleTrack: AnimationTrack? = nil
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = "rbxassetid://" .. tostring(AI_K.BR16_IDLE_ANIM_ID)

	local success, track = pcall(function()
		return animator:LoadAnimation(idleAnim)
	end)
	idleAnim:Destroy()

	if success and track then
		idleTrack = track
		idleTrack.Looped = true
		idleTrack.Priority = Enum.AnimationPriority.Action4
	end

	return gunModel, idleTrack
end

local function createNpcModel(): (Model?, Humanoid?, BasePart?)
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then
		return nil, nil, nil
	end

	local npcTemplate = assetsFolder:FindFirstChild(AI_K.NPC_ASSET_NAME)
	if not npcTemplate or not npcTemplate:IsA("Model") then
		return nil, nil, nil
	end

	local model = npcTemplate:Clone() :: Model
	model.Name = "Training Bot"

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?

	if humanoid and rootPart then
		model.PrimaryPart = rootPart
		humanoid.WalkSpeed = AI_K.ORBIT_WALK_SPEED
		humanoid.UseJumpPower = true
		humanoid.JumpPower = AI_K.JUMP_POWER
		humanoid.AutoRotate = true

		for _, desc in model:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.Anchored = false
				desc.CastShadow = false
			end
		end

		return model, humanoid, rootPart
	end

	model:Destroy()
	return nil, nil, nil
end

local function applyCrouch(npc: NpcInstance): ()
	if npc.IsCrouching or not npc.IsAlive then
		return
	end

	npc.IsCrouching = true
	npc.NextCrouchEndTime = os.clock() + rng:NextNumber(AI_K.CROUCH_DURATION_MIN, AI_K.CROUCH_DURATION_MAX)

	local humanoid = npc.Humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	if not npc.CrouchTrack then
		local anim = Instance.new("Animation")
		anim.AnimationId = AI_K.CROUCH_ANIM_ID
		npc.CrouchTrack = animator:LoadAnimation(anim)
		anim:Destroy()
	end

	if npc.CrouchTrack then
		npc.CrouchTrack:Play()
	end

	humanoid.HipHeight = npc.OriginalHipHeight - AI_K.CROUCH_HIP_REDUCTION
end

local function removeCrouch(npc: NpcInstance): ()
	if not npc.IsCrouching then
		return
	end

	npc.IsCrouching = false

	if npc.CrouchTrack then
		npc.CrouchTrack:Stop()
	end

	npc.Humanoid.HipHeight = npc.OriginalHipHeight
end

local function cleanupNpc(manager: NpcManager, targetNpc: NpcInstance?): ()
	local npc = targetNpc or manager.Npc
	if not npc then
		return
	end

	npc.IsAlive = false

	if npc.HealthConnection then
		npc.HealthConnection:Disconnect()
		npc.HealthConnection = nil
	end

	if npc.JumpConnection then
		npc.JumpConnection:Disconnect()
		npc.JumpConnection = nil
	end

	if npc.DiedConnection then
		npc.DiedConnection:Disconnect()
		npc.DiedConnection = nil
	end

	if npc.IdleConnection then
		npc.IdleConnection:Disconnect()
		npc.IdleConnection = nil
	end

	if npc.CrouchTrack then
		npc.CrouchTrack:Stop()
		npc.CrouchTrack:Destroy()
		npc.CrouchTrack = nil
	end

	if npc.IdleTrack then
		npc.IdleTrack:Stop()
		npc.IdleTrack:Destroy()
		npc.IdleTrack = nil
	end

	if npc.Model and npc.Model.Parent then
		npc.Model:Destroy()
	end

	if manager.Npc == npc then
		manager.Npc = nil
	end
end

local function rollModifiers(
	difficultyConfig: AiDifficultyConfig,
	isHard: boolean,
	effectiveK: typeof(AimChamberConfig.AI_PRESET_CONSTANTS)
): {
	spin: boolean,
	bunnyhop: boolean,
	strafe: boolean,
	randomJump: boolean,
	freeze: boolean,
	crouch: boolean,
}
	local mp = difficultyConfig.MovementProfile

	local comboMax: number
	if isHard then
		comboMax = (effectiveK :: any).COMBO_MAX_HARD or AI_K.COMBO_MAX_HARD
	else
		comboMax = (effectiveK :: any).COMBO_MAX_EASY or AI_K.COMBO_MAX_EASY
	end

	local candidates: { { key: string, chance: number } } = {
		{ key = "spin", chance = mp.SpinChance },
		{ key = "strafe", chance = mp.StrafeChance },
		{ key = "randomJump", chance = mp.RandomJumpChance },
		{ key = "bunnyhop", chance = mp.BunnyhopChance },
		{ key = "crouch", chance = mp.CrouchChance },
		{ key = "freeze", chance = mp.FreezeChance },
	}

	local rolled: { [string]: boolean } = {}
	local activeCount = 0

	for _, entry in candidates do
		if activeCount >= comboMax then
			break
		end
		if rng:NextNumber() < entry.chance then
			rolled[entry.key] = true
			activeCount += 1
		end
	end

	return {
		spin = rolled["spin"] == true,
		bunnyhop = rolled["bunnyhop"] == true,
		strafe = rolled["strafe"] == true,
		randomJump = rolled["randomJump"] == true,
		freeze = rolled["freeze"] == true,
		crouch = rolled["crouch"] == true,
	}
end

local function fireAtPlayer(manager: NpcManager, npc: NpcInstance, targetRoot: BasePart): ()
	local targetPlayer = manager.TargetPlayer
	if not targetPlayer or not targetPlayer.Parent then
		return
	end

	local character = targetPlayer.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local npcRoot = npc.RootPart
	if not npcRoot or not npcRoot.Parent then
		return
	end

	local muzzlePos = npcRoot.Position + Vector3.new(0, 1.5, 0)
	local aimTarget = npc.AimLerpTarget

	local diffConfig = AimChamberConfig.getAiDifficultyConfig(manager.Difficulty)
	local isStandingStill = targetRoot.AssemblyLinearVelocity.Magnitude ^ 2 < 0.04

	local AiWeapon = manager.Settings and manager.Settings.AiWeapon or "H-82"
	
	local accuracyDeg = if isStandingStill then 0 else diffConfig.Accuracy

	local spreadMult = if manager.Settings and manager.Settings.AiNpcAccuracy
		then math.max(manager.Settings.AiNpcAccuracy, 0.01)
		else 1.0
	accuracyDeg = accuracyDeg * spreadMult

	local jitterH = math.rad(rng:NextNumber(-accuracyDeg, accuracyDeg))
	local jitterV = math.rad(rng:NextNumber(-accuracyDeg * 0.5, accuracyDeg * 0.5))

	local actualHitChance = diffConfig.HitChance
	if actualHitChance then
		if spreadMult < 1.0 then
			actualHitChance = actualHitChance + (1.0 - actualHitChance) * (1.0 - spreadMult)
		else
			actualHitChance = actualHitChance / spreadMult
		end
	end

	if actualHitChance and rng:NextNumber() > actualHitChance then
		local missSpread = math.rad(rng:NextNumber(2.5, 5.0) * spreadMult)
		jitterH += missSpread * (if rng:NextNumber() > 0.5 then 1 else -1)
	end

	local toTarget = (aimTarget - muzzlePos)
	local dist = toTarget.Magnitude
	if dist < 0.1 then
		return
	end
	local dir = toTarget.Unit

	local cosH = math.cos(jitterH)
	local sinH = math.sin(jitterH)
	local jitteredDir = Vector3.new(dir.X * cosH - dir.Z * sinH, dir.Y + jitterV, dir.X * sinH + dir.Z * cosH).Unit

	local jitteredTarget = muzzlePos + jitteredDir * math.max(dist, 500)

	if AimChamberMatchManagerRef then
		AimChamberMatchManagerRef.recordBotShot(targetPlayer)
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = { npc.Model }
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = Workspace:Raycast(muzzlePos, jitteredDir * 500, rayParams)
	local visualTarget = jitteredTarget

	if result then
		visualTarget = result.Position
		local hitPart = result.Instance
		local hitModel = hitPart:FindFirstAncestorOfClass("Model")
		if hitModel == character then
			if AimChamberMatchManagerRef then
				AimChamberMatchManagerRef.recordBotHit(targetPlayer)
			end
			if manager.OnPlayerDamaged then
				local dmg = if AiWeapon == "GPR" then 10 else AI_K.BR16_BASE_DAMAGE
				manager.OnPlayerDamaged(dmg)
			end
		end
	end

	Network.AimChamber.fireNpcShot(targetPlayer, {
		origin = muzzlePos,
		target = visualTarget,
		gunName = AiWeapon,
	})
end

local function updateNpc(manager: NpcManager): ()
	local npc = manager.Npc
	if not npc or not npc.IsAlive then
		return
	end

	local targetRoot = getCharacterRoot(manager.TargetPlayer)
	if not targetRoot then
		return
	end

	local effectiveK = getEffectiveConstants(manager)
	local now = os.clock()
	local character = manager.TargetPlayer.Character
	local targetTorso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or targetRoot)
	local targetPos = targetTorso.Position
	local npcPos = npc.RootPart.Position

	local distToTarget = (targetPos - npcPos).Magnitude
	local velocity = targetRoot.AssemblyLinearVelocity
	local rawPredictionOffset = Vector3.new(velocity.X, velocity.Y * 0.1, velocity.Z) * math.clamp(distToTarget / 400, 0, 0.2)
	local predictionOffset = if rawPredictionOffset.Magnitude ^ 2 > MAX_PREDICTION_OFFSET_STUDS ^ 2
		then rawPredictionOffset.Unit * MAX_PREDICTION_OFFSET_STUDS
		else rawPredictionOffset

	local spreadMult = if manager.Settings and manager.Settings.AiNpcAccuracy
		then math.max(manager.Settings.AiNpcAccuracy, 0.01)
		else 1.0

	if manager.Difficulty == "HARD" then
		predictionOffset = Vector3.zero
	end

	local predictedPos = targetPos + predictionOffset

	local aimLerpAlpha = (effectiveK :: any).AIM_LERP_ALPHA or AI_K.AIM_LERP_ALPHA
	if manager.Difficulty == "HARD" then
		aimLerpAlpha = 1.0
	else
		if spreadMult < 1.0 then
			aimLerpAlpha = math.clamp(aimLerpAlpha + (1.0 - aimLerpAlpha) * (1.0 - spreadMult), 0, 1)
		elseif spreadMult > 1.0 then
			aimLerpAlpha = math.clamp(aimLerpAlpha / spreadMult, 0.1, 1)
		end
	end
	npc.AimLerpTarget = npc.AimLerpTarget:Lerp(predictedPos, aimLerpAlpha)

	local toPlayer = predictedPos - npcPos
	local dist = toPlayer.Magnitude

	if not npc.PlaybackPath and npc.IsCrouching and now >= npc.NextCrouchEndTime then
		removeCrouch(npc)
	end

	local AiWeapon = manager.Settings and manager.Settings.AiWeapon or "H-82"
	if AiWeapon == "GPR" and npc.IsCrouching then
		removeCrouch(npc)
	end

	local tierSpeedMult = (effectiveK :: any).ORBIT_WALK_SPEED_MULTIPLIER or 1.0
	local activeWalkSpeed = AI_K.ORBIT_WALK_SPEED * tierSpeedMult
	if manager.Difficulty == "HARD" then
		activeWalkSpeed = AI_K.ORBIT_WALK_SPEED * 1.4
	end

	if npc.IsFrozen and now >= npc.FreezeEndTime then
		npc.IsFrozen = false
		npc.Humanoid.WalkSpeed = activeWalkSpeed
	end

	if now >= npc.NextDecisionTime then
		local diffConfig = AimChamberConfig.getAiDifficultyConfig(manager.Difficulty)
		local isHard = manager.Difficulty == "HARD"
		local newMods = rollModifiers(diffConfig, isHard, effectiveK)
		npc.ActiveModifiers = newMods

		if newMods.freeze then
			npc.IsFrozen = true
			npc.FreezeEndTime = now + rng:NextNumber(AI_K.FREEZE_MIN_DURATION, AI_K.FREEZE_MAX_DURATION)
			npc.Humanoid.WalkSpeed = 0
		else
			npc.IsFrozen = false
			npc.Humanoid.WalkSpeed = activeWalkSpeed
		end

		if newMods.crouch and not npc.IsCrouching then
			applyCrouch(npc)
		elseif not newMods.crouch and npc.IsCrouching then
			removeCrouch(npc)
		end

		if newMods.strafe then
			npc.StrafeDirection = if rng:NextNumber() < 0.5 then 1 else -1
		end

		local tickMin = (effectiveK :: any).DECISION_TICK_MIN or AI_K.DECISION_TICK_MIN
		local tickMax = (effectiveK :: any).DECISION_TICK_MAX or AI_K.DECISION_TICK_MAX
		npc.NextDecisionTime = now + rng:NextNumber(tickMin, tickMax)
	end

	if now >= npc.NextFlipTime then
		npc.StrafeDirection = -npc.StrafeDirection
		if manager.Difficulty == "HARD" then
			npc.NextFlipTime = now + rng:NextNumber(0.15, 0.65)
		else
			local flipMin = (effectiveK :: any).FLIP_MIN_EASY or 0.8
			local flipMax = (effectiveK :: any).FLIP_MAX_EASY or 2.0
			npc.NextFlipTime = now + rng:NextNumber(flipMin, flipMax)
		end
	end

	local playedPath = false

	local cursorEvasionEnabled = (effectiveK :: any).CURSOR_EVASION_ENABLED == true
	local isEvading = false
	local evadeDir = Vector3.zero
	if cursorEvasionEnabled then
		local origin = manager.TargetPlayer:GetAttribute("AimChamberCursorOrigin")
		local dir = manager.TargetPlayer:GetAttribute("AimChamberCursorDir")
		if typeof(origin) == "Vector3" and typeof(dir) == "Vector3" then
			local toNpc = npcPos - origin
			local distToRay = toNpc:Cross(dir).Magnitude
			
			local threshold = (effectiveK :: any).CURSOR_EVASION_RADIUS or 3.5

			if distToRay <= threshold then
				isEvading = true
				local toNpcFlat = Vector3.new(npcPos.X - targetPos.X, 0, npcPos.Z - targetPos.Z)
				local toNpcFlatMag = toNpcFlat.Magnitude
				if toNpcFlatMag > 0.01 then
					local toNpcUnit = toNpcFlat / toNpcFlatMag
					evadeDir = Vector3.new(-toNpcUnit.Z, 0, toNpcUnit.X).Unit * npc.StrafeDirection
				end
			end
		end
	end
	npc.CursorEvading = isEvading

	if npc.PlaybackPath and npc.PlaybackStartTime and npc.SpawnAnchor then
		local path = npc.PlaybackPath
		local speedMult = (effectiveK :: any).PATH_SPEED_MULTIPLIER or 1.0
		local elapsed = (now - npc.PlaybackStartTime) * speedMult
		local lastFrame = path[#path]
		if lastFrame then
			local totalDuration = lastFrame.Time
			local t = elapsed
			if totalDuration > 0 then
				local cycle = elapsed // totalDuration
				if cycle % 2 == 1 then
					t = totalDuration - (elapsed % totalDuration)
				else
					t = elapsed % totalDuration
				end
			end

			local closestFrame = path[1]
			for _, frame in path do
				if frame.Time <= t then
					closestFrame = frame
				else
					break
				end
			end

			if closestFrame then
				playedPath = true
				local localPos = closestFrame.Position
				local swappedPos = Vector3.new(localPos.Z, localPos.Y, localPos.X)
				local worldPos = npc.SpawnAnchor:PointToWorldSpace(swappedPos)

				if isEvading then
					worldPos = npcPos + (evadeDir * 10)
					
					local jumpChance = (effectiveK :: any).CURSOR_EVASION_JUMP_CHANCE or 0.55
					if rng:NextNumber() < (jumpChance * AI_K.UPDATE_TICK_RATE * 5) then
						npc.IsJumping = true
						npc.Humanoid.Jump = true
					end
					
					if npc.IsCrouching then
						removeCrouch(npc)
					end
					
					npc.Humanoid.WalkSpeed = activeWalkSpeed * 0.85
				else
					if closestFrame.Crouching and not npc.IsCrouching then
						applyCrouch(npc)
					elseif not closestFrame.Crouching and npc.IsCrouching then
						removeCrouch(npc)
					end

					if closestFrame.Jumping and not npc.IsJumping then
						npc.IsJumping = true
						npc.Humanoid.Jump = true
					end
					
					npc.Humanoid.WalkSpeed = activeWalkSpeed
				end

				npc.Humanoid:MoveTo(worldPos)
			end
		end
	end

	if not playedPath then
		if not npc.IsFrozen then
			local orbitRadius = math.clamp(dist - 0.5, AI_K.ORBIT_DISTANCE_MIN, 100)
			local currentAngle = math.atan2(npcPos.X - targetPos.X, npcPos.Z - targetPos.Z)

			local lookAheadAngle: number
			if npc.ActiveModifiers.spin then
				lookAheadAngle = math.rad(35) * npc.StrafeDirection
			elseif npc.ActiveModifiers.strafe then
				lookAheadAngle = math.rad(18) * npc.StrafeDirection
			else
				lookAheadAngle = math.rad(8) * npc.StrafeDirection
			end

			local newAngle = currentAngle + lookAheadAngle
			local targetWorldPos = Vector3.new(targetPos.X + math.sin(newAngle) * orbitRadius, targetPos.Y, targetPos.Z + math.cos(newAngle) * orbitRadius)

			npc.Humanoid:MoveTo(targetWorldPos)
		else
			npc.Humanoid.WalkSpeed = 0
		end
	end

	local jumpMin = (effectiveK :: any).JUMP_INTERVAL_MIN or AI_K.JUMP_INTERVAL_MIN
	local jumpMax = (effectiveK :: any).JUMP_INTERVAL_MAX or AI_K.JUMP_INTERVAL_MAX
	local allowJumpDuringPath = (effectiveK :: any).ALLOW_JUMP_DURING_PATH == true
	local pathJumpChance = (effectiveK :: any).PATH_JUMP_CHANCE or 0.0

	local jumpGatePassed = if (playedPath and allowJumpDuringPath)
		then true
		else not npc.IsJumping

	if jumpGatePassed and now >= npc.NextJumpTime then
		local shouldJump = false

		if npc.IsFrozen then
			shouldJump = false
		elseif playedPath and allowJumpDuringPath then
			shouldJump = rng:NextNumber() < pathJumpChance
		elseif not npc.IsJumping then
			if npc.ActiveModifiers.bunnyhop or npc.ActiveModifiers.randomJump then
				shouldJump = rng:NextNumber() < 0.65
			end
		end

		npc.NextJumpTime = now + rng:NextNumber(jumpMin, jumpMax)

		if shouldJump then
			npc.IsJumping = true
			npc.Humanoid.Jump = true
		end
	end

	if now >= npc.NextShootTime then
		if npc.Model and npc.Model:FindFirstChild("SpawnForceField") then
			npc.NextShootTime = now + 0.15
		else
			npc.NextShootTime = now + AI_K.BR16_FIRE_RATE
			fireAtPlayer(manager, npc, targetRoot)
		end
	end
end

function AimChamberNpcAI.applySynchronizedProtection(playerChar: Model?, npcModel: Model?, duration: number): ()
	if duration <= 0 then
		return
	end

	local models: { Model } = {}
	if playerChar and playerChar.Parent then
		table.insert(models, playerChar)
	end
	if npcModel and npcModel.Parent then
		table.insert(models, npcModel)
	end

	for _, char in models do
		for _, child in char:GetChildren() do
			if child:IsA("ForceField") or child.Name == "SpawnHighlight" then
				child:Destroy()
			end
		end

		local ff = Instance.new("ForceField")
		ff.Name = "SpawnForceField"
		ff.Visible = false
		CollectionService:AddTag(ff, "NPCForceField")
		ff.Parent = char

		local hl = Instance.new("Highlight")
		hl.Name = "SpawnHighlight"
		hl.FillColor = Color3.fromRGB(255, 0, 0)
		hl.OutlineColor = Color3.fromRGB(255, 0, 0)
		hl.FillTransparency = 0.5
		hl.OutlineTransparency = 0
		CollectionService:AddTag(hl, "SpawnHighlight")
		hl.Parent = char
	end

	task.delay(duration, function()
		for _, char in models do
			if char and char.Parent then
				local existingFf = char:FindFirstChild("SpawnForceField")
				if existingFf then
					existingFf:Destroy()
				end
				local existingHl = char:FindFirstChild("SpawnHighlight")
				if existingHl then
					existingHl:Destroy()
				end
			end
		end
	end)
end

function AimChamberNpcAI.applySpawnProtection(character: Model, duration: number): ()
	AimChamberNpcAI.applySynchronizedProtection(character, nil, duration)
end

local function spawnNpc(manager: NpcManager): ()
	if manager.Npc and manager.Npc.IsAlive then
		return
	end

	local model, humanoid, rootPart = createNpcModel()
	if not model or not humanoid or not rootPart then
		return
	end

	local tagged = CollectionService:GetTagged("TrainingBotSpawn")
	local spawnCFrame: CFrame
	if #tagged > 0 and tagged[1]:IsA("BasePart") then
		spawnCFrame = (tagged[1] :: BasePart).CFrame
	else
		local spawnPos = getRandomSpawnPosition(manager.SpawnPoints)
		spawnCFrame = CFrame.new(spawnPos)
	end

	do
		local candidatePos = spawnCFrame.Position
		local rayOrigin = Vector3.new(candidatePos.X, candidatePos.Y + 60, candidatePos.Z)
		local rayDir = Vector3.new(0, -120, 0)
		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = { model }
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		local groundResult = Workspace:Raycast(rayOrigin, rayDir, rayParams)
		if groundResult then
			spawnCFrame = CFrame.new(Vector3.new(candidatePos.X, groundResult.Position.Y + 3.5, candidatePos.Z))
		else
			spawnCFrame = CFrame.new(Vector3.new(candidatePos.X, candidatePos.Y + 5, candidatePos.Z))
		end
	end

	model:PivotTo(spawnCFrame)
	local spawnPos = spawnCFrame.Position
	model.Parent = Workspace
	
	rootPart:SetNetworkOwner(nil)

	if manager.Settings.AiMovementProfile and AimChamberConfig.TIER_AVATAR_CONFIG then
		local config = AimChamberConfig.TIER_AVATAR_CONFIG[manager.Settings.AiMovementProfile]
		if config and config.UserId and config.UserId > 1 then
			local desc = getOrCreateHumanoidDescription(config.UserId, config)
			if desc and humanoid and humanoid.Parent then
				pcall(function()
					humanoid:ApplyDescription(desc)
				end)

				for _, v in model:GetDescendants() do
					if v:IsA("Accessory") then
						local handle = v:FindFirstChild("Handle")
						if handle and handle:IsA("BasePart") then
							handle.CanQuery = false
							handle.CanCollide = false
							handle.Massless = true
							handle.Anchored = false
						end
					elseif v:IsA("BasePart") then
						v.Anchored = false
					end
				end
			end
		end
	end

	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = false
		end
	end

	rootPart:SetNetworkOwner(nil)

	humanoid.JumpPower = AI_K.JUMP_POWER
	humanoid.MaxHealth = manager.Settings.AiHealth or 100
	humanoid.Health = humanoid.MaxHealth

	local effectiveK = getEffectiveConstants(manager)
	local tierSpeedMult = (effectiveK :: any).ORBIT_WALK_SPEED_MULTIPLIER or 1.0
	local activeWalkSpeed = AI_K.ORBIT_WALK_SPEED * tierSpeedMult
	if manager.Difficulty == "HARD" then
		activeWalkSpeed = AI_K.ORBIT_WALK_SPEED * 1.4
	end
	humanoid.WalkSpeed = activeWalkSpeed

	local gunModel, idleTrack = equipGun(model, humanoid)
	if idleTrack then
		idleTrack:Play()
	end

	local now = os.clock()

	local playbackPath = nil
	local selectedProfile = manager.Settings.AiMovementProfile
	local pathLookup = if selectedProfile == "TIER 5" then "TIER 4" else selectedProfile
	if pathLookup and pathLookup ~= "RANDOM" and AimChamberRecordedPaths[pathLookup] then
		playbackPath = AimChamberRecordedPaths[pathLookup]
	else
		local pathNames = {}
		for name, _ in AimChamberRecordedPaths do
			table.insert(pathNames, name)
		end
		if #pathNames > 0 then
			local selectedName = pathNames[rng:NextInteger(1, #pathNames)]
			playbackPath = AimChamberRecordedPaths[selectedName]
		end
	end

	local tierJumpMin = (effectiveK :: any).JUMP_INTERVAL_MIN or AI_K.JUMP_INTERVAL_MIN
	local tierJumpMax = (effectiveK :: any).JUMP_INTERVAL_MAX or AI_K.JUMP_INTERVAL_MAX
	local tierDecisionMin = (effectiveK :: any).DECISION_TICK_MIN or AI_K.DECISION_TICK_MIN
	local tierDecisionMax = (effectiveK :: any).DECISION_TICK_MAX or AI_K.DECISION_TICK_MAX

	local npc: NpcInstance = {
		Model = model,
		Humanoid = humanoid,
		RootPart = rootPart,
		GunModel = gunModel,
		IdleTrack = idleTrack,
		CrouchTrack = nil,
		IsAlive = true,
		StrafeDirection = if rng:NextNumber() < 0.5 then 1 else -1,
		NextDecisionTime = now + rng:NextNumber(tierDecisionMin, tierDecisionMax),
		NextShootTime = now + AI_K.SPAWN_FORCEFIELD_DURATION + rng:NextNumber(0.15, 0.4),
		NextJumpTime = now + rng:NextNumber(tierJumpMin, tierJumpMax),
		NextCrouchEndTime = 0,
		NextFlipTime = now + rng:NextNumber(0.5, 1.5),
		IsJumping = false,
		IsCrouching = false,
		IsFrozen = false,
		FreezeEndTime = 0,
		AimLerpTarget = spawnPos + Vector3.new(0, 1.2, 0),
		OriginalHipHeight = humanoid.HipHeight,
		JumpConnection = nil,
		DiedConnection = nil,
		IdleConnection = nil,
		ActiveModifiers = {
			spin = false,
			bunnyhop = false,
			strafe = false,
			randomJump = false,
			freeze = false,
			crouch = false,
		},
		PlaybackPath = playbackPath,
		PlaybackStartTime = now,
		SpawnAnchor = rootPart.CFrame,
		CursorEvading = false,
		CursorEvasionStartTime = 0,
		CursorEvasionEndTime = 0,
		CursorEvasionCooldownEnd = 0,
		CursorEvasionStartAnchor = nil,
		CursorEvasionTargetAnchor = nil,
		HealthConnection = nil,
	}

	if npc.IdleTrack then
		npc.IdleConnection = npc.IdleTrack.Stopped:Connect(function()
			task.delay(1, function()
				if npc.IsAlive and npc.IdleTrack then
					npc.IdleTrack:Play()
				end
			end)
		end)
	end

	npc.JumpConnection = humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Landed
			or newState == Enum.HumanoidStateType.GettingUp
			or newState == Enum.HumanoidStateType.Running then
			npc.IsJumping = false
		end
	end)

	npc.DiedConnection = humanoid.Died:Connect(function()
		if not npc.IsAlive then
			return
		end
		npc.IsAlive = false
		if manager.OnNpcKilled then
			manager.OnNpcKilled()
		end

		local player = manager.TargetPlayer
		if player and player.Parent then
			local killedByMelee = false
			local char = player.Character
			if char then
				local tool = char:FindFirstChildOfClass("Tool")
				if tool and tool.Name == "Sword" then
					killedByMelee = true
				end
			end

			if not killedByMelee then
				StatsService:AddKill(player, 1)

				local killerHealth = 100
				if char then
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hum then
						killerHealth = math.round(hum.Health)
					end
				end

				local selected = manager.Settings.SelectedGun or "H-82"
				if selected == "H-82 INF" then
					selected = "H-82"
				end
				local gunIndex = GunStats.GUN_NAME_TO_INDEX[selected] or 1

				Network.Gun.broadcastKill({
					killer = player.UserId,
					victim = -1,
					headshot = false,
					weapon = gunIndex,
					killerHealth = killerHealth,
					mutual = false,
				}, player.Name, AI_K.NPC_ASSET_NAME, nil, nil)
			end
		end

		task.delay(AI_K.CORPSE_DURATION, function()
			cleanupNpc(manager, npc)
		end)
	end)

	manager.Npc = npc
end

function AimChamberNpcAI.createManager(settings: AimChamberSettings, difficulty: string, targetPlayer: Player, spawnPoints: { BasePart }): NpcManager
	return {
		Settings = settings,
		Difficulty = difficulty,
		TargetPlayer = targetPlayer,
		Npc = nil,
		UpdateThread = nil,
		SpawnThread = nil,
		SpawnPoints = spawnPoints,
		IsRunning = false,
		OnPlayerDamaged = nil,
		OnNpcKilled = nil,
	}
end

function AimChamberNpcAI.start(manager: NpcManager): ()
	if manager.IsRunning then
		return
	end
	manager.IsRunning = true

	spawnNpc(manager)

	manager.UpdateThread = task.spawn(function()
		while manager.IsRunning do
			updateNpc(manager)
			task.wait(AI_K.UPDATE_TICK_RATE)
		end
	end)
end

function AimChamberNpcAI.stop(manager: NpcManager): ()
	manager.IsRunning = false

	if manager.SpawnThread then
		task.cancel(manager.SpawnThread)
		manager.SpawnThread = nil
	end

	if manager.UpdateThread then
		task.cancel(manager.UpdateThread)
		manager.UpdateThread = nil
	end

	cleanupNpc(manager)
end

function AimChamberNpcAI.freeze(manager: NpcManager): ()
	local npc = manager.Npc
	if npc and npc.IsAlive and npc.Model then
		npc.State = "Idle"
		local char = npc.Model
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.MaxHealth = math.huge
			hum.Health = math.huge
		end
		for _, p in char:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end
	end
end

function AimChamberNpcAI.reset(manager: NpcManager): ()
	cleanupNpc(manager)
	if manager.SpawnThread then
		task.cancel(manager.SpawnThread)
		manager.SpawnThread = nil
	end
	spawnNpc(manager)
end

function AimChamberNpcAI.setMatchManager(manager: any): ()
	AimChamberMatchManagerRef = manager
end

return AimChamberNpcAI
