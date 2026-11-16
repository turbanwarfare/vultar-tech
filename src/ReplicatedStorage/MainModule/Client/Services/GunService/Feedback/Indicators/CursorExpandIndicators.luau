--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Constants = require(script.Parent.Parent.Parent.Constants)
local Cache = require(script.Parent.Parent.Parent.Cache)

local DAMAGE_NORMAL_COLOR = Constants.Colors.DamageNormal
local DAMAGE_HEAD_COLOR = Constants.Colors.DamageHead

local CURSOR_EXPAND_DURATION = 0.85
local CURSOR_EXPAND_SPEED = 160
local CURSOR_EXPAND_FADE_START = 0.6
local CURSOR_EXPAND_OFFSET = 45

local POP_DURATION = 0.11
local SETTLE_DURATION = 0.055
local GROW_END = POP_DURATION + SETTLE_DURATION
local OVERSHOOT_SCALE = 1.15

export type CursorExpandData = {
	label: TextLabel,
	stroke: UIStroke?,
	startX: number,
	startY: number,
	velocityX: number,
	velocityY: number,
	textSize: number,
	startTime: number,
}

local CursorExpandIndicators = {}

local cursorExpandIndicators: { CursorExpandData } = {}
local cursorExpandCount: number = 0
local cursorDataPool: { CursorExpandData } = {}
local cursorDataPoolSize: number = 0
local MAX_CURSOR_DATA_POOL = 30

local function acquireCursorData(): CursorExpandData
	if cursorDataPoolSize > 0 then
		local data = cursorDataPool[cursorDataPoolSize]
		cursorDataPool[cursorDataPoolSize] = nil :: any
		cursorDataPoolSize -= 1
		return data
	end
	return { label = nil :: any, stroke = nil, startX = 0, startY = 0, velocityX = 0, velocityY = 0, textSize = 0, startTime = 0 }
end

local function releaseCursorData(data: CursorExpandData): ()
	if cursorDataPoolSize >= MAX_CURSOR_DATA_POOL then return end
	cursorDataPoolSize += 1
	cursorDataPool[cursorDataPoolSize] = data
end
local cursorExpandConnection: RBXScriptConnection? = nil
local cursorExpandContainer: Frame? = nil
local cursorExpandSide: number = 1
local rng = Random.new()

local labelPool: { TextLabel } = {}
local labelPoolSize: number = 0
local POOL_MAX_SIZE = 30

local function ensureCursorExpandContainer(): Frame?
	if cursorExpandContainer and cursorExpandContainer.Parent then
		return cursorExpandContainer
	end

	local player = Players.LocalPlayer
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end

	local screenGui = playerGui:FindFirstChild("CursorExpandGui") :: ScreenGui?
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "CursorExpandGui"
		assert(screenGui).AutoLocalize = false
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.DisplayOrder = 100
		screenGui.Parent = playerGui
	end

	local container = screenGui:FindFirstChild("Container") :: Frame?
	if not container then
		container = Instance.new("Frame")
		container.Name = "Container"
		container.Size = UDim2.fromScale(1, 1)
		container.BackgroundTransparency = 1
		container.Parent = screenGui
	end

	cursorExpandContainer = container
	return container
end

local function createCursorExpandLabel(): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "CursorExpand"
	label.BackgroundTransparency = 1
	label.Font = Cache.getDamageIndicatorFont()
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Size = UDim2.fromOffset(100, 50)
	label.AnchorPoint = Vector2.new(0.5, 0.5)

	local outline = Instance.new("UIStroke")
	outline.Name = "Outline"
	outline.Color = Constants.Colors.Stroke
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	outline.Parent = label

	return label
end

local function getLabelFromPool(textSize: number, color: Color3): TextLabel
	local label: TextLabel
	if labelPoolSize > 0 then
		label = labelPool[labelPoolSize]
		labelPool[labelPoolSize] = nil :: any
		labelPoolSize -= 1
	else
		label = createCursorExpandLabel()
	end

	label.Font = Cache.getDamageIndicatorFont()
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextTransparency = 0
	label.Text = ""

	local outline = label:FindFirstChild("Outline") :: UIStroke?
	if outline then
		outline.Thickness = Cache.getDamageIndicatorOutline()
		outline.Transparency = 0
	end

	return label
end

local function returnLabelToPool(label: TextLabel): ()
	label.Parent = nil
	if labelPoolSize < POOL_MAX_SIZE then
		labelPoolSize += 1
		labelPool[labelPoolSize] = label
	else
		label:Destroy()
	end
end

local function updateCursorExpandIndicators(_dt: number)
	debug.profilebegin("GunService::cursorExpand")
	local now = os.clock()
	local i = 1
	while i <= cursorExpandCount do
		local data = cursorExpandIndicators[i]
		local elapsed = now - data.startTime
		local t = elapsed / CURSOR_EXPAND_DURATION

		if t >= 1 then
			returnLabelToPool(data.label)
			releaseCursorData(data)
			cursorExpandIndicators[i] = cursorExpandIndicators[cursorExpandCount]
			cursorExpandIndicators[cursorExpandCount] = nil :: any
			cursorExpandCount -= 1
		else
			local newX = data.startX + data.velocityX * elapsed
			local newY = data.startY + data.velocityY * elapsed - 30 * elapsed
			data.label.Position = UDim2.fromOffset(newX, newY)

			local textSize = data.textSize
			local currentSize: number

			if elapsed < POP_DURATION then
				local popT = elapsed / POP_DURATION
				local eased = 1 - (1 - popT) ^ 3
				local overshoot = 1 + 0.3 * math.sin(popT * math.pi)
				currentSize = textSize * OVERSHOOT_SCALE * eased * overshoot
			elseif elapsed < GROW_END then
				local settleT = (elapsed - POP_DURATION) / SETTLE_DURATION
				local eased = 1 - (1 - settleT) * (1 - settleT)
				currentSize = textSize * OVERSHOOT_SCALE + (textSize - textSize * OVERSHOOT_SCALE) * eased
			elseif t < CURSOR_EXPAND_FADE_START then
				currentSize = textSize
			else
				local fadeProgress = (t - CURSOR_EXPAND_FADE_START) / (1 - CURSOR_EXPAND_FADE_START)
				local shrinkEased = fadeProgress * fadeProgress
				currentSize = textSize * (1 - shrinkEased)
				data.label.TextTransparency = shrinkEased
				if data.stroke then
					data.stroke.Transparency = shrinkEased
				end
			end

			data.label.TextSize = math.max(1, currentSize)
			i += 1
		end
	end

	if cursorExpandCount == 0 and cursorExpandConnection then
		cursorExpandConnection:Disconnect()
		cursorExpandConnection = nil
	end
	debug.profileend()
end

function CursorExpandIndicators.showExpandAtCursor(damage: number, isHead: boolean): ()
	local container = ensureCursorExpandContainer()
	if not container then
		return
	end

	local textSize = Cache.getDamageIndicatorSize()
	local color = isHead and DAMAGE_HEAD_COLOR or DAMAGE_NORMAL_COLOR

	local mousePos = UserInputService:GetMouseLocation()

	cursorExpandSide = -cursorExpandSide
	local side = cursorExpandSide

	local startX = mousePos.X + side * CURSOR_EXPAND_OFFSET
	local startY = mousePos.Y + rng:NextNumber(-8, 8)

	local label = getLabelFromPool(textSize, color)
	label.Text = tostring(damage)
	label.Position = UDim2.fromOffset(startX, startY)
	label.Parent = container

	local velocityX = side * (CURSOR_EXPAND_SPEED + rng:NextNumber(-30, 30))
	local velocityY = rng:NextNumber(-25, 25)

	cursorExpandCount += 1
	local data = acquireCursorData()
	data.label = label
	data.stroke = label:FindFirstChild("Outline") :: UIStroke?
	data.startX = startX
	data.startY = startY
	data.velocityX = velocityX
	data.velocityY = velocityY
	data.textSize = textSize
	data.startTime = os.clock()
	cursorExpandIndicators[cursorExpandCount] = data

	if not cursorExpandConnection then
		cursorExpandConnection = RunService.RenderStepped:Connect(updateCursorExpandIndicators)
	end
end

function CursorExpandIndicators.clearActive(): ()
	if cursorExpandConnection then
		cursorExpandConnection:Disconnect()
		cursorExpandConnection = nil
	end

	for i = 1, cursorExpandCount do
		local data = cursorExpandIndicators[i]
		if data then
			if data.label then
				returnLabelToPool(data.label)
			end
			releaseCursorData(data)
		end
		cursorExpandIndicators[i] = nil :: any
	end
	cursorExpandCount = 0
end

function CursorExpandIndicators.cleanup(): ()
	if cursorExpandConnection then
		cursorExpandConnection:Disconnect()
		cursorExpandConnection = nil
	end

	for i = 1, cursorExpandCount do
		local data = cursorExpandIndicators[i]
		if data then
			if data.label then
				data.label:Destroy()
			end
		end
		cursorExpandIndicators[i] = nil :: any
	end
	cursorExpandCount = 0
	table.clear(cursorDataPool)
	cursorDataPoolSize = 0

	for i = 1, labelPoolSize do
		local label = labelPool[i]
		if label then
			label:Destroy()
		end
		labelPool[i] = nil :: any
	end
	labelPoolSize = 0

	if cursorExpandContainer then
		local parent = cursorExpandContainer.Parent
		if parent then
			parent:Destroy()
		end
		cursorExpandContainer = nil
	end
end

return CursorExpandIndicators
