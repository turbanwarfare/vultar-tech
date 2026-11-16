--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local RobloxTeams = game:GetService("Teams")

local MainModule = script.Parent.Parent.Parent
local AvatarService = require(MainModule.Server.Services.AvatarService)
local Network = require(MainModule.Shared.Network)
local Maps = require(MainModule.Shared.Config.Maps)
local Constants = require(script.Constants)
local Types = require(script.Types)
local ServerUtils = require(MainModule.Shared.Utils.Game.ServerUtils)

type Faction = Types.Faction
type GameMode = Types.GameMode

local TeamService = {}
TeamService.Name = "TeamService"

local teams: { [string]: Team } = {}
local teamConfigs: { [string]: Types.TeamConfig } = {}
local factions: { [Faction]: { Team } } = {}
local teamToFaction: { [Team]: Faction } = {}
local currentGameMode: GameMode = "DEFAULT"

local serviceConnections: { RBXScriptConnection } = {}

local spectatorSpawnCache: { SpawnLocation } = {}
local spectatorSpawnRng = Random.new()

local function createTeam(config: Types.TeamConfig): Team
	local existing = RobloxTeams:FindFirstChild(config.Name)
	if existing and existing:IsA("Team") then
		existing.TeamColor = config.Color
		existing.AutoAssignable = config.AutoAssignable == true
		return existing
	end

	local team = Instance.new("Team")
	team.Name = config.Name
	team.TeamColor = config.Color
	team.AutoAssignable = config.AutoAssignable == true
	team.Parent = RobloxTeams

	return team
end

local function buildFactions(): ()
	for factionName: Faction, memberNames in Constants.FACTIONS do
		local factionTeams: { Team } = {}
		for _, teamName in memberNames do
			local team = teams[teamName]
			if team then
				table.insert(factionTeams, team)
				teamToFaction[team] = factionName
			end
		end
		factions[factionName] = factionTeams
	end
end

local function isPlayerInGroup(player: Player, groupId: number): boolean
	local ok, inGroup = pcall(player.IsInGroup, player, groupId)
	return ok and inGroup == true
end

local function detectGameMode(): GameMode
	if ServerUtils.isPrivateServer() then
		return "DT"
	end

	return "RAID"
end

local function getInitialSafeTeam(): string
	if ServerUtils.isPrivateServer() then
		return Maps.getFirstTeamNameForFaction("Neutral") or "Spectators"
	end

	return Maps.getFirstTeamNameForFaction("Raiders") or "Hostiles"
end

local function cacheSpectatorSpawns(): ()
	local spawnsFolder = workspace:FindFirstChild("Spawns")
	if spawnsFolder then
		local spectatorsFolder = spawnsFolder:FindFirstChild("Spectators")
			or spawnsFolder:FindFirstChild("Spectator Spawns")
			or spawnsFolder:FindFirstChild("Spectator")
			or spawnsFolder:FindFirstChild("Spectator Spawn")
		if spectatorsFolder then
			for _, desc in spectatorsFolder:GetDescendants() do
				if desc:IsA("SpawnLocation") then
					table.insert(spectatorSpawnCache, desc)
				end
			end
		end
	end

	if #spectatorSpawnCache == 0 then
		local looseFolder = workspace:FindFirstChild("Spectators")
			or workspace:FindFirstChild("Spectator Spawns")
			or workspace:FindFirstChild("Spectator")
			or workspace:FindFirstChild("Spectator Spawn")
		if looseFolder then
			for _, desc in looseFolder:GetDescendants() do
				if desc:IsA("SpawnLocation") then
					table.insert(spectatorSpawnCache, desc)
				end
			end
		end
	end

	if #spectatorSpawnCache == 0 then
		for _, desc in workspace:GetDescendants() do
			if desc:IsA("SpawnLocation") then
				local lowerName = desc.Name:lower()
				if lowerName == "spectator spawns" or lowerName == "spectator spawn" or lowerName == "spectators" or lowerName == "spectator" then
					table.insert(spectatorSpawnCache, desc)
				end
			end
		end
	end
end

local function updateRespawnLocation(player: Player, teamName: string): ()
	if currentGameMode ~= "DT" then
		return
	end
	local team = teams[teamName]
	if not team then
		return
	end
	local faction = teamToFaction[team]
	if faction == "Neutral" then
		if #spectatorSpawnCache > 0 then
			player.RespawnLocation = spectatorSpawnCache[spectatorSpawnRng:NextInteger(1, #spectatorSpawnCache)]
		end
	else
		player.RespawnLocation = nil :: SpawnLocation?
	end
end

local function reconcilePlayerTeam(player: Player): ()
	if not player.Parent then
		return
	end
	if ServerUtils.isPrivateServer() then
		return
	end

	local defenderTeams = Maps.getFactionLists()["Defenders"] or {}
	local mainTeam = defenderTeams[1] or "Vultarians"
	local initiateTeam = defenderTeams[2] or "Initiates"

	local targetTeamName: string? = nil

	if player:GetRankInGroupAsync(Constants.GROUPS.Initiates) >= 120 and teams[initiateTeam] then
		targetTeamName = initiateTeam
	elseif isPlayerInGroup(player, Constants.GROUPS.Vultarians) and teams[mainTeam] then
		targetTeamName = mainTeam
	end

	if targetTeamName and player.Parent then
		local targetTeam = teams[targetTeamName]
		if targetTeam and player.Team ~= targetTeam then
			player.Team = targetTeam
			updateRespawnLocation(player, targetTeamName)
		end
	end
end

local function onPlayerAdded(player: Player): ()
	local defaultTeamName = getInitialSafeTeam()
	local defaultTeam = teams[defaultTeamName]
	if defaultTeam then
		player.Team = defaultTeam
	end
	updateRespawnLocation(player, defaultTeamName)

	if not ServerUtils.isPrivateServer() then
		task.spawn(reconcilePlayerTeam, player)
	end
end

function TeamService:init(): ()
	for _, config in Constants.TEAMS do
		local team = createTeam(config)
		teams[config.Name] = team
		teamConfigs[config.Name] = config
	end
	buildFactions()
	currentGameMode = detectGameMode()
end

local function getDefenderTeamForPlayer(player: Player): string
	local defenderTeams = Maps.getFactionLists()["Defenders"] or {}
	local mainTeam = defenderTeams[1] or "Vultarians"
	local initiateTeam = defenderTeams[2] or "Initiates"

	if isPlayerInGroup(player, Constants.GROUPS.Vultarians) and teams[mainTeam] then
		return mainTeam
	end

	if isPlayerInGroup(player, Constants.GROUPS.Initiates) and teams[initiateTeam] then
		return initiateTeam
	end

	return Maps.getFirstTeamNameForFaction("Defenders") or mainTeam
end

local function respawnPlayer(player: Player): ()
	task.defer(function()
		AvatarService:LoadCharacter(player)
	end)
end

local TEAM_CHANGE_COOLDOWN = 3
local teamChangeCooldowns: { [number]: number } = {}

local function isPlayerAlive(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	return humanoid.Health > 0
end

local function getLegacyChoiceTeamName(player: Player, choice: string): string?
	if choice == "Defenders" then
		return getDefenderTeamForPlayer(player)
	elseif choice == "Raiders" then
		return Maps.getFirstTeamNameForFaction("Raiders")
	elseif choice == "Neutral" then
		return Maps.getFirstTeamNameForFaction("Neutral")
	end

	return nil
end

local function getSelectableTeamName(player: Player, choice: string): string?
	local directTeam = teams[choice]
	local directConfig = teamConfigs[choice]
	if directTeam and directConfig and directConfig.Selectable ~= false then
		return choice
	end

	local legacyTeamName = getLegacyChoiceTeamName(player, choice)
	if not legacyTeamName then
		return nil
	end

	local legacyConfig = teamConfigs[legacyTeamName]
	if legacyConfig and legacyConfig.Selectable == false then
		return nil
	end

	return if teams[legacyTeamName] then legacyTeamName else nil
end

local function handleTeamChangeRequest(player: Player, choice: string): Network.TeamChangeResult
	if not isPlayerAlive(player) then
		return { success = false, error = "Cannot change teams while dead" }
	end

	local now = os.clock()
	local userId = player.UserId
	local lastChange = teamChangeCooldowns[userId]
	if lastChange and (now - lastChange) < TEAM_CHANGE_COOLDOWN then
		return { success = false, error = "Please wait before switching teams" }
	end

	local currentTeam = player.Team
	local currentFaction: Faction? = nil
	if currentTeam then
		currentFaction = teamToFaction[currentTeam]
	end

	local teamName: string?
	local chosenConfig = teamConfigs[choice]
	if chosenConfig and chosenConfig.Faction == "Defenders" then
		teamName = getDefenderTeamForPlayer(player)
	else
		teamName = getSelectableTeamName(player, choice)
	end
	if not teamName then
		return { success = false, error = "Invalid team choice" }
	end

	local team = teams[teamName]
	if not team then
		return { success = false, error = "Invalid team choice" }
	end

	if currentTeam == team then
		return { success = false, error = "Already on " .. teamName }
	end

	local targetFaction = teamToFaction[team]
	if currentFaction and targetFaction and choice == targetFaction then
		return { success = false, error = "Already on " .. targetFaction }
	end

	player.Team = team
	updateRespawnLocation(player, teamName)
	respawnPlayer(player)
	teamChangeCooldowns[userId] = now
	return { success = true, team = teamName }
end

function TeamService:start(): ()
	cacheSpectatorSpawns()

	table.insert(serviceConnections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(
		serviceConnections,
		Players.PlayerRemoving:Connect(function(player: Player)
			teamChangeCooldowns[player.UserId] = nil
		end)
	)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Network.Teams.onChangeTeam(function(player: Player, choice: string)
		return handleTeamChangeRequest(player, choice)
	end)

	Network.Teams.onGetCurrentTeam(function(player: Player)
		local team = player.Team
		if team then
			return team.Name
		end
		return nil
	end)
end

function TeamService:GetGameMode(): GameMode
	return currentGameMode
end

function TeamService:GetTeam(name: string): Team?
	return teams[name]
end

function TeamService:GetAllTeams(): { [string]: Team }
	return teams
end

function TeamService:GetFaction(factionName: Faction): { Team }?
	return factions[factionName]
end

function TeamService:GetTeamFaction(team: Team): Faction?
	return teamToFaction[team]
end

function TeamService:GetPlayerFaction(player: Player): Faction?
	local team = player.Team
	if not team then
		return nil
	end
	return teamToFaction[team]
end

function TeamService:AreAllies(player1: Player, player2: Player): boolean
	local faction1 = self:GetPlayerFaction(player1)
	local faction2 = self:GetPlayerFaction(player2)

	if not faction1 or not faction2 then
		return false
	end

	return faction1 == faction2
end

function TeamService:CanDamage(attacker: Player, target: Player): boolean
	local targetFaction = self:GetPlayerFaction(target)
	if targetFaction == "Neutral" then
		return false
	end

	return not self:AreAllies(attacker, target)
end

function TeamService:AssignPlayerToTeam(player: Player, teamName: string): boolean
	local team = teams[teamName]
	if not team then
		return false
	end

	player.Team = team
	updateRespawnLocation(player, teamName)
	respawnPlayer(player)
	return true
end

function TeamService:GetPlayerTeam(player: Player): string?
	local team = player.Team
	if team then
		return team.Name
	end
	return nil
end

function TeamService:Cleanup(): ()
	for _, conn in serviceConnections do
		conn:Disconnect()
	end
	table.clear(serviceConnections)
	table.clear(spectatorSpawnCache)
end

return TeamService
