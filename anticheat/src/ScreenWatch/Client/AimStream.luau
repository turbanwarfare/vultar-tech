--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Network = require(script.Parent.Parent.Shared.Network)

local AimStream = {}

local SAMPLE_INTERVAL = 1 / 20

local connection: RBXScriptConnection? = nil
local accumulator = 0

local function getCurrentCamera(): Camera?
	return workspace.CurrentCamera
end

local function sample(): ()
	local camera = getCurrentCamera()
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not camera or not humanoid or humanoid.Health <= 0 then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	Network.sendAimSample(workspace:GetServerTimeNow(), ray.Origin, ray.Direction)
end

function AimStream.start(): ()
	if connection then
		return
	end
	connection = RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < SAMPLE_INTERVAL then
			return
		end
		accumulator = 0
		sample()
	end)
end

function AimStream.stop(): ()
	local current = connection
	connection = nil
	if current then
		current:Disconnect()
	end
end

return AimStream
