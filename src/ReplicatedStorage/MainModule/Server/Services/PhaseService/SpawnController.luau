--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local AvatarService = require(MainModule.Server.Services.AvatarService)
local PhaseConfig = require(MainModule.Shared.Config.PhaseConfig)

local GameState = require(script.Parent.GameState)
type State = GameState.GameState
type PhaseId = PhaseConfig.PhaseId

local SpawnController = {}

function SpawnController.cacheSpawnLocations(state: State): ()
	local spawnsFolder = workspace:FindFirstChild("Spawns")
	if not spawnsFolder then return end

	for _, phaseFolder in spawnsFolder:GetChildren() do
		local folderName = phaseFolder.Name
		local folderSpawns: { SpawnLocation } = {}

		for _, desc in phaseFolder:GetDescendants() do
			if not desc:IsA("SpawnLocation") then continue end

			table.insert(folderSpawns, desc)
			if folderName == "Spectators" then
				table.insert(state.spectatorSpawns, desc)
			else
				table.insert(state.allPhaseSpawns, desc)
			end
		end

		if #folderSpawns > 0 then
			state.spawnCache[folderName] = folderSpawns
		end
	end
end

function SpawnController.setSpawnsForPhase(state: State, phaseId: PhaseId): ()
	local folderName = PhaseConfig.getSpawnFolder(phaseId)
	if not folderName then return end

	local phaseSpawns = state.spawnCache[folderName]
	if not phaseSpawns then return end

	for _, spawn in state.allPhaseSpawns do
		spawn.Enabled = false
	end

	for _, spawn in phaseSpawns do
		spawn.Enabled = true
	end
end

function SpawnController.respawnAllCombatants(getPlayerFaction: (player: Player) -> string?): ()
	for _, player in Players:GetPlayers() do
		local faction = getPlayerFaction(player)
		if faction == "Defenders" or faction == "Raiders" or faction == "Neutral" then
			task.spawn(function()
				AvatarService:LoadCharacter(player)
			end)
		end
	end
end

function SpawnController.cleanup(state: State): ()
	for _, spawn in state.allPhaseSpawns do
		spawn.Enabled = true
	end

	table.clear(state.spawnCache)
	table.clear(state.allPhaseSpawns)
	table.clear(state.spectatorSpawns)
end

return SpawnController
