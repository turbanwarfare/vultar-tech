--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Trove = require(Packages:WaitForChild("Trove", 5))
local Network = require(MainModule.Shared.Network)
local Maps = require(MainModule.Shared.Config.Maps)
local StatsConfig = require(MainModule.Shared.Config.Stats.StatsConfig)
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
local Signal = require(MainModule.Shared.Utils.State.Signal)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)
local LeaderboardComponent = require(MainModule.Client.Components.Leaderboard)
local SideLeaderboardComponent = require(MainModule.Client.Components.SideLeaderboard)
local PlayerStatsStore = require(MainModule.Client.Components.Leaderboard.PlayerStatsStore)
local SettingsEnums = require(MainModule.Shared.Config.Settings.SettingsEnums)

local LeaderboardConstants = require(script.LeaderboardConstants)
local LeaderboardCache = require(script.LeaderboardCache)
local LeaderboardUIConstants = require(MainModule.Client.Components.Leaderboard.Constants)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local AnimatedCardService = require(MainModule.Client.Services.AnimatedCardService)

type LeaderboardEntry = StatsConfig.LeaderboardEntry
type PlayerStats = StatsConfig.PlayerStats
type FactionData = LeaderboardComponent.FactionData
type TeamFaction = "Defenders" | "Raiders" | "Neutral"

local LeaderboardService = {}
LeaderboardService.Name = "LeaderboardService"

local localPlayer = Players.LocalPlayer
local isInitialized = false
local isVisible = false
local isBlocked = false

local leaderboardUI: ScreenGui? = nil
local sideLeaderboardUI: ScreenGui? = nil
local isSideMode = false
local sideVisibleState: any = nil
local visibilityChanged = Signal.new()
local dataChanged = Signal.new()

local fusionScope: any = nil
local visibleState: any = nil
local defendersDataState: any = nil
local raidersDataState: any = nil
local defendersTotalsState: any = nil
local raidersTotalsState: any = nil
local statsStore: PlayerStatsStore.PlayerStatsStore? = nil

local trove: typeof(Trove.new()) = nil

local flushScheduled = false
local flushDelayThread: thread? = nil
local sideSettleThread: thread? = nil

local cachedKeybind = Enum.KeyCode.Tab

local deltaBatchConnection: { Disconnect: () -> () }? = nil

local SIDE_SETTLE_TIME = 0.5

local usesCombinedView = Maps.isSparMode() or Maps.isAimMode()

local function getFactionTeamLabels(faction: TeamFaction): { any }
	local labels = {}

	for _, teamConfig in Maps.getTeams() do
		if teamConfig.Faction == faction then
			table.insert(labels, {
				name = teamConfig.Name,
				displayName = teamConfig.DisplayName or teamConfig.Name,
				color = teamConfig.Color.Color,
				order = teamConfig.Order or 999,
			})
		end
	end

	return labels
end

local function isDeployMenuActive(): boolean
	local svc = ServiceLocator.Loading()
	if svc then
		local success, result = pcall(function()
			return svc:IsActive()
		end)
		if success and result then
			return true
		end
	end

	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		local loadingScreen = playerGui:FindFirstChild("VultarLoadingScreen")
		if loadingScreen and loadingScreen:IsA("ScreenGui") and loadingScreen.Enabled then
			return true
		end
	end

	return false
end

local function getKeybind(): Enum.KeyCode
	local svc = ServiceLocator.Settings()
	local keyName = "Tab"
	if svc and typeof(svc.GetKeybind) == "function" then
		keyName = svc:GetKeybind("Leaderboard") or "Tab"
	else
		local settings = SettingsConfig.DefaultSettings.Keybinds
		keyName = settings.Leaderboard or "Tab"
	end
	local success, keyCode = pcall(function()
		return Enum.KeyCode[keyName]
	end)
	if success and keyCode then
		return keyCode
	end
	return Enum.KeyCode.Tab
end

local function disableDefaultLeaderboard()
	local maxAttempts = 10
	for _ = 1, maxAttempts do
		local success = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
		if success then
			break
		end
		task.wait(0.1)
	end
end

local function flushUIUpdate(): ()
	if not LeaderboardCache.isDirty() or (not isVisible and not isSideMode) then
		return
	end

	if LeaderboardCache.isSortDirty() then
		LeaderboardCache.sortAndRebuildIndexMaps()
	end

	LeaderboardCache.clearDirtyFlags()

	local totalsUpdated = false

	if LeaderboardCache.isTotalsDirty() then
		LeaderboardCache.clearTotalsDirty()
		local defTotals = LeaderboardCache.getDefenderTotals()
		local raidTotals = LeaderboardCache.getRaiderTotals()
		if defendersTotalsState then
			defendersTotalsState:set({
				Kills = defTotals.Kills,
				Damage = defTotals.Damage,
				Heals = defTotals.Heals,
				Captures = defTotals.Captures,
			})
		end
		if raidersTotalsState then
			raidersTotalsState:set({
				Kills = raidTotals.Kills,
				Damage = raidTotals.Damage,
				Heals = raidTotals.Heals,
				Captures = raidTotals.Captures,
			})
		end
		totalsUpdated = true
	end

	if LeaderboardCache.isStructureDirty() then
		LeaderboardCache.clearStructureDirty()
		local defenders = LeaderboardCache.getDefenders()
		local raiders = LeaderboardCache.getRaiders()
		local defTotals = LeaderboardCache.getDefenderTotals()
		local raidTotals = LeaderboardCache.getRaiderTotals()

		if defendersDataState then
			defendersDataState:set({
				name = "Defenders",
				displayName = "IMPERIUM OF VULTAR",
				icon = LeaderboardConstants.VULTAR_ICON,
				entries = defenders,
				totals = defTotals,
				playerCount = #defenders,
				teamLabels = getFactionTeamLabels("Defenders"),
			})
		end

		if raidersDataState then
			raidersDataState:set({
				name = "Hostiles",
				displayName = "HOSTILES",
				icon = LeaderboardConstants.HOSTILES_ICON,
				entries = raiders,
				totals = raidTotals,
				playerCount = LeaderboardCache.getRaiderCountExcludingSpectators(),
				teamLabels = getFactionTeamLabels("Raiders"),
			})
		end

		dataChanged:Fire()
	elseif totalsUpdated and usesCombinedView then
		-- Only the combined spar/aim view reads totals from the faction data; the faction
		-- panels read them from the totals states set above.
		local defTotals = LeaderboardCache.getDefenderTotals()
		local raidTotals = LeaderboardCache.getRaiderTotals()

		if defendersDataState then
			local currentData = Fusion.peek(defendersDataState)
			if currentData then
				local newData = table.clone(currentData)
				newData.totals = defTotals
				defendersDataState:set(newData)
			end
		end

		if raidersDataState then
			local currentData = Fusion.peek(raidersDataState)
			if currentData then
				local newData = table.clone(currentData)
				newData.totals = raidTotals
				raidersDataState:set(newData)
			end
		end

		dataChanged:Fire()
	end
end

local function scheduleFlush(): ()
	if not isVisible and not isSideMode then
		return
	end
	if flushScheduled then
		return
	end

	flushScheduled = true
	if flushDelayThread then
		pcall(task.cancel, flushDelayThread)
	end
	flushDelayThread = task.delay(LeaderboardConstants.UI_UPDATE_INTERVAL, function()
		flushDelayThread = nil
		flushScheduled = false
		flushUIUpdate()
	end)
end

local function onStatChanged(userId: number, statType: string, newValue: number): ()
	-- applyStatDelta updates statsStore and sets the totals/structure dirty flags itself.
	LeaderboardCache.applyStatDelta(userId, statType, newValue, statsStore)
	scheduleFlush()
end

local function addPlayerToCache(targetPlayer: Player, stats: PlayerStats?, cardImageId: string?, isAnimatedCard: boolean?): ()
	local userId = targetPlayer.UserId

	if not targetPlayer:IsDescendantOf(Players) then
		return
	end

	local existingEntry = LeaderboardCache.getEntry(userId)
	if existingEntry then
		LeaderboardCache.removeFromFactionArray(userId)
	end

	local resolvedStats = stats or StatsConfig.createDefaultStats()
	local teamName = if targetPlayer.Team then targetPlayer.Team.Name else nil

	local entry: LeaderboardEntry = {
		UserId = userId,
		DisplayName = targetPlayer.DisplayName,
		Username = targetPlayer.Name,
		Team = teamName,
		Stats = resolvedStats,
		CardImageId = cardImageId,
		IsAnimatedCard = isAnimatedCard or false,
	}

	LeaderboardCache.setEntry(userId, entry)
	LeaderboardCache.addToFactionArray(entry)

	if statsStore then
		statsStore:updateAllStats(userId, resolvedStats)
		statsStore:updateCard(userId, cardImageId, isAnimatedCard)
	end

	LeaderboardCache.markTotalsDirty()
	LeaderboardCache.markDirty(true)
	scheduleFlush()
end

local function updatePlayerCard(userId: number, cardImageId: string?, isAnimatedCard: boolean?): ()
	local entry = LeaderboardCache.getEntry(userId)
	if not entry then
		return
	end

	entry.CardImageId = cardImageId
	entry.IsAnimatedCard = isAnimatedCard or false

	if statsStore then
		statsStore:updateCard(userId, cardImageId, isAnimatedCard)
	end
end

local function removePlayerFromCache(userId: number): ()
	local entry = LeaderboardCache.getEntry(userId)
	if not entry then
		LeaderboardCache.clearPendingDeltas(userId)
		return
	end

	LeaderboardCache.removeFromFactionArray(userId)
	LeaderboardCache.removeEntry(userId)
	LeaderboardCache.clearPendingDeltas(userId)

	if statsStore then
		statsStore:removePlayer(userId)
	end

	AnimatedCardService:ClearUserAnimation(userId)
	LeaderboardCache.markTotalsDirty()
	LeaderboardCache.markDirty(true)
	scheduleFlush()
end

local function handleStatsUpdate(data: any): ()
	if not data then
		return
	end

	if data.resetAll then
		for userId, entry in LeaderboardCache.getAllEntries() do
			local newEntry: LeaderboardEntry = {
				UserId = entry.UserId,
				DisplayName = entry.DisplayName,
				Username = entry.Username,
				Team = entry.Team,
				Stats = StatsConfig.createDefaultStats(),
				CardImageId = entry.CardImageId,
				IsAnimatedCard = entry.IsAnimatedCard,
			}
			LeaderboardCache.setEntry(userId, newEntry)

			if statsStore then
				statsStore:updateAllStats(userId, newEntry.Stats)
			end
		end
		LeaderboardCache.clearAllPendingDeltas()
		LeaderboardCache.rebuildFromCache(statsStore)
		if isVisible or isSideMode then
			flushUIUpdate()
		end
		return
	end

	local userId = data.userId
	if not userId then
		return
	end

	if data.playerLeft then
		removePlayerFromCache(userId)
		return
	end

	if data.playerJoined then
		local targetPlayer = Players:GetPlayerByUserId(userId)
		if targetPlayer then
			addPlayerToCache(targetPlayer, data.stats, data.cardImageId, data.isAnimatedCard)
			LeaderboardCache.consumePendingDeltas(userId, statsStore)
		end
		return
	end

	if data.cardChanged then
		updatePlayerCard(userId, data.cardImageId, data.isAnimatedCard)
		return
	end

	if data.reset then
		local entry = LeaderboardCache.getEntry(userId)
		if entry then
			local newEntry: LeaderboardEntry = {
				UserId = entry.UserId,
				DisplayName = entry.DisplayName,
				Username = entry.Username,
				Team = entry.Team,
				Stats = StatsConfig.createDefaultStats(),
				CardImageId = entry.CardImageId,
				IsAnimatedCard = entry.IsAnimatedCard,
			}
			LeaderboardCache.setEntry(userId, newEntry)
			LeaderboardCache.replaceEntryInFactionArray(entry, newEntry)

			if statsStore then
				statsStore:updateAllStats(userId, newEntry.Stats)
			end

			LeaderboardCache.markTotalsDirty()
			LeaderboardCache.markDirty(true)
			scheduleFlush()
		end
		return
	end
end

function LeaderboardService:init(): ()
	isInitialized = true
end

local setSideLeaderboardVisible: (visible: boolean) -> ()

function LeaderboardService:SetBlocked(blocked: boolean): ()
	isBlocked = blocked
	if blocked then
		if isVisible then
			self:Hide()
		end
		if isSideMode then
			setSideLeaderboardVisible(false)
		end
	end
end

function LeaderboardService:IsBlocked(): boolean
	return isBlocked
end

setSideLeaderboardVisible = function(visible: boolean): ()
	if visible then
		if sideSettleThread then
			task.cancel(sideSettleThread)
			sideSettleThread = nil
		end
		if sideLeaderboardUI then
			sideLeaderboardUI.Enabled = true
		end
		if sideVisibleState then
			sideVisibleState:set(true)
		end
	else
		if sideVisibleState then
			sideVisibleState:set(false)
		end
		if sideSettleThread then
			task.cancel(sideSettleThread)
		end
		sideSettleThread = task.delay(SIDE_SETTLE_TIME, function()
			sideSettleThread = nil
			if sideLeaderboardUI and sideVisibleState and not Fusion.peek(sideVisibleState) then
				sideLeaderboardUI.Enabled = false
			end
		end)
	end
end

local function getLeaderboardSizeSetting(): number
	local svc = ServiceLocator.Settings()
	if svc and typeof(svc.GetSetting) == "function" then
		local val = svc:GetSetting("LeaderboardSize")
		if val then
			return val
		end
	end
	return SettingsConfig.DefaultSettings.Settings.LeaderboardSize
end

local function getLeaderboardTypeSetting(): number
	if Maps.forcesSideLeaderboard() then
		return SettingsEnums.LeaderboardType.Side
	end

	local svc = ServiceLocator.Settings()
	if svc and typeof(svc.GetSetting) == "function" then
		local val = svc:GetSetting("LeaderboardType")
		if val then
			return val
		end
	end
	return SettingsConfig.DefaultSettings.Settings.LeaderboardType
end

local function rebuildLeaderboardUI(): ()
	if not fusionScope then
		return
	end

	if sideSettleThread then
		task.cancel(sideSettleThread)
		sideSettleThread = nil
	end

	if leaderboardUI then
		leaderboardUI:Destroy()
		leaderboardUI = nil
	end
	if sideLeaderboardUI then
		sideLeaderboardUI:Destroy()
		sideLeaderboardUI = nil
	end

	LeaderboardUIConstants.applySize(getLeaderboardSizeSetting())

	local playerGui = PlayerGuiHelper.waitForPlayerGui()

	if getLeaderboardTypeSetting() == SettingsEnums.LeaderboardType.Side then
		isSideMode = true
		isVisible = false
		if statsStore then
			LeaderboardCache.syncAllStatsToStore(statsStore)
		end
		sideLeaderboardUI = SideLeaderboardComponent(fusionScope, {
			DefendersData = defendersDataState,
			RaidersData = raidersDataState,
			DefendersTotals = defendersTotalsState,
			RaidersTotals = raidersTotalsState,
			LocalUserId = localPlayer.UserId,
			LocalUsername = localPlayer.Name,
			StatsStore = statsStore,
			Visible = sideVisibleState,
		})
		if playerGui and sideLeaderboardUI then
			sideLeaderboardUI.Parent = playerGui
		end
		LeaderboardCache.markDirty(true)
		flushUIUpdate()
	else
		isSideMode = false
		leaderboardUI = LeaderboardComponent(fusionScope, {
			Visible = visibleState,
			DefendersData = defendersDataState,
			RaidersData = raidersDataState,
			DefendersTotals = defendersTotalsState,
			RaidersTotals = raidersTotalsState,
			LocalUserId = localPlayer.UserId,
			StatsStore = statsStore,
		})
		if playerGui and leaderboardUI then
			leaderboardUI.Parent = playerGui
		end
	end
end

local function createDefaultFactionData(name: string, displayName: string, icon: string, faction: TeamFaction): FactionData
	return {
		name = name,
		displayName = displayName,
		icon = icon,
		entries = {},
		totals = StatsConfig.createDefaultStats(),
		playerCount = 0,
		teamLabels = getFactionTeamLabels(faction),
	}
end

local function loadInitialData(): ()
	local cardImageIds: { [number]: string? } = {}
	local animatedFlags: { [number]: boolean } = {}
	local serverStats: { [number]: PlayerStats } = {}

	local response = Network.Stats.getLeaderboard("Kills")
	if response and response.entries then
		for _, entry in response.entries do
			cardImageIds[entry.UserId] = entry.CardImageId
			animatedFlags[entry.UserId] = entry.IsAnimatedCard or false
			serverStats[entry.UserId] = {
				Kills = entry.Stats.Kills,
				Damage = entry.Stats.Damage,
				Heals = entry.Stats.Heals,
				Captures = entry.Stats.Captures,
			}
		end
	end

	for _, targetPlayer in Players:GetPlayers() do
		if not LeaderboardCache.getEntry(targetPlayer.UserId) then
			local userId = targetPlayer.UserId
			addPlayerToCache(targetPlayer, serverStats[userId], cardImageIds[userId], animatedFlags[userId])
			LeaderboardCache.consumePendingDeltas(userId, statsStore)
		end
	end

	LeaderboardCache.rebuildFromCache(statsStore)
end

function LeaderboardService:start(): ()
	if not isInitialized then
		self:init()
	end

	trove = Trove.new()

	disableDefaultLeaderboard()

	cachedKeybind = getKeybind()

	fusionScope = Fusion.scoped(Fusion)
	visibleState = fusionScope:Value(false)
	sideVisibleState = fusionScope:Value(false)
	defendersDataState = fusionScope:Value(createDefaultFactionData("Defenders", "IMPERIUM OF VULTAR", LeaderboardConstants.VULTAR_ICON, "Defenders"))
	raidersDataState = fusionScope:Value(createDefaultFactionData("Hostiles", "HOSTILES", LeaderboardConstants.HOSTILES_ICON, "Raiders"))
	defendersTotalsState = fusionScope:Value(StatsConfig.createDefaultStats())
	raidersTotalsState = fusionScope:Value(StatsConfig.createDefaultStats())
	statsStore = PlayerStatsStore.new(fusionScope)

	trove:Add(Network.Stats.onStatsUpdated(function(data)
		handleStatsUpdate(data)
	end))

	deltaBatchConnection = Network.Stats.onStatDeltaBatch(function(userId: number, statType: string, newValue: number)
		onStatChanged(userId, statType, newValue)
	end)

	task.spawn(loadInitialData)

	trove:Connect(UserInputService.InputBegan, function(input, gameProcessed)
		if input.KeyCode ~= cachedKeybind then
			return
		end

		if gameProcessed or isBlocked or isDeployMenuActive() then
			return
		end

		if isSideMode then
			if sideVisibleState then
				setSideLeaderboardVisible(not Fusion.peek(sideVisibleState))
			end
		else
			self:Toggle()
		end
	end)

	local function setupPlayerTeamListener(targetPlayer: Player)
		trove:Connect(targetPlayer:GetPropertyChangedSignal("Team"), function()
			local teamName = if targetPlayer.Team then targetPlayer.Team.Name else nil
			LeaderboardCache.updatePlayerTeam(targetPlayer.UserId, teamName, statsStore)
			scheduleFlush()
		end)
	end

	for _, targetPlayer in Players:GetPlayers() do
		setupPlayerTeamListener(targetPlayer)
	end

	trove:Connect(Players.PlayerAdded, function(targetPlayer: Player)
		setupPlayerTeamListener(targetPlayer)
		task.delay(0.5, function()
			if not targetPlayer:IsDescendantOf(Players) then
				return
			end
			if not LeaderboardCache.getEntry(targetPlayer.UserId) then
				local serverStats = Network.Stats.getPlayerStats(targetPlayer.UserId)
				addPlayerToCache(targetPlayer, serverStats, nil, false)
				LeaderboardCache.consumePendingDeltas(targetPlayer.UserId, statsStore)
			end
		end)
	end)

	trove:Connect(Players.PlayerRemoving, function(targetPlayer: Player)
		removePlayerFromCache(targetPlayer.UserId)
	end)

	task.spawn(function()
		local settingsSvc = ServiceLocator.Settings()
		if settingsSvc and settingsSvc.SettingChanged then
			trove:Add(settingsSvc.SettingChanged:Connect(function(key: string, _value: any)
				if key == "Keybinds" then
					cachedKeybind = getKeybind()
				elseif key == "LeaderboardSize" or key == "LeaderboardType" then
					rebuildLeaderboardUI()
					if isVisible or isSideMode then
						LeaderboardCache.markDirty(true)
						flushUIUpdate()
					end
				end
			end))
		end

		if getLeaderboardTypeSetting() == SettingsEnums.LeaderboardType.Side then
			isSideMode = true
			rebuildLeaderboardUI()
		end
	end)
end

function LeaderboardService:RefreshData(): ()
	loadInitialData()
end

function LeaderboardService:GetDefendersData(): FactionData
	local defenders = LeaderboardCache.getDefenders()
	local totals = LeaderboardCache.getDefenderTotals()

	local snapshot = table.create(#defenders)
	for i, entry in defenders do
		snapshot[i] = table.clone(entry)
		snapshot[i].Stats = table.clone(entry.Stats)
	end

	return {
		name = "Defenders",
		displayName = "IMPERIUM OF VULTAR",
		icon = LeaderboardConstants.VULTAR_ICON,
		entries = snapshot,
		totals = table.clone(totals),
		playerCount = #snapshot,
		teamLabels = getFactionTeamLabels("Defenders"),
	}
end

function LeaderboardService:GetRaidersData(): FactionData
	local raiders = LeaderboardCache.getRaiders()
	local totals = LeaderboardCache.getRaiderTotals()

	local snapshot = table.create(#raiders)
	for i, entry in raiders do
		snapshot[i] = table.clone(entry)
		snapshot[i].Stats = table.clone(entry.Stats)
	end

	return {
		name = "Hostiles",
		displayName = "HOSTILES",
		icon = LeaderboardConstants.HOSTILES_ICON,
		entries = snapshot,
		totals = table.clone(totals),
		playerCount = #snapshot,
		teamLabels = getFactionTeamLabels("Raiders"),
	}
end

function LeaderboardService:IsVisible(): boolean
	return isVisible
end

function LeaderboardService:Show(): ()
	if isVisible then
		return
	end

	if isBlocked then
		return
	end

	if not leaderboardUI then
		rebuildLeaderboardUI()
	end

	isVisible = true
	if visibleState then
		visibleState:set(true)
	end

	if statsStore then
		LeaderboardCache.syncAllStatsToStore(statsStore)
	end
	LeaderboardCache.markDirty(true)
	flushUIUpdate()

	visibilityChanged:Fire(true)
end

function LeaderboardService:Hide(): ()
	if not isVisible then
		return
	end

	isVisible = false
	if visibleState then
		visibleState:set(false)
	end

	visibilityChanged:Fire(false)
end

function LeaderboardService:Toggle(): ()
	if isVisible then
		self:Hide()
	else
		self:Show()
	end
end

function LeaderboardService:SetUI(ui: ScreenGui): ()
	leaderboardUI = ui
end

function LeaderboardService:GetUI(): ScreenGui?
	return leaderboardUI
end

function LeaderboardService:OnVisibilityChanged(callback: (visible: boolean) -> ()): () -> ()
	local connection = visibilityChanged:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

function LeaderboardService:OnDataChanged(callback: () -> ()): () -> ()
	local connection = dataChanged:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

function LeaderboardService:GetLocalUserId(): number
	return localPlayer.UserId
end

function LeaderboardService:Cleanup(): ()
	if flushDelayThread then
		pcall(task.cancel, flushDelayThread)
		flushDelayThread = nil
		flushScheduled = false
	end

	if sideSettleThread then
		task.cancel(sideSettleThread)
		sideSettleThread = nil
	end

	if deltaBatchConnection then
		deltaBatchConnection:Disconnect()
		deltaBatchConnection = nil
	end

	if trove then
		trove:Destroy()
		trove = nil
	end

	visibilityChanged:Destroy()
	dataChanged:Destroy()
	visibilityChanged = Signal.new()
	dataChanged = Signal.new()
	if sideLeaderboardUI then
		sideLeaderboardUI:Destroy()
		sideLeaderboardUI = nil
	end
	sideVisibleState = nil
	LeaderboardCache.clear()
	if statsStore then
		statsStore:clear()
		statsStore = nil
	end
	flushScheduled = false
	isVisible = false
	isSideMode = false
	isInitialized = false
	isBlocked = false
end

return LeaderboardService
