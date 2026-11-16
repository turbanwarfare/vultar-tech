--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Trove = require(Packages:WaitForChild("Trove", 5))
local FactionUtils = require(MainModule.Shared.Utils.Game.FactionUtils)
local TeamESPOverhead = require(MainModule.Client.Components.TeamESPOverhead)
local NoChatBadge = require(MainModule.Client.Components.NoChatBadge)
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
local SettingsEnums = require(MainModule.Shared.Config.Settings.SettingsEnums)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local AlertNotification = require(MainModule.Client.Components.AlertNotification)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)

local TeamESPOverheadService = {}
TeamESPOverheadService.Name = "TeamESPOverheadService"

local LocalPlayer = Players.LocalPlayer

local FACTION_NEUTRAL = "Neutral"

local ENEMY_OVERHEAD_DISTANCE = 100
local ENEMY_OVERHEAD_DISTANCE_SQ = ENEMY_OVERHEAD_DISTANCE * ENEMY_OVERHEAD_DISTANCE
local HEARTBEAT_THROTTLE = 0.1

local CLASS_ABBREVIATION: { [string]: string } = {
	Shocktrooper = "[ST]",
	Devastator = "[DEV]",
	Recon = "[RE]",
	FlagBearer = "[FB]",
}

type OverheadData = {
	scope: any,
	gui: BillboardGui,
	displayName: any,
	health: any,
	maxHealth: any,
	mode: any,
	healthConnection: RBXScriptConnection?,
	maxHealthConnection: RBXScriptConnection?,
	classConnection: RBXScriptConnection?,
	noChatGui: BillboardGui?,
	cleanedUp: boolean,
}

local CHAT_ELIGIBILITY_MAX_ATTEMPTS = 4
local CHAT_ELIGIBILITY_RETRY_DELAY = 1
local canUserChatCache: { [number]: boolean } = {}

local function getChatRestrictionStatus(player: Player): boolean
	local userId = player.UserId
	if canUserChatCache[userId] ~= nil then
		return canUserChatCache[userId]
	end

	if userId < 1 then
		canUserChatCache[userId] = false
		return false
	end

	for attempt = 1, CHAT_ELIGIBILITY_MAX_ATTEMPTS do
		local success, result = pcall(function()
			return TextChatService:CanUserChatAsync(userId)
		end)

		if success then
			local canChat = result == true
			canUserChatCache[userId] = not canChat
			return canUserChatCache[userId]
		end

		if attempt < CHAT_ELIGIBILITY_MAX_ATTEMPTS then
			task.wait(CHAT_ELIGIBILITY_RETRY_DELAY)
		end
	end

	canUserChatCache[userId] = false
	return false
end

type EnemyCache = {
	humanoid: Humanoid,
	root: BasePart,
	visible: boolean,
}

local activeOverheads: { [Model]: OverheadData } = {}
local modifiedHumanoids: { [Humanoid]: boolean } = {}
local enemyCache: { [Player]: EnemyCache } = {}
local teammateSet: { [Player]: boolean } = {}
local enemySet: { [Player]: boolean } = {}
local characterToPlayer: { [Model]: Player } = {}
local playerTroves: { [Player]: typeof(Trove.new()) } = {}

local trove: typeof(Trove.new()) = nil
local settingsConnection: RBXScriptConnection? = nil
local heartbeatConnection: RBXScriptConnection? = nil
local reevalThreads: { [Player]: thread } = {}
local SettingsService: any = nil

local cachedEnabled: boolean = false
local cachedNoChatBadgeEnabled: boolean = true
local cachedMode: number = SettingsEnums.TeamESPOverhead.Detailed
local cachedLocalFaction: string? = nil
local lastHeartbeatTime: number = 0
local cachedLocalRootPart: BasePart? = nil

local stopHeartbeatIfEmpty: () -> ()
local ensureHeartbeatRunning: () -> ()

local function syncSettingsCache(): ()
	local svc = SettingsService
	local settings: SettingsConfig.SettingsTemplate = SettingsConfig.DefaultSettings

	if svc and svc.GetSettings then
		local currentSettings = svc:GetSettings()
		if currentSettings then
			settings = currentSettings
		end
	end

	cachedEnabled = settings.Settings.TeamESP == true and settings.Settings.TeamESP_OverheadEnabled ~= false
	cachedNoChatBadgeEnabled = settings.Settings.TeamESP_NoChatBadge ~= false

	local modeVal = settings.Settings.TeamESP_Overhead
	if typeof(modeVal) == "number" then
		cachedMode = modeVal
	else
		cachedMode = SettingsEnums.TeamESPOverhead.Detailed
	end
end

local function updateLocalFactionCache(): ()
	local faction = FactionUtils.getPlayerFaction(LocalPlayer)
	cachedLocalFaction = if faction == "" then nil else faction
end

local function getPlayerByUserId(userId: number): Player?
	if userId == 0 then
		return nil
	end
	for _, p in Players:GetPlayers() do
		if p.UserId == userId then
			return p
		end
	end
	return Players:GetPlayerByUserId(userId)
end

local function addPlayerToSets(player: Player): ()
	teammateSet[player] = nil
	enemySet[player] = nil
	enemyCache[player] = nil

	local sw = ServiceLocator.ScreenWatch()
	local isWatching = sw and typeof(sw.IsWatching) == "function" and sw:IsWatching()

	if isWatching then
		local watchedPlayer = if typeof(sw.GetTargetPlayer) == "function" then sw:GetTargetPlayer() else nil
		if not watchedPlayer then
			local watchedId = if typeof(sw.GetTargetUserId) == "function" then sw:GetTargetUserId() else 0
			if watchedId ~= 0 then
				watchedPlayer = getPlayerByUserId(watchedId)
			end
		end

		if player == watchedPlayer then
			return
		end

		local espMode = if typeof(sw.GetESPMode) == "function" then sw:GetESPMode() else "TEAM"

		if espMode == "OFF" then
			return
		end

		if espMode == "ALL" then
			teammateSet[player] = true
			return
		end

		local areAllies = if watchedPlayer then (
			(watchedPlayer.Team ~= nil and player.Team ~= nil and watchedPlayer.Team == player.Team)
			or FactionUtils.areSameFaction(watchedPlayer, player)
		) else false

		if espMode == "TEAM" then
			if areAllies then
				teammateSet[player] = true
			else
				enemySet[player] = true
			end
		elseif espMode == "ENEMIES" then
			if not areAllies then
				teammateSet[player] = true
			else
				enemySet[player] = true
			end
		end
		return
	end

	if player == LocalPlayer then
		return
	end

	if not cachedLocalFaction then
		return
	end

	local targetFaction = FactionUtils.getPlayerFaction(player)
	if targetFaction == "" or targetFaction == FACTION_NEUTRAL then
		return
	end

	if cachedLocalFaction == FACTION_NEUTRAL or cachedLocalFaction == targetFaction then
		teammateSet[player] = true
	else
		enemySet[player] = true
	end
end

local function rebuildRelationshipSets(): ()
	table.clear(teammateSet)
	table.clear(enemySet)
	table.clear(enemyCache)

	for _, player in Players:GetPlayers() do
		addPlayerToSets(player)
	end
end

local function removePlayerFromSets(player: Player): ()
	teammateSet[player] = nil
	enemySet[player] = nil
	enemyCache[player] = nil
	stopHeartbeatIfEmpty()
end

local function setDefaultOverheadVisible(humanoid: Humanoid, visible: boolean): ()
	if visible then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Subject
		humanoid.HealthDisplayDistance = 100
		humanoid.NameDisplayDistance = 100
		modifiedHumanoids[humanoid] = nil
	else
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayDistance = 0
		humanoid.NameDisplayDistance = 0
		modifiedHumanoids[humanoid] = true
	end
end

local ESP_NAME_LENGTH = 5

local function buildClassDisplayName(baseName: string, character: Model): string
	local truncated = if #baseName > ESP_NAME_LENGTH then string.sub(baseName, 1, ESP_NAME_LENGTH) else baseName
	local className = character:GetAttribute("PlayerClass") :: string?
	if not className then
		return truncated
	end
	local abbrev = CLASS_ABBREVIATION[className]
	if not abbrev then
		return truncated
	end
	return abbrev .. " " .. truncated
end

local function destroyOverhead(character: Model): ()
	local data = activeOverheads[character]
	if not data then
		return
	end

	if data.cleanedUp then
		activeOverheads[character] = nil
		characterToPlayer[character] = nil
		return
	end

	data.cleanedUp = true

	if data.gui then
		data.gui:Destroy()
	end
	if data.noChatGui then
		data.noChatGui:Destroy()
	end

	if data.healthConnection then
		data.healthConnection:Disconnect()
		data.healthConnection = nil
	end
	if data.maxHealthConnection then
		data.maxHealthConnection:Disconnect()
		data.maxHealthConnection = nil
	end
	if data.classConnection then
		data.classConnection:Disconnect()
		data.classConnection = nil
	end

	if data.scope then
		local success, err = pcall(function()
			if data.scope.destroy then
				data.scope:destroy()
			elseif data.scope.doCleanup then
				data.scope:doCleanup()
			end
		end)
		if not success then
			warn("Failed to cleanup scope:", err)
		end
		data.scope = nil
	end

	data.gui = nil
	data.displayName = nil
	data.health = nil
	data.maxHealth = nil
	data.mode = nil
	data.noChatGui = nil

	characterToPlayer[character] = nil
	activeOverheads[character] = nil
end

local function destroyAllOverheads(): ()
	for character in activeOverheads do
		destroyOverhead(character)
	end
	table.clear(activeOverheads)
end

local function createOverhead(character: Model, displayName: string, humanoid: Humanoid): ()
	destroyOverhead(character)

	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end

	local itemScope = Fusion.scoped(Fusion)

	local healthValue = itemScope:Value(humanoid.Health)
	local maxHealthValue = itemScope:Value(humanoid.MaxHealth)
	local displayNameValue = itemScope:Value(buildClassDisplayName(displayName, character))
	local modeValue = itemScope:Value(cachedMode)
	local adorneeValue = itemScope:Value(head :: BasePart?)

	local gui = TeamESPOverhead(itemScope, {
		DisplayName = displayNameValue,
		Health = healthValue,
		MaxHealth = maxHealthValue,
		Mode = modeValue,
		Adornee = adorneeValue,
	})

	local noChatGui = NoChatBadge(itemScope, {
		Adornee = adorneeValue,
	})

	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		gui.Parent = playerGui
		noChatGui.Parent = playerGui
	else
		itemScope:doCleanup()
		return
	end

	local healthConn = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
		healthValue:set(humanoid.Health)
	end)

	local maxHealthConn = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		maxHealthValue:set(humanoid.MaxHealth)
	end)

	local classConn = character:GetAttributeChangedSignal("PlayerClass"):Connect(function()
		displayNameValue:set(buildClassDisplayName(displayName, character))
	end)

	activeOverheads[character] = {
		scope = itemScope,
		gui = gui,
		displayName = displayNameValue,
		health = healthValue,
		maxHealth = maxHealthValue,
		mode = modeValue,
		healthConnection = healthConn,
		maxHealthConnection = maxHealthConn,
		classConnection = classConn,
		noChatGui = noChatGui,
		cleanedUp = false,
	}
end

local function updateOverheadMode(data: OverheadData, mode: number): ()
	if data.mode then
		data.mode:set(mode)
	end
end

local function evaluatePlayer(player: Player): ()
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if FactionUtils.isSpectator(player) then
		humanoid.DisplayName = player.Name
	end

	local isTeammate = teammateSet[player] == true
	local isEnemy = enemySet[player] == true
	local hasOverhead = activeOverheads[character] ~= nil

	local isRestricted = false
	if canUserChatCache[player.UserId] ~= nil then
		isRestricted = canUserChatCache[player.UserId]
	end

	local sw = ServiceLocator.ScreenWatch()
	local isWatching = sw and typeof(sw.IsWatching) == "function" and sw:IsWatching()

	if not isWatching and player == LocalPlayer then
		if hasOverhead then
			destroyOverhead(character)
		end
		return
	end

	local showTeamESP = (cachedEnabled or isWatching) and isTeammate
	local showNoChat = cachedNoChatBadgeEnabled and isRestricted and (isTeammate or (FactionUtils.isSpectator(LocalPlayer) and FactionUtils.isSpectator(player)))
	
	local shouldHaveOverhead = showTeamESP or showNoChat

	if shouldHaveOverhead then
		if showTeamESP then
			setDefaultOverheadVisible(humanoid, false)
		elseif modifiedHumanoids[humanoid] then
			setDefaultOverheadVisible(humanoid, true)
		end
		
		if not hasOverhead and humanoid.Health > 0 then
			createOverhead(character, player.Name, humanoid)
			hasOverhead = true
		end
		
		if hasOverhead then
			local data = activeOverheads[character]
			if data then
				if data.gui then
					data.gui.Enabled = showTeamESP
				end
				if data.noChatGui then
					data.noChatGui.Enabled = showNoChat
				end
			end
		end
	else
		if hasOverhead then
			destroyOverhead(character)
		end
		if isTeammate or modifiedHumanoids[humanoid] then
			setDefaultOverheadVisible(humanoid, true)
		end
	end

	if isEnemy then
		setDefaultOverheadVisible(humanoid, true)
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			enemyCache[player] = {
				humanoid = humanoid,
				root = root,
				visible = true,
			}
			ensureHeartbeatRunning()
		end
	else
		enemyCache[player] = nil
		stopHeartbeatIfEmpty()
	end
end

local function evaluateAllPlayers(): ()
	local sw = ServiceLocator.ScreenWatch()
	local isWatching = sw and typeof(sw.IsWatching) == "function" and sw:IsWatching()

	if not cachedEnabled and not cachedNoChatBadgeEnabled and not isWatching then
		for character in activeOverheads do
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Parent then
				setDefaultOverheadVisible(humanoid, true)
			end
			destroyOverhead(character)
		end
		for humanoid in modifiedHumanoids do
			if humanoid and humanoid.Parent then
				setDefaultOverheadVisible(humanoid, true)
			end
		end
		table.clear(modifiedHumanoids)
		return
	end

	for _, player in Players:GetPlayers() do
		evaluatePlayer(player)
	end
end

local function updateAllModes(): ()
	for _, data in activeOverheads do
		updateOverheadMode(data, cachedMode)
	end
end

local function updateEnemyOverheadVisibility(localPos: Vector3): ()
	for player, cache in enemyCache do
		if not player.Parent then
			local humanoid = cache.humanoid
			if humanoid then
				modifiedHumanoids[humanoid] = nil
			end
			enemyCache[player] = nil
			continue
		end

		local root = cache.root
		if not root or not root.Parent then
			local humanoid = cache.humanoid
			if humanoid then
				modifiedHumanoids[humanoid] = nil
			end
			enemyCache[player] = nil
			continue
		end

		local delta = localPos - root.Position
		local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
		local shouldBeVisible = distSq <= ENEMY_OVERHEAD_DISTANCE_SQ

		if shouldBeVisible ~= cache.visible then
			cache.visible = shouldBeVisible
			local humanoid = cache.humanoid
			if humanoid and humanoid.Parent then
				if shouldBeVisible then
					if modifiedHumanoids[humanoid] then
						setDefaultOverheadVisible(humanoid, true)
					end
				else
					setDefaultOverheadVisible(humanoid, false)
				end
			end
		end
	end
end

stopHeartbeatIfEmpty = function(): ()
	if heartbeatConnection and next(enemyCache) == nil then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

ensureHeartbeatRunning = function(): ()
	if not heartbeatConnection and next(enemyCache) ~= nil and cachedLocalRootPart ~= nil then
		lastHeartbeatTime = 0
		heartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
			lastHeartbeatTime += dt
			if lastHeartbeatTime < HEARTBEAT_THROTTLE then
				return
			end
			lastHeartbeatTime = 0
			debug.profilebegin("TeamESPService::heartbeat")

			local localRoot = cachedLocalRootPart
			if not localRoot or not localRoot.Parent then
				debug.profileend()
				return
			end

			updateEnemyOverheadVisibility(localRoot.Position)
			stopHeartbeatIfEmpty()
			debug.profileend()
		end)
	end
end

local function onCharacterAdded(player: Player, character: Model): ()
	characterToPlayer[character] = player

	if reevalThreads[player] then
		task.cancel(reevalThreads[player])
		reevalThreads[player] = nil
	end

	reevalThreads[player] = task.spawn(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10) :: Humanoid?
		local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		local head = character:FindFirstChild("Head") or character:WaitForChild("Head", 10) :: BasePart?

		reevalThreads[player] = nil

		if not character.Parent or not player.Parent or player.Character ~= character then
			return
		end
		if not humanoid or not root or not head then
			return
		end

		if humanoid.Health <= 0 then
			local conn: RBXScriptConnection
			conn = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
				if humanoid.Health > 0 then
					conn:Disconnect()
					if character.Parent and player.Parent and player.Character == character then
						addPlayerToSets(player)
						evaluatePlayer(player)
					end
				end
			end)
			return
		end

		addPlayerToSets(player)
		evaluatePlayer(player)

		task.delay(0.5, function()
			if character.Parent and player.Parent and player.Character == character then
				local data = activeOverheads[character]
				if data and data.displayName then
					data.displayName:set(buildClassDisplayName(player.Name, character))
				end
			end
		end)
	end)
end

local function onCharacterRemoving(player: Player, character: Model): ()
	if reevalThreads[player] then
		task.cancel(reevalThreads[player])
		reevalThreads[player] = nil
	end

	characterToPlayer[character] = nil
	destroyOverhead(character)
	enemyCache[player] = nil

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		modifiedHumanoids[humanoid] = nil
	end
end

local function registerPlayerSignals(player: Player): ()
	local pt = Trove.new()
	playerTroves[player] = pt

	pt:Connect(player.CharacterAdded, function(character: Model)
		onCharacterAdded(player, character)
	end)

	pt:Connect(player.CharacterRemoving, function(character: Model)
		onCharacterRemoving(player, character)
	end)

	pt:Connect(player:GetPropertyChangedSignal("Team"), function()
		addPlayerToSets(player)
		evaluatePlayer(player)
	end)
end

local function onPlayerAdded(player: Player): ()
	if player == LocalPlayer then
		return
	end

	task.spawn(function()
		getChatRestrictionStatus(player)
		if player.Parent then
			evaluatePlayer(player)
		end
	end)

	registerPlayerSignals(player)
	addPlayerToSets(player)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

local function onPlayerRemoving(player: Player): ()
	local thread = reevalThreads[player]
	if thread then
		task.cancel(thread)
		reevalThreads[player] = nil
	end

	for character, mappedPlayer in characterToPlayer do
		if mappedPlayer == player then
			destroyOverhead(character)
		end
	end

	enemyCache[player] = nil
	removePlayerFromSets(player)

	local pt = playerTroves[player]
	if pt then
		pt:Destroy()
		playerTroves[player] = nil
	end
end

local function onLocalPlayerTeamChanged(): ()
	updateLocalFactionCache()
	rebuildRelationshipSets()
	evaluateAllPlayers()
end

local function onSettingChanged(key: string, value: any): ()
	if key == "TeamESP" or key == "TeamESP_OverheadEnabled" then
		local isMasterEnabled = SettingsService:GetSetting("TeamESP") == true
		local isOverheadEnabled = SettingsService:GetSetting("TeamESP_OverheadEnabled") ~= false
		cachedEnabled = isMasterEnabled and isOverheadEnabled
		evaluateAllPlayers()
	elseif key == "TeamESP_NoChatBadge" then
		cachedNoChatBadgeEnabled = value ~= false
		evaluateAllPlayers()
	elseif key == "TeamESP_Overhead" then
		if typeof(value) == "number" then
			cachedMode = value
		end
		updateAllModes()
	end
end

function TeamESPOverheadService:init(): () end

local function resolveLocalRootPart(character: Model): ()
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if LocalPlayer.Character == character then
		cachedLocalRootPart = root
		ensureHeartbeatRunning()
	end
end

function TeamESPOverheadService:start(): ()
	SettingsService = LazyService.create(MainModule, "SettingsService")()

	local alertScope = Fusion.scoped(Fusion)
	local isAlertVisible = alertScope:Value(false)
	local espKeybind = SettingsService:GetKeybind("ToggleTeamESP") or "V"
	
	local alertGui = AlertNotification(alertScope, {
		Visible = isAlertVisible,
		Title = "TEAM ESP KEYBIND",
		Description = string.format("PRESS <b><font color=\"#FFFFFF\">[%s]</font></b> TO TOGGLE TEAM ESP                               CHANGE KEY IN SETTINGS", string.upper(espKeybind)),
		YOffset = 60,
		OnClose = function()
			isAlertVisible:set(false)
		end
	})
	
	local playerGui = PlayerGuiHelper.waitForPlayerGui()
	if playerGui then
		alertGui.Parent = playerGui
	end

	trove = Trove.new()
	
	local previousToggle = nil
	trove:Connect(SettingsService.SettingChanged, function(key, value)
		if key == "TeamESPToggleKeybindEnabled" then
			if previousToggle ~= nil and value == true then
				isAlertVisible:set(true)
			end
			previousToggle = value
		end
	end)

	syncSettingsCache()
	updateLocalFactionCache()
	rebuildRelationshipSets()

	for _, player in Players:GetPlayers() do
		registerPlayerSignals(player)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end

	trove:Connect(Players.PlayerAdded, onPlayerAdded)
	trove:Connect(Players.PlayerRemoving, onPlayerRemoving)
	trove:Connect(LocalPlayer:GetPropertyChangedSignal("Team"), onLocalPlayerTeamChanged)

	trove:Connect(UserInputService.InputBegan, function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		
		if not SettingsService then return end
		
		local toggleEnabled = SettingsService:GetSetting("TeamESPToggleKeybindEnabled")
		if not toggleEnabled then return end
		
		local keybind = SettingsService:GetKeybind("ToggleTeamESP") or "V"
		local success, keycode = pcall(function()
			return Enum.KeyCode[keybind]
		end)
		if success and input.KeyCode == keycode then
			local behaviour = SettingsService:GetSetting("TeamESPKeybindBehaviour")
			if behaviour == SettingsEnums.TeamESPBehaviour["Overhead GUI"] then
				local currentGUI = SettingsService:GetSetting("TeamESP_OverheadEnabled")
				SettingsService:UpdateSetting("TeamESP_OverheadEnabled", not currentGUI)
			elseif behaviour == SettingsEnums.TeamESPBehaviour.Character then
				local currentCharacter = SettingsService:GetSetting("TeamESP_Highlight")
				SettingsService:UpdateSetting("TeamESP_Highlight", not currentCharacter)
			else
				local currentESP = SettingsService:GetSetting("TeamESP")
				SettingsService:UpdateSetting("TeamESP", not currentESP)
			end
		end
	end)

	if LocalPlayer.Character then
		task.spawn(resolveLocalRootPart, LocalPlayer.Character)
	end

	trove:Connect(LocalPlayer.CharacterAdded, function(character: Model)
		task.spawn(resolveLocalRootPart, character)
	end)

	trove:Connect(LocalPlayer.CharacterRemoving, function()
		cachedLocalRootPart = nil
		if heartbeatConnection then
			heartbeatConnection:Disconnect()
			heartbeatConnection = nil
		end
	end)

	if SettingsService and SettingsService.SettingChanged then
		settingsConnection = SettingsService.SettingChanged:Connect(onSettingChanged)
	end

	evaluateAllPlayers()
	ensureHeartbeatRunning()
end

function TeamESPOverheadService:RefreshAll(): ()
	rebuildRelationshipSets()
	evaluateAllPlayers()
	ensureHeartbeatRunning()
end

function TeamESPOverheadService:Cleanup(): ()
	for _, thread in reevalThreads do
		task.cancel(thread)
	end
	table.clear(reevalThreads)

	if settingsConnection then
		settingsConnection:Disconnect()
		settingsConnection = nil
	end

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	for _, pt in playerTroves do
		pt:Destroy()
	end
	table.clear(playerTroves)

	if trove then
		trove:Destroy()
		trove = nil
	end

	destroyAllOverheads()

	for humanoid in modifiedHumanoids do
		if humanoid and humanoid.Parent then
			setDefaultOverheadVisible(humanoid, true)
		end
	end

	table.clear(modifiedHumanoids)
	table.clear(enemyCache)
	table.clear(teammateSet)
	table.clear(enemySet)
	table.clear(characterToPlayer)
	table.clear(activeOverheads)

	cachedLocalRootPart = nil
end

return TeamESPOverheadService
