--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)

type DoorPartState = {
	Part: BasePart,
	ClosedPosition: Vector3,
	OpenHeight: number,
}

type DoorState = {
	Model: Instance,
	DoorParts: { DoorPartState },
	Buttons: { BasePart },
	Prompts: { ProximityPrompt },
	TweenDuration: number,
	IsOpen: boolean,
	ActiveTweens: { Tween },
}

local DoorController = {}

local doorsByInstance: { [Instance]: DoorState } = {}
local doorsByName: { [string]: DoorState } = {}
local promptConnections: { RBXScriptConnection } = {}

local DEFAULT_TWEEN_DURATION = 1
local BUTTON_COLOR_OPEN = Color3.fromRGB(0, 200, 0)
local BUTTON_COLOR_CLOSED = Color3.fromRGB(200, 0, 0)
local tweenInfoCache: { [number]: TweenInfo } = {}

local function collectDoorParts(doorModel: Instance): { DoorPartState }
	local parts: { DoorPartState } = {}

	for _, desc in doorModel:GetDescendants() do
		if not desc:IsA("BasePart") then continue end

		local openHeight = desc:GetAttribute("OpenHeight")
		if not openHeight then continue end

		local part = desc :: BasePart
		table.insert(parts, {
			Part = part,
			ClosedPosition = part.Position,
			OpenHeight = openHeight :: number,
		})
	end

	return parts
end

local function collectButtonsAndPrompts(doorModel: Instance): ({ BasePart }, { ProximityPrompt })
	local buttons: { BasePart } = {}
	local prompts: { ProximityPrompt } = {}

	for _, desc in doorModel:GetDescendants() do
		if desc:IsA("BasePart") and desc.Name == "Button" then
			table.insert(buttons, desc)
		elseif desc:IsA("ProximityPrompt") then
			table.insert(prompts, desc)
		end
	end

	return buttons, prompts
end

local function updateButtonAppearance(doorState: DoorState): ()
	local color = if doorState.IsOpen then BUTTON_COLOR_OPEN else BUTTON_COLOR_CLOSED
	local actionText = if doorState.IsOpen then "[Close]" else "[Open]"

	for _, button in doorState.Buttons do
		button.Color = color
	end
	for _, prompt in doorState.Prompts do
		prompt.ActionText = actionText
	end
end

local function tweenDoor(state: DoorState, shouldOpen: boolean): ()
	for _, tween in state.ActiveTweens do
		tween:Cancel()
	end
	table.clear(state.ActiveTweens)

	state.IsOpen = shouldOpen
	updateButtonAppearance(state)

	for _, doorPart in state.DoorParts do
		local targetPosition = if shouldOpen
			then doorPart.ClosedPosition + Vector3.new(0, doorPart.OpenHeight, 0)
			else doorPart.ClosedPosition

		local cachedInfo = tweenInfoCache[state.TweenDuration]
		if not cachedInfo then
			cachedInfo = TweenInfo.new(state.TweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			tweenInfoCache[state.TweenDuration] = cachedInfo
		end
		local tween = TweenService:Create(doorPart.Part, cachedInfo, { Position = targetPosition })

		tween.Completed:Once(function()
			for i, t in state.ActiveTweens do
				if t == tween then
					local lastIdx = #state.ActiveTweens
					if i < lastIdx then
						state.ActiveTweens[i] = state.ActiveTweens[lastIdx]
					end
					state.ActiveTweens[lastIdx] = nil
					break
				end
			end
		end)

		table.insert(state.ActiveTweens, tween)
		tween:Play()
	end

	Network.Phase.broadcastDoorState({
		DoorName = state.Model.Name,
		IsOpen = shouldOpen,
	})
end

function DoorController.init(): ()
	local doorsFolder = workspace:FindFirstChild("Doors")
	if not doorsFolder then return end

	for _, doorModel in doorsFolder:GetChildren() do
		local doorParts = collectDoorParts(doorModel)
		local tweenDuration = doorModel:GetAttribute("OpenTime") or DEFAULT_TWEEN_DURATION
		local buttons, prompts = collectButtonsAndPrompts(doorModel)

		local state: DoorState = {
			Model = doorModel,
			DoorParts = doorParts,
			Buttons = buttons,
			Prompts = prompts,
			TweenDuration = tweenDuration,
			IsOpen = false,
			ActiveTweens = {},
		}

		doorsByInstance[doorModel] = state
		doorsByName[doorModel.Name] = state
		updateButtonAppearance(state)

		for _, prompt in prompts do
			prompt.Enabled = false
		end

		if #doorParts == 0 then continue end

		for _, prompt in prompts do
			local conn = prompt.Triggered:Connect(function(player: Player)
				local character = player.Character
				if not character then return end
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if not humanoid or humanoid.Health <= 0 then return end
				tweenDoor(state, not state.IsOpen)
			end)
			table.insert(promptConnections, conn)
		end
	end
end

function DoorController.toggleDoor(doorName: string, forceOpen: boolean?): ()
	local state = doorsByName[doorName]
	if not state then return end

	local shouldOpen = if forceOpen ~= nil then forceOpen else not state.IsOpen
	if shouldOpen == state.IsOpen then return end

	tweenDoor(state, shouldOpen)
end

function DoorController.isDoorOpen(doorName: string): boolean
	local state = doorsByName[doorName]
	if not state then return false end
	return state.IsOpen
end

function DoorController.setPromptEnabled(doorName: string, enabled: boolean): ()
	local state = doorsByName[doorName]
	if not state then return end

	for _, prompt in state.Prompts do
		prompt.Enabled = enabled
	end
end

function DoorController.setAllPromptsEnabled(enabled: boolean): ()
	for _, doorState in doorsByInstance do
		for _, prompt in doorState.Prompts do
			prompt.Enabled = enabled
		end
	end
end

function DoorController.cleanup(): ()
	for _, conn in promptConnections do
		conn:Disconnect()
	end
	table.clear(promptConnections)

	for _, state in doorsByInstance do
		for _, tween in state.ActiveTweens do
			tween:Cancel()
		end
		for _, doorPart in state.DoorParts do
			doorPart.Part.Position = doorPart.ClosedPosition
		end
		state.IsOpen = false
		updateButtonAppearance(state)
	end

	table.clear(doorsByInstance)
	table.clear(doorsByName)
end

return DoorController
