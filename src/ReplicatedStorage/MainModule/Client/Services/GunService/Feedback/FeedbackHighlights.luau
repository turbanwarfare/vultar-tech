--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local ObjectPool = require(MainModule.Shared.Utils.State.ObjectPool)
local Theme = require(MainModule.Shared.UI.Theme)

local Cache = require(script.Parent.Parent.Cache)

local FeedbackHighlights = {}

local BODY_PARTS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local HEAL_COLOR_INDEX = 4
local MAX_POOL_SIZE = 100
local PREWARM_COUNT = 20
local DEBOUNCE_TIME = 0.08
local RECENT_PARTS_TTL = 1

local selectionBoxPool: ObjectPool.ObjectPool<SelectionBox>? = nil
local activeTweens: { [SelectionBox]: Tween } = {}
local activeDelayThreads: { [SelectionBox]: thread } = {}
local reusableGoal: { Transparency: number } = { Transparency = 0 }
local recentParts: { [BasePart]: number } = {}
local recentPartsCleanupThread: thread? = nil
local isCleanedUp = false

local cachedTweenInfos: { [number]: TweenInfo } = {}

local function getTweenInfo(duration: number): TweenInfo
	local key = math.floor(duration * 100)
	local cached = cachedTweenInfos[key]
	if cached then
		return cached
	end
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	cachedTweenInfos[key] = info
	return info
end

local function createSelectionBox(): SelectionBox
	local box = Instance.new("SelectionBox")
	box.SurfaceTransparency = 1
	box.Transparency = 1
	return box
end

local function resetSelectionBox(box: SelectionBox): ()
	box.Adornee = nil
	box.Transparency = 1
	box.Parent = nil
end

local function destroySelectionBox(box: SelectionBox): ()
	box:Destroy()
end

local function returnHighlight(box: SelectionBox): ()
	if isCleanedUp then return end
	if not activeTweens[box] and not activeDelayThreads[box] then return end

	local tween = activeTweens[box]
	if tween then
		tween:Cancel()
		activeTweens[box] = nil
	end
	activeDelayThreads[box] = nil

	if selectionBoxPool then
		selectionBoxPool:returnToPool(box)
	end
end

local function ensureRecentPartsCleanup(): ()
	if recentPartsCleanupThread then return end
	recentPartsCleanupThread = task.spawn(function()
		while not isCleanedUp do
			task.wait(RECENT_PARTS_TTL)
			local now = os.clock()
			for part, timestamp in recentParts do
				if now - timestamp > RECENT_PARTS_TTL then
					recentParts[part] = nil
				end
			end
			if not next(recentParts) then
				recentPartsCleanupThread = nil
				return
			end
		end
	end)
end

local function getColor(colorIndex: number): Color3
	local colors = Theme.HighlightColors
	if colorIndex >= 1 and colorIndex <= #colors then
		return colors[colorIndex]
	end
	return colors[1]
end

local function isPartValid(part: BasePart): boolean
	return part and part.Parent ~= nil
end

local function shouldDebounce(part: BasePart): boolean
	local now = os.clock()
	local lastTime = recentParts[part]
	if lastTime and (now - lastTime) < DEBOUNCE_TIME then
		return true
	end
	recentParts[part] = now
	ensureRecentPartsCleanup()
	return false
end

local function showHighlight(part: BasePart, color: Color3, transparency: number, thickness: number, fadeIn: number, duration: number): ()
	if not isPartValid(part) then return end
	if shouldDebounce(part) then return end
	if not selectionBoxPool then return end

	local box = selectionBoxPool:get()
	box.Color3 = color
	box.SurfaceColor3 = color
	box.SurfaceTransparency = 1
	box.Transparency = 1
	box.LineThickness = thickness
	box.Adornee = part
	box.Parent = part

	local tweenInfo = getTweenInfo(fadeIn)
	reusableGoal.Transparency = transparency
	local tween = TweenService:Create(box, tweenInfo, reusableGoal)
	tween:Play()

	activeTweens[box] = tween
	activeDelayThreads[box] = task.delay(fadeIn + duration, returnHighlight, box)
end

function FeedbackHighlights.showDamage(hitPart: BasePart, isHead: boolean): ()
	if not Cache.getHitHighlightsEnabled() then return end

	local colorIndex = isHead and Cache.getHitHighlightHeadColor() or Cache.getHitHighlightBodyColor()
	local color = getColor(colorIndex)
	local transparency = Cache.getHitHighlightTransparency()
	local thickness = Cache.getHitHighlightThickness()
	local fadeIn = Cache.getHitHighlightFadeIn()
	local duration = Cache.getHitHighlightDuration()

	showHighlight(hitPart, color, transparency, thickness, fadeIn, duration)
end

function FeedbackHighlights.showHeal(hitPart: BasePart): ()
	if not Cache.getHealHighlightsEnabled() then return end
	if not isPartValid(hitPart) then return end

	local character = hitPart.Parent
	if not character or not character:IsA("Model") then return end

	local color = getColor(HEAL_COLOR_INDEX)
	local transparency = Cache.getHealHighlightTransparency()
	local thickness = Cache.getHitHighlightThickness()
	local fadeIn = Cache.getHitHighlightFadeIn()
	local duration = Cache.getHitHighlightDuration()

	for _, partName in BODY_PARTS do
		local bodyPart = character:FindFirstChild(partName)
		if bodyPart and bodyPart:IsA("BasePart") then
			showHighlight(bodyPart, color, transparency, thickness, fadeIn, duration)
		end
	end
end

function FeedbackHighlights.init(): ()
	if selectionBoxPool then return end
	isCleanedUp = false

	selectionBoxPool = ObjectPool.new({
		factory = createSelectionBox,
		maxSize = MAX_POOL_SIZE,
		onReset = resetSelectionBox,
		onDestroy = destroySelectionBox,
	})

	selectionBoxPool:preWarm(PREWARM_COUNT)
end

function FeedbackHighlights.cleanup(): ()
	isCleanedUp = true

	if recentPartsCleanupThread then
		task.cancel(recentPartsCleanupThread)
		recentPartsCleanupThread = nil
	end

	for box, tween in activeTweens do
		tween:Cancel()
		box:Destroy()
	end
	table.clear(activeTweens)
	for _, thread in activeDelayThreads do
		task.cancel(thread)
	end
	table.clear(activeDelayThreads)

	if selectionBoxPool then
		selectionBoxPool:clear()
		selectionBoxPool = nil
	end

	table.clear(recentParts)
	table.clear(cachedTweenInfos)
end

return FeedbackHighlights
