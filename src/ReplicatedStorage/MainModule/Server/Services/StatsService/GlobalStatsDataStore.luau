--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Lyra = require(Packages:WaitForChild("Lyra", 5))
local Maps = require(MainModule.Shared.Config.Maps)

export type GlobalStats = {
	Kills: number,
	Damage: number,
	Heals: number,
	Caps: number,
	GamesPlayed: number,
	GamesWon: number,
	MVP: number,
}

local GlobalStatsDataStore = {}

local globalStatsStore: any = nil
local loadedPlayers: { [Player]: boolean } = {}
local moduleConnections: { RBXScriptConnection } = {}

local DATASTORE_PREFIX = "VultarGlobalStats_"

local GlobalStatsTemplate: GlobalStats = {
	Kills = 0,
	Damage = 0,
	Heals = 0,
	Caps = 0,
	GamesPlayed = 0,
	GamesWon = 0,
	MVP = 0,
}

function GlobalStatsDataStore.create(): ()
	local mapName = Maps.getMapName() or "Unknown"
	globalStatsStore = Lyra.createPlayerStore({
		name = DATASTORE_PREFIX .. mapName,
		template = GlobalStatsTemplate,
		schema = function(data: any): (boolean, string?)
			if type(data) ~= "table" then
				return false, "Data must be a table"
			end
			return true, nil
		end,
	})

	table.insert(moduleConnections, Players.PlayerRemoving:Connect(function(player)
		GlobalStatsDataStore.unloadPlayer(player)
	end))

	game:BindToClose(function()
		local players = Players:GetPlayers()
		if #players == 0 then
			return
		end

		local completed = 0
		local total = #players
		local startTime = os.clock()
		local maxWaitTime = 25

		local MAX_CONCURRENT = 10
		local active = 0
		local idx = 1

		local function unloadNext()
			while idx <= total and active < MAX_CONCURRENT do
				local player = players[idx]
				idx += 1
				active += 1
				task.spawn(function()
					local ok, err = pcall(function()
						if loadedPlayers[player] then
							globalStatsStore:unloadAsync(player)
							loadedPlayers[player] = nil
						end
					end)
					if not ok then
						warn("[GlobalStatsDataStore] Failed to unload player -", err)
					end
					completed += 1
					active -= 1
					unloadNext()
				end)
			end
		end

		unloadNext()

		while completed < total and (os.clock() - startTime) < maxWaitTime do
			task.wait(0.05)
		end
	end)
end

function GlobalStatsDataStore.loadPlayer(player: Player): boolean
	if loadedPlayers[player] then
		return true
	end

	local success, err = pcall(function()
		globalStatsStore:loadAsync(player)
	end)

	if not success then
		warn(`[GlobalStatsDataStore] Failed to load data for {player.Name}: {err}`)
		return false
	end

	loadedPlayers[player] = true
	return true
end

function GlobalStatsDataStore.get(player: Player): GlobalStats?
	if not loadedPlayers[player] then
		return nil
	end

	local success, data = pcall(function()
		return globalStatsStore:getAsync(player)
	end)

	if success then
		return data
	end

	return nil
end

function GlobalStatsDataStore.getByUserId(userId: number): GlobalStats?
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return nil
	end
	return GlobalStatsDataStore.get(player)
end

function GlobalStatsDataStore.incrementStat(player: Player, statKey: string, amount: number): boolean
	if not loadedPlayers[player] then
		return false
	end

	local success = pcall(function()
		globalStatsStore:updateAsync(player, function(state: GlobalStats)
			local currentValue = (state :: any)[statKey] or 0
			;(state :: any)[statKey] = currentValue + amount
			return true
		end)
	end)

	return success
end

function GlobalStatsDataStore.unloadPlayer(player: Player): boolean
	if not loadedPlayers[player] then
		return true
	end

	local success, err = pcall(function()
		globalStatsStore:unloadAsync(player)
	end)

	loadedPlayers[player] = nil

	if not success then
		warn(`[GlobalStatsDataStore] Failed to unload data for {player.Name}: {err}`)
		return false
	end

	return true
end

function GlobalStatsDataStore.isPlayerLoaded(player: Player): boolean
	return loadedPlayers[player] == true
end

function GlobalStatsDataStore.cleanup(): ()
	for _, conn in moduleConnections do
		conn:Disconnect()
	end
	table.clear(moduleConnections)
	table.clear(loadedPlayers)
end

return GlobalStatsDataStore
