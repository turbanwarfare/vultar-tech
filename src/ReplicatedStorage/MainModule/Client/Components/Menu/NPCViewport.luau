--!strict
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
local AvatarViewportLoader = require(MainModule.Client.Utils.AvatarViewportLoader)

local HitPreview = require(script.Parent.HitPreview)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>

local peek = Fusion.peek

export type NPCViewportProps = {
	Size: FusionCanBeState<UDim2>?,
	Position: FusionCanBeState<UDim2>?,
	AnchorPoint: FusionCanBeState<Vector2>?,
	LayoutOrder: number?,
	Visible: FusionCanBeState<boolean>?,
}

local DEFAULT_CAMERA_HEIGHT = 1.2
local CAMERA_FOV = 50

local VIEWPORT_GRADIENT_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.7, 0.8),
	NumberSequenceKeypoint.new(1, 0.4),
})
local MIN_ZOOM = 4
local MAX_ZOOM = 12
local ZOOM_SPEED = 0.5
local CAMERA_DISTANCE = 7
local CAMERA_ANGLE = 205
local LOOK_AT_HEIGHT = 0.2

local viewportCount = 0

local function NPCViewport(scope: FusionScope, props: NPCViewportProps): Frame
	local worldModel: WorldModel? = nil
	local avatarModel: Model? = nil
	local viewport: ViewportFrame? = nil
	local camera: Camera? = nil
	local npcPosition: Vector3 = Vector3.zero
	local hitPreviewInstance: HitPreview.HitPreviewInstance? = nil
	local containerFrame: Frame? = nil

	local currentAngle = CAMERA_ANGLE
	local currentDistance = CAMERA_DISTANCE

	local connections: { RBXScriptConnection } = {}
	local isDestroyed = false
	local isLoadingAvatar = false

	local function updateCamera()
		if not camera or not viewport then
			return
		end

		local angleRad = math.rad(currentAngle)
		local cameraOffset = Vector3.new(
			math.sin(angleRad) * currentDistance,
			DEFAULT_CAMERA_HEIGHT,
			math.cos(angleRad) * currentDistance
		)
		local cameraPosition = npcPosition + cameraOffset
		local lookAt = npcPosition + Vector3.new(0, LOOK_AT_HEIGHT, 0)

		camera.CFrame = CFrame.new(cameraPosition, lookAt)
	end

	local function loadAvatarModel(): Model?
		local player = LocalPlayer
		if not player then
			return nil
		end
		return AvatarViewportLoader.loadCachedFromUserId(player.UserId)
	end

	local function setHitPreviewEnabled(enabled: boolean)
		if enabled == (hitPreviewInstance ~= nil) then
			return
		end
		if hitPreviewInstance then
			hitPreviewInstance.destroy()
			hitPreviewInstance = nil
			return
		end
		if viewport and worldModel and camera and avatarModel and containerFrame then
			hitPreviewInstance = HitPreview.create(viewport, worldModel, camera, avatarModel, containerFrame)
		end
	end

	local function setupAvatarInViewport(model: Model)
		if isDestroyed or not viewport or not worldModel then
			return
		end

		model.Parent = worldModel

		local rootPart = model:FindFirstChild("Torso") :: BasePart?
		if not rootPart then
			rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		end
		if not rootPart then
			rootPart = model.PrimaryPart
		end
		if not rootPart then
			rootPart = model:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
		end

		if rootPart then
			local currentPivot = model:GetPivot()
			model:PivotTo(currentPivot * CFrame.Angles(0, math.rad(180), 0))
			npcPosition = rootPart.Position

			if not camera then
				camera = Instance.new("Camera")
				camera.CameraType = Enum.CameraType.Scriptable
				camera.FieldOfView = CAMERA_FOV
				viewport.CurrentCamera = camera
				camera.Parent = viewport
			end

			updateCamera()
		end

		if containerFrame and camera then
			if hitPreviewInstance then
				hitPreviewInstance.destroy()
				hitPreviewInstance = nil
			end
			setHitPreviewEnabled(props.Visible == nil or peek(props.Visible) == true)
		end
	end

	local function refreshAvatar()
		if isDestroyed or not viewport or not worldModel or isLoadingAvatar then
			return
		end

		if avatarModel then
			if hitPreviewInstance then
				hitPreviewInstance.destroy()
				hitPreviewInstance = nil
			end
			avatarModel:Destroy()
			avatarModel = nil
		end

		isLoadingAvatar = true
		local newModel = loadAvatarModel()
		isLoadingAvatar = false
		if newModel then
			avatarModel = newModel
			setupAvatarInViewport(newModel)
		end
	end

	local function setupViewport()
		if not viewport then
			return
		end

		viewport.Ambient = Color3.fromRGB(180, 185, 195)
		viewport.LightColor = Color3.fromRGB(255, 255, 255)
		viewport.LightDirection = Vector3.new(-0.3, -0.6, -0.5).Unit

		worldModel = Instance.new("WorldModel")
		worldModel.Parent = viewport

		refreshAvatar()

		local player = LocalPlayer
		if player then
			local function onCharacterForAppearance(character: Model)
				if not character:IsDescendantOf(game) then
					character.AncestryChanged:Wait()
				end
				while not player:HasAppearanceLoaded() do
					task.wait(0.1)
				end
				if not avatarModel then
					task.defer(refreshAvatar)
				end
			end

			if player.Character then
				task.spawn(onCharacterForAppearance, player.Character)
			end
			local conn = player.CharacterAdded:Connect(onCharacterForAppearance)
			table.insert(connections, conn)
		end
	end

	local function isMouseInContainer(): boolean
		if not containerFrame then return false end
		local mousePos = UserInputService:GetMouseLocation()
		local guiInset = GuiService:GetGuiInset()
		local pos = containerFrame.AbsolutePosition
		local size = containerFrame.AbsoluteSize
		local relX = mousePos.X - pos.X - guiInset.X
		local relY = mousePos.Y - pos.Y - guiInset.Y
		return relX >= 0 and relY >= 0 and relX <= size.X and relY <= size.Y
	end

	local function onZoomIn()
		currentDistance = math.clamp(currentDistance - ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		updateCamera()
	end

	local function onZoomOut()
		currentDistance = math.clamp(currentDistance + ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		updateCamera()
	end

	local function cleanup()
		isDestroyed = true

		for _, conn in connections do
			conn:Disconnect()
		end
		table.clear(connections)

		if hitPreviewInstance then
			hitPreviewInstance.destroy()
			hitPreviewInstance = nil
		end
		if avatarModel then
			avatarModel:Destroy()
			avatarModel = nil
		end
		if worldModel then
			worldModel:Destroy()
			worldModel = nil
		end
		viewport = nil
		camera = nil
		containerFrame = nil
	end

	table.insert(scope, cleanup)

	viewportCount += 1
	local zoomActionName = `NPCViewportZoom{viewportCount}`
	local isZoomBound = false

	local function setZoomBound(bound: boolean)
		if bound == isZoomBound then
			return
		end
		isZoomBound = bound
		if not bound then
			ContextActionService:UnbindAction(zoomActionName)
			return
		end
		ContextActionService:BindAction(
			zoomActionName,
			function(_actionName: string, _inputState: Enum.UserInputState, inputObject: InputObject)
				if inputObject.UserInputType == Enum.UserInputType.MouseWheel then
					if isMouseInContainer() then
						if inputObject.Position.Z > 0 then
							onZoomIn()
						else
							onZoomOut()
						end
						return Enum.ContextActionResult.Sink
					end
				end
				return Enum.ContextActionResult.Pass
			end,
			false,
			Enum.UserInputType.MouseWheel
		)
	end

	table.insert(scope, function()
		setZoomBound(false)
	end)

	containerFrame = scope:New("Frame")({
		Name = "NPCViewportContainer",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.fromScale(0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Theme.Card.Background,
		BackgroundTransparency = 0.6,
		LayoutOrder = props.LayoutOrder or 0,
		ClipsDescendants = true,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Large,
			}),

			scope:New("UIStroke")({
				Color = Theme.Border.Default,
				Thickness = 1,
				Transparency = 0.65,
			}),

			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			}),
		},
	}) :: Frame

	viewport = Instance.new("ViewportFrame")
	viewport.Name = "NPCViewport"
	viewport.Size = UDim2.new(1, 0, 1, -68)
	viewport.Position = UDim2.fromOffset(0, 62)
	viewport.BackgroundColor3 = Theme.Background.Secondary
	viewport.BackgroundTransparency = 0.7
	viewport.Parent = containerFrame

	local viewportCorner = Instance.new("UICorner")
	viewportCorner.CornerRadius = Theme.Radius.Medium
	viewportCorner.Parent = viewport

	local viewportStroke = Instance.new("UIStroke")
	viewportStroke.Color = Theme.Border.Default
	viewportStroke.Thickness = 1
	viewportStroke.Transparency = 0.8
	viewportStroke.Parent = viewport

	local _headerFrame = scope:New("Frame")({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Theme.Background.Overlay,
		BackgroundTransparency = 0.6,
		Parent = containerFrame,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Medium,
			}),

			scope:New("TextLabel")({
				Name = "Title",
				Size = UDim2.new(1, 0, 0, 24),
				Position = UDim2.new(0.5, 0, 0, 8),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Text = "SETTINGS PREVIEW",
				TextColor3 = Theme.Foreground.Primary,
				TextSize = 18,
				Font = Enum.Font.GothamBold,
			}),

			scope:New("TextLabel")({
				Name = "Subtitle",
				Size = UDim2.new(1, -16, 0, 18),
				Position = UDim2.new(0.5, 0, 0, 32),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Text = "Shoot the NPC and test your settings",
				TextColor3 = Theme.Foreground.Tertiary,
				TextSize = 13,
				Font = Enum.Font.GothamMedium,
			}),
		},
	})

	local _bottomGradient = scope:New("Frame")({
		Name = "BottomGradient",
		Size = UDim2.fromScale(1, 0.2),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Theme.Background.Primary,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = viewport,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Medium,
			}),

			scope:New("UIGradient")({
				Transparency = VIEWPORT_GRADIENT_TRANSPARENCY,
				Rotation = 90,
			}),
		},
	})

	local interactionFrame = Instance.new("Frame")
	interactionFrame.Name = "InteractionLayer"
	interactionFrame.Size = UDim2.fromScale(1, 1)
	interactionFrame.BackgroundTransparency = 1
	interactionFrame.ZIndex = 10
	interactionFrame.Parent = viewport

	local hasLoadedAvatar = false

	local function lazyLoadAvatar()
		if hasLoadedAvatar then
			return
		end
		hasLoadedAvatar = true
		task.defer(setupViewport)
	end

	if props.Visible then
		local visibleObserver = scope:Observer(props.Visible)
		visibleObserver:onBind(function()
			local visible = peek(props.Visible) == true
			if visible then
				lazyLoadAvatar()
			end
			setZoomBound(visible)
			setHitPreviewEnabled(visible)
		end)
	else
		task.defer(setupViewport)
		hasLoadedAvatar = true
		setZoomBound(true)
	end

	return containerFrame
end

return NPCViewport
