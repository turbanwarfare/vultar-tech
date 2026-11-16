--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local Constants = require(MainModule.Shared.Config.Constants)

local TeamDoorService = {}
TeamDoorService.Name = "TeamDoorService"

local player = Players.LocalPlayer
local connections: { RBXScriptConnection } = {}
local teamDoorsFolder: Instance? = nil

local DEFENDER_TEAMS = Constants.FACTIONS.DEFENDER_TEAMS
local HOSTILE_TEAMS = Constants.FACTIONS.RAIDER_TEAMS

local FACTION_BY_FOLDER: { [string]: string } = {
	Defenders = "defender",
	Hostiles = "hostile",
}

local canPassDefender = false
local canPassHostile = false

local cachedDoorParts: { { part: BasePart, faction: string } } = {}

local function applyCollisionToPart(part: BasePart, faction: string): ()
	if faction == "defender" then
		part.CanCollide = not canPassDefender
	elseif faction == "hostile" then
		part.CanCollide = not canPassHostile
	end
end

local function getFactionForPart(part: Instance): string?
	local current = part.Parent
	while current and current ~= teamDoorsFolder do
		local faction = FACTION_BY_FOLDER[current.Name]
		if faction then
			return faction
		end
		current = current.Parent
	end
	return nil
end

local function buildDoorCache(): ()
	table.clear(cachedDoorParts)
	if not teamDoorsFolder then return end

	for _, doorGroup in teamDoorsFolder:GetChildren() do
		local faction = FACTION_BY_FOLDER[doorGroup.Name]
		if faction then
			for _, part in doorGroup:GetDescendants() do
				if part:IsA("BasePart") then
					table.insert(cachedDoorParts, { part = part, faction = faction })
				end
			end
		end
	end
end

local function applyAllDoorCollisions(): ()
	for _, entry in cachedDoorParts do
		applyCollisionToPart(entry.part, entry.faction)
	end
end

local function onTeamChanged(): ()
	local team = player.Team
	local teamName = if team then team.Name else ""

	canPassDefender = DEFENDER_TEAMS[teamName] == true
	canPassHostile = HOSTILE_TEAMS[teamName] == true

	applyAllDoorCollisions()
end

local function onDescendantAdded(descendant: Instance): ()
	if not descendant:IsA("BasePart") then
		return
	end

	local faction = getFactionForPart(descendant)
	if faction then
		table.insert(cachedDoorParts, { part = descendant, faction = faction })
		applyCollisionToPart(descendant, faction)
	end
end

function TeamDoorService:init(): ()
end

function TeamDoorService:start(): ()
	task.spawn(function()
		teamDoorsFolder = workspace:WaitForChild("TeamDoors", 5)
		if not teamDoorsFolder then
			return
		end

		buildDoorCache()

		table.insert(connections, player:GetPropertyChangedSignal("Team"):Connect(onTeamChanged))
		table.insert(connections, teamDoorsFolder.DescendantAdded:Connect(onDescendantAdded))

		onTeamChanged()
	end)
end

function TeamDoorService:Refresh(): ()
	onTeamChanged()
end

function TeamDoorService:Cleanup(): ()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	canPassDefender = false
	canPassHostile = false
	table.clear(cachedDoorParts)
end

return TeamDoorService
