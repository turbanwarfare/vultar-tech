--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Root = script:FindFirstAncestor("Client").Parent
local MainModule = require(Root.Shared.Game).get()
local SWTypes = require(Root.Shared.Network.Types)
local Packages = MainModule:WaitForChild("Packages", 5)
local Trove = require(Packages:WaitForChild("Trove", 5))
local ScreenWatchConfig = require(Root.Shared.Config)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local Network = { ScreenWatch = require(Root.Shared.Network) }

local function getCurrentCamera(): Camera?
	return workspace.CurrentCamera
end

local DEFAULT_CURSOR_ID = "rbxassetid://131581677"

local cachedRaycastParams = RaycastParams.new()
cachedRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
local charFilterTable: { Instance } = table.create(1)

local ScreenWatchTarget = {}

local activeTrove: any = nil
local isCapturing = false

local KEY_NAME_MAP: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.W] = "W",
	[Enum.KeyCode.A] = "A",
	[Enum.KeyCode.S] = "S",
	[Enum.KeyCode.D] = "D",
	[Enum.KeyCode.F] = "SPRINT",
	[Enum.KeyCode.C] = "CROUCH",
	[Enum.KeyCode.Q] = "ZOOM",
	[Enum.KeyCode.R] = "RELOAD",
	[Enum.KeyCode.Space] = "SPACE",
}

local MOUSE_BUTTON_MAP: { [Enum.UserInputType]: string } = {
	[Enum.UserInputType.MouseButton1] = "LMB",
	[Enum.UserInputType.MouseButton2] = "RMB",
}

local function resolveMouseBehaviorString(behavior: Enum.MouseBehavior): SWTypes.MouseBehaviorMode
	if behavior == Enum.MouseBehavior.LockCenter then
		return "LockCenter"
	elseif behavior == Enum.MouseBehavior.LockCurrentPosition then
		return "LockCurrentPosition"
	end
	return "Default"
end

local function isKeyFlagged(keyCode: Enum.KeyCode): boolean
	return table.find(ScreenWatchConfig.FlaggedKeycodes, keyCode) ~= nil
end

local function getTargetMovementState(localPlayer: Player): (boolean, boolean)
	local char = localPlayer.Character
	local isSprinting = false
	local isCrouching = false

	if char then
		isSprinting = char:GetAttribute("Sprinting") == true
		isCrouching = char:GetAttribute("Crouching") == true
	end

	if not isSprinting or not isCrouching then
		local movement = ServiceLocator.Movement()
		if movement then
			if not isSprinting and typeof(movement.IsSprinting) == "function" then
				isSprinting = movement:IsSprinting()
			end
			if not isCrouching and typeof(movement.IsCrouching) == "function" then
				isCrouching = movement:IsCrouching()
			end
		end
	end

	return isSprinting, isCrouching
end

function ScreenWatchTarget.startCapture(config: SWTypes.ConfigPayload): ()
	if isCapturing then
		ScreenWatchTarget.stopCapture()
	end

	isCapturing = true
	local trove = Trove.new()
	activeTrove = trove

	local cameraInterval = 1 / math.max(config.cameraSampleHz or 60, 1)
	local cursorInterval = 1 / math.max(config.cursorSampleHz or 60, 1)

	local lastCamTime = 0
	local lastCursorTime = 0

	local localPlayer = Players.LocalPlayer

	trove:Add(RunService.RenderStepped:Connect(function()
		local cam = getCurrentCamera()
		if not cam then
			return
		end

		local now = os.clock()
		local currentBehavior = UserInputService.MouseBehavior
		local isSprinting, isCrouching = getTargetMovementState(localPlayer)

		local vpSize = cam.ViewportSize
		local activeMousePos = if currentBehavior == Enum.MouseBehavior.LockCenter
			then Vector2.new(vpSize.X * 0.5, vpSize.Y * 0.5)
			else UserInputService:GetMouseLocation()

		if now - lastCamTime >= cameraInterval then
			lastCamTime = now

			local currentCF = cam.CFrame
			local currentFOV = cam.FieldOfView

			local mouseRay = cam:ViewportPointToRay(activeMousePos.X, activeMousePos.Y)
			local myChar = localPlayer.Character
			if myChar then
				charFilterTable[1] = myChar
				cachedRaycastParams.FilterDescendantsInstances = charFilterTable
			else
				table.clear(charFilterTable)
				cachedRaycastParams.FilterDescendantsInstances = charFilterTable
			end
			local rayHit = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 2000, cachedRaycastParams)
			local mouseHit = if rayHit then rayHit.Position else (mouseRay.Origin + mouseRay.Direction * 1000)

			local ghostCandidates: { SWTypes.GhostEntry } = {}
			local cameraPos = currentCF.Position
			local maxGhostDistSq = 350 * 350

			for _, player in Players:GetPlayers() do
				if player == localPlayer then
					continue
				end

				local char = player.Character
				if not char then
					continue
				end

				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = char:FindFirstChildOfClass("Humanoid")
				if not root or not humanoid or humanoid.Health <= 0 then
					continue
				end

				local rootPos = root.Position
				local diff = rootPos - cameraPos
				local distSq = diff.X * diff.X + diff.Y * diff.Y + diff.Z * diff.Z
				if distSq > maxGhostDistSq then
					continue
				end

				local _, onScreen = cam:WorldToViewportPoint(rootPos)
				if onScreen then
					table.insert(ghostCandidates, {
						characterId = player.UserId,
						cframe = root.CFrame,
					})
					if #ghostCandidates >= 16 then
						break
					end
				end
			end

			Network.ScreenWatch.sendCameraStreamTarget({
				cframe = currentCF,
				fov = currentFOV,
				viewportSize = vpSize,
				mouseHit = mouseHit,
				timestamp = now,
				mouseBehavior = resolveMouseBehaviorString(currentBehavior),
				isSprinting = isSprinting,
				isCrouching = isCrouching,
			})

			Network.ScreenWatch.sendGhostStreamTarget({
				ghosts = ghostCandidates,
				timestamp = now,
			})
		end

		if now - lastCursorTime >= cursorInterval then
			lastCursorTime = now

			local normX = if currentBehavior == Enum.MouseBehavior.LockCenter
				then 0.5
				else if vpSize.X > 0 then math.clamp(activeMousePos.X / vpSize.X, 0, 1) else 0.5
			local normY = if currentBehavior == Enum.MouseBehavior.LockCenter
				then 0.5
				else if vpSize.Y > 0 then math.clamp(activeMousePos.Y / vpSize.Y, 0, 1) else 0.5

			local currentIcon = if UserInputService.MouseIcon ~= ""
				then UserInputService.MouseIcon
				else DEFAULT_CURSOR_ID

			Network.ScreenWatch.sendCursorStreamTarget({
				position = {
					X = normX,
					Y = normY,
				},
				timestamp = now,
				icon = currentIcon,
			})
		end
	end))

	local function onInputChanged(input: InputObject, isDown: boolean)
		local now = os.clock()

		if input.UserInputType == Enum.UserInputType.Keyboard then
			local mappedName = KEY_NAME_MAP[input.KeyCode]
			if mappedName then
				Network.ScreenWatch.sendInputEventTarget({
					inputName = mappedName,
					isDown = isDown,
					timestamp = now,
				})
			end

			if isDown and input.KeyCode ~= Enum.KeyCode.None then
				Network.ScreenWatch.sendKeyHistoryEventTarget({
					keyName = input.KeyCode.Name,
					isFlagged = isKeyFlagged(input.KeyCode),
					isDown = true,
					timestamp = now,
				})
			end
		else
			local mouseName = MOUSE_BUTTON_MAP[input.UserInputType]
			if mouseName then
				Network.ScreenWatch.sendInputEventTarget({
					inputName = mouseName,
					isDown = isDown,
					timestamp = now,
				})
			end
		end
	end

	local reportedKeys: { [Enum.KeyCode]: boolean } = {}
	trove:Add(function()
		table.clear(reportedKeys)
	end)

	trove:Add(UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if processed then
				return
			end
			reportedKeys[input.KeyCode] = true
		end
		onInputChanged(input, true)
	end))

	trove:Add(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if not reportedKeys[input.KeyCode] then
				return
			end
			reportedKeys[input.KeyCode] = nil
		end
		onInputChanged(input, false)
	end))

	local isTabbedOut = false
	local tabOutThread: thread? = nil

	trove:Add(function()
		if tabOutThread then
			task.cancel(tabOutThread)
			tabOutThread = nil
		end
	end)

	trove:Add(UserInputService.WindowFocusReleased:Connect(function()
		if tabOutThread then
			task.cancel(tabOutThread)
			tabOutThread = nil
		end

		tabOutThread = task.delay(0.15, function()
			tabOutThread = nil
			if not isTabbedOut then
				isTabbedOut = true
				local now = os.clock()
				Network.ScreenWatch.sendKeyHistoryEventTarget({
					keyName = "CLIENT TABBED OUT",
					isFlagged = false,
					isDown = true,
					timestamp = now,
					isFocusEvent = true,
				})
			end
		end)
	end))

	trove:Add(UserInputService.WindowFocused:Connect(function()
		if tabOutThread then
			task.cancel(tabOutThread)
			tabOutThread = nil
		end

		if isTabbedOut then
			isTabbedOut = false
			local now = os.clock()
			Network.ScreenWatch.sendKeyHistoryEventTarget({
				keyName = "CLIENT TABBED IN",
				isFlagged = false,
				isDown = false,
				timestamp = now,
				isFocusEvent = true,
			})
		end
	end))

	local settingsSvc = ServiceLocator.Settings()
	if settingsSvc and settingsSvc.MenuVisibilityChanged then
		trove:Add(settingsSvc.MenuVisibilityChanged:Connect(function(isOpen: boolean)
			local now = os.clock()
			Network.ScreenWatch.sendKeyHistoryEventTarget({
				keyName = if isOpen then "SETTINGS MENU OPENED" else "SETTINGS MENU CLOSED",
				isFlagged = false,
				isDown = isOpen,
				timestamp = now,
				isFocusEvent = false,
				isSettingsEvent = true,
			})
		end))
	end
end

function ScreenWatchTarget.stopCapture(): ()
	isCapturing = false
	if activeTrove then
		activeTrove:Destroy()
		activeTrove = nil
	end
end

function ScreenWatchTarget.init(): ()
	Network.ScreenWatch.onStartCapture(function(config)
		ScreenWatchTarget.startCapture(config)
	end)

	Network.ScreenWatch.onStopCapture(function()
		ScreenWatchTarget.stopCapture()
	end)
end

return ScreenWatchTarget
