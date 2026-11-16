--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Lyra = require(Packages:WaitForChild("Lyra", 5))

local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
local DeepCopy = require(MainModule.Shared.Utils.Table.DeepCopy)

local PlayerDataStore = {}

local playerStore: any = nil

function PlayerDataStore.create(): ()
	playerStore = Lyra.createPlayerStore({
		name = SettingsConfig.DATASTORE_NAME,
		template = DeepCopy.copy(SettingsConfig.DefaultSettings),
		schema = function(data: any): (boolean, string?)
			if type(data) ~= "table" then
				return false, "Data must be a table"
			end
			if type(data.Settings) ~= "table" then
				return false, "Settings must be a table"
			end
			if type(data.Keybinds) ~= "table" then
				return false, "Keybinds must be a table"
			end
			if type(data.Cosmetics) ~= "table" then
				return false, "Cosmetics must be a table"
			end
			if type(data.Global) ~= "table" then
				return false, "Global must be a table"
			end
			return true, nil
		end,
	})
end

function PlayerDataStore.loadPlayer(player: Player): boolean
	local loadSuccess, loadErr = pcall(function()
		playerStore:loadAsync(player)
	end)

	if not loadSuccess then
		warn(`[PlayerDataStore] Failed to load data for {player.Name}: {loadErr}`)
		return false
	end

	return true
end

function PlayerDataStore.unloadPlayer(player: Player): boolean
	local unloadSuccess, unloadErr = pcall(function()
		playerStore:unloadAsync(player)
	end)

	if not unloadSuccess then
		warn(`[PlayerDataStore] Failed to unload data for {player.Name}: {unloadErr}`)
		return false
	end

	return true
end

function PlayerDataStore.get(player: Player): SettingsConfig.SettingsTemplate?
	local success, data = pcall(function()
		return playerStore:getAsync(player)
	end)

	if success then
		return data
	end

	return nil
end

function PlayerDataStore.update(player: Player, updateFn: (state: SettingsConfig.SettingsTemplate) -> boolean): boolean
	local success, err = pcall(function()
		playerStore:updateAsync(player, updateFn)
	end)

	if not success then
		task.spawn(function()
			error(`[PlayerDataStore] Failed to update data for {player.Name} ({player.UserId}): {err}`)
		end)
	end

	return success
end

function PlayerDataStore.setData(player: Player, data: SettingsConfig.SettingsTemplate): boolean
	local success, err = pcall(function()
		playerStore:updateAsync(player, function(state: SettingsConfig.SettingsTemplate)
			for section, sectionData in data do
				if type(sectionData) == "table" then
					(state :: any)[section] = {}
					for key, value in sectionData :: any do
						(state :: any)[section][key] = value
					end
				end
			end
			return true
		end)
	end)

	if not success then
		task.spawn(function()
			error(`[PlayerDataStore] Failed to set data for {player.Name} ({player.UserId}): {err}`)
		end)
	end

	return success
end

function PlayerDataStore.mergeApiData(player: Player, apiData: SettingsConfig.SettingsTemplate): ()
	local success, err = pcall(function()
		playerStore:updateAsync(player, function(state: SettingsConfig.SettingsTemplate)
			for section, sectionData in apiData do
				if type(sectionData) == "table" then
					for key, value in sectionData :: any do
						if state[section] and type(state[section]) == "table" then
							(state :: any)[section][key] = value
						end
					end
				end
			end
			return true
		end)
	end)

	if not success then
		task.spawn(function()
			error(`[PlayerDataStore] Failed to merge API data for {player.Name} ({player.UserId}): {err}`)
		end)
	end
end

function PlayerDataStore.close(): ()
	pcall(function()
		playerStore:closeAsync()
	end)
end

function PlayerDataStore.getStore(): any
	return playerStore
end

return PlayerDataStore
