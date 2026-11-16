--!strict
--!native
--!optimize 2

local Credits = require(script.Parent.Credits)

export type LoadingCamera = {
	position: Vector3,
	orientation: Vector3,
}

local LoadingCameras = {}

LoadingCameras.Bases = {
	["NOVA STATION"] = {
		{ position = Vector3.new(-14.333, 84.338, 132.079), orientation = Vector3.new(-15.711, -0.951, 0) },
		{ position = Vector3.new(-78.868, 69.657, -19.389), orientation = Vector3.new(-17.717, -90.333, 0) },
		{ position = Vector3.new(-92.443, 66.376, 5.43), orientation = Vector3.new(-22.587, 31.421, 0) },
		{ position = Vector3.new(99.026, 86.831, -60.122), orientation = Vector3.new(-36.911, 179.999, 0) },
	},
	["ONYX CITADEL"] = {
		{ position = Vector3.new(-1385.353, 645.657, 727.691), orientation = Vector3.new(-9.551, 43.318, 0) },
		{ position = Vector3.new(-1149.798, 428.453, 754.028), orientation = Vector3.new(-15.854, 179.292, 0) },
		{ position = Vector3.new(-1152.731, 349.876, 791.788), orientation = Vector3.new(-11.843, -179.849, 0) },
		{ position = Vector3.new(-1270.031, 611.808, 1020.533), orientation = Vector3.new(-0.671, 43.787, 0) },
	},
	["SURREX ASSEMBLY"] = {
		{ position = Vector3.new(303.911, 319.889, -571.987), orientation = Vector3.new(3.845, 24.207, -0) },
		{ position = Vector3.new(-0.004, 124.202, -441.149), orientation = Vector3.new(-21.366, -43.115, -0) },
		{ position = Vector3.new(-106.961, 96.659, -500.41), orientation = Vector3.new(-19.647, -1.003, -0) },
		{ position = Vector3.new(-169.013, 123.863, -732.015), orientation = Vector3.new(-16.21, -55.72, -0) },
	},
	["MATARO FORTRESS DISTRICT"] = {
		{ position = Vector3.new(467.795, 175.879, 461.08), orientation = Vector3.new(-22.082, 39.248, 0) },
		{ position = Vector3.new(233.638, 149.951, 28.553), orientation = Vector3.new(-17.785, -70.76, 0) },
		{ position = Vector3.new(-30.584, 220.3, -806.034), orientation = Vector3.new(-21.939, -127.77, 0) },
		{ position = Vector3.new(51.638, 175.325, -314.168), orientation = Vector3.new(-19.36, -140.375, -0) },
		{ position = Vector3.new(-241.096, 167.299, -523.932), orientation = Vector3.new(-11.912, -34.482, 0) },
		{ position = Vector3.new(977.247, 185.703, -894.505), orientation = Vector3.new(-20.22, 41.006, 0) },
		{ position = Vector3.new(417.285, 181.311, -1062.75), orientation = Vector3.new(-8.188, 39.573, 0) },
	},
	["OVERWATCH"] = {
		{ position = Vector3.new(2366.185, 1628.765, 66.22), orientation = Vector3.new(-15.614, 31.537, -0) },
		{ position = Vector3.new(2376.497, 1624.858, -230.574), orientation = Vector3.new(-21.818, 89.406, 0) },
		{ position = Vector3.new(2505.145, 1621.938, -181.278), orientation = Vector3.new(-26.975, 46.903, -0) },
		{ position = Vector3.new(2169.525, 1539.132, -184.709), orientation = Vector3.new(-19.526, -51.073, -0) },
		{ position = Vector3.new(2368.856, 1534.307, 175.382), orientation = Vector3.new(-12.938, 47.658, 0) },
	},
	["IRONWORKS"] = {
		{ position = Vector3.new(-550.855, 148.615, 449.835), orientation = Vector3.new(-20.22, 139.411, -0) },
		{ position = Vector3.new(-552.169, 66.662, 881.697), orientation = Vector3.new(-13.344, 42.868, 0) },
		{ position = Vector3.new(-710.275, 64.186, 709.857), orientation = Vector3.new(-14.37, -31.903, 0) },
		{ position = Vector3.new(-1083.506, 62.507, 497.559), orientation = Vector3.new(-13.51, -135.609, 0) },
		{ position = Vector3.new(-865.163, 14.265, 541.141), orientation = Vector3.new(-1.764, -179.44, -0) },
	},
	["TESTING PLACE"] = {
		{ position = Vector3.new(-81.197, 23.168, 54.976), orientation = Vector3.new(-15.58, -49.933, 0) },
		{ position = Vector3.new(-114.067, 19.514, 94.222), orientation = Vector3.new(-7.272, 91.015, -0) },
		{ position = Vector3.new(206.024, 40.758, -38.241), orientation = Vector3.new(-14.148, -117.828, -0) },
		{ position = Vector3.new(161.923, 27.439, -2.914), orientation = Vector3.new(-1.829, 3.352, 0) },
		{ position = Vector3.new(46.56, 28.271, 211.773), orientation = Vector3.new(-10.71, 128.83, 0) },
	},
} :: { [string]: { LoadingCamera } }

function LoadingCameras.toCFrame(camera: LoadingCamera): CFrame
	local orientation = camera.orientation
	return CFrame.new(camera.position) * CFrame.fromOrientation(math.rad(orientation.X), math.rad(orientation.Y), math.rad(orientation.Z))
end

function LoadingCameras.getShots(): { CFrame }
	local shots: { CFrame } = {}
	local baseName = Credits.getBaseName()
	local cameras = if baseName then LoadingCameras.Bases[baseName] else nil

	if cameras then
		for _, camera in cameras do
			table.insert(shots, LoadingCameras.toCFrame(camera))
		end
	end

	return shots
end

return LoadingCameras
