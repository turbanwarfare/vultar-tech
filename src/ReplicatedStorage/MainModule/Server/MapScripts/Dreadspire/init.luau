--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local TeamsService = game:GetService("Teams")

local Dreadspire = {}
Dreadspire.Name = "Dreadspire"

local GROUP_ID = 0
local S_ID = 76074070481176
local P_ID = 77421331768811
local TS_ID = 12655040944
local TP_ID = 937485935

local connections: { RBXScriptConnection } = {}

local function teamNameForRank(rank: number): string
	if rank >= 255 then
		return "Imperator"
	elseif rank >= 250 then
		return "Supreme General"
	elseif rank >= 200 then
		return "Commander"
	elseif rank >= 150 then
		return "Castellan"
	elseif rank >= 10 then
		return "Dreadtrooper"
	else
		return "Trialist"
	end
end

local function assignTeam(player: Player): ()
	local rank = 0
	pcall(function()
		rank = player:GetRankInGroupAsync(GROUP_ID)
	end)

	local team = TeamsService:FindFirstChild(teamNameForRank(rank)) :: Team?
	if team then
		player.Team = team
	end
end

local function charPlayer(character: Model): ()
	local player = Players:GetPlayerFromCharacter(character)
	if not player or not player.Team then
		return
	end

	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		return
	end

	local teamName = player.Team.Name
	if teamName ~= "Dreadtrooper" and teamName ~= "Trialist" then
		return
	end

	local description = humanoid:GetAppliedDescription()
	if teamName == "Dreadtrooper" then
		description.Shirt = S_ID
		description.Pants = P_ID
	elseif teamName == "Trialist" then
		description.Shirt = TS_ID
		description.Pants = TP_ID
	end
	humanoid:ApplyDescriptionResetAsync(description)
end

local function setupPlayer(player: Player): ()
	assignTeam(player)

	if player.Character then
		charPlayer(player.Character)
	end

	table.insert(connections, player.CharacterAdded:Connect(charPlayer))
end

function Dreadspire:init(): () end

function Dreadspire:start(): ()
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end

	table.insert(connections, Players.PlayerAdded:Connect(setupPlayer))
end

function Dreadspire:Cleanup(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

return Dreadspire
