--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
local DeepCopy = require(MainModule.Shared.Utils.Table.DeepCopy)
local TableMerge = require(MainModule.Shared.Utils.Table.TableMerge)
local APIClient = require(script.APIClient)
local Validation = require(script.Validation)
local PlayerDataStore = require(script.PlayerDataStore)

local SettingsService = {}
SettingsService.Name = "SettingsService"

local serviceConnections: { RBXScriptConnection } = {}
local isInitialized = false
local cachedDefaults: SettingsConfig.SettingsTemplate? = nil
local isClosing = false

local pendingPushThreads: { [number]: thread } = {}
local PUSH_DEBOUNCE = 2

local function pushSettingsToAPIAsync(player: Player): ()
	local userId = player.UserId
	local existing = pendingPushThreads[userId]
	if existing then
		task.cancel(existing)
	end

	pendingPushThreads[userId] = task.delay(PUSH_DEBOUNCE, function()
		pendingPushThreads[userId] = nil
		local data = PlayerDataStore.get(player)
		if not data then
			return
		end
		local pushSuccess = APIClient.push(player.UserId, data)
		if not pushSuccess then
			error(`[SettingsService] Failed to push settings to API for user {player.UserId}`)
		end
	end)
end

local function getCachedDefaults(): SettingsConfig.SettingsTemplate
	if not cachedDefaults then
		cachedDefaults = DeepCopy.copy(SettingsConfig.DefaultSettings)
	end
	return cachedDefaults
end

local function onPlayerAdded(player: Player): ()
	local userId = player.UserId
	local defaults = getCachedDefaults()

	if not PlayerDataStore.loadPlayer(player) then
		return
	end

	local apiData = APIClient.fetch(userId)

	if apiData then
		local merged = TableMerge.mergeWithDefaults(apiData, defaults)
		PlayerDataStore.setData(player, merged)
		return
	end

	local lyraData = PlayerDataStore.get(player)

	if lyraData and lyraData.Settings and next(lyraData.Settings) then
		local merged = TableMerge.mergeWithDefaults(lyraData, defaults)
		PlayerDataStore.setData(player, merged)
		task.spawn(function()
			local pushSuccess = APIClient.push(userId, merged)
			if not pushSuccess then
				error(`[SettingsService] Failed to push initial settings to API for user {userId}`)
			end
		end)
		return
	end

	PlayerDataStore.setData(player, defaults)
	task.spawn(function()
		local pushSuccess = APIClient.push(userId, defaults)
		if not pushSuccess then
			error(`[SettingsService] Failed to push default settings to API for user {userId}`)
		end
	end)
end

local function onPlayerRemoving(player: Player): ()
	local userId = player.UserId

	local pending = pendingPushThreads[userId]
	if pending then
		task.cancel(pending)
		pendingPushThreads[userId] = nil
	end

	local currentData = PlayerDataStore.get(player)

	if currentData then
		local pushSuccess = APIClient.push(userId, currentData)
		if not pushSuccess then
			task.spawn(error, `[SettingsService] CRITICAL: Failed to save settings to API for user {userId} on leave`)
		end
	end

	if not isClosing then
		PlayerDataStore.unloadPlayer(player)
	end
	APIClient.clearErrorState(userId)
end

function SettingsService:init(): ()
	PlayerDataStore.create()
	isInitialized = true
end

function SettingsService:start(): ()
	if not isInitialized then
		self:init()
	end

	table.insert(serviceConnections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(serviceConnections, Players.PlayerRemoving:Connect(onPlayerRemoving))

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		isClosing = true

		local players = Players:GetPlayers()
		local saveCount = #players
		if saveCount == 0 then
			PlayerDataStore.close()
			return
		end

		local completed = 0
		local startTime = os.clock()
		local maxWaitTime = 25

		local MAX_CONCURRENT_SAVES = 10
		local activeSaves = 0
		local playerIndex = 1

		local function saveNext()
			while playerIndex <= saveCount and activeSaves < MAX_CONCURRENT_SAVES do
				local player = players[playerIndex]
				playerIndex += 1
				activeSaves += 1
				task.spawn(function()
					local data = PlayerDataStore.get(player)
					if data then
						local ok, result = pcall(APIClient.push, player.UserId, data)
						if not ok or not result then
							warn(`[SettingsService] Failed to save settings on shutdown for user {player.UserId}`)
						end
					end
					completed += 1
					activeSaves -= 1
					saveNext()
				end)
			end
		end

		saveNext()

		while completed < saveCount and (os.clock() - startTime) < maxWaitTime do
			task.wait(0.05)
		end

		PlayerDataStore.close()
	end)

	Network.Settings.onGetSettings(function(player: Player)
		local data = PlayerDataStore.get(player)
		if data then
			return data
		end
		return getCachedDefaults()
	end)

	Network.Settings.onChangeSetting(function(player: Player, key: string, value: any)
		if not Validation.validateSettingValue(key, value) then
			warn(`[SettingsService] Invalid setting value for {key}`)
			return
		end

		local success = PlayerDataStore.update(player, function(state: SettingsConfig.SettingsTemplate)
			state.Settings[key] = value
			return true
		end)

		if success then
			pushSettingsToAPIAsync(player)
		end
	end)

	Network.Settings.onChangeKeybind(function(player: Player, key: string, value: string)
		local valid, result = Validation.validateKeybindValue(key, value)
		if not valid or not result then
			local data = PlayerDataStore.get(player)
			if data then
				return data.Keybinds[key]
			end
			return nil
		end

		local currentData = PlayerDataStore.get(player)
		if currentData and Validation.checkDuplicateKeybind(currentData.Keybinds, key, result) then
			return currentData.Keybinds[key]
		end

		local updateSuccess = PlayerDataStore.update(player, function(state: SettingsConfig.SettingsTemplate)
			state.Keybinds[key] = result :: string
			return true
		end)

		if updateSuccess then
			pushSettingsToAPIAsync(player)
		end

		return result
	end)

	Network.Settings.onResetSettings(function(player: Player)
		local defaults = getCachedDefaults()

		PlayerDataStore.update(player, function(state: SettingsConfig.SettingsTemplate)
			for section, sectionData in defaults do
				if type(sectionData) == "table" then
					for settingKey, value in sectionData :: any do
						if state[section] and type(state[section]) == "table" then
							(state :: any)[section][settingKey] = value
						end
					end
				end
			end
			return true
		end)

		pushSettingsToAPIAsync(player)

		return PlayerDataStore.get(player) or defaults
	end)

	Network.Settings.onExportSettings(function(player: Player)
		local data = PlayerDataStore.get(player)
		if not data then
			return { success = false }
		end

		local success, code = APIClient.exportSettings(player.UserId, data.Settings)
		if success and code then
			return { success = true, code = code }
		end

		return { success = false }
	end)

	Network.Settings.onImportSettings(function(player: Player, code: string)
		if type(code) ~= "string" or #code == 0 or #code > 64 then
			return { success = false, error = "Invalid code format" }
		end

		local success, importedSettings = APIClient.importSettings(code)
		if not success or not importedSettings then
			return { success = false, error = "Failed to fetch settings" }
		end

		local appliedSettings: { [string]: any } = {}
		for key, value in importedSettings do
			if key ~= "CustomKillSoundId" and Validation.validateSettingValue(key, value) then
				appliedSettings[key] = value
			end
		end

		if next(appliedSettings) == nil then
			return { success = false, error = "No valid settings found" }
		end

		PlayerDataStore.update(player, function(state: SettingsConfig.SettingsTemplate)
			for key, value in appliedSettings do
				state.Settings[key] = value
			end
			return true
		end)

		pushSettingsToAPIAsync(player)

		local updatedData = PlayerDataStore.get(player)
		return { success = true, settings = updatedData }
	end)

	local cursorCheckCooldowns: { [number]: number } = {}
	local cursorCheckCache: { [number]: number } = {}
	local CURSOR_CHECK_COOLDOWN = 5

	Network.Settings.onCheckCursor(function(_player: Player, assetId: number)
		if type(assetId) ~= "number" or assetId <= 0 or assetId ~= math.floor(assetId) then
			return 0
		end

		local cached = cursorCheckCache[assetId]
		if cached then
			return cached
		end

		local userId = _player.UserId
		local now = os.clock()
		local last = cursorCheckCooldowns[userId]
		if last and (now - last) < CURSOR_CHECK_COOLDOWN then
			return assetId
		end
		cursorCheckCooldowns[userId] = now

		local success, result = pcall(InsertService.LoadAsset, InsertService, assetId)

		if success and result then
			local decal = result:FindFirstChildWhichIsA("Decal", true)
			if decal then
				local texture = (decal :: Decal).Texture
				local a, b = string.find(texture, "%d+")
				if a and b then
					local textureId = tonumber(string.sub(texture, a, b))
					result:Destroy()
					local resolved = textureId or assetId
					cursorCheckCache[assetId] = resolved
					return resolved
				end
			end
			result:Destroy()
		end

		cursorCheckCache[assetId] = assetId
		return assetId
	end)
end

function SettingsService:GetPlayerSettings(player: Player): SettingsConfig.SettingsTemplate?
	return PlayerDataStore.get(player)
end

function SettingsService:SetPlayerSetting(player: Player, key: string, value: any): boolean
	if not Validation.validateSettingValue(key, value) then
		return false
	end

	return PlayerDataStore.update(player, function(state: SettingsConfig.SettingsTemplate)
		state.Settings[key] = value
		return true
	end)
end

function SettingsService:Cleanup(): ()
	for _, conn in serviceConnections do
		conn:Disconnect()
	end
	table.clear(serviceConnections)
	cachedDefaults = nil
	isInitialized = false
end

return SettingsService
