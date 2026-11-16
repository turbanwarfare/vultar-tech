--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local MainModule = script.Parent.Parent.Parent
local AvatarService = require(MainModule.Server.Services.AvatarService)
local Network = require(MainModule.Shared.Network)
local LoadingCameras = require(MainModule.Shared.Config.LoadingCameras)
local UIBuilder = require(script.UIBuilder)

local LoadingScreenService = {}
LoadingScreenService.Name = "LoadingScreenService"

local PROGRESS_STEP_TIME = 0.3

local activeScreens: { [Player]: ScreenGui } = {}
local deployedPlayers: { [Player]: boolean } = {}
local progressThreads: { [Player]: thread } = {}
local pendingReady: { [Player]: boolean } = {}
local creditsPanelVisible: { [Player]: boolean } = {}
local cameraShots: { CFrame } = {}
local serviceConnections: { RBXScriptConnection } = {}

-- local function fetchPlaceNameAsync(): ()
-- 	task.spawn(function()
-- 		local success, info = pcall(function()
-- 			return MarketplaceService:GetProductInfoAsync(game.PlaceId)
-- 		end)
-- 		if success and info and info.Name then
-- 			placeName = info.Name
-- 		end
-- 	end)
-- end

-- local function getPlaceName(): string
-- 	return game.Name or "the game"
-- end

local function stopProgressSequence(player: Player): ()
	local thread = progressThreads[player]
	progressThreads[player] = nil
	if thread and coroutine.status(thread) == "suspended" then
		task.cancel(thread)
	end
end

local function startProgressSequence(player: Player): ()
	if not activeScreens[player] then
		if not deployedPlayers[player] then
			pendingReady[player] = true
		end
		return
	end

	pendingReady[player] = nil
	stopProgressSequence(player)
	progressThreads[player] = task.spawn(function()
		for i = 0, 100, 5 do
			if not activeScreens[player] then
				break
			end
			Network.Progress.sendProgress(player, i / 100)
			task.wait(PROGRESS_STEP_TIME)
		end

		task.wait(0.15)
		if activeScreens[player] then
			Network.Progress.sendProgress(player, "complete")
		end
	end)
end

local function showLoadingScreen(player: Player): ()
	local playerGui = player:WaitForChild("PlayerGui", 30)
	if not playerGui then
		return
	end

	if activeScreens[player] then
		return
	end

	local screen = UIBuilder.createLoadingScreen()
	for index, cframe in cameraShots do
		screen:SetAttribute(`Shot{index}`, cframe)
	end
	screen:SetAttribute("ShotCount", #cameraShots)
	screen.Parent = playerGui
	activeScreens[player] = screen

	if pendingReady[player] then
		startProgressSequence(player)
	end
end

local function hideLoadingScreen(player: Player): ()
	local screen = activeScreens[player]
	if screen then
		screen:Destroy()
		activeScreens[player] = nil
	end
end

local function respawnPlayer(player: Player): ()
	AvatarService:LoadCharacter(player)
end

local function setupNetworking(): ()
	Network.init()

	Network.Loading.onClientReady(function(player)
		startProgressSequence(player)
	end)

	Network.Deploy.onDeployRequested(function(player)
		if deployedPlayers[player] then
			return
		end
		deployedPlayers[player] = true
		task.wait(0.1)
		hideLoadingScreen(player)
		respawnPlayer(player)
		Network.Deploy.sendDeployComplete(player)
	end)

	Network.Credits.onCreditsRequested(function(player)
		local isVisible = creditsPanelVisible[player] or false
		creditsPanelVisible[player] = not isVisible
		Network.Credits.sendToggleCredits(player, not isVisible)
	end)
end

function LoadingScreenService:init(): ()
	cameraShots = LoadingCameras.getShots()
	setupNetworking()
end

function LoadingScreenService:start(): ()
	for _, player in Players:GetPlayers() do
		task.spawn(showLoadingScreen, player)
	end

	table.insert(
		serviceConnections,
		Players.PlayerAdded:Connect(function(player)
			task.spawn(showLoadingScreen, player)
		end)
	)

	table.insert(
		serviceConnections,
		Players.PlayerRemoving:Connect(function(player)
			activeScreens[player] = nil
			deployedPlayers[player] = nil
			stopProgressSequence(player)
			pendingReady[player] = nil
			creditsPanelVisible[player] = nil
		end)
	)
end

function LoadingScreenService:Cleanup(): ()
	for _, conn in serviceConnections do
		conn:Disconnect()
	end
	table.clear(serviceConnections)
	for _, screen in activeScreens do
		if screen then
			screen:Destroy()
		end
	end
	table.clear(activeScreens)
	for player in progressThreads do
		stopProgressSequence(player)
	end
	table.clear(pendingReady)
	table.clear(creditsPanelVisible)
end

function LoadingScreenService:ShowForPlayer(player: Player): ()
	showLoadingScreen(player)
end

function LoadingScreenService:HideForPlayer(player: Player): ()
	hideLoadingScreen(player)
end

return LoadingScreenService
