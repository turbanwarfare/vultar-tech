--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent
local Constants = require(MainModule.Shared.Config.Constants)
local GunStats = require(MainModule.Shared.Config.GunStats)
local GunHUD = require(MainModule.Client.Components.GunHUD)
local Network = require(MainModule.Shared.Network)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local BlurEffect = require(MainModule.Client.Utils.UI.BlurEffect)
local ReconWeaponBalanceConfig = require(MainModule.Shared.Config.Weapons.ReconWeaponBalanceConfig)

local FireCore = require(script.FireCore)
local NetworkDispatcher = require(script.NetworkDispatcher)
local Feedback = require(script.Feedback)
local VFXRenderer = require(script.VFXRenderer)
local MedigunHandler = require(script.MedigunHandler)
local OOCIndicator = require(script.OOCIndicator)
local ReloadController = require(script.ReloadController)
local AmmoManager = require(script.AmmoManager)
local Cache = require(script.Cache)
local SoundReplicator = require(script.SoundReplicator)
local AnimatedSkinEngine = require(script.AnimatedSkinEngine)

local GunService = {}
GunService.Name = "GunService"

local player = Players.LocalPlayer

local equippedTool: Tool? = nil
local gunStats: GunStats.GunProperties? = nil
local gunFireTimes: { [string]: number } = {}
local isFiring: boolean = false
local currentAmmo: number = 0
local maxAmmo: number = 0
local currentGunIndex: number = 1

local rng = Random.new()

local inputConnections: { RBXScriptConnection } = {}
local characterConnection: RBXScriptConnection? = nil
local toolConnections: { RBXScriptConnection } = {}
local firingThread: thread? = nil
local firingGeneration: number = 0
local barrelRetryThread: thread? = nil

local isInitialized = false

local fireSound: Sound? = nil

local isMedigunMode = false
local lastHealTargetId: number? = nil
local fireBlocked: boolean = false

local LOW_CHARGE_THRESHOLD = 5
local LOW_CHARGE_SEND_INTERVAL = OOCIndicator.DISPLAY_DURATION + OOCIndicator.COOLDOWN
local lastLowChargeSendTime = 0

local cachedBarrel: Attachment? = nil
local cachedBarrelParent: BasePart? = nil
local cachedHandle: BasePart? = nil

local chargeProgress: number = 0
local isCharging: boolean = false
local chargeConnection: RBXScriptConnection? = nil

local remoteBarrelCache: { [number]: { barrel: Attachment, handle: BasePart } } = {}

local localHumanoid: Humanoid? = nil
local localHead: BasePart? = nil

local MAX_PELLETS = 12
type PelletHit = { targetId: number, damage: number, head: boolean, pos: Vector3, bodyPart: number }
local pelletHits: { PelletHit } = table.create(MAX_PELLETS)
local pelletHitPool: { PelletHit } = table.create(MAX_PELLETS)
for i = 1, MAX_PELLETS do
	pelletHitPool[i] = { targetId = 0, damage = 0, head = false, pos = Vector3.zero, bodyPart = 0 }
end

local FRAME_TIME_SAMPLE_COUNT = 60
local frameTimeSum: number = 0.0166 * FRAME_TIME_SAMPLE_COUNT
local frameTimeIndex: number = 1
local frameTimeSamples: { number } = table.create(FRAME_TIME_SAMPLE_COUNT, 0.0166)

RunService.Heartbeat:Connect(function(dt: number)
	frameTimeSum -= frameTimeSamples[frameTimeIndex]
	frameTimeSamples[frameTimeIndex] = dt
	frameTimeSum += dt
	frameTimeIndex = (frameTimeIndex % FRAME_TIME_SAMPLE_COUNT) + 1
end)

local function getClientFrameTimeMs(): number
	local avgSec = frameTimeSum / FRAME_TIME_SAMPLE_COUNT
	return math.clamp(math.round(avgSec * 10000) / 10, 0.1, 1000)
end

local function findRemoteBarrelInfo(shooterId: number): (Vector3?, BasePart?)
	if not shooterId or shooterId == 0 then
		return nil, nil
	end

	local cached = remoteBarrelCache[shooterId]
	if cached then
		if cached.barrel.Parent and cached.handle.Parent then
			return cached.barrel.WorldPosition, cached.handle
		end
		remoteBarrelCache[shooterId] = nil
	end

	local shooter = Players:GetPlayerByUserId(shooterId)
	if not shooter or not shooter.Character then
		return nil, nil
	end

	local tool = shooter.Character:FindFirstChildOfClass("Tool")
	if not tool then
		return nil, nil
	end

	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return nil, nil
	end

	local barrel = handle:FindFirstChild("Barrel") :: Attachment?
	if not barrel then
		return nil, nil
	end

	remoteBarrelCache[shooterId] = { barrel = barrel, handle = handle }
	return barrel.WorldPosition, handle
end

local stopFiring: () -> ()

local BARREL_MAX_RETRIES = 5
local PELLET_TIGHT_RANGE = 15
local PELLET_TIGHT_MIN = 0.15
local ST_SPREAD_MAX_MULTIPLIER = 10
local ST_FULL_SPREAD_RANGE = 35
local barrelRetryCount = 0

local function cacheBarrelInfo(): ()
	cachedBarrel = nil
	cachedBarrelParent = nil
	cachedHandle = nil

	if not equippedTool then
		return
	end

	local tool = equippedTool

	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if handle then
		local barrel = handle:FindFirstChild("Barrel") :: Attachment?
		if barrel then
			cachedBarrel = barrel
			cachedBarrelParent = handle
			barrelRetryCount = 0
			return
		end
	end

	if barrelRetryCount < BARREL_MAX_RETRIES then
		barrelRetryCount += 1
		if barrelRetryThread then
			task.cancel(barrelRetryThread)
		end
		barrelRetryThread = task.delay(0.1, function()
			barrelRetryThread = nil
			if equippedTool == tool then
				cacheBarrelInfo()
			end
		end)
	end

	if handle then
		cachedHandle = handle
	end
end

local function findShieldOwner(instance: Instance): number?
	local ownerUserId = instance:GetAttribute("OwnerUserId")
	if ownerUserId then
		return ownerUserId
	end
	local parent = instance.Parent
	if parent then
		return parent:GetAttribute("OwnerUserId")
	end
	return nil
end

local DEFENDER_TEAMS = Constants.FACTIONS.DEFENDER_TEAMS

local function canDamageShield(ownerUserId: number): boolean
	if not player then
		return false
	end

	if ownerUserId == player.UserId then
		return false
	end

	local ownerPlayer = Players:GetPlayerByUserId(ownerUserId)
	if not ownerPlayer then
		return true
	end

	local localTeam = player.Team
	local ownerTeam = ownerPlayer.Team
	if not localTeam or not ownerTeam then
		return true
	end

	local localIsDefender = DEFENDER_TEAMS[localTeam.Name] == true
	local ownerIsDefender = DEFENDER_TEAMS[ownerTeam.Name] == true
	return localIsDefender ~= ownerIsDefender
end

local function getBarrelInfo(): (Vector3?, BasePart?)
	if cachedBarrel and cachedBarrelParent then
		if cachedBarrel.Parent and cachedBarrelParent.Parent then
			return cachedBarrel.WorldPosition, cachedBarrelParent
		end
		cachedBarrel = nil
		cachedBarrelParent = nil
	end

	if equippedTool then
		cacheBarrelInfo()
	end

	if cachedBarrel and cachedBarrelParent then
		return cachedBarrel.WorldPosition, cachedBarrelParent
	end

	return nil, nil
end

local function isToolAttached(): boolean
	local weapon = ServiceLocator.Weapon()
	if weapon then
		return weapon:IsToolProperlyAttached()
	end
	return true
end

local function tryEnsureToolAttached(): boolean
	local weapon = ServiceLocator.Weapon()
	if weapon then
		return weapon:EnsureToolAttached()
	end
	return true
end

local function updateHUDAmmo(ammo: number): ()
	currentAmmo = ammo
	GunHUD.setAmmo(ammo, maxAmmo)
end

local function updateCharge(dt: number): ()
	if not gunStats or not gunStats.Chargeable then
		return
	end
	debug.profilebegin("GunService::chargeUpdate")
	local chargeTime = gunStats.ChargeTime or 6
	chargeProgress = math.min(1, chargeProgress + dt / chargeTime)
	GunHUD.setCharge(chargeProgress)
	debug.profileend()
end

local function startCharging(): ()
	if isCharging then
		return
	end
	isCharging = true
	if not chargeConnection then
		chargeConnection = RunService.RenderStepped:Connect(updateCharge)
	end
end

local function stopCharging(): ()
	if not isCharging then
		return
	end
	isCharging = false
	if chargeConnection then
		chargeConnection:Disconnect()
		chargeConnection = nil
	end
end

local function resetCharge(): ()
	stopCharging()
	chargeProgress = 0
	GunHUD.setCharge(0)
end

local function maybeSendLowCharge(): ()
	local now = os.clock()
	if now - lastLowChargeSendTime < LOW_CHARGE_SEND_INTERVAL then
		return
	end
	lastLowChargeSendTime = now
	Network.Gun.sendLowCharge()
end

local function medigunFire(): ()
	if not equippedTool or not gunStats then
		return
	end
	if currentAmmo <= 0 then
		maybeSendLowCharge()
		return
	end

	if not isToolAttached() then
		if not tryEnsureToolAttached() then
			return
		end
	end

	local character = player.Character
	if not character then
		return
	end
	local humanoid = localHumanoid
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()
	local gunName = equippedTool.Name
	local lastFire = gunFireTimes[gunName] or 0
	if now - lastFire < gunStats.FireRate then
		return
	end
	
	if now - lastFire > gunStats.FireRate * 1.5 then
		gunFireTimes[gunName] = now
	else
		gunFireTimes[gunName] = lastFire + gunStats.FireRate
	end

	if currentAmmo <= LOW_CHARGE_THRESHOLD then
		maybeSendLowCharge()
	end

	local head = localHead
	if not head or not head.Parent then
		return
	end

	local _, barrel = getBarrelInfo()
	if not barrel then
		barrel = cachedHandle or head
	end

	debug.profilebegin("GunService::medigunFire")

	local healAmount = gunStats.HealAmount or 3

	local healResult = MedigunHandler.tryHeal(head.Position, gunStats.Range, healAmount, barrel)

	if healResult then
		if MedigunHandler.isRecharging() then
			MedigunHandler.stopAutoRecharge()
		end

		updateHUDAmmo(currentAmmo - 1)

		if healResult.targetId ~= lastHealTargetId then
			Network.Gun.sendMediBeamStart(healResult.targetId)
			lastHealTargetId = healResult.targetId
		end

		NetworkDispatcher.queueHeal(healResult.targetId, healResult.healAmount, healResult.pos)
		Feedback.showHeal(healResult)
	else
		if lastHealTargetId then
			Network.Gun.sendMediBeamStop()
			lastHealTargetId = nil
		end

		if gunStats and currentAmmo < maxAmmo and not MedigunHandler.isRecharging() then
			MedigunHandler.startAutoRecharge(function()
				return currentAmmo
			end, function()
				return maxAmmo
			end, updateHUDAmmo, gunStats.RechargePerSecond or 1)
		end
	end

	debug.profileend()

	if currentAmmo <= 0 then
		stopFiring()
	end
end

local function computeSTSpread(baseSpread: number, aimDist: number, perfectRange: number): number
	if aimDist <= perfectRange then
		return 0
	end
	local maxSpread = baseSpread * ST_SPREAD_MAX_MULTIPLIER
	if aimDist >= ST_FULL_SPREAD_RANGE then
		return maxSpread
	end
	local t = (aimDist - perfectRange) / (ST_FULL_SPREAD_RANGE - perfectRange)
	return maxSpread * t
end

local function fire(): ()
	if not equippedTool or not gunStats then
		return
	end
	if not gunStats.BaseDamage then
		return
	end
	if not (gunStats.InfiniteAmmo or player:GetAttribute("AimChamberInfiniteAmmo") == true) and currentAmmo <= 0 then
		return
	end
	if not (gunStats.InfiniteAmmo or player:GetAttribute("AimChamberInfiniteAmmo") == true) and ReloadController.isReloading() then
		return
	end

	local weapon = ServiceLocator.Weapon()
	if weapon and weapon:IsSprinting() then
		return
	end

	if weapon then
		if not weapon:IsToolProperlyAttached() then
			if not weapon:EnsureToolAttached() then
				return
			end
		end
	end

	local character = player.Character
	if not character then
		return
	end
	local humanoid = localHumanoid
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()
	local gunName = equippedTool.Name
	local lastFire = gunFireTimes[gunName] or 0
	if now - lastFire < gunStats.FireRate then
		return
	end
	
	if now - lastFire > gunStats.FireRate * 1.5 then
		gunFireTimes[gunName] = now
	else
		gunFireTimes[gunName] = lastFire + gunStats.FireRate
	end

	debug.profilebegin("GunService::fire")

	if not FireCore.prepareAim() then
		debug.profileend()
		return
	end

	if not (gunStats.InfiniteAmmo or player:GetAttribute("AimChamberInfiniteAmmo") == true) then
		updateHUDAmmo(currentAmmo - 1)
	end
	if weapon then
		weapon:PlayFireAnimation()
	end
	if fireSound and Cache.getWeaponSoundsEnabled() then
		fireSound:Play()
	end

	local chargeMultiplier = 1
	if gunStats.Chargeable and chargeProgress > 0 then
		chargeMultiplier = 1 + chargeProgress * ((gunStats.MaxChargeMultiplier or 1.75) - 1)
	end
	local effectiveBase = math.floor(gunStats.BaseDamage * chargeMultiplier)
	local effectiveHead = math.floor((gunStats.HeadDamage or gunStats.BaseDamage) * chargeMultiplier)

	local pelletCount = if gunStats.Pellets and gunStats.Pellets > 1 then gunStats.Pellets else 1

	if pelletCount > 1 then
		local barrelPos, barrelPart = getBarrelInfo()
		local hitCount = 0
		local spreadAmount = gunStats.Spread or 0.12

		local aimDist = FireCore.getAimDistance()
		local perfectRange = gunStats.SpreadPerfectRange
		if perfectRange then
			spreadAmount = computeSTSpread(spreadAmount, aimDist, perfectRange)
		elseif aimDist < PELLET_TIGHT_RANGE then
			spreadAmount *= PELLET_TIGHT_MIN + (1 - PELLET_TIGHT_MIN) * (aimDist / PELLET_TIGHT_RANGE)
		end

		local angleStep = math.pi * 2 / pelletCount
		local baseAngle = rng:NextNumber() * math.pi * 2

		for i = 1, pelletCount do
			local angle = baseAngle + (i - 1) * angleStep
			local radius = spreadAmount * (0.75 + rng:NextNumber() * 0.25)
			local spreadRight = math.cos(angle) * radius
			local spreadUp = math.sin(angle) * radius
			local hitData, origin, endPos, rawResult, hitCharPart = FireCore.castPellet(gunStats.Range, spreadRight, spreadUp, effectiveBase, effectiveHead)
			local pelletBarrel = barrelPos or origin

			if not hitData and not hitCharPart then
				local barrelHitData, newEndPos = FireCore.checkBarrelHit(pelletBarrel, endPos, effectiveBase, effectiveHead)
				if barrelHitData then
					hitData = barrelHitData
					endPos = newEndPos
				elseif rawResult then
					local shieldOwnerUserId = findShieldOwner(rawResult.Instance)
					if shieldOwnerUserId and canDamageShield(shieldOwnerUserId) then
						Network.FlagBearer.fireShieldHit(shieldOwnerUserId, effectiveBase)
						Feedback.showShieldHit(effectiveBase, rawResult.Instance, gunStats.Name or equippedTool and equippedTool.Name)
						local fbService = ServiceLocator.get("FlagBearerService")
						if fbService and fbService.OnShieldHit then
							fbService:OnShieldHit(shieldOwnerUserId)
						end
					end
				end
			end

			VFXRenderer.renderRay(pelletBarrel, endPos, barrelPart)

			if hitData then
				hitData.gunName = gunStats.Name or equippedTool and equippedTool.Name
				Feedback.showHit(hitData)
				hitCount += 1
				local h = pelletHitPool[hitCount]
				h.targetId = hitData.targetUserId
				h.damage = hitData.damage
				h.head = hitData.head
				h.pos = if hitData.targetUserId == 0 then hitData.pos else hitData.localOffset
				h.bodyPart = hitData.bodyPartIndex
				pelletHits[hitCount] = h
			end

			NetworkDispatcher.stagePelletReplicate(pelletBarrel, endPos, currentGunIndex, now)
		end

		if hitCount > 0 then
			Network.Gun.sendHits(currentGunIndex, pelletHits, hitCount, getClientFrameTimeMs())
		end
		NetworkDispatcher.flushPelletReplicates()
	else
		local hitData, origin, endPos, rawResult, hitCharPart = FireCore.cast(gunStats.Range, gunStats.Spread, effectiveBase, effectiveHead)

		local barrelPos, barrelPart = getBarrelInfo()
		barrelPos = barrelPos or origin

		if not hitData and not hitCharPart then
			local barrelHitData, newEndPos = FireCore.checkBarrelHit(barrelPos, endPos, effectiveBase, effectiveHead)
			if barrelHitData then
				hitData = barrelHitData
				endPos = newEndPos
			elseif rawResult then
				local shieldOwnerUserId = findShieldOwner(rawResult.Instance)
				if shieldOwnerUserId and canDamageShield(shieldOwnerUserId) then
					Network.FlagBearer.fireShieldHit(shieldOwnerUserId, effectiveBase)
					Feedback.showShieldHit(effectiveBase, rawResult.Instance, gunStats.Name or equippedTool and equippedTool.Name)
					local fbService = ServiceLocator.get("FlagBearerService")
					if fbService and fbService.OnShieldHit then
						fbService:OnShieldHit(shieldOwnerUserId)
					end
				end
			end
		end

		VFXRenderer.renderRay(barrelPos, endPos, barrelPart, nil, gunStats.Name or equippedTool and equippedTool.Name)

		if hitData then
			NetworkDispatcher.stageHit(hitData, currentGunIndex, getClientFrameTimeMs())
			hitData.gunName = gunStats.Name or equippedTool and equippedTool.Name
			Feedback.showHit(hitData)
		end

		NetworkDispatcher.queueReplicate(barrelPos, endPos, currentGunIndex, now)
	end

	if gunStats.Chargeable then
		local firedCharge = chargeProgress
		local weaponName = if equippedTool then equippedTool.Name else ""
		local pairedPistol = ReconWeaponBalanceConfig.ReconPairings[weaponName]
		if pairedPistol then
			local invService = ServiceLocator.get("InventoryService")
			if invService then
				local pistolSlot = invService:GetSlotForTool(pairedPistol)
				local clamped = math.clamp(firedCharge, 0, 1)
				if pistolSlot and clamped >= ReconWeaponBalanceConfig.MinLockoutCharge and clamped <= ReconWeaponBalanceConfig.MaxLockoutCharge then
					local lockoutDuration = ReconWeaponBalanceConfig.BaseBoltCycleTime
						+ (1 - clamped) * ReconWeaponBalanceConfig.MaxSwitchLockoutPenalty
					invService:SetSlotLockout(pistolSlot, lockoutDuration)
				end
			end
		end
		resetCharge()
		if weapon then
			weapon:SetZooming(false)
		end
	end

	debug.profileend()

	if not (gunStats.InfiniteAmmo or player:GetAttribute("AimChamberInfiniteAmmo") == true) and currentAmmo <= 0 then
		stopFiring()
		task.defer(function()
			if equippedTool and gunStats and not isMedigunMode then
				ReloadController.start(currentAmmo, maxAmmo, gunStats.RechargePerSecond or 15, {
					onAmmoChanged = updateHUDAmmo,
					onReloadComplete = function() end,
					stopFiring = stopFiring,
				})
			end
		end)
	end
end

local function startFiring(): ()
	if isFiring then
		return
	end
	if fireBlocked then
		return
	end
	if not gunStats or (not (gunStats.InfiniteAmmo or player:GetAttribute("AimChamberInfiniteAmmo") == true) and ReloadController.isReloading()) then
		return
	end

	if not (gunStats.InfiniteAmmo or player:GetAttribute("AimChamberInfiniteAmmo") == true) and currentAmmo <= 0 then
		if equippedTool and gunStats and not isMedigunMode then
			ReloadController.start(currentAmmo, maxAmmo, gunStats.RechargePerSecond or 15, {
				onAmmoChanged = updateHUDAmmo,
				onReloadComplete = function() end,
				stopFiring = stopFiring,
			})
		elseif equippedTool and isMedigunMode then
			maybeSendLowCharge()
		end
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local humanoid = localHumanoid
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	isFiring = true
	firingGeneration += 1
	local myGeneration = firingGeneration

	local weapon = ServiceLocator.Weapon()
	if weapon then
		weapon:StartFiring()
	end

	local isSemiAuto = gunStats.Mode == "Semi"

	if isSemiAuto then
		if isMedigunMode then
			medigunFire()
		else
			fire()
		end
		stopFiring()
		return
	end

	firingThread = task.spawn(function()
		local ok, err = pcall(function()
			while isFiring and myGeneration == firingGeneration and equippedTool and gunStats and not fireBlocked do
				if isMedigunMode then
					medigunFire()
				else
					fire()
				end

				local nextFireTime = (gunFireTimes[equippedTool.Name] or os.clock()) + gunStats.FireRate
				local waitTime = nextFireTime - os.clock()
				if waitTime > 0 then
					task.wait(waitTime)
				else
					task.wait()
				end
			end
		end)
		if not ok then
			warn("[GunService] Fire loop error: " .. tostring(err))
		end
		if myGeneration == firingGeneration and isFiring then
			isFiring = false
			local wep = ServiceLocator.Weapon()
			if wep then
				wep:StopFiring()
			end
		end
	end)
end

stopFiring = function()
	if not isFiring then
		return
	end
	isFiring = false

	if firingThread then
		pcall(task.cancel, firingThread)
		firingThread = nil
	end

	local weapon = ServiceLocator.Weapon()
	if weapon then
		weapon:StopFiring()
	end

	if isMedigunMode then
		MedigunHandler.stopBeam()
		if lastHealTargetId then
			Network.Gun.sendMediBeamStop()
			lastHealTargetId = nil
		end

		if gunStats and currentAmmo < maxAmmo and not MedigunHandler.isRecharging() then
			MedigunHandler.startAutoRecharge(function()
				return currentAmmo
			end, function()
				return maxAmmo
			end, updateHUDAmmo, gunStats.RechargePerSecond or 1)
		end
	end
end

local function reload(): ()
	if not equippedTool or not gunStats then
		return
	end
	if gunStats.InfiniteAmmo or player:GetAttribute("AimChamberInfiniteAmmo") == true then
		return
	end
	if isMedigunMode then
		return
	end

	ReloadController.start(currentAmmo, maxAmmo, gunStats.RechargePerSecond or 15, {
		onAmmoChanged = updateHUDAmmo,
		onReloadComplete = function() end,
		stopFiring = stopFiring,
	})
end

local function onInputBegan(input: InputObject, gameProcessed: boolean): ()
	if gameProcessed then
		return
	end
	if not equippedTool then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		startFiring()
	elseif input.KeyCode == Enum.KeyCode.R then
		reload()
	end
end

local function onInputEnded(input: InputObject, _gameProcessed: boolean): ()
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		stopFiring()
	end
end

local function onToolEquipped(tool: Tool): ()
	local stats = GunStats.get(tool.Name)
	if not stats then
		return
	end

	ReloadController.reset()

	if AmmoManager.isBackgroundRecharging(tool.Name) then
		AmmoManager.cancelBackgroundRecharge(tool.Name)
	end

	equippedTool = tool
	gunStats = stats

	maxAmmo = stats.MaxAmmo
	currentAmmo = AmmoManager.getStoredAmmo(tool.Name, stats.MaxAmmo)

	isMedigunMode = stats.Mode == "Medi"
	lastHealTargetId = nil

	currentGunIndex = AmmoManager.getGunIndex(tool.Name)

	cacheBarrelInfo()

	table.insert(
		toolConnections,
		tool.ChildAdded:Connect(function(child)
			if child.Name == "GunModel" and child:IsA("Model") then
				if equippedTool == tool then
					cacheBarrelInfo()
				end
			end
		end)
	)

	local handle = tool:FindFirstChild("Handle")
	if handle then
		local existingSound = handle:FindFirstChild("Fire") :: Sound?
		if existingSound and existingSound:IsA("Sound") then
			fireSound = existingSound
		end
	end

	if stats.Sounds and stats.Sounds.Fire then
		local fireSoundStr = tostring(stats.Sounds.Fire)
		local correctSoundId = if string.find(fireSoundStr, "://") then fireSoundStr else "rbxassetid://" .. fireSoundStr
		if not fireSound then
			fireSound = Instance.new("Sound")
			fireSound.Name = "Fire"
			fireSound.Volume = 0.5
			fireSound.RollOffMode = Enum.RollOffMode.InverseTapered
			fireSound.RollOffMinDistance = 10
			fireSound.RollOffMaxDistance = 300
			fireSound.Parent = cachedHandle or tool
		end
		fireSound.SoundId = correctSoundId
	end

	resetCharge()

	GunHUD.setVisible(true)
	GunHUD.setGunName(tool.Name)
	GunHUD.setAmmo(currentAmmo, maxAmmo)
	GunHUD.setChargeVisible(stats.Chargeable == true)

	if isMedigunMode and currentAmmo < maxAmmo then
		MedigunHandler.startAutoRecharge(function()
			return currentAmmo
		end, function()
			return maxAmmo
		end, updateHUDAmmo, gunStats.RechargePerSecond or 1)
	end

	AnimatedSkinEngine.onEquip(tool)
end

local function onToolUnequipped(_tool: Tool): ()
	stopFiring()
	resetCharge()
	AnimatedSkinEngine.onUnequip()
	local wasReloading = ReloadController.reset()

	if equippedTool and gunStats then
		AmmoManager.storeAmmo(equippedTool.Name, currentAmmo)

		if not (gunStats.InfiniteAmmo or player:GetAttribute("AimChamberInfiniteAmmo") == true) and currentAmmo < maxAmmo then
			if isMedigunMode or wasReloading then
				AmmoManager.startBackgroundRecharge(equippedTool.Name, maxAmmo, gunStats.RechargePerSecond or 15)
			end
		end
	end

	if isMedigunMode then
		MedigunHandler.stopHealing()
		if lastHealTargetId then
			Network.Gun.sendMediBeamStop()
		end
	end

	if fireSound then
		local parent = fireSound.Parent
		local isReplicatedSound = parent and parent.Name == "Handle" and fireSound.Name == "Fire"
		if not isReplicatedSound then
			fireSound:Destroy()
		end
		fireSound = nil
	end

	equippedTool = nil
	gunStats = nil
	isMedigunMode = false
	lastHealTargetId = nil
	cachedBarrel = nil
	cachedBarrelParent = nil
	cachedHandle = nil

	GunHUD.setVisible(false)
	GunHUD.setChargeVisible(false)
end

local function setupCharacter(char: Model): ()
	BlurEffect.cleanupAll()

	localHumanoid = char:FindFirstChildOfClass("Humanoid")
	localHead = char:FindFirstChild("Head") :: BasePart?

	if not localHumanoid or not localHead then
		task.spawn(function()
			if not localHumanoid then
				local h = char:WaitForChild("Humanoid", 10)
				if h and char == player.Character then
					localHumanoid = h :: Humanoid
				end
			end
			if not localHead then
				local h = char:WaitForChild("Head", 10)
				if h and char == player.Character then
					localHead = h :: BasePart
				end
			end
		end)
	end

	table.clear(gunFireTimes)
	FireCore.updateCharacter(char)
	AmmoManager.cancelBackgroundRecharge()
	AmmoManager.clearStoredAmmo()

	for _, conn in toolConnections do
		conn:Disconnect()
	end
	table.clear(toolConnections)

	table.insert(
		toolConnections,
		char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				onToolEquipped(child)
			end
		end)
	)

	table.insert(
		toolConnections,
		char.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and child == equippedTool then
				onToolUnequipped(child)
			end
		end)
	)

	local existingTool = char:FindFirstChildWhichIsA("Tool")
	if existingTool then
		onToolEquipped(existingTool)
	end
end

local function cleanupCharacter(): ()
	localHumanoid = nil
	localHead = nil

	for _, conn in toolConnections do
		conn:Disconnect()
	end
	table.clear(toolConnections)

	stopFiring()
	resetCharge()
	ReloadController.reset()
	FireCore.clearCharacter()
	Feedback.clearActive()

	if isMedigunMode then
		MedigunHandler.stopHealing()
	end

	if fireSound then
		local parent = fireSound.Parent
		local isReplicatedSound = parent and parent.Name == "Handle" and fireSound.Name == "Fire"
		if not isReplicatedSound then
			fireSound:Destroy()
		end
		fireSound = nil
	end

	equippedTool = nil
	gunStats = nil
	isMedigunMode = false
	lastHealTargetId = nil
	fireBlocked = false
	cachedBarrel = nil
	cachedBarrelParent = nil
	cachedHandle = nil
end

function GunService:init(): ()
	Cache.init()
	FireCore.init()
	NetworkDispatcher.init()
	Feedback.init()
	VFXRenderer.init()
	ReloadController.init()
	MedigunHandler.init()
	OOCIndicator.init()
	SoundReplicator.init()
	AnimatedSkinEngine.init()

	local playerGui = player:WaitForChild("PlayerGui", 5)
	GunHUD.init(playerGui :: PlayerGui)

	isInitialized = true
end

function GunService:start(): ()
	if not isInitialized then
		self:init()
	end

	table.insert(inputConnections, UserInputService.InputBegan:Connect(onInputBegan))
	table.insert(inputConnections, UserInputService.InputEnded:Connect(onInputEnded))

	local weapon = ServiceLocator.Weapon()
	if weapon then
		weapon:OnZoomChanged(function(zooming: boolean)
			if not gunStats or not gunStats.Chargeable then
				return
			end
			if zooming then
				startCharging()
			elseif not fireBlocked then
				resetCharge()
			end
		end)
	end

	characterConnection = player.CharacterAdded:Connect(setupCharacter)
	table.insert(inputConnections, player.CharacterRemoving:Connect(cleanupCharacter))

	table.insert(
		inputConnections,
		Players.PlayerRemoving:Connect(function(leavingPlayer)
			remoteBarrelCache[leavingPlayer.UserId] = nil
		end)
	)

	local localUserId = player.UserId
	table.insert(
		inputConnections,
		Network.Gun.onReplicateReceived(function(data, count)
			if count and count > 0 then
				for i = 1, count do
					local shot = data[i]
					if not shot then
						continue
					end
					if shot.shooterId == localUserId then
						continue
					end
					local _, barrelPart = findRemoteBarrelInfo(shot.shooterId)
					local gunName = shot.gunIndex and GunStats.GUN_INDEX_TO_NAME[shot.gunIndex]
					VFXRenderer.renderRay(shot.origin, shot.target, barrelPart, shot.shooterId, gunName)
					SoundReplicator.playGunSound(shot.shooterId, shot.gunIndex, shot.origin)
				end
			else
				if data.shooterId == localUserId then
					return
				end
				local _, barrelPart = findRemoteBarrelInfo(data.shooterId)
				local gunName = data.gunIndex and GunStats.GUN_INDEX_TO_NAME[data.gunIndex]
				VFXRenderer.renderRay(data.origin, data.target, barrelPart, data.shooterId, gunName)
				if data.shooterId and data.gunIndex then
					SoundReplicator.playGunSound(data.shooterId, data.gunIndex, data.origin)
				end
			end
		end)
	)

	table.insert(
		inputConnections,
		Network.AimChamber.onNpcShotReceived(function(payload: any)
			if type(payload) ~= "table" then
				return
			end
			local origin = payload.origin
			local target = payload.target
			if typeof(origin) ~= "Vector3" or typeof(target) ~= "Vector3" then
				return
			end

			VFXRenderer.renderRay(origin, target, nil, -1, payload.gunName or "H-82")
		end)
	)

	table.insert(
		inputConnections,
		Network.Gun.onMediBeamReceived(function(healerId, action, targetId)
			if action == "start" and targetId then
				MedigunHandler.renderRemoteBeam(healerId, targetId)
			elseif action == "stop" then
				MedigunHandler.stopRemoteBeam(healerId)
			end
		end)
	)

	table.insert(
		inputConnections,
		Network.Gun.onLowChargeReceived(function(healerId)
			OOCIndicator.show(healerId)
		end)
	)

	table.insert(
		inputConnections,
		Network.Gun.onKill(function(data)
			if data.killer == player.UserId then
				local victimPlayer = Players:GetPlayerByUserId(data.victim)
				local victimRootPart: BasePart? = nil

				if victimPlayer and victimPlayer.Character then
					local hrp = victimPlayer.Character:FindFirstChild("HumanoidRootPart")
					if hrp and hrp:IsA("BasePart") then
						victimRootPart = hrp
					end
				end

				local killGunName = data.gunName
				if (data.killer == player.UserId or (not killGunName and not data.weapon)) and equippedTool then
					killGunName = equippedTool.Name
				elseif not killGunName and data.weapon then
					killGunName = GunStats.GUN_INDEX_TO_NAME[data.weapon]
				end

				Feedback.showKill(victimRootPart, killGunName)
			end
		end)
	)

	if player.Character then
		setupCharacter(player.Character)
	end
end

function GunService:IsReloading(): boolean
	return ReloadController.isReloading()
end

function GunService:SetFireBlocked(blocked: boolean): ()
	fireBlocked = blocked
	if blocked and isFiring then
		stopFiring()
	end
	if blocked then
		local weapon = ServiceLocator.Weapon()
		if weapon then
			weapon:SetZooming(false)
		end
	end
end

function GunService:StopFiring(): ()
	stopFiring()
end

function GunService:ClearActiveRays(): ()
	VFXRenderer.clearActiveRays()
end

function GunService:Cleanup(): ()
	for _, conn in inputConnections do
		conn:Disconnect()
	end
	table.clear(inputConnections)

	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end

	if firingThread then
		pcall(task.cancel, firingThread)
		firingThread = nil
	end

	if barrelRetryThread then
		task.cancel(barrelRetryThread)
		barrelRetryThread = nil
	end

	cleanupCharacter()
	FireCore.cleanup()
	MedigunHandler.cleanup()
	OOCIndicator.cleanup()
	AmmoManager.cleanup()
	ReloadController.cleanup()
	NetworkDispatcher.cleanup()
	Feedback.cleanup()
	VFXRenderer.cleanup()
	SoundReplicator.cleanup()
	AnimatedSkinEngine.cleanup()
	Cache.cleanup()

	table.clear(remoteBarrelCache)

	resetCharge()
	GunHUD.destroy()

	isInitialized = false
end

return GunService
