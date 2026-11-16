--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local Constants = require(script.Parent.Constants)
local Cache = require(script.Parent.Cache)
local VFXPool = require(script.Parent.VFXPool)
local FactionUtils = require(MainModule.Shared.Utils.Game.FactionUtils)

local VFXRenderer = {}

local RAY_COLOR = Constants.Colors.Ray
local RAY_COLOR_HOSTILE = Constants.Colors.RayHostile
local RAY_COLOR_INNER = Constants.Colors.RayInner

local RAY_COLOR_SEQUENCE = ColorSequence.new(RAY_COLOR)
local RAY_COLOR_HOSTILE_SEQUENCE = ColorSequence.new(RAY_COLOR_HOSTILE)
local RAY_COLOR_INNER_SEQUENCE = ColorSequence.new(RAY_COLOR_INNER)
local BEAM_GLOW_TRANSPARENCY_SEQUENCE = NumberSequence.new(Constants.Ray.BeamGlowTransparency)
local FULLY_OPAQUE_TRANSPARENCY = NumberSequence.new(0)

local LocalPlayer = Players.LocalPlayer

local cachedLocalIsDefender: boolean? = nil
local shooterFactionCache: { [number]: boolean? } = {}
local playerTeamConnections: { [Player]: RBXScriptConnection } = {}
local initConnections: { RBXScriptConnection } = {}
local cachedBarrelEmitters: { [Attachment]: { ParticleEmitter } } = {}

local vfxAnchor: Part = nil :: any

local function computeIsDefender(targetPlayer: Player): boolean?
	local team = targetPlayer.Team
	if not team then
		return nil
	end
	if FactionUtils.NEUTRAL_TEAMS[team.Name] then
		return nil
	end
	return FactionUtils.DEFENDER_TEAMS[team.Name] == true
end

local function updateLocalCache(): ()
	cachedLocalIsDefender = computeIsDefender(LocalPlayer)
end

local function cachePlayerFaction(player: Player): ()
	local isDefender = computeIsDefender(player)
	if isDefender ~= nil then
		shooterFactionCache[player.UserId] = isDefender
	else
		shooterFactionCache[player.UserId] = nil
	end
end

local function watchPlayerTeam(player: Player): ()
	if player == LocalPlayer then
		return
	end
	cachePlayerFaction(player)
	playerTeamConnections[player] = player:GetPropertyChangedSignal("Team"):Connect(function()
		cachePlayerFaction(player)
	end)
end

local function watchPlayerCharacter(player: Player): ()
	player.CharacterRemoving:Connect(function(oldChar)
		for attachment in cachedBarrelEmitters do
			if attachment:IsDescendantOf(oldChar) then
				cachedBarrelEmitters[attachment] = nil
			end
		end
	end)
end

local function getRayColor(shooterId: number?): Color3
	if shooterId == -1 then
		return Color3.fromRGB(0, 100, 255)
	end
	if not shooterId or shooterId == 0 then
		if cachedLocalIsDefender == nil then
			return RAY_COLOR
		end
		return if cachedLocalIsDefender then RAY_COLOR else RAY_COLOR_HOSTILE
	end

	local cached = shooterFactionCache[shooterId]
	if cached ~= nil then
		return if cached then RAY_COLOR else RAY_COLOR_HOSTILE
	end

	local shooter = Players:GetPlayerByUserId(shooterId)
	if not shooter then
		return RAY_COLOR
	end

	local shooterIsDefender = computeIsDefender(shooter)
	if shooterIsDefender == nil then
		return RAY_COLOR
	end

	shooterFactionCache[shooterId] = shooterIsDefender
	return if shooterIsDefender then RAY_COLOR else RAY_COLOR_HOSTILE
end

local MUZZLE_EMIT_COUNTS = {
	Eff1 = 8,
	Eff2 = 5,
	Eff3 = 8,
	Sparks = 6,
	Smoke = 3,
}

local MUZZLE_FLASH_CONFIGS = {
	{
		name = "Eff1",
		texture = "http://www.roblox.com/asset/?id=257430870",
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 0, 0)),
			ColorSequenceKeypoint.new(0.432526, Color3.new(1, 0.278431, 0.278431)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 0, 0)),
		}),
		size = NumberSequence.new(0.2),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		}),
		lifetime = NumberRange.new(0.05),
		speed = NumberRange.new(10),
		spreadAngle = Vector2.zero,
		lightEmission = 1,
		lightInfluence = 0,
		emissionDirection = Enum.NormalId.Front,
		rotSpeed = NumberRange.new(0, 360),
		rotation = NumberRange.new(0, 360),
		drag = 0,
		acceleration = Vector3.zero,
		zOffset = 0,
		lockedToPart = true,
		orientation = Enum.ParticleOrientation.FacingCamera,
	},
	{
		name = "Eff2",
		texture = "rbxassetid://13974905557",
		color = ColorSequence.new(Color3.new(1, 0, 0.0156863)),
		size = NumberSequence.new(0.4),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		}),
		lifetime = NumberRange.new(0.04),
		speed = NumberRange.new(26),
		spreadAngle = Vector2.new(10, 25),
		lightEmission = 0,
		lightInfluence = 1,
		emissionDirection = Enum.NormalId.Front,
		rotSpeed = NumberRange.new(0),
		rotation = NumberRange.new(-90),
		drag = 5,
		acceleration = Vector3.zero,
		zOffset = 0,
		lockedToPart = true,
		orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
	},
	{
		name = "Eff3",
		texture = "http://www.roblox.com/asset/?id=257430870",
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 0, 0)),
			ColorSequenceKeypoint.new(0.427336, Color3.new(1, 0.278431, 0.278431)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 0, 0)),
		}),
		size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.737844, 0.125),
			NumberSequenceKeypoint.new(1, 0.1),
		}),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		}),
		lifetime = NumberRange.new(0.08),
		speed = NumberRange.new(10),
		spreadAngle = Vector2.zero,
		lightEmission = 1,
		lightInfluence = 0,
		emissionDirection = Enum.NormalId.Front,
		rotSpeed = NumberRange.new(0, 360),
		rotation = NumberRange.new(0, 360),
		drag = 0,
		acceleration = Vector3.zero,
		zOffset = 0,
		lockedToPart = true,
		orientation = Enum.ParticleOrientation.FacingCamera,
	},
	{
		name = "Sparks",
		texture = "rbxassetid://13974731802",
		color = ColorSequence.new(Color3.new(1, 0, 0)),
		size = NumberSequence.new(0.035),
		transparency = NumberSequence.new(0),
		lifetime = NumberRange.new(0.015),
		speed = NumberRange.new(64),
		spreadAngle = Vector2.new(25, 25),
		lightEmission = 0.8,
		lightInfluence = 0,
		emissionDirection = Enum.NormalId.Front,
		rotSpeed = NumberRange.new(0),
		rotation = NumberRange.new(90),
		drag = 0,
		acceleration = Vector3.zero,
		zOffset = 1,
		lockedToPart = true,
		orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
	},
	{
		name = "Smoke",
		texture = "rbxasset://textures/particles/smoke_main.dds",
		color = ColorSequence.new(Color3.new(1, 1, 1)),
		size = NumberSequence.new(0.2),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.95),
			NumberSequenceKeypoint.new(1, 1),
		}),
		lifetime = NumberRange.new(0.2),
		speed = NumberRange.new(5, 7),
		spreadAngle = Vector2.new(25, 25),
		lightEmission = 0,
		lightInfluence = 1,
		emissionDirection = Enum.NormalId.Front,
		rotSpeed = NumberRange.new(-200, 200),
		rotation = NumberRange.new(0, 360),
		drag = 0,
		acceleration = Vector3.new(0, 2, 0),
		zOffset = 0,
		lockedToPart = false,
		orientation = Enum.ParticleOrientation.FacingCamera,
	},
}

local function createMuzzleFlashEmitter(config: any, parent: Attachment): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = config.name
	emitter.Texture = config.texture
	emitter.Color = config.color
	emitter.Size = config.size
	emitter.Transparency = config.transparency or FULLY_OPAQUE_TRANSPARENCY
	emitter.Lifetime = config.lifetime
	emitter.Speed = config.speed
	emitter.SpreadAngle = config.spreadAngle
	emitter.LightEmission = config.lightEmission
	emitter.LightInfluence = config.lightInfluence
	emitter.EmissionDirection = config.emissionDirection
	emitter.RotSpeed = config.rotSpeed
	emitter.Rotation = config.rotation
	emitter.Drag = config.drag
	emitter.Acceleration = config.acceleration
	emitter.Brightness = 1
	emitter.ZOffset = config.zOffset or 0
	emitter.LockedToPart = config.lockedToPart or false
	emitter.Orientation = config.orientation or Enum.ParticleOrientation.FacingCamera
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Parent = parent
	return emitter
end

local function createMuzzleFlashEmitters(barrelAttachment: Attachment): { ParticleEmitter }
	local emitters: { ParticleEmitter } = {}
	for _, config in MUZZLE_FLASH_CONFIGS do
		local emitter = createMuzzleFlashEmitter(config, barrelAttachment)
		table.insert(emitters, emitter)
	end
	return emitters
end

local cachedBarrelAttachment: Attachment? = nil
local cachedBarrelAttachmentPart: BasePart? = nil

local function findOrCreateBarrelAttachment(barrelPart: BasePart): Attachment?
	if cachedBarrelAttachmentPart == barrelPart and cachedBarrelAttachment and cachedBarrelAttachment.Parent then
		return cachedBarrelAttachment
	end

	local barrel = barrelPart:FindFirstChild("Barrel")
	if barrel and barrel:IsA("Attachment") then
		cachedBarrelAttachment = barrel
		cachedBarrelAttachmentPart = barrelPart
		return barrel
	end

	cachedBarrelAttachment = nil
	cachedBarrelAttachmentPart = nil
	return nil
end

local function getBarrelEmitters(barrelAttachment: Attachment): { ParticleEmitter }?
	local cached = cachedBarrelEmitters[barrelAttachment]
	if cached then
		if barrelAttachment.Parent then
			return cached
		else
			cachedBarrelEmitters[barrelAttachment] = nil
		end
	end

	if not barrelAttachment.Parent then
		return nil
	end

	local emitters = createMuzzleFlashEmitters(barrelAttachment)
	cachedBarrelEmitters[barrelAttachment] = emitters
	return emitters
end

function VFXRenderer.init(): ()
	VFXPool.init()

	updateLocalCache()
	table.insert(initConnections, LocalPlayer:GetPropertyChangedSignal("Team"):Connect(updateLocalCache))

	for _, player in Players:GetPlayers() do
		watchPlayerTeam(player)
		watchPlayerCharacter(player)
	end

	table.insert(
		initConnections,
		Players.PlayerAdded:Connect(function(player)
			watchPlayerTeam(player)
			watchPlayerCharacter(player)
		end)
	)

	table.insert(
		initConnections,
		Players.PlayerRemoving:Connect(function(player)
			shooterFactionCache[player.UserId] = nil
			local conn = playerTeamConnections[player]
			if conn then
				conn:Disconnect()
				playerTeamConnections[player] = nil
			end

			local char = player.Character
			if char then
				for attachment in cachedBarrelEmitters do
					if attachment:IsDescendantOf(char) then
						cachedBarrelEmitters[attachment] = nil
					end
				end
			end
		end)
	)

	vfxAnchor = Instance.new("Part")
	vfxAnchor.Name = "VFXAnchor"
	vfxAnchor.Anchored = true
	vfxAnchor.CanCollide = false
	vfxAnchor.CanQuery = false
	vfxAnchor.CanTouch = false
	vfxAnchor.Transparency = 1
	vfxAnchor.Size = Vector3.one
	vfxAnchor.Position = Vector3.zero
	vfxAnchor.Parent = workspace
end

function VFXRenderer.renderMuzzleFlash(barrelPart: BasePart?): ()
	if not Cache.getMuzzleFlashEnabled() then
		return
	end

	if not barrelPart or not barrelPart.Parent then
		return
	end

	local barrelAttachment = findOrCreateBarrelAttachment(barrelPart)
	if not barrelAttachment then
		return
	end

	local barrelTip = barrelAttachment.WorldPosition
	local toBarrelTip = barrelTip - barrelPart.Position
	if toBarrelTip:Dot(toBarrelTip) > 0.0001 then
		barrelAttachment.WorldCFrame = CFrame.new(barrelTip, barrelTip + toBarrelTip)
	end

	local emitters = getBarrelEmitters(barrelAttachment)
	if not emitters then
		return
	end

	for _, emitter in emitters do
		if emitter.Parent then
			local count = MUZZLE_EMIT_COUNTS[emitter.Name] or 10
			emitter:Emit(count)
		end
	end
end

function VFXRenderer.renderGPRRay(origin: Vector3, target: Vector3, shooterId: number?): ()
	local rayColor = getRayColor(shooterId)
	local distance = (target - origin).Magnitude
	local cframe = CFrame.lookAt(origin, target)

	local laser1 = Instance.new("Part")
	laser1.Name = "Bullet"
	laser1.FormFactor = Enum.FormFactor.Symmetric
	laser1.Color = rayColor
	laser1.Anchored = true
	laser1.CanCollide = false
	laser1.Locked = true
	laser1.Size = Vector3.one
	laser1.TopSurface = Enum.SurfaceType.Smooth
	laser1.BottomSurface = Enum.SurfaceType.Smooth

	local mesh1 = Instance.new("SpecialMesh")
	mesh1.MeshType = Enum.MeshType.Brick
	mesh1.Name = "Mesh"
	mesh1.Scale = Vector3.new(0.2, 0.2, distance * 0.5)
	mesh1.Parent = laser1

	local laser2 = laser1:Clone()
	
	laser1.CFrame = cframe * CFrame.new(0, 0, -distance * 0.75)
	laser2.CFrame = cframe * CFrame.new(0, 0, -distance * 0.25)
	
	laser1.Parent = vfxAnchor or workspace
	laser2.Parent = vfxAnchor or workspace
	
	task.delay(0.03, function()
		if laser2 then
			laser2:Destroy()
		end
	end)
	
	task.delay(0.06, function()
		if laser1 then
			laser1:Destroy()
		end
	end)
end

function VFXRenderer.renderRay(origin: Vector3, target: Vector3, barrelPart: BasePart?, shooterId: number?, gunName: string?): ()
	local isLocal = not shooterId or shooterId == 0 or shooterId == LocalPlayer.UserId

	if isLocal then
		VFXRenderer.renderMuzzleFlash(barrelPart)
	end

	if Cache.getHideClientRays() and isLocal then
		return
	end

	if gunName == "GPR" then
		VFXRenderer.renderGPRRay(origin, target, shooterId)
		return
	end

	if Cache.useBeamRay() then
		if isLocal then
			VFXRenderer.renderBeamRay(origin, target, barrelPart, shooterId)
		else
			VFXRenderer.renderBeamRaySimple(origin, target, shooterId)
		end
	else
		VFXRenderer.renderPartRay(origin, target, shooterId)
	end
end

function VFXRenderer.renderBeamRay(origin: Vector3, target: Vector3, barrelPart: BasePart?, shooterId: number?): ()
	local rayDuration = Cache.getRayDuration()
	local rayColor = getRayColor(shooterId)
	local colorSequence = if rayColor == RAY_COLOR then RAY_COLOR_SEQUENCE elseif rayColor == RAY_COLOR_HOSTILE then RAY_COLOR_HOSTILE_SEQUENCE else ColorSequence.new(rayColor)

	local beamSet = VFXPool.acquireBeamSet()

	local stickToBarrel = Cache.getRayStickToBarrel() and barrelPart and barrelPart.Parent
	if stickToBarrel then
		local barrelAttachment = findOrCreateBarrelAttachment(barrelPart)
		if barrelAttachment then
			beamSet.att0.CFrame = barrelAttachment.CFrame
		else
			beamSet.att0.WorldPosition = origin
		end
		beamSet.att0.Parent = barrelPart
	else
		beamSet.att0.WorldPosition = origin
	end

	beamSet.att1.WorldPosition = target

	beamSet.glowBeam.Color = colorSequence
	beamSet.glowBeam.Transparency = BEAM_GLOW_TRANSPARENCY_SEQUENCE
	beamSet.glowBeam.Width0 = Constants.Ray.BeamGlowWidth
	beamSet.glowBeam.Width1 = Constants.Ray.BeamGlowWidth
	beamSet.glowBeam.Enabled = true

	beamSet.outerBeam.Color = colorSequence
	beamSet.outerBeam.Transparency = FULLY_OPAQUE_TRANSPARENCY
	beamSet.outerBeam.Width0 = Constants.Ray.BeamOuterWidth
	beamSet.outerBeam.Width1 = Constants.Ray.BeamOuterWidth
	beamSet.outerBeam.Enabled = true

	beamSet.innerBeam.Color = RAY_COLOR_INNER_SEQUENCE
	beamSet.innerBeam.Transparency = FULLY_OPAQUE_TRANSPARENCY
	beamSet.innerBeam.Width0 = Constants.Ray.BeamInnerWidth
	beamSet.innerBeam.Width1 = Constants.Ray.BeamInnerWidth
	beamSet.innerBeam.Enabled = true

	VFXPool.scheduleBeamSet(beamSet, rayDuration)
end

function VFXRenderer.renderBeamRaySimple(origin: Vector3, target: Vector3, shooterId: number?): ()
	local rayDuration = Cache.getRayDuration()
	local rayColor = getRayColor(shooterId)
	local colorSequence = if rayColor == RAY_COLOR then RAY_COLOR_SEQUENCE elseif rayColor == RAY_COLOR_HOSTILE then RAY_COLOR_HOSTILE_SEQUENCE else ColorSequence.new(rayColor)

	local beamSet = VFXPool.acquireBeamSet()

	beamSet.att0.WorldPosition = origin
	beamSet.att1.WorldPosition = target

	beamSet.outerBeam.Color = colorSequence
	beamSet.outerBeam.Transparency = FULLY_OPAQUE_TRANSPARENCY
	beamSet.outerBeam.Width0 = Constants.Ray.BeamOuterWidth
	beamSet.outerBeam.Width1 = Constants.Ray.BeamOuterWidth
	beamSet.outerBeam.Enabled = true

	beamSet.innerBeam.Color = RAY_COLOR_INNER_SEQUENCE
	beamSet.innerBeam.Transparency = FULLY_OPAQUE_TRANSPARENCY
	beamSet.innerBeam.Width0 = Constants.Ray.BeamInnerWidth
	beamSet.innerBeam.Width1 = Constants.Ray.BeamInnerWidth
	beamSet.innerBeam.Enabled = true

	VFXPool.scheduleBeamSet(beamSet, rayDuration)
end

function VFXRenderer.renderPartRay(origin: Vector3, target: Vector3, shooterId: number?): ()
	local rayDuration = Cache.getRayDuration()
	local rayColor = getRayColor(shooterId)
	local materialEnum = Cache.getRayMaterial()
	local sizeMultiplier = Cache.getRaySize()
	local opacity = Cache.getRayOpacity()

	local distance = (target - origin).Magnitude
	local midpoint = (origin + target) / 2
	local baseWidth = Constants.Ray.PartWidth * sizeMultiplier

	local part = VFXPool.acquirePartRay()
	part.Material = if materialEnum == 1 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Color = rayColor
	part.Transparency = 1 - opacity
	part.Size = Vector3.new(baseWidth, baseWidth, distance)
	part.CFrame = CFrame.lookAt(midpoint, target)
	part.Parent = vfxAnchor or workspace

	VFXPool.schedulePartRay(part, rayDuration)
end

function VFXRenderer.clearActiveRays(): () end

function VFXRenderer.cleanup(): ()
	table.clear(cachedBarrelEmitters)
	table.clear(shooterFactionCache)

	for _, conn in initConnections do
		conn:Disconnect()
	end
	table.clear(initConnections)

	for _, conn in playerTeamConnections do
		conn:Disconnect()
	end
	table.clear(playerTeamConnections)

	VFXPool.cleanup()

	if vfxAnchor then
		vfxAnchor:Destroy()
		vfxAnchor = nil :: any
	end
end

return VFXRenderer
