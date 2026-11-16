--!strict
--!native
--!optimize 2

local CONSTANTS = require(script.Parent.CONSTANTS)
local Triangle = require(script.Parent.Triangle)

local TAU = CONSTANTS.TAU
local GAP = CONSTANTS.GAP
local PART_PER_UNIT = CONSTANTS.PART_PER_UNIT
local CENTER = CONSTANTS.CENTER
local EXTERIOR_RADIUS = CONSTANTS.EXTERIOR_RADIUS
local EX_OFFSET = CONSTANTS.EX_OFFSET
local FOV = CONSTANTS.FOV

local BLACK = Color3.new()

local VPF = Instance.new("ViewportFrame")
VPF.Ambient = Color3.new(1, 1, 1)
VPF.LightColor = Color3.new(1, 1, 1)
VPF.LightDirection = Vector3.new(0, 0, -1)
VPF.BackgroundTransparency = 1
VPF.Size = UDim2.fromScale(1, 1)

local CAMERA = Instance.new("Camera")
CAMERA.CameraType = Enum.CameraType.Scriptable
CAMERA.CFrame = CFrame.identity
CAMERA.FieldOfView = FOV

local function pivotAround(model: Model, pivotCF: CFrame, newCF: CFrame)
	local invPivotCF = pivotCF:Inverse()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = newCF * (invPivotCF * part.CFrame)
		end
	end
end

local function createSection(subN: number, interior_radius: number, exterior_radius: number, ppu: number): Model
	local subModel = Instance.new("Model")

	local exCircum = (TAU * exterior_radius) / subN - GAP
	local inCircum = (TAU * interior_radius) / subN - GAP

	local exTheta = exCircum / exterior_radius
	local inTheta = inCircum / interior_radius
	local diffTheta = exTheta - inTheta

	local exPoints: { Vector3 } = {}
	local inPoints: { Vector3 } = {}

	local nParts = math.ceil(exCircum / ppu)

	local exRadiusVec = Vector3.new(exterior_radius, 0, 0)
	local inRadiusVec = Vector3.new(interior_radius, 0, 0)

	for i = 0, nParts do
		exPoints[i + 1] = CENTER * CFrame.fromEulerAnglesXYZ(0, 0, (i / nParts) * exTheta) * exRadiusVec
		inPoints[i + 1] = CENTER * CFrame.fromEulerAnglesXYZ(0, 0, diffTheta / 2 + (i / nParts) * inTheta) * inRadiusVec
	end

	for i = 1, nParts do
		local a = exPoints[i]
		local b = inPoints[i]
		local c = exPoints[i + 1]
		local d = inPoints[i + 1]

		Triangle(subModel, a, b, c)
		Triangle(subModel, b, c, d)
	end

	return subModel
end

local function createDialSection(interior_radius: number, exterior_radius: number, ppu: number): Model
	local subModel = Instance.new("Model")

	local arcAngle = TAU / 6
	local exCircum = exterior_radius * arcAngle

	local exTheta = arcAngle
	local inTheta = arcAngle * (interior_radius / exterior_radius)

	local exPoints: { Vector3 } = {}
	local inPoints: { Vector3 } = {}

	local nParts = math.ceil(exCircum / ppu)

	local exRadiusVec = Vector3.new(exterior_radius, 0, 0)
	local inRadiusVec = Vector3.new(interior_radius, 0, 0)

	for i = 0, nParts do
		local t = i / nParts
		exPoints[i + 1] = CENTER * CFrame.fromEulerAnglesXYZ(0, 0, -exTheta / 2 + t * exTheta) * exRadiusVec
		inPoints[i + 1] = CENTER * CFrame.fromEulerAnglesXYZ(0, 0, -inTheta / 2 + t * inTheta) * inRadiusVec
	end

	for i = 1, nParts do
		local a = exPoints[i]
		local b = inPoints[i]
		local c = exPoints[i + 1]
		local d = inPoints[i + 1]

		Triangle(subModel, a, b, c)
		Triangle(subModel, b, c, d)
	end

	return subModel
end

local function createRadial(subN: number, tPercent: number, rotation: number?): CanvasGroup
	rotation = rotation or 0

	local section = createSection(subN, (1 - tPercent) * EXTERIOR_RADIUS, EXTERIOR_RADIUS, PART_PER_UNIT)

	local frame = Instance.new("CanvasGroup")
	frame.Name = "RadialContainer"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.SizeConstraint = Enum.SizeConstraint.RelativeYY
	frame.Visible = false

	local radialFrame = Instance.new("Frame")
	radialFrame.Name = "Radial"
	radialFrame.BackgroundTransparency = 1
	radialFrame.Size = UDim2.fromScale(1, 1)
	radialFrame.Parent = frame

	local attachFrame = Instance.new("Frame")
	attachFrame.Name = "Attach"
	attachFrame.BackgroundTransparency = 1
	attachFrame.Size = UDim2.fromScale(1, 1)
	attachFrame.Parent = frame

	local thickness = tPercent * EXTERIOR_RADIUS
	local interior_radius = EXTERIOR_RADIUS - thickness
	local inv_tPercent = 1 - tPercent / 2

	local exCircum = (TAU * EXTERIOR_RADIUS) / subN
	local exTheta = exCircum / EXTERIOR_RADIUS
	local inCircum = (TAU * interior_radius) / subN - GAP
	local inTheta = inCircum / interior_radius

	local edge = Vector2.new(math.cos(inTheta), math.sin(inTheta)) * interior_radius - Vector2.new(interior_radius, 0)
	local edgeLen = math.min(edge.Magnitude / (EXTERIOR_RADIUS * 2), 0.18)

	for i = 0, subN - 1 do
		local vpf = VPF:Clone()
		local cam = CAMERA:Clone()
		vpf.CurrentCamera = cam
		vpf.Name = tostring(i + 1)

		local theta = (i / subN) * TAU + (rotation :: number)

		local sub = section:Clone()
		pivotAround(sub, CENTER, CENTER * CFrame.fromEulerAnglesXYZ(0, 0, theta + EX_OFFSET))
		sub.Parent = vpf

		local segmentCorner = Instance.new("UICorner")
		segmentCorner.CornerRadius = UDim.new(0.15, 0)
		segmentCorner.Parent = vpf

		local t = theta + EX_OFFSET + exTheta / 2
		local c = math.cos(t) / 2 * inv_tPercent
		local s = -math.sin(t) / 2 * inv_tPercent

		local attach = Instance.new("Frame")
		attach.Name = tostring(i + 1)
		attach.BackgroundTransparency = 1
		attach.BackgroundColor3 = BLACK
		attach.BorderSizePixel = 0
		attach.AnchorPoint = Vector2.new(0.5, 0.5)
		attach.Position = UDim2.fromScale(0.5 + c, 0.5 + s)
		attach.Size = UDim2.fromScale(edgeLen, edgeLen)
		attach.Parent = attachFrame

		cam.Parent = vpf
		vpf.Parent = radialFrame
	end

	section:Destroy()

	local dialEx = (1 - tPercent) * EXTERIOR_RADIUS - 1
	local dialIn = dialEx - 3
	local dialSection = createDialSection(dialIn, dialEx, PART_PER_UNIT / 2)

	local dialVpf = VPF:Clone()
	dialVpf.Name = "RadialDial"
	dialVpf.Size = UDim2.fromScale(1, 1)
	dialVpf.ZIndex = 5
	dialVpf.ImageColor3 = Color3.fromRGB(200, 210, 225)
	dialVpf.ImageTransparency = 0.15

	local dialCam = CAMERA:Clone()
	dialVpf.CurrentCamera = dialCam

	pivotAround(dialSection, CENTER, CENTER * CFrame.fromEulerAnglesXYZ(0, 0, -TAU / 4))
	dialSection.Parent = dialVpf
	dialCam.Parent = dialVpf

	local dialCorner = Instance.new("UICorner")
	dialCorner.CornerRadius = UDim.new(0.2, 0)
	dialCorner.Parent = dialVpf

	dialVpf.Parent = frame

	return frame
end

return createRadial :: (subN: number, tPercent: number, rotation: number?) -> CanvasGroup
