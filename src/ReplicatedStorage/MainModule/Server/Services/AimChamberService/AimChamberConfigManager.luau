--!strict
--!native
--!optimize 2

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local AimChamberConfig = require(MainModule.Shared.Config.AimChamberConfig)

type AimChamberSettings = AimChamberConfig.AimChamberSettings

local settingsStore = DataStoreService:GetDataStore(AimChamberConfig.DATASTORE.SETTINGS_STORE)

local AimChamberConfigManager = {}

local playerSettings: { [number]: AimChamberSettings } = {}
local playerPresets: { [number]: string } = {}
local playerCustomSettings: { [number]: AimChamberSettings } = {}
local rateLimits: { [number]: { [string]: number } } = {}
local rejectionCounts: { [number]: { count: number, windowStart: number } } = {}

local playerAddedConn: RBXScriptConnection? = nil
local playerRemovingConn: RBXScriptConnection? = nil

local function getDataStoreKey(userId: number): string
	return AimChamberConfig.DATASTORE.SETTINGS_KEY_PREFIX .. tostring(userId)
end

local function mergeAndClampSettings(savedSettings: any): AimChamberSettings
	local settings = AimChamberConfig.getDefaultSettings()
	if type(savedSettings) ~= "table" then
		return settings
	end

	for key, defaultValue in settings do
		local savedValue = savedSettings[key]
		if savedValue == nil then
			continue
		end

		if typeof(defaultValue) == "number" and typeof(savedValue) == "number" then
			settings[key] = AimChamberConfig.clampValue(key, savedValue)
		elseif typeof(defaultValue) == "boolean" and typeof(savedValue) == "boolean" then
			settings[key] = savedValue
		elseif typeof(defaultValue) == "string" and typeof(savedValue) == "string" then
			if key == "SelectedGun" then
				local gunValid = false
				for _, name in AimChamberConfig.GUN_NAMES do
					if name == savedValue then
						gunValid = true
						break
					end
				end
				if gunValid then
					settings[key] = savedValue
				end
			else
				settings[key] = savedValue
			end
		end
	end

	if type(savedSettings.AiDifficulty) == "string" then
		local difficultyValid = false
		for _, name in AimChamberConfig.AI_DIFFICULTY_NAMES do
			if name == savedSettings.AiDifficulty then
				difficultyValid = true
				break
			end
		end
		if difficultyValid then
			settings.AiDifficulty = savedSettings.AiDifficulty
		end
	end

	if type(savedSettings.AiNpcAccuracy) == "number" then
		settings.AiNpcAccuracy = AimChamberConfig.clampValue("AiNpcAccuracy", savedSettings.AiNpcAccuracy)
	end

	if type(savedSettings.AiMovementProfile) == "string" then
		settings.AiMovementProfile = savedSettings.AiMovementProfile
	end

	if type(savedSettings.AiWeapon) == "string" then
		settings.AiWeapon = savedSettings.AiWeapon
	else
		settings.AiWeapon = "H-82"
	end

	if type(savedSettings.AiRounds) == "number" then
		settings.AiRounds = AimChamberConfig.clampValue("AiRounds", savedSettings.AiRounds)
	else
		settings.AiRounds = 3
	end

	if type(savedSettings.AiHealth) == "number" then
		settings.AiHealth = AimChamberConfig.clampValue("AiHealth", savedSettings.AiHealth)
	else
		settings.AiHealth = 100
	end

	return settings
end

function AimChamberConfigManager.loadPlayerSettings(player: Player): ()
	local userId = player.UserId
	local key = getDataStoreKey(userId)

	local success, saved = pcall(function()
		return settingsStore:GetAsync(key)
	end)

	if success and type(saved) == "table" then
		local settings = mergeAndClampSettings(saved.Settings)
		playerSettings[userId] = settings

		local savedPreset = saved.ActivePreset
		if type(savedPreset) == "string" and (savedPreset == "CUSTOM" or AimChamberConfig.getPreset(savedPreset)) then
			playerPresets[userId] = savedPreset
		else
			playerPresets[userId] = AimChamberConfig.DEFAULT_PRESET
		end
	else
		playerSettings[userId] = AimChamberConfig.getDefaultSettings()
		playerPresets[userId] = AimChamberConfig.DEFAULT_PRESET
	end
end

function AimChamberConfigManager.savePlayerSettings(player: Player): ()
	local userId = player.UserId
	local settings = playerSettings[userId]
	local presetId = playerPresets[userId]
	if not settings then
		return
	end

	local key = getDataStoreKey(userId)
	local data = {
		Settings = settings,
		ActivePreset = presetId or AimChamberConfig.DEFAULT_PRESET,
	}

	pcall(function()
		settingsStore:SetAsync(key, data)
	end)
end

function AimChamberConfigManager.checkRateLimit(player: Player, action: string): boolean
	local userId = player.UserId
	local now = os.clock()
	local limits = rateLimits[userId]
	if not limits then
		limits = {}
		rateLimits[userId] = limits
	end

	local lastTime = limits[action]
	local cooldown = AimChamberConfig.RATE_LIMITS[action]
	if not cooldown then
		return true
	end

	if lastTime and (now - lastTime) < cooldown then
		return false
	end

	limits[action] = now
	return true
end

function AimChamberConfigManager.recordRejection(player: Player): boolean
	local userId = player.UserId
	local now = os.clock()
	local data = rejectionCounts[userId]
	if not data then
		data = { count = 1, windowStart = now }
		rejectionCounts[userId] = data
		return false
	end

	if (now - data.windowStart) > AimChamberConfig.ANOMALY_THRESHOLDS.REPEATED_REJECTION_WINDOW then
		data.count = 1
		data.windowStart = now
		return false
	end

	data.count += 1
	return data.count >= AimChamberConfig.ANOMALY_THRESHOLDS.REPEATED_REJECTION_MAX
end

function AimChamberConfigManager.validateAndApplySettings(player: Player, clientSettings: any): (boolean, string?)
	local userId = player.UserId
	if not playerSettings[userId] then
		AimChamberConfigManager.loadPlayerSettings(player)
	end

	if type(clientSettings) ~= "table" then
		return false, "Invalid settings payload"
	end


	if clientSettings.SelectedGun ~= nil then
		local gunValid = false
		for _, name in AimChamberConfig.GUN_NAMES do
			if name == clientSettings.SelectedGun then
				gunValid = true
				break
			end
		end
		if not gunValid then
			return false, "Invalid gun selection: " .. tostring(clientSettings.SelectedGun)
		end
	end

	local validated = mergeAndClampSettings(clientSettings)
	validated.AssessmentValidation = false
	playerPresets[userId] = "CUSTOM"
	playerCustomSettings[userId] = table.clone(validated)

	playerSettings[userId] = validated
	task.spawn(AimChamberConfigManager.savePlayerSettings, player)

	return true, nil
end

function AimChamberConfigManager.applyPreset(player: Player, presetId: string): (boolean, string?)
	local userId = player.UserId

	if presetId == "CUSTOM" then
		local custom = playerCustomSettings[userId]
		if not custom then
			return false, "No custom settings saved yet"
		end
		playerSettings[userId] = table.clone(custom)
		playerPresets[userId] = "CUSTOM"
		task.spawn(AimChamberConfigManager.savePlayerSettings, player)
		return true, nil
	end

	local preset = AimChamberConfig.getPreset(presetId)
	if not preset then
		return false, "Unknown preset: " .. tostring(presetId)
	end

	local settings = table.clone(preset.Settings)
	settings.SelectedGun = preset.GunRule.DefaultGun

	playerSettings[userId] = settings
	playerPresets[userId] = presetId
	task.spawn(AimChamberConfigManager.savePlayerSettings, player)

	return true, nil
end

function AimChamberConfigManager.getPlayerSettings(player: Player): AimChamberSettings
	local userId = player.UserId
	if not playerSettings[userId] then
		AimChamberConfigManager.loadPlayerSettings(player)
	end
	return playerSettings[userId]
end

function AimChamberConfigManager.getPlayerPreset(player: Player): string
	local userId = player.UserId
	return playerPresets[userId] or AimChamberConfig.DEFAULT_PRESET
end

function AimChamberConfigManager.getConfigState(player: Player): {
	Settings: AimChamberSettings,
	ActivePreset: string,
	Locked: boolean,
}
	local settings = AimChamberConfigManager.getPlayerSettings(player)
	local presetId = AimChamberConfigManager.getPlayerPreset(player)
	local preset = AimChamberConfig.getPreset(presetId)
	local locked = if preset then preset.Locked else false

	return {
		Settings = settings,
		ActivePreset = presetId,
		Locked = locked,
	}
end

function AimChamberConfigManager.getMatchSnapshot(player: Player): AimChamberSettings
	local presetId = AimChamberConfigManager.getPlayerPreset(player)
	local preset = AimChamberConfig.getPreset(presetId)

	if preset and preset.Locked then
		local settings = table.clone(preset.Settings)
		settings.SelectedGun = preset.GunRule.DefaultGun
		return settings
	end

	return table.clone(AimChamberConfigManager.getPlayerSettings(player))
end

function AimChamberConfigManager.start(): ()
	playerAddedConn = Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(AimChamberConfigManager.loadPlayerSettings, player)
	end)

	playerRemovingConn = Players.PlayerRemoving:Connect(function(player: Player)
		local userId = player.UserId
		task.spawn(AimChamberConfigManager.savePlayerSettings, player)
		task.defer(function()
			playerSettings[userId] = nil
			playerPresets[userId] = nil
			playerCustomSettings[userId] = nil
			rateLimits[userId] = nil
			rejectionCounts[userId] = nil
		end)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(AimChamberConfigManager.loadPlayerSettings, player)
	end
end

function AimChamberConfigManager.cleanup(): ()
	if playerAddedConn then
		playerAddedConn:Disconnect()
		playerAddedConn = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	table.clear(playerSettings)
	table.clear(playerPresets)
	table.clear(playerCustomSettings)
	table.clear(rateLimits)
	table.clear(rejectionCounts)
end

function AimChamberConfigManager.getAiDifficulty(player: Player): string
	local userId = player.UserId
	local settings = playerSettings[userId]
	if settings and type(settings.AiDifficulty) == "string" then
		return settings.AiDifficulty
	end
	return AimChamberConfig.DEFAULT_AI_DIFFICULTY
end

function AimChamberConfigManager.applyAiDifficulty(player: Player, difficulty: string, clientPayload: any?): (boolean, string?)
	local userId = player.UserId

	local diffValid = false
	for _, name in AimChamberConfig.AI_DIFFICULTY_NAMES do
		if name == difficulty then
			diffValid = true
			break
		end
	end
	if not diffValid then
		return false, "Unknown AI difficulty: " .. tostring(difficulty)
	end

	if not playerSettings[userId] then
		AimChamberConfigManager.loadPlayerSettings(player)
	end

	local preset = AimChamberConfig.getPreset("AI")
	if not preset then
		return false, "AI preset not found"
	end

	local currentSettings = playerSettings[userId]
	local settings = table.clone(preset.Settings)
	settings.SelectedGun = preset.GunRule.DefaultGun
	settings.AiDifficulty = difficulty
	settings.AiNpcAccuracy = 1.0
	
	if type(clientPayload) == "table" then
		if type(clientPayload.AiWeapon) == "string" then
			settings.AiWeapon = clientPayload.AiWeapon
		end
		if type(clientPayload.AiNpcAccuracy) == "number" then
			settings.AiNpcAccuracy = math.clamp(clientPayload.AiNpcAccuracy, 0.1, 3.0)
		end
		if type(clientPayload.AiRounds) == "number" then
			settings.AiRounds = math.clamp(math.round(clientPayload.AiRounds), 1, 10)
		end
		if type(clientPayload.AiHealth) == "number" then
			settings.AiHealth = math.clamp(math.round(clientPayload.AiHealth), 10, 10000)
		end
		if type(clientPayload.AiMovementProfile) == "string" then
			settings.AiMovementProfile = clientPayload.AiMovementProfile
		end
	else
		if currentSettings then
			settings.AiWeapon = currentSettings.AiWeapon or settings.AiWeapon
			settings.AiNpcAccuracy = currentSettings.AiNpcAccuracy or 1.0
			settings.AiRounds = currentSettings.AiRounds or settings.AiRounds
			settings.AiHealth = currentSettings.AiHealth or settings.AiHealth
			settings.AiMovementProfile = currentSettings.AiMovementProfile or settings.AiMovementProfile
		end
	end
	
	if not settings.AiWeapon then
		settings.AiWeapon = "H-82"
	end

	playerSettings[userId] = settings
	playerPresets[userId] = "AI"
	task.spawn(AimChamberConfigManager.savePlayerSettings, player)

	return true, nil
end

return AimChamberConfigManager
