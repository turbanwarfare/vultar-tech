--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local Constants = require(MainModule.Shared.Config.Constants)
local PlayerCache = require(MainModule.Shared.Cache.PlayerCache)
local GunStats = require(MainModule.Shared.Config.GunStats)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
local FactionUtils = require(MainModule.Shared.Utils.Game.FactionUtils)
local AimChamberLink = require(script.Parent.AimChamberLink)

local DamageProcessor = {}

local getDeathService = LazyService.create(MainModule, "DeathService")
local getHardpointService = LazyService.create(MainModule, "HardpointService")
local getPhaseService = LazyService.create(MainModule, "PhaseService")
local getDominationService = LazyService.create(MainModule, "DominationService")
local getStatsService = LazyService.create(MainModule, "StatsService")
local getGunService = LazyService.create(MainModule, "GunService")
local getScreenWatchService = LazyService.create(MainModule, "ScreenWatchService")
local getReconAntiMacroService = LazyService.create(MainModule, "ReconAntiMacroService")

local statsSvc: any = nil
local deathSvc: any = nil

local MIN_PLAYERS_FOR_STATS = Constants.STATS.MIN_PLAYERS
local MAX_DAMAGE_PER_HIT = 120

local GUN_INDEX_TO_NAME = GunStats.GUN_INDEX_TO_NAME

type PrecomputedGunDamage = {
	base: number,
	head: number,
	chargeable: boolean,
	maxChargeMultiplier: number,
}

local GUN_DAMAGE_BY_INDEX: { [number]: PrecomputedGunDamage } = {}
for idx, name in GUN_INDEX_TO_NAME do
	local stats = GunStats.get(name)
	if stats then
		GUN_DAMAGE_BY_INDEX[idx] = {
			base = stats.BaseDamage or 0,
			head = stats.HeadDamage or stats.BaseDamage or 0,
			chargeable = stats.Chargeable == true,
			maxChargeMultiplier = stats.MaxChargeMultiplier or 1.75,
		}
	end
end



local function resolveGunDamage(gunIndex: number, head: boolean, clientDamage: number?): number
	local precomputed = GUN_DAMAGE_BY_INDEX[gunIndex]
	if not precomputed then
		return 0
	end

	local baseDmg = if head then precomputed.head else precomputed.base

	if precomputed.chargeable and clientDamage and clientDamage > baseDmg then
		local maxCharged = math.floor(baseDmg * precomputed.maxChargeMultiplier)
		return math.clamp(clientDamage, baseDmg, maxCharged)
	end

	return baseDmg
end

local function shouldCountStats(): boolean
	local hardpoint = getHardpointService()
	if hardpoint and hardpoint:IsOfficial() then
		return PlayerCache.getCount() >= MIN_PLAYERS_FOR_STATS
	end
	local phase = getPhaseService()
	if phase and phase:IsOfficial() then
		return PlayerCache.getCount() >= MIN_PLAYERS_FOR_STATS
	end
	local domination = getDominationService()
	if domination and domination:IsOfficial() then
		return PlayerCache.getCount() >= MIN_PLAYERS_FOR_STATS
	end
	return false
end

local cachedCountStats: boolean = false
local countStatsDirty: boolean = true

local function shouldCountStatsCached(): boolean
	if countStatsDirty then
		cachedCountStats = shouldCountStats()
		countStatsDirty = false
	end
	return cachedCountStats
end

local CREATOR_TAG_DURATION = 1.0
local MUTUAL_KILL_WINDOW = 0.3

local humanoidCache: { [number]: Humanoid? } = {}
local cacheTimestamps: { [number]: number } = {}
local CACHE_LIFETIME = 2

local recentKills: { [number]: number } = {}
local KILL_DEDUP_WINDOW = 0.5

local recentDeaths: { [number]: { killedBy: number, time: number } } = {}

local creatorTagCache: { [number]: ObjectValue } = {}
local creatorTagExpiry: { [number]: number } = {}
local creatorTagDelayPending: { [number]: boolean } = {}

local MAX_BODY_PART_INDEX = 6
local MAX_HIT_LOG = 100
local MAX_OUTGOING_LOG = 100
local INCOMING_WINDOW = 60
local OUTGOING_WINDOW = 30

type ServerHitLogEntry = {
	attackerId: number,
	bodyPart: number,
	localX: number,
	localY: number,
	localZ: number,
	damage: number,
	gunIndex: number,
	headshot: boolean,
	timestamp: number,
}

type ServerOutgoingEntry = {
	targetId: number,
	damage: number,
	gunIndex: number,
	headshot: boolean,
	timestamp: number,
}

type CircularBuffer<T> = { entries: { T }, head: number, count: number, max: number }

local function createCircularBuffer(max: number): CircularBuffer<any>
	return { entries = table.create(max), head = 0, count = 0, max = max }
end

local victimHitLogs: { [number]: CircularBuffer<ServerHitLogEntry> } = {}
local attackerOutgoingLogs: { [number]: CircularBuffer<ServerOutgoingEntry> } = {}
local assistDamage: { [number]: { [number]: number } } = {}
local moduleConnections: { RBXScriptConnection } = {}
local characterConnections: { [number]: { RBXScriptConnection } } = {}

local function getHumanoidFromUserId(userId: number): Humanoid?
	local now = os.clock()
	local cached = humanoidCache[userId]
	if cached and cached.Parent and (now - (cacheTimestamps[userId] or 0)) < CACHE_LIFETIME then
		return cached
	end

	local cachedPlayer = PlayerCache.getByUserId(userId)
	if not cachedPlayer then
		humanoidCache[userId] = nil
		return nil
	end

	local targetPlayer = cachedPlayer.player
	local char = targetPlayer.Character
	if not char then
		humanoidCache[userId] = nil
		return nil
	end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	humanoidCache[userId] = humanoid
	cacheTimestamps[userId] = now
	return humanoid
end

local function isHumanoidAlive(humanoid: Humanoid): boolean
	return humanoid:GetState() ~= Enum.HumanoidStateType.Dead
end

local cachedPlayerCharacters = {}
local cachedPlayerCharactersDirty = true

local function getActivePlayerCharacters(): { Model }
	if cachedPlayerCharactersDirty then
		table.clear(cachedPlayerCharacters)
		for _, p in Players:GetPlayers() do
			if p.Character then
				table.insert(cachedPlayerCharacters, p.Character)
			end
		end
		cachedPlayerCharactersDirty = false
	end
	return cachedPlayerCharacters
end

local function findNPCHumanoidNearPosition(position: Vector3, radius: number): Humanoid?
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	params.FilterDescendantsInstances = getActivePlayerCharacters()


	local parts = workspace:GetPartBoundsInRadius(position, radius, params)
	local bestHumanoid: Humanoid? = nil
	local minDistance = math.huge

	local seenModels = {}

	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not seenModels[model] then
			seenModels[model] = true
			
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and isHumanoidAlive(humanoid) then
				local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
				local refPart = hrp or model.PrimaryPart or part
				if refPart then
					local dist = (refPart.Position - position).Magnitude
					if dist < minDistance then
						minDistance = dist
						bestHumanoid = humanoid
					end
				end
			end
		end
	end
	return bestHumanoid
end

local function expireCreatorTag(targetId: number, tag: ObjectValue): ()
	local expiry = creatorTagExpiry[targetId]
	if expiry and workspace:GetServerTimeNow() < expiry then
		creatorTagDelayPending[targetId] = nil
		return
	end
	creatorTagExpiry[targetId] = nil
	creatorTagDelayPending[targetId] = nil
	if tag.Parent then
		tag.Parent = nil
	end
end

local function setCreatorTag(attacker: Player, humanoid: Humanoid, targetId: number): ()
	local tag = creatorTagCache[targetId]
	if not tag or not tag.Parent then
		if tag then
			tag:Destroy()
		end
		tag = Instance.new("ObjectValue")
		tag.Name = "creator"
		creatorTagCache[targetId] = tag
	end

	tag.Value = attacker
	tag.Parent = humanoid

	local expiry = workspace:GetServerTimeNow() + CREATOR_TAG_DURATION
	creatorTagExpiry[targetId] = expiry

	if not creatorTagDelayPending[targetId] then
		creatorTagDelayPending[targetId] = true
		task.delay(CREATOR_TAG_DURATION, expireCreatorTag, targetId, tag)
	end
end

local function logHit(targetId: number, attackerId: number, localOffset: Vector3, bodyPart: number, damage: number, gunIndex: number, headshot: boolean): ()
	if bodyPart < 1 or bodyPart > MAX_BODY_PART_INDEX then
		bodyPart = 2
	end

	local buf = victimHitLogs[targetId]
	if not buf then
		buf = createCircularBuffer(MAX_HIT_LOG)
		victimHitLogs[targetId] = buf
	end

	local head_idx = (buf.head % buf.max) + 1
	buf.head = head_idx

	local now = os.clock()

	local entry = buf.entries[head_idx]
	if entry then
		entry.attackerId = attackerId
		entry.bodyPart = bodyPart
		entry.localX = localOffset.X
		entry.localY = localOffset.Y
		entry.localZ = localOffset.Z
		entry.damage = damage
		entry.gunIndex = gunIndex
		entry.headshot = headshot
		entry.timestamp = now
	else
		buf.entries[head_idx] = {
			attackerId = attackerId,
			bodyPart = bodyPart,
			localX = localOffset.X,
			localY = localOffset.Y,
			localZ = localOffset.Z,
			damage = damage,
			gunIndex = gunIndex,
			headshot = headshot,
			timestamp = now,
		}
	end

	if buf.count < buf.max then
		buf.count += 1
	end
end

local function logOutgoing(attackerId: number, targetId: number, damage: number, gunIndex: number, headshot: boolean): ()
	local buf = attackerOutgoingLogs[attackerId]
	if not buf then
		buf = createCircularBuffer(MAX_OUTGOING_LOG)
		attackerOutgoingLogs[attackerId] = buf
	end

	local head_idx = (buf.head % buf.max) + 1
	buf.head = head_idx

	local now = os.clock()

	local entry = buf.entries[head_idx]
	if entry then
		entry.targetId = targetId
		entry.damage = damage
		entry.gunIndex = gunIndex
		entry.headshot = headshot
		entry.timestamp = now
	else
		buf.entries[head_idx] = {
			targetId = targetId,
			damage = damage,
			gunIndex = gunIndex,
			headshot = headshot,
			timestamp = now,
		}
	end

	if buf.count < buf.max then
		buf.count += 1
	end
end

local function consumeHitLog(victimId: number): { any }?
	local buf = victimHitLogs[victimId]
	victimHitLogs[victimId] = nil
	if not buf or buf.count == 0 then
		return nil
	end

	local now = os.clock()
	local cutoff = now - INCOMING_WINDOW
	local filtered: { any } = table.create(buf.count)
	local max = buf.max
	local start = if buf.count < max then 1 else (buf.head % max) + 1

	for i = 0, buf.count - 1 do
		local idx = ((start - 1 + i) % max) + 1
		local entry = buf.entries[idx]
		if entry and entry.timestamp >= cutoff then
			table.insert(filtered, {
				attackerId = entry.attackerId,
				bodyPart = entry.bodyPart,
				localX = entry.localX,
				localY = entry.localY,
				localZ = entry.localZ,
				damage = entry.damage,
				gunIndex = entry.gunIndex,
				headshot = entry.headshot,
			})
		end
	end

	if #filtered == 0 then
		return nil
	end
	return filtered
end

local function consumeOutgoingLog(attackerId: number): { any }?
	local buf = attackerOutgoingLogs[attackerId]
	attackerOutgoingLogs[attackerId] = nil
	if not buf or buf.count == 0 then
		return nil
	end

	local now = os.clock()
	local cutoff = now - OUTGOING_WINDOW
	local filtered: { any } = table.create(buf.count)
	local max = buf.max
	local start = if buf.count < max then 1 else (buf.head % max) + 1

	for i = 0, buf.count - 1 do
		local idx = ((start - 1 + i) % max) + 1
		local entry = buf.entries[idx]
		if entry and entry.timestamp >= cutoff then
			table.insert(filtered, {
				targetId = entry.targetId,
				damage = entry.damage,
				gunIndex = entry.gunIndex,
				headshot = entry.headshot,
			})
		end
	end

	if #filtered == 0 then
		return nil
	end
	return filtered
end

local function clearRecentKillEntry(victimId: number, timestamp: number): ()
	if recentKills[victimId] == timestamp then
		recentKills[victimId] = nil
	end
end

local function clearRecentDeathEntry(victimId: number, killedBy: number): ()
	local entry = recentDeaths[victimId]
	if entry and entry.killedBy == killedBy then
		recentDeaths[victimId] = nil
	end
end

local function processKill(
	killer: Player,
	victim: Humanoid,
	wasHeadshot: boolean,
	gunIndex: number,
	victimId: number,
	countStats: boolean,
	mutual: boolean?
): ()
	local victimChar = victim.Parent
	if not victimChar then
		return
	end

	if victimId ~= 0 then
		local cachedVictim = PlayerCache.getByUserId(victimId)
		local victimPlayer = cachedVictim and cachedVictim.player
		if not victimPlayer then
			return
		end
	end

	local killerId = killer.UserId

	local now = os.clock()
	if victimId ~= 0 then
		local lastKillTime = recentKills[victimId]
		if lastKillTime and (now - lastKillTime) < KILL_DEDUP_WINDOW then
			return
		end
		recentKills[victimId] = now
		task.delay(KILL_DEDUP_WINDOW, clearRecentKillEntry, victimId, now)

		recentDeaths[victimId] = { killedBy = killerId, time = now }
		task.delay(MUTUAL_KILL_WINDOW, clearRecentDeathEntry, victimId, killerId)
	end

	local range = 0
	local killerHealth = 100

	local killerChar = killer.Character
	if killerChar then
		local killerHrp = killerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		local victimHrp = victimChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if killerHrp and victimHrp then
			range = math.round((killerHrp.Position - victimHrp.Position).Magnitude)
		end

		local killerHumanoid = killerChar:FindFirstChildOfClass("Humanoid")
		if killerHumanoid then
			killerHealth = math.round(killerHumanoid.Health)
		end
	end

	if victimId ~= 0 then
		local hitLog = consumeHitLog(victimId)
		local outgoingLog = consumeOutgoingLog(victimId)

		if not deathSvc then
			deathSvc = getDeathService()
		end
		if deathSvc then
			deathSvc:SetDeathInfo(victimId, killerId, killer.Name, gunIndex, range, killerHealth, hitLog, outgoingLog)
		end
	end

	if not statsSvc then
		statsSvc = getStatsService()
	end
	if statsSvc then
		statsSvc:AddKill(killer, 1)
		if countStats then
			statsSvc:AddKillGlobal(killer)
		end
	end
	
	if assistDamage[victimId] then
		for assisterId, dmg in assistDamage[victimId] do
			if assisterId ~= killerId and dmg >= 80 then
				local assister = Players:GetPlayerByUserId(assisterId)
				if assister then
					if statsSvc then
						statsSvc:AddKill(assister, 1)
						if countStats then
							statsSvc:AddKillGlobal(assister)
						end
					end
					local Core = require(MainModule.Shared.Network.Core)
					local acakEvent = Core.getOrCreateRemoteEvent("ACAK")
					acakEvent:FireClient(assister)
				end
			end
		end
		assistDamage[victimId] = nil
	end

	local finishGunName = GUN_INDEX_TO_NAME[gunIndex]
	if finishGunName == "BR-8" or finishGunName == "H-12" then
		local antiMacroSvc = getReconAntiMacroService()
		if antiMacroSvc then
			antiMacroSvc.RegisterKill(killer, victimId, finishGunName)
		end
	end

	Network.Gun.broadcastKill({
		killer = killerId,
		victim = victimId,
		headshot = wasHeadshot,
		weapon = gunIndex,
		killerHealth = killerHealth,
		mutual = mutual == true,
	})
end

local function updateDamageStats(attacker: Player, damage: number, countStats: boolean): ()
	if not statsSvc then
		statsSvc = getStatsService()
	end
	if not statsSvc then
		return
	end
	statsSvc:AddDamage(attacker, damage)
	if countStats then
		statsSvc:AddDamageGlobal(attacker, damage)
	end
end

local function watchCharacter(player: Player): ()
	local userId = player.UserId
	local existing = characterConnections[userId]
	if existing then
		for _, conn in existing do
			conn:Disconnect()
		end
	end

	local conns: { RBXScriptConnection } = {}
	characterConnections[userId] = conns

	table.insert(
		conns,
		player.CharacterRemoving:Connect(function()
			cachedPlayerCharactersDirty = true
			humanoidCache[userId] = nil
			cacheTimestamps[userId] = nil
		end)
	)

	table.insert(
		conns,
		player.CharacterAdded:Connect(function()
			cachedPlayerCharactersDirty = true
			humanoidCache[userId] = nil
			cacheTimestamps[userId] = nil
			victimHitLogs[userId] = nil
			attackerOutgoingLogs[userId] = nil
			assistDamage[userId] = nil
			recentDeaths[userId] = nil
		end)
	)
end

function DamageProcessor.init(): ()
	local Core = require(MainModule.Shared.Network.Core)
	Core.getOrCreateRemoteEvent("ACAK")

	table.insert(
		moduleConnections,
		Players.PlayerAdded:Connect(function(player)
			cachedPlayerCharactersDirty = true
			countStatsDirty = true
			watchCharacter(player)
		end)
	)

	table.insert(
		moduleConnections,
		Players.PlayerRemoving:Connect(function(player)
			cachedPlayerCharactersDirty = true
			countStatsDirty = true
			local userId = player.UserId
			humanoidCache[userId] = nil
			cacheTimestamps[userId] = nil
			recentKills[userId] = nil
			recentDeaths[userId] = nil
			victimHitLogs[userId] = nil
			attackerOutgoingLogs[userId] = nil
			assistDamage[userId] = nil

			local conns = characterConnections[userId]
			if conns then
				for _, conn in conns do
					conn:Disconnect()
				end
				characterConnections[userId] = nil
			end

			creatorTagExpiry[userId] = nil
			creatorTagDelayPending[userId] = nil
			local tag = creatorTagCache[userId]
			if tag then
				tag:Destroy()
				creatorTagCache[userId] = nil
			end
		end)
	)

	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end
end

function DamageProcessor.cleanup(): ()
	for _, conn in moduleConnections do
		conn:Disconnect()
	end
	for _, conns in characterConnections do
		for _, conn in conns do
			conn:Disconnect()
		end
	end
	for _, tag in creatorTagCache do
		tag:Destroy()
	end
	table.clear(moduleConnections)
	table.clear(characterConnections)
	table.clear(humanoidCache)
	table.clear(cacheTimestamps)
	table.clear(recentKills)
	table.clear(recentDeaths)
	table.clear(victimHitLogs)
	table.clear(attackerOutgoingLogs)
	table.clear(creatorTagCache)
	table.clear(creatorTagExpiry)
	table.clear(creatorTagDelayPending)
	countStatsDirty = true
	cachedPlayerCharactersDirty = true

	statsSvc = nil
	deathSvc = nil
end

local HEAD_BODY_PART = 1

local function checkMutualKill(attacker: Player, targetId: number, verifiedHead: boolean, gunIndex: number, countStats: boolean): boolean
	local humanoid = getHumanoidFromUserId(targetId)
	if not humanoid or humanoid.Health > 0 then
		return false
	end

	local attackerUserId = attacker.UserId
	local deathEntry = recentDeaths[attackerUserId]
	if deathEntry and deathEntry.killedBy == targetId and (os.clock() - deathEntry.time) <= MUTUAL_KILL_WINDOW then
		processKill(attacker, humanoid, verifiedHead, gunIndex, targetId, countStats, true)
	end

	return true
end

local function processHitInternalUnchecked(
	attacker: Player,
	targetId: number,
	clientDamage: number,
	head: boolean,
	localOffset: Vector3,
	bodyPart: number,
	gunIndex: number,
	worldHitPos: Vector3?,
	fixedDamage: number?
): ()
	debug.profilebegin("DamageProcessor::applyDamage")

	local verifiedHead = head and bodyPart == HEAD_BODY_PART
	
	if targetId == 0 and AimChamberLink.isPlayerInAiMode(attacker) then
		verifiedHead = false
	end
	
	local damage = fixedDamage or resolveGunDamage(gunIndex, verifiedHead, clientDamage)

	if damage <= 0 then
		debug.profileend()
		return
	end
	if damage > MAX_DAMAGE_PER_HIT then
		damage = MAX_DAMAGE_PER_HIT
	end

	local countStats = shouldCountStatsCached()

	if targetId == 0 then
		local npcHumanoid = nil
		if worldHitPos then
			npcHumanoid = findNPCHumanoidNearPosition(worldHitPos, 10)
		end
		if npcHumanoid then
			local parent = npcHumanoid.Parent
			if parent and parent:FindFirstChildOfClass("ForceField") then
				debug.profileend()
				return
			end
			local healthBefore = npcHumanoid.Health
			npcHumanoid.Health = math.max(0, healthBefore - damage)
			setCreatorTag(attacker, npcHumanoid, 0)

			AimChamberLink.recordPlayerHit(attacker, 1)
		end

		local npcName = if npcHumanoid and npcHumanoid.Parent then npcHumanoid.Parent.Name else "NPC"
		local screenWatch = getScreenWatchService()
		if screenWatch and typeof(screenWatch.NotifyHit) == "function" then
			screenWatch:NotifyHit(attacker.UserId, 0, damage, bodyPart, verifiedHead, gunIndex, npcName)
		end

		updateDamageStats(attacker, damage, countStats)
		debug.profileend()
		return
	end

	if checkMutualKill(attacker, targetId, verifiedHead, gunIndex, countStats) then
		debug.profileend()
		return
	end

	local cachedTarget = PlayerCache.getByUserId(targetId)
	local targetPlayer = cachedTarget and cachedTarget.player
	if targetPlayer and FactionUtils.isSpectator(targetPlayer) then
		debug.profileend()
		return
	end
	if targetPlayer and not FactionUtils.areEnemies(attacker, targetPlayer) then
		debug.profileend()
		return
	end

	local humanoid = getHumanoidFromUserId(targetId)
	if not humanoid then
		debug.profileend()
		return
	end

	local humanoidParent = humanoid.Parent
	if humanoidParent and humanoidParent:FindFirstChildOfClass("ForceField") then
		debug.profileend()
		return
	end

	logHit(targetId, attacker.UserId, localOffset, bodyPart, damage, gunIndex, verifiedHead)
	logOutgoing(attacker.UserId, targetId, damage, gunIndex, verifiedHead)

	local screenWatch = getScreenWatchService()
	if screenWatch and typeof(screenWatch.NotifyHit) == "function" then
		screenWatch:NotifyHit(attacker.UserId, targetId, damage, bodyPart, verifiedHead, gunIndex, nil, localOffset)
	end

	if not assistDamage[targetId] then
		assistDamage[targetId] = {}
	end
	assistDamage[targetId][attacker.UserId] = (assistDamage[targetId][attacker.UserId] or 0) + damage

	updateDamageStats(attacker, damage, countStats)

	local healthBefore = humanoid.Health
	if healthBefore ~= math.huge and not fixedDamage then
		local gunService = getGunService()
		if gunService and gunService.registerValidHit then
			gunService.registerValidHit(attacker.UserId, 1)
		end
	end
	humanoid.Health = math.max(0, healthBefore - damage)

	setCreatorTag(attacker, humanoid, targetId)

	if humanoid.Health <= 0 then
		local isMutual = false
		local attackerDeath = recentDeaths[attacker.UserId]
		if attackerDeath and attackerDeath.killedBy == targetId and (os.clock() - attackerDeath.time) <= MUTUAL_KILL_WINDOW then
			isMutual = true
		end

		processKill(attacker, humanoid, verifiedHead, gunIndex, targetId, countStats, isMutual)
	end
	debug.profileend()
end

local function processHitInternal(
	attacker: Player,
	targetId: number,
	clientDamage: number,
	head: boolean,
	localOffset: Vector3,
	bodyPart: number,
	gunIndex: number,
	worldHitPos: Vector3?
): ()
	debug.profilebegin("DamageProcessor::applyDamage")

	local verifiedHead = head and bodyPart == HEAD_BODY_PART
	
	if targetId == 0 and AimChamberLink.isPlayerInAiMode(attacker) then
		verifiedHead = false
	end
	
	local damage = resolveGunDamage(gunIndex, verifiedHead, clientDamage)

	local gunName = GUN_INDEX_TO_NAME[gunIndex]
	if gunName == "BR-50" or gunName == "H-50" then
		local stats = GunStats.get(gunName)
		if not stats then
			warn("[DamageProcessor] GunStats not found for recon rifle:", gunName)
		end
		local baseDmg = if stats and stats.BaseDamage then stats.BaseDamage else 60
		local maxMultiplier = if stats and stats.MaxChargeMultiplier then stats.MaxChargeMultiplier else 1.75
		local maxDmg = baseDmg * maxMultiplier
		local clampedCharge = if maxDmg > baseDmg
			then math.clamp((damage - baseDmg) / (maxDmg - baseDmg), 0, 1)
			else 0
		local antiMacroSvc = getReconAntiMacroService()
		if antiMacroSvc then
			antiMacroSvc.RegisterRifleDischarge(attacker, gunName, clampedCharge)
			if targetId > 0 then
				antiMacroSvc.RecordRifleHit(attacker, targetId, damage)
			end
		end
	end

	if damage <= 0 then
		debug.profileend()
		return
	end
	if damage > MAX_DAMAGE_PER_HIT then
		damage = MAX_DAMAGE_PER_HIT
	end

	if FactionUtils.isSpectator(attacker) then
		debug.profileend()
		return
	end

	local countStats = shouldCountStatsCached()

	if targetId == 0 then
		local npcHumanoid = nil
		if worldHitPos then
			npcHumanoid = findNPCHumanoidNearPosition(worldHitPos, 10)
		end
		if npcHumanoid then
			local parent = npcHumanoid.Parent
			if parent and parent:FindFirstChildOfClass("ForceField") then
				debug.profileend()
				return
			end
			local healthBefore = npcHumanoid.Health
			npcHumanoid.Health = math.max(0, healthBefore - damage)
			setCreatorTag(attacker, npcHumanoid, 0)

			AimChamberLink.recordPlayerHit(attacker, 1)
		end

		local npcName = if npcHumanoid and npcHumanoid.Parent then npcHumanoid.Parent.Name else "NPC"
		local screenWatch = getScreenWatchService()
		if screenWatch and typeof(screenWatch.NotifyHit) == "function" then
			screenWatch:NotifyHit(attacker.UserId, 0, damage, bodyPart, verifiedHead, gunIndex, npcName)
		end

		updateDamageStats(attacker, damage, countStats)
		debug.profileend()
		return
	end

	if checkMutualKill(attacker, targetId, verifiedHead, gunIndex, countStats) then
		debug.profileend()
		return
	end

	local attackerHumanoid = getHumanoidFromUserId(attacker.UserId)
	local isAttackerDead = not attackerHumanoid or attackerHumanoid.Health <= 0
	if isAttackerDead then
		local deathEntry = recentDeaths[attacker.UserId]
		if not deathEntry or (os.clock() - deathEntry.time) > MUTUAL_KILL_WINDOW then
			debug.profileend()
			return
		end
	end

	local cachedTarget = PlayerCache.getByUserId(targetId)
	local targetPlayer = cachedTarget and cachedTarget.player
	if targetPlayer and FactionUtils.isSpectator(targetPlayer) then
		debug.profileend()
		return
	end
	if targetPlayer and not FactionUtils.areEnemies(attacker, targetPlayer) then
		debug.profileend()
		return
	end

	local humanoid = getHumanoidFromUserId(targetId)
	if not humanoid then
		debug.profileend()
		return
	end

	local humanoidParent = humanoid.Parent
	if humanoidParent and humanoidParent:FindFirstChildOfClass("ForceField") then
		debug.profileend()
		return
	end

	logHit(targetId, attacker.UserId, localOffset, bodyPart, damage, gunIndex, verifiedHead)
	logOutgoing(attacker.UserId, targetId, damage, gunIndex, verifiedHead)

	local screenWatch = getScreenWatchService()
	if screenWatch and typeof(screenWatch.NotifyHit) == "function" then
		screenWatch:NotifyHit(attacker.UserId, targetId, damage, bodyPart, verifiedHead, gunIndex, nil, localOffset)
	end

	if not assistDamage[targetId] then
		assistDamage[targetId] = {}
	end
	assistDamage[targetId][attacker.UserId] = (assistDamage[targetId][attacker.UserId] or 0) + damage

	updateDamageStats(attacker, damage, countStats)

	local healthBefore = humanoid.Health
	if healthBefore < 1000000 then
		local gunService = getGunService()
		if gunService and gunService.registerValidHit then
			gunService.registerValidHit(attacker.UserId, 1)
		end
	end
	humanoid.Health = math.max(0, healthBefore - damage)
	setCreatorTag(attacker, humanoid, targetId)

	if humanoid.Health <= 0 then
		local isMutual = false
		local attackerDeath = recentDeaths[attacker.UserId]
		if attackerDeath and attackerDeath.killedBy == targetId and (os.clock() - attackerDeath.time) <= MUTUAL_KILL_WINDOW then
			isMutual = true
		end

		processKill(attacker, humanoid, verifiedHead, gunIndex, targetId, countStats, isMutual)
	end

	debug.profileend()
end

local function isHitPlausible(player: Player, targetId: number, localOffset: Vector3): boolean
	local ping = player:GetNetworkPing()
	local target = Players:GetPlayerByUserId(targetId)
	if not target or not target.Character then
		return false
	end

	local hrp = target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return false
	end

	local MAX_WALK_SPEED = 24
	local leniency = (ping * MAX_WALK_SPEED) + 6

	local claimedWorldPos = hrp.CFrame:PointToWorldSpace(localOffset)
	local dist = (claimedWorldPos - hrp.Position).Magnitude

	return dist <= leniency
end

function DamageProcessor.applyDamageImmediate(
	attacker: Player,
	targetId: number,
	clientDamage: number,
	head: boolean,
	localOffset: Vector3,
	bodyPart: number,
	gunIndex: number,
	worldHitPos: Vector3?
): ()
	if targetId ~= 0 and not isHitPlausible(attacker, targetId, localOffset) then
		debug.profileend()
		return
	end

	processHitInternal(attacker, targetId, clientDamage, head, localOffset, bodyPart, gunIndex, worldHitPos)
end

function DamageProcessor.processBatch(
	attacker: Player,
	hits: {
		{
			targetId: number,
			damage: number,
			head: boolean,
			pos: Vector3,
			bodyPart: number?,
		}
	},
	count: number,
	gunIndex: number
): ()
	if FactionUtils.isSpectator(attacker) then
		return
	end

	local attackerHumanoid = getHumanoidFromUserId(attacker.UserId)
	local isAttackerDead = not attackerHumanoid or attackerHumanoid.Health <= 0

	if isAttackerDead then
		local deathEntry = recentDeaths[attacker.UserId]
		if not deathEntry or (os.clock() - deathEntry.time) > MUTUAL_KILL_WINDOW then
			return
		end
	end

	for i = 1, count do
		local hit = hits[i]
		if hit then
			local worldPos = if hit.targetId == 0 then hit.pos else nil
			processHitInternalUnchecked(attacker, hit.targetId, hit.damage, hit.head, hit.pos, hit.bodyPart or 2, gunIndex, worldPos)
		end
	end
end

function DamageProcessor.applyDamage(
	attacker: Player,
	hit: {
		targetId: number,
		damage: number,
		head: boolean,
		pos: Vector3,
		bodyPart: number?,
	},
	gunIndex: number
): ()
	processHitInternal(attacker, hit.targetId, hit.damage, hit.head, hit.pos, hit.bodyPart or 2, gunIndex, nil)
end

function DamageProcessor.applyExplosionDamage(attacker: Player, targetId: number, damage: number, gunIndex: number): ()
	if targetId == 0 or damage <= 0 then
		return
	end
	processHitInternalUnchecked(attacker, targetId, damage, false, Vector3.zero, 2, gunIndex, nil, damage)
end

function DamageProcessor.invalidateStatsCache(): ()
	countStatsDirty = true
end

function DamageProcessor.registerHeal(targetId: number, healAmount: number): ()
	local attackers = assistDamage[targetId]
	if not attackers then
		return
	end
	
	local total = 0
	for _, dmg in attackers do
		total += dmg
	end
	
	if total > 0 then
		for id, dmg in attackers do
			attackers[id] = math.max(0, dmg - healAmount * (dmg / total))
		end
	end
end

return DamageProcessor
