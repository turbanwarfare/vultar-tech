--!strict
--!native
--!optimize 2

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local SparringServiceFolder = script.Parent
local MainModule = SparringServiceFolder.Parent.Parent.Parent
local SparConfig = require(MainModule.Shared.Config.SparConfig)
local Constants = require(MainModule.Shared.Config.Constants)
local Network = require(MainModule.Shared.Network)
local RankCache = require(MainModule.Server.Cache.RankCache)
local ArenaTitleService = require(SparringServiceFolder.ArenaTitleService)
local ArenaLeaderboardService = require(SparringServiceFolder.ArenaLeaderboardService)

local version = SparConfig.DATA_VERSION or ""
local SparStats = DataStoreService:GetDataStore("SparStatsV2" .. version)
local LeaderboardStore = DataStoreService:GetDataStore("SparLeaderboard" .. version)

local MatchRecordStore = DataStoreService:GetDataStore("SparMatchRecords" .. version)
local PlayerMatchIndexStore = DataStoreService:GetDataStore("SparPlayerMatchIndex" .. version)
local MatchTimeIndexStore = DataStoreService:GetOrderedDataStore("SparMatchTimeIndex" .. version)
local AuditLogStore = DataStoreService:GetDataStore("SparViacomAuditLog" .. version)
local SparPlayerFlagIndexStore = DataStoreService:GetDataStore("SparPlayerFlagIndex" .. version)

export type RoundBreakdownEntry = {
	round: number,
	winnerId: number,
	winnerName: string,
	p1Health: number,
	p2Health: number,
}

export type MatchRecord = {
	MatchId: string,
	GameType: string,
	WinnerId: number,
	WinnerName: string,
	LoserId: number,
	LoserName: string,
	Timestamp: number,
	EndTimestamp: number,
	Duration: number,
	MapName: string,
	GunName: string,
	Rounds: number,
	HealthOption: string,
	VultarianId: number,
	VultarianName: string,
	HostileId: number,
	HostileName: string,
	VultarianWins: number,
	HostileWins: number,
	Player1UserId: number,
	Player2UserId: number,
	RoundBreakdown: { RoundBreakdownEntry },
	Player1EndHealth: number,
	Player2EndHealth: number,
	InstantRespawn: boolean,
}

export type PlayerHistory = {
	AllTime: { [string]: number },
	LastDay: { [string]: number },
	LastWeek: { [string]: number },
	LastMonth: { [string]: number },
	LastReset: number,
	LastDayReset: number,
	LastWeekReset: number,
	LastMonthReset: number,
	UnlockedTitles: { [string]: boolean },
	MatchHistory: { MatchRecord },
}

export type AuditLogEntry = {
	staffUserId: number,
	staffName: string,
	searchedUserId: number,
	searchedName: string,
	timestamp: number,
	matchIdsViewed: { string },
}

local ArenaStatsService = {}

local function buildLabelLookup(...: { string }): { [string]: boolean }
	local lookup: { [string]: boolean } = {}
	for _, list in { ... } do
		for _, entry in list do
			lookup[entry] = true
		end
	end
	return lookup
end

local SYSTEM_MAP_LABELS = { "Unknown", "Sparring Arena" }
local SYSTEM_GUN_LABELS = { "Unknown", "Spar", "VDI_INJECTED" }

local VALID_RECORD_MAPS = buildLabelLookup(SparConfig.MAP_NAMES, SparConfig.ACTUAL_MAP_NAMES, SYSTEM_MAP_LABELS)
local VALID_RECORD_GUNS = buildLabelLookup(SparConfig.GUN_NAMES, SYSTEM_GUN_LABELS)

local function sanitizeLabel(value: unknown, allowed: { [string]: boolean }): string
	if type(value) ~= "string" then
		return "Unknown"
	end
	return if allowed[value] then value else "Unknown"
end

local function sanitizeHealthLabel(value: unknown): string
	local count = tonumber(value)
	if not count or count ~= math.floor(count) or count < 1 or count > SparConfig.MAX_CUSTOM_HEALTH then
		return "100"
	end
	return tostring(count)
end

local SYSTEM_NAME_LABELS = { Tie = true, Unknown = true }

local function sanitizeUsername(value: unknown): string
	if type(value) ~= "string" then
		return "Unknown"
	end
	if SYSTEM_NAME_LABELS[value] then
		return value
	end
	if #value < 3 or #value > 20 or not string.match(value, "^[%w_]+$") then
		return "Unknown"
	end
	return value
end

local function sanitizeMatchRecord(record: any): any
	if type(record) ~= "table" then
		return record
	end
	record.MapName = sanitizeLabel(record.MapName, VALID_RECORD_MAPS)
	record.GunName = sanitizeLabel(record.GunName, VALID_RECORD_GUNS)
	record.HealthOption = sanitizeHealthLabel(record.HealthOption)
	record.WinnerName = sanitizeUsername(record.WinnerName)
	record.LoserName = sanitizeUsername(record.LoserName)
	record.VultarianName = sanitizeUsername(record.VultarianName)
	record.HostileName = sanitizeUsername(record.HostileName)

	if type(record.RoundBreakdown) == "table" then
		for _, entry in record.RoundBreakdown do
			if type(entry) == "table" then
				entry.winnerName = sanitizeUsername(entry.winnerName)
			end
		end
	end

	return record
end

local function sanitizeMatchRecords(records: any): any
	if type(records) ~= "table" then
		return records
	end
	for _, record in records do
		sanitizeMatchRecord(record)
	end
	return records
end

local playerHistory: { [number]: PlayerHistory } = {}
local pendingSaves: { [number]: boolean } = {}
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local viacomExportCooldowns: { [number]: number } = {}
local winTradeAlertCooldowns: { [string]: number } = {}

local isShuttingDown = false
local activeDataStoreRequests = 0

game:BindToClose(function()
	isShuttingDown = true

	for userId, _ in playerHistory do
		activeDataStoreRequests += 1
		task.spawn(function()
			ArenaStatsService.ForceSaveUserId(userId)
			activeDataStoreRequests -= 1
		end)
	end

	local waited = 0
	while activeDataStoreRequests > 0 and waited < 25 do
		task.wait(1)
		waited += 1
	end
end)

local SAVE_DELAY = 15
local DAY = 24 * 60 * 60
local WEEK = 7 * 24 * 60 * 60
local MONTH = 30.44 * 24 * 60 * 60
local MAX_MATCH_HISTORY = 20
local WIN_TRADE_MIN_MATCHES_AGAINST_OPPONENT = 6
local WIN_TRADE_ALERT_COOLDOWN = SparConfig.WIN_TRADE_ALERT_COOLDOWN or 1800
local WIN_TRADE_SCORE_THRESHOLD = SparConfig.WIN_TRADE_SCORE_THRESHOLD or 7

local function buildDefaultHistory(): PlayerHistory
	return {
		AllTime = table.clone(SparConfig.STATS_DEFAULT),
		LastDay = table.clone(SparConfig.STATS_DEFAULT),
		LastWeek = table.clone(SparConfig.STATS_DEFAULT),
		LastMonth = table.clone(SparConfig.STATS_DEFAULT),
		LastReset = os.time(),
		LastDayReset = os.time(),
		LastWeekReset = os.time(),
		LastMonthReset = os.time(),
		UnlockedTitles = {},
		MatchHistory = {},
	}
end

local function rotateIfNeeded(history: PlayerHistory)
	local now = os.time()

	history.LastDayReset = history.LastDayReset or history.LastReset
	history.LastWeekReset = history.LastWeekReset or history.LastReset
	history.LastMonthReset = history.LastMonthReset or history.LastReset

	if (now - history.LastDayReset) >= DAY then
		history.LastDay = table.clone(SparConfig.STATS_DEFAULT)
		history.LastDayReset = now
	end

	if (now - history.LastWeekReset) >= WEEK then
		history.LastWeek = table.clone(SparConfig.STATS_DEFAULT)
		history.LastWeekReset = now
	end

	if (now - history.LastMonthReset) >= MONTH then
		history.LastMonth = table.clone(SparConfig.STATS_DEFAULT)
		history.LastMonthReset = now
	end

	history.LastReset = now
end

local function getHistory(userId: number): PlayerHistory?
	local history = playerHistory[userId]
	if history then
		rotateIfNeeded(history)
	end
	return history
end

local function pushMatchRecord(history: PlayerHistory, record: MatchRecord)
	local matchHistory = history.MatchHistory
	local count = #matchHistory
	table.move(matchHistory, 1, count, 2)
	matchHistory[1] = record
	if count + 1 > MAX_MATCH_HISTORY then
		matchHistory[MAX_MATCH_HISTORY + 1] = nil
	end
end

local function writeIndexedMatchRecord(record: MatchRecord)
	if record.GameType ~= "Spar" then
		return
	end

	local matchId = record.MatchId
	local timestamp = record.Timestamp
	local recordSuccess = pcall(function()
		MatchRecordStore:SetAsync("Match_" .. matchId, record)
	end)

	local timeIndexSuccess = pcall(function()
		MatchTimeIndexStore:SetAsync(matchId, timestamp)
	end)

	local playerIds = { record.Player1UserId, record.Player2UserId }
	for _, userId in playerIds do
		if userId > 0 then
			pcall(function()
				PlayerMatchIndexStore:UpdateAsync("Index_" .. userId, function(old: any)
					old = old or {}
					local count = #old
					table.move(old, 1, count, 2)
					old[1] = matchId
					local max = SparConfig.VIACOM_MAX_PER_PLAYER_MATCHES or 200
					if count + 1 > max then
						local trimmed = {}
						for i = 1, max do
							trimmed[i] = old[i]
						end
						return trimmed
					end
					return old
				end)
			end)
		end
	end

	if not recordSuccess or not timeIndexSuccess then
		task.delay(2, function()
			activeDataStoreRequests += 1
			pcall(function()
				MatchRecordStore:SetAsync("Match_" .. matchId, record)
			end)
			pcall(function()
				MatchTimeIndexStore:SetAsync(matchId, timestamp)
			end)
			activeDataStoreRequests -= 1
		end)
	end

	task.spawn(function()
		local killFarmModule = SparringServiceFolder and SparringServiceFolder:FindFirstChild("ArenaKillFarmService")
		if killFarmModule then
			local ArenaKillFarmService = require(killFarmModule)
			if ArenaKillFarmService then
				ArenaKillFarmService.CheckSingleMatchKillFarm(record)
				ArenaKillFarmService.CheckPairWindowKillFarm(record)
			end
		end
	end)
end

function ArenaStatsService.LoadPlayer(player: Player): PlayerHistory?
	if not player then
		return nil
	end
	local key = "History_" .. player.UserId
	local success, saved = pcall(function()
		return SparStats:GetAsync(key)
	end)
	local history = buildDefaultHistory()
	if success and type(saved) == "table" then
		if saved.AllTime then
			for k, v in saved.AllTime do
				history.AllTime[k] = v
			end
		end
		if saved.LastDay then
			for k, v in saved.LastDay do
				history.LastDay[k] = v
			end
		end
		if saved.LastWeek then
			for k, v in saved.LastWeek do
				history.LastWeek[k] = v
			end
		end
		if saved.LastMonth then
			for k, v in saved.LastMonth do
				history.LastMonth[k] = v
			end
		end
		if saved.LastReset then
			history.LastReset = saved.LastReset
		end
		if saved.LastDayReset then
			history.LastDayReset = saved.LastDayReset
		end
		if saved.LastWeekReset then
			history.LastWeekReset = saved.LastWeekReset
		end
		if saved.LastMonthReset then
			history.LastMonthReset = saved.LastMonthReset
		end
		if saved.UnlockedTitles then
			history.UnlockedTitles = saved.UnlockedTitles
		end
		if saved.MatchHistory then
			history.MatchHistory = saved.MatchHistory
		else
			history.MatchHistory = {}
		end
	end
	rotateIfNeeded(history)
	playerHistory[player.UserId] = history

	player:SetAttribute("SparWins", history.AllTime.MatchesWon or 0)
	player:SetAttribute("SparStreak", history.AllTime.Streak or 0)

	ArenaLeaderboardService.UpdatePlayerStats(player, history)

	return history
end

function ArenaStatsService.GetPlayerStats(player: Player): PlayerHistory?
	if not player then
		return nil
	end
	return getHistory(player.UserId)
end

function ArenaStatsService.IncrementStat(player: Player, statName: string, amount: number): number
	if not player then
		return 0
	end
	local history = getHistory(player.UserId)
	if not history then
		warn(string.format("[ArenaStatsService] IncrementStat: history not loaded for %s (%d) | stat '%s' dropped", player.Name, player.UserId, statName))
		return 0
	end
	local old = history.AllTime[statName] or 0
	history.AllTime[statName] = old + amount

	history.LastDay[statName] = (history.LastDay[statName] or 0) + amount
	history.LastWeek[statName] = (history.LastWeek[statName] or 0) + amount
	history.LastMonth[statName] = (history.LastMonth[statName] or 0) + amount

	ArenaStatsService.QueueSave(player)

	if statName == "MatchesWon" then
		player:SetAttribute("SparWins", history.AllTime.MatchesWon or 0)
	elseif statName == "Streak" then
		player:SetAttribute("SparStreak", history.AllTime.Streak or 0)
	end

	return history.AllTime[statName] or 0
end

function ArenaStatsService.AddDamage(player: Player, damage: number)
	ArenaStatsService.IncrementStat(player, "Damage", math.round(damage))
end

function ArenaStatsService.AddKill(player: Player, amount: number)
	ArenaStatsService.IncrementStat(player, "Kills", math.round(amount))
end

function ArenaStatsService.QueueSave(player: Player)
	local userId = player.UserId
	if pendingSaves[userId] then
		pendingSaves[userId] = "dirty"
		return
	end
	pendingSaves[userId] = true
	task.delay(SAVE_DELAY, function()
		if pendingSaves[userId] == nil then
			return
		end
		activeDataStoreRequests += 1
		ArenaStatsService.ForceSaveUserId(userId)
		activeDataStoreRequests -= 1
	end)
end

function ArenaStatsService.ForceSaveUserId(userId: number)
	local history = getHistory(userId)
	if not history then
		return
	end

	local data = {
		AllTime = table.clone(history.AllTime),
		LastDay = table.clone(history.LastDay),
		LastWeek = table.clone(history.LastWeek),
		LastMonth = table.clone(history.LastMonth),
		LastReset = history.LastReset,
		LastDayReset = history.LastDayReset,
		LastWeekReset = history.LastWeekReset,
		LastMonthReset = history.LastMonthReset,
		UnlockedTitles = history.UnlockedTitles,
		MatchHistory = history.MatchHistory,
	}

	local retries = 0
	local success = false
	while retries < 3 and not success do
		success, _ = pcall(function()
			SparStats:UpdateAsync("History_" .. userId, function(oldData: any)
				if not oldData then
					return data
				end

				oldData.AllTime = data.AllTime
				oldData.LastDay = data.LastDay
				oldData.LastWeek = data.LastWeek
				oldData.LastMonth = data.LastMonth
				oldData.LastReset = data.LastReset
				oldData.LastDayReset = data.LastDayReset
				oldData.LastWeekReset = data.LastWeekReset
				oldData.LastMonthReset = data.LastMonthReset
				oldData.UnlockedTitles = data.UnlockedTitles
				oldData.MatchHistory = data.MatchHistory
				return oldData
			end)
		end)
		if not success then
			retries += 1
			if retries < 3 then
				task.wait(2 ^ retries)
			end
		end
	end

	if not success then
		warn(string.format("[ArenaStatsService] ForceSaveUserId: all 3 retries failed for userId %d", userId))
	end

	local wasDirty = pendingSaves[userId] == "dirty"
	pendingSaves[userId] = nil
	if wasDirty then
		local player = Players:GetPlayerByUserId(userId)
		if player then
			ArenaStatsService.QueueSave(player)
		end
	end
end

function ArenaStatsService.ForceSave(player: Player)
	ArenaStatsService.ForceSaveUserId(player.UserId)
end

function ArenaStatsService.UpdateLeaderboard(player: Player, category: string, value: number)
	task.spawn(function()
		activeDataStoreRequests += 1
		pcall(function()
			LeaderboardStore:UpdateAsync(category, function(old: any)
				old = old or {}
				for _i, entry in old do
					if entry.userId == player.UserId then
						entry.value = value
						entry.name = player.Name
						return old
					end
				end
				table.insert(old, {
					userId = player.UserId,
					name = player.Name,
					value = value,
				})
				table.sort(old, function(a, b)
					return a.value > b.value
				end)
				if #old > 100 then
					local trimmed = {}
					for i = 1, 100 do
						trimmed[i] = old[i]
					end
					return trimmed
				end
				return old
			end)
		end)
		activeDataStoreRequests -= 1
	end)
end

function ArenaStatsService.RecordMatchResult(winner: Player?, loser: Player?, matchData: any?, isMutualMatchWin: boolean?)
	if not matchData then
		return
	end

	local gameType = matchData.GameType or "Spar"
	if gameType ~= "Spar" then
		return
	end

	local affectedPlayers: { Player } = {}
	if isMutualMatchWin then
		if matchData.player1 then
			local ok, err = pcall(function()
				ArenaStatsService.IncrementStat(matchData.player1, "MatchesWon", 1)
				ArenaStatsService.IncrementStat(matchData.player1, "MatchesPlayed", 1)
				ArenaStatsService.IncrementStat(matchData.player1, "Streak", 1)
			end)
			if not ok then
				warn("[ArenaStatsService] RecordMatchResult: error incrementing player1 stats:", err)
			end
			table.insert(affectedPlayers, matchData.player1)
		end
		if matchData.player2 and matchData.player2 ~= matchData.player1 then
			local ok, err = pcall(function()
				ArenaStatsService.IncrementStat(matchData.player2, "MatchesWon", 1)
				ArenaStatsService.IncrementStat(matchData.player2, "MatchesPlayed", 1)
				ArenaStatsService.IncrementStat(matchData.player2, "Streak", 1)
			end)
			if not ok then
				warn("[ArenaStatsService] RecordMatchResult: error incrementing player2 stats:", err)
			end
			table.insert(affectedPlayers, matchData.player2)
		end
	else
		if winner then
			local ok, err = pcall(function()
				ArenaStatsService.IncrementStat(winner, "MatchesWon", 1)
				ArenaStatsService.IncrementStat(winner, "MatchesPlayed", 1)
				ArenaStatsService.IncrementStat(winner, "Streak", 1)
			end)
			if not ok then
				warn("[ArenaStatsService] RecordMatchResult: error incrementing winner stats:", err)
			end
			table.insert(affectedPlayers, winner)
		end
		if loser then
			local ok, err = pcall(function()
				ArenaStatsService.IncrementStat(loser, "MatchesLost", 1)
				ArenaStatsService.IncrementStat(loser, "MatchesPlayed", 1)
			end)
			if not ok then
				warn("[ArenaStatsService] RecordMatchResult: error incrementing loser stats:", err)
			end
			table.insert(affectedPlayers, loser)
		end
	end

	for _, p in affectedPlayers do
		local uid = p.UserId

		if pendingSaves[uid] == nil then
			pendingSaves[uid] = true
		end

		activeDataStoreRequests += 1
		task.spawn(function()
			ArenaStatsService.ForceSaveUserId(uid)
			activeDataStoreRequests -= 1
			
			local history = getHistory(uid)
			if history then
				ArenaLeaderboardService.UpdatePlayerStats(p, history)
			end
		end)
	end

	local rinfo = matchData.roundInfo
	if not rinfo then
		return
	end

	local startTime = matchData.StartTime or os.time()
	local endTime = os.time()
	local duration = endTime - startTime
	local roundBreakdown: { RoundBreakdownEntry } = {}

	table.insert(roundBreakdown, {
		round = rinfo.currentRound,
		winnerId = winner and winner.UserId or 0,
		winnerName = winner and winner.Name or "Tie",
		p1Health = 0,
		p2Health = 0,
	})

	local p1EndHealth = 0
	local p2EndHealth = 0
	if matchData.player1 and matchData.player1.Character then
		local hum = matchData.player1.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			p1EndHealth = hum.Health
		end
	end
	if matchData.player2 and matchData.player2.Character then
		local hum = matchData.player2.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			p2EndHealth = hum.Health
		end
	end

	local matchId = matchData.MatchId
	if not matchId or matchId == "" then
		matchId = HttpService:GenerateGUID(false)
	end

	local record: MatchRecord = {
		MatchId = matchId,
		GameType = gameType,
		WinnerId = winner and winner.UserId or 0,
		WinnerName = winner and winner.Name or "Tie",
		LoserId = loser and loser.UserId or 0,
		LoserName = loser and loser.Name or "Tie",
		Timestamp = startTime,
		EndTimestamp = endTime,
		Duration = duration,
		MapName = rinfo.mapName or "Unknown",
		GunName = rinfo.gunName or "Unknown",
		Rounds = rinfo.totalRounds or 1,
		HealthOption = rinfo.healthName or "100",
		VultarianId = matchData.player1.UserId,
		VultarianName = matchData.player1.Name,
		HostileId = matchData.player2.UserId,
		HostileName = matchData.player2.Name,
		VultarianWins = rinfo.player1Wins,
		HostileWins = rinfo.player2Wins,
		Player1UserId = matchData.player1.UserId,
		Player2UserId = matchData.player2.UserId,
		RoundBreakdown = roundBreakdown,
		Player1EndHealth = p1EndHealth,
		Player2EndHealth = p2EndHealth,
		InstantRespawn = rinfo.instantRespawn == true,
	}

	local processed = {}
	for _, player in { matchData.player1, matchData.player2 } do
		if player and not processed[player.UserId] then
			processed[player.UserId] = true
			local history = getHistory(player.UserId)
			if history then
				if not history.MatchHistory then
					history.MatchHistory = {}
				end
				pushMatchRecord(history, record)
				ArenaStatsService.QueueSave(player)
			end
		end
	end

	task.spawn(function()
		activeDataStoreRequests += 1
		writeIndexedMatchRecord(record)
		activeDataStoreRequests -= 1
	end)

	if winner and loser then
		task.spawn(pcall, ArenaStatsService.CheckWinTrading, winner, loser, matchId)
	end
end

local function getWinTradePairKey(idA: number, idB: number): string
	if idA < idB then
		return idA .. "_" .. idB
	end
	return idB .. "_" .. idA
end

function ArenaStatsService.CheckWinTrading(winner: Player, loser: Player, matchId: string?)
	local winnerId = winner.UserId
	local loserId = loser.UserId

	local pairKey = getWinTradePairKey(winnerId, loserId)
	local now = os.time()
	local lastAlert = winTradeAlertCooldowns[pairKey]
	if lastAlert and now - lastAlert < WIN_TRADE_ALERT_COOLDOWN then
		return
	end

	local history = getHistory(winnerId)
	if not history or not history.MatchHistory then
		return
	end

	local matchesChecked = math.min(#history.MatchHistory, 20)
	if matchesChecked < 10 then
		return
	end

	local matchesAgainstOpponent = 0
	local winsAgainstOpponent = 0
	local consecutiveWins = 0
	local matchesLastHour = 0
	local totalDuration = 0
	local durationCount = 0

	local checkingConsecutive = true

	for i, r in ipairs(history.MatchHistory) do
		local isAgainstOpponent = (r.VultarianId == winnerId and r.HostileId == loserId) or (r.VultarianId == loserId and r.HostileId == winnerId)

		if checkingConsecutive then
			if isAgainstOpponent and r.WinnerId == winnerId then
				consecutiveWins += 1
			else
				checkingConsecutive = false
			end
		end

		if isAgainstOpponent then
			if i <= matchesChecked then
				matchesAgainstOpponent += 1
				if r.WinnerId == winnerId then
					winsAgainstOpponent += 1
				end
			end

			if now - r.Timestamp <= 3600 then
				matchesLastHour += 1
			end

			if r.Duration then
				totalDuration += r.Duration
				durationCount += 1
			end
		end
	end

	if matchesAgainstOpponent < WIN_TRADE_MIN_MATCHES_AGAINST_OPPONENT then
		return
	end

	local ratio = (matchesAgainstOpponent / matchesChecked) * 100
	local winRate = matchesAgainstOpponent > 0 and (winsAgainstOpponent / matchesAgainstOpponent) * 100 or 0
	local avgDuration = durationCount > 0 and (totalDuration / durationCount) or nil

	local flagRatio = ratio >= 70
	local flagWinRate = winRate >= 90
	local flagConsecutive = consecutiveWins >= 10
	local flagRecent = matchesLastHour >= 10
	local flagDuration = avgDuration ~= nil and avgDuration < 45

	local suspicionScore = 0
	if flagRatio then
		suspicionScore += 3
	end
	if flagWinRate then
		suspicionScore += 3
	end
	if flagConsecutive then
		suspicionScore += 2
	end
	if flagRecent then
		suspicionScore += 2
	end
	if flagDuration then
		suspicionScore += 2
	end

	if suspicionScore < WIN_TRADE_SCORE_THRESHOLD then
		return
	end

	winTradeAlertCooldowns[pairKey] = now

	local riskLevel = "Warning"
	local riskColor = 0xFFCC00
	if suspicionScore >= 10 then
		riskLevel = "Very High Risk"
		riskColor = 0xFF3040
	elseif suspicionScore >= 8 then
		riskLevel = "High Risk"
		riskColor = 0xFF8C00
	end

	local function mark(flagged: boolean): string
		return flagged and "❌" or "✅"
	end

	local avgDurationStr = if avgDuration then string.format("%.1fs", avgDuration) else "N/A"

	local embed = {
		author = { name = "Vultarian Combat Arena" },
		title = "Win Trading Suspicion",
		description = string.format("**Risk Level:** %s", riskLevel),
		color = riskColor,
		thumbnail = {
			url = string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png", winnerId),
		},
		fields = {
			{ name = "Winner", value = string.format("%s (%d)", winner.Name, winnerId), inline = true },
			{ name = "Loser", value = string.format("%s (%d)", loser.Name, loserId), inline = true },
			{ name = "Suspicion Score", value = string.format("%d / 12", suspicionScore), inline = true },
			{ name = "Match ID", value = matchId or "N/A", inline = false },

			{
				name = string.format("%s Same Opponent Ratio", mark(flagRatio)),
				value = string.format("%.1f%% (%d/%d)", ratio, matchesAgainstOpponent, matchesChecked),
				inline = true,
			},
			{
				name = string.format("%s Win Rate vs Opponent", mark(flagWinRate)),
				value = string.format("%.1f%%", winRate),
				inline = true,
			},
			{
				name = string.format("%s Consecutive Wins", mark(flagConsecutive)),
				value = tostring(consecutiveWins),
				inline = true,
			},

			{
				name = string.format("%s Matches Last Hour", mark(flagRecent)),
				value = tostring(matchesLastHour),
				inline = true,
			},
			{
				name = string.format("%s Avg Match Length", mark(flagDuration)),
				value = avgDurationStr,
				inline = true,
			},
			{ name = "\u{200B}", value = "\u{200B}", inline = true },
		},
		footer = { text = "VULTARIAN DEFENSE INDUSTRIES" },
		timestamp = DateTime.now():ToIsoDate(),
	}

	local WEBHOOK_URL = "REPLACE_WITH_YOUR_WEBHOOK_URL"
	local payload = HttpService:JSONEncode({
		username = "Vultarian Combat Arena",
		embeds = { embed },
	})

	pcall(HttpService.PostAsync, HttpService, WEBHOOK_URL, payload)
end

function ArenaStatsService.GetPlayerStatsByUsername(username: string): PlayerHistory?
	local player = Players:FindFirstChild(username)
	if not player then
		for _, p in Players:GetPlayers() do
			if p.Name:lower() == username:lower() then
				player = p
				break
			end
		end
	end

	if player then
		local history = getHistory(player.UserId)
		if not history then
			history = ArenaStatsService.LoadPlayer(player)
		end
		return history
	end

	local userId = nil
	local successId, _ = pcall(function()
		userId = Players:GetUserIdFromNameAsync(username)
	end)

	if not successId or not userId then
		return nil
	end

	local key = "History_" .. userId
	local success, saved = pcall(function()
		return SparStats:GetAsync(key)
	end)

	if success and type(saved) == "table" then
		local history = buildDefaultHistory()
		if saved.AllTime then
			for k, v in saved.AllTime do
				history.AllTime[k] = v
			end
		end
		if saved.LastDay then
			for k, v in saved.LastDay do
				history.LastDay[k] = v
			end
		end
		if saved.LastWeek then
			for k, v in saved.LastWeek do
				history.LastWeek[k] = v
			end
		end
		if saved.LastMonth then
			for k, v in saved.LastMonth do
				history.LastMonth[k] = v
			end
		end
		if saved.LastReset then
			history.LastReset = saved.LastReset
		end
		if saved.LastDayReset then
			history.LastDayReset = saved.LastDayReset
		end
		if saved.LastWeekReset then
			history.LastWeekReset = saved.LastWeekReset
		end
		if saved.LastMonthReset then
			history.LastMonthReset = saved.LastMonthReset
		end
		if saved.UnlockedTitles then
			history.UnlockedTitles = saved.UnlockedTitles
		end
		if saved.MatchHistory then
			history.MatchHistory = saved.MatchHistory
		end
		return history
	end

	return nil
end

function ArenaStatsService.GetFormattedStatsForLookup(username: string)
	local history = ArenaStatsService.GetPlayerStatsByUsername(username)
	if not history then
		return nil
	end

	local canonicalName = username
	local userId = nil
	local inGamePlayer = Players:FindFirstChild(username)
	if not inGamePlayer then
		for _, p in Players:GetPlayers() do
			if p.Name:lower() == username:lower() then
				inGamePlayer = p
				break
			end
		end
	end
	if inGamePlayer then
		canonicalName = inGamePlayer.Name
		userId = inGamePlayer.UserId
	else
		pcall(function()
			userId = Players:GetUserIdFromNameAsync(username)
			canonicalName = Players:GetNameFromUserIdAsync(userId)
		end)
	end

	local rankName, rankColor = ArenaTitleService.GetRankForWins(history.AllTime.MatchesWon or 0)

	local cardImageId = nil
	local isAnimatedCard = false
	if inGamePlayer then
		local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
		local cosmeticService = LazyService.create(MainModule, "CosmeticService")()
		if cosmeticService then
			local resolved = cosmeticService:GetEquippedItem(inGamePlayer, "PlayerCard")
			if resolved then
				cardImageId = resolved.imageId
				isAnimatedCard = resolved.isAnimated or false
			end
		end
	end

	return {
		username = canonicalName,
		userId = userId or 0,
		rankName = rankName,
		rankColor = rankColor,
		AllTimeWins = history.AllTime.MatchesWon or 0,
		AllTimeLosses = history.AllTime.MatchesLost or 0,
		AllTimeKills = history.AllTime.Kills or 0,
		AllTimeDamage = history.AllTime.Damage or 0,
		WeeklyKills = history.LastWeek.Kills or 0,
		WeeklyWins = history.LastWeek.MatchesWon or 0,
		MonthlyWins = history.LastMonth.MatchesWon or 0,
		cardImageId = cardImageId,
		isAnimatedCard = isAnimatedCard,
	}
end

function ArenaStatsService.HasViacomAccess(player: Player): boolean
	local whitelist = SparConfig.ViacomWhitelist or {}
	for _, id in whitelist do
		if player.UserId == id then
			return true
		end
	end

	return RankCache.isInGroup(player, Constants.GROUPS.VIACOM, Constants.MIN_RANK.VIACOM_INSTRUCTOR)
end

function ArenaStatsService.IsHighCommand(player: Player): boolean
	return RankCache.isInGroup(player, Constants.GROUPS.VULTAR, Constants.MIN_RANK.HIGH_COMMAND)
end

function ArenaStatsService.IsAdminPanelAuthorized(player: Player): boolean
	return table.find(SparConfig.ADMIN_PANEL_WHITELIST, player.UserId) ~= nil
end

local function getPlayerMatchIds(userId: number): { string }
	local success, result = pcall(function()
		return PlayerMatchIndexStore:GetAsync("Index_" .. userId)
	end)
	if success and type(result) == "table" then
		return result
	end
	return {}
end

local function getMatchRecordById(matchId: string): MatchRecord?
	local success, result = pcall(function()
		return MatchRecordStore:GetAsync("Match_" .. matchId)
	end)
	if success and type(result) == "table" then
		return result :: any
	end
	return nil
end

local function resolveUsername(userId: number): string
	if userId <= 0 then
		return "N/A"
	end
	local inGame = Players:GetPlayerByUserId(userId)
	if inGame then
		return inGame.Name
	end
	local success, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	return success and name or ("User_" .. tostring(userId))
end

local function formatTimestamp(timestamp: number): string
	local success, result = pcall(os.date, "%b %d, %Y %H:%M:%S UTC", timestamp)
	return success and result or "Unknown Time"
end

function ArenaStatsService.GetViacomPlayerMatches(userId: number, page: number?): { MatchRecord }
	local matchIds = getPlayerMatchIds(userId)
	local pageSize = SparConfig.VIACOM_MATCH_INDEX_PAGE_SIZE or 50
	local pageNum = page or 1
	local startIdx = (pageNum - 1) * pageSize + 1
	local endIdx = startIdx + pageSize - 1

	local records: { MatchRecord } = {}
	for i = startIdx, math.min(endIdx, #matchIds) do
		local matchId = matchIds[i]
		if matchId then
			local record = getMatchRecordById(matchId)
			if record and record.GameType == "Spar" then
				table.insert(records, record)
			end
		end
	end
	return records
end

function ArenaStatsService.GetMatchById(matchId: string): MatchRecord?
	return getMatchRecordById(matchId)
end

function ArenaStatsService.GetMatchesByDateRange(startTime: number, endTime: number, maxResults: number?): { MatchRecord }
	local max = maxResults or 100
	local records: { MatchRecord } = {}

	local success, pages = pcall(function()
		return MatchTimeIndexStore:GetSortedAsync(false, max, tostring(startTime), tostring(endTime))
	end)

	if success and pages then
		local entries = pages:GetCurrentPage()
		for _, entry in entries do
			local matchId = entry.value
			if matchId then
				local record = getMatchRecordById(matchId)
				if record and record.GameType == "Spar" then
					table.insert(records, record)
				end
			end
		end
	end

	return records
end

function ArenaStatsService.GetViacomPlayerData(username: string, page: number?): any?
	local stats = ArenaStatsService.GetFormattedStatsForLookup(username)
	if not stats then
		return nil
	end

	local userId = stats.userId
	if userId == 0 then
		pcall(function()
			userId = Players:GetUserIdFromNameAsync(username)
		end)
	end

	local matches = {}
	local flags = {}
	if userId > 0 then
		matches = ArenaStatsService.GetViacomPlayerMatches(userId, page)

		local success, result = pcall(function()
			return SparPlayerFlagIndexStore:GetAsync("FlagIndex_" .. userId)
		end)
		if success and type(result) == "table" then
			flags = result
		end
	end

	return {
		stats = stats,
		matches = matches,
		flags = flags,
	}
end

function ArenaStatsService.LogViacomSearch(staffPlayer: Player, searchedUserId: number, searchedName: string, matchIdsViewed: { string })
	local entry: AuditLogEntry = {
		staffUserId = staffPlayer.UserId,
		staffName = staffPlayer.Name,
		searchedUserId = searchedUserId,
		searchedName = searchedName,
		timestamp = os.time(),
		matchIdsViewed = matchIdsViewed,
	}

	task.spawn(function()
		pcall(function()
			AuditLogStore:UpdateAsync("AuditLog", function(old: any)
				old = old or {}
				table.insert(old, entry)
				local max = SparConfig.VIACOM_AUDIT_LOG_MAX or 500
				if #old > max then
					local trimmed = {}
					for i = #old - max + 1, #old do
						table.insert(trimmed, old[i])
					end
					return trimmed
				end
				return old
			end)
		end)
	end)
end

function ArenaStatsService.GetAuditLog(): { AuditLogEntry }
	local success, result = pcall(function()
		return AuditLogStore:GetAsync("AuditLog")
	end)
	if success and type(result) == "table" then
		return result :: any
	end
	return {}
end

function ArenaStatsService.ExportMatchToCaseWebhook(staffPlayer: Player, matchId: string): { success: boolean, error: string? }
	if not ArenaStatsService.HasViacomAccess(staffPlayer) then
		return { success = false, error = "Permission denied" }
	end

	local now = os.time()
	local lastExport = viacomExportCooldowns[staffPlayer.UserId] or 0
	if now - lastExport < 2 then
		return { success = false, error = "Please wait before exporting again" }
	end
	viacomExportCooldowns[staffPlayer.UserId] = now

	local record = getMatchRecordById(matchId)
	if not record then
		return { success = false, error = "Match not found" }
	end
	if record.GameType ~= "Spar" then
		return { success = false, error = "Only Spar matches can be exported" }
	end

	sanitizeMatchRecord(record)

	local winnerName = resolveUsername(record.WinnerId)
	local loserName = resolveUsername(record.LoserId)
	local player1Name = resolveUsername(record.Player1UserId)
	local player2Name = resolveUsername(record.Player2UserId)

	local embed = {
		author = { name = "Vultarian Sparring Arena | VIACOM Case Export" },
		title = "Match Exported to Case Log",
		description = string.format("Exported by **%s** (%d)", staffPlayer.Name, staffPlayer.UserId),
		color = 0x3498DB,
		fields = {
			{ name = "Match ID", value = record.MatchId, inline = false },
			{ name = "Map", value = record.MapName or "Unknown", inline = true },
			{ name = "Weapon", value = record.GunName or "Unknown", inline = true },
			{ name = "Rounds", value = tostring(record.Rounds or 1), inline = true },
			{ name = "Winner", value = string.format("%s (%d)", winnerName, record.WinnerId), inline = true },
			{ name = "Loser", value = string.format("%s (%d)", loserName, record.LoserId), inline = true },
			{ name = "Player 1", value = string.format("%s (%d)", player1Name, record.Player1UserId), inline = true },
			{ name = "Player 2", value = string.format("%s (%d)", player2Name, record.Player2UserId), inline = true },
			{ name = "Start Time", value = formatTimestamp(record.Timestamp), inline = true },
			{ name = "End Time", value = formatTimestamp(record.EndTimestamp), inline = true },
			{ name = "Duration", value = string.format("%ds", record.Duration or 0), inline = true },
		},
		footer = { text = "VULTARIAN DEFENSE INDUSTRIES" },
		timestamp = DateTime.now():ToIsoDate(),
	}

	local WEBHOOK_URL = "REPLACE_WITH_YOUR_WEBHOOK_URL"
	if not WEBHOOK_URL or WEBHOOK_URL == "" then
		return { success = false, error = "Case webhook URL not configured" }
	end

	local payload = HttpService:JSONEncode({
		username = "VIACOM Case Bot",
		embeds = { embed },
	})

	local postSuccess, postErr = pcall(HttpService.PostAsync, HttpService, WEBHOOK_URL, payload)
	if not postSuccess then
		return { success = false, error = "Webhook request failed: " .. tostring(postErr) }
	end

	ArenaStatsService.LogViacomSearch(staffPlayer, 0, "export:" .. matchId, { matchId })

	return { success = true, error = nil }
end

function ArenaStatsService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(ArenaStatsService.LoadPlayer, player)
	end

	playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		ArenaStatsService.LoadPlayer(player)
	end)

	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		local history = getHistory(userId)
		if history then
			ArenaLeaderboardService.UpdatePlayerStats(player, history)
		end

		if isShuttingDown then
			return
		end

		activeDataStoreRequests += 1
		task.spawn(function()
			ArenaStatsService.ForceSaveUserId(userId)
			playerHistory[userId] = nil
			pendingSaves[userId] = nil
			activeDataStoreRequests -= 1
		end)
	end)

	task.spawn(function()
		while not isShuttingDown do
			task.wait(600)
			local now = os.time()

			for userId, timestamp in pairs(viacomExportCooldowns) do
				if now - timestamp > 60 then
					viacomExportCooldowns[userId] = nil
				end
			end

			for combo, timestamp in pairs(winTradeAlertCooldowns) do
				if now - timestamp > WIN_TRADE_ALERT_COOLDOWN then
					winTradeAlertCooldowns[combo] = nil
				end
			end
		end
	end)

	Network.Spar.registerGetPlayerStats(function(_player: Player, username: string)
		return ArenaStatsService.GetFormattedStatsForLookup(username)
	end)

	Network.Spar.registerGetMatchHistory(function(player: Player)
		local history = getHistory(player.UserId)
		return sanitizeMatchRecords(history and history.MatchHistory or {})
	end)

	Network.Spar.registerViacomCheckAccess(function(player: Player)
		return ArenaStatsService.HasViacomAccess(player)
	end)

	Network.Spar.registerViacomSearch(function(player: Player, username: string)
		if not ArenaStatsService.HasViacomAccess(player) then
			return nil
		end
		local data = ArenaStatsService.GetViacomPlayerData(username)
		if data then
			local matchIdsViewed = {}
			if data.matches then
				for _, m in data.matches do
					table.insert(matchIdsViewed, m.MatchId)
				end
			end
			ArenaStatsService.LogViacomSearch(player, data.stats.userId, data.stats.username, matchIdsViewed)
			sanitizeMatchRecords(data.matches)
		end
		return data
	end)

	Network.Spar.registerViacomGetMatch(function(player: Player, matchId: string)
		if not ArenaStatsService.HasViacomAccess(player) then
			return nil
		end
		local record = ArenaStatsService.GetMatchById(matchId)
		if record then
			ArenaStatsService.LogViacomSearch(player, 0, "match:" .. matchId, { matchId })
			sanitizeMatchRecord(record)
		end
		return record
	end)

	Network.Spar.registerViacomGetAuditLog(function(player: Player)
		if not ArenaStatsService.IsHighCommand(player) then
			return nil
		end
		return ArenaStatsService.GetAuditLog()
	end)

	Network.Spar.registerViacomExportMatch(function(player: Player, matchId: string)
		return ArenaStatsService.ExportMatchToCaseWebhook(player, matchId)
	end)
	Network.Spar.registerAdminEditStats(function(player: Player, targetUsername: string, statsData: any)
		if not ArenaStatsService.IsAdminPanelAuthorized(player) then
			return false
		end

		local targetUserId
		local targetPlayer = Players:FindFirstChild(targetUsername)
		if targetPlayer then
			targetUserId = targetPlayer.UserId
		else
			local s, id = pcall(function()
				return Players:GetUserIdFromNameAsync(targetUsername)
			end)
			if s and id then
				targetUserId = id
			else
				return false
			end
		end

		local history = getHistory(targetUserId)
		local isInGame = targetPlayer ~= nil
		if not history then
			local s, data = pcall(function()
				return SparStats:GetAsync("History_" .. tostring(targetUserId))
			end)
			if s and data then
				history = data
			else
				return false
			end
		end

		for period, stats in pairs(statsData) do
			if history[period] then
				for statName, statVal in pairs(stats) do
					if type(statVal) == "number" then
						history[period][statName] = statVal
					end
				end
			end
		end

		if isInGame and targetPlayer then
			ArenaStatsService.ForceSave(targetPlayer)
		else
			pcall(function()
				SparStats:SetAsync("History_" .. tostring(targetUserId), history)
			end)
		end

		ArenaStatsService.LogViacomSearch(player, targetUserId, "AdminEditStats:" .. targetUsername, {})
		return true
	end)

	Network.Spar.registerAdminInjectMatch(function(player: Player, targetUsername: string, matchData: any)
		if not ArenaStatsService.IsAdminPanelAuthorized(player) then
			return false
		end

		sanitizeMatchRecord(matchData)

		local targetUserId
		local targetPlayer = Players:FindFirstChild(targetUsername)
		if targetPlayer then
			targetUserId = targetPlayer.UserId
		else
			local s, id = pcall(function()
				return Players:GetUserIdFromNameAsync(targetUsername)
			end)
			if s and id then
				targetUserId = id
			else
				return false
			end
		end

		local history = getHistory(targetUserId)
		local isInGame = targetPlayer ~= nil
		if not history then
			local s, data = pcall(function()
				return SparStats:GetAsync("History_" .. tostring(targetUserId))
			end)
			if s and data then
				history = data
			else
				return false
			end
		end

		local oppId = 0
		if matchData.HostileName and matchData.HostileName ~= targetUsername then
			local s, id = pcall(function()
				return Players:GetUserIdFromNameAsync(matchData.HostileName)
			end)
			if s and id then
				oppId = id
			end
		end

		if targetUsername == matchData.WinnerName then
			matchData.WinnerId = targetUserId
			matchData.LoserId = oppId
		else
			matchData.WinnerId = oppId
			matchData.LoserId = targetUserId
		end

		matchData.Player1UserId = targetUserId
		matchData.Player2UserId = oppId
		matchData.VultarianId = targetUserId
		matchData.HostileId = oppId

		local count = #history.MatchHistory
		table.move(history.MatchHistory, 1, count, 2)
		history.MatchHistory[1] = matchData
		if #history.MatchHistory > MAX_MATCH_HISTORY then
			history.MatchHistory[MAX_MATCH_HISTORY + 1] = nil
		end

		activeDataStoreRequests += 1
		writeIndexedMatchRecord(matchData)
		activeDataStoreRequests -= 1

		if isInGame and targetPlayer then
			ArenaStatsService.ForceSave(targetPlayer)
		else
			pcall(function()
				SparStats:SetAsync("History_" .. tostring(targetUserId), history)
			end)
		end

		ArenaStatsService.LogViacomSearch(player, targetUserId, "AdminInjectMatch:" .. targetUsername, { matchData.MatchId or "" })
		return true
	end)

	Network.Spar.registerAdminCheckAccess(function(player: Player)
		return ArenaStatsService.IsAdminPanelAuthorized(player)
	end)
end

function ArenaStatsService.cleanup()
	if playerAddedConnection then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end
	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end

	for userId, _ in pendingSaves do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			ArenaStatsService.ForceSave(player)
		end
	end
	table.clear(playerHistory)
end

return ArenaStatsService
