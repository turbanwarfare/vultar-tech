--!nonstrict

local Players = game:GetService("Players")

local Config = require(script.Parent.Config)
local Ring = require(script.Parent.Ring)

local Signals = {}

local SIGNAL_ORDER = { "silentAim", "cluster", "switch", "headshot", "accuracy", "wallHit", "wallTrack", "flick" }
local SIGNAL_TITLES = {
	silentAim = "SILENT_AIM",
	cluster = "HIT_CLUSTER",
	switch = "TARGET_SWITCH",
	headshot = "HEADSHOT_RATE",
	accuracy = "ACCURACY",
	wallHit = "WALL_HIT",
	wallTrack = "WALL_TRACK",
	flick = "FAST_FLICK",
}

local MIN_VICTIM_SPEED_FOR_ALLOWANCE = 8
local MIN_FRAME_SECONDS = 1 / 240
local DEFAULT_FRAME_SECONDS = 1 / 60
local SAME_FRAME_WINDOW = 0.02
local SHOT_MATCH_WINDOW = 0.1

Signals.SIGNAL_TITLES = SIGNAL_TITLES

local function ramp(value: number, low: number, high: number): number
	return math.clamp((value - low) / (high - low), 0, 1)
end

local function angleBetween(a: Vector3, b: Vector3): number
	return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
end

local function countSince(ring, since: number): number
	local count = 0
	for i = ring.count, 1, -1 do
		if ring:get(i) >= since then
			count += 1
		else
			break
		end
	end
	return count
end

local function partName(part: number): string
	return if part == 1 then "head" else "body"
end

local function plural(count: number, word: string): string
	return `{count} {word}{if count == 1 then "" else "s"}`
end

local function cachedPing(state, player: Player): number
	local now = os.clock()
	if now - state.pingAt >= Config.Lag.PingCacheSeconds then
		local ok, ping = pcall(player.GetNetworkPing, player)
		state.ping = if ok and typeof(ping) == "number" then ping else state.ping
		state.pingAt = now
	end
	return state.ping
end

local function getRoot(player: Player?): BasePart?
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function Signals.newState()
	return {
		hits = Ring.new(Config.HitWindow),
		shots = Ring.new(Config.ShotWindow),
		silentAim = Ring.new(32),
		switches = Ring.new(32),
		wallHits = Ring.new(16),
		wallTracks = Ring.new(16),
		flicks = Ring.new(16),
		lastWallHitAt = -math.huge,
		lastShot = nil,
		lastHit = nil,
		ping = 0.1,
		pingAt = 0,
		frameSeconds = DEFAULT_FRAME_SECONDS,
	}
end

function Signals.recordShot(state, origin: Vector3, target: Vector3): ()
	local now = os.clock()
	state.shots:push(now)
	local delta = target - origin
	if delta:Dot(delta) > 0.0001 then
		state.lastShot = { origin = origin, dir = delta.Unit, t = now }
	end
end

function Signals.recordHit(state, attacker: Player, hit): ()
	local now = os.clock()
	local ping = cachedPing(state, attacker)
	if hit.clientFrameMs and hit.clientFrameMs > 0 and hit.clientFrameMs < 1000 then
		state.frameSeconds = hit.clientFrameMs / 1000
	end
	local lagging = ping > Config.Lag.MaxPingSeconds
	local last = state.lastHit
	local burst = last ~= nil and (now - last.t) < Config.Lag.BurstGapSeconds

	local origin, dir = hit.origin, nil
	if origin and hit.shotTarget then
		local delta = hit.shotTarget - origin
		if delta:Dot(delta) > 0.0001 then
			dir = delta.Unit
		end
	elseif state.lastShot and now - state.lastShot.t <= SHOT_MATCH_WINDOW then
		origin, dir = state.lastShot.origin, state.lastShot.dir
	end

	local victimRoot = getRoot(Players:GetPlayerByUserId(hit.targetId))
	local victimSpeed = if victimRoot then victimRoot.AssemblyLinearVelocity.Magnitude else 0
	local distance = 0
	if victimRoot then
		local from = origin
		if not from then
			local attackerRoot = getRoot(attacker)
			from = if attackerRoot then attackerRoot.Position else nil
		end
		if from then
			distance = (victimRoot.CFrame:PointToWorldSpace(hit.offset) - from).Magnitude
		end
	end

	if origin and dir and victimRoot and not lagging and distance >= Config.SilentAim.MinDistance then
		local toHit = victimRoot.CFrame:PointToWorldSpace(hit.offset) - origin
		local travel = math.max(victimSpeed, MIN_VICTIM_SPEED_FOR_ALLOWANCE) * (ping + state.frameSeconds) + 1.5
		local allowance = math.deg(math.atan2(travel, distance))
		if angleBetween(dir, toHit.Unit) > Config.SilentAim.BaseAngleDeg + allowance then
			state.silentAim:push(now)
		end
	end

	if dir and last and last.dir and last.targetId ~= hit.targetId and not burst and not lagging then
		local angle = angleBetween(last.dir, dir)
		local dt = math.max(now - last.t, state.frameSeconds, MIN_FRAME_SECONDS)
		if angle >= Config.Switch.MinAngleDeg and angle / dt >= Config.Switch.MaxDegPerSec then
			state.switches:push(now)
		end
	end

	local entry = {
		t = now,
		targetId = hit.targetId,
		offset = hit.offset,
		bodyPart = hit.bodyPart,
		head = hit.head,
		gunIndex = hit.gunIndex,
		dir = dir,
		distance = distance,
		victimMoving = victimSpeed >= Config.Cluster.MinVictimSpeed,
	}
	state.hits:push(entry)
	state.lastHit = entry
end

function Signals.recordWallHit(state): ()
	local now = os.clock()
	if now - state.lastWallHitAt < Config.WallHit.EventGap then
		return
	end
	state.lastWallHitAt = now
	state.wallHits:push(now)
end

function Signals.recordWallTrack(state, enemyId: number): ()
	state.wallTracks:push({ t = os.clock(), enemyId = enemyId })
end

function Signals.recordFlick(state): ()
	state.flicks:push(os.clock())
end

function Signals.evaluate(state)
	local now = os.clock()
	local since = now - Config.TimeWindow

	local hits = {}
	for i = 1, state.hits.count do
		local hit = state.hits:get(i)
		if hit.t >= since then
			table.insert(hits, hit)
		end
	end
	local hitCount = #hits
	local shotCount = countSince(state.shots, since)
	local sightSince = now - Config.SightWindow
	local wallHitCount = countSince(state.wallHits, sightSince)
	local flickCount = countSince(state.flicks, sightSince)
	local trackCount, trackEnemies, trackSeen = 0, 0, {}
	for i = state.wallTracks.count, 1, -1 do
		local episode = state.wallTracks:get(i)
		if episode.t < sightSince then
			break
		end
		trackCount += 1
		if not trackSeen[episode.enemyId] then
			trackSeen[episode.enemyId] = true
			trackEnemies += 1
		end
	end
	if hitCount == 0 and shotCount == 0 and wallHitCount == 0 and trackCount == 0 and flickCount == 0 then
		return nil
	end

	local groups = {}
	local gunCounts = {}
	local headHits, frames, lastFrameTime = 0, 0, -1
	for _, hit in hits do
		if hit.victimMoving and hit.distance >= Config.Cluster.MinDistance then
			local group = groups[hit.bodyPart]
			if not group then
				group = { offsets = {}, victims = {} }
				groups[hit.bodyPart] = group
			end
			table.insert(group.offsets, hit.offset)
			group.victims[hit.targetId] = true
		end
		if hit.head then
			headHits += 1
		end
		if hit.t - lastFrameTime > SAME_FRAME_WINDOW then
			frames += 1
			lastFrameTime = hit.t
		end
		gunCounts[hit.gunIndex] = (gunCounts[hit.gunIndex] or 0) + 1
	end

	local tightest, tightPart, tightCount = math.huge, 0, 0
	for part, group in groups do
		local offsets = group.offsets
		local victimCount = 0
		for _ in group.victims do
			victimCount += 1
		end
		if #offsets >= Config.Cluster.MinHits and victimCount >= Config.Cluster.MinVictims then
			local sum = Vector3.zero
			for _, offset in offsets do
				sum += offset
			end
			local mean = sum / #offsets
			local squared = 0
			for _, offset in offsets do
				local delta = offset - mean
				squared += delta:Dot(delta)
			end
			local spread = math.sqrt(squared / #offsets)
			if spread < tightest then
				tightest, tightPart, tightCount = spread, part, #offsets
			end
		end
	end

	local silentCount = countSince(state.silentAim, since)
	local switchCount = countSince(state.switches, since)
	local headRatio = if hitCount > 0 then headHits / hitCount else 0
	local accuracyRatio = if shotCount > 0 then math.min(1, frames / shotCount) else 0

	local signals = {
		cluster = if tightCount > 0 then ramp(tightest, Config.Cluster.HumanStuds, Config.Cluster.TightStuds) else 0,
		silentAim = math.min(1, silentCount / Config.SilentAim.ViolationsForFull),
		switch = math.min(1, switchCount / Config.Switch.EventsForFull),
		headshot = if hitCount >= Config.Headshot.MinHits then ramp(headRatio, Config.Headshot.LowRatio, Config.Headshot.HighRatio) else 0,
		accuracy = if shotCount >= Config.Accuracy.MinShots then ramp(accuracyRatio, Config.Accuracy.LowRatio, Config.Accuracy.HighRatio) else 0,
		wallHit = math.min(1, wallHitCount / Config.WallHit.EventsForFull),
		wallTrack = math.min(1, trackCount / Config.WallTrack.EpisodesForFull) * (if trackEnemies >= Config.WallTrack.MinEnemies then 1 else 0.5),
		flick = math.min(1, flickCount / Config.Flick.EventsForFull),
	}

	local primary, primaryContribution, total = nil, 0, 0
	for _, name in SIGNAL_ORDER do
		local contribution = signals[name] * (Config.AloneWeights[name] or 0)
		total += contribution
		if contribution > primaryContribution then
			primary, primaryContribution = name, contribution
		end
	end
	local score = math.min(1, primaryContribution + Config.CorroborationWeight * (total - primaryContribution))

	local topGun, topGunCount = nil, 0
	for gunIndex, count in gunCounts do
		if count > topGunCount then
			topGun, topGunCount = gunIndex, count
		end
	end

	local details = {}
	local function reason(level: number, text: string)
		table.insert(details, { level = level, text = text })
	end
	if signals.cluster > 0 then
		reason(signals.cluster, string.format("Shots land on the exact same spot of the %s on moving players: %d hits all within %.2f studs. Real players spread out.", partName(tightPart), tightCount, tightest))
	end
	if silentCount > 0 then
		reason(signals.silentAim, string.format("%s hit a player their cursor wasn't on (the shot was aimed somewhere else).", plural(silentCount, "shot")))
	end
	if switchCount > 0 then
		reason(signals.switch, string.format("Snapped between two different players faster than a human can, %s.", plural(switchCount, "time")))
	end
	if signals.headshot > 0 then
		reason(signals.headshot, string.format("%.0f%% of their hits are headshots (%d hits).", headRatio * 100, hitCount))
	end
	if signals.accuracy > 0 then
		reason(signals.accuracy, string.format("%.0f%% of their shots hit (%d shots).", accuracyRatio * 100, shotCount))
	end
	if wallHitCount > 0 then
		reason(signals.wallHit, string.format("%s through solid walls. The server traced the shot and a wall was in the way.", plural(wallHitCount, "hit")))
	end
	if trackCount > 0 then
		reason(signals.wallTrack, string.format("Kept their crosshair on %s hidden behind walls, %s.", plural(trackEnemies, "player"), plural(trackCount, "time")))
	end
	if flickCount > 0 then
		reason(signals.flick, string.format("Snapped onto a player within %.2fs of them coming into view, %s. Humans can't react that fast.", Config.Flick.MaxSeconds, plural(flickCount, "time")))
	end
	table.sort(details, function(a, b)
		return a.level > b.level
	end)

	return {
		score = score,
		primary = primary,
		signals = signals,
		details = details,
		hits = hitCount,
		shots = shotCount,
		eligible = hitCount >= Config.MinHitsForAlert or wallHitCount >= Config.WallHit.EventsForFull or signals.wallTrack >= 1,
		headshotRatio = headRatio,
		accuracyRatio = accuracyRatio,
		topGunIndex = topGun,
		pingMs = math.round(state.ping * 1000),
		fps = if state.frameSeconds > 0 then math.round(1 / state.frameSeconds) else 0,
	}
end

return Signals
