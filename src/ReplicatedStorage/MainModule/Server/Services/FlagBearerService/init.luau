--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local MainModule = script.Parent.Parent.Parent
local Constants = require(MainModule.Shared.Config.Constants)
local Network = require(MainModule.Shared.Network)
local FlagBearerConfig = require(MainModule.Shared.Config.Champions.FlagBearerConfig)
local PlayerCache = require(MainModule.Shared.Cache.PlayerCache)
local FactionUtils = require(MainModule.Shared.Utils.Game.FactionUtils)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

local AuraHeal = FlagBearerConfig.AuraHeal
local Shield = FlagBearerConfig.Shield

local AURA_PARTICLE_TEXTURE = "rbxassetid://4925956526"
local AURA_PARTICLE_COLOR = ColorSequence.new(Color3.fromRGB(100, 255, 100))
local AURA_PARTICLE_SIZE = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0) })
local AURA_PARTICLE_TRANSPARENCY = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
local AURA_PARTICLE_RATE = 20
local AURA_PARTICLE_LIFETIME = NumberRange.new(1)
local AURA_PARTICLE_SPEED = NumberRange.new(0.5)
local AURA_PARTICLE_SPREAD = 45
local AURA_PARTICLE_ROTATION = NumberRange.new(0, 180)
local AURA_PARTICLE_ROT_SPEED = NumberRange.new(-45, 45)
local FEET_PARTICLE_RATE = 25
local FEET_PARTICLE_LIFETIME = NumberRange.new(0.5, 1)
local FEET_PARTICLE_SPEED = NumberRange.new(0.5, 1.5)
local FEET_PARTICLE_SPREAD = 60
local AURA_LIGHT_COLOR = Color3.fromRGB(100, 255, 100)
local AURA_LIGHT_BRIGHTNESS = 2
local AURA_LIGHT_RANGE = 8

type AbilityState = {
	auraActive: boolean,
	auraEnd: number,
	auraCooldownEnd: number,
	auraTickAccum: number,
	shieldActive: boolean,
	shieldEnd: number,
	shieldCooldownEnd: number,
}

type ShieldData = {
	part: BasePart,
	health: number,
	ownerUserId: number,
}

local FLAG_NAME = "FlagBanner"
local CUSTOM_FLAG_NAME = "FlagBanner_Custom"
local CUSTOM_FLAG_USERS: { [number]: boolean } = {}
local MAX_SHIELD_HIT_DAMAGE = 50

local DEFENDER_TEAMS = Constants.FACTIONS.DEFENDER_TEAMS
local SHIELD_COLOR_DEFENDER = Color3.fromRGB(180, 60, 60)
local SHIELD_COLOR_RAIDER = Color3.fromRGB(80, 140, 220)
local SHIELD_SEQ_DEFENDER = ColorSequence.new(SHIELD_COLOR_DEFENDER)
local SHIELD_SEQ_RAIDER = ColorSequence.new(SHIELD_COLOR_RAIDER)

local MIN_PLAYERS_FOR_STATS = Constants.STATS.MIN_PLAYERS

local FlagBearerService = {}
FlagBearerService.Name = "FlagBearerService"

local playerIsFlagBearer: { [number]: boolean } = {}
local abilityState: { [number]: AbilityState } = {}
local activeShields: { [number]: ShieldData } = {}
local shieldPartToOwner: { [BasePart]: number } = {}
local activeAuraVFX: { [number]: { Instance } } = {}

local serviceConnections: { RBXScriptConnection } = {}
local playerConnections: { [number]: { RBXScriptConnection } } = {}

local heartbeatConnection: RBXScriptConnection? = nil

local modelsService: any = nil
local teamService: any = nil
local statsService: any = nil
local hardpointService: any = nil
local phaseService: any = nil
local dominationService: any = nil

local function shouldCountStats(): boolean
	if hardpointService and hardpointService:IsOfficial() then
		return PlayerCache.getCount() >= MIN_PLAYERS_FOR_STATS
	end
	if phaseService and phaseService:IsOfficial() then
		return PlayerCache.getCount() >= MIN_PLAYERS_FOR_STATS
	end
	if dominationService and dominationService:IsOfficial() then
		return PlayerCache.getCount() >= MIN_PLAYERS_FOR_STATS
	end
	return false
end

local function trackHealStats(healer: Player, healAmount: number): ()
	if not statsService then
		return
	end

	statsService:AddHeal(healer, healAmount)

	if shouldCountStats() then
		statsService:AddHealGlobal(healer, healAmount)
	end
end

local function getFlagTemplate(character: Model): Model?
	if not modelsService or not modelsService:IsLoaded() then
		return nil
	end
	local player = Players:GetPlayerFromCharacter(character)
	if player and CUSTOM_FLAG_USERS[player.UserId] then
		local custom = modelsService:FindModel(CUSTOM_FLAG_NAME)
		if custom then
			return custom
		end
	end
	return modelsService:FindModel(FLAG_NAME)
end

local function attachFlagMotor6D(leftArm: BasePart, handle: BasePart): ()
	local oldAttach = leftArm:FindFirstChild("FlagAttach")
	if oldAttach then
		oldAttach:Destroy()
	end
	local oldMotor = leftArm:FindFirstChild("FlagMotor6D")
	if oldMotor then
		oldMotor:Destroy()
	end
	local oldFlagAttach = handle:FindFirstChild("FlagAttach")
	if oldFlagAttach then
		oldFlagAttach:Destroy()
	end

	local leftArmAttach = Instance.new("Attachment")
	leftArmAttach.Name = "FlagAttach"
	leftArmAttach.Position = Vector3.new(0, -0.5, 0)
	leftArmAttach.Parent = leftArm

	local flagAttach = Instance.new("Attachment")
	flagAttach.Name = "FlagAttach"
	flagAttach.Position = Vector3.zero
	flagAttach.Parent = handle

	local motor = Instance.new("Motor6D")
	motor.Name = "FlagMotor6D"
	motor.Part0 = leftArm
	motor.Part1 = handle
	motor.C1 = flagAttach.CFrame
	motor.Parent = leftArm
end

local function attachFlagToCharacter(character: Model): ()
	local leftArm = character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftUpperArm")
	if not leftArm or not leftArm:IsA("BasePart") then
		return
	end

	local existingFlag = character:FindFirstChild(FLAG_NAME)
	if existingFlag then
		existingFlag:Destroy()
	end

	local flagTemplate = getFlagTemplate(character)
	if not flagTemplate then
		return
	end

	local flag = flagTemplate:Clone()
	flag.Name = FLAG_NAME
	flag.Parent = character

	for _, part in flag:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
		end
	end

	local handle = flag.PrimaryPart
	if not handle then
		flag:Destroy()
		return
	end

	attachFlagMotor6D(leftArm :: BasePart, handle)
end

local function getDefaultAbilityState(): AbilityState
	return {
		auraActive = false,
		auraEnd = 0,
		auraCooldownEnd = 0,
		auraTickAccum = 0,
		shieldActive = false,
		shieldEnd = 0,
		shieldCooldownEnd = 0,
	}
end

local function buildAbilityStatus(state: AbilityState): Network.FlagBearerAbilityStatus
	local now = os.clock()
	return {
		AuraHealReady = not state.auraActive and now >= state.auraCooldownEnd,
		AuraHealActive = state.auraActive,
		AuraHealCooldown = math.max(0, state.auraCooldownEnd - now),
		ShieldReady = not state.shieldActive and now >= state.shieldCooldownEnd,
		ShieldActive = state.shieldActive,
		ShieldCooldown = math.max(0, state.shieldCooldownEnd - now),
	}
end

local function destroyShield(userId: number): ()
	local shield = activeShields[userId]
	if not shield then
		return
	end

	shieldPartToOwner[shield.part] = nil
	shield.part:Destroy()
	activeShields[userId] = nil

	Network.FlagBearer.broadcastShieldDestroy(userId)
end

local cachedFlagEffectsTemplate: Attachment? = nil
local cachedBeingHealedTemplate: Attachment? = nil
local auraVFXSearched = false

local FEET_OFFSET = Vector3.new(0, -2.9, 0)

local function loadAuraVFXTemplates(): ()
	if auraVFXSearched then
		return
	end
	auraVFXSearched = true

	local vfx: Instance? = if modelsService then modelsService:Find("MedicAuraVFX") else nil
	if not vfx then
		vfx = ServerStorage:FindFirstChild("MedicAuraVFX", true)
	end
	if not vfx then
		return
	end

	local part = vfx:FindFirstChild("Part")
	if not part then
		return
	end

	cachedFlagEffectsTemplate = part:FindFirstChild("FlagEffects") :: Attachment?
	cachedBeingHealedTemplate = part:FindFirstChild("BeingHealed") :: Attachment?
end

local function ensureVFXTemplatesLoaded(): ()
	if auraVFXSearched then
		return
	end
	if modelsService and not modelsService:IsLoaded() then
		local attempts = 0
		while not modelsService:IsLoaded() and attempts < 30 do
			task.wait(0.1)
			attempts += 1
		end
	end
	loadAuraVFXTemplates()
end

local activeBeingHealedAttachments: { [number]: Attachment } = {}
local healedUserIdSet: { [number]: boolean } = {}
local pendingDestroyHealAttach: { [number]: Attachment } = {}
local pendingDestroyAuraInstances: { [number]: { Instance } } = {}

local function destroyHealAttach(targetUserId: number): ()
	local attach = pendingDestroyHealAttach[targetUserId]
	pendingDestroyHealAttach[targetUserId] = nil
	if attach and attach.Parent then
		attach:Destroy()
	end
end

local function destroyAuraInstances(userId: number): ()
	local instances = pendingDestroyAuraInstances[userId]
	pendingDestroyAuraInstances[userId] = nil
	if not instances then
		return
	end
	for _, inst in instances do
		if inst and inst.Parent then
			inst:Destroy()
		end
	end
end

local function enableGameplayParticles(instance: Instance): ()
	instance:SetAttribute("IgnoreWorldParticles", true)
	for _, desc in instance:GetDescendants() do
		if desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") then
			desc:SetAttribute("IgnoreWorldParticles", true)
			desc.Enabled = true
		end
	end
end

local function applyBeingHealedVFX(targetUserId: number, targetRootPart: BasePart): ()
	local existing = activeBeingHealedAttachments[targetUserId]
	if existing and existing.Parent == targetRootPart then
		return
	end
	if existing then
		for _, desc in existing:GetDescendants() do
			if desc:IsA("ParticleEmitter") then
				desc.Enabled = false
			end
		end
		activeBeingHealedAttachments[targetUserId] = nil
		pendingDestroyHealAttach[targetUserId] = existing
		task.delay(1, destroyHealAttach, targetUserId)
	end

	loadAuraVFXTemplates()
	local template = cachedBeingHealedTemplate
	local attach = if template then template:Clone() else Instance.new("Attachment")
	attach.Name = "BeingHealed"
	if template then
		enableGameplayParticles(attach)
	else
		local particle = Instance.new("ParticleEmitter")
		particle.Name = "BeingHealedFallback"
		particle:SetAttribute("IgnoreWorldParticles", true)
		particle.Texture = AURA_PARTICLE_TEXTURE
		particle.Color = AURA_PARTICLE_COLOR
		particle.Size = AURA_PARTICLE_SIZE
		particle.Transparency = AURA_PARTICLE_TRANSPARENCY
		particle.Rate = AURA_PARTICLE_RATE
		particle.Lifetime = AURA_PARTICLE_LIFETIME
		particle.Speed = AURA_PARTICLE_SPEED
		particle.SpreadAngle = Vector2.new(AURA_PARTICLE_SPREAD, AURA_PARTICLE_SPREAD)
		particle.Rotation = AURA_PARTICLE_ROTATION
		particle.RotSpeed = AURA_PARTICLE_ROT_SPEED
		particle.Enabled = true
		particle.Parent = attach
	end
	attach:SetAttribute("IgnoreWorldParticles", true)
	attach.Parent = targetRootPart
	activeBeingHealedAttachments[targetUserId] = attach
end

local function removeBeingHealedVFX(targetUserId: number): ()
	local attach = activeBeingHealedAttachments[targetUserId]
	if attach then
		for _, desc in attach:GetDescendants() do
			if desc:IsA("ParticleEmitter") then
				desc.Enabled = false
			end
		end
		activeBeingHealedAttachments[targetUserId] = nil
		pendingDestroyHealAttach[targetUserId] = attach
		task.delay(1, destroyHealAttach, targetUserId)
	end
end

local function createAuraVFX(player: Player): ()
	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	ensureVFXTemplatesLoaded()

	local clonedInstances: { Instance } = {}

	local flagEffectsTemplate = cachedFlagEffectsTemplate

	local feetPart = Instance.new("Part")
	feetPart.Name = "AuraFeetPart"
	feetPart:SetAttribute("IgnoreWorldParticles", true)
	feetPart.Size = Vector3.new(4, 1, 2)
	feetPart.Transparency = 1
	feetPart.Anchored = false
	feetPart.CanCollide = false
	feetPart.CanTouch = false
	feetPart.CanQuery = false
	feetPart.CastShadow = false
	feetPart.Massless = true
	feetPart.CFrame = rootPart.CFrame * CFrame.new(FEET_OFFSET)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = feetPart
	weld.Parent = feetPart

	if flagEffectsTemplate then
		local flagEffects = flagEffectsTemplate:Clone()
		flagEffects.Position = Vector3.zero
		enableGameplayParticles(flagEffects)
		flagEffects.Parent = feetPart
	end

	local feetParticle = Instance.new("ParticleEmitter")
	feetParticle.Name = "FeetMagic"
	feetParticle:SetAttribute("IgnoreWorldParticles", true)
	feetParticle.Texture = AURA_PARTICLE_TEXTURE
	feetParticle.Color = AURA_PARTICLE_COLOR
	feetParticle.Size = AURA_PARTICLE_SIZE
	feetParticle.Transparency = AURA_PARTICLE_TRANSPARENCY
	feetParticle.Rate = FEET_PARTICLE_RATE
	feetParticle.Lifetime = FEET_PARTICLE_LIFETIME
	feetParticle.Speed = FEET_PARTICLE_SPEED
	feetParticle.SpreadAngle = Vector2.new(FEET_PARTICLE_SPREAD, FEET_PARTICLE_SPREAD)
	feetParticle.Rotation = AURA_PARTICLE_ROTATION
	feetParticle.RotSpeed = AURA_PARTICLE_ROT_SPEED
	feetParticle.Enabled = true
	feetParticle.Parent = feetPart

	feetPart.Parent = character
	enableGameplayParticles(feetPart)
	table.insert(clonedInstances, feetPart)

	local particle = Instance.new("ParticleEmitter")
	particle.Name = "AuraEffect"
	particle:SetAttribute("IgnoreWorldParticles", true)
	particle.Texture = AURA_PARTICLE_TEXTURE
	particle.Color = AURA_PARTICLE_COLOR
	particle.Size = AURA_PARTICLE_SIZE
	particle.Transparency = AURA_PARTICLE_TRANSPARENCY
	particle.Rate = AURA_PARTICLE_RATE
	particle.Lifetime = AURA_PARTICLE_LIFETIME
	particle.Speed = AURA_PARTICLE_SPEED
	particle.SpreadAngle = Vector2.new(AURA_PARTICLE_SPREAD, AURA_PARTICLE_SPREAD)
	particle.Rotation = AURA_PARTICLE_ROTATION
	particle.RotSpeed = AURA_PARTICLE_ROT_SPEED
	particle.VelocityInheritance = 1
	particle.Enabled = true
	particle.Parent = rootPart
	table.insert(clonedInstances, particle)

	local light = Instance.new("PointLight")
	light.Name = "AuraGlow"
	light.Color = AURA_LIGHT_COLOR
	light.Brightness = AURA_LIGHT_BRIGHTNESS
	light.Range = AURA_LIGHT_RANGE
	light.Parent = rootPart
	table.insert(clonedInstances, light)

	activeAuraVFX[player.UserId] = clonedInstances
end

local function destroyAuraVFX(userId: number): ()
	local instances = activeAuraVFX[userId]
	if not instances then
		return
	end

	for _, inst in instances do
		if inst:IsA("ParticleEmitter") then
			inst.Enabled = false
		else
			for _, desc in inst:GetDescendants() do
				if desc:IsA("ParticleEmitter") then
					desc.Enabled = false
				end
			end
		end
	end

	activeAuraVFX[userId] = nil
	pendingDestroyAuraInstances[userId] = instances
	task.delay(1, destroyAuraInstances, userId)
end

local function isAnyOtherAuraActive(excludeUserId: number): boolean
	for uid, st in abilityState do
		if uid ~= excludeUserId and st.auraActive then
			return true
		end
	end
	return false
end

local function deactivateAura(userId: number): ()
	local state = abilityState[userId]
	if not state or not state.auraActive then
		return
	end

	state.auraActive = false
	state.auraCooldownEnd = os.clock() + AuraHeal.Cooldown
	state.auraTickAccum = 0
	destroyAuraVFX(userId)

	if not isAnyOtherAuraActive(userId) then
		for targetUserId in activeBeingHealedAttachments do
			removeBeingHealedVFX(targetUserId)
		end
	end
end

local function deactivateShield(userId: number): ()
	local state = abilityState[userId]
	if not state or not state.shieldActive then
		return
	end

	state.shieldActive = false
	state.shieldCooldownEnd = os.clock() + Shield.Cooldown
	destroyShield(userId)
end

local function deactivateAllAbilities(userId: number): ()
	deactivateAura(userId)
	deactivateShield(userId)
end

local teammatesBuffer: { Player } = {}
local healedUserIds: { number } = {}

local TEAMMATE_CACHE_TTL = 0.25
type TeammateCache = {
	teammates: { Player },
	time: number,
}
local teammateCaches: { [Player]: TeammateCache } = {}

local function areSameFaction(player1: Player, player2: Player): boolean
	if teamService then
		return teamService:AreAllies(player1, player2)
	end
	return FactionUtils.areSameFaction(player1, player2)
end

local function getTeammates(player: Player): { Player }
	local now = os.clock()
	local cached = teammateCaches[player]
	if cached and now - cached.time < TEAMMATE_CACHE_TTL then
		return cached.teammates
	end

	table.clear(teammatesBuffer)

	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		if areSameFaction(player, other) then
			table.insert(teammatesBuffer, other)
		end
	end

	local teammates: { Player } = table.create(#teammatesBuffer)
	table.move(teammatesBuffer, 1, #teammatesBuffer, 1, teammates)
	teammateCaches[player] = { teammates = teammates, time = now }

	return teammates
end

local function tryHealTeammate(healer: Player, teammate: Player, origin: Vector3): (boolean, boolean)
	local tChar = teammate.Character
	if not tChar then
		return false, false
	end
	local tRoot = tChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not tRoot then
		return false, false
	end
	local delta = tRoot.Position - origin
	if delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z > AuraHeal.RadiusSquared then
		return false, false
	end
	local humanoid = tChar:FindFirstChildOfClass("Humanoid")
	if not humanoid or not humanoid.Parent then
		return false, false
	end
	local hp, maxHP = humanoid.Health, humanoid.MaxHealth
	if hp <= 0 then
		return false, false
	end

	local inRange = true
	local didHeal = false

	if hp < maxHP then
		humanoid.Health = math.min(maxHP, hp + AuraHeal.HealPerTick)
		local actualHeal = humanoid.Health - hp
		if actualHeal > 0 then
			trackHealStats(healer, actualHeal)
			didHeal = true
		end
	end

	if inRange then
		applyBeingHealedVFX(teammate.UserId, tRoot)
	end

	return inRange, didHeal
end

local function removeUnhealedVFX(): ()
	for targetUserId in activeBeingHealedAttachments do
		if not healedUserIdSet[targetUserId] then
			removeBeingHealedVFX(targetUserId)
		end
	end
end

local function healNearbyTeammates(player: Player, _userId: number): ()
	debug.profilebegin("FlagBearerService::healNearbyTeammates")
	local character = player.Character
	if not character then
		debug.profileend()
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		debug.profileend()
		return
	end

	table.clear(healedUserIds)

	local selfHumanoid = character:FindFirstChildOfClass("Humanoid")
	if selfHumanoid and selfHumanoid.Parent then
		local hp, maxHP = selfHumanoid.Health, selfHumanoid.MaxHealth
		if hp > 0 then
			table.insert(healedUserIds, player.UserId)
			healedUserIdSet[player.UserId] = true
			if hp < maxHP then
				selfHumanoid.Health = math.min(maxHP, hp + AuraHeal.HealPerTick)
				local actualHeal = selfHumanoid.Health - hp
				if actualHeal > 0 then
					trackHealStats(player, actualHeal)
				end
			end
		end
	end

	local origin = rootPart.Position
	for _, teammate in getTeammates(player) do
		local inRange, _didHeal = tryHealTeammate(player, teammate, origin)
		if inRange then
			table.insert(healedUserIds, teammate.UserId)
			healedUserIdSet[teammate.UserId] = true
		end
	end

	if #healedUserIds > 0 then
		Network.FlagBearer.broadcastHealVFX(healedUserIds)
	end
	debug.profileend()
end

local function getShieldTemplate(): BasePart?
	if not modelsService or not modelsService:IsLoaded() then
		return nil
	end
	local shield = modelsService:Find("Shield")
	if shield and shield:IsA("BasePart") then
		return shield :: BasePart
	end
	return nil
end

local function buildShieldPart(shieldTemplate: BasePart?, spawnPosition: Vector3, shieldColor: Color3, beamSequence: ColorSequence): BasePart
	local shieldPart: BasePart
	if shieldTemplate then
		shieldPart = shieldTemplate:Clone()
	else
		shieldPart = Instance.new("Part");
		(shieldPart :: Part).Shape = Enum.PartType.Ball
		shieldPart.Size = Vector3.new(Shield.Radius * 2, Shield.Radius * 2, Shield.Radius * 2)
		shieldPart.Material = Enum.Material.ForceField
	end

	shieldPart.Color = shieldColor
	shieldPart.Name = "FlagBearerShield"
	shieldPart.Transparency = 0.5
	shieldPart.Anchored = true
	shieldPart.CanCollide = false
	shieldPart.CanTouch = false
	shieldPart.CanQuery = true
	shieldPart.CastShadow = false
	shieldPart.CFrame = CFrame.new(spawnPosition)

	for _, desc in shieldPart:GetDescendants() do
		if desc:IsA("Beam") or desc:IsA("ParticleEmitter") then
			(desc :: any).Color = beamSequence
		elseif desc:IsA("BasePart") then
			desc.CanQuery = false
		end
	end

	return shieldPart
end

local function spawnShield(player: Player, userId: number): ()
	local character = player.Character
	if not character then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local teamName = player.Team and player.Team.Name or ""
	local isDefender = DEFENDER_TEAMS[teamName] == true
	local shieldColor = if isDefender then SHIELD_COLOR_DEFENDER else SHIELD_COLOR_RAIDER
	local beamSequence = if isDefender then SHIELD_SEQ_DEFENDER else SHIELD_SEQ_RAIDER

	local template = getShieldTemplate()
	local halfHeight: number = if template then template.Size.Y / 2 else Shield.Radius

	local groundRayParams = RaycastParams.new()
	groundRayParams.FilterType = Enum.RaycastFilterType.Exclude
	groundRayParams.FilterDescendantsInstances = { character }
	local groundRay = workspace:Raycast(rootPart.Position, Vector3.new(0, -50, 0), groundRayParams)
	local groundY = if groundRay then groundRay.Position.Y else (rootPart.Position.Y - 3)
	local spawnPosition = Vector3.new(rootPart.Position.X, groundY + halfHeight, rootPart.Position.Z)

	local shieldPart = buildShieldPart(template, spawnPosition, shieldColor, beamSequence)
	shieldPart:SetAttribute("OwnerUserId", userId)
	shieldPart:SetAttribute("MaxHealth", Shield.Health)
	shieldPart:SetAttribute("CurrentHealth", Shield.Health)
	shieldPart.Parent = workspace

	local shieldData: ShieldData = {
		part = shieldPart,
		health = Shield.Health,
		ownerUserId = userId,
	}
	activeShields[userId] = shieldData
	shieldPartToOwner[shieldPart] = userId
end

local function activateAuraHeal(player: Player, userId: number): ()
	local state = abilityState[userId]
	if not state then
		return
	end

	if state.auraActive then
		return
	end

	local now = os.clock()
	if now < state.auraCooldownEnd then
		return
	end

	state.auraActive = true
	state.auraEnd = now + AuraHeal.Duration
	state.auraTickAccum = 0
	createAuraVFX(player)
end

local function activateEnergyShield(player: Player, userId: number): ()
	local state = abilityState[userId]
	if not state then
		return
	end

	if state.shieldActive then
		return
	end

	local now = os.clock()
	if now < state.shieldCooldownEnd then
		return
	end

	state.shieldActive = true
	state.shieldEnd = now + Shield.Duration
	spawnShield(player, userId)
end

local function validateFlagBearer(player: Player): boolean
	if not playerIsFlagBearer[player.UserId] then
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	return true
end

local function onActivateAbility(player: Player, abilityName: string): ()
	if not validateFlagBearer(player) then
		return
	end

	local userId = player.UserId

	if abilityName == "AuraHeal" then
		activateAuraHeal(player, userId)
	elseif abilityName == "EnergyShield" then
		activateEnergyShield(player, userId)
	end

	local state = abilityState[userId]
	if state then
		Network.FlagBearer.sendAbilityStatus(player, buildAbilityStatus(state))
	end
end

local ensureHeartbeatRunning: () -> ()
local stopHeartbeatIfEmpty: () -> ()

local function onHeartbeat(dt: number): ()
	debug.profilebegin("FlagBearerService::heartbeat")
	local now = os.clock()

	table.clear(healedUserIdSet)
	local anyAuraHealed = false

	for userId, state in abilityState do
		local cached = PlayerCache.getByUserId(userId)
		local player = cached and cached.player
		if not player then
			continue
		end

		local changed = false

		if state.auraActive then
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local shouldDeactivate = not hum or hum.Health <= 0 or now >= state.auraEnd
			if shouldDeactivate then
				deactivateAura(userId)
				changed = true
			else
				state.auraTickAccum += dt
				while state.auraTickAccum >= AuraHeal.TickInterval do
					state.auraTickAccum -= AuraHeal.TickInterval
					healNearbyTeammates(player, userId)
					anyAuraHealed = true
				end
			end
		elseif state.auraCooldownEnd > 0 and now >= state.auraCooldownEnd then
			state.auraCooldownEnd = 0
			changed = true
		end

		if state.shieldActive then
			if now >= state.shieldEnd then
				deactivateShield(userId)
				changed = true
			end
		elseif state.shieldCooldownEnd > 0 and now >= state.shieldCooldownEnd then
			state.shieldCooldownEnd = 0
			changed = true
		end

		if changed then
			Network.FlagBearer.sendAbilityStatus(player, buildAbilityStatus(state))
		end
	end

	if anyAuraHealed then
		removeUnhealedVFX()
	end

	stopHeartbeatIfEmpty()
	debug.profileend()
end

ensureHeartbeatRunning = function(): ()
	if heartbeatConnection then
		return
	end
	heartbeatConnection = RunService.Heartbeat:Connect(onHeartbeat)
end

stopHeartbeatIfEmpty = function(): ()
	if not heartbeatConnection then
		return
	end
	if next(abilityState) == nil then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

local function onPlayerRemoving(player: Player): ()
	local userId = player.UserId
	local conns = playerConnections[userId]

	if conns then
		for _, conn in conns do
			conn:Disconnect()
		end
		playerConnections[userId] = nil
	end

	deactivateAllAbilities(userId)
	playerIsFlagBearer[userId] = nil
	abilityState[userId] = nil
	teammateCaches[player] = nil
end

local function onCharacterAdded(player: Player, character: Model): ()
	local userId = player.UserId
	if not playerIsFlagBearer[userId] then
		return
	end

	task.defer(function()
		if not character.Parent or not playerIsFlagBearer[userId] then
			return
		end

		attachFlagToCharacter(character)
		Network.FlagBearer.sendState(player, true)
	end)
end

local function onCharacterRemoving(player: Player): ()
	local userId = player.UserId
	if not playerIsFlagBearer[userId] then
		return
	end

	deactivateAllAbilities(userId)

	local state = abilityState[userId]
	if state then
		Network.FlagBearer.sendAbilityStatus(player, buildAbilityStatus(state))
	end
end

function FlagBearerService:init(): () end

local function connectPlayerCharacterEvents(player: Player): ()
	local userId = player.UserId
	local conns: { RBXScriptConnection } = {}
	playerConnections[userId] = conns

	table.insert(
		conns,
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	)

	table.insert(
		conns,
		player.CharacterRemoving:Connect(function()
			onCharacterRemoving(player)
		end)
	)
end

local function onShieldHit(player: Player, ownerUserId: number, damage: number): ()
	if not player or not player.Parent then
		return
	end

	local shield = activeShields[ownerUserId]
	if not shield then
		return
	end

	local ownerCached = PlayerCache.getByUserId(ownerUserId)
	if not ownerCached or not ownerCached.player then
		return
	end

	if areSameFaction(player, ownerCached.player) then
		return
	end

	local clampedDamage = math.clamp(damage, 0, MAX_SHIELD_HIT_DAMAGE)
	if clampedDamage <= 0 then
		return
	end

	FlagBearerService:DamageShield(shield.part, clampedDamage)
end

function FlagBearerService:start(): ()
	modelsService = LazyService.create(MainModule, "ModelsService")()
	teamService = LazyService.create(MainModule, "TeamService")()
	statsService = LazyService.create(MainModule, "StatsService")()
	hardpointService = LazyService.create(MainModule, "HardpointService")()
	phaseService = LazyService.create(MainModule, "PhaseService")()
	dominationService = LazyService.create(MainModule, "DominationService")()

	task.spawn(ensureVFXTemplatesLoaded)

	table.insert(serviceConnections, Network.FlagBearer.onActivateAbility(onActivateAbility))
	table.insert(serviceConnections, Network.FlagBearer.onShieldHit(onShieldHit))
	table.insert(serviceConnections, Players.PlayerRemoving:Connect(onPlayerRemoving))

	for _, player in Players:GetPlayers() do
		connectPlayerCharacterEvents(player)
	end

	table.insert(
		serviceConnections,
		Players.PlayerAdded:Connect(function(player)
			connectPlayerCharacterEvents(player)
		end)
	)
end

function FlagBearerService:SetPlayerFlagBearer(player: Player, enabled: boolean): ()
	local userId = player.UserId

	if not enabled and playerIsFlagBearer[userId] then
		deactivateAllAbilities(userId)
		playerIsFlagBearer[userId] = nil
		abilityState[userId] = nil
		Network.FlagBearer.sendState(player, false)

		local character = player.Character
		if character then
			local existingFlag = character:FindFirstChild(FLAG_NAME)
			if existingFlag then
				existingFlag:Destroy()
			end
		end
		return
	end

	if enabled then
		playerIsFlagBearer[userId] = true
		abilityState[userId] = getDefaultAbilityState()
		ensureHeartbeatRunning()
		Network.FlagBearer.sendState(player, true)
		Network.FlagBearer.sendAbilityStatus(player, buildAbilityStatus(abilityState[userId]))

		local character = player.Character
		if character then
			attachFlagToCharacter(character)
		end
	end
end

function FlagBearerService:IsPlayerFlagBearer(player: Player): boolean
	return playerIsFlagBearer[player.UserId] == true
end

function FlagBearerService:DamageShield(shieldPart: BasePart, damage: number): boolean
	local userId = shieldPartToOwner[shieldPart]
	if not userId then
		return false
	end

	local shield = activeShields[userId]
	if not shield then
		return false
	end

	shield.health = math.max(0, shield.health - damage)
	if shield.health > 0 then
		shield.part:SetAttribute("CurrentHealth", shield.health)
	end
	if shield.health <= 0 then
		deactivateShield(userId)

		local state = abilityState[userId]
		if state then
			local cached = PlayerCache.getByUserId(userId)
			if cached and cached.player then
				Network.FlagBearer.sendAbilityStatus(cached.player, buildAbilityStatus(state))
			end
		end
	end

	return true
end

function FlagBearerService:IsShieldPart(part: BasePart): boolean
	return shieldPartToOwner[part] ~= nil
end

function FlagBearerService:GetShieldOwnerUserId(part: BasePart): number?
	return shieldPartToOwner[part]
end

function FlagBearerService:Cleanup(): ()
	for _, conn in serviceConnections do
		conn:Disconnect()
	end
	table.clear(serviceConnections)

	for _, conns in playerConnections do
		for _, conn in conns do
			conn:Disconnect()
		end
	end
	table.clear(playerConnections)

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	for userId in activeShields do
		destroyShield(userId)
	end

	for userId in activeAuraVFX do
		destroyAuraVFX(userId)
	end

	table.clear(playerIsFlagBearer)
	table.clear(abilityState)
	table.clear(activeShields)
	table.clear(shieldPartToOwner)
	table.clear(activeAuraVFX)

	for targetUserId in activeBeingHealedAttachments do
		removeBeingHealedVFX(targetUserId)
	end
	table.clear(activeBeingHealedAttachments)

	table.clear(teammateCaches)
	table.clear(pendingDestroyHealAttach)
	table.clear(pendingDestroyAuraInstances)
end

return FlagBearerService
