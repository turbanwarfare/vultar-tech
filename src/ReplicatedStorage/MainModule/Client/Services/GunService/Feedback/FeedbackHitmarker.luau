--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
local Theme = require(MainModule.Shared.UI.Theme)

local Constants = require(script.Parent.Parent.Constants)
local Cache = require(script.Parent.Parent.Cache)

local FeedbackHitmarker = {}

local player = Players.LocalPlayer

local hitmarkerGui: ScreenGui? = nil
local damageLabel: TextLabel? = nil
local hitmarkerImage: ImageLabel? = nil
local hitmarkerBaseSize: UDim2 = UDim2.fromOffset(32, 32)
local hitmarkerRotation: number = 0
local hitmarkerRotationDir: number = 1
local hitmarkerRotSpeed: number = 180
local hitmarkerConnection: boolean? = nil
local hitmarkerFadeThread: thread? = nil
local activeFadeTween: Tween? = nil

local rotationMode: number = 1
local randomPhase: number = 0
local randomSeed: number = 0
local hitStartTime: number = 0
local lastMouseX: number = 0
local lastMouseY: number = 0

local HITMARKER_BIND_NAME = "HitmarkerUpdate"
local GOLDEN_ANGLE = 137.507764
local PHI = 1.6180339887

local HOLD_DURATION = Constants.Hitmarker.HoldDuration
local FADE_OUT_DURATION = Constants.Hitmarker.FadeOutDuration
local HITMARKER_FADE_TWEEN_INFO = TweenInfo.new(FADE_OUT_DURATION, Enum.EasingStyle.Linear)
local ROTATION_SPEED = Constants.Hitmarker.RotationSpeed
local SIZE_NORMAL = Constants.Hitmarker.SizeNormal
local DAMAGE_HEAD_COLOR = Constants.Colors.DamageHead

local cachedHitmarkerAssets = SettingsConfig.HitmarkerAssets

local function executeHitmarkerFade(): ()
	if not hitmarkerImage then
		return
	end

	local tween = TweenService:Create(hitmarkerImage, HITMARKER_FADE_TWEEN_INFO, { ImageTransparency = 1 })
	activeFadeTween = tween
	tween.Completed:Once(function()
		if activeFadeTween ~= tween then
			return
		end
		activeFadeTween = nil
		if hitmarkerImage then
			hitmarkerImage.Visible = false
		end
		if hitmarkerConnection then
			RunService:UnbindFromRenderStep(HITMARKER_BIND_NAME)
			hitmarkerConnection = nil
		end
	end)
	tween:Play()

	hitmarkerFadeThread = nil
end

local function computeRandomRotation(elapsed: number): number
	local t = elapsed
	local seed = randomSeed
	local phase = randomPhase

	local wave1 = math.sin(t * 2.3 + phase) * 45
	local wave2 = math.sin(t * PHI * 1.7 + phase * PHI) * 28
	local wave3 = math.sin(t * PHI * PHI + phase * 0.7) * 15
	local wave4 = math.sin(t * 0.8 + seed) * 8

	local goldenDrift = (elapsed * GOLDEN_ANGLE * 0.3) % 360
	local driftInfluence = math.sin(t * 0.5 + phase) * 0.3 + 0.2

	local baseRotation = wave1 + wave2 + wave3 + wave4
	local finalRotation = baseRotation + goldenDrift * driftInfluence

	local breathe = 1 + math.sin(t * 1.2 + phase * 0.5) * 0.15
	finalRotation = finalRotation * breathe

	return finalRotation
end

local function updateHitmarker(dt: number)
	if not hitmarkerImage or not hitmarkerImage.Visible then
		return
	end

	local mousePos = UserInputService:GetMouseLocation()
	local mx = math.round(mousePos.X)
	local my = math.round(mousePos.Y)
	if mx ~= lastMouseX or my ~= lastMouseY then
		lastMouseX = mx
		lastMouseY = my
		hitmarkerImage.Position = UDim2.fromOffset(mx, my)
	end

	if rotationMode == 3 then
		return
	elseif rotationMode == 4 then
		local elapsed = os.clock() - hitStartTime
		hitmarkerRotation = computeRandomRotation(elapsed)
		hitmarkerImage.Rotation = hitmarkerRotation
	else
		hitmarkerRotation += dt * hitmarkerRotSpeed * hitmarkerRotationDir
		hitmarkerImage.Rotation = hitmarkerRotation
	end
end

function FeedbackHitmarker.createUI(): ()
	local playerGui = player:WaitForChild("PlayerGui", 5)
	if not playerGui then
		return
	end

	hitmarkerGui = Instance.new("ScreenGui")
	hitmarkerGui.Name = "HitmarkerGui"
	assert(hitmarkerGui).AutoLocalize = false
	hitmarkerGui.IgnoreGuiInset = true
	hitmarkerGui.ResetOnSpawn = false
	hitmarkerGui.DisplayOrder = 100

	hitmarkerImage = Instance.new("ImageLabel")
	hitmarkerImage.Name = "Hitmarker"
	hitmarkerImage.Size = SIZE_NORMAL
	hitmarkerImage.AnchorPoint = Vector2.new(0.5, 0.5)
	hitmarkerImage.BackgroundTransparency = 1
	hitmarkerImage.ImageTransparency = 1
	hitmarkerImage.Visible = false
	hitmarkerImage.ZIndex = 10
	hitmarkerImage.Parent = hitmarkerGui

	damageLabel = Instance.new("TextLabel")
	damageLabel.Name = "DamageLabel"
	damageLabel.Size = UDim2.fromOffset(120, 40)
	damageLabel.Position = UDim2.fromOffset(0, 0)
	damageLabel.AnchorPoint = Vector2.zero
	damageLabel.BackgroundTransparency = 1
	damageLabel.Font = Cache.getDamageIndicatorFont()
	damageLabel.TextSize = 18
	damageLabel.TextColor3 = Constants.Colors.DamageNormal
	damageLabel.TextStrokeTransparency = 1
	damageLabel.TextTransparency = 1
	damageLabel.TextXAlignment = Enum.TextXAlignment.Left
	damageLabel.Text = ""
	damageLabel.Parent = hitmarkerGui

	local cursorStroke = Instance.new("UIStroke")
	cursorStroke.Name = "Outline"
	cursorStroke.Color = Constants.Colors.Stroke
	cursorStroke.Thickness = Cache.getDamageIndicatorOutline()
	cursorStroke.Transparency = 1
	cursorStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	cursorStroke.Parent = damageLabel

	hitmarkerGui.Parent = playerGui
end

function FeedbackHitmarker.getDamageLabel(): TextLabel?
	if damageLabel then
		damageLabel.Font = Cache.getDamageIndicatorFont()
	end
	return damageLabel
end

function FeedbackHitmarker.animate(isHeadshot: boolean): ()
	if not hitmarkerImage then
		return
	end

	if not Cache.getHitIndicatorsEnabled() then
		return
	end

	if hitmarkerFadeThread then
		task.cancel(hitmarkerFadeThread)
		hitmarkerFadeThread = nil
	end

	if activeFadeTween then
		activeFadeTween:Cancel()
		activeFadeTween = nil
	end

	local preset = Cache.getHitPreset()
	local colorIndex = Cache.getHitColor()
	local rotationSetting = Cache.getHitmarkerRotation()

	local hitmarkerAsset = cachedHitmarkerAssets[preset]
	if not hitmarkerAsset then
		return
	end

	local mousePos = UserInputService:GetMouseLocation()

	hitmarkerImage.Image = hitmarkerAsset.id
	local useRedHeadshot = isHeadshot and Cache.getHitHeadshotRed()
	hitmarkerImage.ImageColor3 = useRedHeadshot and DAMAGE_HEAD_COLOR
		or Theme.HighlightColors[colorIndex]
		or Theme.HighlightColors[1]
	hitmarkerImage.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
	hitmarkerImage.ImageTransparency = 0
	hitmarkerImage.Visible = true

	local sizeScale = Cache.getHitIndicatorSize()
	local sizeX = hitmarkerAsset.size.X.Scale * SIZE_NORMAL.X.Offset * sizeScale
	local sizeY = hitmarkerAsset.size.Y.Scale * SIZE_NORMAL.Y.Offset * sizeScale
	if sizeX < 1 then
		sizeX = 32 * sizeScale
	end
	if sizeY < 1 then
		sizeY = 32 * sizeScale
	end
	hitmarkerBaseSize = UDim2.fromOffset(sizeX, sizeY)
	hitmarkerImage.Size = hitmarkerBaseSize

	rotationMode = rotationSetting
	hitmarkerRotationDir = if rotationSetting == 1 then -1 else 1
	hitmarkerRotSpeed = ROTATION_SPEED * Cache.getHitmarkerSpeedMultiplier()

	if rotationSetting == 3 then
		hitmarkerImage.Rotation = 0
	elseif rotationSetting == 4 then
		hitStartTime = os.clock()
		randomPhase = randomPhase + GOLDEN_ANGLE
		randomSeed = (randomSeed + PHI * 100) % 1000
	end

	if not hitmarkerConnection then
		RunService:BindToRenderStep(HITMARKER_BIND_NAME, Enum.RenderPriority.Last.Value, updateHitmarker)
		hitmarkerConnection = true
	end

	hitmarkerFadeThread = task.delay(HOLD_DURATION, executeHitmarkerFade)
end

function FeedbackHitmarker.cleanup(): ()
	if hitmarkerConnection then
		RunService:UnbindFromRenderStep(HITMARKER_BIND_NAME)
		hitmarkerConnection = nil
	end

	if hitmarkerFadeThread then
		task.cancel(hitmarkerFadeThread)
		hitmarkerFadeThread = nil
	end

	if activeFadeTween then
		activeFadeTween:Cancel()
		activeFadeTween = nil
	end

	if hitmarkerGui then
		hitmarkerGui:Destroy()
		hitmarkerGui = nil
	end

	hitmarkerImage = nil
	damageLabel = nil
	hitmarkerRotation = 0
	hitmarkerRotationDir = 1
	rotationMode = 1
	randomPhase = 0
	randomSeed = 0
	hitStartTime = 0
	lastMouseX = 0
	lastMouseY = 0
end

return FeedbackHitmarker
