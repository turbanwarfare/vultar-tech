--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local AbilityConfig = require(MainModule.Shared.Config.AbilityConfig)

export type Raycaster = (origin: Vector3, direction: Vector3) -> (Vector3?, Vector3?)

local Stats = AbilityConfig.Abilities.Grenade.Stats
local MAX_WALLS = 4

local Physics = {}

local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Include

function Physics.simulate(origin: Vector3, initialVelocity: Vector3, raycast: Raycaster, sticky: boolean?): { Vector3 }
	local dt = Stats.FRAME_TIME
	local gravity = Stats.GRAVITY
	local bounce = Stats.BOUNCE

	local position = origin
	local velocity = initialVelocity
	local offset = Vector3.zero
	local frames = { position }
	local resting = false

	for _ = 1, 1 + Stats.FUSE_TIME // dt do
		if resting then
			table.insert(frames, position)
			continue
		end

		local nextPosition = position + dt * velocity + (dt * dt / 2) * gravity
		local hitPosition, normal = raycast(position, nextPosition - position - 0.05 * offset)

		if hitPosition and normal then
			offset = 0.2 * normal
			local delta = hitPosition - position
			local deltaLength = delta.Magnitude
			local scale = if deltaLength > 0 then math.max(1 - 0.001 / deltaLength, 0) else 0
			position += scale * delta + 0.05 * normal

			local normalSpeed = normal:Dot(velocity)
			local impactSpeed = math.max(-normalSpeed, 0)
			local slopePull = gravity - normal:Dot(gravity) * normal
			local tangentVelocity = velocity - normalSpeed * normal + dt * slopePull
			local tangentSpeed = tangentVelocity.Magnitude
			local bounced = impactSpeed > Stats.BOUNCE_MIN_SPEED
			local keep = if bounced then Stats.BOUNCE_KEEP elseif tangentSpeed > 0 then math.max(1 - Stats.ROLL_FRICTION * dt / tangentSpeed, 0) else 0
			velocity = keep * tangentVelocity + (if bounced then bounce * impactSpeed else 0) * normal
			resting = sticky == true or (normal.Y > 0.7 and velocity:Dot(velocity) < Stats.REST_SPEED * Stats.REST_SPEED)
		else
			position = nextPosition
			velocity += dt * gravity
		end

		table.insert(frames, position)
	end

	return frames
end

function Physics.launchVelocity(origin: Vector3, target: Vector3): Vector3
	local offset = target - origin
	if offset:Dot(offset) > Stats.MAX_RANGE * Stats.MAX_RANGE then
		offset = offset.Unit * Stats.MAX_RANGE
	end
	local flatDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	local flightTime = math.clamp(flatDistance / Stats.THROW_SPEED, Stats.MIN_FLIGHT_TIME, Stats.MAX_FLIGHT_TIME)
	return (offset - 0.5 * Stats.GRAVITY * flightTime * flightTime) / flightTime
end

function Physics.damageAt(distance: number): number
	if distance <= Stats.KILL_RADIUS then
		return Stats.MAX_DAMAGE
	elseif distance < Stats.DAMAGE_RADIUS then
		local falloffRange = Stats.DAMAGE_RADIUS - Stats.KILL_RADIUS
		return Stats.MAX_DAMAGE * (Stats.DAMAGE_RADIUS - distance) / falloffRange
	end
	return 0
end

function Physics.isBlocked(from: Vector3, to: Vector3, params: RaycastParams): boolean
	local maxThickness = Stats.MAX_WALL_THICKNESS
	local origin = from
	for _ = 1, MAX_WALLS do
		local direction = to - origin
		local hit = workspace:Raycast(origin, direction, params)
		if not hit then
			return false
		end
		wallParams.FilterDescendantsInstances = { hit.Instance }
		local back = workspace:Raycast(to, hit.Position - to, wallParams)
		local exit = if back then back.Position else to
		local thickness = exit - hit.Position
		if thickness:Dot(thickness) > maxThickness * maxThickness then
			return true
		end
		origin = exit + direction.Unit * 0.01
	end
	return true
end

return Physics
