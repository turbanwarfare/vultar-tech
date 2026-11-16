--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Trove = require(Packages:WaitForChild("Trove", 5))
local FactionUtils = require(MainModule.Shared.Utils.Game.FactionUtils)
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
local Theme = require(MainModule.Shared.UI.Theme)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

local TeamESPService = {}
TeamESPService.Name = "TeamESPService"

local LocalPlayer = Players.LocalPlayer

local activeHighlights: { [Model]: Highlight } = {}
local playerToCharacter: { [Player]: Model } = {}
local characterToPlayer: { [Model]: Player } = {}
local SettingsService: any = nil

local trove: typeof(Trove.new()) = nil
local settingsConnection: RBXScriptConnection? = nil
local reevalThreads: { [Player]: { thread } } = {}
local playerTroves: { [Player]: typeof(Trove.new()) } = {}

local cachedEnabled: boolean = false
local cachedFillEnabled: boolean = true
local cachedColorIndex: number = 4
local cachedTransparency: number = 0.5

local function syncSettingsCache(): ()
	local svc = SettingsService
	local settings: SettingsConfig.SettingsTemplate = SettingsConfig.DefaultSettings

	if svc and svc.GetSettings then
		local currentSettings = svc:GetSettings()
		if currentSettings then
			settings = currentSettings
		end
	end

	cachedEnabled = settings.Settings.TeamESP == true
	cachedFillEnabled = settings.Settings.TeamESP_Highlight == true

	local colorIdx = settings.Settings.TeamESP_HighlightColor
	if typeof(colorIdx) == "number" and colorIdx >= 1 and colorIdx <= #Theme.HighlightColors then
		cachedColorIndex = colorIdx
	else
		cachedColorIndex = 4
	end

	local trans = settings.Settings.TeamESP_HighlightTransparency
	if typeof(trans) == "number" then
		cachedTransparency = math.clamp(trans, 0, 1)
	else
		cachedTransparency = 0.5
	end
end

local function getHighlightColor(): Color3
	return Theme.HighlightColors[cachedColorIndex] or Theme.HighlightColors[4]
end

local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)

local function isTeammate(targetPlayer: Player): boolean
	if targetPlayer == LocalPlayer then
		return false
	end

	if FactionUtils.isSpectator(targetPlayer) then
		return false
	end

	local sw = ServiceLocator.ScreenWatch()
	if sw and typeof(sw.IsWatching) == "function" and sw:IsWatching() then
		return false
	end

	if FactionUtils.isSpectator(LocalPlayer) then
		return true
	end

	return FactionUtils.areSameFaction(LocalPlayer, targetPlayer)
end

local function destroyHighlight(character: Model): ()
	local highlight = activeHighlights[character]
	if highlight then
		activeHighlights[character] = nil
		if highlight.Parent then
			highlight:Destroy()
		end
	end
end

local function destroyAllHighlights(): ()
	for character in activeHighlights do
		destroyHighlight(character)
	end
	table.clear(activeHighlights)
end

local function createHighlight(character: Model): Highlight?
	destroyHighlight(character)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	local color = getHighlightColor()

	local highlight = Instance.new("Highlight")
	highlight.Name = "TeamESPHighlight"
	highlight.Adornee = character
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = if cachedFillEnabled then cachedTransparency else 1
	highlight.OutlineTransparency = cachedTransparency
	highlight.Parent = character

	activeHighlights[character] = highlight

	return highlight
end

local function updateHighlightAppearance(highlight: Highlight): ()
	local color = getHighlightColor()
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = if cachedFillEnabled then cachedTransparency else 1
	highlight.OutlineTransparency = cachedTransparency
end

local function updateAllHighlightAppearances(): ()
	for character, highlight in activeHighlights do
		if highlight and highlight.Parent then
			updateHighlightAppearance(highlight)
		else
			activeHighlights[character] = nil
		end
	end
end

local function evaluatePlayer(player: Player): ()
	local character = player.Character
	if not character then
		return
	end

	local shouldTrack = cachedEnabled and cachedFillEnabled and isTeammate(player)

	if shouldTrack then
		if not activeHighlights[character] then
			createHighlight(character)
		end
	else
		destroyHighlight(character)
	end
end

local function evaluateAllPlayers(): ()
	for character in activeHighlights do
		local player = characterToPlayer[character]
		if not player or not cachedEnabled or not cachedFillEnabled or not isTeammate(player) then
			destroyHighlight(character)
		end
	end

	if cachedEnabled and cachedFillEnabled then
		for player in playerToCharacter do
			evaluatePlayer(player)
		end
	end
end

local function onCharacterAdded(player: Player, character: Model): ()
	playerToCharacter[player] = character
	characterToPlayer[character] = player

	task.defer(function()
		if character.Parent and player.Parent then
			evaluatePlayer(player)
		end
	end)

	local threads = reevalThreads[player]
	if threads then
		for _, t in threads do
			task.cancel(t)
		end
	end
	threads = {}
	reevalThreads[player] = threads

	threads[1] = task.delay(0.5, function()
		if character.Parent and player.Parent and playerToCharacter[player] == character then
			evaluatePlayer(player)
		end
	end)

	threads[2] = task.delay(1.5, function()
		reevalThreads[player] = nil
		if character.Parent and player.Parent and playerToCharacter[player] == character then
			evaluatePlayer(player)
		end
	end)
end

local function onCharacterRemoving(player: Player, character: Model): ()
	characterToPlayer[character] = nil
	destroyHighlight(character)
	if playerToCharacter[player] == character then
		playerToCharacter[player] = nil
	end
end

local function onPlayerTeamChanged(player: Player): ()
	evaluatePlayer(player)
end

local function onLocalPlayerTeamChanged(): ()
	evaluateAllPlayers()
end

local function onPlayerAdded(player: Player): ()
	if player == LocalPlayer then
		return
	end

	local playerTrove = Trove.new()
	playerTroves[player] = playerTrove

	playerTrove:Connect(player.CharacterAdded, function(character: Model)
		onCharacterAdded(player, character)
	end)

	playerTrove:Connect(player.CharacterRemoving, function(character: Model)
		onCharacterRemoving(player, character)
	end)

	playerTrove:Connect(player:GetPropertyChangedSignal("Team"), function()
		onPlayerTeamChanged(player)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

local function onPlayerRemoving(player: Player): ()
	if playerTroves[player] then
		playerTroves[player]:Destroy()
		playerTroves[player] = nil
	end

	local character = playerToCharacter[player]
	if character then
		characterToPlayer[character] = nil
		destroyHighlight(character)
	end
	playerToCharacter[player] = nil
end

local function onSettingChanged(key: string, value: any): ()
	if key == "TeamESP" then
		cachedEnabled = value == true
		evaluateAllPlayers()
	elseif key == "TeamESP_Highlight" then
		cachedFillEnabled = value == true
		evaluateAllPlayers()
	elseif key == "TeamESP_HighlightColor" then
		if typeof(value) == "number" and value >= 1 and value <= #Theme.HighlightColors then
			cachedColorIndex = value
		end
		updateAllHighlightAppearances()
	elseif key == "TeamESP_HighlightTransparency" then
		if typeof(value) == "number" then
			cachedTransparency = math.clamp(value, 0, 1)
		end
		updateAllHighlightAppearances()
	end
end

function TeamESPService:init(): ()
end

function TeamESPService:start(): ()
	SettingsService = LazyService.create(MainModule, "SettingsService")()

	trove = Trove.new()

	syncSettingsCache()

	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer then
			onPlayerAdded(player)
		end
	end

	trove:Connect(Players.PlayerAdded, onPlayerAdded)
	trove:Connect(Players.PlayerRemoving, onPlayerRemoving)
	trove:Connect(LocalPlayer:GetPropertyChangedSignal("Team"), onLocalPlayerTeamChanged)

	if SettingsService and SettingsService.SettingChanged then
		settingsConnection = SettingsService.SettingChanged:Connect(onSettingChanged)
	end

	evaluateAllPlayers()
end

function TeamESPService:RefreshAll(): ()
	evaluateAllPlayers()
end

function TeamESPService:Cleanup(): ()
	for player, threads in reevalThreads do
		for _, t in threads do
			task.cancel(t)
		end
		reevalThreads[player] = nil
	end

	if settingsConnection then
		settingsConnection:Disconnect()
		settingsConnection = nil
	end

	if trove then
		trove:Destroy()
		trove = nil
	end

	destroyAllHighlights()
	table.clear(playerToCharacter)
	table.clear(characterToPlayer)
end

return TeamESPService
