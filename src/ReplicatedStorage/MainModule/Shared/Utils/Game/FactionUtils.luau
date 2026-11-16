--!strict
--!native
--!optimize 2

local Constants = require(script.Parent.Parent.Parent.Config.Constants)

local FactionUtils = {}

local DEFENDER_TEAMS: { [string]: boolean } = Constants.FACTIONS.DEFENDER_TEAMS
local RAIDER_TEAMS: { [string]: boolean } = Constants.FACTIONS.RAIDER_TEAMS
local NEUTRAL_TEAMS: { [string]: boolean } = Constants.FACTIONS.NEUTRAL_TEAMS

FactionUtils.DEFENDER_TEAMS = DEFENDER_TEAMS
FactionUtils.RAIDER_TEAMS = RAIDER_TEAMS
FactionUtils.NEUTRAL_TEAMS = NEUTRAL_TEAMS

local FACTION_DEFENDERS = "Defenders"
local FACTION_RAIDERS = "Raiders"
local FACTION_NEUTRAL = "Neutral"
local FACTION_NONE = ""

local teamNameToFaction: { [string]: string } = {}

for teamName in DEFENDER_TEAMS do
	teamNameToFaction[teamName] = FACTION_DEFENDERS
end

for teamName in RAIDER_TEAMS do
	teamNameToFaction[teamName] = FACTION_RAIDERS
end

for teamName in NEUTRAL_TEAMS do
	teamNameToFaction[teamName] = FACTION_NEUTRAL
end

function FactionUtils.getPlayerFaction(player: Player): string
	local team = player.Team
	if not team then
		return FACTION_NONE
	end
	return teamNameToFaction[team.Name] or FACTION_NONE
end

function FactionUtils.getTeamFaction(teamName: string): string
	return teamNameToFaction[teamName] or FACTION_NONE
end

function FactionUtils.areEnemies(playerA: Player, playerB: Player): boolean
	local teamA = playerA.Team
	local teamB = playerB.Team
	if not teamA or not teamB then
		return false
	end

	local factionA = teamNameToFaction[teamA.Name]
	local factionB = teamNameToFaction[teamB.Name]
	if not factionA or not factionB then
		return false
	end
	if factionA == FACTION_NEUTRAL or factionB == FACTION_NEUTRAL then
		return false
	end

	return factionA ~= factionB
end

function FactionUtils.areSameFaction(playerA: Player, playerB: Player): boolean
	local teamA = playerA.Team
	local teamB = playerB.Team
	if not teamA or not teamB then
		return false
	end

	local factionA = teamNameToFaction[teamA.Name]
	local factionB = teamNameToFaction[teamB.Name]
	if not factionA or not factionB then
		return false
	end

	return factionA == factionB
end

function FactionUtils.isSpectator(player: Player): boolean
	local team = player.Team
	if not team then
		return false
	end
	return NEUTRAL_TEAMS[team.Name] == true
end

function FactionUtils.isDefender(player: Player): boolean
	local team = player.Team
	if not team then
		return false
	end
	return DEFENDER_TEAMS[team.Name] == true
end

function FactionUtils.isRaider(player: Player): boolean
	local team = player.Team
	if not team then
		return false
	end
	return RAIDER_TEAMS[team.Name] == true
end

return FactionUtils
