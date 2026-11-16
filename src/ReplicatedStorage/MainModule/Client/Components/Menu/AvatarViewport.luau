--!native
--!optimize 2

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Uniforms = require(MainModule.Shared.Config.Uniforms)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionValue<T> = Types.FusionValue<T>

local peek = Fusion.peek

export type AvatarViewportProps = {
	UniformKey: FusionCanBeState<string?>,
	VariantKey: FusionCanBeState<string?>,
	NoobicSkinColor: FusionValue<boolean>,
	TorsoColor: FusionValue<number>,
	Size: FusionCanBeState<UDim2>?,
	Position: FusionCanBeState<UDim2>?,
	AnchorPoint: FusionCanBeState<Vector2>?,
}

local CAMERA_FOV = 45
local CAMERA_DISTANCE = 9
local CAMERA_ANGLE = 205
local LOOK_AT_HEIGHT = -0.5
local CAMERA_HEIGHT = 0.5
local MIN_ZOOM = 5
local MAX_ZOOM = 13
local ZOOM_SPEED = 0.5
local DRAG_SENSITIVITY = 0.4

local NOOBIC_HEAD_ARM_COLOR = Color3.fromRGB(224, 206, 34)
local NOOBIC_LEG_COLOR = Color3.fromRGB(164, 185, 58)
local TORSO_COLORS: { Color3 } = {
	Color3.fromRGB(18, 102, 172),
	Color3.fromRGB(190, 32, 23),
	Color3.fromRGB(87, 157, 69),
}

type OriginalColors = { head: Color3, torso: Color3, leftArm: Color3, rightArm: Color3, leftLeg: Color3, rightLeg: Color3 }

local function AvatarViewport(scope: FusionScope, props: AvatarViewportProps): Frame
	local worldModel: WorldModel? = nil
	local avatarModel: Model? = nil
	local baseDesc: HumanoidDescription? = nil
	local viewportInstance: ViewportFrame? = nil
	local cameraInstance: Camera? = nil
	local npcPosition = Vector3.zero
	local containerFrame: Frame? = nil
	local isDestroyed = false
	local originalColors: OriginalColors? = nil

	local currentAngle = CAMERA_ANGLE
	local currentDistance = CAMERA_DISTANCE
	local isDragging = false
	local lastMousePos = Vector2.zero

	local dragInputConn: RBXScriptConnection? = nil
	local dragEndConn: RBXScriptConnection? = nil
	local connections: { RBXScriptConnection } = {}

	local function updateCamera()
		if not cameraInstance or not viewportInstance then return end
		local angleRad = math.rad(currentAngle)
		local offset = Vector3.new(
			math.sin(angleRad) * currentDistance,
			CAMERA_HEIGHT,
			math.cos(angleRad) * currentDistance
		)
		local pos = npcPosition + offset
		local lookAt = npcPosition + Vector3.new(0, LOOK_AT_HEIGHT, 0)
		cameraInstance.CFrame = CFrame.new(pos, lookAt)
	end

	local function applyViewportBodyColors()
		if not avatarModel then return end
		local bc = avatarModel:FindFirstChildOfClass("BodyColors")
		if not peek(props.NoobicSkinColor) then
			if not bc or not originalColors then return end
			bc.HeadColor3 = originalColors.head
			bc.TorsoColor3 = originalColors.torso
			bc.LeftArmColor3 = originalColors.leftArm
			bc.RightArmColor3 = originalColors.rightArm
			bc.LeftLegColor3 = originalColors.leftLeg
			bc.RightLegColor3 = originalColors.rightLeg
			return
		end
		if not bc then
			bc = Instance.new("BodyColors")
			bc.Parent = avatarModel
		end
		local torsoIndex = math.clamp(peek(props.TorsoColor), 1, 3)
		bc.HeadColor3 = NOOBIC_HEAD_ARM_COLOR
		bc.LeftArmColor3 = NOOBIC_HEAD_ARM_COLOR
		bc.RightArmColor3 = NOOBIC_HEAD_ARM_COLOR
		bc.TorsoColor3 = TORSO_COLORS[torsoIndex]
		bc.LeftLegColor3 = NOOBIC_LEG_COLOR
		bc.RightLegColor3 = NOOBIC_LEG_COLOR
	end

	local function applyUniformToModel(model: Model, uniformKey: string?, variantKey: string?)
		if not baseDesc then return end
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		local modified = baseDesc:Clone()
		if uniformKey then
			local shirtId, pantId = Uniforms.getClothingIds(uniformKey, variantKey)
			modified.Shirt = shirtId or 0
			modified.Pants = pantId or 0
		end
		pcall(hum.ApplyDescription, hum, modified)
	end

	local function reapplyUniform()
		if not avatarModel then return end
		applyUniformToModel(avatarModel, peek(props.UniformKey), peek(props.VariantKey))
		applyViewportBodyColors()
	end

	local function setupModel(model: Model)
		if isDestroyed or not viewportInstance or not worldModel then return end

		model.Parent = worldModel

		local rootPart = model:FindFirstChild("Torso") :: BasePart?
		if not rootPart then
			rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		end
		if rootPart then
			local pivot = model:GetPivot()
			model:PivotTo(pivot * CFrame.Angles(0, math.rad(180), 0))
			npcPosition = rootPart.Position
		end

		local bc = model:FindFirstChildOfClass("BodyColors")
		if bc then
			originalColors = {
				head = bc.HeadColor3,
				torso = bc.TorsoColor3,
				leftArm = bc.LeftArmColor3,
				rightArm = bc.RightArmColor3,
				leftLeg = bc.LeftLegColor3,
				rightLeg = bc.RightLegColor3,
			}
		end

		if not cameraInstance then
			cameraInstance = Instance.new("Camera")
			cameraInstance.CameraType = Enum.CameraType.Scriptable
			cameraInstance.FieldOfView = CAMERA_FOV
			viewportInstance.CurrentCamera = cameraInstance
			cameraInstance.Parent = viewportInstance
		end

		updateCamera()
		applyViewportBodyColors()
	end

	local function loadAvatar()
		if isDestroyed then return end

		local okDesc, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, LocalPlayer.UserId)
		if not okDesc or not desc then return end
		if isDestroyed then return end

		local okModel, model = pcall(Players.CreateHumanoidModelFromDescription, Players, desc :: HumanoidDescription, Enum.HumanoidRigType.R6)
		if not okModel or not model then return end
		if isDestroyed then
			(model :: Model):Destroy()
			return
		end

		baseDesc = desc :: HumanoidDescription

		local m = model :: Model
		m.Name = "AvatarPreview"

		local humanoid = m:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end

		local scriptToRemove = m:FindFirstChildWhichIsA("BaseScript", true)
		while scriptToRemove do
			scriptToRemove:Destroy()
			scriptToRemove = m:FindFirstChildWhichIsA("BaseScript", true)
		end

		applyUniformToModel(m, peek(props.UniformKey), peek(props.VariantKey))
		avatarModel = m
		setupModel(m)
	end

	local function setupViewport()
		if not viewportInstance then return end
		viewportInstance.Ambient = Color3.fromRGB(180, 185, 195)
		viewportInstance.LightColor = Color3.fromRGB(255, 255, 255)
		viewportInstance.LightDirection = Vector3.new(-0.3, -0.6, -0.5).Unit
		worldModel = Instance.new("WorldModel")
		worldModel.Parent = viewportInstance
		task.spawn(loadAvatar)
	end

	local function stopDrag()
		isDragging = false
		if dragInputConn then
			dragInputConn:Disconnect()
			dragInputConn = nil
		end
		if dragEndConn then
			dragEndConn:Disconnect()
			dragEndConn = nil
		end
	end

	local function startDrag(startPos: Vector2)
		isDragging = true
		lastMousePos = startPos
		stopDrag()

		dragInputConn = UserInputService.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			if not isDragging then return end
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			local delta = pos - lastMousePos
			lastMousePos = pos
			currentAngle -= delta.X * DRAG_SENSITIVITY
			updateCamera()
		end)

		dragEndConn = UserInputService.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				stopDrag()
			end
		end)
	end

	local function cleanup()
		isDestroyed = true
		stopDrag()
		for _, conn in connections do
			conn:Disconnect()
		end
		table.clear(connections)
		if avatarModel then
			avatarModel:Destroy()
			avatarModel = nil
		end
		if worldModel then
			worldModel:Destroy()
			worldModel = nil
		end
		viewportInstance = nil
		cameraInstance = nil
		containerFrame = nil
		originalColors = nil
		baseDesc = nil
	end

	table.insert(scope, cleanup)

	local noobicObserver = scope:Observer(props.NoobicSkinColor)
	local torsoObserver = scope:Observer(props.TorsoColor)
	local uniformObserver = scope:Observer(props.UniformKey)
	local variantObserver = scope:Observer(props.VariantKey)

	noobicObserver:onChange(applyViewportBodyColors)
	torsoObserver:onChange(applyViewportBodyColors)
	uniformObserver:onChange(reapplyUniform)
	variantObserver:onChange(reapplyUniform)

	local function isMouseInContainer(): boolean
		if not containerFrame then return false end
		local mousePos = UserInputService:GetMouseLocation()
		local inset = GuiService:GetGuiInset()
		local pos = containerFrame.AbsolutePosition
		local size = containerFrame.AbsoluteSize
		local relX = mousePos.X - pos.X - inset.X
		local relY = mousePos.Y - pos.Y - inset.Y
		return relX >= 0 and relY >= 0 and relX <= size.X and relY <= size.Y
	end

	local ZOOM_ACTION = "AvatarViewportZoom"
	ContextActionService:BindAction(
		ZOOM_ACTION,
		function(_name: string, _state: Enum.UserInputState, input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseWheel then
				return Enum.ContextActionResult.Pass
			end
			if not isMouseInContainer() then
				return Enum.ContextActionResult.Pass
			end
			if input.Position.Z > 0 then
				currentDistance = math.clamp(currentDistance - ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
			else
				currentDistance = math.clamp(currentDistance + ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
			end
			updateCamera()
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.UserInputType.MouseWheel
	)
	table.insert(scope, function()
		ContextActionService:UnbindAction(ZOOM_ACTION)
	end)

	containerFrame = scope:New("Frame")({
		Name = "AvatarViewportContainer",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.fromScale(0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		ClipsDescendants = true,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
		},
	}) :: Frame

	viewportInstance = Instance.new("ViewportFrame")
	viewportInstance.Name = "AvatarViewport"
	viewportInstance.Size = UDim2.fromScale(1, 1)
	viewportInstance.BackgroundTransparency = 1
	viewportInstance.Parent = containerFrame

	local hitbox = Instance.new("TextButton")
	hitbox.Name = "DragHitbox"
	hitbox.Size = UDim2.fromScale(1, 1)
	hitbox.BackgroundTransparency = 1
	hitbox.Text = ""
	hitbox.ZIndex = 5
	hitbox.Parent = viewportInstance

	table.insert(connections, hitbox.MouseButton1Down:Connect(function()
		local mousePos = UserInputService:GetMouseLocation()
		startDrag(Vector2.new(mousePos.X, mousePos.Y))
	end))

	task.defer(setupViewport)

	return containerFrame
end

return AvatarViewport
