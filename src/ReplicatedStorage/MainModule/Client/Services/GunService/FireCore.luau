--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local MainModule = script.Parent.Parent.Parent.Parent
local GunConstants = require(script.Parent.Constants)
local FactionUtils = require(MainModule.Shared.Utils.Game.FactionUtils)
local Maps = require(MainModule.Shared.Config.Maps)

local FireCore = {}

local CurrentCamera = workspace.CurrentCamera
local rng = Random.new()

local rayParams = RaycastParams.new()
local aimRayParams = RaycastParams.new()

local player = Players.LocalPlayer

local cachedSpawnLocations: { SpawnLocation } = {}
local spawnCacheBuilt = false

local MAX_AIM_DISTANCE = GunConstants.Raycast.MaxAimDistance

local cachedHead: BasePart? = nil
local aimOverrideCallback: (() -> Vector3?)? = nil

local cachedAimPoint: Vector3? = nil
local cachedAimDistance: number = 0
local cachedBaseDirection: Vector3 = Vector3.zero
local cachedOrigin: Vector3 = Vector3.zero
local cachedCameraAimResult: RaycastResult? = nil
local cachedCameraCFrame: CFrame = CFrame.identity
local aimCacheValid: boolean = false
local filterListReady: boolean = false

local humanoidCache: { [Model]: Humanoid } = {}
local CACHE_CLEAR_INTERVAL = 30
local cacheCleanupThread: thread? = nil

local characterToPlayer: { [Model]: Player } = {}
local playerCharConns: { [Player]: { RBXScriptConnection } } = {}
local playerAddedConn: RBXScriptConnection? = nil
local playerRemovingConn: RBXScriptConnection? = nil

local VALID_BODYPARTS: { [string]: boolean } = {
	Head = true, Torso = true,
	["Left Arm"] = true, ["Right Arm"] = true,
	["Left Leg"] = true, ["Right Leg"] = true,
	HumanoidRootPart = true,
}

local BODY_PART_TO_INDEX: { [string]: number } = {
	Head = 1, Torso = 2,
	["Left Arm"] = 3, ["Right Arm"] = 4,
	["Left Leg"] = 5, ["Right Leg"] = 6,
	HumanoidRootPart = 2,
}

export type HitData = {
	target: Humanoid,
	targetUserId: number,
	damage: number,
	head: boolean,
	pos: Vector3,
	normal: Vector3,
	hitPart: BasePart,
	bodyPartIndex: number,
	localOffset: Vector3,
}

local reusableHit: HitData = {
	target = nil :: any,
	targetUserId = 0,
	damage = 0,
	head = false,
	pos = Vector3.zero,
	normal = Vector3.zero,
	hitPart = nil :: any,
	bodyPartIndex = 2,
	localOffset = Vector3.zero,
}

local function buildSpawnCache(): ()
	if spawnCacheBuilt then return end
	table.clear(cachedSpawnLocations)
	local tagged = CollectionService:GetTagged("SpawnLocation")
	if #tagged > 0 then
		for _, spawn in tagged do
			if spawn:IsA("SpawnLocation") then
				table.insert(cachedSpawnLocations, spawn)
			end
		end
	else
		for _, spawn in workspace:GetDescendants() do
			if spawn:IsA("SpawnLocation") then
				table.insert(cachedSpawnLocations, spawn)
			end
		end
	end
	spawnCacheBuilt = true
end

local function canDamage(attacker: Player, target: Player): boolean
	return FactionUtils.areEnemies(attacker, target)
end

local function cacheCleanupLoop(): ()
	while cacheCleanupThread do
		task.wait(CACHE_CLEAR_INTERVAL)
		if cacheCleanupThread then
			table.clear(humanoidCache)
		end
	end
end

local function connectPlayerCharacters(p: Player): ()
	local conns: { RBXScriptConnection } = {}
	table.insert(conns, p.CharacterAdded:Connect(function(char)
		characterToPlayer[char] = p
	end))
	table.insert(conns, p.CharacterRemoving:Connect(function(char)
		characterToPlayer[char] = nil
	end))
	if p.Character then
		characterToPlayer[p.Character] = p
	end
	playerCharConns[p] = conns
end

local function disconnectPlayerCharacters(p: Player): ()
	if p.Character then
		characterToPlayer[p.Character] = nil
	end
	local conns = playerCharConns[p]
	if not conns then return end
	for _, conn in conns do
		conn:Disconnect()
	end
	playerCharConns[p] = nil
end

local function processHit(result: RaycastResult, effectiveBase: number, effectiveHead: number): HitData?
	local hitPart = result.Instance
	local hitCharacter = hitPart.Parent
	if not hitCharacter or not hitCharacter:IsA("Model") then return nil end

	local humanoid = humanoidCache[hitCharacter]
	if not humanoid then
		humanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
		if not humanoid then return nil end
		humanoidCache[hitCharacter] = humanoid
	end

	local hitPlayer = characterToPlayer[hitCharacter]
	if hitPlayer == player then return nil end
	if hitPlayer and not canDamage(player, hitPlayer) then return nil end
	if humanoid.Health <= 0 then return nil end

	local isHeadshot = hitPart.Name == "Head"
	
	if not hitPlayer and player:GetAttribute("AimChamberIsAiMode") == true then
		isHeadshot = false
	end
	
	local damage = if isHeadshot then effectiveHead else effectiveBase

	local bodyPartIndex = BODY_PART_TO_INDEX[hitPart.Name] or 2
	local offsetPart: BasePart = hitPart
	if hitPart.Name == "HumanoidRootPart" then
		local torso = hitCharacter:FindFirstChild("Torso") :: BasePart?
		if torso then
			offsetPart = torso
		end
	end

	reusableHit.target = humanoid
	reusableHit.targetUserId = if hitPlayer then hitPlayer.UserId else 0
	reusableHit.damage = damage
	reusableHit.head = isHeadshot
	reusableHit.pos = result.Position
	reusableHit.normal = result.Normal
	reusableHit.hitPart = hitPart
	reusableHit.bodyPartIndex = bodyPartIndex
	reusableHit.localOffset = offsetPart.CFrame:PointToObjectSpace(result.Position)
	return reusableHit
end

function FireCore.init(): ()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	rayParams.RespectCanCollide = false

	aimRayParams.FilterType = Enum.RaycastFilterType.Exclude
	aimRayParams.IgnoreWater = true
	aimRayParams.RespectCanCollide = false

	if Maps.getConfig().RaidType == "Phase" then
		rayParams.CollisionGroup = "PlayerCharacter"
		aimRayParams.CollisionGroup = "PlayerCharacter"
	end

	buildSpawnCache()

	if not cacheCleanupThread then
		cacheCleanupThread = task.spawn(cacheCleanupLoop)
	end

	for _, p in Players:GetPlayers() do
		connectPlayerCharacters(p)
	end
	playerAddedConn = Players.PlayerAdded:Connect(connectPlayerCharacters)
	playerRemovingConn = Players.PlayerRemoving:Connect(disconnectPlayerCharacters)
end

function FireCore.cleanup(): ()
	if cacheCleanupThread then
		task.cancel(cacheCleanupThread)
		cacheCleanupThread = nil
	end
	if playerAddedConn then
		playerAddedConn:Disconnect()
		playerAddedConn = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	for p in playerCharConns do
		local conns = playerCharConns[p]
		for _, conn in conns do
			conn:Disconnect()
		end
	end
	table.clear(playerCharConns)
	table.clear(characterToPlayer)
	table.clear(humanoidCache)
end

function FireCore.updateCharacter(char: Model): ()
	cachedHead = char:FindFirstChild("Head") :: BasePart?

	if not cachedHead then
		task.spawn(function()
			local head = char:WaitForChild("Head", 5)
			if head and head:IsA("BasePart") and char == player.Character then
				cachedHead = head :: BasePart
			end
		end)
	end

	local ignoreList: { Instance } = { char }
	local ignore = workspace:FindFirstChild("Ignore")
	if ignore then
		table.insert(ignoreList, ignore)
	end
	local vfxStorage = workspace:FindFirstChild("VFXStorage")
	if vfxStorage then
		table.insert(ignoreList, vfxStorage)
	end

	if not spawnCacheBuilt then
		buildSpawnCache()
	end
	for _, spawn in cachedSpawnLocations do
		table.insert(ignoreList, spawn)
	end

	rayParams.FilterDescendantsInstances = ignoreList
	aimRayParams.FilterDescendantsInstances = ignoreList
	filterListReady = true
end

function FireCore.clearCharacter(): ()
	cachedHead = nil
	filterListReady = false
	rayParams.FilterDescendantsInstances = {}
	aimRayParams.FilterDescendantsInstances = {}
end

function FireCore.clearHumanoidCache(): ()
	table.clear(humanoidCache)
end

function FireCore.setAimOverride(callback: () -> Vector3?): ()
	aimOverrideCallback = callback
end

function FireCore.clearAimOverride(): ()
	aimOverrideCallback = nil
end

function FireCore.prepareAim(): boolean
	cachedAimPoint = nil
	cachedAimDistance = 0
	cachedBaseDirection = Vector3.zero
	cachedOrigin = Vector3.zero
	cachedCameraAimResult = nil
	aimCacheValid = false

	local head = cachedHead
	if not head or not head.Parent then return false end

	local character = player.Character
	if not character then return false end

	if not filterListReady then
		FireCore.updateCharacter(character)
	end

	local camera = CurrentCamera
	if not camera then return false end

	cachedCameraCFrame = camera.CFrame
	local origin = head.Position

	if aimOverrideCallback then
		local targetPos = aimOverrideCallback()
		if targetPos then
			local delta = targetPos - origin
			cachedAimPoint = targetPos
			cachedAimDistance = delta.Magnitude
			cachedBaseDirection = delta.Unit
			cachedOrigin = origin
			aimCacheValid = true
			return true
		end
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local aimRay = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local aimDirection = aimRay.Direction * MAX_AIM_DISTANCE
	local cameraAimResult = workspace:Raycast(aimRay.Origin, aimDirection, aimRayParams)
	cachedCameraAimResult = cameraAimResult

	local aimPoint = if cameraAimResult then cameraAimResult.Position else aimRay.Origin + aimDirection
	local delta = aimPoint - origin
	cachedAimPoint = aimPoint
	cachedAimDistance = delta.Magnitude
	cachedBaseDirection = delta.Unit
	cachedOrigin = origin
	aimCacheValid = true
	return true
end

function FireCore.getAimDistance(): number
	if aimCacheValid then return cachedAimDistance end
	FireCore.prepareAim()
	return cachedAimDistance
end

function FireCore.cast(
	range: number,
	spread: number?,
	effectiveBase: number,
	effectiveHead: number
): (HitData?, Vector3, Vector3, RaycastResult?, boolean)
	local head = cachedHead
	if not head or not head.Parent then
		return nil, Vector3.zero, Vector3.zero, nil, false
	end

	local character = player.Character
	if not character then
		return nil, Vector3.zero, Vector3.zero, nil, false
	end

	if not filterListReady then
		FireCore.updateCharacter(character)
	end

	local camera = CurrentCamera
	if not camera then
		return nil, Vector3.zero, Vector3.zero, nil, false
	end

	local origin = head.Position

	if aimOverrideCallback then
		local targetPos = aimOverrideCallback()
		if targetPos then
			local direction = (targetPos - origin).Unit * range
			local result = workspace:Raycast(origin, direction, rayParams)
			local endPos = if result then result.Position else (origin + direction)
			if not result then return nil, origin, endPos, nil, false end
			if not VALID_BODYPARTS[result.Instance.Name] then return nil, origin, endPos, result, false end
			local hitData = processHit(result, effectiveBase, effectiveHead)
			return hitData, origin, endPos, nil, true
		end
	end

	local cameraAimResult: RaycastResult?
	local cameraAimPoint: Vector3

	if aimCacheValid then
		cameraAimResult = cachedCameraAimResult
		cameraAimPoint = cachedAimPoint :: Vector3
	else
		local mouseLocation = UserInputService:GetMouseLocation()
		local aimRay = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
		local aimDirection = aimRay.Direction * MAX_AIM_DISTANCE
		cameraAimResult = workspace:Raycast(aimRay.Origin, aimDirection, aimRayParams)
		cameraAimPoint = if cameraAimResult then cameraAimResult.Position else (aimRay.Origin + aimDirection)
	end

	if cameraAimResult then
		local hitModel = cameraAimResult.Instance:FindFirstAncestorOfClass("Model")
		if hitModel then
			local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				local baseDir = cameraAimPoint - origin
				local direction: Vector3
				if spread and spread > 0 then
					local camCF = cachedCameraCFrame
					local right = camCF.RightVector * rng:NextNumber(-spread, spread)
					local up = camCF.UpVector * rng:NextNumber(-spread, spread)
					direction = (baseDir.Unit + right + up).Unit * range
				else
					direction = baseDir.Unit * range
				end

				local result = workspace:Raycast(origin, direction, rayParams)
				local endPos = if result then result.Position else (origin + direction)

				if not result then
					if not VALID_BODYPARTS[cameraAimResult.Instance.Name] then
						return nil, origin, cameraAimPoint, cameraAimResult, false
					end
					local hitData = processHit(cameraAimResult, effectiveBase, effectiveHead)
					return hitData, origin, cameraAimPoint, nil, true
				end

				if not VALID_BODYPARTS[result.Instance.Name] then
					return nil, origin, endPos, result, false
				end
				local hitData = processHit(result, effectiveBase, effectiveHead)
				return hitData, origin, endPos, nil, true
			end
		end
	end

	local baseDir = cameraAimPoint - origin
	local direction: Vector3
	if spread and spread > 0 then
		local camCF = cachedCameraCFrame
		local right = camCF.RightVector * rng:NextNumber(-spread, spread)
		local up = camCF.UpVector * rng:NextNumber(-spread, spread)
		direction = (baseDir.Unit + right + up).Unit * range
	else
		direction = baseDir.Unit * range
	end

	local result = workspace:Raycast(origin, direction, rayParams)
	local endPos = if result then result.Position else (origin + direction)
	if not result then return nil, origin, endPos, nil, false end

	if not VALID_BODYPARTS[result.Instance.Name] then
		return nil, origin, endPos, result, false
	end
	local hitData = processHit(result, effectiveBase, effectiveHead)
	return hitData, origin, endPos, nil, true
end

function FireCore.castPellet(
	range: number,
	spreadRight: number,
	spreadUp: number,
	effectiveBase: number,
	effectiveHead: number
): (HitData?, Vector3, Vector3, RaycastResult?, boolean)
	if not aimCacheValid or not cachedAimPoint then
		return nil, Vector3.zero, Vector3.zero, nil, false
	end

	local head = cachedHead
	if not head or not head.Parent then
		return nil, Vector3.zero, Vector3.zero, nil, false
	end

	local origin = cachedOrigin
	local camCF = cachedCameraCFrame
	local direction = (cachedBaseDirection + camCF.RightVector * spreadRight + camCF.UpVector * spreadUp).Unit * range

	local result = workspace:Raycast(origin, direction, rayParams)
	local endPos = if result then result.Position else (origin + direction)
	if not result then return nil, origin, endPos, nil, false end

	if not VALID_BODYPARTS[result.Instance.Name] then
		return nil, origin, endPos, result, false
	end
	local hitData = processHit(result, effectiveBase, effectiveHead)
	return hitData, origin, endPos, nil, true
end

function FireCore.checkBarrelHit(
	barrelPos: Vector3,
	endPos: Vector3,
	effectiveBase: number,
	effectiveHead: number
): (HitData?, Vector3)
	local direction = endPos - barrelPos
	local result = workspace:Raycast(barrelPos, direction, rayParams)
	if not result then return nil, endPos end
	if not VALID_BODYPARTS[result.Instance.Name] then return nil, endPos end
	local hitData = processHit(result, effectiveBase, effectiveHead)
	if hitData then return hitData, result.Position end
	return nil, endPos
end

function FireCore.getBarrelPosition(tool: Tool): Vector3?
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then return nil end
	local handleBarrel = handle:FindFirstChild("Barrel") :: Attachment?
	if handleBarrel then return handleBarrel.WorldPosition end
	return nil
end

return FireCore
