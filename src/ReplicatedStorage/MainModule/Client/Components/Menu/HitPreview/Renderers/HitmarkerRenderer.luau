--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)

local Constants = require(script.Parent.Parent.Constants)
local SettingsHelper = require(script.Parent.Parent.Utils.SettingsHelper)

export type HitmarkerState = {
	image: ImageLabel,
	visible: boolean,
	fadeThread: thread?,
	rotation: number,
	rotationDir: number,
	rotationMode: number,
	rotSpeed: number,
	randomPhase: number,
	randomSeed: number,
	startTime: number,
}

local HitmarkerRenderer = {}

function HitmarkerRenderer.createImage(parent: Frame): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = "Hitmarker"
	image.Size = UDim2.fromOffset(Constants.HITMARKER_SIZE, Constants.HITMARKER_SIZE)
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.BackgroundTransparency = 1
	image.ImageTransparency = 1
	image.Visible = false
	image.ZIndex = 10
	image.Parent = parent
	return image
end

function HitmarkerRenderer.createState(image: ImageLabel): HitmarkerState
	return {
		image = image,
		visible = false,
		fadeThread = nil,
		rotation = 0,
		rotationDir = 1,
		rotationMode = 1,
		rotSpeed = Constants.HITMARKER_ROTATION_SPEED,
		randomPhase = 0,
		randomSeed = 0,
		startTime = 0,
	}
end

function HitmarkerRenderer.show(state: HitmarkerState, isHeadshot: boolean, isDestroyed: () -> boolean): ()
	local image = state.image
	if not image then
		return
	end
	if not SettingsHelper.getSetting("HitIndicators") then
		return
	end

	if state.fadeThread then
		task.cancel(state.fadeThread)
		state.fadeThread = nil
	end

	local presetIndex = SettingsHelper.getSetting("HitPreset") or 1
	local preset = SettingsConfig.HitmarkerAssets[presetIndex] or SettingsConfig.HitmarkerAssets[1]
	local color = SettingsHelper.getHitmarkerColor(isHeadshot)
	local rotationModeSetting = SettingsHelper.getSetting("HitmarkerRotation") or 1
	local sizeMultiplier = SettingsHelper.getSetting("HitIndicatorSize") or 1

	local baseSize = Constants.HITMARKER_SIZE * sizeMultiplier
	image.Image = preset.id
	image.ImageColor3 = color
	image.Size = UDim2.fromOffset(baseSize * preset.size.X.Scale, baseSize * preset.size.Y.Scale)
	image.ImageTransparency = 0
	image.Visible = true
	state.visible = true

	state.rotationMode = rotationModeSetting
	state.rotationDir = if rotationModeSetting == 1 then -1 else 1

	local speedSetting = SettingsHelper.getSetting("HitmarkerSpeed") or 2
	local speedMultiplier = Constants.HITMARKER_SPEED_MULTIPLIERS[speedSetting] or 1.0
	state.rotSpeed = Constants.HITMARKER_ROTATION_SPEED * speedMultiplier

	if rotationModeSetting == 3 then
		image.Rotation = 0
	elseif rotationModeSetting == 4 then
		state.startTime = os.clock()
		state.randomPhase = state.randomPhase + Constants.GOLDEN_ANGLE
		state.randomSeed = (state.randomSeed + Constants.PHI * 100) % 1000
	end

	state.fadeThread = task.delay(Constants.HITMARKER_HOLD_TIME, function()
		if isDestroyed() or not image then
			return
		end

		local fadeStart = os.clock()
		while true do
			if isDestroyed() or not image then
				break
			end

			local elapsed = os.clock() - fadeStart
			local progress = math.min(elapsed / Constants.HITMARKER_FADE_TIME, 1)

			image.ImageTransparency = progress

			if progress >= 1 then
				image.Visible = false
				state.visible = false
				break
			end

			task.wait()
		end
		state.fadeThread = nil
	end)
end

function HitmarkerRenderer.updatePosition(state: HitmarkerState, position: Vector2): ()
	if state.visible and state.image then
		state.image.Position = UDim2.fromOffset(position.X, position.Y)
	end
end

function HitmarkerRenderer.updateRotation(state: HitmarkerState, dt: number): ()
	if not state.visible or not state.image then
		return
	end

	local now = os.clock()

	if state.rotationMode == 4 then
		local elapsed = now - state.startTime
		local phase = state.randomPhase
		local seed = state.randomSeed

		local wave1 = math.sin(elapsed * 2.3 + phase) * 45
		local wave2 = math.sin(elapsed * Constants.PHI * 1.7 + phase * Constants.PHI) * 28
		local wave3 = math.sin(elapsed * Constants.PHI * Constants.PHI + phase * 0.7) * 15
		local wave4 = math.sin(elapsed * 0.8 + seed) * 8

		local goldenDrift = (elapsed * Constants.GOLDEN_ANGLE * 0.3) % 360
		local driftInfluence = math.sin(elapsed * 0.5 + phase) * 0.3 + 0.2

		local baseRotation = wave1 + wave2 + wave3 + wave4
		local finalRotation = baseRotation + goldenDrift * driftInfluence

		local breathe = 1 + math.sin(elapsed * 1.2 + phase * 0.5) * 0.15
		state.image.Rotation = finalRotation * breathe
	elseif state.rotationMode ~= 3 then
		state.rotation = state.rotation + dt * state.rotSpeed * state.rotationDir
		state.image.Rotation = state.rotation
	end
end

function HitmarkerRenderer.hide(state: HitmarkerState): ()
	if state.fadeThread then
		task.cancel(state.fadeThread)
		state.fadeThread = nil
	end
	if state.image then
		state.image.Visible = false
		state.image.ImageTransparency = 1
	end
	state.visible = false
end

function HitmarkerRenderer.cleanup(state: HitmarkerState): ()
	if state.fadeThread then
		task.cancel(state.fadeThread)
		state.fadeThread = nil
	end
end

return HitmarkerRenderer
