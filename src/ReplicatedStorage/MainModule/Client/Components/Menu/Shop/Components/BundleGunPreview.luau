--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)

local SkinModelCache = require(script.Parent.Parent.Cache.SkinModelCache)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

local cameraTemplate: Camera = Instance.new("Camera")
cameraTemplate.CameraType = Enum.CameraType.Scriptable
cameraTemplate.FieldOfView = 50

export type BundleGunPreviewProps = {
	SkinId: string,
	GunName: string,
	Size: UDim2,
	Position: UDim2,
	AnchorPoint: Vector2?,
	Rotation: number?,
	ZIndex: number?,
}

local function BundleGunPreview(scope: FusionScope, props: BundleGunPreviewProps): Frame
	local model = SkinModelCache.getModel(props.SkinId, props.GunName)

	local viewportChildren: { Instance } = {}

	if model then
		local worldModel = Instance.new("WorldModel")
		local clonedModel = model:Clone()
		local _, size = clonedModel:GetBoundingBox()
		local maxDim = math.max(size.X, size.Y, size.Z)

		local tiltAngle = math.rad(35)
		local rightTilt = math.rad(15)
		clonedModel:PivotTo(
			CFrame.Angles(0, -math.pi / 2, 0)
			* CFrame.Angles(0, 0, tiltAngle)
			* CFrame.Angles(0, rightTilt, 0)
		)
		clonedModel.Parent = worldModel

		local camera = cameraTemplate:Clone()
		local distance = maxDim * 0.65
		camera.CFrame = CFrame.lookAt(
			Vector3.new(distance * 0.1, distance * 0.05, distance),
			Vector3.zero
		)

		table.insert(viewportChildren, worldModel)
		table.insert(viewportChildren, camera)

		task.defer(function()
			local viewport = worldModel.Parent
			if viewport and viewport:IsA("ViewportFrame") then
				viewport.CurrentCamera = camera
			end
		end)
	end

	return scope:New("Frame")({
		Name = "GunPreviewContainer",
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		Rotation = props.Rotation or 0,
		ZIndex = props.ZIndex or 1,

		[Fusion.Children] = {
			scope:New("ViewportFrame")({
				Name = "GunViewport",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Ambient = Color3.fromRGB(140, 140, 145),
				LightColor = Color3.fromRGB(255, 255, 255),
				LightDirection = Vector3.new(-0.5, -0.8, -0.3).Unit,

				[Fusion.Children] = viewportChildren,
			}),
		},
	})
end

return BundleGunPreview
