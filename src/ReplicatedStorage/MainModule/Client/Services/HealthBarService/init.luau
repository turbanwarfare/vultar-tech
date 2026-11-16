--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)
local Network = require(MainModule.Shared.Network)
local HealthBarHUD = require(MainModule.Client.Components.HealthBarHUD)

local HealthBarService = {}
HealthBarService.Name = "HealthBarService"

local LocalPlayer = Players.LocalPlayer

local playerGui: PlayerGui? = nil
local hasDeployed = false
local currentVisible = false

local characterConnection: RBXScriptConnection? = nil
local characterRemovingConnection: RBXScriptConnection? = nil
local healthConnection: RBXScriptConnection? = nil
local diedConnection: RBXScriptConnection? = nil
local deployConnection: { Disconnect: () -> () }? = nil

local function updateVisibility(): ()
	if not hasDeployed then
		HealthBarHUD.setVisible(false)
		currentVisible = false
		return
	end
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local isAlive = humanoid and humanoid.Health > 0
	local show = isAlive == true
	currentVisible = show
	HealthBarHUD.setVisible(show)
end

local function connectToHumanoid(humanoid: Humanoid): ()
	if healthConnection then
		healthConnection:Disconnect()
		healthConnection = nil
	end
	if diedConnection then
		diedConnection:Disconnect()
		diedConnection = nil
	end

	HealthBarHUD.setHealth(humanoid.Health, humanoid.MaxHealth)

	healthConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
		HealthBarHUD.setHealth(humanoid.Health, humanoid.MaxHealth)
		updateVisibility()
	end)

	diedConnection = humanoid.Died:Connect(function()
		currentVisible = false
		HealthBarHUD.setVisible(false)
	end)

	updateVisibility()
end

local function onCharacterAdded(character: Model): ()
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		connectToHumanoid(humanoid)
	end
end

local function onCharacterRemoving(_character: Model): ()
	if healthConnection then
		healthConnection:Disconnect()
		healthConnection = nil
	end
	if diedConnection then
		diedConnection:Disconnect()
		diedConnection = nil
	end
	currentVisible = false
	HealthBarHUD.setVisible(false)
end

local function onDeployComplete(): ()
	hasDeployed = true
	updateVisibility()
end

function HealthBarService:init(): ()
	playerGui = PlayerGuiHelper.waitForPlayerGui()
end

function HealthBarService:start(): ()
	HealthBarHUD.init(playerGui :: PlayerGui)

	deployConnection = Network.Deploy.onDeployComplete(onDeployComplete)
	characterConnection = LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
	characterRemovingConnection = LocalPlayer.CharacterRemoving:Connect(onCharacterRemoving)

	if LocalPlayer.Character then
		onCharacterAdded(LocalPlayer.Character)
	end
end

function HealthBarService:SetVisible(visible: boolean): ()
	currentVisible = visible
	HealthBarHUD.setVisible(visible)
end

function HealthBarService:IsVisible(): boolean
	return currentVisible
end

function HealthBarService:Cleanup(): ()
	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end
	if characterRemovingConnection then
		characterRemovingConnection:Disconnect()
		characterRemovingConnection = nil
	end
	if healthConnection then
		healthConnection:Disconnect()
		healthConnection = nil
	end
	if diedConnection then
		diedConnection:Disconnect()
		diedConnection = nil
	end
	if deployConnection then
		deployConnection:Disconnect()
		deployConnection = nil
	end

	HealthBarHUD.destroy()
	hasDeployed = false
	currentVisible = false
end

return HealthBarService
