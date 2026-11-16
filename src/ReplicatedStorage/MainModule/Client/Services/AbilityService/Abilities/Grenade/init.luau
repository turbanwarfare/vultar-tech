--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Core = require(MainModule.Shared.Network.Core)
local AbilityConfig = require(MainModule.Shared.Config.AbilityConfig)
local ExplosionVFX = require(script.ExplosionVFX)

local Definition = AbilityConfig.Abilities.Grenade
local Stats = Definition.Stats

type ActiveGrenade = {
	visual: BasePart,
	frames: { Vector3 },
	startTime: number,
	lastPosition: Vector3,
	spin: number,
	beeps: number,
	flashing: boolean,
}

local SPIN_PER_STUD = 0.6
local FLASH_TIME = 0.15
local GRENADE_COLOR = Color3.fromRGB(45, 45, 50)
local FLASH_COLOR = Color3.fromRGB(255, 40, 40)
local INDICATOR_SIZE = 62

local Grenade = {}

local throwAnimation: Animation? = nil
local throwTrack: AnimationTrack? = nil
local activeGrenades: { [number]: ActiveGrenade } = {}
local connections: { RBXScriptConnection } = {}

local function playSoundAt(soundId: string, parent: Instance, volume: number): ()
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.Parent = parent
	sound:Play()
	task.delay(6, sound.Destroy, sound)
end

local function createGrenadePart(): BasePart
	local part = Instance.new("Part")
	part.Name = "Grenade"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * Stats.RADIUS * 2
	part.Color = GRENADE_COLOR
	part.Material = Enum.Material.Metal
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 60, 60)
	light.Range = 4
	light.Brightness = 2
	light.Parent = part

	return part
end

local function createGrenadeVisual(anchored: boolean): BasePart
	local part = createGrenadePart()
	part.Anchored = anchored
	part.Massless = true
	return part
end

local function getAimTarget(character: Model): Vector3?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end

	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true

	local reach = Stats.MAX_RANGE * 3
	local result = workspace:Raycast(ray.Origin, ray.Direction * reach, params)
	return if result then result.Position else ray.Origin + ray.Direction * reach
end

local function updateGrenades(): ()
	local now = os.clock()
	for _, grenade in activeGrenades do
		local frames = grenade.frames
		local elapsed = now - grenade.startTime
		local beat = elapsed // 1
		if beat > grenade.beeps then
			grenade.beeps = beat
			playSoundAt(Stats.BEEP_SOUND, grenade.visual, 1)
		end
		local flashing = elapsed % 1 < FLASH_TIME
		if flashing ~= grenade.flashing then
			grenade.flashing = flashing
			grenade.visual.Material = if flashing then Enum.Material.Neon else Enum.Material.Metal
			grenade.visual.Color = if flashing then FLASH_COLOR else GRENADE_COLOR
		end

		local progress = elapsed / Stats.FRAME_TIME + 1
		local index = math.clamp(math.floor(progress), 1, #frames)
		local nextIndex = math.min(index + 1, #frames)
		local alpha = math.clamp(progress - index, 0, 1)
		local position = frames[index]:Lerp(frames[nextIndex], alpha)
		grenade.spin += (position - grenade.lastPosition).Magnitude * SPIN_PER_STUD
		grenade.lastPosition = position
		grenade.visual:PivotTo(CFrame.new(position) * CFrame.Angles(grenade.spin, grenade.spin * 0.6, 0))
	end
end

local function onThrown(throwId: number, _throwerUserId: number, frames: { Vector3 }): ()
	if typeof(frames) ~= "table" or #frames == 0 then
		return
	end

	local visual = createGrenadeVisual(true)
	visual:PivotTo(CFrame.new(frames[1]))

	local indicator = Instance.new("BillboardGui")
	indicator.Name = "Indicator"
	indicator.Size = UDim2.fromOffset(INDICATOR_SIZE, INDICATOR_SIZE)
	indicator.StudsOffset = Vector3.new(0, 1.75, 0)
	indicator.MaxDistance = Stats.INDICATOR_DISTANCE
	indicator.Parent = visual

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Image = Stats.INDICATOR_IMAGE
	icon.ImageColor3 = Color3.fromRGB(255, 0, 0)
	icon.Parent = indicator

	visual.Parent = workspace
	activeGrenades[throwId] = {
		visual = visual,
		frames = frames,
		startTime = os.clock(),
		lastPosition = frames[1],
		spin = 0,
		beeps = -1,
		flashing = false,
	}
	task.delay(#frames * Stats.FRAME_TIME + 2, visual.Destroy, visual)
end

local function onExploded(throwId: number, position: Vector3): ()
	local grenade = activeGrenades[throwId]
	activeGrenades[throwId] = nil
	if grenade then
		grenade.visual:Destroy()
	end

	ExplosionVFX.play(position)
end

function Grenade.init(): ()
	local animation = Instance.new("Animation")
	animation.AnimationId = Stats.THROW_ANIMATION
	throwAnimation = animation
end

function Grenade.start(): ()
	table.insert(connections, Core.getOrCreateRemoteEvent("Grenade_Thrown").OnClientEvent:Connect(onThrown))
	table.insert(connections, Core.getOrCreateRemoteEvent("Grenade_Exploded").OnClientEvent:Connect(onExploded))
	table.insert(connections, RunService.RenderStepped:Connect(updateGrenades))
end

function Grenade.getPayload(character: Model): Vector3?
	return getAimTarget(character)
end

function Grenade.onUsed(character: Model, humanoid: Humanoid): ()
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator and throwAnimation then
		if not throwTrack then
			local ok, track = pcall(function()
				return animator:LoadAnimation(throwAnimation :: Animation)
			end)
			throwTrack = if ok then track else nil
		end
		if throwTrack then
			throwTrack.Priority = Enum.AnimationPriority.Action
			throwTrack:Play()
		end
	end

	local arm = character:FindFirstChild("Right Arm") :: BasePart?
	if not arm then
		return
	end

	local prop = createGrenadeVisual(false)
	prop:PivotTo(arm.CFrame * CFrame.new(0, -1, 0))
	local propParts: { Instance } = prop:GetDescendants()
	table.insert(propParts, prop)
	for _, part in propParts do
		if part:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = arm
			weld.Part1 = part
			weld.Parent = part
		end
	end
	prop.Parent = character
	task.delay(Definition.Windup, prop.Destroy, prop)

	task.delay(0.1, function()
		if arm.Parent then
			playSoundAt(Stats.PIN_SOUND, arm, 0.8)
		end
	end)
end

function Grenade.onCharacterAdded(): ()
	throwTrack = nil
end

function Grenade.cleanup(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for _, grenade in activeGrenades do
		grenade.visual:Destroy()
	end
	table.clear(activeGrenades)
	throwTrack = nil
end

return Grenade
