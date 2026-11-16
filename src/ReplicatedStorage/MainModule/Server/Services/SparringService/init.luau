--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local Maps = require(MainModule.Shared.Config.Maps)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

local getStatsService = LazyService.create(MainModule, "StatsService")

local ArenaService: any = nil
local ArenaMatchService: any = nil
local ArenaStatsService: any = nil
local ArenaLeaderboardService: any = nil
local ArenaUIService: any = nil
local ArenaLobbyService: any = nil

local SparringService = {}
SparringService.Name = "SparringService"

function SparringService:init()
	if not Maps.isSparMode() then
		return
	end

	ArenaService = require(script.ArenaService)
	ArenaMatchService = require(script.ArenaMatchService)
	ArenaStatsService = require(script.ArenaStatsService)
	ArenaLeaderboardService = require(script.ArenaLeaderboardService)
	ArenaUIService = require(script.ArenaUIService)
	ArenaLobbyService = require(script.ArenaLobbyService)

	ArenaService.setArenaMatchService(ArenaMatchService)
	ArenaMatchService.setArenaService(ArenaService)

	ArenaMatchService.setOnMatchEnded(function(arenaNumber: number, winner: Player, loser: Player, isMutualMatchWin: boolean?)
		local matchData = ArenaMatchService.getActiveMatch(arenaNumber)
		if matchData then
			ArenaStatsService.RecordMatchResult(winner, loser, matchData, isMutualMatchWin)
		end
		ArenaMatchService.cleanupMatch(arenaNumber, winner, loser)
	end)

	ArenaMatchService.setOnDamageDealt(function(attacker: Player, damage: number)
		ArenaStatsService.AddDamage(attacker, damage)
		local StatsService = getStatsService()
		if StatsService then
			StatsService:AddDamageGlobal(attacker, damage)
		end
	end)

	ArenaMatchService.setOnPlayerKilled(function(killer: Player, _victim: Player)
		ArenaStatsService.AddKill(killer, 1)
		local StatsService = getStatsService()
		if StatsService then
			StatsService:AddKillGlobal(killer)
		end
	end)
end

function SparringService:start()
	if not Maps.isSparMode() then
		return
	end

	Network.Spar.init()

	local Core = require(MainModule.Shared.Network.Core)
	Core.getOrCreateRemoteEvent("Spar_PadStatus")
	Core.getOrCreateRemoteEvent("Spar_SelectOption")
	Core.getOrCreateRemoteEvent("Spar_ToggleSetting")
	Core.getOrCreateRemoteEvent("Spar_StartMatch")
	Core.getOrCreateRemoteEvent("Spar_MatchStarted")
	Core.getOrCreateRemoteEvent("Spar_ArenaStatus")
	Core.getOrCreateRemoteEvent("Spar_SimulateRoundWin")
	Core.getOrCreateRemoteEvent("Spar_SuppressDeathScreen")

	Network.Spar.onSelectOption(function(player: Player, arenaNumber: number, optionType: string, value: string)
		local sanitized = ArenaService.sanitizeSelectionValue(optionType, value)
		if not sanitized then
			return
		end
		ArenaService.handleSelectOption(player, arenaNumber, optionType, sanitized)
		ArenaUIService.broadcastChange(arenaNumber, player, optionType, sanitized)
	end)

	Network.Spar.onToggleSetting(function(player: Player, arenaNumber: number, settingName: string)
		ArenaService.handleToggleSetting(player, arenaNumber, settingName)
	end)

	Network.Spar.onStartMatch(
		function(player: Player, arenaNumber: number, map: string, gun: string, health: string, rounds: string, showVersusGUI: boolean, instantRespawn: boolean, isSoloMode: boolean?, forcefieldDuration: string?)
			if not map or not gun or not health or not rounds then
				warn(
					"[SparringService] onStartMatch: missing selections from",
					player.Name,
					"(arena",
					arenaNumber,
					") —",
					"map=",
					map,
					"gun=",
					gun,
					"health=",
					health,
					"rounds=",
					rounds
				)
				return
			end

			local sanitizedMap = ArenaService.sanitizeSelectionValue("map", map)
			local sanitizedGun = ArenaService.sanitizeSelectionValue("gun", gun)
			local sanitizedHealth = ArenaService.sanitizeSelectionValue("health", health)
			local sanitizedRounds = ArenaService.sanitizeSelectionValue("rounds", rounds)
			if not sanitizedMap or not sanitizedGun or not sanitizedHealth or not sanitizedRounds then
				warn("[SparringService] onStartMatch: rejected selections from", player.Name, "(arena", arenaNumber, ")")
				return
			end

			local sanitizedForcefield = if forcefieldDuration then ArenaService.sanitizeSelectionValue("forcefield", forcefieldDuration) else nil

			ArenaService.applySelectionsFromStart(
				player,
				arenaNumber,
				sanitizedMap,
				sanitizedGun,
				sanitizedHealth,
				sanitizedRounds,
				showVersusGUI,
				instantRespawn,
				sanitizedForcefield
			)
			ArenaService.handleStartMatch(player, arenaNumber, isSoloMode)
		end
	)

	Network.Spar.onSimulateRoundWin(function(player: Player, arenaNumber: number)
		local matchData = ArenaMatchService.getActiveMatch(arenaNumber)
		if not matchData then
			warn("[SparringService] SimulateRoundWin: no active match for arena", arenaNumber)
			return
		end

		local loser = if matchData.player1 == player then matchData.player2 else matchData.player1
		ArenaMatchService.endMatch(arenaNumber, player, loser)
	end)

	Network.Spar.onRevealArena(function(player: Player, arenaNumber: number, roundNumber: number)
		ArenaMatchService.revealArena(arenaNumber, player, roundNumber)
	end)

	Network.Spar.onExitMatch(function(player: Player, arenaNumber: number)
		ArenaMatchService.handleExitMatch(player, arenaNumber)
	end)

	ArenaService.initAll()
	ArenaService.start()
	ArenaMatchService.start()
	ArenaStatsService.start()
	ArenaLeaderboardService.start()
	ArenaLobbyService.start()
end

function SparringService:Cleanup()
	if not ArenaService then
		return
	end
	ArenaService.cleanup()
	ArenaMatchService.cleanup()
	ArenaStatsService.cleanup()
	ArenaLeaderboardService.cleanup()
	ArenaUIService.cleanup()
	ArenaLobbyService.cleanup()
end

return SparringService
