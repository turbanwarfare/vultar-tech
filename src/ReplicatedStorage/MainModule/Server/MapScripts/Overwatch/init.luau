--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
local getHardpointService = LazyService.create(MainModule, "HardpointService")

local Overwatch = {}
Overwatch.Name = "Overwatch"

type GateState = {
	door: BasePart,
	button: BasePart,
	prompt: ProximityPrompt,
	closedPosition: Vector3,
	closedSize: Vector3,
	openPosition: Vector3,
	openSize: Vector3,
	isOpen: boolean,
	activeTween: Tween?,
	connection: RBXScriptConnection?,
}

local RAISE_OFFSET = 25
local SHRINK_Y = 31
local FADE_DURATION = 2.0

local COLOR_CLOSED = BrickColor.new("Lime green")
local COLOR_OPEN = BrickColor.new("Really red")

local VALID_GATE_TYPES: { [string]: boolean } = {
	DefaultGate = true,
	FadeGate = true,
}

local DEFAULT_TWEEN = TweenInfo.new(5.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local FADE_TWEEN = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local gates: { GateState } = {}

local function cancelActiveTween(state: GateState): ()
	if state.activeTween then
		state.activeTween:Cancel()
		state.activeTween = nil
	end
end

local function toggleDefaultGate(state: GateState): ()
	cancelActiveTween(state)

	if state.isOpen then
		state.button.BrickColor = COLOR_CLOSED
		state.prompt.ActionText = "Open Gate"
		state.isOpen = false
		state.activeTween = TweenService:Create(state.door, DEFAULT_TWEEN, {
			Position = state.closedPosition,
			Size = state.closedSize,
		})
	else
		state.button.BrickColor = COLOR_OPEN
		state.prompt.ActionText = "Close Gate"
		state.isOpen = true
		state.activeTween = TweenService:Create(state.door, DEFAULT_TWEEN, {
			Position = state.openPosition,
			Size = state.openSize,
		})
	end

	state.activeTween:Play()
end

local function toggleFadeGate(state: GateState): ()
	cancelActiveTween(state)

	if state.isOpen then
		state.door.CanCollide = true
		state.button.BrickColor = COLOR_CLOSED
		state.prompt.ActionText = "Open Gate"
		state.isOpen = false
		state.activeTween = TweenService:Create(state.door, FADE_TWEEN, { Transparency = 0 })
	else
		state.button.BrickColor = COLOR_OPEN
		state.prompt.ActionText = "Close Gate"
		state.isOpen = true
		state.activeTween = TweenService:Create(state.door, FADE_TWEEN, { Transparency = 1 })
		state.activeTween.Completed:Once(function()
			if state.isOpen then
				state.door.CanCollide = false
			end
		end)
	end

	state.activeTween:Play()
end

local function setupGate(model: Model, gateType: string): ()
	local button = model:FindFirstChild("Button") :: BasePart?
	if not button then
		return
	end

	local door = model:FindFirstChild("Door") :: BasePart?
	if not door then
		return
	end

	local prompt = button:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end

	local state: GateState = {
		door = door,
		button = button,
		prompt = prompt,
		closedPosition = door.Position,
		closedSize = door.Size,
		openPosition = door.Position + Vector3.new(0, RAISE_OFFSET, 0),
		openSize = door.Size + Vector3.new(0, -SHRINK_Y, 0),
		isOpen = false,
		activeTween = nil,
		connection = nil,
	}

	local toggleFn: (typeof(state)) -> () = if gateType == "FadeGate" then toggleFadeGate else toggleDefaultGate

	state.connection = prompt.Triggered:Connect(function(_player: Player)
		if not getHardpointService():IsOfficial() then return end
		toggleFn(state)
	end)

	table.insert(gates, state)
end

local function discoverGates(): ()
	local doorsFolder = workspace:FindFirstChild("Doors") :: Folder?
	if not doorsFolder then
		return
	end

	for _, child in doorsFolder:GetChildren() do
		if child:IsA("Model") and VALID_GATE_TYPES[child.Name] then
			setupGate(child, child.Name)
		end
	end
end

function Overwatch:init(): ()
end

function Overwatch:start(): ()
	discoverGates()
end

function Overwatch:Cleanup(): ()
	for _, state in gates do
		cancelActiveTween(state)
		if state.connection then
			state.connection:Disconnect()
			state.connection = nil
		end
	end
	table.clear(gates)
end

return Overwatch
