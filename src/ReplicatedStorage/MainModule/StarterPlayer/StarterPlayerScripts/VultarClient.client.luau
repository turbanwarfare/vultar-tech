--!strict
--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local MAINMODULE_TIMEOUT = 30
local READY_TIMEOUT = 60
local ERROR_MESSAGE = "Failed to load game systems. Please rejoin."

local function showErrorScreen(message: string)
	local player = Players.LocalPlayer
	if not player then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui", 10)
	if not playerGui then
		return
	end

	local loadingScreen = playerGui:FindFirstChild("VultarLoadingScreen")
	if loadingScreen then
		loadingScreen:Destroy()
	end

	local errorScreen = Instance.new("ScreenGui")
	errorScreen.Name = "VultarErrorScreen"
	errorScreen.AutoLocalize = false
	errorScreen.ResetOnSpawn = false
	errorScreen.IgnoreGuiInset = true
	errorScreen.DisplayOrder = 999

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	background.BorderSizePixel = 0
	background.Parent = errorScreen

	local errorLabel = Instance.new("TextLabel")
	errorLabel.Name = "ErrorLabel"
	errorLabel.Size = UDim2.new(0.8, 0, 0, 60)
	errorLabel.Position = UDim2.fromScale(0.5, 0.4)
	errorLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	errorLabel.BackgroundTransparency = 1
	errorLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	errorLabel.TextSize = 24
	errorLabel.Font = Enum.Font.GothamBold
	errorLabel.Text = message
	errorLabel.TextWrapped = true
	errorLabel.Parent = background

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "SubLabel"
	subLabel.Size = UDim2.new(0.8, 0, 0, 40)
	subLabel.Position = UDim2.fromScale(0.5, 0.5)
	subLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	subLabel.BackgroundTransparency = 1
	subLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	subLabel.TextSize = 16
	subLabel.Font = Enum.Font.Gotham
	subLabel.Text = "Press the button below to rejoin"
	subLabel.Parent = background

	local rejoinButton = Instance.new("TextButton")
	rejoinButton.Name = "RejoinButton"
	rejoinButton.Size = UDim2.fromOffset(200, 50)
	rejoinButton.Position = UDim2.fromScale(0.5, 0.6)
	rejoinButton.AnchorPoint = Vector2.new(0.5, 0.5)
	rejoinButton.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	rejoinButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	rejoinButton.TextSize = 18
	rejoinButton.Font = Enum.Font.GothamBold
	rejoinButton.Text = "REJOIN"
	rejoinButton.Parent = background

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = rejoinButton

	local _rejoinConn = rejoinButton.Activated:Connect(function()
		pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { player })
	end)

	errorScreen.Parent = playerGui
end

local MainModule = ReplicatedStorage:WaitForChild("MainModule", MAINMODULE_TIMEOUT)

if MainModule then
	task.spawn(function()
		local ok, clientMod = pcall(function()
			return MainModule:WaitForChild("Shared", 10)
				:WaitForChild("Network", 10)
				:WaitForChild("Generated", 10)
				:WaitForChild("Client", 10)
		end)
		if ok and clientMod then
			pcall(require, clientMod)
		end
	end)
end

if not MainModule then
	warn("[VultarClient] MainModule not found after timeout")
	showErrorScreen("Game failed to initialize. MainModule not found.")
	return
end

local loadError = MainModule:GetAttribute("LoadError")
if loadError then
	warn(`[VultarClient] Server reported load error: {loadError}`)
	showErrorScreen(`Server error: {loadError}`)
	return
end

local startTime = os.clock()
local ready = MainModule:GetAttribute("Ready")

while not ready do
	loadError = MainModule:GetAttribute("LoadError")
	if loadError then
		warn(`[VultarClient] Load error detected: {loadError}`)
		showErrorScreen(`Load error: {loadError}`)
		return
	end

	if os.clock() - startTime > READY_TIMEOUT then
		warn("[VultarClient] Timeout waiting for Ready attribute")
		showErrorScreen("Game initialization timed out. Server may be experiencing issues.")
		return
	end

	local waitStart = os.clock()
	while os.clock() - waitStart < 1 do
		if MainModule:GetAttribute("Ready") or MainModule:GetAttribute("LoadError") then
			break
		end
		task.wait(0.1)
	end

	ready = MainModule:GetAttribute("Ready")
end

loadError = MainModule:GetAttribute("LoadError")
if loadError then
	warn(`[VultarClient] Load error after Ready: {loadError}`)
	showErrorScreen(`Load error: {loadError}`)
	return
end

if ready == false then
	warn("[VultarClient] Ready attribute is false - load failed")
	showErrorScreen(ERROR_MESSAGE)
	return
end

if not MainModule:IsA("ModuleScript") then
	warn("[VultarClient] MainModule is not a ModuleScript")
	showErrorScreen("Invalid MainModule type")
	return
end

local success, err = pcall(function()
	local Vultar = require(MainModule)
	Vultar.Load()
	MainModule:SetAttribute("ClientReady", true)
end)

if not success then
	warn(`[VultarClient] Failed to load Vultar: {err}`)
	showErrorScreen(`Client load error: {err}`)
end
