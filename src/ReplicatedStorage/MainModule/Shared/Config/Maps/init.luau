--!strict
--!native
--!optimize 2

export type GameType = "DT" | "Raid" | "Spar" | "Aim"
export type RaidType = "Phase" | "Hardpoint"
export type PhaseType = "Generic"
export type FeatureFlagName = "ClassSystem" | "Nades" | "Roll"
export type TeamFaction = "Defenders" | "Raiders" | "Neutral"

export type TeamConfig = {
	Name: string,
	DisplayName: string?,
	Faction: TeamFaction,
	Color: BrickColor,
	AutoAssignable: boolean?,
	Selectable: boolean?,
	Order: number?,
}

export type MapConfig = {
	GameType: GameType,
	DefaultPoints: number,
	Hardpoint: boolean,
	Domination: boolean?,
	ClassSystem: boolean,
	RaidType: RaidType?,
	PhaseType: PhaseType?,
	ForceWeapon: ForceWeaponConfig?,
	RespawnTime: number?,
	ForceSideLeaderboard: boolean?,
	Teams: { TeamConfig }?,
	PointBillboardOffsets: { [string]: Vector3 }?,
}

export type ForceWeaponConfig = {
	Defender: string?,
	Raider: string?,
}

export type FeatureFlagsConfig = {
	ClassSystem: boolean?,
	Nades: boolean?,
	Roll: boolean?,
}

export type MapDefinition = {
	DT: MapConfig?,
	Raid: MapConfig?,
	Spar: MapConfig?,
	Aim: MapConfig?,
	FeatureFlags: FeatureFlagsConfig?,
}

local ServerUtils = require(script.Parent.Parent.Utils.Game.ServerUtils)

local Maps = {}

local Onyx: MapDefinition = require(script.Onyx) :: any
local Surrex: MapDefinition = require(script.Surrex) :: any
local Nova: MapDefinition = require(script.Nova) :: any
local Tridenthold: MapDefinition = require(script.Tridenthold) :: any
local Mataro: MapDefinition = require(script.Mataro) :: any
local MataroTesting: MapDefinition = require(script.MataroTesting) :: any
local Overwatch: MapDefinition = require(script.Overwatch) :: any
local Pitgrounds: MapDefinition = require(script.Pitgrounds) :: any
local Silo: MapDefinition = require(script.Silo) :: any
local AimChamber: MapDefinition = require(script.AimChamber) :: any
local SparringArena: MapDefinition = require(script.SparringArena) :: any
local Testing: MapDefinition = require(script.Testing) :: any
local Dreadspire: MapDefinition = require(script.Dreadspire) :: any
local Ironworks: MapDefinition = require(script.Ironworks) :: any

local placeIdToMap: { [number]: { map: MapDefinition, variant: GameType? } } = {
	[70983359460672] = { map = Onyx },
	[106608091105526] = { map = Surrex },
	[118987827318205] = { map = Nova },
	[113408083426676] = { map = Tridenthold },
	[82023579765520] = { map = Mataro },
	[86371032857491] = { map = MataroTesting },
	[117954931852402] = { map = Overwatch },
	[100112194136333] = { map = Silo },

	[134407518396463] = { map = Testing },
	[111392438943897] = { map = Pitgrounds },
	[94785875266022] = { map = AimChamber, variant = "Aim" },
	[106589413108827] = { map = SparringArena, variant = "Spar" },
	[88634683432584] = { map = Dreadspire },

	[103242562426271] = { map = Ironworks },
}

local mapModuleToName: { [MapDefinition]: string } = {
	[Onyx] = "Onyx",
	[Surrex] = "Surrex",
	[Nova] = "Nova",
	[Tridenthold] = "Tridenthold",
	[Mataro] = "Mataro",
	[MataroTesting] = "MataroTesting",
	[Overwatch] = "Overwatch",
	[Pitgrounds] = "Pitgrounds",
	[Silo] = "Silo",
	[AimChamber] = "AimChamber",
	[SparringArena] = "SparringArena",
	[Dreadspire] = "Dreadspire",
	[Testing] = "Testing",
	[Ironworks] = "Ironworks",
}

local DEFAULT_CONFIG: MapConfig = {
	GameType = "DT",
	DefaultPoints = 1000,
	Hardpoint = true,
	ClassSystem = false,
}

local DEFAULT_TEAMS: { TeamConfig } = {
	{
		Name = "Vultarians",
		DisplayName = "Vultarians",
		Faction = "Defenders",
		Color = BrickColor.new("Maroon"),
		AutoAssignable = false,
		Selectable = true,
		Order = 1,
	},
	{
		Name = "Initiates",
		DisplayName = "Initiates",
		Faction = "Defenders",
		Color = BrickColor.new("Bright red"),
		AutoAssignable = false,
		Selectable = false,
		Order = 2,
	},
	{
		Name = "Hostiles",
		DisplayName = "Hostiles",
		Faction = "Raiders",
		Color = BrickColor.new("Bright blue"),
		AutoAssignable = false,
		Selectable = true,
		Order = 3,
	},
	{
		Name = "Spectators",
		DisplayName = "Spectators",
		Faction = "Neutral",
		Color = BrickColor.new("Medium stone grey"),
		AutoAssignable = false,
		Selectable = true,
		Order = 4,
	},
}

local function cloneTeamConfig(teamConfig: TeamConfig): TeamConfig
	return {
		Name = teamConfig.Name,
		DisplayName = teamConfig.DisplayName,
		Faction = teamConfig.Faction,
		Color = teamConfig.Color,
		AutoAssignable = teamConfig.AutoAssignable,
		Selectable = teamConfig.Selectable,
		Order = teamConfig.Order,
	}
end

local function sortTeams(teams: { TeamConfig }): ()
	table.sort(teams, function(a, b)
		local orderA = a.Order or 999
		local orderB = b.Order or 999
		if orderA ~= orderB then
			return orderA < orderB
		end
		return a.Name < b.Name
	end)
end

local function getActiveVariant(mapDef: MapDefinition): GameType
	local isPrivate = ServerUtils.isPrivateServer()

	if isPrivate then
		if mapDef.DT then
			return "DT"
		elseif mapDef.Raid then
			return "Raid"
		elseif mapDef.Spar then
			return "Spar"
		elseif mapDef.Aim then
			return "Aim"
		end
	else
		if mapDef.Raid then
			return "Raid"
		elseif mapDef.DT then
			return "DT"
		elseif mapDef.Spar then
			return "Spar"
		elseif mapDef.Aim then
			return "Aim"
		end
	end

	return "DT"
end

function Maps.getConfig(placeId: number?): MapConfig
	local id = placeId or game.PlaceId
	local entry = placeIdToMap[id]

	if not entry then
		return DEFAULT_CONFIG
	end

	local variant = entry.variant or getActiveVariant(entry.map)
	local variantConfig = entry.map[variant]
	if not variantConfig then
		local mapName = mapModuleToName[entry.map] or "Unknown"
		warn(string.format("[Maps] Map '%s' (placeId: %d) is missing requested variant '%s'", mapName, id, variant))
		return DEFAULT_CONFIG
	end

	return variantConfig
end

function Maps.getTeams(placeId: number?): { TeamConfig }
	local config = Maps.getConfig(placeId)
	local configuredTeams = config.Teams or DEFAULT_TEAMS
	local result = table.create(#configuredTeams)

	for _, teamConfig in configuredTeams do
		table.insert(result, cloneTeamConfig(teamConfig))
	end

	sortTeams(result)
	return result
end

function Maps.getTeamConfig(teamName: string?, placeId: number?): TeamConfig?
	if not teamName then
		return nil
	end

	for _, teamConfig in Maps.getTeams(placeId) do
		if teamConfig.Name == teamName then
			return teamConfig
		end
	end

	return nil
end

function Maps.getTeamFaction(teamName: string?, placeId: number?): TeamFaction?
	local teamConfig = Maps.getTeamConfig(teamName, placeId)
	return if teamConfig then teamConfig.Faction else nil
end

function Maps.getTeamSet(faction: TeamFaction, placeId: number?): { [string]: boolean }
	local result: { [string]: boolean } = {}

	for _, teamConfig in Maps.getTeams(placeId) do
		if teamConfig.Faction == faction then
			result[teamConfig.Name] = true
		end
	end

	return result
end

function Maps.getFactionLists(placeId: number?): { [TeamFaction]: { string } }
	local result: { [TeamFaction]: { string } } = {
		Defenders = {},
		Raiders = {},
		Neutral = {},
	}

	for _, teamConfig in Maps.getTeams(placeId) do
		table.insert(result[teamConfig.Faction], teamConfig.Name)
	end

	return result
end

function Maps.getFirstTeamNameForFaction(faction: TeamFaction, placeId: number?): string?
	for _, teamConfig in Maps.getTeams(placeId) do
		if teamConfig.Faction == faction then
			return teamConfig.Name
		end
	end

	return nil
end

function Maps.getTeamOrder(teamName: string?, placeId: number?): number
	local teamConfig = Maps.getTeamConfig(teamName, placeId)
	return if teamConfig and teamConfig.Order then teamConfig.Order else 999
end

function Maps.getMapName(placeId: number?): string?
	local id = placeId or game.PlaceId
	local entry = placeIdToMap[id]
	if not entry then
		return nil
	end
	return mapModuleToName[entry.map]
end

function Maps.getForceWeapon(placeId: number?, faction: string): string?
	local config = Maps.getConfig(placeId)
	if not config or not config.ForceWeapon then
		return nil
	end

	if faction == "Defenders" then
		return config.ForceWeapon.Defender
	elseif faction == "Raiders" then
		return config.ForceWeapon.Raider
	end
	return nil
end

function Maps.getRespawnTime(placeId: number?): number
	local config = Maps.getConfig(placeId)
	local defaultRespawnTime = 5

	if config.RespawnTime and type(config.RespawnTime) == "number" then
		return config.RespawnTime
	end

	return defaultRespawnTime
end

function Maps.isSparMode(placeId: number?): boolean
	return Maps.getConfig(placeId).GameType == "Spar"
end

function Maps.isAimMode(placeId: number?): boolean
	return Maps.getConfig(placeId).GameType == "Aim"
end

function Maps.forcesSideLeaderboard(placeId: number?): boolean
	return Maps.getConfig(placeId).ForceSideLeaderboard == true
end

function Maps.isHardpointMap(placeId: number?): boolean
	local config = Maps.getConfig(placeId)
	return config.Hardpoint
end

function Maps.isPhaseMap(placeId: number?): boolean
	local config = Maps.getConfig(placeId)
	return config.RaidType == "Phase"
end

function Maps.isDominationMap(placeId: number?): boolean
	local config = Maps.getConfig(placeId)
	return config.Domination == true
end

function Maps.getDefaultPoints(placeId: number?): number
	local config = Maps.getConfig(placeId)
	return config.DefaultPoints
end

function Maps.getFeatureFlags(placeId: number?): FeatureFlagsConfig
	local id = placeId or game.PlaceId
	local entry = placeIdToMap[id]

	if not entry then
		return {}
	end

	return entry.map.FeatureFlags or {}
end

return Maps
