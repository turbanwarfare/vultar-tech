--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Core = require(MainModule.Shared.Network.Core)
local AbilityConfig = require(MainModule.Shared.Config.AbilityConfig)
local GunStats = require(MainModule.Shared.Config.GunStats)
local DamageProcessor = require(MainModule.Server.Services.GunService.DamageProcessor)
local Physics = require(script.Physics)

local Stats = AbilityConfig.Abilities.Grenade.Stats
local GRENADE_INDEX = GunStats.GUN_NAME_TO_INDEX.Grenade

local Grenade = {}

local nextThrowId = 0
local rng = Random.new()
local thrownRemote: RemoteEvent? = nil
local explodedRemote: RemoteEvent? = nil

local function getAliveCharacter(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or humanoid.Health <= 0 or not root then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function canReach(center: Vector3, character: Model, params: RaycastParams): boolean
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and not Physics.isBlocked(center, part.Position, params) then
			return true
		end
	end
	return false
end

local function explode(thrower: Player, throwId: number, position: Vector3): ()
	if explodedRemote then
		explodedRemote:FireAllClients(throwId, position)
	end

	local center = position + Vector3.new(0, 1, 0)
	local players = Players:GetPlayers()
	local characters = table.create(#players)
	for _, target in players do
		if target.Character then
			table.insert(characters, target.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characters
	params.RespectCanCollide = true

	for _, target in players do
		local character, humanoid, root = getAliveCharacter(target)
		if character and humanoid and root then
			local damage = Physics.damageAt((center - root.Position).Magnitude)
			if damage > 0 and canReach(center, character, params) then
				if target == thrower then
					humanoid:TakeDamage(damage)
				else
					DamageProcessor.applyExplosionDamage(thrower, target.UserId, damage, GRENADE_INDEX)
				end
			end
		end
	end
end

function Grenade.init(): ()
	thrownRemote = Core.getOrCreateRemoteEvent("Grenade_Thrown")
	explodedRemote = Core.getOrCreateRemoteEvent("Grenade_Exploded")
end

function Grenade.validate(target: any): boolean
	if typeof(target) ~= "Vector3" then
		return false
	end
	local magnitude = target.Magnitude
	return magnitude == magnitude and magnitude ~= math.huge
end

function Grenade.use(player: Player, character: Model, target: Vector3): ()
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local arm = character:FindFirstChild("Right Arm") :: BasePart?
	local origin = if arm then (arm.CFrame * CFrame.new(0, 1, 0)).Position else root.Position
	local offset = target - origin
	local flatDistance = math.min(Vector3.new(offset.X, 0, offset.Z).Magnitude, Stats.MAX_RANGE)
	local scatterAngle = rng:NextNumber(0, 2 * math.pi)
	local scatterRadius = rng:NextNumber(0, Stats.AIM_SPREAD) * flatDistance
	local scattered = target + Vector3.new(math.cos(scatterAngle), 0, math.sin(scatterAngle)) * scatterRadius
	local velocity = Physics.launchVelocity(origin, scattered)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true

	local frames = Physics.simulate(origin, velocity, function(from: Vector3, direction: Vector3)
		if direction.Magnitude <= 0 then
			return nil, nil
		end
		local result = workspace:Spherecast(from, Stats.RADIUS, direction, params)
		if result then
			return from + direction.Unit * result.Distance, result.Normal
		end
		return nil, nil
	end, Stats.STICKY)

	nextThrowId += 1
	local throwId = nextThrowId
	if thrownRemote then
		thrownRemote:FireAllClients(throwId, player.UserId, frames)
	end

	task.delay(#frames * Stats.FRAME_TIME, explode, player, throwId, frames[#frames])
end

return Grenade
