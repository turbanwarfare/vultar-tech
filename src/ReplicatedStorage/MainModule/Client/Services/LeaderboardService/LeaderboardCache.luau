--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local StatsConfig = require(MainModule.Shared.Config.Stats.StatsConfig)
local LeaderboardConstants = require(script.Parent.LeaderboardConstants)

type LeaderboardEntry = StatsConfig.LeaderboardEntry
type PlayerStats = StatsConfig.PlayerStats

local DEFENDER_TEAMS = LeaderboardConstants.DEFENDER_TEAMS
local NEUTRAL_TEAMS = LeaderboardConstants.NEUTRAL_TEAMS
local TEAM_PRIORITY = LeaderboardConstants.TEAM_PRIORITY

local LeaderboardCache = {}

local entryCache: { [number]: LeaderboardEntry } = {}
local cachedDefenders: { LeaderboardEntry } = {}
local cachedRaiders: { LeaderboardEntry } = {}
local defenderIndexMap: { [number]: number } = {}
local raiderIndexMap: { [number]: number } = {}
local defenderTotals: PlayerStats = StatsConfig.createDefaultStats()
local raiderTotals: PlayerStats = StatsConfig.createDefaultStats()

local entryCount: number = 0
local uiDirty = false
local sortDirty = false
local structureDirty = false
local totalsDirty = false

local pendingDeltas: { [number]: { [string]: number } } = {}
local MAX_PENDING_DELTAS = 200

function LeaderboardCache.isDefenderTeam(team: string?): boolean
	return team ~= nil and DEFENDER_TEAMS[team] == true
end

function LeaderboardCache.isSpectatorTeam(team: string?): boolean
	return team ~= nil and NEUTRAL_TEAMS[team] == true
end

local function addToTotals(totals: PlayerStats, stats: PlayerStats): ()
	totals.Kills += stats.Kills
	totals.Damage += stats.Damage
	totals.Heals += stats.Heals
	totals.Captures += stats.Captures
end

local function subtractFromTotals(totals: PlayerStats, stats: PlayerStats): ()
	totals.Kills -= stats.Kills
	totals.Damage -= stats.Damage
	totals.Heals -= stats.Heals
	totals.Captures -= stats.Captures
end

local function updateTotalsDelta(totals: PlayerStats, statType: string, delta: number): ()
	(totals :: any)[statType] = ((totals :: any)[statType] or 0) + delta
end

local function rebuildIndexMaps(): ()
	table.clear(defenderIndexMap)
	table.clear(raiderIndexMap)
	for i, entry in cachedDefenders do
		defenderIndexMap[entry.UserId] = i
	end
	for i, entry in cachedRaiders do
		raiderIndexMap[entry.UserId] = i
	end
end

local function sortEntries(entries: { LeaderboardEntry }): ()
	table.sort(entries, function(a, b)
		local priorityA = TEAM_PRIORITY[a.Team] or 99
		local priorityB = TEAM_PRIORITY[b.Team] or 99
		if priorityA ~= priorityB then
			return priorityA < priorityB
		end
		return a.Stats.Kills > b.Stats.Kills
	end)
end

function LeaderboardCache.getEntry(userId: number): LeaderboardEntry?
	return entryCache[userId]
end

function LeaderboardCache.setEntry(userId: number, entry: LeaderboardEntry): ()
	if entryCache[userId] == nil then
		entryCount += 1
	end
	entryCache[userId] = entry
end

function LeaderboardCache.removeEntry(userId: number): ()
	if entryCache[userId] ~= nil then
		entryCount -= 1
	end
	entryCache[userId] = nil
end

function LeaderboardCache.getAllEntries(): { [number]: LeaderboardEntry }
	return entryCache
end

function LeaderboardCache.clearAllPendingDeltas(): ()
	table.clear(pendingDeltas)
end

function LeaderboardCache.getDefenders(): { LeaderboardEntry }
	return cachedDefenders
end

function LeaderboardCache.getRaiders(): { LeaderboardEntry }
	return cachedRaiders
end

function LeaderboardCache.getRaidersExcludingSpectators(): { LeaderboardEntry }
	local filtered = {}
	for _, entry in cachedRaiders do
		if not LeaderboardCache.isSpectatorTeam(entry.Team) then
			table.insert(filtered, entry)
		end
	end
	return filtered
end


function LeaderboardCache.getDefenderTotals(): PlayerStats
	local totals = StatsConfig.createDefaultStats()
	for _, entry in cachedDefenders do
		totals.Kills += entry.Stats.Kills
		totals.Damage += entry.Stats.Damage
		totals.Heals += entry.Stats.Heals
		totals.Captures += entry.Stats.Captures
	end
	return totals
end

function LeaderboardCache.getRaiderTotals(): PlayerStats
	local totals = StatsConfig.createDefaultStats()
	for _, entry in cachedRaiders do
		if not LeaderboardCache.isSpectatorTeam(entry.Team) then
			totals.Kills += entry.Stats.Kills
			totals.Damage += entry.Stats.Damage
			totals.Heals += entry.Stats.Heals
			totals.Captures += entry.Stats.Captures
		end
	end
	return totals
end

function LeaderboardCache.markDirty(structureChange: boolean?): ()
	uiDirty = true
	if structureChange then
		structureDirty = true
	end
end

function LeaderboardCache.markTotalsDirty(): ()
	totalsDirty = true
	uiDirty = true
end

function LeaderboardCache.markSortDirty(): ()
	sortDirty = true
end

function LeaderboardCache.isDirty(): boolean
	return uiDirty
end

function LeaderboardCache.isSortDirty(): boolean
	return sortDirty
end

function LeaderboardCache.isStructureDirty(): boolean
	return structureDirty
end

function LeaderboardCache.isTotalsDirty(): boolean
	return totalsDirty
end

function LeaderboardCache.clearDirtyFlags(): ()
	uiDirty = false
end

function LeaderboardCache.clearSortDirty(): ()
	sortDirty = false
end

function LeaderboardCache.clearStructureDirty(): ()
	structureDirty = false
end

function LeaderboardCache.clearTotalsDirty(): ()
	totalsDirty = false
end

function LeaderboardCache.removeFromFactionArray(userId: number): (LeaderboardEntry?, boolean)
	local defIdx = defenderIndexMap[userId]
	if defIdx then
		local entry = cachedDefenders[defIdx]
		local lastIdx = #cachedDefenders
		if defIdx < lastIdx then
			local lastEntry = cachedDefenders[lastIdx]
			cachedDefenders[defIdx] = lastEntry
			defenderIndexMap[lastEntry.UserId] = defIdx
		end
		cachedDefenders[lastIdx] = nil
		defenderIndexMap[userId] = nil
		if entry then
			subtractFromTotals(defenderTotals, entry.Stats)
		end
		sortDirty = true
		return entry, true
	end

	local raidIdx = raiderIndexMap[userId]
	if raidIdx then
		local entry = cachedRaiders[raidIdx]
		local lastIdx = #cachedRaiders
		if raidIdx < lastIdx then
			local lastEntry = cachedRaiders[lastIdx]
			cachedRaiders[raidIdx] = lastEntry
			raiderIndexMap[lastEntry.UserId] = raidIdx
		end
		cachedRaiders[lastIdx] = nil
		raiderIndexMap[userId] = nil
		if entry and not LeaderboardCache.isSpectatorTeam(entry.Team) then
			subtractFromTotals(raiderTotals, entry.Stats)
		end
		sortDirty = true
		return entry, false
	end

	return nil, false
end

function LeaderboardCache.addToFactionArray(entry: LeaderboardEntry): ()
	if LeaderboardCache.isDefenderTeam(entry.Team) then
		table.insert(cachedDefenders, entry)
		defenderIndexMap[entry.UserId] = #cachedDefenders
		addToTotals(defenderTotals, entry.Stats)
	else
		table.insert(cachedRaiders, entry)
		raiderIndexMap[entry.UserId] = #cachedRaiders
		if not LeaderboardCache.isSpectatorTeam(entry.Team) then
			addToTotals(raiderTotals, entry.Stats)
		end
	end
	sortDirty = true
end

function LeaderboardCache.replaceEntryInFactionArray(oldEntry: LeaderboardEntry, newEntry: LeaderboardEntry): ()
	local userId = oldEntry.UserId

	local defIdx = defenderIndexMap[userId]
	if defIdx and cachedDefenders[defIdx] then
		cachedDefenders[defIdx] = newEntry
		return
	end

	local raidIdx = raiderIndexMap[userId]
	if raidIdx and cachedRaiders[raidIdx] then
		cachedRaiders[raidIdx] = newEntry
		return
	end
end

function LeaderboardCache.applyStatDelta(userId: number, statType: string, newValue: number, statsStore: any?): ()
	local entry = entryCache[userId]
	if not entry then
		local pending = pendingDeltas[userId]
		if not pending then
			local pendingCount = 0
			for _ in pendingDeltas do
				pendingCount += 1
			end
			if pendingCount >= MAX_PENDING_DELTAS then
				return
			end
			pending = {}
			pendingDeltas[userId] = pending
		end
		pending[statType] = newValue
		return
	end

	local oldValue = (entry.Stats :: any)[statType] or 0
	local delta = newValue - oldValue

	if delta == 0 then
		return
	end

	(entry.Stats :: any)[statType] = newValue

	local inDefenders = defenderIndexMap[userId] ~= nil
	local inRaiders = raiderIndexMap[userId] ~= nil

	if inDefenders then
		updateTotalsDelta(defenderTotals, statType, delta)
		LeaderboardCache.markTotalsDirty()
	elseif inRaiders and not LeaderboardCache.isSpectatorTeam(entry.Team) then
		updateTotalsDelta(raiderTotals, statType, delta)
		LeaderboardCache.markTotalsDirty()
	end

	if statsStore then
		statsStore:updateStat(userId, statType, newValue)
	end

	-- Row cells read from statsStore, so only a change to the sort key (Kills) needs a structure update.
	if statType == "Kills" then
		sortDirty = true
		LeaderboardCache.markDirty(true)
	else
		LeaderboardCache.markDirty(false)
	end
end

function LeaderboardCache.applyFullStats(userId: number, stats: PlayerStats, statsStore: any?): ()
	local entry = entryCache[userId]
	if not entry then
		return
	end

	local oldKills = entry.Stats.Kills

	local newEntry: LeaderboardEntry = {
		UserId = entry.UserId,
		DisplayName = entry.DisplayName,
		Username = entry.Username,
		Team = entry.Team,
		Stats = stats,
		CardImageId = entry.CardImageId,
		IsAnimatedCard = entry.IsAnimatedCard,
	}

	local inDefenders = defenderIndexMap[userId] ~= nil
	local inRaiders = raiderIndexMap[userId] ~= nil

	if inDefenders then
		subtractFromTotals(defenderTotals, entry.Stats)
		addToTotals(defenderTotals, stats)
		LeaderboardCache.markTotalsDirty()
	elseif inRaiders and not LeaderboardCache.isSpectatorTeam(entry.Team) then
		subtractFromTotals(raiderTotals, entry.Stats)
		addToTotals(raiderTotals, stats)
		LeaderboardCache.markTotalsDirty()
	end

	LeaderboardCache.replaceEntryInFactionArray(entry, newEntry)
	entryCache[userId] = newEntry

	if statsStore then
		statsStore:updateAllStats(userId, stats)
	end

	if stats.Kills ~= oldKills then
		sortDirty = true
		LeaderboardCache.markDirty(true)
	end
end

function LeaderboardCache.updatePlayerTeam(userId: number, newTeam: string?, statsStore: any?): ()
	local entry = entryCache[userId]
	if not entry then
		return
	end

	local oldTeam = entry.Team
	local wasDefender = LeaderboardCache.isDefenderTeam(oldTeam)
	local isNowDefender = LeaderboardCache.isDefenderTeam(newTeam)
	local wasSpectator = LeaderboardCache.isSpectatorTeam(oldTeam)
	local isNowSpectator = LeaderboardCache.isSpectatorTeam(newTeam)

	local newEntry: LeaderboardEntry = {
		UserId = entry.UserId,
		DisplayName = entry.DisplayName,
		Username = entry.Username,
		Team = newTeam,
		Stats = entry.Stats,
		CardImageId = entry.CardImageId,
		IsAnimatedCard = entry.IsAnimatedCard,
	}

	if wasDefender then
		subtractFromTotals(defenderTotals, entry.Stats)
	elseif not wasSpectator then
		subtractFromTotals(raiderTotals, entry.Stats)
	end

	if isNowDefender then
		addToTotals(defenderTotals, entry.Stats)
	elseif not isNowSpectator then
		addToTotals(raiderTotals, entry.Stats)
	end

	if wasDefender ~= isNowDefender then
		if wasDefender then
			local idx = defenderIndexMap[userId]
			if idx then
				local lastIdx = #cachedDefenders
				if idx < lastIdx then
					local lastEntry = cachedDefenders[lastIdx]
					cachedDefenders[idx] = lastEntry
					defenderIndexMap[lastEntry.UserId] = idx
				end
				cachedDefenders[lastIdx] = nil
				defenderIndexMap[userId] = nil
			end
		else
			local idx = raiderIndexMap[userId]
			if idx then
				local lastIdx = #cachedRaiders
				if idx < lastIdx then
					local lastEntry = cachedRaiders[lastIdx]
					cachedRaiders[idx] = lastEntry
					raiderIndexMap[lastEntry.UserId] = idx
				end
				cachedRaiders[lastIdx] = nil
				raiderIndexMap[userId] = nil
			end
		end

		if isNowDefender then
			table.insert(cachedDefenders, newEntry)
			defenderIndexMap[userId] = #cachedDefenders
		else
			table.insert(cachedRaiders, newEntry)
			raiderIndexMap[userId] = #cachedRaiders
		end
	else
		LeaderboardCache.replaceEntryInFactionArray(entry, newEntry)
	end

	entryCache[userId] = newEntry
	sortDirty = true
	LeaderboardCache.markTotalsDirty()
	LeaderboardCache.markDirty(true)

	if statsStore then
		statsStore:updateAllStats(userId, newEntry.Stats)
	end
end

function LeaderboardCache.sortAndRebuildIndexMaps(): ()
	sortEntries(cachedDefenders)
	sortEntries(cachedRaiders)
	rebuildIndexMaps()
	sortDirty = false
	structureDirty = true
end

function LeaderboardCache.rebuildFromCache(statsStore: any?): ()
	table.clear(cachedDefenders)
	table.clear(cachedRaiders)
	table.clear(defenderIndexMap)
	table.clear(raiderIndexMap)
	defenderTotals = StatsConfig.createDefaultStats()
	raiderTotals = StatsConfig.createDefaultStats()

	for userId, entry in entryCache do
		if LeaderboardCache.isDefenderTeam(entry.Team) then
			table.insert(cachedDefenders, entry)
			addToTotals(defenderTotals, entry.Stats)
		else
			table.insert(cachedRaiders, entry)
			if not LeaderboardCache.isSpectatorTeam(entry.Team) then
				addToTotals(raiderTotals, entry.Stats)
			end
		end

		if statsStore then
			statsStore:updateAllStats(userId, entry.Stats)
			statsStore:updateCard(userId, entry.CardImageId, entry.IsAnimatedCard)
		end
	end

	sortEntries(cachedDefenders)
	sortEntries(cachedRaiders)
	rebuildIndexMaps()
	sortDirty = false
	structureDirty = true
	totalsDirty = true
	uiDirty = true
end

function LeaderboardCache.clear(): ()
	table.clear(entryCache)
	entryCount = 0
	cachedDefenders = {}
	cachedRaiders = {}
	table.clear(defenderIndexMap)
	table.clear(raiderIndexMap)
	table.clear(pendingDeltas)
	defenderTotals = StatsConfig.createDefaultStats()
	raiderTotals = StatsConfig.createDefaultStats()
	uiDirty = false
	sortDirty = false
	structureDirty = false
	totalsDirty = false
end

function LeaderboardCache.iterateEntries(): typeof(pairs(entryCache))
	return pairs(entryCache)
end

function LeaderboardCache.getRaiderCountExcludingSpectators(): number
	local count = 0
	for _, entry in cachedRaiders do
		if not LeaderboardCache.isSpectatorTeam(entry.Team) then
			count += 1
		end
	end
	return count
end

function LeaderboardCache.getEntryCount(): number
	return entryCount
end

function LeaderboardCache.syncAllStatsToStore(statsStore: any): ()
	for userId, entry in entryCache do
		statsStore:updateAllStats(userId, entry.Stats)
	end
end

function LeaderboardCache.consumePendingDeltas(userId: number, statsStore: any?): boolean
	local pending = pendingDeltas[userId]
	if not pending then
		return false
	end
	pendingDeltas[userId] = nil

	local entry = entryCache[userId]
	if not entry then
		return false
	end

	local applied = false
	for statType, newValue in pending do
		local oldValue = (entry.Stats :: any)[statType] or 0
		if newValue > oldValue then
			(entry.Stats :: any)[statType] = newValue

			local inDefenders = defenderIndexMap[userId] ~= nil
			local inRaiders = raiderIndexMap[userId] ~= nil
			local delta = newValue - oldValue

			if inDefenders then
				updateTotalsDelta(defenderTotals, statType, delta)
			elseif inRaiders and not LeaderboardCache.isSpectatorTeam(entry.Team) then
				updateTotalsDelta(raiderTotals, statType, delta)
			end

			if statsStore then
				statsStore:updateStat(userId, statType, newValue)
			end

			if statType == "Kills" then
				sortDirty = true
			end
			applied = true
		end
	end

	if applied then
		LeaderboardCache.markTotalsDirty()
		LeaderboardCache.markDirty(true)
	end
	return applied
end

function LeaderboardCache.clearPendingDeltas(userId: number): ()
	pendingDeltas[userId] = nil
end

return LeaderboardCache
