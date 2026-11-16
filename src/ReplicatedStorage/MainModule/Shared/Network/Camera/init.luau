--!strict
--!native
--!optimize 2

local NOOP_CONNECTION = { Disconnect = function() end }

local CameraNetwork = {}

function CameraNetwork.getCameraData(): CFrame?
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Camera.GetData.Invoke)
	if success then
		return result
	end
	return nil
end

function CameraNetwork.onGetCameraData(callback: (player: Player) -> CFrame): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Camera.GetData.On(callback)
	return NOOP_CONNECTION
end

function CameraNetwork.init(): ()
end

return CameraNetwork
