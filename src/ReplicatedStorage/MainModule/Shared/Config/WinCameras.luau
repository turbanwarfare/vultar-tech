--!strict
--!native
--!optimize 2

local Credits = require(script.Parent.Credits)
local LoadingCameras = require(script.Parent.LoadingCameras)

local WinCameras = {}

WinCameras.Bases = {
	["NOVA STATION"] = { position = Vector3.new(-14.333, 84.338, 132.079), orientation = Vector3.new(-15.711, -0.951, 0) },
	["ONYX CITADEL"] = { position = Vector3.new(-1385.353, 645.657, 727.691), orientation = Vector3.new(-9.551, 43.318, 0) },
	["SURREX ASSEMBLY"] = { position = Vector3.new(303.911, 319.889, -571.987), orientation = Vector3.new(3.845, 24.207, 0) },
	["MATARO FORTRESS DISTRICT"] = { position = Vector3.new(977.247, 185.703, -894.505), orientation = Vector3.new(-20.22, 41.006, 0) },
	["OVERWATCH"] = { position = Vector3.new(2366.185, 1628.765, 66.22), orientation = Vector3.new(-15.614, 31.537, 0) },
	["IRONWORKS"] = { position = Vector3.new(-550.855, 148.615, 449.835), orientation = Vector3.new(-20.22, 139.411, 0) },
	["TESTING PLACE"] = { position = Vector3.new(-81.197, 23.168, 54.976), orientation = Vector3.new(-15.58, -49.933, 0) },
} :: { [string]: LoadingCameras.LoadingCamera }

function WinCameras.getShot(): CFrame?
	local baseName = Credits.getBaseName()
	local camera = if baseName then WinCameras.Bases[baseName] else nil

	if camera then
		return LoadingCameras.toCFrame(camera)
	end

	return nil
end

return WinCameras
