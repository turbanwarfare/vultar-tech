--!strict
--!native
--!optimize 2

local Shared = script.Parent.Parent.Parent
local StatsConfig = require(Shared.Config.Stats.StatsConfig)

export type PlayerStats = StatsConfig.PlayerStats
export type LeaderboardEntry = StatsConfig.LeaderboardEntry
export type SortField = StatsConfig.SortField
export type StatTypeId = StatsConfig.StatTypeId

export type LeaderboardResponse = {
	entries: { LeaderboardEntry },
	sortedBy: SortField,
}

export type StatsUpdateData = {
	statType: string,
	amount: number,
	newValue: number,
}

export type StatsUpdateDataCompact = {
	statTypeId: StatTypeId,
	newValue: number,
}

return nil
