--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
local SettingsHelper = require(script.Parent.Parent.Utils.SettingsHelper)

local KillIndicatorRenderer = {}

export type KillIndicatorState = {
	indicatorImage: ImageLabel,
	activeThread: thread?,
	isAnimating: boolean,
}

local KILL_THRESHOLD = 100

local CIRCLE_IMAGE = "rbxassetid://6031068433"
local SKULL_IMAGE = "rbxassetid://0"

local KILL_COLORS = {
	Color3.new(1, 1, 1),
	Color3.fromRGB(255, 220, 50),
	Color3.fromRGB(180, 30, 30),
	Color3.fromRGB(80, 255, 120),
	Color3.fromRGB(255, 150, 50),
	Color3.fromRGB(100, 180, 255),
}

local Constants = require(script.Parent.Parent.Constants)

local EXPAND_DURATION = 0.3
local FADE_DURATION = 0.3
local TOTAL_LIFETIME = Constants.KILL_INDICATOR_TOTAL_LIFETIME
local DEFAULT_SIZE = 65

local TWEEN_EXPAND = TweenInfo.new(EXPAND_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_FADE = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

local TYPE_CIRCLE = 1
local TYPE_HITMARKER = 2
local TYPE_SKULL = 3

local function getIndicatorImage(indicatorType: number): (string, UDim2)
	if indicatorType == TYPE_SKULL then
		return SKULL_IMAGE, UDim2.fromScale(1, 1)
	elseif indicatorType == TYPE_HITMARKER then
		local hitPreset = SettingsHelper.getSetting("HitPreset") or 1
		local asset = SettingsConfig.HitmarkerAssets[hitPreset]
		if asset then
			return asset.id, asset.size
		end
		return CIRCLE_IMAGE, UDim2.fromScale(1, 1)
	else
		return CIRCLE_IMAGE, UDim2.fromScale(1, 1)
	end
end

export type KillIndicatorStateExtended = KillIndicatorState & {
	circleFrame: Frame?,
	circleStroke: UIStroke?,
	sizeTween: Tween?,
	fadeTween: Tween?,
	strokeFadeTween: Tween?,
}

function KillIndicatorRenderer.createState(parent: Frame): KillIndicatorStateExtended
	local indicatorImage = Instance.new("ImageLabel")
	indicatorImage.Name = "KillIndicator"
	indicatorImage.Size = UDim2.fromOffset(0, 0)
	indicatorImage.AnchorPoint = Vector2.new(0.5, 0.5)
	indicatorImage.BackgroundTransparency = 1
	indicatorImage.ImageTransparency = 0
	indicatorImage.Visible = false
	indicatorImage.ZIndex = 19
	indicatorImage.Parent = parent

	local circleFrame = Instance.new("Frame")
	circleFrame.Name = "KillCircle"
	circleFrame.Size = UDim2.fromOffset(0, 0)
	circleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	circleFrame.BackgroundTransparency = 1
	circleFrame.Visible = false
	circleFrame.ZIndex = 19
	circleFrame.Parent = parent

	local circleCorner = Instance.new("UICorner")
	circleCorner.CornerRadius = UDim.new(0.5, 0)
	circleCorner.Parent = circleFrame

	local circleStroke = Instance.new("UIStroke")
	circleStroke.Name = "CircleStroke"
	circleStroke.Thickness = 4
	circleStroke.Color = Color3.new(1, 1, 1)
	circleStroke.Transparency = 0
	circleStroke.Parent = circleFrame

	return {
		indicatorImage = indicatorImage,
		circleFrame = circleFrame,
		circleStroke = circleStroke,
		activeThread = nil,
		isAnimating = false,
		sizeTween = nil,
		fadeTween = nil,
		strokeFadeTween = nil,
	}
end

local function cancelActiveTweens(state: KillIndicatorStateExtended)
	if state.sizeTween then
		state.sizeTween:Cancel()
		state.sizeTween = nil
	end
	if state.fadeTween then
		state.fadeTween:Cancel()
		state.fadeTween = nil
	end
	if state.strokeFadeTween then
		state.strokeFadeTween:Cancel()
		state.strokeFadeTween = nil
	end
	if state.activeThread then
		task.cancel(state.activeThread)
		state.activeThread = nil
	end
end

function KillIndicatorRenderer.show(
	state: KillIndicatorStateExtended,
	position: Vector2,
	isDestroyed: () -> boolean
): ()
	if not SettingsHelper.getSetting("KillIndicators") then
		return
	end

	local indicatorImage = state.indicatorImage
	local circleFrame = state.circleFrame
	local circleStroke = state.circleStroke

	cancelActiveTweens(state)

	state.isAnimating = true

	local indicatorType = SettingsHelper.getSetting("KillIndicatorType") or 1
	local colorIndex = SettingsHelper.getSetting("KillIndicatorColor") or 1
	local size = SettingsHelper.getSetting("KillIndicatorSize") or DEFAULT_SIZE

	local color = KILL_COLORS[colorIndex] or KILL_COLORS[1]
	local useCircleFrame = indicatorType == TYPE_CIRCLE

	local targetSize = size
	if targetSize <= 0 then
		targetSize = DEFAULT_SIZE
	end

	if useCircleFrame and circleFrame and circleStroke then
		indicatorImage.Visible = false

		circleStroke.Color = color
		circleStroke.Transparency = 0
		circleFrame.Position = UDim2.fromOffset(position.X, position.Y)
		circleFrame.Size = UDim2.fromOffset(0, 0)
		circleFrame.Visible = true

		local finalSize = UDim2.fromOffset(targetSize, targetSize)

		state.sizeTween = TweenService:Create(circleFrame, TWEEN_EXPAND, {
			Size = finalSize,
		})

		state.strokeFadeTween = TweenService:Create(circleStroke, TWEEN_FADE, {
			Transparency = 1,
		})

		state.sizeTween:Play()
		state.strokeFadeTween:Play()

		state.activeThread = task.delay(TOTAL_LIFETIME, function()
			if isDestroyed() then return end
			circleFrame.Visible = false
			circleFrame.Size = UDim2.fromOffset(0, 0)
			circleStroke.Transparency = 0
			state.isAnimating = false
			state.activeThread = nil
		end)
	else
		if circleFrame then
			circleFrame.Visible = false
		end

		local image, imageScale = getIndicatorImage(indicatorType)
		local scaledWidth = targetSize * imageScale.X.Scale + imageScale.X.Offset
		local scaledHeight = targetSize * imageScale.Y.Scale + imageScale.Y.Offset

		indicatorImage.Image = image
		indicatorImage.ImageColor3 = color
		indicatorImage.Position = UDim2.fromOffset(position.X, position.Y)
		indicatorImage.Size = UDim2.fromOffset(0, 0)
		indicatorImage.ImageTransparency = 0
		indicatorImage.Visible = true

		local finalSize = UDim2.fromOffset(scaledWidth, scaledHeight)

		state.sizeTween = TweenService:Create(indicatorImage, TWEEN_EXPAND, {
			Size = finalSize,
		})

		state.fadeTween = TweenService:Create(indicatorImage, TWEEN_FADE, {
			ImageTransparency = 1,
		})

		state.sizeTween:Play()
		state.fadeTween:Play()

		state.activeThread = task.delay(TOTAL_LIFETIME, function()
			if isDestroyed() then return end
			indicatorImage.Visible = false
			indicatorImage.Size = UDim2.fromOffset(0, 0)
			indicatorImage.ImageTransparency = 0
			state.isAnimating = false
			state.activeThread = nil
		end)
	end
end

function KillIndicatorRenderer.getThreshold(): number
	return KILL_THRESHOLD
end

function KillIndicatorRenderer.cleanup(state: KillIndicatorStateExtended): ()
	cancelActiveTweens(state)
	state.isAnimating = false

	if state.indicatorImage then
		state.indicatorImage:Destroy()
	end
	if state.circleFrame then
		state.circleFrame:Destroy()
	end
end

return KillIndicatorRenderer
