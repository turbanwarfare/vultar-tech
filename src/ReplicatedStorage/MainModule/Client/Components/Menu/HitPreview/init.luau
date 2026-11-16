--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(script.Constants)
local ViewportMath = require(script.Utils.ViewportMath)
local HitmarkerRenderer = require(script.Renderers.HitmarkerRenderer)
local DamageNumberRenderer = require(script.Renderers.DamageNumberRenderer)
local HighlightRenderer = require(script.Renderers.HighlightRenderer)
local KillIndicatorRenderer = require(script.Renderers.KillIndicatorRenderer)

local HitPreview = {}

export type HitPreviewInstance = {
	destroy: () -> (),
	setEnabled: (enabled: boolean) -> (),
}

local function isHeadPart(partName: string): boolean
	for _, head in Constants.HEAD_PARTS do
		if partName == head then
			return true
		end
	end
	return false
end

local function getDamage(isHeadshot: boolean): number
	return if isHeadshot then Constants.HEAD_DAMAGE else Constants.BODY_DAMAGE
end

function HitPreview.create(
	viewport: ViewportFrame,
	worldModel: WorldModel,
	camera: Camera,
	npcModel: Model,
	containerFrame: Frame
): HitPreviewInstance
	local connections: { RBXScriptConnection } = {}
	local isDestroyed = false
	local isEnabled = true

	local isMouseDown = false
	local lastFireTime = 0

	local overlayFrame = Instance.new("Frame")
	overlayFrame.Name = "HitPreviewOverlay"
	overlayFrame.Size = UDim2.fromScale(1, 1)
	overlayFrame.BackgroundTransparency = 1
	overlayFrame.ZIndex = 5
	overlayFrame.Parent = containerFrame

	local hitmarkerImage = HitmarkerRenderer.createImage(overlayFrame)
	local hitmarkerState = HitmarkerRenderer.createState(hitmarkerImage)
	local damageState = DamageNumberRenderer.createState(overlayFrame, true)
	local highlightState = HighlightRenderer.createState()
	local killIndicatorState = KillIndicatorRenderer.createState(overlayFrame)

	local killDamageCounter = 0
	local killThreshold = KillIndicatorRenderer.getThreshold()

	local function isDestroyedFn()
		return isDestroyed
	end

	local function triggerHit(part: BasePart, _hitPosition: Vector3, mousePos: Vector2)
		local isHeadshot = isHeadPart(part.Name)
		local damage = getDamage(isHeadshot)
		local overlayPos = ViewportMath.getOverlayPosition(mousePos, overlayFrame)

		killDamageCounter += damage

		HitmarkerRenderer.show(hitmarkerState, isHeadshot, isDestroyedFn)
		DamageNumberRenderer.showDamageNumber(
			damageState,
			overlayFrame,
			overlayPos,
			damage,
			isHeadshot,
			viewport,
			npcModel,
			camera,
			isDestroyedFn
		)
		HighlightRenderer.show(highlightState, part, isHeadshot, worldModel)

		while killDamageCounter >= killThreshold do
			killDamageCounter -= killThreshold
			KillIndicatorRenderer.show(killIndicatorState, overlayPos, isDestroyedFn)
		end
	end

	local function tryFire()
		local mousePos = UserInputService:GetMouseLocation()
		local part, hitPos = ViewportMath.raycastViewport(mousePos, camera, worldModel, npcModel, viewport)

		if part and hitPos then
			triggerHit(part, hitPos, mousePos)
		end
	end

	table.insert(connections, UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or not isEnabled then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local mousePos = UserInputService:GetMouseLocation()
			if ViewportMath.isMouseInViewport(mousePos, viewport) then
				isMouseDown = true
				lastFireTime = 0
			end
		end
	end))

	table.insert(connections, UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isMouseDown = false
		end
	end))

	table.insert(connections, UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if hitmarkerState.visible then
				local mousePos = UserInputService:GetMouseLocation()
				local overlayPos = ViewportMath.getOverlayPosition(mousePos, overlayFrame)
				HitmarkerRenderer.updatePosition(hitmarkerState, overlayPos)
			end
		end
	end))

	local renderConnection: RBXScriptConnection? = nil

	local function connectRenderLoop()
		if renderConnection then
			return
		end
		renderConnection = RunService.RenderStepped:Connect(function(dt)
			if isDestroyed or not isEnabled then
				return
			end

			local now = os.clock()

			if isMouseDown then
				if now - lastFireTime >= Constants.FIRE_RATE then
					lastFireTime = now
					tryFire()
				end
			end

			local hasExpandIndicators = damageState.expandCount > 0
			local hasActiveEffects = hitmarkerState.visible or isMouseDown or damageState.stack.isVisible or hasExpandIndicators
			if not hasActiveEffects then
				return
			end

			local mousePos = UserInputService:GetMouseLocation()
			local overlayPos = ViewportMath.getOverlayPosition(mousePos, overlayFrame)

			if hitmarkerState.visible then
				HitmarkerRenderer.updatePosition(hitmarkerState, overlayPos)
				HitmarkerRenderer.updateRotation(hitmarkerState, dt)
			end

			if hasExpandIndicators then
				DamageNumberRenderer.updateExpand(damageState)
			end

			if damageState.stack.isVisible then
				DamageNumberRenderer.updateStackPosition(damageState, overlayPos, viewport, npcModel, camera)
			end

			HighlightRenderer.update(highlightState)
		end)
	end

	local function disconnectRenderLoop()
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
	end

	connectRenderLoop()
	table.insert(connections, { Disconnect = disconnectRenderLoop })

	local function destroy()
		if isDestroyed then
			return
		end
		isDestroyed = true

		for _, conn in connections do
			conn:Disconnect()
		end
		table.clear(connections)

		HitmarkerRenderer.cleanup(hitmarkerState)
		DamageNumberRenderer.cleanup(damageState)
		HighlightRenderer.cleanup(highlightState)
		KillIndicatorRenderer.cleanup(killIndicatorState)

		if overlayFrame then
			overlayFrame:Destroy()
		end
	end

	local function setEnabled(enabled: boolean)
		isEnabled = enabled
		if not enabled then
			disconnectRenderLoop()
			isMouseDown = false
			killDamageCounter = 0
			HitmarkerRenderer.hide(hitmarkerState)
			DamageNumberRenderer.cleanup(damageState)
			damageState.stack.isVisible = false
			damageState.stack.accumulatedDamage = 0
			if damageState.stack.label then
				damageState.stack.label.Visible = false
				damageState.stack.label.TextTransparency = 1
			end
			HighlightRenderer.cleanup(highlightState)
			KillIndicatorRenderer.cleanup(killIndicatorState)
		else
			connectRenderLoop()
		end
		overlayFrame.Visible = enabled
	end

	return {
		destroy = destroy,
		setEnabled = setEnabled,
	}
end

return HitPreview
