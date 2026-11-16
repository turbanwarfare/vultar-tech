--!strict
--!native
--!optimize 2

local CrateViewportFactory = {}

export type CrateViewportOptions = {
	fov: number?,
	paddingMultiplier: number?,
	pitchAngleDeg: number?,
	cameraElevationDeg: number?,
	yawAngleDeg: number?,
	verticalOffset: number?,
	ambient: Color3?,
	lightColor: Color3?,
	lightDirection: Vector3?,
	backgroundColor: Color3?,
	backgroundTransparency: number?,
}

local DEFAULT_FOV = 35
local DEFAULT_AMBIENT = Color3.fromRGB(140, 140, 150)
local DEFAULT_LIGHT_COLOR = Color3.fromRGB(255, 255, 255)
local DEFAULT_LIGHT_DIR = Vector3.new(-0.35, -0.85, -0.4).Unit

local cameraTemplateCache: { [number]: Camera } = {}

local function getCameraTemplate(fov: number): Camera
	local cached = cameraTemplateCache[fov]
	if cached then
		return cached:Clone()
	end
	local template = Instance.new("Camera")
	template.CameraType = Enum.CameraType.Scriptable
	template.FieldOfView = fov
	cameraTemplateCache[fov] = template
	return template:Clone()
end

function CrateViewportFactory.create(sourceModel: Model, options: CrateViewportOptions?): (ViewportFrame, Model, number)
	local opts = options or {}
	local fov = opts.fov or DEFAULT_FOV
	local padding = opts.paddingMultiplier or 1.30
	local elevationDeg = opts.cameraElevationDeg or opts.pitchAngleDeg or 12
	local yawDeg = opts.yawAngleDeg or 150
	local vertOffsetRatio = opts.verticalOffset or 0
	local ambient = opts.ambient or DEFAULT_AMBIENT
	local lightColor = opts.lightColor or DEFAULT_LIGHT_COLOR
	local lightDir = if opts.lightDirection then opts.lightDirection.Unit else DEFAULT_LIGHT_DIR

	local clone = sourceModel:Clone()

	for _, desc in clone:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
		end
	end

	local DEBUG_LOGGING = false

	if DEBUG_LOGGING then
		local rawPivot = clone:GetPivot()
		local rx, ry, rz = rawPivot:ToOrientation()
		print(string.format("[CrateViewportFactory] Raw Model Pivot: Pos=(%.2f, %.2f, %.2f) RotDeg=(%.1f, %.1f, %.1f)",
			rawPivot.Position.X, rawPivot.Position.Y, rawPivot.Position.Z,
			math.deg(rx), math.deg(ry), math.deg(rz)
		))

		local cframe, size = clone:GetBoundingBox()
		local bx, by, bz = cframe:ToOrientation()
		print(string.format("[CrateViewportFactory] BoundingBox: Pos=(%.2f, %.2f, %.2f) RotDeg=(%.1f, %.1f, %.1f) Size=(%.2f, %.2f, %.2f)",
			cframe.Position.X, cframe.Position.Y, cframe.Position.Z,
			math.deg(bx), math.deg(by), math.deg(bz),
			size.X, size.Y, size.Z
		))
	end

	local cframe, size = clone:GetBoundingBox()

	local sphereRadius = 0.5 * math.sqrt(size.X * size.X + size.Y * size.Y + size.Z * size.Z)

	local modelYawCF = CFrame.Angles(0, math.rad(yawDeg), 0)
	local centerTransform = modelYawCF * cframe:Inverse()
	clone:PivotTo(centerTransform * clone:GetPivot())

	if DEBUG_LOGGING then
		local leveledPivot = clone:GetPivot()
		local lx, ly, lz = leveledPivot:ToOrientation()
		print(string.format("[CrateViewportFactory] Leveled & Centered Pivot: Pos=(%.2f, %.2f, %.2f) RotDeg=(%.1f, %.1f, %.1f)",
			leveledPivot.Position.X, leveledPivot.Position.Y, leveledPivot.Position.Z,
			math.deg(lx), math.deg(ly), math.deg(lz)
		))
	end

	local halfFovRad = math.rad(fov * 0.5)
	local distance = (sphereRadius / math.sin(halfFovRad)) * padding

	local elevationRad = math.rad(elevationDeg)
	local targetY = vertOffsetRatio * size.Y
	local cameraPos = Vector3.new(
		0,
		targetY + distance * math.sin(elevationRad),
		distance * math.cos(elevationRad)
	)

	local camera = getCameraTemplate(fov)
	camera.CFrame = CFrame.lookAt(cameraPos, Vector3.new(0, targetY, 0))

	local worldModel = Instance.new("WorldModel")
	clone.Parent = worldModel

	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = if opts.backgroundTransparency ~= nil then opts.backgroundTransparency else 1
	if opts.backgroundColor then
		viewport.BackgroundColor3 = opts.backgroundColor
	end
	viewport.Ambient = ambient
	viewport.LightColor = lightColor
	viewport.LightDirection = lightDir
	worldModel.Parent = viewport
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	return viewport, clone, distance
end

return CrateViewportFactory
