--!strict
--!native
--!optimize 2

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
local Theme = require(MainModule.Shared.UI.Theme)

local CreateRadial = require(script.CreateRadial)
local CONSTANTS = require(script.CONSTANTS)

local MOUSE_GROUP = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseMovement] = true,
	[Enum.UserInputType.Touch] = true,
}

local RadialUI = {}

local DEFAULT_ICON_SCALE = 2
local CUSTOM_CURSOR_ICON_SCALE = 1.5

local OPEN_SIZE_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0)
local OPEN_ROTATION_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local OPEN_FADE_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local HOVER_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local SEGMENT_COLOR_DEFAULT = Theme.Colors.Black[850]
local SEGMENT_COLOR_HOVER = Theme.Colors.Black[450]

export type RadialResult = {
	segmentType: "preset" | "custom",
	presetIndex: number?,
	customCursorId: number?,
}

function RadialUI.createRadialSelector(
	parentScope: any,
	hoveredIndex: any,
	currentStyle: any,
	_innerRadius: number,
	_outerRadius: number,
	customCursorIdRef: any?,
	isUsingCustomRef: any?,
	radialCursorsRef: any?
): (ScreenGui, any, any, () -> (), () -> RadialResult?)
	local Fusion = require(MainModule.Packages:WaitForChild("Fusion", 5)) :: any
	local peek = Fusion.peek

	local player = Players.LocalPlayer
	local mouse = player:GetMouse()

	local presetCount = #SettingsConfig.Cursors
	local tPercent = 0.38

	local wheelVisible = parentScope:Value(false)
	local wheelPosition = parentScope:Value(UDim2.fromScale(0.5, 0.5))

	local function getRadialCursors(): { number }
		if not radialCursorsRef then
			if customCursorIdRef then
				local customId = peek(customCursorIdRef)
				if customId and customId > 0 then
					return { customId }
				end
			end
			return {}
		end
		local cursors = peek(radialCursorsRef)
		if type(cursors) ~= "table" then
			return {}
		end
		return cursors
	end

	local radialCursors = getRadialCursors()
	local customCount = #radialCursors
	local totalSegments = presetCount + customCount
	if totalSegments < 1 then
		totalSegments = presetCount
	end
	local segmentAngle = 360 / totalSegments

	local segmentMap: { [number]: RadialResult } = {}
	for i = 1, presetCount do
		segmentMap[i] = { segmentType = "preset", presetIndex = i }
	end
	for i = 1, customCount do
		local segmentIdx = presetCount + i
		segmentMap[segmentIdx] = { segmentType = "custom", customCursorId = radialCursors[i] }
	end

	local frame = CreateRadial(totalSegments, tPercent, 0)
	frame.Name = "RadialWheel"
	frame.Size = UDim2.fromOffset(170, 170)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Visible = false

	local lastHoverIndex = 1
	local customIconLabels: { [number]: ImageLabel } = {}
	local isDestroyed = false

	local segmentNames = table.create(totalSegments)
	for i = 1, totalSegments do
		segmentNames[i] = tostring(i)
	end

	for i = 1, totalSegments do
		local radial = frame.Radial:FindFirstChild(segmentNames[i]) :: ViewportFrame?
		if radial then
			radial.ImageColor3 = SEGMENT_COLOR_DEFAULT
			radial.ImageTransparency = 0.25
		end

		local attach = frame.Attach:FindFirstChild(segmentNames[i]) :: Frame?
		if attach then
			if i <= presetCount then
				local cursorData = SettingsConfig.Cursors[i]
				local cursorId = cursorData and cursorData.id or 0
				local iconScale = cursorData and cursorData.radialScale or DEFAULT_ICON_SCALE

				if cursorId > 0 then
					local icon = Instance.new("ImageLabel")
					icon.Name = "CursorIcon"
					icon.Size = UDim2.fromScale(iconScale, iconScale)
					icon.Position = UDim2.fromScale(0.5, 0.5)
					icon.AnchorPoint = Vector2.new(0.5, 0.5)
					icon.BackgroundTransparency = 1
					icon.Image = "rbxassetid://" .. tostring(cursorId)
					icon.ScaleType = Enum.ScaleType.Fit
					icon.Parent = attach
				end
			else
				local customIdx = i - presetCount
				local customCursorId = radialCursors[customIdx] or 0

				local icon = Instance.new("ImageLabel")
				icon.Name = "CustomCursorIcon"
				icon.Size = UDim2.fromScale(CUSTOM_CURSOR_ICON_SCALE, CUSTOM_CURSOR_ICON_SCALE)
				icon.Position = UDim2.fromScale(0.5, 0.5)
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.BackgroundTransparency = 1
				icon.Image = if customCursorId > 0 then "rbxassetid://" .. tostring(customCursorId) else ""
				icon.ScaleType = Enum.ScaleType.Fit
				icon.Parent = attach
				customIconLabels[i] = icon
			end
		end
	end

	local dial = frame:FindFirstChild("RadialDial") :: ViewportFrame?

	local function getMouseAngle(): number?
		if isDestroyed then
			return nil
		end

		local frameSize = frame.AbsoluteSize
		local framePos = frame.AbsolutePosition
		local radius = frameSize.Y / 2
		local center = framePos + frameSize / 2

		local mouseX = mouse.X
		local mouseY = mouse.Y
		local dx = mouseX - center.X
		local dy = mouseY - center.Y
		local dist = math.sqrt(dx * dx + dy * dy)

		if dist < radius * 0.15 or dist > radius * 4 then
			return nil
		end

		local angleRad = math.atan2(dy, dx)
		local angleDeg = math.deg(angleRad)

		return angleDeg
	end

	local function pickIndex(angleDeg: number): number
		local gOffsetDeg = math.deg(CONSTANTS.G_OFFSET)
		local shifted = (-angleDeg + 90 - gOffsetDeg + 360) % 360
		local segmentIndex = shifted // segmentAngle
		local idx = segmentIndex + 1
		if idx > totalSegments then
			idx = 1
		end

		return idx
	end

	local function getRadial(index: number): ViewportFrame?
		if isDestroyed then
			return nil
		end
		return frame.Radial:FindFirstChild(tostring(index)) :: ViewportFrame?
	end

	local function updateHover(index: number)
		if isDestroyed then
			return
		end

		if index ~= lastHoverIndex then
			local lastRadial = getRadial(lastHoverIndex)
			if lastRadial then
				TweenService:Create(lastRadial, HOVER_TWEEN_INFO, {
					ImageColor3 = SEGMENT_COLOR_DEFAULT,
				}):Play()
			end

			local newRadial = getRadial(index)
			if newRadial then
				TweenService:Create(newRadial, HOVER_TWEEN_INFO, {
					ImageColor3 = SEGMENT_COLOR_HOVER,
				}):Play()
			end

			lastHoverIndex = index
			hoveredIndex:set(index)
		end
	end

	local inputType = Enum.UserInputType.MouseMovement
	local renderConnection: RBXScriptConnection? = nil
	local inputTypeConnection: RBXScriptConnection? = nil
	local scrollConnection: RBXScriptConnection? = nil
	local openSizeTween: Tween? = nil
	local openRotationTween: Tween? = nil
	local openFadeTween: Tween? = nil
	local closeSizeTween: Tween? = nil
	local closeRotationTween: Tween? = nil
	local closeFadeTween: Tween? = nil

	inputTypeConnection = UserInputService.LastInputTypeChanged:Connect(function(iType)
		if MOUSE_GROUP[iType] then
			inputType = iType
		end
	end)

	local function onRenderStep()
		if isDestroyed then
			return
		end

		if not MOUSE_GROUP[inputType] then
			return
		end

		local angleDeg = getMouseAngle()

		if angleDeg then
			if dial and not isDestroyed then
				dial.Visible = true
				dial.Rotation = angleDeg - 90
			end
			local index = pickIndex(angleDeg)
			updateHover(index)
		end
	end

	local function updateCustomIcons()
		if isDestroyed then
			return
		end
		local cursors = getRadialCursors()
		for segmentIdx, iconLabel in customIconLabels do
			local customIdx = segmentIdx - presetCount
			local cursorId = cursors[customIdx] or 0
			if cursorId > 0 then
				iconLabel.Image = "rbxassetid://" .. tostring(cursorId)
			end
		end
	end

	local function getInitialHighlight(): number
		if isUsingCustomRef and peek(isUsingCustomRef) and customCount > 0 then
			local currentCustomId = customCursorIdRef and peek(customCursorIdRef) or 0
			if currentCustomId > 0 then
				for i, cursorId in radialCursors do
					if cursorId == currentCustomId then
						return presetCount + i
					end
				end
			end
			return presetCount + 1
		end
		local currentIdx = peek(currentStyle)
		if currentIdx and currentIdx > 0 and currentIdx <= presetCount then
			return currentIdx
		end
		return 1
	end

	local function cancelCloseTweens()
		if closeSizeTween then
			closeSizeTween:Cancel()
			closeSizeTween = nil
		end
		if closeRotationTween then
			closeRotationTween:Cancel()
			closeRotationTween = nil
		end
		if closeFadeTween then
			closeFadeTween:Cancel()
			closeFadeTween = nil
		end
	end

	local function cancelOpenTweens()
		if openSizeTween then
			openSizeTween:Cancel()
			openSizeTween = nil
		end
		if openRotationTween then
			openRotationTween:Cancel()
			openRotationTween = nil
		end
		if openFadeTween then
			openFadeTween:Cancel()
			openFadeTween = nil
		end
	end

	local function showRadial()
		if isDestroyed then
			return
		end

		local pos = peek(wheelPosition)
		frame.Position = pos
		frame.Visible = true

		updateCustomIcons()

		local initialIdx = getInitialHighlight()
		lastHoverIndex = 0
		updateHover(initialIdx)

		cancelCloseTweens()

		frame.Size = UDim2.fromOffset(0, 0)
		frame.GroupTransparency = 1
		frame.Rotation = -45

		openSizeTween = TweenService:Create(frame, OPEN_SIZE_TWEEN, {
			Size = UDim2.fromOffset(170, 170),
		})
		openRotationTween = TweenService:Create(frame, OPEN_ROTATION_TWEEN, {
			Rotation = 0,
		})
		openFadeTween = TweenService:Create(frame, OPEN_FADE_TWEEN, {
			GroupTransparency = 0,
		})

		openSizeTween:Play()
		openRotationTween:Play()
		openFadeTween:Play()

		if not renderConnection then
			renderConnection = RunService.RenderStepped:Connect(onRenderStep)
		end

		if scrollConnection then
			scrollConnection:Disconnect()
		end
		scrollConnection = UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed then return end
			if isDestroyed then return end
			if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end

			local delta = input.Position.Z
			local current = lastHoverIndex
			local newIdx: number

			if delta > 0 then
				newIdx = current - 1
				if newIdx < 1 then
					newIdx = totalSegments
				end
			else
				newIdx = current + 1
				if newIdx > totalSegments then
					newIdx = 1
				end
			end

			updateHover(newIdx)
		end)
	end

	local function hideRadial()
		if isDestroyed then
			return
		end

		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end

		if scrollConnection then
			scrollConnection:Disconnect()
			scrollConnection = nil
		end

		cancelOpenTweens()

		closeSizeTween = TweenService:Create(frame, CLOSE_TWEEN_INFO, {
			Size = UDim2.fromOffset(0, 0),
		})
		closeRotationTween = TweenService:Create(frame, CLOSE_TWEEN_INFO, {
			Rotation = 30,
		})
		closeFadeTween = TweenService:Create(frame, CLOSE_TWEEN_INFO, {
			GroupTransparency = 1,
		})

		closeSizeTween:Play()
		closeRotationTween:Play()
		closeFadeTween:Play()

		closeSizeTween.Completed:Once(function()
			if not isDestroyed then
				frame.Visible = false
				frame.Rotation = 0
			end
		end)
	end

	local _observerConnection = parentScope:Observer(wheelVisible):onChange(function()
		local visible = peek(wheelVisible)
		if visible then
			showRadial()
		else
			hideRadial()
		end
	end)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "VultarCursorRadial"
	screenGui.AutoLocalize = false
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 100001
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	frame.Parent = screenGui

	local function cleanup()
		isDestroyed = true

		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end

		if scrollConnection then
			scrollConnection:Disconnect()
			scrollConnection = nil
		end

		if inputTypeConnection then
			inputTypeConnection:Disconnect()
			inputTypeConnection = nil
		end

		cancelOpenTweens()
		cancelCloseTweens()
	end

	local function getSelectedResult(): RadialResult?
		local selected = peek(hoveredIndex)
		if selected <= 0 or selected > totalSegments then
			return nil
		end
		return segmentMap[selected]
	end

	return screenGui, wheelVisible, wheelPosition, cleanup, getSelectedResult
end

return RadialUI
