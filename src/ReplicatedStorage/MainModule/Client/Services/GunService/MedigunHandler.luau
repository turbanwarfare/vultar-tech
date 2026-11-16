--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MainModule = script.Parent.Parent.Parent.Parent
local Cache = require(script.Parent.Cache)
local Constants = require(script.Parent.Constants)
local FactionUtils = require(MainModule.Shared.Utils.Game.FactionUtils)

local MedigunHandler = {}

local localPlayer = Players.LocalPlayer
local localMouse = localPlayer:GetMouse()

local MEDI_BEAM_TEXTURE = "rbxassetid://12781750620"
local MEDI_BEAM_COLOR = Color3.fromRGB(0, 255, 100)
local MEDI_BEAM_COLOR_SEQUENCE = ColorSequence.new(MEDI_BEAM_COLOR)
local MEDI_BEAM_TRANSPARENCY = NumberSequence.new(0.1)
local MEDI_BEAM_WIDTH = 1.2
local MEDI_PART_WIDTH = 0.2

local RECHARGE_DELAY = 1.5
local RECHARGE_RATE = 1 / 1.5

local teammateCache: { [Player]: boolean } = {}
local characterHumanoidCache: { [Model]: Humanoid } = setmetatable({}, { __mode = "k" }) :: any
local characterToPlayerMap: { [Model]: Player } = {}
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local playerAddedConn: RBXScriptConnection? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local localTeamConn: RBXScriptConnection? = nil

local currentBeam: Beam? = nil
local currentBeamPart: Part? = nil
local currentBarrelPart: BasePart? = nil
local beamAttachment0: Attachment? = nil
local beamAttachment1: Attachment? = nil
local currentTarget: Humanoid? = nil
local targetTorso: BasePart? = nil

local currentCamera = workspace.CurrentCamera
local activeBeamUpdaters: { [string]: () -> () } = {}
local sharedBeamConnection: RBXScriptConnection? = nil
local activeBeamCount = 0

local LOCAL_BEAM_KEY = "__local__"

local function removeBeamUpdater(key: string): ()
	if not activeBeamUpdaters[key] then
		return
	end

	activeBeamUpdaters[key] = nil
	activeBeamCount -= 1

	if activeBeamCount <= 0 then
		activeBeamCount = 0
		if sharedBeamConnection then
			sharedBeamConnection:Disconnect()
			sharedBeamConnection = nil
		end
	end
end

local function addBeamUpdater(key: string, updater: () -> ()): ()
	if activeBeamUpdaters[key] then
		activeBeamUpdaters[key] = updater
		return
	end

	activeBeamUpdaters[key] = updater
	activeBeamCount += 1

	if not sharedBeamConnection then
		sharedBeamConnection = RunService.RenderStepped:Connect(function()
			debug.profilebegin("GunService::medigunBeam")
			for _, fn in activeBeamUpdaters do
				fn()
			end
			debug.profileend()
		end)
	end
end

local rechargeTask: thread? = nil
local isRecharging = false

local barrelAttachment: Attachment? = nil

local HEAL_HIGHLIGHT_COLOR = Color3.fromRGB(80, 255, 120)
local HEAL_HIGHLIGHT_TRANSPARENCY = 0.65
local HEAL_HIGHLIGHT_THICKNESS = 0.04
local HEAL_BOX_COUNT = 6
local healBoxPool: { SelectionBox } = {}
local healHolder: Folder? = nil
local healHighlightActiveCount: number = 0
local healHighlightTarget: Model? = nil

local healSound: Sound? = nil

local TARGET_RESELECT_INTERVAL = 0.1
local lastTargetSelectTime = 0
local cachedHealTarget: Humanoid? = nil
local cachedHealTorso: BasePart? = nil

local function getCharacterTorso(character: Model): BasePart?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	if torso and torso:IsA("BasePart") then
		return torso
	end
	return nil
end

local function updatePlayerInCache(player: Player): ()
	if player == localPlayer then
		return
	end

	if FactionUtils.isSpectator(localPlayer) then
		teammateCache[player] = nil
		return
	end

	if not FactionUtils.isSpectator(player) and FactionUtils.areSameFaction(localPlayer, player) then
		teammateCache[player] = true
	else
		teammateCache[player] = nil
	end
end

local function rebuildTeammateCache(): ()
	table.clear(teammateCache)

	if FactionUtils.isSpectator(localPlayer) then
		return
	end

	for _, player in Players:GetPlayers() do
		if player ~= localPlayer then
			updatePlayerInCache(player)
		end
	end
end

local function setupPlayerConnections(player: Player): ()
	if player == localPlayer then
		return
	end

	local conns = {}
	table.insert(
		conns,
		player:GetPropertyChangedSignal("Team"):Connect(function()
			updatePlayerInCache(player)
		end)
	)
	table.insert(
		conns,
		player.CharacterAdded:Connect(function(char: Model)
			characterToPlayerMap[char] = player
		end)
	)
	table.insert(
		conns,
		player.CharacterRemoving:Connect(function(char: Model)
			characterHumanoidCache[char] = nil
			characterToPlayerMap[char] = nil
		end)
	)
	if player.Character then
		characterToPlayerMap[player.Character] = player
	end
	playerConnections[player] = conns
	updatePlayerInCache(player)
end

local function cleanupPlayerConnections(player: Player): ()
	local conns = playerConnections[player]
	if conns then
		for _, conn in conns do
			conn:Disconnect()
		end
		playerConnections[player] = nil
	end
	teammateCache[player] = nil
	local char = player.Character
	if char then
		characterHumanoidCache[char] = nil
		characterToPlayerMap[char] = nil
	end
end

local stickyTarget: Humanoid? = nil

local NPC_TEAMMATE_NAME = "NPC_Teammate"

local function getNPCTeammate(): Model?
	return workspace:FindFirstChild(NPC_TEAMMATE_NAME) :: Model?
end

local function getHumanoidFromModel(model: Model): (Humanoid?, BasePart?)
	local humanoid = characterHumanoidCache[model]
	if not humanoid then
		humanoid = model:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return nil, nil
		end
		characterHumanoidCache[model] = humanoid
	end
	if humanoid.Health <= 0 then
		return nil, nil
	end

	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model:FindFirstChild("HumanoidRootPart")
	if not torso or not torso:IsA("BasePart") then
		return nil, nil
	end

	return humanoid, torso :: BasePart
end

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true
local raycastFilterList: { Instance } = {}

local function hasLineOfSight(origin: Vector3, torso: BasePart, targetCharacter: Model): boolean
	local localCharacter = localPlayer.Character

	if localCharacter then
		raycastFilterList[1] = localCharacter
		raycastFilterList[2] = targetCharacter
	else
		raycastFilterList[1] = targetCharacter
		raycastFilterList[2] = nil :: any
	end
	raycastParams.FilterDescendantsInstances = raycastFilterList

	local direction = torso.Position - origin
	local result = workspace:Raycast(origin, direction, raycastParams)

	if not result then
		return true
	end

	return result.Instance:IsDescendantOf(targetCharacter)
end

local function isValidHealTarget(humanoid: Humanoid, torso: BasePart, origin: Vector3, rangeSq: number, targetModel: Model): boolean
	if humanoid.Health <= 0 then
		return false
	end

	if humanoid.Health >= humanoid.MaxHealth then
		return false
	end

	local delta = torso.Position - origin
	local distanceSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
	if distanceSq > rangeSq then
		return false
	end

	return hasLineOfSight(origin, torso, targetModel)
end

local SCREEN_AIM_THRESHOLD = 150
local SCREEN_AIM_THRESHOLD_SQ = SCREEN_AIM_THRESHOLD * SCREEN_AIM_THRESHOLD

local function scoreScreenCandidate(
	humanoid: Humanoid,
	torso: BasePart,
	targetModel: Model,
	origin: Vector3,
	rangeSq: number,
	cursorX: number,
	cursorY: number,
	bestDistSq: number
): (Humanoid?, BasePart?, number)
	if humanoid.Health >= humanoid.MaxHealth then
		return nil, nil, bestDistSq
	end
	local delta = torso.Position - origin
	local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
	if distSq > rangeSq then
		return nil, nil, bestDistSq
	end

	local screenPos, onScreen = currentCamera:WorldToScreenPoint(torso.Position)
	if not onScreen then
		return nil, nil, bestDistSq
	end
	local dx = screenPos.X - cursorX
	local dy = screenPos.Y - cursorY
	local screenDistSq = dx * dx + dy * dy
	if screenDistSq >= bestDistSq then
		return nil, nil, bestDistSq
	end

	if not hasLineOfSight(origin, torso, targetModel) then
		return nil, nil, bestDistSq
	end
	return humanoid, torso, screenDistSq
end

local function findCursorTarget(origin: Vector3, range: number): (Humanoid?, BasePart?)
	if not currentCamera then
		return nil, nil
	end

	local rangeSq = range * range
	local bestTarget: Humanoid? = nil
	local bestTorso: BasePart? = nil
	local bestScreenDistSq = SCREEN_AIM_THRESHOLD_SQ
	local cursorX, cursorY = localMouse.X, localMouse.Y

	for player in teammateCache do
		if not player.Parent then
			teammateCache[player] = nil
			continue
		end
		local character = player.Character
		if not character then
			continue
		end
		local humanoid, torso = getHumanoidFromModel(character)
		if not humanoid or not torso then
			continue
		end
		local h, t, d = scoreScreenCandidate(humanoid, torso, character, origin, rangeSq, cursorX, cursorY, bestScreenDistSq)
		if h then
			bestTarget, bestTorso, bestScreenDistSq = h, t, d
		end
	end

	local npc = getNPCTeammate()
	if npc then
		local humanoid, torso = getHumanoidFromModel(npc)
		if humanoid and torso then
			local h, t, _ = scoreScreenCandidate(humanoid, torso, npc, origin, rangeSq, cursorX, cursorY, bestScreenDistSq)
			if h then
				bestTarget, bestTorso = h, t
			end
		end
	end

	return bestTarget, bestTorso
end

local function scoreDistanceCandidate(
	humanoid: Humanoid,
	torso: BasePart,
	targetModel: Model,
	origin: Vector3,
	rangeSq: number,
	bestDistSq: number
): (Humanoid?, BasePart?, number)
	local hp = humanoid.Health
	if hp <= 0 or hp >= humanoid.MaxHealth then
		return nil, nil, bestDistSq
	end
	local delta = torso.Position - origin
	local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
	if distSq > rangeSq or distSq >= bestDistSq then
		return nil, nil, bestDistSq
	end
	if not hasLineOfSight(origin, torso, targetModel) then
		return nil, nil, bestDistSq
	end
	return humanoid, torso, distSq
end

local function findClosestTarget(origin: Vector3, range: number): (Humanoid?, BasePart?)
	local rangeSq = range * range
	local bestTarget: Humanoid? = nil
	local bestTorso: BasePart? = nil
	local bestDistanceSq = rangeSq + 1

	for player in teammateCache do
		if not player.Parent then
			teammateCache[player] = nil
			continue
		end
		local character = player.Character
		if not character then
			continue
		end
		local humanoid, torso = getHumanoidFromModel(character)
		if not humanoid or not torso then
			continue
		end
		local h, t, d = scoreDistanceCandidate(humanoid, torso, character, origin, rangeSq, bestDistanceSq)
		if h then
			bestTarget, bestTorso, bestDistanceSq = h, t, d
		end
	end

	local npc = getNPCTeammate()
	if npc then
		local humanoid, torso = getHumanoidFromModel(npc)
		if humanoid and torso then
			local h, t, _ = scoreDistanceCandidate(humanoid, torso, npc, origin, rangeSq, bestDistanceSq)
			if h then
				bestTarget, bestTorso = h, t
			end
		end
	end

	return bestTarget, bestTorso
end

local function findHealTarget(origin: Vector3, range: number): (Humanoid?, BasePart?)
	debug.profilebegin("MedigunHandler::findHealTarget")

	local localCharacter = localPlayer.Character
	if not localCharacter then
		debug.profileend()
		return nil, nil
	end

	local now = os.clock()
	local rangeSq = range * range

	if cachedHealTarget and cachedHealTorso and (now - lastTargetSelectTime) < TARGET_RESELECT_INTERVAL then
		if isValidHealTarget(cachedHealTarget, cachedHealTorso, origin, rangeSq, cachedHealTarget.Parent :: Model) then
			stickyTarget = cachedHealTarget
			debug.profileend()
			return cachedHealTarget, cachedHealTorso
		end
		lastTargetSelectTime = 0
	end

	lastTargetSelectTime = now

	local cursorTarget, cursorTorso = findCursorTarget(origin, range)
	if cursorTarget and cursorTorso then
		stickyTarget = cursorTarget
		cachedHealTarget = cursorTarget
		cachedHealTorso = cursorTorso
		debug.profileend()
		return cursorTarget, cursorTorso
	end

	if stickyTarget and stickyTarget.Parent then
		local stickyModel = stickyTarget.Parent :: Model
		local stickyTorso = getCharacterTorso(stickyModel)
		if stickyTorso and isValidHealTarget(stickyTarget, stickyTorso, origin, rangeSq, stickyModel) then
			cachedHealTarget = stickyTarget
			cachedHealTorso = stickyTorso
			debug.profileend()
			return stickyTarget, stickyTorso
		end
	end

	stickyTarget = nil

	local closestTarget, closestTorso = findClosestTarget(origin, range)
	if closestTarget and closestTorso then
		stickyTarget = closestTarget
		cachedHealTarget = closestTarget
		cachedHealTorso = closestTorso
		debug.profileend()
		return closestTarget, closestTorso
	end

	cachedHealTarget = nil
	cachedHealTorso = nil
	debug.profileend()
	return nil, nil
end

local function updatePartBeamPosition()
	if not currentBeamPart or not currentBarrelPart or not targetTorso then
		MedigunHandler.stopBeam()
		return
	end

	if not currentBarrelPart.Parent or not targetTorso.Parent then
		MedigunHandler.stopBeam()
		return
	end

	local barrelPos = if barrelAttachment then barrelAttachment.WorldPosition else currentBarrelPart.Position
	local targetPos = targetTorso.Position
	local midpoint = (barrelPos + targetPos) / 2
	local distance = (targetPos - barrelPos).Magnitude
	local baseWidth = MEDI_PART_WIDTH * Cache.getRaySize()

	currentBeamPart.Size = Vector3.new(baseWidth, baseWidth, distance)
	currentBeamPart.CFrame = CFrame.lookAt(midpoint, targetPos)
end

local BODY_PARTS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local function hideHealHighlight(): ()
	for i = 1, healHighlightActiveCount do
		healBoxPool[i].Adornee = nil
	end
	healHighlightActiveCount = 0
	healHighlightTarget = nil
end

local function showHealHighlight(targetModel: Model): ()
	if not Cache.getHealHighlightsEnabled() then
		return
	end

	if healHighlightTarget == targetModel and healHighlightActiveCount > 0 then
		return
	end

	hideHealHighlight()

	local count = 0
	for _, partName in BODY_PARTS do
		local part = targetModel:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			count += 1
			local box = healBoxPool[count]
			box.Adornee = part
		end
	end
	healHighlightActiveCount = count
	healHighlightTarget = targetModel
end

local function setupLocalBeamRay(barrel: BasePart, target: BasePart): ()
	if not barrelAttachment then
		beamAttachment0 = Instance.new("Attachment")
		beamAttachment0.Name = "MediBeamStart"
		beamAttachment0.Parent = barrel
	else
		beamAttachment0 = barrelAttachment
	end

	beamAttachment1 = Instance.new("Attachment")
	beamAttachment1.Name = "MediBeamEnd"
	beamAttachment1.Parent = target

	currentBeam = Instance.new("Beam")
	currentBeam.Name = "MediBeam"
	currentBeam.Attachment0 = beamAttachment0
	currentBeam.Attachment1 = beamAttachment1
	currentBeam.Texture = MEDI_BEAM_TEXTURE
	currentBeam.Color = MEDI_BEAM_COLOR_SEQUENCE
	currentBeam.Transparency = MEDI_BEAM_TRANSPARENCY
	currentBeam.LightEmission = 0.8
	currentBeam.LightInfluence = 0
	currentBeam.Width0 = MEDI_BEAM_WIDTH
	currentBeam.Width1 = MEDI_BEAM_WIDTH
	currentBeam.FaceCamera = true
	currentBeam.Segments = 10
	currentBeam.TextureMode = Enum.TextureMode.Wrap
	currentBeam.TextureSpeed = 2
	currentBeam.TextureLength = 1
	currentBeam.Enabled = true
	currentBeam.Parent = barrel
end

local function setupLocalPartBeam(barrel: BasePart, target: BasePart): ()
	local barrelPos = if barrelAttachment then barrelAttachment.WorldPosition else barrel.Position
	local targetPos = target.Position
	local midpoint = (barrelPos + targetPos) / 2
	local distance = (targetPos - barrelPos).Magnitude
	local baseWidth = MEDI_PART_WIDTH * Cache.getRaySize()
	local materialEnum = Cache.getRayMaterial()

	currentBeamPart = Instance.new("Part")
	currentBeamPart.Name = "MediBeamPart"
	currentBeamPart.Anchored = true
	currentBeamPart.CanCollide = false
	currentBeamPart.CanQuery = false
	currentBeamPart.CanTouch = false
	currentBeamPart.Material = if materialEnum == 1 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	currentBeamPart.Color = MEDI_BEAM_COLOR
	currentBeamPart.Transparency = 1 - Cache.getRayOpacity()
	currentBeamPart.Size = Vector3.new(baseWidth, baseWidth, distance)
	currentBeamPart.CFrame = CFrame.lookAt(midpoint, targetPos)
	currentBeamPart.Parent = workspace

	addBeamUpdater(LOCAL_BEAM_KEY, updatePartBeamPosition)
end

local function setupHealSound(barrel: BasePart): ()
	if not Cache.getHealSoundsEnabled() then
		if healSound then
			healSound:Stop()
		end
		return
	end
	if healSound then
		healSound:Stop()
		healSound.Parent = barrel
	else
		healSound = Instance.new("Sound")
		healSound.SoundId = Constants.Sounds.Heal
		healSound.Volume = 0.6
		healSound.Looped = true
		healSound.RollOffMode = Enum.RollOffMode.InverseTapered
		healSound.RollOffMinDistance = 10
		healSound.RollOffMaxDistance = 100
		healSound.Parent = barrel
	end
	healSound:Play()
end

function MedigunHandler.createBeam(barrel: BasePart, target: BasePart): ()
	MedigunHandler.stopBeam()

	targetTorso = target
	currentBarrelPart = barrel
	barrelAttachment = barrel:FindFirstChild("Barrel") :: Attachment?

	if Cache.useBeamRay() then
		setupLocalBeamRay(barrel, target)
	else
		setupLocalPartBeam(barrel, target)
	end

	local targetModel = target.Parent
	if targetModel and targetModel:IsA("Model") then
		showHealHighlight(targetModel)
	end

	setupHealSound(barrel)
end

function MedigunHandler.stopBeam(): ()
	removeBeamUpdater(LOCAL_BEAM_KEY)

	if currentBeam then
		currentBeam:Destroy()
		currentBeam = nil
	end

	if currentBeamPart then
		currentBeamPart:Destroy()
		currentBeamPart = nil
	end

	if beamAttachment0 and beamAttachment0 ~= barrelAttachment then
		beamAttachment0:Destroy()
	end
	beamAttachment0 = nil

	if beamAttachment1 then
		beamAttachment1:Destroy()
		beamAttachment1 = nil
	end

	currentTarget = nil
	targetTorso = nil
	barrelAttachment = nil
	currentBarrelPart = nil
	stickyTarget = nil
	cachedHealTarget = nil
	cachedHealTorso = nil
	lastTargetSelectTime = 0

	hideHealHighlight()

	if healSound then
		healSound:Stop()
		healSound:Destroy()
		healSound = nil
	end
end

export type HealResult = {
	target: Humanoid,
	healAmount: number,
	targetId: number,
	pos: Vector3,
	hitPart: BasePart,
}

local reusableHealResult: HealResult = {
	target = nil :: any,
	healAmount = 0,
	targetId = 0,
	pos = Vector3.zero,
	hitPart = nil :: any,
}

function MedigunHandler.tryHeal(origin: Vector3, range: number, healAmount: number, barrel: BasePart): HealResult?
	debug.profilebegin("MedigunHandler::tryHeal")

	local target, torso = findHealTarget(origin, range)

	if not target or not torso then
		if currentTarget then
			MedigunHandler.stopBeam()
		end
		debug.profileend()
		return nil
	end

	if target ~= currentTarget then
		MedigunHandler.createBeam(barrel, torso)
		currentTarget = target
	end

	if target.Health >= target.MaxHealth then
		debug.profileend()
		return nil
	end

	local targetChar = target.Parent :: Model
	local targetPlayer = characterToPlayerMap[targetChar]
	local targetId = targetPlayer and targetPlayer.UserId or 0

	reusableHealResult.target = target
	reusableHealResult.healAmount = healAmount
	reusableHealResult.targetId = targetId
	reusableHealResult.pos = torso.Position
	reusableHealResult.hitPart = torso

	debug.profileend()
	return reusableHealResult
end

function MedigunHandler.startAutoRecharge(getCurrentAmmo: () -> number, getMaxAmmo: () -> number, setAmmo: (number) -> (), _rechargeRate: number): ()
	MedigunHandler.stopAutoRecharge()

	isRecharging = true
	rechargeTask = task.spawn(function()
		task.wait(RECHARGE_DELAY)

		while isRecharging do
			local current = getCurrentAmmo()
			local max = getMaxAmmo()

			if current >= max then
				isRecharging = false
				break
			end

			setAmmo(current + 1)
			task.wait(1 / RECHARGE_RATE)
		end

		rechargeTask = nil
	end)
end

function MedigunHandler.stopAutoRecharge(): ()
	isRecharging = false
	if rechargeTask then
		task.cancel(rechargeTask)
		rechargeTask = nil
	end
end

function MedigunHandler.isRecharging(): boolean
	return isRecharging
end

function MedigunHandler.getCurrentTarget(): Humanoid?
	return currentTarget
end

function MedigunHandler.init(): ()
	local holder = Instance.new("Folder")
	holder.Name = "HealHighlights"
	holder.Parent = workspace
	healHolder = holder

	local boxTemplate = Instance.new("SelectionBox")
	boxTemplate.Color3 = HEAL_HIGHLIGHT_COLOR
	boxTemplate.SurfaceColor3 = HEAL_HIGHLIGHT_COLOR
	boxTemplate.SurfaceTransparency = 1
	boxTemplate.Transparency = HEAL_HIGHLIGHT_TRANSPARENCY
	boxTemplate.LineThickness = HEAL_HIGHLIGHT_THICKNESS
	boxTemplate.Parent = holder
	healBoxPool[1] = boxTemplate

	for i = 2, HEAL_BOX_COUNT do
		local clone = boxTemplate:Clone()
		clone.Parent = holder
		healBoxPool[i] = clone
	end

	rebuildTeammateCache()

	for _, player in Players:GetPlayers() do
		setupPlayerConnections(player)
	end

	playerAddedConn = Players.PlayerAdded:Connect(function(player: Player)
		setupPlayerConnections(player)
	end)

	playerRemovingConn = Players.PlayerRemoving:Connect(function(player: Player)
		cleanupPlayerConnections(player)
	end)

	localTeamConn = localPlayer:GetPropertyChangedSignal("Team"):Connect(function()
		rebuildTeammateCache()
	end)
end

function MedigunHandler.stopHealing(): ()
	MedigunHandler.stopBeam()
	MedigunHandler.stopAutoRecharge()
end

function MedigunHandler.cleanup(): ()
	hideHealHighlight()
	if healHolder then
		healHolder:Destroy()
		healHolder = nil
	end
	table.clear(healBoxPool)

	MedigunHandler.stopBeam()
	MedigunHandler.stopAutoRecharge()
	MedigunHandler.cleanupRemoteBeams()

	if sharedBeamConnection then
		sharedBeamConnection:Disconnect()
		sharedBeamConnection = nil
	end
	table.clear(activeBeamUpdaters)
	activeBeamCount = 0

	if playerAddedConn then
		playerAddedConn:Disconnect()
		playerAddedConn = nil
	end

	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end

	if localTeamConn then
		localTeamConn:Disconnect()
		localTeamConn = nil
	end

	for player in playerConnections do
		cleanupPlayerConnections(player)
	end

	table.clear(teammateCache)
	table.clear(characterHumanoidCache)
	table.clear(characterToPlayerMap)
	stickyTarget = nil

	if healSound then
		healSound:Stop()
		healSound:Destroy()
		healSound = nil
	end
end

local remoteBeams: {
	[number]: {
		beam: Beam?,
		attachment0: Attachment?,
		attachment1: Attachment?,
		part: Part?,
		lastUpdate: number,
		sound: Sound?,
		cachedBarrel: BasePart?,
		cachedTargetTorso: BasePart?,
	},
} =
	{}

local REMOTE_BEAM_UPDATE_INTERVAL = 1 / 30
local REMOTE_BEAM_KEY_PREFIX = "remote_"

local function getBarrelFromPlayer(healerId: number): BasePart?
	local healer = Players:GetPlayerByUserId(healerId)
	if not healer then
		return nil
	end

	local character = healer.Character
	if not character then
		return nil
	end

	local tool = character:FindFirstChildWhichIsA("Tool")
	if not tool then
		return nil
	end
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return handle
	end
	return nil
end

local function getTargetTorso(targetId: number): BasePart?
	if targetId == 0 then
		local npc = getNPCTeammate()
		if not npc then
			return nil
		end
		return getCharacterTorso(npc)
	end

	local targetPlayer = Players:GetPlayerByUserId(targetId)
	if not targetPlayer then
		return nil
	end

	local character = targetPlayer.Character
	if not character then
		return nil
	end

	return getCharacterTorso(character)
end

local function createRemoteHealSound(barrel: BasePart): Sound?
	if not Cache.getHealSoundsEnabled() then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = Constants.Sounds.Heal
	sound.Volume = 0.5
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 100
	sound.Parent = barrel
	sound:Play()
	return sound
end

local function setupRemoteBeamRay(barrel: BasePart, targetTorsoRemote: BasePart, sound: Sound?, healerId: number, existingBarrelAtt: Attachment?): ()
	local att0 = Instance.new("Attachment")
	att0.Name = "RemoteMediBeamStart"
	if existingBarrelAtt then
		att0.Position = existingBarrelAtt.Position
	end
	att0.Parent = barrel

	local att1 = Instance.new("Attachment")
	att1.Name = "RemoteMediBeamEnd"
	att1.Parent = targetTorsoRemote

	local beam = Instance.new("Beam")
	beam.Name = "RemoteMediBeam"
	beam.Attachment0 = att0
	beam.Attachment1 = att1
	beam.Texture = MEDI_BEAM_TEXTURE
	beam.Color = MEDI_BEAM_COLOR_SEQUENCE
	beam.Transparency = MEDI_BEAM_TRANSPARENCY
	beam.LightEmission = 0.8
	beam.LightInfluence = 0
	beam.Width0 = MEDI_BEAM_WIDTH
	beam.Width1 = MEDI_BEAM_WIDTH
	beam.FaceCamera = true
	beam.Segments = 10
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureSpeed = 2
	beam.TextureLength = 1
	beam.Enabled = true
	beam.Parent = barrel

	remoteBeams[healerId] = {
		beam = beam,
		attachment0 = att0,
		attachment1 = att1,
		lastUpdate = 0,
		sound = sound,
		cachedBarrel = barrel,
		cachedTargetTorso = targetTorsoRemote,
	}
end

local function setupRemotePartBeam(barrel: BasePart, targetTorsoRemote: BasePart, sound: Sound?, healerId: number, existingBarrelAtt: Attachment?): ()
	local barrelPos = if existingBarrelAtt then existingBarrelAtt.WorldPosition else barrel.Position
	local targetPos = targetTorsoRemote.Position
	local midpoint = (barrelPos + targetPos) / 2
	local distance = (targetPos - barrelPos).Magnitude
	local baseWidth = MEDI_PART_WIDTH * Cache.getRaySize()
	local materialEnum = Cache.getRayMaterial()

	local remotePart = Instance.new("Part")
	remotePart.Name = "RemoteMediBeamPart"
	remotePart.Anchored = true
	remotePart.CanCollide = false
	remotePart.CanQuery = false
	remotePart.CanTouch = false
	remotePart.Material = if materialEnum == 1 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	remotePart.Color = MEDI_BEAM_COLOR
	remotePart.Transparency = 1 - Cache.getRayOpacity()
	remotePart.Size = Vector3.new(baseWidth, baseWidth, distance)
	remotePart.CFrame = CFrame.lookAt(midpoint, targetPos)
	remotePart.Parent = workspace

	remoteBeams[healerId] = {
		part = remotePart,
		lastUpdate = 0,
		sound = sound,
		cachedBarrel = barrel,
		cachedTargetTorso = targetTorsoRemote,
	}
end

local function updateRemotePartBeamPosition(data: { [string]: any }, healerId: number, targetId: number, cachedBarrelAtt: Attachment?): Attachment?
	local remoteTorso = data.cachedTargetTorso :: BasePart?
	local remoteBarrel = data.cachedBarrel :: BasePart?

	if not remoteTorso or not remoteTorso.Parent then
		remoteTorso = getTargetTorso(targetId)
		if not remoteTorso then
			MedigunHandler.stopRemoteBeam(healerId)
			return cachedBarrelAtt
		end
		data.cachedTargetTorso = remoteTorso
	end

	if not remoteBarrel or not remoteBarrel.Parent then
		remoteBarrel = getBarrelFromPlayer(healerId)
		if not remoteBarrel then
			MedigunHandler.stopRemoteBeam(healerId)
			return cachedBarrelAtt
		end
		data.cachedBarrel = remoteBarrel
		cachedBarrelAtt = remoteBarrel:FindFirstChild("Barrel") :: Attachment?
	end

	if cachedBarrelAtt and not cachedBarrelAtt.Parent then
		cachedBarrelAtt = remoteBarrel:FindFirstChild("Barrel") :: Attachment?
	end

	local bPos = if cachedBarrelAtt and cachedBarrelAtt.Parent then cachedBarrelAtt.WorldPosition else (remoteBarrel :: BasePart).Position
	local tPos = (remoteTorso :: BasePart).Position
	local mid = (bPos + tPos) / 2
	local dist = (tPos - bPos).Magnitude
	local w = MEDI_PART_WIDTH * Cache.getRaySize();
	(data.part :: Part).Size = Vector3.new(w, w, dist);
	(data.part :: Part).CFrame = CFrame.lookAt(mid, tPos)
	return cachedBarrelAtt
end

function MedigunHandler.renderRemoteBeam(healerId: number, targetId: number): ()
	MedigunHandler.stopRemoteBeam(healerId)

	local barrel = getBarrelFromPlayer(healerId)
	local targetTorsoRemote = getTargetTorso(targetId)
	if not barrel or not targetTorsoRemote then
		return
	end

	local sound = createRemoteHealSound(barrel)
	local existingBarrelAtt = barrel:FindFirstChild("Barrel") :: Attachment?

	if Cache.useBeamRay() then
		setupRemoteBeamRay(barrel, targetTorsoRemote, sound, healerId, existingBarrelAtt)
	else
		setupRemotePartBeam(barrel, targetTorsoRemote, sound, healerId, existingBarrelAtt)
	end

	local beamKey = REMOTE_BEAM_KEY_PREFIX .. tostring(healerId)
	local cachedBarrelAtt = barrel:FindFirstChild("Barrel") :: Attachment?

	addBeamUpdater(beamKey, function()
		local data = remoteBeams[healerId]
		if not data then
			removeBeamUpdater(beamKey)
			return
		end

		local now = os.clock()
		if now - data.lastUpdate < REMOTE_BEAM_UPDATE_INTERVAL then
			return
		end
		data.lastUpdate = now

		if data.attachment1 then
			if not data.attachment1.Parent then
				MedigunHandler.stopRemoteBeam(healerId)
			end
		elseif data.part then
			cachedBarrelAtt = updateRemotePartBeamPosition(data, healerId, targetId, cachedBarrelAtt)
		else
			MedigunHandler.stopRemoteBeam(healerId)
		end
	end)
end

function MedigunHandler.stopRemoteBeam(healerId: number): ()
	local data = remoteBeams[healerId]
	if not data then
		return
	end

	removeBeamUpdater(REMOTE_BEAM_KEY_PREFIX .. tostring(healerId))

	if data.sound then
		data.sound:Stop()
		data.sound:Destroy()
	end
	if data.beam then
		data.beam:Destroy()
	end
	if data.part then
		data.part:Destroy()
	end
	if data.attachment0 then
		data.attachment0:Destroy()
	end
	if data.attachment1 then
		data.attachment1:Destroy()
	end

	remoteBeams[healerId] = nil
end

function MedigunHandler.cleanupRemoteBeams(): ()
	for healerId in remoteBeams do
		MedigunHandler.stopRemoteBeam(healerId)
	end
end

return MedigunHandler
