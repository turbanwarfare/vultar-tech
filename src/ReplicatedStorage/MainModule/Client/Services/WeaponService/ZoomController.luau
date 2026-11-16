--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent
local WeaponConfig = require(MainModule.Shared.Config.Weapons.WeaponConfig)

local ZoomController = {}

local camera = workspace.CurrentCamera
local currentZoomTween: Tween? = nil
local defaultFOV = 70
local zoomDisabled = false

function ZoomController.init(): ()
	defaultFOV = camera.FieldOfView
end

function ZoomController.setZoomDisabled(disabled: boolean): ()
	zoomDisabled = disabled
	if disabled then
		ZoomController.reset()
	end
end

function ZoomController.isZoomDisabled(): boolean
	return zoomDisabled
end

function ZoomController.applyZoom(zoomIn: boolean): ()
	if zoomDisabled then
		return
	end

	if currentZoomTween then
		currentZoomTween:Cancel()
		currentZoomTween = nil
	end

	local zoomSettings = WeaponConfig.ZoomSettings
	local targetFOV = if zoomIn then zoomSettings.FOV else defaultFOV
	local duration = if zoomIn then zoomSettings.TweenIn else zoomSettings.TweenOut
	local easing = if zoomIn then zoomSettings.EasingIn else zoomSettings.EasingOut

	local tweenInfo = TweenInfo.new(duration, easing, Enum.EasingDirection.Out)
	currentZoomTween = TweenService:Create(camera, tweenInfo, { FieldOfView = targetFOV })
	currentZoomTween:Play()
end

function ZoomController.reset(): ()
	if currentZoomTween then
		currentZoomTween:Cancel()
		currentZoomTween = nil
	end
	camera.FieldOfView = defaultFOV
end

function ZoomController.cleanup(): ()
	ZoomController.reset()
	zoomDisabled = false
end

return ZoomController
