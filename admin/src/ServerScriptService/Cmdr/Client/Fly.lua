local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MAX_SPEED = 100
local ACCELERATION = 5
local DRAG = 0.95
local DOUBLE_TAP_TIME = 0.3

local stopFlying: (() -> ())? = nil

local Fly = {}

function Fly.SetEnabled(enabled: boolean)
	if stopFlying then
		stopFlying()
	end
	if not enabled then
		return
	end

	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "FlyAttachment"
	attachment.Parent = root

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linearVelocity.MaxForce = math.huge
	linearVelocity.Parent = root

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Attachment0 = attachment
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.MaxTorque = math.huge
	alignOrientation.Responsiveness = 200
	alignOrientation.CFrame = root.CFrame.Rotation
	alignOrientation.Parent = root

	local flying = false
	local speed = Vector3.zero
	local lastSpaceTap = 0

	local function setFlying(value: boolean)
		flying = value
		humanoid.PlatformStand = value
		linearVelocity.Enabled = value
		alignOrientation.Enabled = value
	end

	local connections = {}

	table.insert(connections, RunService.RenderStepped:Connect(function(deltaTime)
		if not flying then
			return
		end

		local cameraCFrame = workspace.CurrentCamera.CFrame
		local frames = deltaTime * 60
		local move = cameraCFrame:VectorToObjectSpace(humanoid.MoveDirection)

		local vertical = 0
		if not UserInputService:GetFocusedTextBox() then
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				vertical = 1
			elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				vertical = -1
			end
		end

		local push = Vector3.new(move.X, vertical, move.Z) * ACCELERATION * frames
		local newSpeed = speed * DRAG ^ frames + push
		speed = Vector3.new(
			math.clamp(newSpeed.X, -MAX_SPEED, MAX_SPEED),
			math.clamp(newSpeed.Y, -MAX_SPEED, MAX_SPEED),
			math.clamp(newSpeed.Z, -MAX_SPEED, MAX_SPEED)
		)

		linearVelocity.VectorVelocity = cameraCFrame:VectorToWorldSpace(speed)
		alignOrientation.CFrame = cameraCFrame.Rotation
	end))

	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.Space or UserInputService:GetFocusedTextBox() then
			return
		end
		if os.clock() - lastSpaceTap < DOUBLE_TAP_TIME then
			setFlying(not flying)
		end
		lastSpaceTap = os.clock()
	end))

	local function stop()
		stopFlying = nil
		for _, connection in connections do
			connection:Disconnect()
		end
		linearVelocity:Destroy()
		alignOrientation:Destroy()
		attachment:Destroy()
		humanoid.PlatformStand = false
	end

	table.insert(connections, humanoid.Died:Connect(stop))
	table.insert(connections, character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			stop()
		end
	end))

	stopFlying = stop
	setFlying(true)
end

return Fly
