--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent
local Theme = require(MainModule.Shared.UI.Theme)

type PhaseOwner = "Defenders" | "Raiders" | nil

local DEFENDER_COLOR = Color3.fromRGB(180, 50, 50)
local DEFENDER_LIGHT = Color3.fromRGB(200, 70, 70)
local DEFENDER_EDGE = Color3.fromRGB(70, 18, 22)
local RAIDER_COLOR = Color3.fromRGB(50, 110, 200)
local RAIDER_LIGHT = Color3.fromRGB(70, 130, 215)
local RAIDER_EDGE = Color3.fromRGB(35, 75, 140)

local TOTAL_WIDTH = 400
local TOP_OFFSET = 11
local HEADER_HEIGHT = 17
local HEADER_GAP = 3
local MAIN_BAR_HEIGHT = 22
local BAR_GAP = 3
local BOTTOM_ROW_HEIGHT = 22
local ICON_WRAPPER_SIZE = 30
local ELEMENT_GAP = 8
local BAR_CORNER = 4
local FILL_EDGE = 2
local STROKE_PAD = 2

local MAIN_BAR_Y = HEADER_HEIGHT + HEADER_GAP
local BOTTOM_Y = MAIN_BAR_Y + MAIN_BAR_HEIGHT + BAR_GAP
local CONTAINER_HEIGHT = BOTTOM_Y + BOTTOM_ROW_HEIGHT + STROKE_PAD * 2
local ESCORT_CONTAINER_HEIGHT = MAIN_BAR_Y + math.max(MAIN_BAR_HEIGHT, ICON_WRAPPER_SIZE) + STROKE_PAD * 2
local MAIN_BAR_X = ICON_WRAPPER_SIZE + ELEMENT_GAP

local DISABLE_DELAY = 0.4
local CONTAINER_X_OFFSET = -25
local HIDDEN_Y = -(CONTAINER_HEIGHT + 20)

local WINDOW_BG = Theme.Chat.Window.Background
local WINDOW_BORDER = Theme.Chat.Window.Border

local SLIDE_IN_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SLIDE_OUT_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FILL_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CAPTURE_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HEIGHT_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local timeStringCache: { [number]: string } = {}

local function formatTime(totalSeconds: number): string
	local cached = timeStringCache[totalSeconds]
	if cached then
		return cached
	end
	local minutes = totalSeconds // 60
	local seconds = math.floor(totalSeconds % 60)
	local str = string.format("%d:%02d", minutes, seconds)
	timeStringCache[totalSeconds] = str
	return str
end

local function computeCapturePosition(owner: PhaseOwner, progress: number, team: PhaseOwner): number
	if team == nil or progress <= 0 then
		if owner == "Defenders" then
			return 1
		end
		if owner == "Raiders" then
			return 0
		end
		return 0.5
	end
	if team == "Raiders" then
		return math.clamp(1 - progress, 0, 1)
	end
	if team == "Defenders" then
		return math.clamp(progress, 0, 1)
	end
	return 0.5
end

local function newCorner(radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	return c
end

local function newStroke(): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = WINDOW_BORDER
	s.Thickness = 1
	s.Transparency = 0.5
	return s
end

local function newFillBar(
	edgeColor: Color3,
	lightColor: Color3,
	darkColor: Color3,
	anchorRight: boolean
): (Frame, UIGradient)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.Position = if anchorRight then UDim2.fromScale(1, 0) else UDim2.fromOffset(0, 0)
	fill.AnchorPoint = if anchorRight then Vector2.new(1, 0) else Vector2.zero
	fill.BackgroundColor3 = edgeColor
	fill.ClipsDescendants = true
	newCorner(BAR_CORNER).Parent = fill

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.Size = UDim2.new(1, -FILL_EDGE * 2, 1, -FILL_EDGE * 2)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.BackgroundColor3 = Theme.Colors.White
	inner.Parent = fill
	newCorner(math.max(1, BAR_CORNER - 1)).Parent = inner

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, lightColor),
		ColorSequenceKeypoint.new(1, darkColor),
	})
	gradient.Rotation = 90
	gradient.Parent = inner

	return fill, gradient
end

local stateConquestActive: boolean = true
local statePayloadControlTeam: PhaseOwner = nil
local stateOwner: PhaseOwner = nil
local stateCaptureProgress: number = 0
local stateCaptureTeam: PhaseOwner = nil
local stateTermProgress: number = 0
local statePayloadProgress: number = 0
local stateOvertime: boolean = false

local gui: ScreenGui
local container: Frame
local phaseLabel: TextLabel
local officialLabel: TextLabel
local elapsedLabel: TextLabel
local mainBarFill: Frame
local mainBarGradient: UIGradient
local percentLabel: TextLabel
local timeLabel: TextLabel
local defCaptureFill: Frame
local raidCaptureFill: Frame
local iconBox: Frame
local ownerIcon: ImageLabel
local phaseBottomLabel: TextLabel
local captureBar: Frame
local captureProgressFill: Frame

local slideTween: Tween? = nil
local fillTween: Tween? = nil
local defCaptureTween: Tween? = nil
local raidCaptureTween: Tween? = nil
local captureProgressTween: Tween? = nil
local heightTween: Tween? = nil
local disableTask: thread? = nil

local lastElapsedSec = -1
local lastTermSec = -1
local lastBarPct = -1
local captureUpdatePending = false
local isReady = false

local function updateMainBarColor(): ()
	local edge: Color3
	local light: Color3
	local dark: Color3
	local teamColor: Color3
	local isDefenderOwned = stateOwner == "Defenders"
	if
		(not stateConquestActive and statePayloadControlTeam == "Defenders")
		or (stateConquestActive and isDefenderOwned)
	then
		edge, light, dark = DEFENDER_EDGE, DEFENDER_LIGHT, DEFENDER_COLOR
		teamColor = DEFENDER_COLOR
	else
		edge, light, dark = RAIDER_EDGE, RAIDER_LIGHT, RAIDER_COLOR
		teamColor = RAIDER_COLOR
	end
	mainBarFill.BackgroundColor3 = edge
	mainBarGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, light),
		ColorSequenceKeypoint.new(1, dark),
	})
	iconBox.BackgroundColor3 = teamColor

	if
		(not stateConquestActive and statePayloadControlTeam == "Defenders")
		or (stateConquestActive and isDefenderOwned)
	then
		ownerIcon.Image = "rbxassetid://98751546690059"
	else
		ownerIcon.Image = "rbxassetid://0"
	end
end

local function updateMainBarFill(): ()
	local progress = if stateConquestActive
		then math.clamp(stateTermProgress, 0, 1)
		else math.clamp(statePayloadProgress, 0, 1)
	local pct = math.floor(progress * 100)
	if pct ~= lastBarPct then
		lastBarPct = pct
		percentLabel.Text = tostring(pct) .. "%"
	end
	if fillTween then
		fillTween:Cancel()
	end
	fillTween = TweenService:Create(mainBarFill, FILL_TWEEN, { Size = UDim2.fromScale(progress, 1) })
	fillTween:Play()
end

local function updateCaptureBar(): ()
	local targetPos = computeCapturePosition(stateOwner, stateCaptureProgress, stateCaptureTeam)
	local defFill = math.clamp(targetPos * 2 - 1, 0, 1)
	local raidFill = math.clamp(1 - targetPos * 2, 0, 1)
	if defCaptureTween then
		defCaptureTween:Cancel()
	end
	if raidCaptureTween then
		raidCaptureTween:Cancel()
	end
	defCaptureTween = TweenService:Create(defCaptureFill, CAPTURE_TWEEN, { Size = UDim2.fromScale(defFill, 1) })
	raidCaptureTween = TweenService:Create(raidCaptureFill, CAPTURE_TWEEN, { Size = UDim2.fromScale(raidFill, 1) })
	defCaptureTween:Play()
	raidCaptureTween:Play()

	local fillWidth: number
	local fillColor: Color3
	if stateOwner == "Raiders" then
		if raidFill > 0 then
			fillWidth = raidFill
			fillColor = RAIDER_COLOR
		elseif defFill > 0 then
			fillWidth = defFill
			fillColor = DEFENDER_COLOR
		else
			fillWidth = 0
			fillColor = RAIDER_COLOR
		end
	else
		if stateCaptureTeam ~= nil and stateCaptureProgress > 0 and stateCaptureProgress < 1 then
			fillWidth = stateCaptureProgress
			fillColor = if stateCaptureTeam == "Defenders" then DEFENDER_COLOR else RAIDER_COLOR
		else
			fillWidth = 0
			fillColor = RAIDER_COLOR
		end
	end

	captureProgressFill.Visible = fillWidth > 0
	if fillWidth > 0 then
		captureProgressFill.BackgroundColor3 = fillColor
		if captureProgressTween then
			captureProgressTween:Cancel()
		end
		captureProgressTween = TweenService:Create(captureProgressFill, CAPTURE_TWEEN, {
			Size = UDim2.new(fillWidth, 0, 0, 3),
		})
		captureProgressTween:Play()
	end
end

local function scheduleCaptureUpdate(): ()
	if captureUpdatePending then
		return
	end
	captureUpdatePending = true
	task.defer(function()
		captureUpdatePending = false
		updateCaptureBar()
	end)
end

local MataroLayout = {}

function MataroLayout.init(parent: PlayerGui): ()
	gui = Instance.new("ScreenGui")
	gui.Name = "PhaseTerminalHUD"
	gui.AutoLocalize = false
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	container = Instance.new("Frame")
	container.Name = "PhaseTerminalContainer"
	container.Size = UDim2.fromOffset(TOTAL_WIDTH + STROKE_PAD * 2, CONTAINER_HEIGHT)
	container.Position = UDim2.new(0.5, CONTAINER_X_OFFSET, 0, HIDDEN_Y)
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.BackgroundTransparency = 1
	container.ClipsDescendants = true
	container.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, STROKE_PAD)
	padding.PaddingRight = UDim.new(0, STROKE_PAD)
	padding.PaddingTop = UDim.new(0, STROKE_PAD)
	padding.PaddingBottom = UDim.new(0, STROKE_PAD)
	padding.Parent = container

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, -MAIN_BAR_X, 0, HEADER_HEIGHT)
	header.Position = UDim2.fromOffset(MAIN_BAR_X, 0)
	header.BackgroundTransparency = 1
	header.Parent = container

	phaseLabel = Instance.new("TextLabel")
	phaseLabel.Name = "PhaseLabel"
	phaseLabel.Size = UDim2.new(0, 80, 1, 0)
	phaseLabel.BackgroundTransparency = 1
	phaseLabel.Text = "STANDBY"
	phaseLabel.TextColor3 = Theme.Foreground.Primary
	phaseLabel.TextSize = 11
	phaseLabel.Font = Theme.Text.Bold
	phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
	phaseLabel.Parent = header

	officialLabel = Instance.new("TextLabel")
	officialLabel.Name = "OfficialLabel"
	officialLabel.Size = UDim2.fromScale(1, 1)
	officialLabel.BackgroundTransparency = 1
	officialLabel.Text = "UNOFFICIAL"
	officialLabel.TextColor3 = Theme.Foreground.Primary
	officialLabel.TextSize = 10
	officialLabel.Font = Theme.Text.Bold
	officialLabel.TextXAlignment = Enum.TextXAlignment.Center
	officialLabel.Parent = header

	elapsedLabel = Instance.new("TextLabel")
	elapsedLabel.Name = "ElapsedLabel"
	elapsedLabel.Size = UDim2.new(0, 60, 1, 0)
	elapsedLabel.Position = UDim2.fromScale(1, 0)
	elapsedLabel.AnchorPoint = Vector2.new(1, 0)
	elapsedLabel.BackgroundTransparency = 1
	elapsedLabel.Text = "0:00"
	elapsedLabel.TextColor3 = Theme.Foreground.Secondary
	elapsedLabel.TextSize = 11
	elapsedLabel.Font = Theme.Text.Bold
	elapsedLabel.TextXAlignment = Enum.TextXAlignment.Right
	elapsedLabel.Parent = header

	local iconWrapper = Instance.new("Frame")
	iconWrapper.Name = "IconWrapper"
	iconWrapper.Size = UDim2.fromOffset(ICON_WRAPPER_SIZE, ICON_WRAPPER_SIZE)
	iconWrapper.Position = UDim2.fromOffset(5, 17)
	iconWrapper.BackgroundColor3 = WINDOW_BG
	iconWrapper.BackgroundTransparency = 0.3
	iconWrapper.Parent = container
	newCorner(BAR_CORNER).Parent = iconWrapper
	newStroke().Parent = iconWrapper

	iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.Size = UDim2.fromOffset(22, 22)
	iconBox.Position = UDim2.fromScale(0.5, 0.5)
	iconBox.AnchorPoint = Vector2.new(0.5, 0.5)
	iconBox.BackgroundColor3 = RAIDER_COLOR
	iconBox.Parent = iconWrapper
	newCorner(BAR_CORNER - 1).Parent = iconBox

	ownerIcon = Instance.new("ImageLabel")
	ownerIcon.Name = "ownerIcon"
	ownerIcon.ZIndex = 5
	ownerIcon.BackgroundTransparency = 1
	ownerIcon.Image = "rbxassetid://0"
	ownerIcon.Size = UDim2.fromOffset(15, 15)
	ownerIcon.Position = UDim2.fromOffset(3, 3)
	ownerIcon.Parent = iconBox

	local holdBar = Instance.new("Frame")
	holdBar.Name = "HoldBar"
	holdBar.Size = UDim2.new(1, -MAIN_BAR_X, 0, MAIN_BAR_HEIGHT)
	holdBar.Position = UDim2.fromOffset(MAIN_BAR_X, MAIN_BAR_Y)
	holdBar.BackgroundColor3 = WINDOW_BG
	holdBar.BackgroundTransparency = 0.3
	holdBar.ClipsDescendants = true
	holdBar.Parent = container
	newCorner(BAR_CORNER).Parent = holdBar
	newStroke().Parent = holdBar

	mainBarFill, mainBarGradient = newFillBar(RAIDER_EDGE, RAIDER_LIGHT, RAIDER_COLOR, false)
	mainBarFill.Parent = holdBar

	percentLabel = Instance.new("TextLabel")
	percentLabel.Name = "Percent"
	percentLabel.Size = UDim2.new(0, 50, 1, 0)
	percentLabel.Position = UDim2.new(1, -6, 0.5, 0)
	percentLabel.AnchorPoint = Vector2.new(1, 0.5)
	percentLabel.BackgroundTransparency = 1
	percentLabel.Text = "0%"
	percentLabel.TextColor3 = Theme.Colors.White
	percentLabel.TextSize = 11
	percentLabel.Font = Theme.Text.Bold
	percentLabel.TextXAlignment = Enum.TextXAlignment.Right
	percentLabel.ZIndex = 2
	percentLabel.Parent = holdBar

	local captureHolder = Instance.new("Frame")
	captureHolder.Name = "CaptureHolder"
	captureHolder.Size = UDim2.fromOffset(0, 0)
	captureHolder.BackgroundTransparency = 1
	captureHolder.Visible = false
	captureHolder.Parent = container

	defCaptureFill, _ = newFillBar(DEFENDER_EDGE, DEFENDER_LIGHT, DEFENDER_COLOR, false)
	defCaptureFill.Parent = captureHolder

	raidCaptureFill, _ = newFillBar(RAIDER_EDGE, RAIDER_LIGHT, RAIDER_COLOR, false)
	raidCaptureFill.Parent = captureHolder

	captureBar = Instance.new("Frame")
	captureBar.Name = "CaptureBar"
	captureBar.Size = UDim2.new(1, -225, 0, MAIN_BAR_HEIGHT)
	captureBar.Position = UDim2.new(0.5, MAIN_BAR_X / 2, 0, 45)
	captureBar.AnchorPoint = Vector2.new(0.5, 0)
	captureBar.BackgroundColor3 = WINDOW_BG
	captureBar.BackgroundTransparency = 0.3
	captureBar.ClipsDescendants = true
	captureBar.Parent = container
	newCorner(BAR_CORNER).Parent = captureBar
	newStroke().Parent = captureBar

	phaseBottomLabel = Instance.new("TextLabel")
	phaseBottomLabel.Name = "PhaseBottomLabel"
	phaseBottomLabel.Size = UDim2.new(1, -8, 1, 0)
	phaseBottomLabel.Position = UDim2.fromOffset(8, 0)
	phaseBottomLabel.BackgroundTransparency = 1
	phaseBottomLabel.Text = ""
	phaseBottomLabel.TextColor3 = Theme.Foreground.Secondary
	phaseBottomLabel.TextSize = 12
	phaseBottomLabel.Font = Theme.Text.Bold
	phaseBottomLabel.TextXAlignment = Enum.TextXAlignment.Left
	phaseBottomLabel.ZIndex = 2
	phaseBottomLabel.Parent = captureBar

	timeLabel = Instance.new("TextLabel")
	timeLabel.Name = "Time"
	timeLabel.Size = UDim2.new(1, -8, 1, 0)
	timeLabel.Position = UDim2.fromOffset(0, 0)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Text = "0:00"
	timeLabel.TextColor3 = Theme.Foreground.Primary
	timeLabel.TextSize = 13
	timeLabel.Font = Theme.Text.Bold
	timeLabel.TextXAlignment = Enum.TextXAlignment.Right
	timeLabel.ZIndex = 2
	timeLabel.Parent = captureBar

	captureProgressFill = Instance.new("Frame")
	captureProgressFill.Name = "CaptureProgressFill"
	captureProgressFill.Size = UDim2.fromOffset(0, 3)
	captureProgressFill.Position = UDim2.new(0, 0, 1, -3)
	captureProgressFill.BackgroundColor3 = RAIDER_COLOR
	captureProgressFill.Visible = false
	captureProgressFill.ZIndex = 3
	captureProgressFill.Parent = captureBar
	newCorner(2).Parent = captureProgressFill

	gui.Parent = parent
	isReady = true
end

function MataroLayout.setVisible(visible: boolean): ()
	if not isReady then
		return
	end
	if visible then
		if disableTask then
			task.cancel(disableTask)
			disableTask = nil
		end
		gui.Enabled = true
		if slideTween then
			slideTween:Cancel()
		end
		slideTween = TweenService:Create(container, SLIDE_IN_TWEEN, {
			Position = UDim2.new(0.5, CONTAINER_X_OFFSET, 0, TOP_OFFSET),
		})
		slideTween:Play()
	else
		if slideTween then
			slideTween:Cancel()
		end
		slideTween = TweenService:Create(container, SLIDE_OUT_TWEEN, {
			Position = UDim2.new(0.5, CONTAINER_X_OFFSET, 0, HIDDEN_Y),
		})
		slideTween:Play()
		if disableTask then
			task.cancel(disableTask)
		end
		disableTask = task.delay(DISABLE_DELAY, function()
			disableTask = nil
			gui.Enabled = false
		end)
	end
end

function MataroLayout.setPhaseState(phase: number, official: boolean): ()
	if not isReady then
		return
	end
	phaseLabel.Text = if phase <= 0 then "STANDBY" else "PHASE " .. tostring(phase)
	officialLabel.Text = if official then "OFFICIAL" else "UNOFFICIAL"
	phaseBottomLabel.Text = if phase <= 0 then "" else "P" .. tostring(phase)
end

function MataroLayout.setElapsedTime(seconds: number): ()
	if not isReady then
		return
	end
	if stateOvertime then
		return
	end
	local s = math.floor(seconds)
	if s == lastElapsedSec then
		return
	end
	lastElapsedSec = s
	elapsedLabel.Text = formatTime(s)
end

function MataroLayout.setOvertime(active: boolean): ()
	if not isReady then
		return
	end
	stateOvertime = active
	if active then
		lastElapsedSec = -1
		elapsedLabel.Text = "OVERTIME"
		elapsedLabel.TextColor3 = Color3.fromRGB(255, 180, 60)
	else
		elapsedLabel.TextColor3 = Theme.Foreground.Secondary
	end
end

function MataroLayout.setTermTimeRemaining(seconds: number): ()
	if not isReady then
		return
	end
	local s = math.floor(seconds)
	if s == lastTermSec then
		return
	end
	lastTermSec = s
	timeLabel.Text = formatTime(s)
end

function MataroLayout.setTermProgress(progress: number): ()
	if not isReady then
		return
	end
	stateTermProgress = progress
	if stateConquestActive then
		updateMainBarFill()
	end
end

function MataroLayout.setOwner(owner: PhaseOwner): ()
	if not isReady then
		return
	end
	stateOwner = owner
	scheduleCaptureUpdate()
	updateMainBarColor()
end

function MataroLayout.setCaptureState(progress: number, team: PhaseOwner): ()
	if not isReady then
		return
	end
	stateCaptureProgress = progress
	stateCaptureTeam = team
	scheduleCaptureUpdate()
end

function MataroLayout.setPayloadProgress(progress: number, team: PhaseOwner): ()
	if not isReady then
		return
	end
	statePayloadProgress = progress
	statePayloadControlTeam = team
	if not stateConquestActive then
		updateMainBarFill()
	end
	updateMainBarColor()
end

function MataroLayout.setConquestActive(active: boolean): ()
	if not isReady then
		return
	end
	stateConquestActive = active
	local targetHeight = if active then CONTAINER_HEIGHT else ESCORT_CONTAINER_HEIGHT
	if heightTween then
		heightTween:Cancel()
	end
	heightTween = TweenService:Create(container, HEIGHT_TWEEN, {
		Size = UDim2.fromOffset(TOTAL_WIDTH + STROKE_PAD * 2, targetHeight),
	})
	heightTween:Play()
	captureBar.Visible = active
	lastBarPct = -1
	updateMainBarFill()
	updateMainBarColor()
end

function MataroLayout.resetPhaseData(): ()
	if not isReady then
		return
	end
	stateCaptureProgress = 0
	stateCaptureTeam = nil
	statePayloadProgress = 0
	statePayloadControlTeam = nil
	updateCaptureBar()
	updateMainBarFill()
	updateMainBarColor()
end

function MataroLayout.destroy(): ()
	isReady = false
	if disableTask then
		task.cancel(disableTask)
		disableTask = nil
	end
	if slideTween then
		slideTween:Cancel()
		slideTween = nil
	end
	if fillTween then
		fillTween:Cancel()
		fillTween = nil
	end
	if defCaptureTween then
		defCaptureTween:Cancel()
		defCaptureTween = nil
	end
	if raidCaptureTween then
		raidCaptureTween:Cancel()
		raidCaptureTween = nil
	end
	if captureProgressTween then
		captureProgressTween:Cancel()
		captureProgressTween = nil
	end
	if heightTween then
		heightTween:Cancel()
		heightTween = nil
	end
	if gui then
		gui:Destroy()
	end
	lastElapsedSec = -1
	lastTermSec = -1
	lastBarPct = -1
	stateConquestActive = true
	statePayloadControlTeam = nil
	stateOwner = nil
	stateCaptureProgress = 0
	stateCaptureTeam = nil
	stateTermProgress = 0
	statePayloadProgress = 0
	stateOvertime = false
end

return MataroLayout
