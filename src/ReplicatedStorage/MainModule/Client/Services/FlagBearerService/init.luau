--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local FlagBearerConfig = require(MainModule.Shared.Config.Champions.FlagBearerConfig)
local PlayerCache = require(MainModule.Shared.Cache.PlayerCache)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

local FlagBearerAbilityHUD = require(MainModule.Client.Components.FlagBearerAbilityHUD)
local ShieldHealthBar = require(MainModule.Client.Components.ShieldHealthBar)

type AbilityState = FlagBearerAbilityHUD.AbilityState
type ShieldBar = ShieldHealthBar.ShieldBar

local AuraHealCfg = FlagBearerConfig.AuraHeal
local ShieldCfg = FlagBearerConfig.Shield

local FLAG_NAME = "FlagBanner"
local ANIMATION_ID = FlagBearerConfig.FlagAnimationId
local COOLDOWN_UPDATE_INTERVAL = 0.05

local NR_LIFETIME = NumberRange.new(1)
local NR_SPEED = NumberRange.new(0.5)
local NR_ROTATION = NumberRange.new(0, 180)
local NR_ROT_SPEED = NumberRange.new(-45, 45)

local FlagBearerService = {}
FlagBearerService.Name = "FlagBearerService"

local localPlayer = Players.LocalPlayer
local connections: { RBXScriptConnection } = {}
local ModelsService: any = nil

local cachedPlayerGui: PlayerGui? = nil

local isFlagBearer = false
local hasToolEquipped = false
local flagAnimTrack: AnimationTrack? = nil
local abilityStatus: Network.FlagBearerAbilityStatus? = nil
local isApplyingFlag = false

local healVFXActive: { [number]: { instances: { Instance }, emitters: { ParticleEmitter } } } = {}
local healVFXCleanupThreads: { [number]: thread } = {}
local healVFXInstanceThreads: { [number]: thread } = {}

local heartbeatConnection: RBXScriptConnection? = nil
local heartbeatUpdateFn: (() -> ())? = nil
local stopHeartbeatIfIdle: () -> ()

local function ensureHeartbeatRunning()
	if not heartbeatConnection and heartbeatUpdateFn then
		heartbeatConnection = RunService.Heartbeat:Connect(heartbeatUpdateFn)
	end
end
local pendingDestroyInstances: { [number]: { Instance } } = {}
local characterConnections: { RBXScriptConnection } = {}
local cachedRootPart: BasePart? = nil

local lastCooldownUpdate = 0
local cooldownEndTimes = { AuraHeal = 0, Shield = 0 }

type ShieldUIData = {
	bar: ShieldBar,
	part: BasePart,
}

local shotShields: { [number]: boolean } = {}
local shieldUIs: { [number]: ShieldUIData } = {}
local shieldWatchConns: { RBXScriptConnection } = {}

stopHeartbeatIfIdle = function()
	if not isFlagBearer and next(shieldUIs) == nil then
		if heartbeatConnection then
			heartbeatConnection:Disconnect()
			heartbeatConnection = nil
		end
	end
end

local cachedBeingHealedTemplate: Attachment? = nil
local vfxTemplateSearched = false

local function loadBeingHealedTemplate(): ()
	if vfxTemplateSearched then
		return
	end
	vfxTemplateSearched = true
	if not ModelsService then
		return
	end
	if not ModelsService:IsLoaded() then
		local attempts = 0
		while not ModelsService:IsLoaded() and attempts < 100 do
			task.wait(0.1)
			attempts += 1
		end
	end
	if not ModelsService:IsLoaded() then
		return
	end
	local vfx = ModelsService:Find("MedicAuraVFX")
	if not vfx then
		return
	end
	local part = vfx:FindFirstChild("Part")
	if not part then
		return
	end
	cachedBeingHealedTemplate = part:FindFirstChild("BeingHealed") :: Attachment?
end

local function getBeingHealedTemplate(): Attachment?
	loadBeingHealedTemplate()
	return cachedBeingHealedTemplate
end

local function createFallbackBeingHealedAttachment(): Attachment
	local attach = Instance.new("Attachment")
	attach.Name = "BeingHealedFallback"
	attach:SetAttribute("IgnoreWorldParticles", true)

	local particle = Instance.new("ParticleEmitter")
	particle.Name = "HealAura"
	particle:SetAttribute("IgnoreWorldParticles", true)
	particle.Texture = "rbxassetid://4925956526"
	particle.Color = ColorSequence.new(Color3.fromRGB(100, 255, 100))
	particle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0) })
	particle.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	particle.Rate = 20
	particle.Lifetime = NR_LIFETIME
	particle.Speed = NR_SPEED
	particle.SpreadAngle = Vector2.new(45, 45)
	particle.Rotation = NR_ROTATION
	particle.RotSpeed = NR_ROT_SPEED
	particle.Enabled = true
	particle.Parent = attach

	return attach
end

local function cleanupAnimation(): ()
	if flagAnimTrack then
		flagAnimTrack:Stop()
		flagAnimTrack:Destroy()
		flagAnimTrack = nil
	end
end

local function playFlagHoldAnimation(): ()
	cleanupAnimation()
	local character = localPlayer.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
		RunService.Heartbeat:Wait()
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = ANIMATION_ID
	local success, track = pcall(function()
		return (animator :: Animator):LoadAnimation(anim)
	end)
	anim:Destroy()
	if success and track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play()
		flagAnimTrack = track
	end
end

local function applyFlagToCharacter(): ()
	if isApplyingFlag then
		return
	end
	local character = localPlayer.Character
	if not character then
		return
	end
	isApplyingFlag = true
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if not humanoid then
		isApplyingFlag = false
		return
	end
	local flagModel = character:FindFirstChild(FLAG_NAME)
	if not flagModel then
		for _ = 1, 100 do
			flagModel = character:FindFirstChild(FLAG_NAME)
			if flagModel then
				break
			end
			RunService.Heartbeat:Wait()
		end
	end
	if not flagModel or not character.Parent or not isFlagBearer then
		isApplyingFlag = false
		return
	end
	task.wait(0.1)
	if character.Parent and isFlagBearer then
		playFlagHoldAnimation()
	end
	isApplyingFlag = false
end

local function destroyVFXInstances(userId: number): ()
	healVFXInstanceThreads[userId] = nil
	local instances = pendingDestroyInstances[userId]
	pendingDestroyInstances[userId] = nil
	if not instances then
		return
	end
	for _, inst in instances do
		if inst and inst.Parent then
			inst:Destroy()
		end
	end
end

local function cleanupHealVFX(userId: number): ()
	local data = healVFXActive[userId]
	if not data then
		return
	end
	for _, emitter in data.emitters do
		emitter.Enabled = false
	end
	local instances = data.instances
	if healVFXInstanceThreads[userId] then
		task.cancel(healVFXInstanceThreads[userId])
	end
	pendingDestroyInstances[userId] = instances
	healVFXInstanceThreads[userId] = task.delay(1, destroyVFXInstances, userId)
	healVFXActive[userId] = nil
end

local function triggerHealVFXCleanup(targetUserId: number): ()
	healVFXCleanupThreads[targetUserId] = nil
	cleanupHealVFX(targetUserId)
end

local function showHealVFX(targetUserId: number): ()
	local cached = PlayerCache.getByUserId(targetUserId)
	if not cached or not cached.player then
		return
	end
	local character = cached.player.Character
	if not character then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local active = healVFXActive[targetUserId]
	if active then
		local currentAttach = active.instances[1]
		if currentAttach and currentAttach.Parent == rootPart then
			if healVFXCleanupThreads[targetUserId] then
				task.cancel(healVFXCleanupThreads[targetUserId])
			end
			healVFXCleanupThreads[targetUserId] = task.delay(0.5, triggerHealVFXCleanup, targetUserId)
			return
		end
		cleanupHealVFX(targetUserId)
	end

	if healVFXInstanceThreads[targetUserId] then
		task.cancel(healVFXInstanceThreads[targetUserId])
		healVFXInstanceThreads[targetUserId] = nil
		local pendingInstances = pendingDestroyInstances[targetUserId]
		if pendingInstances then
			for _, inst in pendingInstances do
				if inst and inst.Parent then
					inst:Destroy()
				end
			end
		end
		pendingDestroyInstances[targetUserId] = nil
	end

	local template = getBeingHealedTemplate()
	local attach = if template then template:Clone() else createFallbackBeingHealedAttachment()
	attach:SetAttribute("IgnoreWorldParticles", true)
	local emitters: { ParticleEmitter } = {}
	for _, desc in attach:GetDescendants() do
		if desc:IsA("ParticleEmitter") then
			desc:SetAttribute("IgnoreWorldParticles", true)
			desc.Enabled = true
			table.insert(emitters, desc)
		end
	end
	attach.Parent = rootPart
	healVFXActive[targetUserId] = { instances = { attach }, emitters = emitters }
	if healVFXCleanupThreads[targetUserId] then
		task.cancel(healVFXCleanupThreads[targetUserId])
	end
	healVFXCleanupThreads[targetUserId] = task.delay(0.5, triggerHealVFXCleanup, targetUserId)
end

local function updateHUDVisibility(): ()
	FlagBearerAbilityHUD.setVisible(isFlagBearer and hasToolEquipped)
end

local function cleanupCharacterConnections(): ()
	for _, conn in characterConnections do
		conn:Disconnect()
	end
	table.clear(characterConnections)
	hasToolEquipped = false
end

local function setupCharacterToolTracking(character: Model): ()
	cleanupCharacterConnections()
	hasToolEquipped = character:FindFirstChildWhichIsA("Tool") ~= nil
	updateHUDVisibility()
	table.insert(
		characterConnections,
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				hasToolEquipped = true
				updateHUDVisibility()
			end
		end)
	)
	table.insert(
		characterConnections,
		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				hasToolEquipped = character:FindFirstChildWhichIsA("Tool") ~= nil
				updateHUDVisibility()
			end
		end)
	)
end

local function cleanupShieldUI(ownerUserId: number): ()
	local data = shieldUIs[ownerUserId]
	if not data then
		return
	end
	if data.healthConn then
		data.healthConn:Disconnect()
	end
	if data.ancestryConn then
		data.ancestryConn:Disconnect()
	end
	data.bar.destroy()
	shieldUIs[ownerUserId] = nil
	shotShields[ownerUserId] = nil
end

local function setupShieldUI(shieldPart: BasePart): ()
	local ownerUserId = shieldPart:GetAttribute("OwnerUserId") :: number?
	if not ownerUserId then
		return
	end
	if shieldUIs[ownerUserId] then
		cleanupShieldUI(ownerUserId)
	end
	if not cachedPlayerGui then
		return
	end

	local maxHealth = shieldPart:GetAttribute("MaxHealth") :: number? or 500
	local currentHealth = shieldPart:GetAttribute("CurrentHealth") :: number? or maxHealth

	local bar = ShieldHealthBar.create(shieldPart, cachedPlayerGui)
	bar.setHealth(currentHealth, maxHealth)
	bar.setVisible(ownerUserId == localPlayer.UserId)

	local healthConn = shieldPart:GetAttributeChangedSignal("CurrentHealth"):Connect(function()
		local newHealth = shieldPart:GetAttribute("CurrentHealth") :: number? or 0
		bar.setHealth(newHealth, maxHealth)
		if newHealth <= 0 then
			cleanupShieldUI(ownerUserId)
		end
	end)

	local ancestryConn = shieldPart.AncestryChanged:Connect(function()
		if not shieldPart:IsDescendantOf(workspace) then
			healthConn:Disconnect()
			cleanupShieldUI(ownerUserId)
		end
	end)

	table.insert(shieldWatchConns, healthConn)
	table.insert(shieldWatchConns, ancestryConn)

	shieldUIs[ownerUserId] = { bar = bar, part = shieldPart, healthConn = healthConn, ancestryConn = ancestryConn }
end

local function resolveAbilityState(isActive: boolean, isReady: boolean, cd: number): AbilityState
	if isActive then
		return "active"
	end
	if cd <= 0 or isReady then
		return "ready"
	end
	return "cooldown"
end

local function onStateReceived(enabled: boolean): ()
	isFlagBearer = enabled
	updateHUDVisibility()
	if enabled then
		ensureHeartbeatRunning()
		task.spawn(applyFlagToCharacter)
	else
		cleanupAnimation()
		FlagBearerAbilityHUD.setShieldState("cooldown", 0)
		FlagBearerAbilityHUD.setHealState("cooldown", 0)
		cooldownEndTimes = { AuraHeal = 0, Shield = 0 }
	end
end

local function onAbilityStatusReceived(status: Network.FlagBearerAbilityStatus): ()
	abilityStatus = status
	local now = os.clock()
	cooldownEndTimes.AuraHeal = if status.AuraHealCooldown > 0 and not status.AuraHealActive
		then now + status.AuraHealCooldown
		else 0
	cooldownEndTimes.Shield = if status.ShieldCooldown > 0 and not status.ShieldActive
		then now + status.ShieldCooldown
		else 0

	local healCd = math.max(0, cooldownEndTimes.AuraHeal - now)
	local shieldCd = math.max(0, cooldownEndTimes.Shield - now)
	FlagBearerAbilityHUD.setHealState(resolveAbilityState(status.AuraHealActive, status.AuraHealReady, healCd), healCd)
	FlagBearerAbilityHUD.setShieldState(
		resolveAbilityState(status.ShieldActive, status.ShieldReady, shieldCd),
		shieldCd
	)
end

local function onInputBegan(input: InputObject, gameProcessed: boolean): ()
	if gameProcessed or not isFlagBearer then
		return
	end
	
	local settingsService = LazyService.create(MainModule, "SettingsService")()
	local healKeyName = settingsService:GetKeybind("FlagBearerHeal") or "E"
	local shieldKeyName = settingsService:GetKeybind("FlagBearerShield") or "G"
	
	local successHeal, healKey = pcall(function()
		return Enum.KeyCode[healKeyName]
	end)
	local successShield, shieldKey = pcall(function()
		return Enum.KeyCode[shieldKeyName]
	end)
	
	local targetHealKey = if successHeal and healKey then healKey else AuraHealCfg.Key
	local targetShieldKey = if successShield and shieldKey then shieldKey else ShieldCfg.Key

	if input.KeyCode == targetHealKey then
		Network.FlagBearer.fireActivateAbility("AuraHeal")
	elseif input.KeyCode == targetShieldKey then
		Network.FlagBearer.fireActivateAbility("EnergyShield")
	end
end

local function onCharacterAdded(character: Model): ()
	cachedRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	setupCharacterToolTracking(character)
	if isFlagBearer then
		task.spawn(applyFlagToCharacter)
	end
end

local function onCharacterRemoving(_character: Model): ()
	cachedRootPart = nil
	cleanupCharacterConnections()
	cleanupAnimation()
	isApplyingFlag = false
	updateHUDVisibility()
end

function FlagBearerService:init(): ()
	cachedPlayerGui = localPlayer:WaitForChild("PlayerGui", 5) :: PlayerGui
	FlagBearerAbilityHUD.init(cachedPlayerGui :: PlayerGui)
end

function FlagBearerService:start(): ()
	ModelsService = LazyService.create(MainModule, "ModelsService")()

	task.spawn(loadBeingHealedTemplate)

	table.insert(connections, Network.FlagBearer.onStateReceived(onStateReceived))
	table.insert(connections, Network.FlagBearer.onAbilityStatus(onAbilityStatusReceived))
	table.insert(
		connections,
		Network.FlagBearer.onHealVFX(function(targetUserIds: { number })
			for _, userId in targetUserIds do
				showHealVFX(userId)
			end
		end)
	)
	table.insert(connections, UserInputService.InputBegan:Connect(onInputBegan))

	if localPlayer.Character then
		cachedRootPart = localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		setupCharacterToolTracking(localPlayer.Character)
		if isFlagBearer then
			task.spawn(applyFlagToCharacter)
		end
	end
	table.insert(connections, localPlayer.CharacterAdded:Connect(onCharacterAdded))
	table.insert(connections, localPlayer.CharacterRemoving:Connect(onCharacterRemoving))

	for _, child in workspace:GetChildren() do
		if child:IsA("BasePart") and child.Name == "FlagBearerShield" then
			setupShieldUI(child)
		end
	end

	table.insert(
		connections,
		workspace.ChildAdded:Connect(function(child)
			if child:IsA("BasePart") and child.Name == "FlagBearerShield" then
				setupShieldUI(child)
			end
		end)
	)

	table.insert(
		connections,
		workspace.ChildRemoved:Connect(function(child)
			if child:IsA("BasePart") and child.Name == "FlagBearerShield" then
				local ownerUserId = child:GetAttribute("OwnerUserId") :: number?
				if ownerUserId then
					cleanupShieldUI(ownerUserId)
				end
			end
		end)
	)

	local function heartbeatUpdate()
		debug.profilebegin("FlagBearerService::heartbeat")

		local now = os.clock()

		if isFlagBearer and now - lastCooldownUpdate >= COOLDOWN_UPDATE_INTERVAL then
			lastCooldownUpdate = now
			local healCd = math.max(0, cooldownEndTimes.AuraHeal - now)
			local shieldCd = math.max(0, cooldownEndTimes.Shield - now)
			local isHealActive = abilityStatus and abilityStatus.AuraHealActive
			local isShieldActive = abilityStatus and abilityStatus.ShieldActive
			FlagBearerAbilityHUD.setHealState(
				if isHealActive then "active" elseif healCd <= 0 then "ready" else "cooldown",
				healCd
			)
			FlagBearerAbilityHUD.setShieldState(
				if isShieldActive then "active" elseif shieldCd <= 0 then "ready" else "cooldown",
				shieldCd
			)
		end

		local rootPart = cachedRootPart
		for ownerUserId, uiData in shieldUIs do
			local shieldPart = uiData.part
			local isInside = false
			if rootPart and shieldPart and shieldPart.Parent then
				local delta = shieldPart.Position - rootPart.Position
				isInside = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z < ShieldCfg.RadiusSquared
			end
			uiData.bar.setVisible(ownerUserId == localPlayer.UserId or isInside or shotShields[ownerUserId] == true)
		end

		stopHeartbeatIfIdle()

		debug.profileend()
	end

	heartbeatUpdateFn = heartbeatUpdate

	if isFlagBearer or next(shieldUIs) then
		ensureHeartbeatRunning()
	end

	local originalSetupShieldUI = setupShieldUI
	setupShieldUI = function(shieldPart: BasePart)
		originalSetupShieldUI(shieldPart)
		ensureHeartbeatRunning()
	end
end

function FlagBearerService:IsFlagBearer(): boolean
	return isFlagBearer
end

function FlagBearerService:GetAbilityStatus(): Network.FlagBearerAbilityStatus?
	return abilityStatus
end

function FlagBearerService:OnShieldHit(ownerUserId: number): ()
	shotShields[ownerUserId] = true
end

function FlagBearerService:Cleanup(): ()
	cleanupAnimation()
	cleanupCharacterConnections()

	for userId, thread in healVFXCleanupThreads do
		task.cancel(thread)
		healVFXCleanupThreads[userId] = nil
	end
	for userId, thread in healVFXInstanceThreads do
		task.cancel(thread)
		healVFXInstanceThreads[userId] = nil
	end
	for userId in healVFXActive do
		cleanupHealVFX(userId)
	end
	for ownerUserId in shieldUIs do
		cleanupShieldUI(ownerUserId)
	end
	for _, conn in shieldWatchConns do
		conn:Disconnect()
	end
	table.clear(shieldWatchConns)
	table.clear(shotShields)
	table.clear(shieldUIs)

	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	table.clear(healVFXActive)
	table.clear(pendingDestroyInstances)

	FlagBearerAbilityHUD.destroy()

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	heartbeatUpdateFn = nil

	isFlagBearer = false
	isApplyingFlag = false
	abilityStatus = nil
	cachedRootPart = nil
	cooldownEndTimes = { AuraHeal = 0, Shield = 0 }
end

return FlagBearerService
