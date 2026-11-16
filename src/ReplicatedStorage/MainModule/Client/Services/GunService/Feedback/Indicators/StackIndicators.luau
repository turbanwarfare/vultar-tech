--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local FeedbackPools = require(script.Parent.Parent.FeedbackPools)
local Constants = require(script.Parent.Parent.Parent.Constants)
local Cache = require(script.Parent.Parent.Parent.Cache)

local DAMAGE_NORMAL_COLOR = Constants.Colors.DamageNormal
local DAMAGE_HEAD_COLOR = Constants.Colors.DamageHead
local HEAL_COLOR = Constants.Colors.Heal
local STACK_TIMEOUT = Constants.Indicator.StackTimeout

local POP_DURATION = 0.11
local SETTLE_DURATION = 0.055
local SHRINK_DURATION = 0.13
local OVERSHOOT_SCALE = 1.15

local KILL_FLASH_COLOR = Color3.fromRGB(255, 70, 70)
local KILL_SCALE = 1.25
local KILL_POP_DURATION = 0.08
local KILL_SETTLE_DURATION = 0.15
local KILL_COLOR_HOLD = 0.12

local TWEEN_POP_IN = TweenInfo.new(POP_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_POP_SETTLE = TweenInfo.new(SETTLE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_SHRINK = TweenInfo.new(SHRINK_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TWEEN_HEIGHT_SHIFT = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_KILL_POP = TweenInfo.new(KILL_POP_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_KILL_SETTLE = TweenInfo.new(KILL_SETTLE_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_KILL_COLOR_RESET = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local CURSOR_X_OFFSET = 8
local CURSOR_Y_OFFSET = 0

local PLAYER_X_OFFSET = 2.5

export type StackState = {
	billboard: BillboardGui,
	label: TextLabel,
	anchor: Attachment,
	value: number,
	timeout: thread?,
	generation: number,
	currentYOffset: number,
	heightTween: Tween?,
}

local StackIndicators = {}

local accumulatedDamage: number = 0
local cursorPopInTween: Tween? = nil
local cursorSettleTween: Tween? = nil
local cursorShrinkTween: Tween? = nil
local cursorFadeOutThread: thread? = nil
local cursorIsVisible: boolean = false
local cursorTrackConnection: RBXScriptConnection? = nil

local stackStates: { [Model]: StackState } = {}
local healStackStates: { [Model]: StackState } = {}

local getDamageLabelFn: (() -> TextLabel?)? = nil
local cursorGeneration: number = 0
local cursorStrokeFadeTween: Tween? = nil
local lastMouseX: number = 0
local lastMouseY: number = 0
local cursorBumpTween: Tween? = nil
local cursorBumpSettleTween: Tween? = nil

local TWEEN_BUMP = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_BUMP_SETTLE = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local goalPopIn = { TextSize = 0, TextTransparency = 0 }
local goalSettle = { TextSize = 0 }
local goalShrink = { TextSize = 0, TextTransparency = 1 }
local goalStrokeFade = { Transparency = 1 }
local goalBump = { TextSize = 0 }
local goalBumpSettle = { TextSize = 0 }
local goalCursorPopIn = { TextSize = 0 }
local goalCursorSettle = { TextSize = 0 }
local goalHeightShift = { WorldPosition = Vector3.zero }

local killPopTween: Tween? = nil
local killSettleTween: Tween? = nil
local killColorResetTween: Tween? = nil
local killResetThread: thread? = nil

local function updateCursorPosition()
	debug.profilebegin("GunService::stackIndicators")
	if getDamageLabelFn and cursorIsVisible then
		local damageLabel = getDamageLabelFn()
		if damageLabel then
			local mousePos = UserInputService:GetMouseLocation()
			local mx = mousePos.X
			local my = mousePos.Y
			if mx ~= lastMouseX or my ~= lastMouseY then
				lastMouseX = mx
				lastMouseY = my
				damageLabel.Position = UDim2.fromOffset(mx + CURSOR_X_OFFSET, my + CURSOR_Y_OFFSET)
			end
		end
	end
	debug.profileend()
end

function StackIndicators.setDamageLabelGetter(getter: () -> TextLabel?): ()
	getDamageLabelFn = getter
end

function StackIndicators.flashKillAtCursor(): ()
	if not getDamageLabelFn then
		return
	end

	local damageLabel = getDamageLabelFn()
	if not damageLabel or not cursorIsVisible then
		return
	end

	if killPopTween then
		killPopTween:Cancel()
	end
	if killSettleTween then
		killSettleTween:Cancel()
	end
	if killColorResetTween then
		killColorResetTween:Cancel()
	end
	if killResetThread then
		task.cancel(killResetThread)
	end

	local textSize = Cache.getDamageIndicatorSize()
	local targetSize = math.floor(textSize * KILL_SCALE)

	damageLabel.TextColor3 = KILL_FLASH_COLOR

	killPopTween = TweenService:Create(damageLabel, TWEEN_KILL_POP, { TextSize = targetSize })
	killSettleTween = TweenService:Create(damageLabel, TWEEN_KILL_SETTLE, { TextSize = textSize })
	killColorResetTween = TweenService:Create(damageLabel, TWEEN_KILL_COLOR_RESET, { TextColor3 = DAMAGE_NORMAL_COLOR })

	killPopTween:Play()
	killPopTween.Completed:Once(function()
		if killSettleTween then
			killSettleTween:Play()
		end
	end)

	killResetThread = task.delay(KILL_COLOR_HOLD, function()
		if killColorResetTween then
			killColorResetTween:Play()
		end
		killResetThread = nil
	end)
end

local function handleDamageStackTimeout(character: Model, gen: number): ()
	local s = stackStates[character]
	if not s or s.generation ~= gen then
		return
	end

	if s.heightTween then
		s.heightTween:Cancel()
		s.heightTween = nil
	end

	local stroke = s.label:FindFirstChild("Outline") :: UIStroke?
	if stroke then
		TweenService:Create(stroke, TWEEN_SHRINK, goalStrokeFade):Play()
	end

	goalShrink.TextSize = 0
	goalShrink.TextTransparency = 1
	local shrink = TweenService:Create(s.label, TWEEN_SHRINK, goalShrink)
	shrink:Play()
	shrink.Completed:Once(function()
		if stackStates[character] == s then
			stackStates[character] = nil
		end
		FeedbackPools.returnBillboard(s.billboard)
		if s.anchor then
			FeedbackPools.returnAttachment(s.anchor)
		end
	end)
end

function StackIndicators.showStackAtPlayer(damage: number, isHead: boolean, hitPart: BasePart?, character: Model, rootPartHint: BasePart?): ()
	local textSize = Cache.getDamageIndicatorSize()
	local color = isHead and DAMAGE_HEAD_COLOR or DAMAGE_NORMAL_COLOR
	local state = stackStates[character]

	local rootPart = rootPartHint or character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local targetYOffset = 0
	if hitPart and hitPart.Parent then
		local hitPartCenter = hitPart.Position
		local rootPartCenter = rootPart.Position
		targetYOffset = hitPartCenter.Y - rootPartCenter.Y
	end

	if not state or not state.billboard or not state.billboard.Parent then
		local anchor = FeedbackPools.getAttachment()
		local spawnPos = rootPart.Position + Vector3.new(PLAYER_X_OFFSET, targetYOffset, 0)
		anchor.WorldPosition = spawnPos
		anchor.Parent = workspace.Terrain

		local billboard = FeedbackPools.getBillboard()
		billboard.StudsOffset = Vector3.zero
		billboard.Size = UDim2.fromOffset(textSize * 6, textSize * 3)
		billboard.Adornee = anchor
		billboard.Parent = workspace

		local label = FeedbackPools.getLabel(textSize, color)
		label.Text = tostring(damage)
		label.TextTransparency = 1
		label.TextSize = 0
		label.Parent = billboard

		local overshootSize = math.floor(textSize * OVERSHOOT_SCALE)
		goalPopIn.TextSize = overshootSize
		goalPopIn.TextTransparency = 0
		local popTween = TweenService:Create(label, TWEEN_POP_IN, goalPopIn)
		goalSettle.TextSize = textSize
		local settleTween = TweenService:Create(label, TWEEN_POP_SETTLE, goalSettle)
		popTween.Completed:Once(function()
			settleTween:Play()
		end)
		popTween:Play()

		state = {
			billboard = billboard,
			label = label,
			anchor = anchor,
			value = damage,
			timeout = nil,
			generation = 1,
			currentYOffset = targetYOffset,
			heightTween = nil,
		}
		stackStates[character] = state
	else
		state.value += damage
		state.label.Text = tostring(state.value)
		state.label.TextColor3 = color
		state.generation += 1

		if math.abs(targetYOffset - state.currentYOffset) > 0.1 and state.anchor then
			if state.heightTween then
				state.heightTween:Cancel()
			end

			local currentAnchorPos = state.anchor.WorldPosition
			local newYPos = currentAnchorPos.Y + (targetYOffset - state.currentYOffset)
			state.currentYOffset = targetYOffset
			goalHeightShift.WorldPosition = Vector3.new(currentAnchorPos.X, newYPos, currentAnchorPos.Z)
			state.heightTween = TweenService:Create(state.anchor, TWEEN_HEIGHT_SHIFT, goalHeightShift)
			state.heightTween:Play()
		end

		if state.timeout then
			task.cancel(state.timeout)
		end
	end

	local gen = state.generation
	state.timeout = task.delay(STACK_TIMEOUT, handleDamageStackTimeout, character, gen)
end

function StackIndicators.showStackAtCursor(damage: number): ()
	if not getDamageLabelFn then
		return
	end
	local damageLabel = getDamageLabelFn()
	if not damageLabel then
		return
	end

	cursorGeneration += 1
	local gen = cursorGeneration

	local wasVisible = cursorIsVisible

	if not wasVisible then
		accumulatedDamage = 0
	end

	accumulatedDamage += damage

	local textSize = Cache.getDamageIndicatorSize()

	damageLabel.Text = tostring(accumulatedDamage)
	damageLabel.TextColor3 = DAMAGE_NORMAL_COLOR

	if cursorShrinkTween then
		cursorShrinkTween:Cancel()
		cursorShrinkTween = nil
	end
	if cursorFadeOutThread then
		task.cancel(cursorFadeOutThread)
		cursorFadeOutThread = nil
	end
	if cursorPopInTween then
		cursorPopInTween:Cancel()
		cursorPopInTween = nil
	end
	if cursorSettleTween then
		cursorSettleTween:Cancel()
		cursorSettleTween = nil
	end
	if cursorStrokeFadeTween then
		cursorStrokeFadeTween:Cancel()
		cursorStrokeFadeTween = nil
	end
	if cursorBumpTween then
		cursorBumpTween:Cancel()
		cursorBumpTween = nil
	end
	if cursorBumpSettleTween then
		cursorBumpSettleTween:Cancel()
		cursorBumpSettleTween = nil
	end

	local cursorStroke = damageLabel:FindFirstChild("Outline") :: UIStroke?

	if not wasVisible then
		cursorIsVisible = true
		damageLabel.TextSize = 0
		damageLabel.TextTransparency = 0

		if cursorStroke then
			cursorStroke.Thickness = Cache.getDamageIndicatorOutline()
			cursorStroke.Transparency = 0
		end

		local overshootSize = math.floor(textSize * OVERSHOOT_SCALE)
		goalCursorPopIn.TextSize = overshootSize
		cursorPopInTween = TweenService:Create(damageLabel, TWEEN_POP_IN, goalCursorPopIn)
		goalCursorSettle.TextSize = textSize
		cursorSettleTween = TweenService:Create(damageLabel, TWEEN_POP_SETTLE, goalCursorSettle)
		cursorPopInTween.Completed:Once(function()
			if cursorSettleTween then
				cursorSettleTween:Play()
			end
		end)
		cursorPopInTween:Play()
	else
		damageLabel.TextTransparency = 0

		if cursorStroke then
			cursorStroke.Transparency = 0
		end

		local bumpSize = math.floor(textSize * 1.12)
		goalBump.TextSize = bumpSize
		cursorBumpTween = TweenService:Create(damageLabel, TWEEN_BUMP, goalBump)
		goalBumpSettle.TextSize = textSize
		cursorBumpSettleTween = TweenService:Create(damageLabel, TWEEN_BUMP_SETTLE, goalBumpSettle)
		cursorBumpTween.Completed:Once(function()
			if cursorBumpSettleTween then
				cursorBumpSettleTween:Play()
			end
		end)
		cursorBumpTween:Play()
	end

	if not cursorTrackConnection then
		cursorTrackConnection = RunService.RenderStepped:Connect(updateCursorPosition)
	end

	cursorFadeOutThread = task.delay(1, function()
		if cursorGeneration ~= gen then
			return
		end

		local label = getDamageLabelFn and getDamageLabelFn()
		if not label then
			return
		end

		local stroke = label:FindFirstChild("Outline") :: UIStroke?

		cursorShrinkTween = TweenService:Create(label, TWEEN_SHRINK, goalShrink)
		if stroke then
			cursorStrokeFadeTween = TweenService:Create(stroke, TWEEN_SHRINK, goalStrokeFade)
			cursorStrokeFadeTween:Play()
		end
		cursorShrinkTween:Play()
		cursorShrinkTween.Completed:Once(function()
			if cursorGeneration ~= gen then
				return
			end

			local finalLabel = getDamageLabelFn and getDamageLabelFn()
			if finalLabel then
				finalLabel.TextTransparency = 1
			end
			cursorIsVisible = false
			if cursorTrackConnection then
				cursorTrackConnection:Disconnect()
				cursorTrackConnection = nil
			end
			cursorShrinkTween = nil
		end)
	end)
end

local function handleHealStackTimeout(character: Model, gen: number): ()
	local s = healStackStates[character]
	if not s or s.generation ~= gen then
		return
	end

	if s.heightTween then
		s.heightTween:Cancel()
		s.heightTween = nil
	end

	local stroke = s.label:FindFirstChild("Outline") :: UIStroke?
	if stroke then
		TweenService:Create(stroke, TWEEN_SHRINK, goalStrokeFade):Play()
	end

	goalShrink.TextSize = 0
	goalShrink.TextTransparency = 1
	local shrink = TweenService:Create(s.label, TWEEN_SHRINK, goalShrink)
	shrink:Play()
	shrink.Completed:Once(function()
		if healStackStates[character] == s then
			healStackStates[character] = nil
		end
		FeedbackPools.returnBillboard(s.billboard)
		if s.anchor then
			FeedbackPools.returnAttachment(s.anchor)
		end
	end)
end

function StackIndicators.showHealStackAtPlayer(healAmount: number, hitPart: BasePart?, character: Model, rootPartHint: BasePart?): ()
	local textSize = Cache.getHealIndicatorSize()
	local state = healStackStates[character]

	local rootPart = rootPartHint or character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local targetYOffset = 0
	if hitPart and hitPart.Parent then
		local hitPartCenter = hitPart.Position
		local rootPartCenter = rootPart.Position
		targetYOffset = hitPartCenter.Y - rootPartCenter.Y
	end

	if not state or not state.billboard or not state.billboard.Parent then
		local anchor = FeedbackPools.getAttachment()
		local spawnPos = rootPart.Position + Vector3.new(PLAYER_X_OFFSET, targetYOffset, 0)
		anchor.WorldPosition = spawnPos
		anchor.Parent = workspace.Terrain

		local billboard = FeedbackPools.getBillboard()
		billboard.StudsOffset = Vector3.zero
		billboard.Size = UDim2.fromOffset(textSize * 6, textSize * 3)
		billboard.Adornee = anchor
		billboard.Parent = workspace

		local label = FeedbackPools.getLabel(textSize, HEAL_COLOR, Cache.getHealIndicatorFont())
		label.Text = tostring(healAmount)
		label.TextTransparency = 1
		label.TextSize = 0
		label.Parent = billboard

		local overshootSize = math.floor(textSize * OVERSHOOT_SCALE)
		goalPopIn.TextSize = overshootSize
		goalPopIn.TextTransparency = 0
		local popTween = TweenService:Create(label, TWEEN_POP_IN, goalPopIn)
		goalSettle.TextSize = textSize
		local settleTween = TweenService:Create(label, TWEEN_POP_SETTLE, goalSettle)
		popTween.Completed:Once(function()
			settleTween:Play()
		end)
		popTween:Play()

		state = {
			billboard = billboard,
			label = label,
			anchor = anchor,
			value = healAmount,
			timeout = nil,
			generation = 1,
			currentYOffset = targetYOffset,
			heightTween = nil,
		}
		healStackStates[character] = state
	else
		state.value += healAmount
		state.label.Text = tostring(state.value)
		state.generation += 1

		if math.abs(targetYOffset - state.currentYOffset) > 0.1 and state.anchor then
			if state.heightTween then
				state.heightTween:Cancel()
			end

			local currentAnchorPos = state.anchor.WorldPosition
			local newYPos = currentAnchorPos.Y + (targetYOffset - state.currentYOffset)
			state.currentYOffset = targetYOffset
			goalHeightShift.WorldPosition = Vector3.new(currentAnchorPos.X, newYPos, currentAnchorPos.Z)
			state.heightTween = TweenService:Create(state.anchor, TWEEN_HEIGHT_SHIFT, goalHeightShift)
			state.heightTween:Play()
		end

		if state.timeout then
			task.cancel(state.timeout)
		end
	end

	local gen = state.generation
	state.timeout = task.delay(STACK_TIMEOUT, handleHealStackTimeout, character, gen)
end

function StackIndicators.cleanup(): ()
	if cursorTrackConnection then
		cursorTrackConnection:Disconnect()
		cursorTrackConnection = nil
	end

	if cursorPopInTween then
		cursorPopInTween:Cancel()
		cursorPopInTween = nil
	end
	if cursorSettleTween then
		cursorSettleTween:Cancel()
		cursorSettleTween = nil
	end
	if cursorShrinkTween then
		cursorShrinkTween:Cancel()
		cursorShrinkTween = nil
	end
	if cursorFadeOutThread then
		task.cancel(cursorFadeOutThread)
		cursorFadeOutThread = nil
	end

	if cursorStrokeFadeTween then
		cursorStrokeFadeTween:Cancel()
		cursorStrokeFadeTween = nil
	end
	if cursorBumpTween then
		cursorBumpTween:Cancel()
		cursorBumpTween = nil
	end
	if cursorBumpSettleTween then
		cursorBumpSettleTween:Cancel()
		cursorBumpSettleTween = nil
	end

	if killPopTween then
		killPopTween:Cancel()
		killPopTween = nil
	end
	if killSettleTween then
		killSettleTween:Cancel()
		killSettleTween = nil
	end
	if killColorResetTween then
		killColorResetTween:Cancel()
		killColorResetTween = nil
	end
	if killResetThread then
		task.cancel(killResetThread)
		killResetThread = nil
	end

	table.clear(stackStates)
	table.clear(healStackStates)
	accumulatedDamage = 0
	cursorIsVisible = false
	cursorGeneration = 0
	lastMouseX = 0
	lastMouseY = 0
end

return StackIndicators
