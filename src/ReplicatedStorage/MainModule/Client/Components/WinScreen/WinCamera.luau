--!native
--!optimize 2

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent
local Types = require(MainModule.Shared.Types)
local WinCameras = require(MainModule.Shared.Config.WinCameras)

type FusionScope = Types.FusionScope
export type CutTo = (from: CFrame, to: CFrame, duration: number, onBlack: (() -> ())?) -> ()
export type FadeOut = () -> ()

local STREAM_TIMEOUT = 3
local END_OFFSET = CFrame.new(1.5, 0.4, -1.5)
local TWEEN_INFO = TweenInfo.new(10, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local FADE_OUT_TIME = 0.5
local FADE_OUT_INFO = TweenInfo.new(FADE_OUT_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local FADE_IN_INFO = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local WinCamera = {}

function WinCamera.start(scope: FusionScope, onReady: (() -> ())?): (CutTo, FadeOut)
	local shot = WinCameras.getShot()
	local camera = workspace.CurrentCamera
	if not shot or not camera then
		if onReady then
			task.spawn(onReady)
		end
		return function() end, function() end
	end

	local player = Players.LocalPlayer
	local active = true
	local tween: Tween? = nil

	local fadeGui = Instance.new("ScreenGui")
	fadeGui.Name = "WinCameraFade"
	fadeGui.IgnoreGuiInset = true
	fadeGui.ResetOnSpawn = false
	fadeGui.DisplayOrder = 94
	local fade = Instance.new("Frame")
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 1
	fade.BorderSizePixel = 0
	fade.Parent = fadeGui
	fadeGui.Parent = player:FindFirstChildOfClass("PlayerGui")

	local typeConnection = camera:GetPropertyChangedSignal("CameraType"):Connect(function()
		if active and camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
	end)

	table.insert(scope, function()
		active = false
		typeConnection:Disconnect()
		if tween then
			tween:Cancel()
		end
		TweenService:Create(fade, FADE_IN_INFO, { BackgroundTransparency = 1 }):Play()
		task.delay(FADE_IN_INFO.Time, fadeGui.Destroy, fadeGui)
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end)

	local function cut(target: CFrame, goal: CFrame, info: TweenInfo, onBlack: (() -> ())?)
		local fadeStarted = os.clock()
		TweenService:Create(fade, FADE_OUT_INFO, { BackgroundTransparency = 0 }):Play()
		pcall(player.RequestStreamAroundAsync, player, target.Position, STREAM_TIMEOUT)
		local remaining = FADE_OUT_TIME - (os.clock() - fadeStarted)
		if remaining > 0 then
			task.wait(remaining)
		end
		if not active then
			return
		end

		if onBlack then
			onBlack()
		end
		if tween then
			tween:Cancel()
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = target
		TweenService:Create(fade, FADE_IN_INFO, { BackgroundTransparency = 1 }):Play()
		tween = TweenService:Create(camera, info, { CFrame = goal })
		tween:Play()
	end

	task.spawn(function()
		cut(shot, shot * END_OFFSET, TWEEN_INFO)
		if active and onReady then
			onReady()
		end
	end)

	return function(from: CFrame, to: CFrame, duration: number, onBlack: (() -> ())?)
		cut(from, to, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), onBlack)
	end, function()
		TweenService:Create(fade, FADE_OUT_INFO, { BackgroundTransparency = 0 }):Play()
	end
end

return WinCamera
