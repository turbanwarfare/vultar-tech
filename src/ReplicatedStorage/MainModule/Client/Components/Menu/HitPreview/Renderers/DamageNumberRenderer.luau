--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local Constants = require(script.Parent.Parent.Constants)
local SettingsHelper = require(script.Parent.Parent.Utils.SettingsHelper)
local ViewportMath = require(script.Parent.Parent.Utils.ViewportMath)
local FeedbackPools = require(script.Parent.Parent.Parent.Parent.Parent.Services.GunService.Feedback.FeedbackPools)

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

export type StackState = {
	label: TextLabel,
	stroke: UIStroke?,
	accumulatedDamage: number,
	isVisible: boolean,
	popTween: Tween?,
	fadeTween: Tween?,
	fadeThread: thread?,
}

export type DamageNumberState = {
	expandIndicators: { CursorExpandData },
	expandCount: number,
	expandSide: number,
	stack: StackState,
	rng: Random,
	neverResetDamage: boolean?,
}

local DamageNumberRenderer = {}

function DamageNumberRenderer.createDamageLabel(textSize: number, color: Color3, parent: Frame): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "DamageNumber"
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextSize = textSize
	label.Font = SettingsHelper.getDamageFont()
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Size = UDim2.fromOffset(100, 50)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.TextTransparency = 0
	label.ZIndex = 8
	label.Parent = parent

	local outline = Instance.new("UIStroke")
	outline.Name = "Outline"
	outline.Color = Color3.fromRGB(15, 15, 15)
	outline.Thickness = SettingsHelper.getSetting("DamageIndicatorOutline") or 1.5
	outline.Transparency = 0
	outline.Parent = label

	return label
end

function DamageNumberRenderer.createStackLabel(parent: Frame): (TextLabel, UIStroke)
	local label = Instance.new("TextLabel")
	label.Name = "StackDamage"
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 1
	label.Font = SettingsHelper.getDamageFont()
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Size = UDim2.fromOffset(100, 50)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.TextTransparency = 1
	label.Visible = false
	label.ZIndex = 9
	label.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.Color = Color3.fromRGB(15, 15, 15)
	stroke.Thickness = SettingsHelper.getSetting("DamageIndicatorOutline") or 1.5
	stroke.Transparency = 1
	stroke.Parent = label

	return label, stroke
end

function DamageNumberRenderer.createState(parent: Frame, neverResetDamage: boolean?): DamageNumberState
	local stackLabel, stackStroke = DamageNumberRenderer.createStackLabel(parent)

	return {
		expandIndicators = {},
		expandCount = 0,
		expandSide = 1,
		stack = {
			label = stackLabel,
			stroke = stackStroke,
			accumulatedDamage = 0,
			isVisible = false,
			popTween = nil,
			fadeTween = nil,
			fadeThread = nil,
		},
		rng = Random.new(),
		neverResetDamage = neverResetDamage,
	}
end

function DamageNumberRenderer.showExpand(
	state: DamageNumberState,
	parent: Frame,
	overlayPos: Vector2,
	damage: number,
	isHeadshot: boolean,
	useWideSpread: boolean?
): ()
	local textSize = SettingsHelper.getSetting("DamageIndicatorSize") or 18
	local color = SettingsHelper.getDamageColor(isHeadshot)

	state.expandSide = -state.expandSide
	local side = state.expandSide

	local spreadOffset = if useWideSpread then Constants.PLAYER_EXPAND_SPREAD else Constants.CURSOR_EXPAND_OFFSET
	local startX = overlayPos.X + side * spreadOffset
	local startY = overlayPos.Y + state.rng:NextNumber(-8, 8)

	local label = FeedbackPools.getLabel(1, color)
	label.Font = SettingsHelper.getDamageFont()
	label.Parent = parent
	label.Text = tostring(damage)
	label.Position = UDim2.fromOffset(startX, startY)

	local baseSpeed = if useWideSpread then Constants.CURSOR_EXPAND_SPEED * 1.3 else Constants.CURSOR_EXPAND_SPEED
	local velocityX = side * (baseSpeed + state.rng:NextNumber(-30, 30))
	local velocityY = state.rng:NextNumber(-25, 25)

	state.expandCount += 1
	state.expandIndicators[state.expandCount] = {
		label = label,
		stroke = label:FindFirstChild("Outline") :: UIStroke?,
		startX = startX,
		startY = startY,
		velocityX = velocityX,
		velocityY = velocityY,
		textSize = textSize,
		startTime = os.clock(),
	}
end

function DamageNumberRenderer.showStack(state: DamageNumberState, overlayPos: Vector2, damage: number, isHeadshot: boolean, isDestroyed: () -> boolean): ()
	local stackState = state.stack
	local label = stackState.label
	if not label then
		return
	end

	local wasVisible = stackState.isVisible
	local textSize = SettingsHelper.getSetting("DamageIndicatorSize") or 18
	local color = SettingsHelper.getDamageColor(isHeadshot)

	label.Font = SettingsHelper.getDamageFont()

	if not wasVisible and not state.neverResetDamage then
		stackState.accumulatedDamage = 0
	end

	stackState.accumulatedDamage += damage

	label.Text = tostring(stackState.accumulatedDamage)
	label.TextColor3 = color

	if stackState.fadeTween then
		stackState.fadeTween:Cancel()
		stackState.fadeTween = nil
	end
	if stackState.fadeThread then
		task.cancel(stackState.fadeThread)
		stackState.fadeThread = nil
	end
	if stackState.popTween then
		stackState.popTween:Cancel()
		stackState.popTween = nil
	end

	if not wasVisible then
		stackState.isVisible = true
		label.TextSize = 0
		label.TextTransparency = 0
		label.Visible = true
		label.Position = UDim2.fromOffset(overlayPos.X + Constants.STACK_OFFSET_X, overlayPos.Y + Constants.STACK_OFFSET_Y)

		if stackState.stroke then
			stackState.stroke.Thickness = SettingsHelper.getSetting("DamageIndicatorOutline") or 1.5
			stackState.stroke.Transparency = 0
		end

		local overshootSize = math.floor(textSize * Constants.STACK_OVERSHOOT_SCALE)
		stackState.popTween = TweenService:Create(label, Constants.TWEEN_STACK_POP, { TextSize = overshootSize })
		local settleTween = TweenService:Create(label, Constants.TWEEN_STACK_SETTLE, { TextSize = textSize })
		stackState.popTween.Completed:Once(function()
			settleTween:Play()
		end)
		stackState.popTween:Play()
	else
		local pulseSize = math.floor(textSize * Constants.STACK_OVERSHOOT_SCALE)
		local pulseUp = TweenService:Create(label, Constants.TWEEN_STACK_PULSE_UP, { TextSize = pulseSize })
		local pulseDown = TweenService:Create(label, Constants.TWEEN_STACK_PULSE_DOWN, { TextSize = textSize })
		pulseUp.Completed:Once(function()
			pulseDown:Play()
		end)
		pulseUp:Play()
	end

	stackState.fadeThread = task.delay(Constants.STACK_TIMEOUT, function()
		if isDestroyed() or not label then
			return
		end

		local shrinkTween = TweenService:Create(label, Constants.TWEEN_STACK_SHRINK, { TextSize = 0, TextTransparency = 1 })
		if stackState.stroke then
			TweenService:Create(stackState.stroke, Constants.TWEEN_STACK_SHRINK, { Transparency = 1 }):Play()
		end
		shrinkTween:Play()
		shrinkTween.Completed:Once(function()
			if isDestroyed() or not label then
				return
			end
			label.Visible = false
			stackState.isVisible = false
		end)
	end)
end

function DamageNumberRenderer.showDamageNumber(
	state: DamageNumberState,
	parent: Frame,
	overlayPos: Vector2,
	damage: number,
	isHeadshot: boolean,
	viewport: ViewportFrame,
	npcModel: Model,
	camera: Camera,
	isDestroyed: () -> boolean
): ()
	if not SettingsHelper.getSetting("DamageIndicators") then
		return
	end

	local indicatorType = SettingsHelper.getSetting("DamageIndicatorType") or 1
	local stickTo = SettingsHelper.getSetting("DamageIndicatorStickTo") or 2

	local displayPos = overlayPos
	local useWideSpread = false

	if stickTo == 1 then
		local viewportSize = viewport.AbsoluteSize
		if indicatorType == 2 then
			local headScreenPos = ViewportMath.getNpcHeadScreenPos(npcModel, camera, viewport, Constants.PLAYER_STACK_ABOVE_HEAD)
			if headScreenPos then
				displayPos =
					Vector2.new(headScreenPos.X - Constants.STACK_OFFSET_X + Constants.PLAYER_STACK_RIGHT_OFFSET, headScreenPos.Y - Constants.STACK_OFFSET_Y)
			else
				displayPos = Vector2.new(viewportSize.X / 2 - Constants.STACK_OFFSET_X + Constants.PLAYER_STACK_RIGHT_OFFSET, viewportSize.Y * 0.25)
			end
		else
			displayPos = Vector2.new(viewportSize.X / 2, overlayPos.Y)
			useWideSpread = true
		end
	end

	if indicatorType == 2 then
		DamageNumberRenderer.showStack(state, displayPos, damage, isHeadshot, isDestroyed)
	else
		DamageNumberRenderer.showExpand(state, parent, displayPos, damage, isHeadshot, useWideSpread)
	end
end

function DamageNumberRenderer.updateExpand(state: DamageNumberState): ()
	local now = os.clock()
	local i = 1

	local popDuration = Constants.EXPAND_POP_DURATION
	local settleDuration = Constants.EXPAND_SETTLE_DURATION
	local growEnd = popDuration + settleDuration
	local overshootScale = Constants.EXPAND_OVERSHOOT_SCALE

	while i <= state.expandCount do
		local data = state.expandIndicators[i]
		local elapsed = now - data.startTime
		local t = elapsed / Constants.CURSOR_EXPAND_DURATION

		if t >= 1 then
			FeedbackPools.returnLabel(data.label)
			state.expandIndicators[i] = state.expandIndicators[state.expandCount]
			state.expandIndicators[state.expandCount] = nil :: any
			state.expandCount -= 1
		else
			local newX = data.startX + data.velocityX * elapsed
			local newY = data.startY + data.velocityY * elapsed - Constants.CURSOR_EXPAND_GRAVITY * elapsed
			data.label.Position = UDim2.fromOffset(newX, newY)

			local textSize = data.textSize
			local currentSize: number

			if elapsed < popDuration then
				local popT = elapsed / popDuration
				local eased = 1 - (1 - popT) ^ 3
				local overshoot = 1 + 0.3 * math.sin(popT * math.pi)
				currentSize = textSize * overshootScale * eased * overshoot
			elseif elapsed < growEnd then
				local settleT = (elapsed - popDuration) / settleDuration
				local eased = 1 - (1 - settleT) * (1 - settleT)
				currentSize = textSize * overshootScale + (textSize - textSize * overshootScale) * eased
			elseif t < Constants.CURSOR_EXPAND_FADE_START then
				currentSize = textSize
			else
				local fadeProgress = (t - Constants.CURSOR_EXPAND_FADE_START) / (1 - Constants.CURSOR_EXPAND_FADE_START)
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
end

function DamageNumberRenderer.updateStackPosition(state: DamageNumberState, overlayPos: Vector2, viewport: ViewportFrame, npcModel: Model, camera: Camera): ()
	local stackState = state.stack
	if not stackState.isVisible or not stackState.label then
		return
	end

	local stickTo = SettingsHelper.getSetting("DamageIndicatorStickTo") or 2
	local stackPos = overlayPos

	if stickTo == 1 then
		local headScreenPos = ViewportMath.getNpcHeadScreenPos(npcModel, camera, viewport, Constants.PLAYER_STACK_ABOVE_HEAD)
		if headScreenPos then
			stackPos = Vector2.new(headScreenPos.X - Constants.STACK_OFFSET_X + Constants.PLAYER_STACK_RIGHT_OFFSET, headScreenPos.Y - Constants.STACK_OFFSET_Y)
		else
			local viewportSize = viewport.AbsoluteSize
			stackPos = Vector2.new(viewportSize.X / 2 - Constants.STACK_OFFSET_X + Constants.PLAYER_STACK_RIGHT_OFFSET, viewportSize.Y * 0.25)
		end
	end

	stackState.label.Position = UDim2.fromOffset(stackPos.X + Constants.STACK_OFFSET_X, stackPos.Y + Constants.STACK_OFFSET_Y)
end

function DamageNumberRenderer.cleanup(state: DamageNumberState): ()
	local stackState = state.stack

	if stackState.fadeThread then
		task.cancel(stackState.fadeThread)
		stackState.fadeThread = nil
	end
	if stackState.popTween then
		stackState.popTween:Cancel()
		stackState.popTween = nil
	end
	if stackState.fadeTween then
		stackState.fadeTween:Cancel()
		stackState.fadeTween = nil
	end

	for i = 1, state.expandCount do
		local data = state.expandIndicators[i]
		if data and data.label then
			data.label:Destroy()
		end
	end
	table.clear(state.expandIndicators)
	state.expandCount = 0
end

return DamageNumberRenderer
