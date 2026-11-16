--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local StatsConfig = require(MainModule.Shared.Config.Stats.StatsConfig)
local SharedTypes = require(MainModule.Shared.Types)
local PlayerStatsStore = require(script.Parent.PlayerStatsStore)

export type PlayerStats = StatsConfig.PlayerStats
export type LeaderboardEntry = StatsConfig.LeaderboardEntry

export type TeamLabel = {
	name: string,
	displayName: string,
	color: Color3,
	order: number,
}

export type FusionScope = SharedTypes.FusionScope
export type FusionCanBeState<T> = SharedTypes.FusionCanBeState<T>
export type FusionUseFn = SharedTypes.FusionUseFn

export type FactionData = {
	name: string,
	displayName: string,
	icon: string,
	entries: { LeaderboardEntry },
	totals: PlayerStats,
	playerCount: number,
	teamLabels: { TeamLabel }?,
}

export type LeaderboardProps = {
	Visible: FusionCanBeState<boolean>,
	DefendersData: FusionCanBeState<FactionData>,
	RaidersData: FusionCanBeState<FactionData>,
	DefendersTotals: FusionCanBeState<PlayerStats>?,
	RaidersTotals: FusionCanBeState<PlayerStats>?,
	LocalUserId: number,
}

export type PlayerRowProps = {
	Entry: LeaderboardEntry,
	IsLocalPlayer: boolean,
	LayoutOrder: FusionCanBeState<number>?,
	ShowSeparator: boolean?,
}

export type HeaderStatColumnProps = {
	Label: string,
	GetValue: () -> string,
	Position: number,
}

export type FactionHeaderProps = {
	Data: FusionCanBeState<FactionData>,
	Totals: FusionCanBeState<PlayerStats>?,
	IsDefenders: boolean,
	IsSpar: boolean?,
}

export type FactionPanelProps = {
	Data: FusionCanBeState<FactionData>,
	Totals: FusionCanBeState<PlayerStats>?,
	LocalUserId: number,
	IsDefenders: boolean,
	StatsStore: PlayerStatsStore.PlayerStatsStore?,
	OnRowClick: ((userId: number, cardImageId: string?, isAnimatedCard: boolean) -> ())?,
	IsSpar: boolean?,
}

return nil
