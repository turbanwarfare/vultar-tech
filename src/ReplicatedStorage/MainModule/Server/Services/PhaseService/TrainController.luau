--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)

local GameState = require(script.Parent.GameState)
type State = GameState.GameState

local TRAIN_WAIT_BEFORE_ARRIVAL = 18
local TRAIN_MOVE_DELAY = 1
local TRAIN_TRAVEL_TIME = 4
local TRAIN_STOP_DURATION = 2.5
local TRAIN_EXIT_TRAVEL_TIME = 6
local TRAIN_ORIENTATION = CFrame.Angles(math.rad(-0.014), math.rad(90), math.rad(0))

local TrainController = {}

function TrainController.runTrainSequence(state: State, getModelsService: () -> any?, broadcastMessage: (message: string) -> ()): ()
	local trainFolder = workspace:FindFirstChild("Train")
	if not trainFolder then
		state.waitingForTrainDelivery = false
		return
	end

	local startWaypoint = trainFolder:FindFirstChild("Start") :: BasePart?
	local stopWaypoint = trainFolder:FindFirstChild("Stop") :: BasePart?
	local endWaypoint = trainFolder:FindFirstChild("End") :: BasePart?

	if not startWaypoint or not stopWaypoint or not endWaypoint then
		state.waitingForTrainDelivery = false
		return
	end

	task.wait(TRAIN_WAIT_BEFORE_ARRIVAL)

	if not state.official or not state.waitingForTrainDelivery then
		state.waitingForTrainDelivery = false
		return
	end

	local modelsSvc = getModelsService()
	if not modelsSvc then
		state.waitingForTrainDelivery = false
		return
	end

	local trainModel = modelsSvc:Clone("Train")
	if not trainModel then
		state.waitingForTrainDelivery = false
		return
	end

	local startCFrame = startWaypoint.CFrame * TRAIN_ORIENTATION
	local stopCFrame = stopWaypoint.CFrame * TRAIN_ORIENTATION
	local endCFrame = endWaypoint.CFrame * TRAIN_ORIENTATION

	if trainModel:IsA("Model") then
		trainModel:PivotTo(startCFrame)
	end
	trainModel.Parent = trainFolder

	local primaryPart = if trainModel:IsA("Model") then trainModel.PrimaryPart else nil
	if primaryPart then
		local sound = primaryPart:FindFirstChild("TrainMovementSound") :: Sound?
		if sound then
			sound:Play()
		end
	end

	Network.Phase.broadcastTrainMovement({
		StartPosition = startCFrame,
		TargetPosition = stopCFrame,
		Delay = TRAIN_MOVE_DELAY,
		TravelTime = TRAIN_TRAVEL_TIME,
	})

	task.wait(TRAIN_MOVE_DELAY + TRAIN_TRAVEL_TIME)

	if trainModel:IsA("Model") then
		trainModel:PivotTo(stopCFrame)
	end

	task.wait(TRAIN_STOP_DURATION)

	broadcastMessage("THE TRAIN HAS DELIVERED THE PAYLOAD!")
	state.waitingForTrainDelivery = false

	Network.Phase.broadcastTrainMovement({
		StartPosition = stopCFrame,
		TargetPosition = endCFrame,
		Delay = 0,
		TravelTime = TRAIN_EXIT_TRAVEL_TIME,
	})

	task.wait(TRAIN_EXIT_TRAVEL_TIME)
	trainModel:Destroy()
end

return TrainController
