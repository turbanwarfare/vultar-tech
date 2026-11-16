--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AimChamberRecorder = {}
local isRecording = false
local anchorCFrame: CFrame? = nil
local startTime = 0
local frames: { { Position: Vector3, Crouching: boolean, Jumping: boolean, Time: number } } = {}
local updateConnection: RBXScriptConnection? = nil

local function getCharacter(): Model?
	local player = Players.LocalPlayer
	return player and player.Character
end

local function recordTick()
	local char = getCharacter()
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end

	local anchor = anchorCFrame
	if not anchor then return end

	local now = os.clock()
	local elapsed = now - startTime

	local lastFrame = frames[#frames]
	if lastFrame and (elapsed - lastFrame.Time) < 0.033 then
		return
	end

	local relativePos = anchor:PointToObjectSpace(root.Position)
	local crouching = char:GetAttribute("Crouching") == true
	local jumping = hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall

	table.insert(frames, {
		Position = relativePos,
		Crouching = crouching,
		Jumping = jumping,
		Time = elapsed,
	})
end

function AimChamberRecorder.startRecording()
	if isRecording then return end
	local char = getCharacter()
	if not char then
		warn("[AimChamberRecorder] Character not found!")
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		warn("[AimChamberRecorder] HumanoidRootPart not found!")
		return
	end

	isRecording = true
	anchorCFrame = root.CFrame
	startTime = os.clock()
	table.clear(frames)

	print("[AimChamberRecorder] STARTED recording. Press L or use UI to stop.")

	updateConnection = RunService.PreSimulation:Connect(recordTick)
end

function AimChamberRecorder.isCurrentlyRecording()
	return isRecording
end

function AimChamberRecorder.getFrameCount()
	return #frames
end

function AimChamberRecorder.getFormattedChunks(): { string }
	if #frames == 0 then
		return {}
	end

	local buffer = { "{\n" }
	for i, frame in frames do
		table.insert(buffer, string.format("\t{ Position = Vector3.new(%.3f, %.3f, %.3f), Crouching = %s, Jumping = %s, Time = %.3f },\n",
			frame.Position.X, frame.Position.Y, frame.Position.Z,
			tostring(frame.Crouching), tostring(frame.Jumping), frame.Time
		))
		if i % 100 == 0 then
			table.insert(buffer, "}--CHUNK_SPLIT--{\n")
		end
	end
	table.insert(buffer, "}")

	local fullString = table.concat(buffer)
	return string.split(fullString, "--CHUNK_SPLIT--")
end

function AimChamberRecorder.stopRecording()
	if not isRecording then return end
	isRecording = false

	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	print("[AimChamberRecorder] STOPPED recording. Total frames:", #frames)

	if #frames == 0 then
		print("[AimChamberRecorder] No frames recorded.")
		return {}
	end

	return AimChamberRecorder.getFormattedChunks()
end

function AimChamberRecorder.getElapsedTime(): number
	if not isRecording then
		if #frames > 0 then
			return frames[#frames].Time
		end
		return 0
	end
	return os.clock() - startTime
end

function AimChamberRecorder.start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if UserInputService:GetFocusedTextBox() then return end

		if input.KeyCode == Enum.KeyCode.K then
			AimChamberRecorder.startRecording()
		elseif input.KeyCode == Enum.KeyCode.L then
			AimChamberRecorder.stopRecording()
		end
	end)
end

return AimChamberRecorder
