--!strict
--!native
--!optimize 2

export type StatType = "Kills" | "Damage" | "Heals" | "Captures"
export type StatTypeId = number

export type PlayerStats = {
	Kills: number,
	Damage: number,
	Heals: number,
	Captures: number,
}

export type LeaderboardEntry = {
	UserId: number,
	DisplayName: string,
	Username: string,
	Team: string?,
	Stats: PlayerStats,
	CardImageId: string?,
	IsAnimatedCard: boolean?,
}

export type SortField = "Kills" | "Damage" | "Heals" | "Captures" | "Total"

local StatsConfig = {}

StatsConfig.StatTypes = { "Kills", "Damage", "Heals", "Captures" } :: { StatType }

StatsConfig.StatTypeIds = {
	Kills = 1,
	Damage = 2,
	Heals = 3,
	Captures = 4,
} :: { [StatType]: StatTypeId }

StatsConfig.StatTypeNames = {
	[1] = "Kills",
	[2] = "Damage",
	[3] = "Heals",
	[4] = "Captures",
} :: { [StatTypeId]: StatType }

local VALID_STAT_TYPES: { [string]: boolean } = {
	Kills = true,
	Damage = true,
	Heals = true,
	Captures = true,
}

StatsConfig.DefaultStats = {
	Kills = 0,
	Damage = 0,
	Heals = 0,
	Captures = 0,
} :: PlayerStats

function StatsConfig.createDefaultStats(): PlayerStats
	return {
		Kills = 0,
		Damage = 0,
		Heals = 0,
		Captures = 0,
	}
end

function StatsConfig.getTotal(stats: PlayerStats): number
	return stats.Kills + stats.Damage + stats.Heals + stats.Captures
end

function StatsConfig.isValidStatType(statType: string): boolean
	return VALID_STAT_TYPES[statType] == true
end

function StatsConfig.getStatTypeId(statType: string): StatTypeId?
	return StatsConfig.StatTypeIds[statType :: StatType]
end

function StatsConfig.getStatTypeName(statTypeId: StatTypeId): StatType?
	return StatsConfig.StatTypeNames[statTypeId]
end

function StatsConfig.isValidStatTypeId(statTypeId: StatTypeId): boolean
	return StatsConfig.StatTypeNames[statTypeId] ~= nil
end

return StatsConfig
