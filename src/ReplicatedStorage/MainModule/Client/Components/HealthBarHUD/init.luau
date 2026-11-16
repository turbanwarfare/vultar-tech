--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent
local Theme = require(MainModule.Shared.UI.Theme)

local SHADOW_ASSET = "rbxassetid://1316045217"
local SHADOW_SLICE = Rect.new(32, 32, 96, 96)

local PADDING_BOTTOM = 12
local BAR_WIDTH = 200
local BAR_HEIGHT = 14
local PLUS_SIZE = 24
local NUMBER_WIDTH = 50
local GAP = 8

local FILL_OVERFLOW = 2
local FILL_HEIGHT = BAR_HEIGHT + FILL_OVERFLOW * 2
local CENTER_OFFSET = (NUMBER_WIDTH - PLUS_SIZE) / 2 - 4
local TOTAL_WIDTH = PLUS_SIZE + GAP + BAR_WIDTH + GAP + NUMBER_WIDTH

local BG_DARKEN = 0.25
local BG_TRANSPARENCY = 0.3
local GLOW_SPREAD = 2
local GLOW_TRANSPARENCY = 0.45
local BG_GLOW_TRANSPARENCY = 0.6
local CORNER_RADIUS = 4
local GODDED_THRESHOLD = 999999
local DISABLE_DELAY = 0.4

local VISIBLE_POS = UDim2.new(0.5, CENTER_OFFSET, 1, -PADDING_BOTTOM)
local HIDDEN_POS = UDim2.new(0.5, CENTER_OFFSET, 1, BAR_HEIGHT + 40)

local SLIDE_IN_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local SLIDE_OUT_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local FILL_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local HEALTH_COLORS: { Color3 } = {
	Color3.fromRGB(80, 220, 80),
	Color3.fromRGB(200, 210, 50),
	Color3.fromRGB(240, 180, 30),
	Color3.fromRGB(240, 100, 30),
	Color3.fromRGB(220, 40, 40),
}
local HEALTH_BG_COLORS: { Color3 } = {}
for i, c in HEALTH_COLORS do
	HEALTH_BG_COLORS[i] = Color3.new(c.R * BG_DARKEN, c.G * BG_DARKEN, c.B * BG_DARKEN)
end

local HEALTH_COLOR_GODDED = Color3.fromRGB(255, 195, 60)
local HEALTH_COLOR_GODDED_BG = Color3.new(
	HEALTH_COLOR_GODDED.R * BG_DARKEN,
	HEALTH_COLOR_GODDED.G * BG_DARKEN,
	HEALTH_COLOR_GODDED.B * BG_DARKEN
)

local function getColorIndex(percent: number): number
	if percent > 0.8 then return 1
	elseif percent > 0.6 then return 2
	elseif percent > 0.4 then return 3
	elseif percent > 0.2 then return 4
	else return 5
	end
end

local HealthBarHUD = {}

local isReady = false
local isVisible = false

local gui: ScreenGui
local container: Frame
local fill: Frame
local fillWrapper: Frame
local bgFrame: Frame
local bgGlowShadow: ImageLabel
local barGlowShadow: ImageLabel
local healthLabel: TextLabel

local disableTask: thread? = nil
local slideTween: Tween? = nil
local fillTween: Tween? = nil

function HealthBarHUD.init(parent: PlayerGui): ()
	gui = Instance.new("ScreenGui")
	gui.Name = "HealthBarHUD"
	gui.AutoLocalize = false
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.fromOffset(TOTAL_WIDTH, FILL_HEIGHT)
	container.Position = HIDDEN_POS
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.BackgroundTransparency = 1
	container.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	local plusIcon = Instance.new("TextLabel")
	plusIcon.Name = "PlusIcon"
	plusIcon.Size = UDim2.fromOffset(PLUS_SIZE, PLUS_SIZE)
	plusIcon.BackgroundTransparency = 1
	plusIcon.Text = "+"
	plusIcon.TextColor3 = Theme.Colors.White
	plusIcon.TextSize = 28
	plusIcon.Font = Theme.Text.Bold
	plusIcon.TextXAlignment = Enum.TextXAlignment.Center
	plusIcon.TextYAlignment = Enum.TextYAlignment.Center
	plusIcon.LayoutOrder = 1
	plusIcon.Parent = container

	local barWrapper = Instance.new("Frame")
	barWrapper.Name = "BarWrapper"
	barWrapper.Size = UDim2.fromOffset(BAR_WIDTH, FILL_HEIGHT)
	barWrapper.BackgroundTransparency = 1
	barWrapper.LayoutOrder = 2
	barWrapper.Parent = container

	bgGlowShadow = Instance.new("ImageLabel")
	bgGlowShadow.Name = "Shadow"
	bgGlowShadow.Size = UDim2.new(1, GLOW_SPREAD * 2, 0, BAR_HEIGHT + GLOW_SPREAD * 2)
	bgGlowShadow.Position = UDim2.fromScale(0.5, 0.5)
	bgGlowShadow.AnchorPoint = Vector2.new(0.5, 0.5)
	bgGlowShadow.BackgroundTransparency = 1
	bgGlowShadow.Image = SHADOW_ASSET
	bgGlowShadow.ImageColor3 = HEALTH_BG_COLORS[1]
	bgGlowShadow.ImageTransparency = BG_GLOW_TRANSPARENCY
	bgGlowShadow.ScaleType = Enum.ScaleType.Slice
	bgGlowShadow.SliceCenter = SHADOW_SLICE
	bgGlowShadow.ZIndex = 0
	bgGlowShadow.Parent = barWrapper

	bgFrame = Instance.new("Frame")
	bgFrame.Name = "Background"
	bgFrame.Size = UDim2.new(1, 0, 0, BAR_HEIGHT)
	bgFrame.Position = UDim2.fromScale(0, 0.5)
	bgFrame.AnchorPoint = Vector2.new(0, 0.5)
	bgFrame.BackgroundColor3 = HEALTH_BG_COLORS[1]
	bgFrame.BackgroundTransparency = BG_TRANSPARENCY
	bgFrame.ZIndex = 1
	bgFrame.Parent = barWrapper
	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, CORNER_RADIUS)
	bgCorner.Parent = bgFrame

	fillWrapper = Instance.new("Frame")
	fillWrapper.Name = "FillWrapper"
	fillWrapper.Size = UDim2.fromOffset(BAR_WIDTH, FILL_HEIGHT)
	fillWrapper.Position = UDim2.fromScale(0, 0.5)
	fillWrapper.AnchorPoint = Vector2.new(0, 0.5)
	fillWrapper.BackgroundTransparency = 1
	fillWrapper.ClipsDescendants = false
	fillWrapper.ZIndex = 2
	fillWrapper.Parent = barWrapper

	barGlowShadow = Instance.new("ImageLabel")
	barGlowShadow.Name = "Shadow"
	barGlowShadow.Size = UDim2.new(1, GLOW_SPREAD * 2, 1, GLOW_SPREAD * 2)
	barGlowShadow.Position = UDim2.fromScale(0.5, 0.5)
	barGlowShadow.AnchorPoint = Vector2.new(0.5, 0.5)
	barGlowShadow.BackgroundTransparency = 1
	barGlowShadow.Image = SHADOW_ASSET
	barGlowShadow.ImageColor3 = HEALTH_COLORS[1]
	barGlowShadow.ImageTransparency = GLOW_TRANSPARENCY
	barGlowShadow.ScaleType = Enum.ScaleType.Slice
	barGlowShadow.SliceCenter = SHADOW_SLICE
	barGlowShadow.ZIndex = 0
	barGlowShadow.Parent = fillWrapper

	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.Position = UDim2.fromScale(0, 0.5)
	fill.AnchorPoint = Vector2.new(0, 0.5)
	fill.BackgroundColor3 = HEALTH_COLORS[1]
	fill.BackgroundTransparency = 0
	fill.ZIndex = 1
	fill.Parent = fillWrapper
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, CORNER_RADIUS)
	fillCorner.Parent = fill

	healthLabel = Instance.new("TextLabel")
	healthLabel.Name = "HealthNumber"
	healthLabel.Size = UDim2.fromOffset(NUMBER_WIDTH, BAR_HEIGHT)
	healthLabel.BackgroundTransparency = 1
	healthLabel.Text = "100"
	healthLabel.TextColor3 = Theme.Colors.White
	healthLabel.TextSize = 18
	healthLabel.Font = Theme.Text.Bold
	healthLabel.TextXAlignment = Enum.TextXAlignment.Left
	healthLabel.TextYAlignment = Enum.TextYAlignment.Center
	healthLabel.LayoutOrder = 3
	healthLabel.Parent = container

	gui.Parent = parent
	isReady = true
end

function HealthBarHUD.setVisible(visible: boolean): ()
	if not isReady then return end
	isVisible = visible
	if visible then
		if disableTask then
			task.cancel(disableTask)
			disableTask = nil
		end
		gui.Enabled = true
		if slideTween then
			slideTween:Cancel()
		end
		slideTween = TweenService:Create(container, SLIDE_IN_TWEEN, { Position = VISIBLE_POS })
		slideTween:Play()
	else
		if slideTween then
			slideTween:Cancel()
		end
		slideTween = TweenService:Create(container, SLIDE_OUT_TWEEN, { Position = HIDDEN_POS })
		slideTween:Play()
		disableTask = task.delay(DISABLE_DELAY, function()
			disableTask = nil
			if not isVisible then
				gui.Enabled = false
			end
		end)
	end
end

function HealthBarHUD.setHealth(current: number, max: number): ()
	if not isReady then return end

	local isGodded = current >= GODDED_THRESHOLD or current ~= current
		or max >= GODDED_THRESHOLD or max ~= max
	if isGodded then
		healthLabel.Text = "inf"
		fill.BackgroundColor3 = HEALTH_COLOR_GODDED
		barGlowShadow.ImageColor3 = HEALTH_COLOR_GODDED
		bgFrame.BackgroundColor3 = HEALTH_COLOR_GODDED_BG
		bgGlowShadow.ImageColor3 = HEALTH_COLOR_GODDED_BG
		if fillTween then
			fillTween:Cancel()
		end
		fillTween = TweenService:Create(fillWrapper, FILL_TWEEN, {
			Size = UDim2.fromOffset(BAR_WIDTH, FILL_HEIGHT),
		})
		fillTween:Play()
		return
	end

	local percent = if max > 0 then math.clamp(current / max, 0, 1) else 0
	local idx = getColorIndex(percent)
	local barColor = HEALTH_COLORS[idx]
	local bgColor = HEALTH_BG_COLORS[idx]

	healthLabel.Text = tostring(math.floor(current))
	fill.BackgroundColor3 = barColor
	barGlowShadow.ImageColor3 = barColor
	bgFrame.BackgroundColor3 = bgColor
	bgGlowShadow.ImageColor3 = bgColor

	if fillTween then
		fillTween:Cancel()
	end
	fillTween = TweenService:Create(fillWrapper, FILL_TWEEN, {
		Size = UDim2.fromOffset(percent * BAR_WIDTH, FILL_HEIGHT),
	})
	fillTween:Play()
end

function HealthBarHUD.destroy(): ()
	if disableTask then
		task.cancel(disableTask)
	end
	if slideTween then
		slideTween:Cancel()
	end
	if fillTween then
		fillTween:Cancel()
	end
	if isReady then
		gui:Destroy()
	end
	isReady = false
	isVisible = false
	disableTask = nil
	slideTween = nil
	fillTween = nil
end

return HealthBarHUD
