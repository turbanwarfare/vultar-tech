--!strict
--!native
--!optimize 2

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5)) :: any
local scoped = Fusion.scoped

local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)
local CoreGuiManager = require(script.CoreGuiManager)
local LoadingScreen = require(script.Parent.Parent.Components.Loading.Screen)

type LoadingState = {
	IsActive: boolean,
	Progress: number,
	CurrentStep: string,
}

local LoadingService = {}
LoadingService.Name = "LoadingService"

local playerGui: PlayerGui? = nil
local scope: any = nil
local loadingScreen: ScreenGui? = nil
local blur: BlurEffect? = nil

local state: LoadingState = {
	IsActive = false,
	Progress = 0,
	CurrentStep = "Initializing",
}

local isInitialized: boolean = false
local blurSafetyThread: thread? = nil
local blurFadeThread: thread? = nil
local loadedBindable: BindableEvent = Instance.new("BindableEvent")

local BLUR_NAME = "LoadingServiceBlur"
local BLUR_FADE_TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function forceCleanupBlur(): ()
	local existingBlur = Lighting:FindFirstChild(BLUR_NAME)
	if existingBlur and existingBlur:IsA("BlurEffect") then
		existingBlur:Destroy()
	end
	blur = nil
end

local function createBlur(): ()
	forceCleanupBlur()

	local newBlur = Instance.new("BlurEffect")
	newBlur.Name = BLUR_NAME
	newBlur.Size = 12
	newBlur.Enabled = true
	newBlur.Parent = Lighting
	blur = newBlur

	if blurSafetyThread then
		task.cancel(blurSafetyThread)
	end
	blurSafetyThread = task.delay(30, function()
		blurSafetyThread = nil
		if newBlur and newBlur.Parent then
			newBlur:Destroy()
		end
		if blur == newBlur then
			blur = nil
		end
	end)
end

local function removeBlur(): ()
	local currentBlur = blur
	blur = nil

	if not currentBlur then
		forceCleanupBlur()
		return
	end

	local destroyed = false
	local function safeDestroy()
		if destroyed then
			return
		end
		destroyed = true
		if currentBlur and currentBlur.Parent then
			currentBlur:Destroy()
		end
		forceCleanupBlur()
	end

	local tween = TweenService:Create(currentBlur, BLUR_FADE_TWEEN_INFO, { Size = 0 })
	tween.Completed:Once(safeDestroy)
	tween:Play()

	if blurFadeThread then
		task.cancel(blurFadeThread)
	end
	blurFadeThread = task.delay(1, function()
		blurFadeThread = nil
		safeDestroy()
	end)
end

function LoadingService:init(): ()
	playerGui = PlayerGuiHelper.waitForPlayerGui()
	if not playerGui then
		return
	end
	isInitialized = true
end

function LoadingService:start(): ()
end

function LoadingService:Show(): ()
	if not isInitialized then
		self:init()
	end

	if not playerGui then
		return
	end

	state.IsActive = true
	state.Progress = 0
	state.CurrentStep = "Initializing"

	CoreGuiManager.disableCoreGui()
	CoreGuiManager.disableOtherScreenGuis(playerGui, "VultarLoadingScreen")
	createBlur()

	scope = scoped(Fusion)
	loadingScreen = LoadingScreen(scope :: any, {
		OnDeploy = function()
			self:Hide()
		end,
		OnCredits = function()
		end,
	})
	loadingScreen.Parent = playerGui
end

function LoadingService:SetProgress(progress: number, stepName: string?): ()
	state.Progress = math.clamp(progress, 0, 1)

	if stepName then
		state.CurrentStep = stepName
	end
end

function LoadingService:Hide(): ()
	if not loadingScreen then
		return
	end

	loadingScreen = nil

	state.IsActive = false
	removeBlur()
	CoreGuiManager.restoreCoreGui()
	CoreGuiManager.restoreOtherScreenGuis()

	if scope then
		Fusion.doCleanup(scope)
		scope = nil
	end

	loadedBindable:Fire()
end

function LoadingService:WaitForComplete(): ()
	if not state.IsActive then
		return
	end
	loadedBindable.Event:Wait()
end

function LoadingService:IsActive(): boolean
	return state.IsActive
end

function LoadingService:GetProgress(): number
	return state.Progress
end

function LoadingService:Cleanup(): ()
	self:Hide()

	if blurSafetyThread then
		task.cancel(blurSafetyThread)
		blurSafetyThread = nil
	end

	if blurFadeThread then
		task.cancel(blurFadeThread)
		blurFadeThread = nil
	end

	if loadedBindable then
		loadedBindable:Destroy()
	end

	playerGui = nil
	isInitialized = false
end

return LoadingService
