--!strict
--!native
--!optimize 2

local HitDots = {}

local BODY_PART_NAMES: { string } = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local R6_OFFSETS: { [string]: CFrame } = {
	Head = CFrame.new(0, 1.5, 0),
	["Left Arm"] = CFrame.new(-1.5, 0, 0),
	["Right Arm"] = CFrame.new(1.5, 0, 0),
	["Left Leg"] = CFrame.new(-0.5, -2, 0),
	["Right Leg"] = CFrame.new(0.5, -2, 0),
}

local CAM_DIST = 7.5
local CAM_UP = 1.0
local CAM_LOOK = 0.1
local CAM_FOV = 50

function HitDots.bodyPartName(index: number): string
	return BODY_PART_NAMES[index] or "Torso"
end

function HitDots.prepareAvatar(model: Model): ()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	for _, desc in model:GetDescendants() do
		if desc:IsA("BaseScript") or desc:IsA("Sound") or desc:IsA("Tool") or desc:IsA("BallSocketConstraint") then
			desc:Destroy()
		end
	end

	local torso = model:FindFirstChild("Torso") :: BasePart?
	if torso then
		local torsoCF = CFrame.new(torso.Position)
		torso.CFrame = torsoCF
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.CFrame = torsoCF
		end
		for partName, offset in R6_OFFSETS do
			local part = model:FindFirstChild(partName) :: BasePart?
			if part then
				part.CFrame = torsoCF * offset
			end
		end
	end

	model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.pi, 0))
end

function HitDots.aimCamera(camera: Camera, model: Model): CFrame?
	local root = model:FindFirstChild("Torso") :: BasePart? or model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end

	local center = root.Position
	local camCF = CFrame.new(center + Vector3.new(0, CAM_UP, -CAM_DIST), center + Vector3.new(0, CAM_LOOK, 0))
	camera.FieldOfView = CAM_FOV
	camera.CFrame = camCF
	return camCF
end

local function mirrorToFront(hitWorldPos: Vector3, partCenter: Vector3, camPos: Vector3): Vector3
	local toCamera = (camPos - partCenter).Unit
	local offset = hitWorldPos - partCenter
	if offset:Dot(toCamera) < 0 then
		return partCenter + offset - 2 * offset:Dot(toCamera) * toCamera
	end
	return hitWorldPos
end

function HitDots.project(
	model: Model,
	camCF: CFrame,
	bodyPart: number,
	localOffset: Vector3,
	frameWidth: number,
	frameHeight: number
): (number, number, boolean)
	local part = model:FindFirstChild(HitDots.bodyPartName(bodyPart)) :: BasePart? or model:FindFirstChild("Torso") :: BasePart?
	if not part then
		return 0, 0, false
	end

	local hitWorld = (part.CFrame * CFrame.new(localOffset)).Position
	local worldPos = mirrorToFront(hitWorld, part.Position, camCF.Position)

	local localPos = camCF:PointToObjectSpace(worldPos)
	if localPos.Z >= 0 then
		return 0, 0, false
	end

	local aspect = frameWidth / frameHeight
	local halfTan = math.tan(math.rad(CAM_FOV) / 2)
	local depth = -localPos.Z
	local sx = (-localPos.X / (depth * halfTan * aspect)) * 0.5 + 0.5
	local sy = (-localPos.Y / (depth * halfTan)) * 0.5 + 0.5

	local visible = sx >= -0.1 and sx <= 1.1 and sy >= -0.1 and sy <= 1.1
	return sx * frameWidth, sy * frameHeight, visible
end

return HitDots
