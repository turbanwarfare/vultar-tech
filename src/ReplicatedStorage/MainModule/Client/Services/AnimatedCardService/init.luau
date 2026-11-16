--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local AnimatedCardService = {}
AnimatedCardService.Name = "AnimatedCardService"

local isInitialized = false
local activeTweens: { [Frame]: Tween } = {}
local containerToUserId: { [Frame]: number } = {}
local userAnimationStartTime: { [number]: number } = {}
local tweenCount = 0

local CYCLE_DURATION = 12.5

local tweenInfo = TweenInfo.new(CYCLE_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 0)

local function calculateCurrentPosition(userId: number): number
	local startTime = userAnimationStartTime[userId]
	if not startTime then
		return 0
	end

	local elapsed = (os.clock() - startTime) % CYCLE_DURATION
	local progress = elapsed / CYCLE_DURATION
	return -progress
end
local targetPosition = { Position = UDim2.fromScale(-1, 0) }

function AnimatedCardService:RegisterContainer(container: Frame, userId: number?): ()
	if activeTweens[container] then
		return
	end

	local scrollingFrame = container:FindFirstChild("ScrollingFrame") :: Frame?
	if not scrollingFrame then
		return
	end

	local startX = 0
	if userId then
		containerToUserId[container] = userId

		if userAnimationStartTime[userId] then
			startX = calculateCurrentPosition(userId)
		else
			userAnimationStartTime[userId] = os.clock()
		end
	end

	scrollingFrame.Position = UDim2.fromScale(startX, 0)

	local adjustedTweenInfo = TweenInfo.new(
		CYCLE_DURATION * (1 + startX),
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.In,
		0,
		false,
		0
	)

	local initialTween = TweenService:Create(scrollingFrame, adjustedTweenInfo, targetPosition)

	local function startInfiniteLoop()
		scrollingFrame.Position = UDim2.fromOffset(0, 0)
		local loopTween = TweenService:Create(scrollingFrame, tweenInfo, targetPosition)
		loopTween:Play()
		activeTweens[container] = loopTween
	end

	initialTween.Completed:Once(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed and activeTweens[container] then
			startInfiniteLoop()
		end
	end)

	initialTween:Play()
	activeTweens[container] = initialTween
	tweenCount += 1
end

function AnimatedCardService:UnregisterContainer(container: Frame): ()
	local tween = activeTweens[container]
	if not tween then
		return
	end

	tween:Cancel()
	activeTweens[container] = nil
	containerToUserId[container] = nil
	tweenCount -= 1
end

function AnimatedCardService:GetContainerCount(): number
	return tweenCount
end

function AnimatedCardService:IsRunning(): boolean
	return tweenCount > 0
end

function AnimatedCardService:IsAnimated(cardId: string): boolean
	return cardId:find("_Animated") ~= nil
end

function AnimatedCardService:ClearUserAnimation(userId: number): ()
	userAnimationStartTime[userId] = nil
end

function AnimatedCardService:init(): ()
	isInitialized = true
end

function AnimatedCardService:start(): ()
	if not isInitialized then
		self:init()
	end
end

function AnimatedCardService:Cleanup(): ()
	for _, tween in activeTweens do
		tween:Cancel()
	end
	table.clear(activeTweens)
	table.clear(containerToUserId)
	table.clear(userAnimationStartTime)
	tweenCount = 0
	isInitialized = false
end

return AnimatedCardService
