--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
local Constants = require(script.Parent.Parent.Constants)
local Cache = require(script.Parent.Parent.Cache)

local FeedbackKillIndicator = {}

local player = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera

local killIndicatorGui: ScreenGui? = nil
local indicatorImage: ImageLabel? = nil
local circleFrame: Frame? = nil
local circleStroke: UIStroke? = nil

local activeThread: thread? = nil
local sizeTween: Tween? = nil
local fadeTween: Tween? = nil
local strokeFadeTween: Tween? = nil
local trackingConnection: RBXScriptConnection? = nil

local trackedRootPart: BasePart? = nil
local trackingMode: number = 0
local isTracking: boolean = false
local lastTrackX: number = 0
local lastTrackY: number = 0

local KILL_INDICATOR = Constants.KillIndicator
local KILL_COLORS = Constants.KillIndicatorColors

local EXPAND_DURATION = 0.3
local FADE_DURATION = 0.3
local TOTAL_LIFETIME = 1.5

local TWEEN_EXPAND = TweenInfo.new(EXPAND_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_FADE = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

local TYPE_CIRCLE = 1
local TYPE_HITMARKER = 2
local TYPE_SKULL = 3

local POSITION_PLAYER = 1
local _POSITION_CURSOR = 2
local POSITION_STATIC = 3

local DEFAULT_SIZE = 65

local cachedHitmarkerAsset: { id: string, size: UDim2 }? = nil
local cachedHitPreset: number? = nil

local function getHitmarkerAsset(): { id: string, size: UDim2 }
	local hitPreset = Cache.getHitPreset()
	if cachedHitPreset == hitPreset and cachedHitmarkerAsset then
		return cachedHitmarkerAsset
	end
	cachedHitPreset = hitPreset
	local asset = SettingsConfig.HitmarkerAssets[hitPreset]
	if asset then
		cachedHitmarkerAsset = asset
		return asset
	end
	cachedHitmarkerAsset = { id = KILL_INDICATOR.CircleImage, size = UDim2.fromScale(1, 1) }
	return cachedHitmarkerAsset
end

local function updateTracking()
	if not isTracking then
		return
	end
	debug.profilebegin("GunService::killIndicator")

	local px: number
	local py: number

	if trackingMode == POSITION_PLAYER and trackedRootPart and trackedRootPart.Parent then
		local currentCamera = CurrentCamera
		if currentCamera then
			local screenPos, onScreen = currentCamera:WorldToViewportPoint(trackedRootPart.Position)
			if onScreen then
				px = screenPos.X
				py = screenPos.Y
			end
		end
	end

	if not px then
		local mousePos = UserInputService:GetMouseLocation()
		px = mousePos.X
		py = mousePos.Y
	end

	local rx = math.round(px :: number)
	local ry = math.round(py :: number)

	if rx == lastTrackX and ry == lastTrackY then
		debug.profileend()
		return
	end
	lastTrackX = rx
	lastTrackY = ry

	local position = UDim2.fromOffset(rx, ry)
	if indicatorImage and indicatorImage.Visible then
		indicatorImage.Position = position
	end
	if circleFrame and circleFrame.Visible then
		circleFrame.Position = position
	end
	debug.profileend()
end

local function startTracking()
	if trackingConnection then
		return
	end
	isTracking = true
	trackingConnection = RunService.RenderStepped:Connect(updateTracking)
end

local function stopTracking()
	isTracking = false
	trackedRootPart = nil
	trackingMode = 0
	lastTrackX = 0
	lastTrackY = 0
	if trackingConnection then
		trackingConnection:Disconnect()
		trackingConnection = nil
	end
end

local function executeCircleIndicatorExpiry(): ()
	if circleFrame then
		circleFrame.Visible = false
		circleFrame.Size = UDim2.fromOffset(0, 0)
	end
	if circleStroke then
		circleStroke.Transparency = 0
	end
	stopTracking()
	activeThread = nil
end

local function executeImageIndicatorExpiry(): ()
	if indicatorImage then
		indicatorImage.Visible = false
		indicatorImage.Size = UDim2.fromOffset(0, 0)
		indicatorImage.ImageTransparency = 0
	end
	stopTracking()
	activeThread = nil
end

local function cancelActiveTweens()
	if sizeTween then
		sizeTween:Cancel()
		sizeTween = nil
	end
	if fadeTween then
		fadeTween:Cancel()
		fadeTween = nil
	end
	if strokeFadeTween then
		strokeFadeTween:Cancel()
		strokeFadeTween = nil
	end
	if activeThread then
		task.cancel(activeThread)
		activeThread = nil
	end
end

function FeedbackKillIndicator.createUI(): ()
	local playerGui = player:WaitForChild("PlayerGui", 5)
	if not playerGui then
		return
	end

	killIndicatorGui = Instance.new("ScreenGui")
	killIndicatorGui.Name = "KillIndicatorGui"
	assert(killIndicatorGui).AutoLocalize = false
	killIndicatorGui.IgnoreGuiInset = true
	killIndicatorGui.ResetOnSpawn = false
	killIndicatorGui.DisplayOrder = 99

	indicatorImage = Instance.new("ImageLabel")
	indicatorImage.Name = "KillIndicator"
	indicatorImage.Size = UDim2.fromOffset(0, 0)
	indicatorImage.AnchorPoint = Vector2.new(0.5, 0.5)
	indicatorImage.BackgroundTransparency = 1
	indicatorImage.ImageTransparency = 0
	indicatorImage.Visible = false
	indicatorImage.ZIndex = 9
	indicatorImage.Parent = killIndicatorGui

	circleFrame = Instance.new("Frame")
	circleFrame.Name = "KillCircle"
	circleFrame.Size = UDim2.fromOffset(0, 0)
	circleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	circleFrame.BackgroundTransparency = 1
	circleFrame.Visible = false
	circleFrame.ZIndex = 9
	circleFrame.Parent = killIndicatorGui

	local circleCorner = Instance.new("UICorner")
	circleCorner.CornerRadius = UDim.new(0.5, 0)

	circleStroke = Instance.new("UIStroke")
	circleStroke.Name = "CircleStroke"
	circleStroke.Thickness = 4
	circleStroke.Color = Color3.new(1, 1, 1)
	circleStroke.Transparency = 0

	circleCorner.Parent = circleFrame
	circleStroke.Parent = circleFrame
	killIndicatorGui.Parent = playerGui
end

local function getIndicatorImage(indicatorType: number): (string, UDim2)
	if indicatorType == TYPE_SKULL then
		return KILL_INDICATOR.SkullImage, UDim2.fromScale(1, 1)
	elseif indicatorType == TYPE_HITMARKER then
		local asset = getHitmarkerAsset()
		return asset.id, asset.size
	else
		return KILL_INDICATOR.CircleImage, UDim2.fromScale(1, 1)
	end
end

local function getInitialPosition(positionType: number, victimRootPart: BasePart?): UDim2
	if positionType == POSITION_PLAYER and victimRootPart then
		local camera = CurrentCamera
		if camera then
			local screenPos, onScreen = camera:WorldToViewportPoint(victimRootPart.Position)
			if onScreen then
				return UDim2.fromOffset(screenPos.X, screenPos.Y)
			end
		end
	end

	local mousePos = UserInputService:GetMouseLocation()
	return UDim2.fromOffset(mousePos.X, mousePos.Y)
end

function FeedbackKillIndicator.show(victimRootPart: BasePart?): ()
	if not Cache.getKillIndicatorsEnabled() then
		return
	end

	if not indicatorImage then
		return
	end

	cancelActiveTweens()
	stopTracking()

	local indicatorType = Cache.getKillIndicatorType()
	local colorIndex = Cache.getKillIndicatorColor()
	local size = Cache.getKillIndicatorSize()
	local positionType = Cache.getKillIndicatorPosition()

	local color = KILL_COLORS[colorIndex] or KILL_COLORS[1]
	local position = getInitialPosition(positionType, victimRootPart)
	local useCircleFrame = indicatorType == TYPE_CIRCLE

	local targetSize = size
	if targetSize <= 0 then
		targetSize = DEFAULT_SIZE
	end

	trackingMode = positionType
	trackedRootPart = victimRootPart
	if positionType ~= POSITION_STATIC then
		startTracking()
	end

	if useCircleFrame and circleFrame and circleStroke then
		indicatorImage.Visible = false

		circleStroke.Color = color
		circleStroke.Transparency = 0
		circleFrame.Position = position
		circleFrame.Size = UDim2.fromOffset(0, 0)
		circleFrame.Visible = true

		local finalSize = UDim2.fromOffset(targetSize, targetSize)

		sizeTween = TweenService:Create(circleFrame, TWEEN_EXPAND, {
			Size = finalSize,
		})

		strokeFadeTween = TweenService:Create(circleStroke, TWEEN_FADE, {
			Transparency = 1,
		})

		sizeTween:Play()
		strokeFadeTween:Play()

		activeThread = task.delay(TOTAL_LIFETIME, executeCircleIndicatorExpiry)
	else
		if circleFrame then
			circleFrame.Visible = false
		end

		local image, imageScale = getIndicatorImage(indicatorType)
		local scaledWidth = targetSize * imageScale.X.Scale + imageScale.X.Offset
		local scaledHeight = targetSize * imageScale.Y.Scale + imageScale.Y.Offset

		indicatorImage.Image = image
		indicatorImage.ImageColor3 = color
		indicatorImage.Position = position
		indicatorImage.Size = UDim2.fromOffset(0, 0)
		indicatorImage.ImageTransparency = 0
		indicatorImage.Visible = true

		local finalSize = UDim2.fromOffset(scaledWidth, scaledHeight)

		sizeTween = TweenService:Create(indicatorImage, TWEEN_EXPAND, {
			Size = finalSize,
		})

		fadeTween = TweenService:Create(indicatorImage, TWEEN_FADE, {
			ImageTransparency = 1,
		})

		sizeTween:Play()
		fadeTween:Play()

		activeThread = task.delay(TOTAL_LIFETIME, executeImageIndicatorExpiry)
	end
end

function FeedbackKillIndicator.cleanup(): ()
	stopTracking()
	cancelActiveTweens()

	if killIndicatorGui then
		killIndicatorGui:Destroy()
		killIndicatorGui = nil
	end

	indicatorImage = nil
	circleFrame = nil
	circleStroke = nil
end

return FeedbackKillIndicator
