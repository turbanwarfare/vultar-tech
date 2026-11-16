--!strict

local MainModule = script.Parent.Parent.Parent.Parent
local StatsConfig = require(MainModule.Shared.Config.Stats.StatsConfig)

type PlayerStats = StatsConfig.PlayerStats

export type StatValues = {
	Kills: any,
	Damage: any,
	Heals: any,
	Captures: any,
	CardImageId: any,
	IsAnimatedCard: any,
}

export type PlayerStatsStore = {
	getPlayerStats: (self: PlayerStatsStore, userId: number) -> StatValues,
	updateStat: (self: PlayerStatsStore, userId: number, statType: string, value: number) -> (),
	updateAllStats: (self: PlayerStatsStore, userId: number, stats: PlayerStats) -> (),
	updateCard: (self: PlayerStatsStore, userId: number, cardImageId: string?, isAnimatedCard: boolean?) -> (),
	removePlayer: (self: PlayerStatsStore, userId: number) -> (),
	clear: (self: PlayerStatsStore) -> (),
}

local PlayerStatsStore = {}
PlayerStatsStore.__index = PlayerStatsStore

function PlayerStatsStore.new(scope: any): PlayerStatsStore
	local self = setmetatable({}, PlayerStatsStore)
	self._scope = scope
	self._players = {} :: { [number]: StatValues }
	return self :: any
end

function PlayerStatsStore:_ensurePlayer(userId: number): StatValues
	if not self._players[userId] then
		self._players[userId] = {
			Kills = self._scope:Value(0),
			Damage = self._scope:Value(0),
			Heals = self._scope:Value(0),
			Captures = self._scope:Value(0),
			CardImageId = self._scope:Value(nil :: string?),
			IsAnimatedCard = self._scope:Value(false),
		}
	end
	return self._players[userId]
end

function PlayerStatsStore:getPlayerStats(userId: number): StatValues
	return self:_ensurePlayer(userId)
end

function PlayerStatsStore:updateStat(userId: number, statType: string, value: number): ()
	local stats = self:_ensurePlayer(userId)
	local statValue = (stats :: any)[statType]
	if statValue then
		statValue:set(value)
	end
end

function PlayerStatsStore:updateAllStats(userId: number, newStats: PlayerStats): ()
	local stats = self:_ensurePlayer(userId)
	stats.Kills:set(newStats.Kills)
	stats.Damage:set(newStats.Damage)
	stats.Heals:set(newStats.Heals)
	stats.Captures:set(newStats.Captures)
end

function PlayerStatsStore:updateCard(userId: number, cardImageId: string?, isAnimatedCard: boolean?): ()
	local stats = self:_ensurePlayer(userId)
	stats.CardImageId:set(cardImageId)
	stats.IsAnimatedCard:set(isAnimatedCard or false)
end

function PlayerStatsStore:removePlayer(userId: number): ()
	self._players[userId] = nil
end

function PlayerStatsStore:clear(): ()
	table.clear(self._players)
end

return PlayerStatsStore
