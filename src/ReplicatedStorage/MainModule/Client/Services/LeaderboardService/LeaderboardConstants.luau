--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Maps = require(MainModule.Shared.Config.Maps)

local LeaderboardConstants = {}

LeaderboardConstants.DEFENDER_TEAMS = Maps.getTeamSet("Defenders")
LeaderboardConstants.RAIDER_TEAMS = Maps.getTeamSet("Raiders")
LeaderboardConstants.NEUTRAL_TEAMS = Maps.getTeamSet("Neutral")
LeaderboardConstants.SPECTATOR_TEAM = Maps.getFirstTeamNameForFaction("Neutral") or "Spectators"
LeaderboardConstants.TEAM_PRIORITY = {}

for _, teamConfig in Maps.getTeams() do
	LeaderboardConstants.TEAM_PRIORITY[teamConfig.Name] = teamConfig.Order or 999
end

LeaderboardConstants.VULTAR_ICON = "rbxassetid://98751546690059"
LeaderboardConstants.HOSTILES_ICON = "rbxassetid://0"

LeaderboardConstants.UI_UPDATE_INTERVAL = 0.25

return LeaderboardConstants
