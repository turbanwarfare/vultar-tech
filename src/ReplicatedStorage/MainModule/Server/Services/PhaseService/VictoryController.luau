--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)

local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)

local VictoryController = {}

local function getTopPlayersByFaction(
	faction: string,
	statsSvc: any,
	isDefenderTeam: (teamName: string?) -> boolean,
	isRaiderTeam: (teamName: string?) -> boolean
): Network.TeamTopPlayers
	local leaderboard = statsSvc:GetLeaderboard("Kills")
	local result: Network.TeamTopPlayers = { Kills = nil, Damage = nil, Heals = nil }
	local topKills, topDamage, topHeals = 0, 0, 0
	local isDefenderFaction = faction == "Defenders"

	for _, entry in leaderboard do
		local isMatchingFaction = if isDefenderFaction
			then isDefenderTeam(entry.Team)
			else isRaiderTeam(entry.Team)

		if isMatchingFaction then
			if entry.Stats.Kills > topKills then
				topKills = entry.Stats.Kills
				result.Kills = { UserId = entry.UserId, DisplayName = entry.DisplayName, Value = entry.Stats.Kills }
			end
			if entry.Stats.Damage > topDamage then
				topDamage = entry.Stats.Damage
				result.Damage = { UserId = entry.UserId, DisplayName = entry.DisplayName, Value = entry.Stats.Damage }
			end
			if entry.Stats.Heals > topHeals then
				topHeals = entry.Stats.Heals
				result.Heals = { UserId = entry.UserId, DisplayName = entry.DisplayName, Value = entry.Stats.Heals }
			end
		end
	end

	return result
end

function VictoryController.getVictoryData(
	defendersWon: boolean,
	getStatsService: () -> any?,
	isDefenderTeam: (teamName: string?) -> boolean,
	isRaiderTeam: (teamName: string?) -> boolean
): Network.VictoryData
	local statsSvc = getStatsService()
	local defenderTop: Network.TeamTopPlayers = { Kills = nil, Damage = nil, Heals = nil }
	local hostileTop: Network.TeamTopPlayers = { Kills = nil, Damage = nil, Heals = nil }

	if statsSvc then
		statsSvc:FlushPendingUpdates()
		defenderTop = getTopPlayersByFaction("Defenders", statsSvc, isDefenderTeam, isRaiderTeam)
		hostileTop = getTopPlayersByFaction("Raiders", statsSvc, isDefenderTeam, isRaiderTeam)
	end

	return {
		WinningTeam = if defendersWon then "Defenders" else "Hostiles",
		DefenderTopPlayers = defenderTop,
		HostileTopPlayers = hostileTop,
		DefenderScore = 0,
		HostileScore = 0,
	}
end

function VictoryController.findMVP(
	defendersWon: boolean,
	getStatsService: () -> any?,
	getPlayerFaction: (player: Player) -> string?
): Player?
	local statsSvc = getStatsService()
	if not statsSvc then return nil end

	local leaderboard = statsSvc:GetLeaderboard("Total")
	local mvpPlayer: Player? = nil
	local mvpScore = 0
	local winningFaction = if defendersWon then "Defenders" else "Raiders"

	for _, entry in leaderboard do
		local player = Players:GetPlayerByUserId(entry.UserId)
		if not player then continue end

		local faction = getPlayerFaction(player)
		if faction ~= winningFaction then continue end

		local score = entry.Stats.Kills + entry.Stats.Damage + entry.Stats.Heals + entry.Stats.Captures
		if score > mvpScore then
			mvpScore = score
			mvpPlayer = player
		end
	end

	return mvpPlayer
end

function VictoryController.trackEndGameStats(
	defendersWon: boolean,
	shouldCountStats: () -> boolean,
	getStatsService: () -> any?,
	getPlayerFaction: (player: Player) -> string?
): ()
	if not shouldCountStats() then return end

	local statsSvc = getStatsService()
	if not statsSvc then return end

	for _, player in Players:GetPlayers() do
		local faction = getPlayerFaction(player)
		if not faction or faction == "Neutral" then continue end

		statsSvc:AddGamesPlayed(player)
		local isWinner = (faction == "Defenders" and defendersWon) or (faction == "Raiders" and not defendersWon)
		if isWinner then
			statsSvc:AddGamesWon(player)
		end

		local economySvc = ServiceLocator.Economy()
		if economySvc then
			economySvc:AwardMatchOutcome(player, isWinner)
		end
	end

	local mvpPlayer = VictoryController.findMVP(defendersWon, getStatsService, getPlayerFaction)
	if mvpPlayer then
		statsSvc:AddMVP(mvpPlayer)
	end
end

function VictoryController.awardCapture(
	player: Player,
	shouldCountStats: () -> boolean,
	getStatsService: () -> any?
): ()
	local statsSvc = getStatsService()
	if statsSvc then
		statsSvc:AddCapture(player)
		if shouldCountStats() then
			statsSvc:AddCaptureGlobal(player)
		end
	end
end

return VictoryController
