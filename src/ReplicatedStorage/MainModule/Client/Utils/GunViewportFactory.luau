--!strict
--!native
--!optimize 2

local GunViewportFactory = {}

export type ViewportConfig = {
	fov: number?,
	distanceMultiplier: number?,
	rotation: CFrame?,
	cameraOffsetX: number?,
	cameraOffsetY: number?,
	ambient: Color3?,
	lightColor: Color3?,
	lightDirection: Vector3?,
	deferCamera: boolean?,
	backgroundColor: Color3?,
	backgroundTransparency: number?,
}

local DEFAULT_ROTATION = CFrame.Angles(0, -math.pi / 2, 0)
local DEFAULT_AMBIENT = Color3.fromRGB(150, 150, 155)
local DEFAULT_LIGHT_DIR = Vector3.new(-0.4, -0.7, -0.5).Unit

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

function GunViewportFactory.create(sourceModel: Model, config: ViewportConfig?): (ViewportFrame, Model, number)
	local cfg = config or {}
	local fov = cfg.fov or 50
	local distMul = cfg.distanceMultiplier or 0.85
	local rotation = cfg.rotation or DEFAULT_ROTATION
	local offsetX = cfg.cameraOffsetX or 0
	local offsetY = cfg.cameraOffsetY or 0
	local ambient = cfg.ambient or DEFAULT_AMBIENT
	local lightColor = cfg.lightColor or Color3.new(1, 1, 1)
	local lightDir = if cfg.lightDirection then cfg.lightDirection.Unit else DEFAULT_LIGHT_DIR
	local deferCamera = if cfg.deferCamera ~= nil then cfg.deferCamera else true

	local clone = sourceModel:Clone()
	local cframe, size = clone:GetBoundingBox()
	local maxDim = math.max(size.X, size.Y, size.Z)

	local pivotOffset = cframe:Inverse() * clone:GetPivot()
	clone:PivotTo(rotation * pivotOffset)

	local distance = maxDim * distMul
	local cameraPos = Vector3.new(distance * offsetX, distance * offsetY, distance)

	local camera = getCameraTemplate(fov)
	camera.CFrame = CFrame.lookAt(cameraPos, Vector3.zero)

	local worldModel = Instance.new("WorldModel")
	clone.Parent = worldModel

	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = if cfg.backgroundTransparency ~= nil then cfg.backgroundTransparency else 1
	if cfg.backgroundColor then
		viewport.BackgroundColor3 = cfg.backgroundColor
	end
	viewport.Ambient = ambient
	viewport.LightColor = lightColor
	viewport.LightDirection = lightDir
	worldModel.Parent = viewport
	camera.Parent = viewport

	if deferCamera then
		task.defer(function()
			if viewport.Parent then
				viewport.CurrentCamera = camera
			end
		end)
	else
		viewport.CurrentCamera = camera
	end

	return viewport, clone, distance
end

return GunViewportFactory
