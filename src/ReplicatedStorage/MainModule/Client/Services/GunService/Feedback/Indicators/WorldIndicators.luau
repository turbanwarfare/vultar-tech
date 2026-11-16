--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")

local FeedbackPools = require(script.Parent.Parent.FeedbackPools)
local Constants = require(script.Parent.Parent.Parent.Constants)
local Cache = require(script.Parent.Parent.Parent.Cache)

export type IndicatorData = {
	billboard: BillboardGui,
	label: TextLabel,
	stroke: UIStroke?,
	anchor: Attachment,
	arcA: Vector3,
	arcB: Vector3,
	arcC: Vector3,
	textSize: number,
	startTime: number,
	lastWrittenSize: number,
}

local EXPAND_DURATION = Constants.Indicator.ExpandDuration
local EXPAND_FADE_START = Constants.Indicator.ExpandFadeStart
local DAMAGE_NORMAL_COLOR = Constants.Colors.DamageNormal
local DAMAGE_HEAD_COLOR = Constants.Colors.DamageHead
local HEAL_COLOR = Constants.Colors.Heal

local POP_DURATION = 0.11
local SETTLE_DURATION = 0.055
local GROW_END = POP_DURATION + SETTLE_DURATION
local OVERSHOOT_SCALE = 1.15

local MAX_ACTIVE_INDICATORS = 24

local WorldIndicators = {}

local activeIndicators: { IndicatorData } = {}
local indicatorCount: number = 0
local indicatorDataPool: { IndicatorData } = {}
local indicatorDataPoolSize: number = 0

local function acquireIndicatorData(): IndicatorData
	if indicatorDataPoolSize > 0 then
		local data = indicatorDataPool[indicatorDataPoolSize]
		indicatorDataPool[indicatorDataPoolSize] = nil :: any
		indicatorDataPoolSize -= 1
		return data
	end
	return {
		billboard = nil :: any,
		label = nil :: any,
		stroke = nil,
		anchor = nil :: any,
		arcA = Vector3.zero,
		arcB = Vector3.zero,
		arcC = Vector3.zero,
		textSize = 0,
		startTime = 0,
		lastWrittenSize = 0,
	}
end

local MAX_DATA_POOL = 32
local function releaseIndicatorData(data: IndicatorData): ()
	if indicatorDataPoolSize >= MAX_DATA_POOL then
		return
	end
	indicatorDataPoolSize += 1
	indicatorDataPool[indicatorDataPoolSize] = data
end

local indicatorConnection: RBXScriptConnection? = nil
local sideFlip: { [Model]: number } = {}
local currentCamera = workspace.CurrentCamera
local rng = Random.new()

local function nextSide(model: Model): number
	local s = sideFlip[model]
	if s == nil then
		s = if rng:NextNumber() > 0.5 then 1 else -1
	else
		s = -s
	end
	sideFlip[model] = s
	return s
end

local function updateIndicators()
	debug.profilebegin("GunService::worldIndicators")
	local now = os.clock()
	local i = 1
	while i <= indicatorCount do
		local data = activeIndicators[i]
		local elapsed = now - data.startTime
		local t = elapsed / EXPAND_DURATION

		if t >= 1 then
			FeedbackPools.returnBillboard(data.billboard)
			FeedbackPools.returnAttachment(data.anchor)
			releaseIndicatorData(data)
			activeIndicators[i] = activeIndicators[indicatorCount]
			activeIndicators[indicatorCount] = nil :: any
			indicatorCount -= 1
		else
			local easedT = 1 - (1 - t) * (1 - t) * (1 - t)
			local et2 = easedT * easedT
			data.billboard.StudsOffset = data.arcA + data.arcB * easedT + data.arcC * et2
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
			elseif t < EXPAND_FADE_START then
				currentSize = textSize
			else
				local fadeProgress = (t - EXPAND_FADE_START) / (1 - EXPAND_FADE_START)
				local shrinkEased = fadeProgress * fadeProgress
				currentSize = textSize * (1 - shrinkEased)
				data.label.TextTransparency = shrinkEased
				if data.stroke then
					data.stroke.Transparency = shrinkEased
				end
			end

			local snapped = math.max(1, currentSize)
			if snapped ~= data.lastWrittenSize then
				data.label.TextSize = snapped
				data.lastWrittenSize = snapped
			end

			i += 1
		end
	end

	if indicatorCount == 0 and indicatorConnection then
		indicatorConnection:Disconnect()
		indicatorConnection = nil
		table.clear(sideFlip)
	end
	debug.profileend()
end

local function createExpand(value: number, color: Color3, textSize: number, hitPos: Vector3, character: Model?, prefix: string?, font: Enum.Font?): ()
	local model = character or workspace

	if indicatorCount >= MAX_ACTIVE_INDICATORS then
		local evict = activeIndicators[1]
		FeedbackPools.returnBillboard(evict.billboard)
		FeedbackPools.returnAttachment(evict.anchor)
		releaseIndicatorData(evict)
		activeIndicators[1] = activeIndicators[indicatorCount]
		activeIndicators[indicatorCount] = nil :: any
		indicatorCount -= 1
	end

	local anchor = FeedbackPools.getAttachment()
	anchor.WorldPosition = hitPos
	anchor.Parent = workspace.Terrain

	local side = nextSide(model :: Model)

	local scale = 1
	if currentCamera then
		local distance = (currentCamera.CFrame.Position - hitPos).Magnitude
		scale = math.min(4, math.max(1, distance / 50))
	end

	local billboard = FeedbackPools.getBillboard()
	billboard.Size = UDim2.fromOffset(textSize * 8, textSize * 4)
	billboard.Adornee = anchor
	billboard.Parent = workspace.Terrain

	local label = FeedbackPools.getLabel(textSize, color, font)
	label.Text = (prefix or "") .. tostring(value)
	label.TextSize = 0
	label.TextTransparency = 0
	label.Parent = billboard

	local yBase = rng:NextNumber(-0.4, 0.4) * scale
	local zBase = rng:NextNumber(-0.1, 0.1) * scale
	local startX = side * rng:NextNumber(2.8, 3.5) * scale
	local controlX = side * rng:NextNumber(4.5, 5.5) * scale
	local endX = side * rng:NextNumber(6.0, 7.5) * scale
	local controlDip = rng:NextNumber(-0.1, 0.15) * scale
	local endRise = rng:NextNumber(0.5, 1.0) * scale

	local p0 = Vector3.new(startX, yBase, zBase)
	local p1 = Vector3.new(controlX, yBase + controlDip, zBase)
	local p2 = Vector3.new(endX, yBase + endRise, zBase)
	local arcA = p0
	local arcB = 2 * (p1 - p0)
	local arcC = p0 - 2 * p1 + p2

	billboard.StudsOffset = p0

	indicatorCount += 1
	local data = acquireIndicatorData()
	data.billboard = billboard
	data.label = label
	data.stroke = label:FindFirstChild("Outline") :: UIStroke?
	data.anchor = anchor
	data.arcA = arcA
	data.arcB = arcB
	data.arcC = arcC
	data.textSize = textSize
	data.startTime = os.clock()
	data.lastWrittenSize = 0
	activeIndicators[indicatorCount] = data

	if not indicatorConnection then
		indicatorConnection = RunService.RenderStepped:Connect(updateIndicators)
	end
end

function WorldIndicators.showExpand(damage: number, isHead: boolean, hitPart: BasePart?, character: Model?): ()
	local textSize = Cache.getDamageIndicatorSize()
	local color = isHead and DAMAGE_HEAD_COLOR or DAMAGE_NORMAL_COLOR

	local targetPos = Vector3.zero
	if hitPart and hitPart.Parent then
		targetPos = hitPart.Position
	elseif character then
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			targetPos = hrp.Position
		end
	end

	if targetPos == Vector3.zero then
		return
	end

	createExpand(damage, color, textSize, targetPos, character, nil, Cache.getDamageIndicatorFont())
end

function WorldIndicators.showHealExpand(healAmount: number, hitPos: Vector3, character: Model?): ()
	local textSize = Cache.getHealIndicatorSize()
	createExpand(healAmount, HEAL_COLOR, textSize, hitPos, character, "+", Cache.getHealIndicatorFont())
end

function WorldIndicators.clearActive(): ()
	if indicatorConnection then
		indicatorConnection:Disconnect()
		indicatorConnection = nil
	end

	for i = 1, indicatorCount do
		local data = activeIndicators[i]
		if data then
			FeedbackPools.returnBillboard(data.billboard)
			FeedbackPools.returnAttachment(data.anchor)
			releaseIndicatorData(data)
		end
		activeIndicators[i] = nil :: any
	end
	indicatorCount = 0
	table.clear(sideFlip)
end

function WorldIndicators.cleanup(): ()
	if indicatorConnection then
		indicatorConnection:Disconnect()
		indicatorConnection = nil
	end

	for i = 1, indicatorCount do
		local data = activeIndicators[i]
		if data then
			data.billboard:Destroy()
			data.anchor:Destroy()
		end
		activeIndicators[i] = nil :: any
	end
	indicatorCount = 0
	table.clear(sideFlip)
	table.clear(indicatorDataPool)
	indicatorDataPoolSize = 0
end

return WorldIndicators
