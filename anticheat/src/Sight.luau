--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local Ring = require(script.Parent.Ring)
local SightMath = require(script.Parent.SightMath)
local Network = require(script.Parent.ScreenWatch.Shared.Network)

local Sight = {}

type Pose = { t: number, head: Vector3, torso: Vector3 }
type Aim = { t: number, origin: Vector3, dir: Vector3 }
type Pair = {
	run: SightMath.TrackRun?,
	lastDir: Vector3?,
	lastSeen: number,
	checkedAt: number,
	cooldownUntil: number,
	lastHitAt: number,
}
type PingEntry = { value: number, at: number }

export type Handlers = {
	wallTrack: (viewer: Player, enemy: Player) -> (),
	flick: (attacker: Player, victim: Player) -> (),
}

local POSE_CAPACITY = 48
local AIM_CAPACITY = 64
local POSE_INTERVAL = 1 / 20
local BODY_RADIUS = 1.5
local MAX_MOVE_SPEED = 32
local MIN_SAMPLE_GAP = 1 / 40
local MAX_SKIPS = 3
local SKIP_EPSILON = 0.01
local EXCLUDED_FOLDERS = { "Ignore", "VFXStorage" }

local poses: { [Player]: Ring.Ring<Pose> } = {}
local poseTimes: { [Player]: (number) -> number } = {}
local poseCharacters: { [Player]: Model } = {}
local aims: { [Player]: Ring.Ring<Aim> } = {}
local lastAimAt: { [Player]: number } = {}
local lastFiredAt: { [Player]: number } = {}
local pairStates: { [Player]: { [Player]: Pair } } = {}
local pings: { [Player]: PingEntry } = {}

local bulletParams = RaycastParams.new()
local sightParams = RaycastParams.new()
local staticExclusions: { Instance } = {}
local filtersDirty = true
local streamingRadius: number? = nil

local connections: { RBXScriptConnection } = {}
local handlers: Handlers? = nil
local vultar: any = nil
local factionUtils: any = nil
local poseAccumulator = 0
local passAccumulator = 0
local passOffset = 0

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function angleDeg(a: Vector3, b: Vector3): number
	return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
end

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function finiteVector(value: Vector3): boolean
	return finite(value.X) and finite(value.Y) and finite(value.Z)
end

local function isWithin(delta: Vector3, distance: number): boolean
	return delta:Dot(delta) <= distance * distance
end

local function pingOf(player: Player): number
	local now = os.clock()
	local cached = pings[player]
	if cached and now - cached.at < 1 then
		return cached.value
	end
	local ok, value = pcall(player.GetNetworkPing, player)
	local ping = if ok and typeof(value) == "number" then value elseif cached then cached.value else 0.1
	pings[player] = { value = ping, at = now }
	return ping
end

local function viewLag(player: Player): number
	return math.clamp(pingOf(player) / 2, Config.Sight.MinLagSeconds, Config.Sight.MaxLagSeconds)
end

local function aliveCharacter(player: Player): Model?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and humanoid and humanoid.Health > 0 then
		return character
	end
	return nil
end

local function getService(name: string): any
	if not vultar then
		return nil
	end
	local ok, service = pcall(vultar.GetService, name)
	return if ok then service else nil
end

local function isWatcher(player: Player): boolean
	local service = getService("ScreenWatchService")
	return service ~= nil and typeof(service.GetTargetForWatcher) == "function" and service:GetTargetForWatcher(player) ~= nil
end

local function isRevealed(enemy: Player): boolean
	local service = getService("PingService")
	return service ~= nil and typeof(service.IsRevealed) == "function" and service:IsRevealed(enemy) == true
end

local function isActive(player: Player): boolean
	return aliveCharacter(player) ~= nil and not player:GetAttribute("InDuel") and not (factionUtils and factionUtils.isSpectator(player))
end

local function areEnemies(a: Player, b: Player): boolean
	return a ~= b and factionUtils ~= nil and factionUtils.areEnemies(a, b) == true
end

local function poseRing(player: Player, character: Model): Ring.Ring<Pose>
	local ring = poses[player]
	if ring and poseCharacters[player] == character then
		return ring
	end
	local fresh: Ring.Ring<Pose> = Ring.new(POSE_CAPACITY)
	poses[player] = fresh
	poseTimes[player] = function(index: number): number
		return fresh:get(index).t
	end
	poseCharacters[player] = character
	filtersDirty = true
	return fresh
end

local function samplePoses(now: number): ()
	for _, player in Players:GetPlayers() do
		local character = aliveCharacter(player)
		if character then
			local head = character:FindFirstChild("Head")
			local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
			if head and head:IsA("BasePart") and torso and torso:IsA("BasePart") then
				poseRing(player, character):push({ t = now, head = head.Position, torso = torso.Position })
			end
		end
	end
end

local function poseAt(player: Player, t: number): (Vector3?, Vector3?)
	local ring = poses[player]
	local timeAt = poseTimes[player]
	if not ring or not timeAt or ring.count == 0 then
		return nil, nil
	end
	local first, second, alpha = SightMath.locate(ring.count, timeAt, t)
	local a, b = ring:get(first), ring:get(second)
	return a.head:Lerp(b.head, alpha), a.torso:Lerp(b.torso, alpha)
end

local function getPair(viewer: Player, enemy: Player, now: number): Pair
	local byEnemy = pairStates[viewer] or {}
	pairStates[viewer] = byEnemy
	local pair: Pair = byEnemy[enemy] or {
		run = nil,
		lastDir = nil,
		lastSeen = now,
		checkedAt = now,
		cooldownUntil = 0,
		lastHitAt = -math.huge,
	}
	byEnemy[enemy] = pair
	return pair
end

local function addExclusion(instance: Instance): ()
	table.insert(staticExclusions, instance)
	filtersDirty = true
end

local function refreshFilters(): ()
	if not filtersDirty then
		return
	end
	filtersDirty = false
	local bullet = table.clone(staticExclusions)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(bullet, character)
		end
	end
	bulletParams.FilterDescendantsInstances = bullet
	sightParams.FilterDescendantsInstances = bullet
end

local function shouldSkip(part: Instance, skipTransparent: boolean): boolean
	if part:IsA("SpawnLocation") then
		return true
	end
	return skipTransparent and part:IsA("BasePart") and part.Transparency >= Config.Sight.SeeThroughTransparency
end

local function castThrough(params: RaycastParams, origin: Vector3, direction: Vector3, skipTransparent: boolean): (RaycastResult?, number)
	local length = direction.Magnitude
	if length <= 0 then
		return nil, 0
	end
	local unit = direction / length
	local travelled = 0
	for _ = 1, MAX_SKIPS + 1 do
		local result = workspace:Raycast(origin + unit * travelled, unit * (length - travelled), params)
		if not result then
			return nil, 0
		end
		if not shouldSkip(result.Instance, skipTransparent) then
			return result, travelled + result.Distance
		end
		travelled += result.Distance + SKIP_EPSILON
		if travelled >= length then
			return nil, 0
		end
	end
	return nil, 0
end

local function occludedSpan(params: RaycastParams, from: Vector3, to: Vector3, startMargin: number, endMargin: number, skipTransparent: boolean): (number, RaycastResult?)
	local delta = to - from
	local length = delta.Magnitude
	if length <= startMargin + endMargin then
		return 0, nil
	end
	local dir = delta / length
	local a = from + dir * startMargin
	local b = to - dir * endMargin
	local segment = b - a
	local forward, forwardDistance = castThrough(params, a, segment, skipTransparent)
	if not forward then
		return 0, nil
	end
	local reverse, reverseDistance = castThrough(params, b, -segment, skipTransparent)
	return SightMath.blockedSpan(segment.Magnitude, forwardDistance, if reverse then reverseDistance else nil), forward
end

local function isHidden(from: Vector3, head: Vector3, torso: Vector3): boolean
	local config = Config.Sight
	return occludedSpan(sightParams, from, head, config.StartMargin, config.EndMargin, true) >= config.MinOccluderThickness
		and occludedSpan(sightParams, from, torso, config.StartMargin, config.EndMargin, true) >= config.MinOccluderThickness
end

local function isDoorPart(instance: Instance): boolean
	local current: Instance? = instance
	while current and current ~= workspace do
		local name = current.Name
		if string.find(name, "^[Dd]oor") or string.find(name, "Doors?$") then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isBulletBlocked(from: Vector3, to: Vector3, shooterHead: Vector3): boolean
	local config = Config.WallHit
	local span, forward = occludedSpan(bulletParams, from, to, config.StartMargin, config.EndMargin, false)
	if not forward or span < config.MinThickness then
		return false
	end
	local part = forward.Instance
	if part:IsA("BasePart") and not part.Anchored then
		return false
	end
	if streamingRadius and not isWithin(forward.Position - shooterHead, streamingRadius) then
		return false
	end
	return not isDoorPart(part)
end

local function trackSample(viewer: Player, sample: Aim): ()
	local report = handlers and handlers.wallTrack
	if not report then
		return
	end
	refreshFilters()
	local config = Config.WallTrack
	local now = serverNow()
	local ping = pingOf(viewer)
	local lag = viewLag(viewer)
	for _, enemy in Players:GetPlayers() do
		if areEnemies(viewer, enemy) and aliveCharacter(enemy) and not enemy:GetAttribute("InDuel") then
			local head, torso = poseAt(enemy, sample.t - lag)
			if head and torso then
				local toTorso = torso - sample.origin
				local distance = toTorso.Magnitude
				if distance >= config.MinDistance and distance <= Config.Sight.Range then
					local pair = getPair(viewer, enemy, now)
					local err = SightMath.effectiveError(angleDeg(sample.dir, toTorso / distance), BODY_RADIUS, distance)
					local qualifies = false
					if
						err <= config.ConeDeg
						and now - pair.checkedAt <= config.MaxCheckAge
						and now - pair.lastSeen >= config.HiddenSeconds + ping
						and now - (lastFiredAt[enemy] or -math.huge) >= config.QuietSeconds
						and not isRevealed(enemy)
					then
						local _, oldTorso = poseAt(enemy, sample.t - lag - config.LateralWindow)
						if oldTorso then
							local before = oldTorso - sample.origin
							if not isWithin(before, 0.1) then
								local lateral = angleDeg(before.Unit, toTorso / distance) / config.LateralWindow
								qualifies = lateral >= config.MinLateralDegPerSec and isHidden(sample.origin, head, torso)
							end
						end
					end
					local lastDir = pair.lastDir
					local travel = if lastDir then angleDeg(lastDir, sample.dir) else 0
					pair.lastDir = sample.dir
					local run, episode = SightMath.stepTrack(pair.run, sample.t, qualifies, travel, config)
					pair.run = run
					if episode and sample.t >= pair.cooldownUntil then
						pair.cooldownUntil = sample.t + config.PairCooldown
						report(viewer, enemy)
					end
				end
			end
		end
	end
end

local function visibilityPass(now: number): ()
	refreshFilters()
	local config = Config.WallTrack
	local budget = Config.Sight.PassRaycastBudget
	local viewers = Players:GetPlayers()
	local count = #viewers
	if count == 0 then
		return
	end
	passOffset = passOffset % count + 1
	for step = 0, count - 1 do
		local viewer = viewers[(passOffset + step - 1) % count + 1]
		local ring = aims[viewer]
		if ring and ring.count > 0 then
			local latest = ring:get(ring.count)
			if now - latest.t <= config.MaxCheckAge and isActive(viewer) then
				local lag = viewLag(viewer)
				for _, enemy in Players:GetPlayers() do
					if areEnemies(viewer, enemy) and aliveCharacter(enemy) then
						local pair = getPair(viewer, enemy, now)
						if now - pair.checkedAt > config.MaxCheckAge then
							pair.lastSeen = now
						end
						local head, torso = poseAt(enemy, latest.t - lag)
						if head and torso then
							local toTorso = torso - latest.origin
							local distance = toTorso.Magnitude
							local inView = distance > 0.1
								and distance <= Config.Sight.Range
								and angleDeg(latest.dir, toTorso / distance) <= Config.Sight.FovDeg
							if not inView then
								pair.checkedAt = now
							elseif budget > 0 then
								budget -= 4
								pair.checkedAt = now
								if not isHidden(latest.origin, head, torso) then
									pair.lastSeen = now
								end
							end
						end
					end
				end
			end
		end
	end
end

local function evaluateFlick(attacker: Player, victim: Player, hitAt: number): ()
	local report = handlers and handlers.flick
	local ring = aims[attacker]
	if not report or not ring or not attacker.Parent or not victim.Parent then
		return
	end
	refreshFilters()
	local lag = viewLag(attacker)
	local from = hitAt - pingOf(attacker) - Config.Flick.WindowSeconds
	local to = hitAt + Config.Flick.SettleSeconds
	local samples: { SightMath.FlickSample } = {}
	local origins: { Vector3 } = {}
	local heads: { Vector3 } = {}
	local torsos: { Vector3 } = {}
	for index = 1, ring.count do
		local entry = ring:get(index)
		if entry.t >= from and entry.t <= to then
			local head, torso = poseAt(victim, entry.t - lag)
			if head and torso then
				local toTorso = torso - entry.origin
				local distance = toTorso.Magnitude
				if distance > 0.1 then
					local err = SightMath.effectiveError(angleDeg(entry.dir, toTorso / distance), BODY_RADIUS, distance)
					table.insert(samples, { t = entry.t, visible = false, err = err })
					table.insert(origins, entry.origin)
					table.insert(heads, head)
					table.insert(torsos, torso)
				end
			end
		end
	end
	local index = #samples
	while index >= 1 and isHidden(origins[index], heads[index], torsos[index]) do
		index -= 1
	end
	while index >= 1 and not isHidden(origins[index], heads[index], torsos[index]) do
		samples[index].visible = true
		index -= 1
	end
	if SightMath.classifyFlick(samples, Config.Flick) then
		report(attacker, victim)
	end
end

local function onAimSample(player: Player, t: number, origin: Vector3, direction: Vector3): ()
	if #connections == 0 then
		return
	end
	if typeof(t) ~= "number" or typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	if not finite(t) or not finiteVector(origin) or not finiteVector(direction) then
		return
	end
	local now = serverNow()
	if t < now - Config.Sight.MaxSampleAge or t > now + Config.Sight.MaxSampleLead then
		return
	end
	local last = lastAimAt[player]
	if last and t - last < MIN_SAMPLE_GAP then
		return
	end
	local length = direction.Magnitude
	if length < 0.5 or length > 1.5 then
		return
	end
	lastAimAt[player] = t
	if not isActive(player) or isWatcher(player) then
		return
	end
	local head = poseAt(player, t)
	if not head or not isWithin(origin - head, Config.Sight.MaxCameraOffset + pingOf(player) * MAX_MOVE_SPEED) then
		return
	end
	local ring: Ring.Ring<Aim> = aims[player] or Ring.new(AIM_CAPACITY)
	aims[player] = ring
	local sample: Aim = { t = t, origin = origin, dir = direction / length }
	ring:push(sample)
	trackSample(player, sample)
end

local function onHeartbeat(dt: number): ()
	poseAccumulator += dt
	passAccumulator += dt
	if poseAccumulator >= POSE_INTERVAL then
		poseAccumulator = 0
		debug.profilebegin("AC::Sight::poses")
		samplePoses(serverNow())
		debug.profileend()
	end
	if passAccumulator >= Config.Sight.PassInterval then
		passAccumulator = 0
		debug.profilebegin("AC::Sight::visibility")
		visibilityPass(serverNow())
		debug.profileend()
	end
end

local function findModule(root: Instance, path: { string }): ModuleScript?
	local current: Instance? = root
	for _, name in path do
		current = current and current:FindFirstChild(name)
	end
	return if current and current:IsA("ModuleScript") then current else nil
end

local function isPhaseMap(mainModule: Instance): boolean
	local mapsModule = findModule(mainModule, { "Shared", "Config", "Maps" })
	if not mapsModule then
		return false
	end
	local ok, maps = pcall(require, mapsModule)
	if not ok or typeof(maps) ~= "table" or typeof(maps.getConfig) ~= "function" then
		return false
	end
	local configOk, mapConfig = pcall(maps.getConfig)
	return configOk and typeof(mapConfig) == "table" and mapConfig.RaidType == "Phase"
end

function Sight.init(mainModule: Instance, vultarModule: any, eventHandlers: Handlers): ()
	if #connections > 0 then
		return
	end
	vultar = vultarModule
	handlers = eventHandlers

	local factionModule = findModule(mainModule, { "Shared", "Utils", "Game", "FactionUtils" })
	if factionModule then
		local ok, result = pcall(require, factionModule)
		factionUtils = if ok then result else nil
	end
	if not factionUtils then
		warn("[AC] Sight could not load FactionUtils; wall tracking and flick checks are off")
	end

	for _, params in { bulletParams, sightParams } do
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true
		params.RespectCanCollide = false
	end
	if isPhaseMap(mainModule) then
		bulletParams.CollisionGroup = "PlayerCharacter"
	end
	streamingRadius = if workspace.StreamingEnabled then workspace.StreamingMinRadius else nil

	for _, name in EXCLUDED_FOLDERS do
		local folder = workspace:FindFirstChild(name)
		if folder then
			addExclusion(folder)
		end
	end
	table.insert(connections, workspace.ChildAdded:Connect(function(child: Instance)
		if table.find(EXCLUDED_FOLDERS, child.Name) then
			addExclusion(child)
		end
	end))
	table.insert(connections, RunService.Heartbeat:Connect(onHeartbeat))
	Network.onAimSample(onAimSample)
end

function Sight.isWallHit(attacker: Player, victim: Player, origin: Vector3?, target: Vector3?): boolean
	if #connections == 0 or not origin or not target then
		return false
	end
	local ping = pingOf(attacker)
	if ping > Config.Lag.MaxPingSeconds then
		return false
	end
	local attackerCharacter = attacker.Character
	local victimCharacter = victim.Character
	local head = attackerCharacter and attackerCharacter:FindFirstChild("Head")
	local victimRoot = victimCharacter and victimCharacter:FindFirstChild("HumanoidRootPart")
	if not head or not head:IsA("BasePart") or not victimRoot or not victimRoot:IsA("BasePart") then
		return false
	end
	local slack = ping * MAX_MOVE_SPEED
	if not isWithin(target - victimRoot.Position, Config.WallHit.MaxEndpointError + slack) then
		return false
	end
	refreshFilters()
	local headPosition = head.Position
	if not isBulletBlocked(headPosition, target, headPosition) then
		return false
	end
	local ring = poses[attacker]
	if ring then
		local since = serverNow() - ping - Config.WallHit.HistorySlack
		for index = ring.count, 1, -1 do
			local entry = ring:get(index)
			if entry.t < since then
				break
			end
			if not isBulletBlocked(entry.head, target, headPosition) then
				return false
			end
		end
	end
	if isWithin(origin - headPosition, Config.WallHit.MaxOriginError + slack) and not isBulletBlocked(origin, target, headPosition) then
		return false
	end
	return true
end

function Sight.noteFired(player: Player): ()
	lastFiredAt[player] = serverNow()
end

function Sight.noteHit(attacker: Player, victim: Player): ()
	if #connections == 0 then
		return
	end
	local now = serverNow()
	lastFiredAt[attacker] = now
	local pair = getPair(attacker, victim, now)
	local fresh = now - pair.lastHitAt >= Config.Flick.EngagementGap
	pair.lastHitAt = now
	if fresh and pingOf(attacker) <= Config.Flick.MaxPingSeconds then
		task.delay(Config.Flick.SettleSeconds, evaluateFlick, attacker, victim, now)
	end
end

function Sight.clear(player: Player): ()
	poses[player] = nil
	poseTimes[player] = nil
	poseCharacters[player] = nil
	aims[player] = nil
	lastAimAt[player] = nil
	lastFiredAt[player] = nil
	pings[player] = nil
	pairStates[player] = nil
	for _, byEnemy in pairStates do
		byEnemy[player] = nil
	end
	filtersDirty = true
end

function Sight.stop(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	handlers = nil
	table.clear(poses)
	table.clear(poseTimes)
	table.clear(poseCharacters)
	table.clear(aims)
	table.clear(lastAimAt)
	table.clear(lastFiredAt)
	table.clear(pairStates)
	table.clear(pings)
	table.clear(staticExclusions)
	filtersDirty = true
end

return Sight
