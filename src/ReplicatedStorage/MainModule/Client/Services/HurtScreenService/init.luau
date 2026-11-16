--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)

local HurtScreenService = {}
HurtScreenService.Name = "HurtScreenService"

local localPlayer = Players.LocalPlayer

local isEnabled = true
local deployConnection: RBXScriptConnection? = nil
local settingsConnection: RBXScriptConnection? = nil
local healthConnection: RBXScriptConnection? = nil
local characterConnection: RBXScriptConnection? = nil
local humanoidAddedConnection: RBXScriptConnection? = nil

local hurtScreenGui: ScreenGui? = nil
local flashElements: { Frame } = {}

local previousHealth: number = 100
local activeFlashCount = 0
local flashFadeThread: thread? = nil
local humanoidWaitThread: thread? = nil

local DEFAULT_BORDER_SIZE = 35
local DEFAULT_FLASH_TRANSPARENCY = 0.65
local HURT_COLOR = Color3.fromRGB(160, 20, 20)
local FLASH_DURATION = 0.05
local FADE_DURATION = 0.1

local SCREEN_TYPE_SCREEN = 1

local borderSize = DEFAULT_BORDER_SIZE
local flashTransparency = DEFAULT_FLASH_TRANSPARENCY
local screenType = SCREEN_TYPE_SCREEN

local TWEEN_FLASH = TweenInfo.new(FLASH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_FADE = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local SCREEN_GRADIENT_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.15, 0.4),
	NumberSequenceKeypoint.new(0.4, 0.95),
	NumberSequenceKeypoint.new(0.5, 1),
	NumberSequenceKeypoint.new(0.6, 0.95),
	NumberSequenceKeypoint.new(0.85, 0.4),
	NumberSequenceKeypoint.new(1, 0),
})

local BORDER_FADE_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.7, 0.5),
	NumberSequenceKeypoint.new(1, 1),
})

local function executeFlashFade(flashId: number): ()
	flashFadeThread = nil
	if activeFlashCount ~= flashId then
		return
	end
	for _, element in flashElements do
		local fadeTween = TweenService:Create(element, TWEEN_FADE, {
			BackgroundTransparency = 1,
		})
		fadeTween:Play()
	end
end

local function createScreenOverlay(): Frame
	local overlay = Instance.new("Frame")
	overlay.Name = "ScreenOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Position = UDim2.fromScale(0, 0)
	overlay.BackgroundColor3 = HURT_COLOR
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 0
	gradient.Transparency = SCREEN_GRADIENT_TRANSPARENCY
	gradient.Parent = overlay

	return overlay
end

local function createBorder(name: string, size: UDim2, position: UDim2, gradientRotation: number): Frame
	local border = Instance.new("Frame")
	border.Name = name
	border.Size = size
	border.Position = position
	border.BackgroundColor3 = HURT_COLOR
	border.BackgroundTransparency = 1
	border.BorderSizePixel = 0

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = gradientRotation
	gradient.Transparency = BORDER_FADE_TRANSPARENCY
	gradient.Parent = border

	return border
end

local function createHurtScreenGui(): ()
	if hurtScreenGui and hurtScreenGui.Parent then
		return
	end

	if hurtScreenGui then
		hurtScreenGui:Destroy()
		hurtScreenGui = nil
		table.clear(flashElements)
	end

	local playerGui = localPlayer:WaitForChild("PlayerGui", 5)
	if not playerGui then
		return
	end

	hurtScreenGui = Instance.new("ScreenGui")
	hurtScreenGui.Name = "HurtScreen"
	assert(hurtScreenGui).AutoLocalize = false
	hurtScreenGui.ResetOnSpawn = false
	hurtScreenGui.IgnoreGuiInset = true
	hurtScreenGui.DisplayOrder = 100
	hurtScreenGui.Parent = playerGui

	if screenType == SCREEN_TYPE_SCREEN then
		local overlay = createScreenOverlay()
		overlay.Parent = hurtScreenGui
		table.insert(flashElements, overlay)
		return
	end

	local topBorder = createBorder(
		"TopBorder",
		UDim2.new(1, 0, 0, borderSize),
		UDim2.fromScale(0, 0),
		90
	)
	topBorder.Parent = hurtScreenGui
	table.insert(flashElements, topBorder)

	local bottomBorder = createBorder(
		"BottomBorder",
		UDim2.new(1, 0, 0, borderSize),
		UDim2.new(0, 0, 1, -borderSize),
		-90
	)
	bottomBorder.Parent = hurtScreenGui
	table.insert(flashElements, bottomBorder)

	local leftBorder = createBorder(
		"LeftBorder",
		UDim2.new(0, borderSize, 1, 0),
		UDim2.fromScale(0, 0),
		0
	)
	leftBorder.Parent = hurtScreenGui
	table.insert(flashElements, leftBorder)

	local rightBorder = createBorder(
		"RightBorder",
		UDim2.new(0, borderSize, 1, 0),
		UDim2.new(1, -borderSize, 0, 0),
		180
	)
	rightBorder.Parent = hurtScreenGui
	table.insert(flashElements, rightBorder)
end

local function flashHurtScreen(): ()
	if not isEnabled then
		return
	end

	if #flashElements == 0 then
		createHurtScreenGui()
		if #flashElements == 0 then
			return
		end
	end

	activeFlashCount = activeFlashCount + 1
	local flashId = activeFlashCount

	for _, element in flashElements do
		local flashTween = TweenService:Create(element, TWEEN_FLASH, {
			BackgroundTransparency = flashTransparency,
		})
		flashTween:Play()
	end

	if flashFadeThread then
		task.cancel(flashFadeThread)
	end
	flashFadeThread = task.delay(FLASH_DURATION, executeFlashFade, flashId)
end

local function onHealthChanged(newHealth: number): ()
	if newHealth < previousHealth then
		flashHurtScreen()
	end
	previousHealth = newHealth
end

local function connectToHumanoid(humanoid: Humanoid): ()
	if healthConnection then
		healthConnection:Disconnect()
		healthConnection = nil
	end

	previousHealth = humanoid.MaxHealth
	healthConnection = humanoid.HealthChanged:Connect(onHealthChanged)
end

local function setupHealthListener(character: Model?): ()
	if healthConnection then
		healthConnection:Disconnect()
		healthConnection = nil
	end

	if humanoidAddedConnection then
		humanoidAddedConnection:Disconnect()
		humanoidAddedConnection = nil
	end

	if not character then
		return
	end

	if humanoidWaitThread then
		task.cancel(humanoidWaitThread)
	end
	humanoidWaitThread = task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		humanoidWaitThread = nil
		if humanoid then
			connectToHumanoid(humanoid)
		end
	end)
end

local function rebuildHurtScreenGui(): ()
	if hurtScreenGui then
		hurtScreenGui:Destroy()
		hurtScreenGui = nil
		table.clear(flashElements)
	end
	createHurtScreenGui()
end

local function updateSettingState(): ()
	local settingsService = ServiceLocator.Settings()
	if not settingsService then
		return
	end

	local hurtScreenSetting = settingsService:GetSetting("HurtScreen")
	isEnabled = hurtScreenSetting ~= false

	local typeSetting = settingsService:GetSetting("HurtScreenType")
	if type(typeSetting) == "number" then
		screenType = typeSetting
	end

	local sizeSetting = settingsService:GetSetting("HurtScreenSize")
	if type(sizeSetting) == "number" then
		borderSize = math.clamp(sizeSetting, 10, 70)
	end

	local transparencySetting = settingsService:GetSetting("HurtScreenTransparency")
	if type(transparencySetting) == "number" then
		flashTransparency = math.clamp(transparencySetting, 0, 1)
	end
end

local function disableCoreHealthGui(): ()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
end

local function onDeployComplete(): ()
	disableCoreHealthGui()
	createHurtScreenGui()
	setupHealthListener(localPlayer.Character)
end

function HurtScreenService:init(): ()
end

function HurtScreenService:start(): ()
	updateSettingState()
	disableCoreHealthGui()
	createHurtScreenGui()

	local settingsService = ServiceLocator.Settings()
	if settingsService and settingsService.SettingChanged then
		settingsConnection = settingsService.SettingChanged:Connect(function(key: string, value: any)
			if key == "HurtScreen" then
				isEnabled = value == true
			elseif key == "HurtScreenType" and type(value) == "number" then
				screenType = value
				rebuildHurtScreenGui()
			elseif key == "HurtScreenSize" and type(value) == "number" then
				borderSize = math.clamp(value, 10, 70)
				rebuildHurtScreenGui()
			elseif key == "HurtScreenTransparency" and type(value) == "number" then
				flashTransparency = math.clamp(value, 0, 1)
			end
		end)
	end

	characterConnection = localPlayer.CharacterAdded:Connect(function(character)
		setupHealthListener(character)
	end)

	if localPlayer.Character then
		setupHealthListener(localPlayer.Character)
	end

	deployConnection = Network.Deploy.onDeployComplete(onDeployComplete)
end

function HurtScreenService:SetEnabled(enabled: boolean): ()
	isEnabled = enabled
end

function HurtScreenService:IsEnabled(): boolean
	return isEnabled
end

function HurtScreenService:Flash(): ()
	flashHurtScreen()
end

function HurtScreenService:Cleanup(): ()
	if deployConnection then
		deployConnection:Disconnect()
		deployConnection = nil
	end

	if settingsConnection then
		settingsConnection:Disconnect()
		settingsConnection = nil
	end

	if healthConnection then
		healthConnection:Disconnect()
		healthConnection = nil
	end

	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end

	if humanoidAddedConnection then
		humanoidAddedConnection:Disconnect()
		humanoidAddedConnection = nil
	end

	if flashFadeThread then
		task.cancel(flashFadeThread)
		flashFadeThread = nil
	end

	if humanoidWaitThread then
		task.cancel(humanoidWaitThread)
		humanoidWaitThread = nil
	end

	if hurtScreenGui then
		hurtScreenGui:Destroy()
		hurtScreenGui = nil
	end

	table.clear(flashElements)
	isEnabled = true
	previousHealth = 100
	activeFlashCount = 0
	borderSize = DEFAULT_BORDER_SIZE
	flashTransparency = DEFAULT_FLASH_TRANSPARENCY
	screenType = SCREEN_TYPE_SCREEN

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, true)
	end)
end

return HurtScreenService
