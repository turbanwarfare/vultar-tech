--!strict
--!native
--!optimize 2

local Workspace = workspace

local MainModule = script.Parent.Parent.Parent.Parent
local AimChamberConfig = require(MainModule.Shared.Config.AimChamberConfig)
local Network = require(MainModule.Shared.Network)
local StatsService = require(MainModule.Server.Services.StatsService)
local GunStats = require(MainModule.Shared.Config.GunStats)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

type AimChamberSettings = AimChamberConfig.AimChamberSettings

local AI_CONSTANTS = AimChamberConfig.ZOMBIE_AI
local XZ_MASK = Vector3.new(1, 0, 1)

export type ZombieInstance = {
	Model: Model,
	Humanoid: Humanoid,
	RootPart: BasePart,
	SpawnTime: number,
	IsCrouching: boolean,
	CrouchEndTime: number,
	IsAlive: boolean,
	DamageCooldown: number,
	TouchConnection: RBXScriptConnection?,
	JumpConnection: RBXScriptConnection?,
	DiedConnection: RBXScriptConnection?,
	CrouchTrack: AnimationTrack?,
	Phase: "Approach" | "ApproachJuke" | "Orbit" | "Juke" | "Commit",
	NextDecisionTime: number,
	NextFlipTime: number,
	IsJumping: boolean,
	LastJumpTime: number,
	JumpChainCount: number,
	OriginalHipHeight: number,
	StrafeDirection: number,
	OrbitStartTime: number?,
}

export type ZombieManager = {
	Settings: AimChamberSettings,
	TargetPlayer: Player,
	Zombies: { ZombieInstance },
	SpawnThread: thread?,
	UpdateThread: thread?,
	SpawnPoints: { BasePart },
	IsRunning: boolean,
	OnPlayerDamaged: ((damage: number) -> ())?,
	OnZombieKilled: (() -> ())?,
}

local AimChamberZombieAI = {}

local rng = Random.new()

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function createZombieModel(): (Model?, Humanoid?, BasePart?)
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then
		return nil, nil, nil
	end
	local zombieTemplate = assetsFolder:FindFirstChild("Zombie")
	if not zombieTemplate or not zombieTemplate:IsA("Model") then
		return nil, nil, nil
	end

	local model = zombieTemplate:Clone()
	model.Name = "AimChamberZombie"

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?

	if humanoid and rootPart then
		model.PrimaryPart = rootPart
		humanoid.WalkSpeed = 0
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 0
		humanoid.AutoRotate = true

		for _, desc in model:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.CastShadow = false
			end
		end

		return model, humanoid, rootPart
	end

	return nil, nil, nil
end

local function getRandomSpawnPosition(spawnPoints: { BasePart }): Vector3
	if #spawnPoints > 0 then
		local spawnPart = spawnPoints[rng:NextInteger(1, #spawnPoints)]
		local offset = Vector3.new(
			rng:NextNumber(-AI_CONSTANTS.SPAWN_JITTER, AI_CONSTANTS.SPAWN_JITTER),
			0,
			rng:NextNumber(-AI_CONSTANTS.SPAWN_JITTER, AI_CONSTANTS.SPAWN_JITTER)
		)
		return spawnPart.Position + offset
	end
	return Vector3.new(
		rng:NextNumber(-AI_CONSTANTS.SPAWN_OFFSET_RADIUS, AI_CONSTANTS.SPAWN_OFFSET_RADIUS),
		AI_CONSTANTS.SPAWN_HEIGHT,
		rng:NextNumber(-AI_CONSTANTS.SPAWN_OFFSET_RADIUS, AI_CONSTANTS.SPAWN_OFFSET_RADIUS)
	)
end

local function triggerJump(zombie: ZombieInstance): ()
	if zombie.IsJumping then
		return
	end
	zombie.IsJumping = true
	zombie.Humanoid.Jump = true
end

local function applyCrouch(zombie: ZombieInstance): ()
	if zombie.IsCrouching or not zombie.IsAlive then
		return
	end

	zombie.IsCrouching = true
	zombie.CrouchEndTime = os.clock() + AI_CONSTANTS.CROUCH_DURATION

	local humanoid = zombie.Humanoid
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	if not zombie.CrouchTrack then
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://101785625813335"
		zombie.CrouchTrack = animator:LoadAnimation(anim)
	end

	if zombie.CrouchTrack then
		zombie.CrouchTrack:Play()
	end

	humanoid.HipHeight = zombie.OriginalHipHeight - 1
end

local function removeCrouch(zombie: ZombieInstance): ()
	if not zombie.IsCrouching then
		return
	end

	zombie.IsCrouching = false

	if zombie.CrouchTrack then
		zombie.CrouchTrack:Stop()
	end

	zombie.Humanoid.HipHeight = zombie.OriginalHipHeight
end

local function cleanupZombie(manager: ZombieManager, zombie: ZombieInstance): ()
	zombie.IsAlive = false

	if zombie.TouchConnection then
		zombie.TouchConnection:Disconnect()
		zombie.TouchConnection = nil
	end

	if zombie.JumpConnection then
		zombie.JumpConnection:Disconnect()
		zombie.JumpConnection = nil
	end

	if zombie.DiedConnection then
		zombie.DiedConnection:Disconnect()
		zombie.DiedConnection = nil
	end

	if zombie.IsCrouching then
		zombie.IsCrouching = false
	end

	if zombie.CrouchTrack then
		zombie.CrouchTrack:Stop()
		zombie.CrouchTrack:Destroy()
		zombie.CrouchTrack = nil
	end

	if zombie.Model and zombie.Model.Parent then
		zombie.Model:Destroy()
	end

	local idx = table.find(manager.Zombies, zombie)
	if idx then
		table.remove(manager.Zombies, idx)
	end
end

function AimChamberZombieAI.createManager(settings: AimChamberSettings, targetPlayer: Player, spawnPoints: { BasePart }): ZombieManager
	return {
		Settings = settings,
		TargetPlayer = targetPlayer,
		Zombies = {},
		SpawnThread = nil,
		UpdateThread = nil,
		SpawnPoints = spawnPoints,
		IsRunning = false,
		OnPlayerDamaged = nil,
		OnZombieKilled = nil,
	}
end

local function spawnZombie(manager: ZombieManager): ()
	local settings = manager.Settings

	local aliveCount = 0
	for _, z in manager.Zombies do
		if z.IsAlive then
			aliveCount += 1
		end
	end

	if settings.MaxZombiesEnabled and not settings.AssessmentValidation and aliveCount >= settings.MaxZombies then
		return
	end

	local model, humanoid, rootPart = createZombieModel()
	if not model or not humanoid or not rootPart then
		return
	end

	local spawnPos = getRandomSpawnPosition(manager.SpawnPoints)
	model:PivotTo(CFrame.new(spawnPos))
	model.Parent = Workspace

	rootPart:SetNetworkOwner(nil)

	humanoid.JumpPower = settings.ZombieJumpPower

	local now = os.clock()
	local initialStagger = rng:NextNumber(-settings.DecisionTimeStaggerMax, settings.DecisionTimeStaggerMax)

	local zombie: ZombieInstance = {
		Model = model,
		Humanoid = humanoid,
		RootPart = rootPart,
		SpawnTime = now + rng:NextNumber(-1, 1),
		IsCrouching = false,
		CrouchEndTime = 0,
		IsAlive = true,
		DamageCooldown = 0,
		TouchConnection = nil,
		JumpConnection = nil,
		CrouchTrack = nil,
		Phase = "Approach",
		NextDecisionTime = now + rng:NextNumber(settings.StrafeHoldMin, settings.StrafeHoldMax) + initialStagger,
		NextFlipTime = now + rng:NextNumber(settings.StrafeFlipIntervalMin, settings.StrafeFlipIntervalMax),
		IsJumping = false,
		LastJumpTime = now,
		JumpChainCount = 0,
		OriginalHipHeight = humanoid.HipHeight,
		StrafeDirection = if rng:NextNumber() < settings.OrbitDirectionBias then 1 else -1,
		OrbitStartTime = nil,
		DiedConnection = nil,
	}

	zombie.DiedConnection = humanoid.Died:Connect(function()
		if not zombie.IsAlive then
			return
		end
		zombie.IsAlive = false
		if manager.OnZombieKilled then
			manager.OnZombieKilled()
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
				}, player.Name, "Zombie", nil, nil)
			end
		end

		task.delay(AI_CONSTANTS.CORPSE_DURATION, function()
			cleanupZombie(manager, zombie)
		end)
	end)

	zombie.JumpConnection = humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Landed then
			zombie.IsJumping = false

			local dist = 9999
			local targetRoot = getCharacterRoot(manager.TargetPlayer)
			if targetRoot and zombie.RootPart then
				dist = (targetRoot.Position - zombie.RootPart.Position).Magnitude
			end

			if dist > settings.MinEngageDistance and settings.BunnyHopEnabled and zombie.JumpChainCount < settings.BunnyHopMaxChain then
				if rng:NextNumber() < settings.BunnyHopChainChance then
					zombie.JumpChainCount += 1
					zombie.LastJumpTime = os.clock()
					triggerJump(zombie)
				else
					zombie.JumpChainCount = 0
				end
			else
				zombie.JumpChainCount = 0
			end
		end
	end)

	local player = manager.TargetPlayer
	zombie.TouchConnection = rootPart.Touched:Connect(function(hit: BasePart)
		if not zombie.IsAlive then
			return
		end
		local nowTime = os.clock()
		if nowTime < zombie.DamageCooldown then
			return
		end

		local character = player.Character
		if not character then
			return
		end

		local hitModel = hit:FindFirstAncestorOfClass("Model")
		if hitModel ~= character then
			return
		end

		zombie.DamageCooldown = nowTime + AI_CONSTANTS.DAMAGE_COOLDOWN

		if settings.ZombieDamageEnabled then
			if manager.OnPlayerDamaged then
				manager.OnPlayerDamaged(settings.ZombieDamageAmount)
			end
			zombie.OrbitStartTime = nil
			zombie.Phase = "Approach"
		else
			cleanupZombie(manager, zombie)
		end
	end)

	table.insert(manager.Zombies, zombie)
end

local function updateZombies(manager: ZombieManager): ()
	local settings = manager.Settings
	local targetRoot = getCharacterRoot(manager.TargetPlayer)
	if not targetRoot then
		return
	end

	local now = os.clock()
	local targetPos = targetRoot.Position

	local positions = {}
	for i, z in manager.Zombies do
		if z.IsAlive and z.RootPart and z.RootPart.Parent then
			positions[i] = z.RootPart.Position
		end
	end

	for i, zombie in manager.Zombies do
		if not zombie.IsAlive then
			continue
		end

		local currentPos = positions[i]
		if not currentPos then
			zombie.IsAlive = false
			continue
		end

		local toPlayer = targetPos - currentPos
		local distance = toPlayer.Magnitude
		local horizontalToPlayer = toPlayer * XZ_MASK
		local dirToPlayer = if horizontalToPlayer.Magnitude > 0.1 then horizontalToPlayer.Unit else Vector3.new(1, 0, 0)

		if distance <= settings.MinEngageDistance or zombie.Phase == "Commit" then
			if zombie.IsCrouching then
				removeCrouch(zombie)
			end
		else
			if zombie.IsCrouching and now >= zombie.CrouchEndTime then
				removeCrouch(zombie)
			end
		end

		local needsDecision = false

		if distance <= settings.MinEngageDistance then
			zombie.Phase = "Commit"
		else
			if zombie.Phase == "Commit" then
				if distance > settings.MaxEngageDistance then
					zombie.Phase = "Approach"
					zombie.NextDecisionTime = 0
				end
			elseif zombie.Phase == "Approach" or zombie.Phase == "ApproachJuke" then
				if distance > settings.MinEngageDistance then
					if now >= zombie.NextDecisionTime then
						needsDecision = true
					end
				end
			elseif zombie.Phase == "Orbit" or zombie.Phase == "Juke" then
				if distance <= settings.MaxEngageDistance or (zombie.OrbitStartTime and (now - zombie.OrbitStartTime) >= settings.MaxOrbitDuration) then
					zombie.Phase = "Approach"
					zombie.OrbitStartTime = nil
					zombie.NextDecisionTime = 0
				elseif now >= zombie.NextDecisionTime then
					needsDecision = true
				end
			end
		end

		if needsDecision and zombie.Phase ~= "Commit" and distance > settings.MinEngageDistance then
			local baseDuration = rng:NextNumber(settings.StrafeHoldMin, settings.StrafeHoldMax)
			local jitter = baseDuration * rng:NextNumber(-settings.MovementJitter, settings.MovementJitter)
			zombie.NextDecisionTime = now + math.max(0.1, baseDuration + jitter)

			if rng:NextNumber() < settings.ApproachCrouchChance then
				applyCrouch(zombie)
			end

			if distance > settings.MaxEngageDistance then
				local r = rng:NextNumber()
				if r < settings.JukeChance then
					zombie.Phase = "Juke"
					zombie.StrafeDirection = -zombie.StrafeDirection
					if not zombie.IsJumping and rng:NextNumber() < settings.JukeJumpChance then
						zombie.LastJumpTime = now
						triggerJump(zombie)
					end
				elseif r < settings.JukeChance + AI_CONSTANTS.ORBIT_CHANCE then
					zombie.Phase = "Orbit"
					zombie.OrbitStartTime = now
					zombie.StrafeDirection = if rng:NextNumber() < settings.OrbitDirectionBias then 1 else -1
				else
					zombie.Phase = "Approach"
					zombie.StrafeDirection = if rng:NextNumber() < settings.OrbitDirectionBias then 1 else -1
				end
			else
				if rng:NextNumber() < settings.ApproachJukeChance then
					zombie.Phase = "ApproachJuke"
					zombie.StrafeDirection = -zombie.StrafeDirection
					if not zombie.IsJumping and rng:NextNumber() < settings.JukeJumpChance then
						zombie.LastJumpTime = now
						triggerJump(zombie)
					end
				else
					zombie.Phase = "Approach"
					zombie.StrafeDirection = if rng:NextNumber() < settings.OrbitDirectionBias then 1 else -1
				end
			end
		end

		if zombie.Phase ~= "Commit" and now >= zombie.NextFlipTime then
			zombie.StrafeDirection = -zombie.StrafeDirection
			zombie.NextFlipTime = now + rng:NextNumber(settings.StrafeFlipIntervalMin, settings.StrafeFlipIntervalMax)
		end

		if not zombie.IsJumping and now - zombie.LastJumpTime >= settings.JumpCooldown then
			local jumpChance: number
			if distance <= settings.MinEngageDistance then
				jumpChance = settings.CloseRangeJumpChance
			elseif zombie.Phase == "Orbit" or zombie.Phase == "Juke" then
				jumpChance = settings.OrbitJumpChance
			else
				jumpChance = settings.ApproachJumpChance
			end
			zombie.LastJumpTime = now
			if rng:NextNumber() < jumpChance then
				triggerJump(zombie)
			end
		end

		local baseSpeed: number
		if zombie.Phase == "Approach" then
			baseSpeed = settings.ZombieSpeed * settings.ApproachSpeedMultiplier
		elseif zombie.Phase == "ApproachJuke" then
			baseSpeed = settings.ZombieSpeed * settings.ApproachSpeedMultiplier * settings.JukeSpeedMultiplier
		elseif zombie.Phase == "Orbit" then
			baseSpeed = settings.ZombieSpeed * settings.StrafeSpeedMultiplier
		elseif zombie.Phase == "Juke" then
			baseSpeed = settings.ZombieSpeed * settings.JukeSpeedMultiplier
		else
			baseSpeed = settings.ZombieSpeed * settings.CommitSpeedMultiplier
		end

		if zombie.JumpChainCount > 0 then
			baseSpeed = baseSpeed * settings.BunnyHopSpeedMultiplier
		end

		local targetWorldPos: Vector3

		if zombie.Phase == "Commit" then
			targetWorldPos = targetPos
		elseif zombie.Phase == "Approach" or zombie.Phase == "ApproachJuke" then
			local angleDeg = if zombie.Phase == "ApproachJuke" then AI_CONSTANTS.APPROACH_JUKE_ANGLE else settings.StrafeApproachAngle
			local angleRad = math.rad(angleDeg) * zombie.StrafeDirection
			local cosA = math.cos(angleRad)
			local sinA = math.sin(angleRad)
			local strafedDir = Vector3.new(dirToPlayer.X * cosA - dirToPlayer.Z * sinA, 0, dirToPlayer.X * sinA + dirToPlayer.Z * cosA)
			targetWorldPos = currentPos + strafedDir * math.max(distance, AI_CONSTANTS.TARGET_RANGE)
		else
			local orbitRadius = math.clamp(distance, settings.MinEngageDistance + 1, settings.MaxEngageDistance - 1)
			local currentAngle = math.atan2(currentPos.X - targetPos.X, currentPos.Z - targetPos.Z)
			local lookAheadAngle = math.rad(AI_CONSTANTS.ORBIT_LOOK_AHEAD_ANGLE) * zombie.StrafeDirection
			local newAngle = currentAngle + lookAheadAngle
			targetWorldPos = Vector3.new(targetPos.X + math.sin(newAngle) * orbitRadius, targetPos.Y, targetPos.Z + math.cos(newAngle) * orbitRadius)
		end

		local tangent = Vector3.new(-dirToPlayer.Z, 0, dirToPlayer.X)

		for j, other in manager.Zombies do
			if other ~= zombie and other.IsAlive then
				local otherPos = positions[j]
				if otherPos then
					local diff = (currentPos - otherPos) * XZ_MASK
					local dist = diff.Magnitude
					if dist < AI_CONSTANTS.SEPARATION_RADIUS and dist > 0.1 then
						local lateralPush = tangent * diff:Dot(tangent)
						local force = (AI_CONSTANTS.SEPARATION_RADIUS - dist) / AI_CONSTANTS.SEPARATION_RADIUS
						local maxSep = if zombie.Phase == "Commit" then AI_CONSTANTS.COMMIT_SEPARATION_FORCE else settings.SeparationMaxForce
						local pushAmount = math.min(lateralPush.Magnitude * force, maxSep)
						if lateralPush.Magnitude ^ 2 > 0.0001 then
							targetWorldPos = targetWorldPos + lateralPush.Unit * pushAmount
						end
					end
				end
			end
		end

		zombie.Humanoid.WalkSpeed = baseSpeed
		zombie.Humanoid:MoveTo(targetWorldPos)
	end
end

function AimChamberZombieAI.start(manager: ZombieManager): ()
	if manager.IsRunning then
		return
	end
	manager.IsRunning = true

	local matchStartTime = os.clock()

	manager.SpawnThread = task.spawn(function()
		while manager.IsRunning do
			spawnZombie(manager)

			local settings = manager.Settings
			local currentRate: number
			if settings.SpawnRateRampEnabled then
				local elapsed = os.clock() - matchStartTime
				local t = math.clamp(elapsed / math.max(settings.SpawnRateRampDuration, 0.1), 0, 1)
				local startRate = math.max(settings.SpawnRateRampStartRate, 0.1)
				local endRate = math.max(settings.ZombieSpawnRate, 0.1)
				currentRate = startRate + (endRate - startRate) * t
			else
				currentRate = math.max(settings.ZombieSpawnRate, 0.1)
			end

			task.wait(1 / currentRate)
		end
	end)

	manager.UpdateThread = task.spawn(function()
		while manager.IsRunning do
			updateZombies(manager)
			task.wait(AI_CONSTANTS.UPDATE_TICK_RATE)
		end
	end)
end

function AimChamberZombieAI.stop(manager: ZombieManager): ()
	manager.IsRunning = false

	if manager.SpawnThread then
		task.cancel(manager.SpawnThread)
		manager.SpawnThread = nil
	end

	if manager.UpdateThread then
		task.cancel(manager.UpdateThread)
		manager.UpdateThread = nil
	end

	local copy = table.clone(manager.Zombies)
	for _, zombie in copy do
		cleanupZombie(manager, zombie)
	end
	table.clear(manager.Zombies)
end

return AimChamberZombieAI
