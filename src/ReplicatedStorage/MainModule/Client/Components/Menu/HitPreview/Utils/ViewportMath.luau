--!strict
--!native
--!optimize 2


local GuiService = game:GetService("GuiService")

local ViewportMath = {}

local cachedRayParams = RaycastParams.new()
cachedRayParams.FilterType = Enum.RaycastFilterType.Include

function ViewportMath.getOverlayPosition(mousePos: Vector2, containerFrame: Frame): Vector2
	local guiInset = GuiService:GetGuiInset()
	local containerPos = containerFrame.AbsolutePosition
	return mousePos - containerPos - guiInset
end

function ViewportMath.projectToViewport(worldPos: Vector3, camera: Camera, viewport: ViewportFrame): Vector2?
	if not camera or not viewport then
		return nil
	end

	local localPos = camera.CFrame:PointToObjectSpace(worldPos)
	if localPos.Z >= 0 then
		return nil
	end

	local viewportSize = viewport.AbsoluteSize
	local fov = math.rad(camera.FieldOfView)
	local aspectRatio = viewportSize.X / viewportSize.Y
	local tanHalfFov = math.tan(fov / 2)
	local depth = -localPos.Z

	local ndcX = localPos.X / (depth * tanHalfFov * aspectRatio)
	local ndcY = -localPos.Y / (depth * tanHalfFov)

	local screenX = (ndcX + 1) / 2 * viewportSize.X
	local screenY = (ndcY + 1) / 2 * viewportSize.Y

	return Vector2.new(screenX, screenY)
end

function ViewportMath.getNpcHeadScreenPos(
	npcModel: Model,
	camera: Camera,
	viewport: ViewportFrame,
	aboveHeadOffset: number
): Vector2?
	if not npcModel then
		return nil
	end

	local head = npcModel:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end

	local aboveHeadPos = head.Position + Vector3.new(0, aboveHeadOffset, 0)
	return ViewportMath.projectToViewport(aboveHeadPos, camera, viewport)
end

function ViewportMath.isMouseInViewport(mousePos: Vector2, viewport: ViewportFrame): boolean
	local guiInset = GuiService:GetGuiInset()
	local viewportPos = viewport.AbsolutePosition
	local viewportSize = viewport.AbsoluteSize
	local relativePos = mousePos - viewportPos - guiInset

	return relativePos.X >= 0 and relativePos.Y >= 0 and relativePos.X <= viewportSize.X and relativePos.Y <= viewportSize.Y
end

function ViewportMath.raycastViewport(
	mousePos: Vector2,
	camera: Camera,
	worldModel: WorldModel,
	npcModel: Model,
	viewport: ViewportFrame
): (BasePart?, Vector3?)
	if not camera or not worldModel or not npcModel then
		return nil, nil
	end

	local guiInset = GuiService:GetGuiInset()
	local viewportPos = viewport.AbsolutePosition
	local viewportSize = viewport.AbsoluteSize
	local relativePos = mousePos - viewportPos - guiInset

	if relativePos.X < 0 or relativePos.Y < 0 or relativePos.X > viewportSize.X or relativePos.Y > viewportSize.Y then
		return nil, nil
	end

	local normalizedX = (relativePos.X / viewportSize.X) * 2 - 1
	local normalizedY = (relativePos.Y / viewportSize.Y) * 2 - 1

	local fov = math.rad(camera.FieldOfView)
	local aspectRatio = viewportSize.X / viewportSize.Y

	local tanHalfFov = math.tan(fov / 2)
	local directionX = normalizedX * tanHalfFov * aspectRatio
	local directionY = -normalizedY * tanHalfFov
	local directionZ = -1

	local localDirection = Vector3.new(directionX, directionY, directionZ).Unit
	local worldDirection = camera.CFrame:VectorToWorldSpace(localDirection)

	cachedRayParams.FilterDescendantsInstances = { npcModel }

	local rayResult = worldModel:Raycast(camera.CFrame.Position, worldDirection * 100, cachedRayParams)

	if rayResult and rayResult.Instance then
		local hitPart = rayResult.Instance
		if hitPart:IsA("BasePart") then
			return hitPart, rayResult.Position
		end
	end

	return nil, nil
end

return ViewportMath
