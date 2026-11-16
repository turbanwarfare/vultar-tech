--!strict
--!optimize 2

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local MainModule = script.Parent.Parent.Parent.Parent
local SparConfig = require(MainModule.Shared.Config.SparConfig)
local ArenaStatsService = require(script.Parent.ArenaStatsService)

local version = SparConfig.DATA_VERSION or ""
local SparPairAggStore = DataStoreService:GetDataStore("SparPairAgg" .. version)
local AuditLogStore = DataStoreService:GetDataStore("SparViacomAuditLog" .. version)
local SparPlayerFlagIndexStore = DataStoreService:GetDataStore("SparPlayerFlagIndex" .. version)

type PairCounter = {
	matchCount: number,
	p1Kills: number,
	p2Kills: number,
	totalRounds: number,
	totalDuration: number,
}

type PairAggregate = {
	standard: PairCounter,
	instant: PairCounter,
	windowStart: number,
	windowEnd: number,
	p1Id: number,
	p2Id: number,
}

local ArenaKillFarmService = {}

local singleMatchCooldowns: { [string]: number } = {}
local pairWindowCooldowns: { [string]: number } = {}
local isShuttingDown = false

game:BindToClose(function()
	isShuttingDown = true
end)

local WEBHOOK_URL = "REPLACE_WITH_YOUR_WEBHOOK_URL"

local WINDOW_SECONDS = SparConfig.KILL_FARM_WINDOW_SECONDS
local MIN_MATCHES = SparConfig.KILL_FARM_MIN_MATCHES_TO_SCORE
local ALERT_COOLDOWN = SparConfig.KILL_FARM_ALERT_COOLDOWN

local VOLUME_BASELINE = SparConfig.KILL_FARM_VOLUME_MATCH_BASELINE
local MUTUAL_ROUND_BASELINE = SparConfig.KILL_FARM_MUTUAL_ROUND_BASELINE

local POP_AVG = SparConfig.KILL_FARM_POP_AVG_ROUND_DURATION
local POP_STDDEV = SparConfig.KILL_FARM_POP_STDDEV_ROUND_DURATION
local IR_POP_AVG = SparConfig.KILL_FARM_INSTANT_POP_AVG_ROUND_DURATION
local IR_POP_STDDEV = SparConfig.KILL_FARM_INSTANT_POP_STDDEV_ROUND_DURATION

local W_VOLUME = SparConfig.KILL_FARM_W_VOLUME
local W_SKEW = SparConfig.KILL_FARM_W_SKEW
local W_MUTUAL = SparConfig.KILL_FARM_W_MUTUAL
local W_SPEED = SparConfig.KILL_FARM_W_SPEED
local W_DPK = SparConfig.KILL_FARM_W_DPK

local FEEDING_THRESHOLD = SparConfig.KILL_FARM_FEEDING_THRESHOLD
local MUTUAL_THRESHOLD = SparConfig.KILL_FARM_MUTUAL_THRESHOLD

local SINGLE_ROUND_THRESHOLD = SparConfig.KILL_FARM_SINGLE_MATCH_ROUND_THRESHOLD
local SINGLE_SKEW_THRESHOLD = SparConfig.KILL_FARM_SINGLE_MATCH_SKEW_THRESHOLD
local SINGLE_SPEED_THRESHOLD = SparConfig.KILL_FARM_SINGLE_MATCH_SPEED_THRESHOLD
local SINGLE_INSTANT_SPEED_THRESHOLD = SparConfig.KILL_FARM_SINGLE_MATCH_INSTANT_SPEED_THRESHOLD
local SINGLE_ALERT_COOLDOWN = SparConfig.KILL_FARM_SINGLE_MATCH_ALERT_COOLDOWN

local function getPairKey(idA: number, idB: number): string
	if idA < idB then
		return tostring(idA) .. "_" .. tostring(idB)
	end
	return tostring(idB) .. "_" .. tostring(idA)
end

local function clamp01(v: number): number
	return if v < 0 then 0 elseif v > 1 then 1 else v
end

local function writeAuditFlag(
	p1Id: number,
	p2Id: number,
	flagType: "MUTUAL_FARM" | "FEEDING_SUSPECTED",
	feedingScore: number,
	mutualScore: number,
	signals: { [string]: number },
	matchId: string
)
	local entry: ArenaStatsService.AuditLogEntry = {
		staffUserId = 0,
		staffName = "SYSTEM",
		searchedUserId = p1Id,
		searchedName = tostring(p1Id),
		timestamp = os.time(),
		matchIdsViewed = { matchId },
		entryType = "KillFarmFlag",
		flagType = flagType,
		flaggedPairIds = { p1Id, p2Id },
		feedingScore = feedingScore,
		mutualScore = mutualScore,
		rawSignals = signals,
		triggerMatchId = matchId,
	}

	local success = pcall(function()
		AuditLogStore:UpdateAsync("AuditLog", function(old: any)
			old = old or {}
			local count = #old
			table.move(old, 1, count, 2)
			old[1] = entry
			local max = SparConfig.VIACOM_AUDIT_LOG_MAX or 500
			if count + 1 > max then
				old[max + 1] = nil
			end
			return old
		end)
	end)

	if success then
		task.spawn(function()
			pcall(function()
				SparPlayerFlagIndexStore:UpdateAsync("FlagIndex_" .. p1Id, function(old: any)
					old = old or {}
					local count = #old
					table.move(old, 1, count, 2)
					old[1] = entry
					if count + 1 > 10 then
						old[11] = nil
					end
					return old
				end)
			end)
		end)

		task.spawn(function()
			pcall(function()
				SparPlayerFlagIndexStore:UpdateAsync("FlagIndex_" .. p2Id, function(old: any)
					old = old or {}
					local count = #old
					table.move(old, 1, count, 2)
					old[1] = entry
					if count + 1 > 10 then
						old[11] = nil
					end
					return old
				end)
			end)
		end)
	end
end

local function fireWebhook(
	path: "single" | "window",
	flagType: "MUTUAL_FARM" | "FEEDING_SUSPECTED",
	p1Id: number,
	p1Name: string,
	p2Id: number,
	p2Name: string,
	matchId: string,
	completedRounds: number,
	duration: number,
	vWins: number,
	hWins: number,
	extraFields: { { name: string, value: string, inline: boolean } }
)
	local riskColor = if flagType == "FEEDING_SUSPECTED" then 0xFF3040 else 0xFF8C00
	local pathLabel = if path == "single" then "Single-Match" else "Rolling Window"

	local embed = {
		author = { name = "Vultarian Combat Arena" },
		title = string.format("Kill Farm |  %s [%s]", flagType, pathLabel),
		color = riskColor,
		thumbnail = {
			url = string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png", p1Id),
		},
		fields = {
			{ name = "Player 1", value = string.format("%s (%d)", p1Name, p1Id), inline = true },
			{ name = "Player 2", value = string.format("%s (%d)", p2Name, p2Id), inline = true },
			{ name = "\u{200B}", value = "\u{200B}", inline = true },
			{ name = "Match ID", value = matchId, inline = false },
			{ name = "Completed Rounds", value = tostring(completedRounds), inline = true },
			{ name = "Duration", value = string.format("%.0fs", duration), inline = true },
			{ name = "Kill Split", value = string.format("%d / %d", vWins, hWins), inline = true },
		},
		footer = { text = "VULTARIAN DEFENSE INDUSTRIES" },
		timestamp = DateTime.now():ToIsoDate(),
	}

	for _, field in extraFields do
		table.insert(embed.fields, field)
	end

	local payload = HttpService:JSONEncode({
		username = "Vultarian Combat Arena",
		embeds = { embed },
	})

	pcall(HttpService.PostAsync, HttpService, WEBHOOK_URL, payload, Enum.HttpContentType.ApplicationJson)
end

function ArenaKillFarmService.CheckSingleMatchKillFarm(record: ArenaStatsService.MatchRecord)
	if record.GameType ~= "Spar" then
		return
	end

	local p1Id = record.VultarianId
	local p2Id = record.HostileId
	if p1Id <= 0 or p2Id <= 0 or p1Id == p2Id then
		return
	end

	local pairKey = getPairKey(p1Id, p2Id)
	local now = os.time()
	local lastAlert = singleMatchCooldowns[pairKey]
	if lastAlert and now - lastAlert < SINGLE_ALERT_COOLDOWN then
		return
	end

	local completedRounds = record.CompletedRounds or record.Rounds
	if completedRounds < SINGLE_ROUND_THRESHOLD then
		return
	end

	local totalKills = record.VultarianWins + record.HostileWins
	local killerKills = math.max(record.VultarianWins, record.HostileWins)
	local victimKills = math.min(record.VultarianWins, record.HostileWins)
	local singleSkew = (killerKills - victimKills) / math.max(1, totalKills)
	local avgRoundDur = record.Duration / math.max(1, completedRounds)

	local speedThreshold = if record.InstantRespawn then SINGLE_INSTANT_SPEED_THRESHOLD else SINGLE_SPEED_THRESHOLD
	local skewFlag = singleSkew >= SINGLE_SKEW_THRESHOLD
	local speedFlag = avgRoundDur <= speedThreshold

	local flagType: ("MUTUAL_FARM" | "FEEDING_SUSPECTED")?
	if skewFlag then
		flagType = "FEEDING_SUSPECTED"
	elseif speedFlag then
		flagType = "MUTUAL_FARM"
	end

	if not flagType then
		return
	end

	singleMatchCooldowns[pairKey] = now

	local resolvedFlagType = flagType :: "MUTUAL_FARM" | "FEEDING_SUSPECTED"

	local extraFields: { { name: string, value: string, inline: boolean } } = {
		{ name = "Avg Sec/Round", value = string.format("%.1f", avgRoundDur), inline = true },
		{ name = "Kill Skew", value = string.format("%.2f", singleSkew), inline = true },
		{ name = "Instant Respawn", value = tostring(record.InstantRespawn), inline = true },
	}

	fireWebhook(
		"single",
		resolvedFlagType,
		p1Id,
		record.VultarianName,
		p2Id,
		record.HostileName,
		record.MatchId,
		completedRounds,
		record.Duration,
		record.VultarianWins,
		record.HostileWins,
		extraFields
	)

	writeAuditFlag(p1Id, p2Id, resolvedFlagType, if skewFlag then 1.0 else 0.0, if not skewFlag and speedFlag then 1.0 else 0.0, {
		S_skew = singleSkew,
		avgRoundDur = avgRoundDur,
		completedRounds = completedRounds,
	}, record.MatchId)
end

local function emptyCounter(): PairCounter
	return {
		matchCount = 0,
		p1Kills = 0,
		p2Kills = 0,
		totalRounds = 0,
		totalDuration = 0,
	}
end

function ArenaKillFarmService.CheckPairWindowKillFarm(record: ArenaStatsService.MatchRecord)
	if record.GameType ~= "Spar" then
		return
	end

	local vId = record.VultarianId
	local hId = record.HostileId
	if vId <= 0 or hId <= 0 or vId == hId then
		return
	end

	local pairKey = getPairKey(vId, hId)
	local sortedP1Id = math.min(vId, hId)
	local sortedP2Id = math.max(vId, hId)
	local sortedP1Wins = if sortedP1Id == vId then record.VultarianWins else record.HostileWins
	local sortedP2Wins = if sortedP2Id == vId then record.VultarianWins else record.HostileWins

	local storeKey = "Pair_" .. pairKey
	local completedRounds = record.CompletedRounds or record.Rounds
	local now = os.time()
	local isIR = record.InstantRespawn == true

	local capturedAgg: PairAggregate? = nil

	pcall(function()
		SparPairAggStore:UpdateAsync(storeKey, function(old: any): PairAggregate
			local existing: PairAggregate = if old ~= nil
				then old :: PairAggregate
				else {
					standard = emptyCounter(),
					instant = emptyCounter(),
					windowStart = now,
					windowEnd = now,
					p1Id = sortedP1Id,
					p2Id = sortedP2Id,
				}

			if not existing.standard then
				existing.standard = emptyCounter()
			end
			if not existing.instant then
				existing.instant = emptyCounter()
			end

			if now - existing.windowStart > WINDOW_SECONDS then
				existing.standard = emptyCounter()
				existing.instant = emptyCounter()
				existing.windowStart = now
			end

			local counter: PairCounter = if isIR then existing.instant else existing.standard
			counter.matchCount += 1
			counter.p1Kills += sortedP1Wins
			counter.p2Kills += sortedP2Wins
			counter.totalRounds += completedRounds
			counter.totalDuration += record.Duration

			existing.windowEnd = now
			existing.p1Id = sortedP1Id
			existing.p2Id = sortedP2Id

			capturedAgg = table.clone(existing)
			return existing
		end)
	end)

	if not capturedAgg then
		return
	end

	local aggregate: PairAggregate = capturedAgg :: PairAggregate

	local stdCounter = aggregate.standard
	local irCounter = aggregate.instant
	local combinedMatchCount = stdCounter.matchCount + irCounter.matchCount
	local combinedTotalRounds = stdCounter.totalRounds + irCounter.totalRounds
	local combinedP1Kills = stdCounter.p1Kills + irCounter.p1Kills
	local combinedP2Kills = stdCounter.p2Kills + irCounter.p2Kills

	if combinedMatchCount < MIN_MATCHES then
		return
	end

	local lastAlert = pairWindowCooldowns[pairKey]
	if lastAlert and now - lastAlert < ALERT_COOLDOWN then
		return
	end

	local totalKills = combinedP1Kills + combinedP2Kills

	local activeCounter: PairCounter = if isIR then irCounter else stdCounter
	local activeAvg = if isIR then IR_POP_AVG else POP_AVG
	local activeStddev = if isIR then IR_POP_STDDEV else POP_STDDEV
	local activeAvgRoundDur = activeCounter.totalDuration / math.max(1, activeCounter.totalRounds)

	local S_volume = clamp01(combinedMatchCount / VOLUME_BASELINE)
	local S_skew = math.abs(combinedP1Kills - combinedP2Kills) / math.max(1, totalKills)
	local S_mutual = (1 - S_skew) * clamp01(combinedTotalRounds / MUTUAL_ROUND_BASELINE)
	local S_speed = if activeCounter.totalRounds > 0
		then clamp01(((activeAvg - activeAvgRoundDur) / math.max(1, activeStddev)) / 3)
		else 0
	local S_dpk: number = W_DPK * 0

	local feedingScore = (W_VOLUME * S_volume) + (W_SKEW * S_skew) + (W_SPEED * S_speed) + S_dpk
	local mutualScore = (W_VOLUME * S_volume) + (W_MUTUAL * S_mutual) + (W_SPEED * S_speed) + S_dpk

	local firedFeeding = feedingScore >= FEEDING_THRESHOLD
	local firedMutual = mutualScore >= MUTUAL_THRESHOLD

	if not firedFeeding and not firedMutual then
		return
	end

	pairWindowCooldowns[pairKey] = now

	local signals: { [string]: number } = {
		S_volume = S_volume,
		S_skew = S_skew,
		S_mutual = S_mutual,
		S_speed = S_speed,
		S_dpk = 0,
	}

	local sharedFields: { { name: string, value: string, inline: boolean } } = {
		{ name = "S_volume", value = string.format("%.3f", S_volume), inline = true },
		{ name = "S_skew", value = string.format("%.3f", S_skew), inline = true },
		{ name = "S_mutual", value = string.format("%.3f", S_mutual), inline = true },
		{ name = "S_speed", value = string.format("%.3f", S_speed), inline = true },
		{ name = "Window Matches", value = tostring(combinedMatchCount), inline = true },
		{ name = "Window Rounds", value = tostring(combinedTotalRounds), inline = true },
	}

	if firedFeeding or firedMutual then
		local p1Name = if aggregate.p1Id == record.VultarianId then record.VultarianName else record.HostileName
		local p2Name = if aggregate.p2Id == record.VultarianId then record.VultarianName else record.HostileName

		if firedFeeding then
			local extraFields = table.clone(sharedFields)
			extraFields[#extraFields + 1] = {
				name = "FEEDING SCORE",
				value = string.format("%.3f / %.2f threshold", feedingScore, FEEDING_THRESHOLD),
				inline = false,
			}
			fireWebhook(
				"window",
				"FEEDING_SUSPECTED",
				aggregate.p1Id,
				p1Name,
				aggregate.p2Id,
				p2Name,
			record.MatchId,
			combinedTotalRounds,
			stdCounter.totalDuration + irCounter.totalDuration,
			combinedP1Kills,
			combinedP2Kills,
			extraFields
		)
		writeAuditFlag(aggregate.p1Id, aggregate.p2Id, "FEEDING_SUSPECTED", feedingScore, mutualScore, signals, record.MatchId)
	end

		if firedMutual and not firedFeeding then
			local extraFields = table.clone(sharedFields)
			extraFields[#extraFields + 1] = {
				name = "MUTUAL SCORE",
				value = string.format("%.3f / %.2f threshold", mutualScore, MUTUAL_THRESHOLD),
				inline = false,
			}
			fireWebhook(
				"window",
				"MUTUAL_FARM",
				aggregate.p1Id,
				p1Name,
				aggregate.p2Id,
				p2Name,
			record.MatchId,
			combinedTotalRounds,
			stdCounter.totalDuration + irCounter.totalDuration,
			combinedP1Kills,
			combinedP2Kills,
			extraFields
		)
			writeAuditFlag(aggregate.p1Id, aggregate.p2Id, "MUTUAL_FARM", feedingScore, mutualScore, signals, record.MatchId)
		end
	end
end

task.spawn(function()
	while not isShuttingDown do
		task.wait(600)
		local now = os.time()
		for key, ts in singleMatchCooldowns do
			if now - ts > SINGLE_ALERT_COOLDOWN then
				singleMatchCooldowns[key] = nil
			end
		end
		for key, ts in pairWindowCooldowns do
			if now - ts > ALERT_COOLDOWN then
				pairWindowCooldowns[key] = nil
			end
		end
	end
end)

return ArenaKillFarmService

