--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

local TweenService = game:GetService("TweenService")

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type ConquestUIProps = {
	Visible: Types.FusionValue<boolean>,
	Progress: Types.FusionValue<number>,
	Team: Types.FusionValue<string?>,
	Action: Types.FusionValue<string>,
	NodeName: Types.FusionValue<string>,
	TimeRemaining: Types.FusionValue<number>,
}

local BAR_WIDTH = 240
local BAR_HEIGHT = 12
local CORNER_RADIUS = 4

local RAIDER_COLOR   = Color3.fromRGB(50, 110, 200)
local DEFENDER_COLOR = Color3.fromRGB(180, 50, 50)
local NEUTRAL_COLOR  = Color3.fromRGB(120, 120, 125)
local BG_COLOR       = Color3.fromRGB(14, 14, 14)
local BORDER_COLOR   = Color3.fromRGB(75, 73, 75)

local BG_TRANSPARENCY_VISIBLE   = 0.2
local STROKE_TRANSPARENCY_VISIBLE = 0.3
local BAR_BG_TRANSPARENCY_VISIBLE = 0.4

local FADE_TWEEN     = TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BAR_TWEEN      = TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local COLOR_TWEEN    = TweenInfo.new(0.40, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local DISABLE_DELAY = 0.35

local TIME_STRINGS: { [number]: string } = table.create(600)
do
	for i = 0, 599 do
		TIME_STRINGS[i] = string.format("%d:%02d", i // 60, i % 60)
	end
end

local function formatTime(seconds: number): string
	return TIME_STRINGS[math.floor(math.clamp(seconds, 0, 599))]
end

local function ConquestUI(scope: FusionScope, props: ConquestUIProps): ScreenGui
	local guiEnabled = scope:Value(false)
	local disableTask: thread? = nil

	local barColor = scope:Computed(function(use: FusionUseFn)
		local team = use(props.Team)
		if team == "Raiders" then return RAIDER_COLOR end
		if team == "Defenders" then return DEFENDER_COLOR end
		return NEUTRAL_COLOR
	end)

	local clampedProgress = scope:Computed(function(use: FusionUseFn)
		return math.clamp(use(props.Progress), 0, 1)
	end)

	local statusText = scope:Computed(function(use: FusionUseFn)
		local action = use(props.Action)
		local team   = use(props.Team) or "NEUTRAL"
		if action == "UpdateCaptureProgress" then
			return string.upper(team) .. " CAPTURING"
		elseif action == "CaptureComplete" then
			return string.upper(team) .. " CAPTURED"
		elseif action == "StartHold" or action == "UpdateHoldProgress" then
			return string.upper(team) .. " HOLDING - " .. formatTime(use(props.TimeRemaining))
		elseif action == "EndHold" then
			return "HOLD ENDED"
		elseif action == "RollbackComplete" then
			return "ROLLBACK"
		end
		return "CONTESTED"
	end)

	local initialVisible  = Fusion.peek(props.Visible)
	local initialProgress = Fusion.peek(clampedProgress)
	local initialColor    = Fusion.peek(barColor)

	local barFill = scope:New("Frame")({
		Name = "Fill",
		Size = UDim2.fromScale(initialProgress, 1),
		BackgroundColor3 = initialColor,
		BackgroundTransparency = if initialVisible then 0 else 1,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
		},
	}) :: Frame

	local barBackground = scope:New("Frame")({
		Name = "BarBackground",
		Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Theme.Colors.Black[800],
		BackgroundTransparency = if initialVisible then BAR_BG_TRANSPARENCY_VISIBLE else 1,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
			barFill,
		},
	}) :: Frame

	local barStroke = scope:New("UIStroke")({
		Color = BORDER_COLOR,
		Thickness = 1,
		Transparency = if initialVisible then STROKE_TRANSPARENCY_VISIBLE else 1,
	}) :: UIStroke

	local statusTextLabel = scope:New("TextLabel")({
		Name = "StatusText",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0.5, 0, 0, 6),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Text = statusText,
		TextColor3 = barColor,
		TextTransparency = if initialVisible then 0 else 1,
		TextSize = 12,
		Font = Theme.Text.Bold,
	}) :: TextLabel

	local conquestFrame = scope:New("Frame")({
		Name = "ConquestFrame",
		Size = UDim2.fromOffset(BAR_WIDTH + 20, 52),
		Position = UDim2.fromScale(0.5, 0.72),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = BG_COLOR,
		BackgroundTransparency = if initialVisible then BG_TRANSPARENCY_VISIBLE else 1,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER_RADIUS) }),
			barStroke,
			statusTextLabel,
			barBackground,
		},
	}) :: Frame

	local fadeTween:     Tween? = nil
	local progressTween: Tween? = nil
	local colorTween:    Tween? = nil
	local fadeStrokeTween:  Tween? = nil
	local fadeStatusTween:  Tween? = nil
	local fadeBarBgTween:   Tween? = nil
	local fadeFillTween:    Tween? = nil

	scope:Observer(props.Visible):onBind(function()
		local visible = Fusion.peek(props.Visible)
		if visible then
			if disableTask then
				task.cancel(disableTask)
				disableTask = nil
			end
			guiEnabled:set(true)
		else
			disableTask = task.delay(DISABLE_DELAY, function()
				disableTask = nil
				if not Fusion.peek(props.Visible) then
					guiEnabled:set(false)
				end
			end)
		end

		if fadeTween then
			fadeTween:Cancel()
		end
		if fadeStrokeTween then
			fadeStrokeTween:Cancel()
		end
		if fadeStatusTween then
			fadeStatusTween:Cancel()
		end
		if fadeBarBgTween then
			fadeBarBgTween:Cancel()
		end
		if fadeFillTween then
			fadeFillTween:Cancel()
		end
		fadeTween = TweenService:Create(conquestFrame, FADE_TWEEN, {
			BackgroundTransparency = if visible then BG_TRANSPARENCY_VISIBLE else 1,
		})
		fadeTween:Play()
		fadeStrokeTween = TweenService:Create(barStroke, FADE_TWEEN, {
			Transparency = if visible then STROKE_TRANSPARENCY_VISIBLE else 1,
		})
		fadeStrokeTween:Play()
		fadeStatusTween = TweenService:Create(statusTextLabel, FADE_TWEEN, {
			TextTransparency = if visible then 0 else 1,
		})
		fadeStatusTween:Play()
		fadeBarBgTween = TweenService:Create(barBackground, FADE_TWEEN, {
			BackgroundTransparency = if visible then BAR_BG_TRANSPARENCY_VISIBLE else 1,
		})
		fadeBarBgTween:Play()
		fadeFillTween = TweenService:Create(barFill, FADE_TWEEN, {
			BackgroundTransparency = if visible then 0 else 1,
		})
		fadeFillTween:Play()
	end)

	scope:Observer(clampedProgress):onBind(function()
		if progressTween then
			progressTween:Cancel()
		end
		progressTween = TweenService:Create(barFill, BAR_TWEEN, {
			Size = UDim2.fromScale(Fusion.peek(clampedProgress), 1),
		})
		progressTween:Play()
	end)

	scope:Observer(barColor):onBind(function()
		if colorTween then
			colorTween:Cancel()
		end
		colorTween = TweenService:Create(barFill, COLOR_TWEEN, {
			BackgroundColor3 = Fusion.peek(barColor),
		})
		colorTween:Play()
	end)

	table.insert(scope, function()
		if disableTask then
			task.cancel(disableTask)
		end
		if fadeTween then
			fadeTween:Cancel()
		end
		if fadeStrokeTween then
			fadeStrokeTween:Cancel()
		end
		if fadeStatusTween then
			fadeStatusTween:Cancel()
		end
		if fadeBarBgTween then
			fadeBarBgTween:Cancel()
		end
		if fadeFillTween then
			fadeFillTween:Cancel()
		end
		if progressTween then
			progressTween:Cancel()
		end
		if colorTween then
			colorTween:Cancel()
		end
	end)

	return scope:New("ScreenGui")({
		Name = "ConquestUI",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 85,
		Enabled = guiEnabled,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		[Fusion.Children] = {
			conquestFrame,
		},
	})
end

return ConquestUI
