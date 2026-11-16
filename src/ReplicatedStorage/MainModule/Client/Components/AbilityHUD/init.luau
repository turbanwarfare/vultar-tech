--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent
local Theme = require(MainModule.Shared.UI.Theme)

local SHADOW_ASSET = "rbxassetid://1316045217"
local SHADOW_SLICE = Rect.new(32, 32, 96, 96)

local BOX_SIZE = 68
local GAP_TO_GUN_HUD = 8
local CORNER_RADIUS = UDim.new(0, 6)
local SHADOW_SPREAD = 6
local SHADOW_OFFSET_Y = 2
local SHADOW_TRANSPARENCY = 0.65
local PANEL_TRANSPARENCY = 0.55

local PIP_SIZE = 6
local PIP_GAP = 4

local DEFAULT_ICON_SIZE = 22
local LARGE_ICON_SIZE = 30
local LARGE_ICON_OFFSET = 4

local COLOR_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local COLOR_READY = Color3.fromRGB(40, 180, 80)
local COLOR_COOLDOWN = Color3.fromRGB(200, 45, 45)
local COLOR_EMPTY = Color3.fromRGB(90, 90, 90)

local KEY_LABELS = {
	LeftControl = "Ctrl",
	RightControl = "Ctrl",
}

local GRADIENT_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0.95),
	NumberSequenceKeypoint.new(1, 0.1),
})

type Box = {
	wrapper: Frame,
	gradientFrame: Frame,
	keybindLabel: TextLabel,
	cooldownLabel: TextLabel,
	pips: { Frame },
	colorTween: Tween?,
}

local AbilityHUD = {}

local boxes: { [string]: Box } = {}

local function newLabel(name: string, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.TextColor3 = Theme.Colors.White
	label.Font = Theme.Text.Bold
	label.ZIndex = 3
	label.Parent = parent
	return label
end

function AbilityHUD.add(name: string, icon: string, maxCharges: number, iconSize: number?): ()
	local wrapper = Instance.new("Frame")
	wrapper.Name = name .. "Box"
	wrapper.Size = UDim2.fromOffset(BOX_SIZE + SHADOW_SPREAD * 2, BOX_SIZE + SHADOW_SPREAD * 2)
	wrapper.Position = UDim2.fromOffset(-(BOX_SIZE + GAP_TO_GUN_HUD), 0)
	wrapper.BackgroundTransparency = 1
	wrapper.Visible = false

	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y)
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.BackgroundTransparency = 1
	shadow.Image = SHADOW_ASSET
	shadow.ImageColor3 = Color3.new(0, 0, 0)
	shadow.ImageTransparency = SHADOW_TRANSPARENCY
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = SHADOW_SLICE
	shadow.ZIndex = 0
	shadow.Parent = wrapper

	local box = Instance.new("Frame")
	box.Name = "Box"
	box.Size = UDim2.fromOffset(BOX_SIZE, BOX_SIZE)
	box.Position = UDim2.fromOffset(SHADOW_SPREAD, SHADOW_SPREAD)
	box.BackgroundColor3 = Theme.Background.Primary
	box.BackgroundTransparency = PANEL_TRANSPARENCY
	box.ZIndex = 1
	box.Parent = wrapper

	local corner = Instance.new("UICorner")
	corner.CornerRadius = CORNER_RADIUS
	corner.Parent = box

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Border.Default
	stroke.Thickness = 1
	stroke.Transparency = Theme.Stroke.Subtle
	stroke.Parent = box

	local gradientFrame = Instance.new("Frame")
	gradientFrame.Name = "Gradient"
	gradientFrame.Size = UDim2.fromScale(1, 1)
	gradientFrame.BackgroundColor3 = COLOR_READY
	gradientFrame.ZIndex = 1
	gradientFrame.Parent = box

	local gradientCorner = Instance.new("UICorner")
	gradientCorner.CornerRadius = CORNER_RADIUS
	gradientCorner.Parent = gradientFrame

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = GRADIENT_TRANSPARENCY
	gradient.Rotation = 90
	gradient.Parent = gradientFrame

	local keybindLabel = newLabel("Keybind", box)
	keybindLabel.Size = UDim2.fromOffset(24, 16)
	keybindLabel.Position = UDim2.fromOffset(6, 4)
	keybindLabel.TextColor3 = Theme.Foreground.Tertiary
	keybindLabel.TextSize = 12
	keybindLabel.TextXAlignment = Enum.TextXAlignment.Left

	local cooldownLabel = newLabel("Cooldown", box)
	cooldownLabel.Size = UDim2.fromOffset(24, 16)
	cooldownLabel.Position = UDim2.new(1, -6, 0, 4)
	cooldownLabel.AnchorPoint = Vector2.new(1, 0)
	cooldownLabel.TextSize = 12
	cooldownLabel.TextXAlignment = Enum.TextXAlignment.Right
	cooldownLabel.Visible = false

	if icon ~= "" then
		local iconLabel = Instance.new("ImageLabel")
		local size = iconSize or DEFAULT_ICON_SIZE
		iconLabel.Size = UDim2.fromOffset(size, size)
		iconLabel.Position = UDim2.new(0.5, 0, 0.5, if size > LARGE_ICON_SIZE then LARGE_ICON_OFFSET else 0)
		iconLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Image = icon
		iconLabel.Parent = box
	else
		local nameLabel = newLabel("Name", box)
		nameLabel.Size = UDim2.fromOffset(BOX_SIZE, 20)
		nameLabel.Position = UDim2.fromScale(0.5, 0.5)
		nameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		nameLabel.TextSize = 14
		nameLabel.Text = string.upper(name)
	end

	local pipRow = Instance.new("Frame")
	pipRow.Name = "Pips"
	pipRow.Size = UDim2.fromOffset(BOX_SIZE, PIP_SIZE)
	pipRow.Position = UDim2.new(0.5, 0, 1, -10)
	pipRow.AnchorPoint = Vector2.new(0.5, 1)
	pipRow.BackgroundTransparency = 1
	pipRow.ZIndex = 3
	pipRow.Parent = box

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, PIP_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = pipRow

	local pips: { Frame } = {}
	for index = 1, maxCharges do
		local pip = Instance.new("Frame")
		pip.Name = "Pip" .. index
		pip.Size = UDim2.fromOffset(PIP_SIZE, PIP_SIZE)
		pip.BackgroundColor3 = Theme.Colors.White
		pip.LayoutOrder = index
		pip.ZIndex = 3
		pip.Parent = pipRow

		local pipCorner = Instance.new("UICorner")
		pipCorner.CornerRadius = UDim.new(0, 2)
		pipCorner.Parent = pip

		table.insert(pips, pip)
	end

	boxes[name] = {
		wrapper = wrapper,
		gradientFrame = gradientFrame,
		keybindLabel = keybindLabel,
		cooldownLabel = cooldownLabel,
		pips = pips,
		colorTween = nil,
	}
end

function AbilityHUD.attach(parent: Frame): ()
	for _, box in boxes do
		box.wrapper.Parent = parent
	end
end

function AbilityHUD.show(names: { string }): ()
	for _, box in boxes do
		box.wrapper.Visible = false
	end
	for index, name in names do
		local box = boxes[name]
		if box then
			box.wrapper.Position = UDim2.fromOffset(-index * (BOX_SIZE + GAP_TO_GUN_HUD), 0)
			box.wrapper.Visible = true
		end
	end
end

function AbilityHUD.setKeybind(name: string, key: string): ()
	local box = boxes[name]
	if box then
		box.keybindLabel.Text = "[" .. (KEY_LABELS[key] or key) .. "]"
	end
end

function AbilityHUD.setState(name: string, count: number, cooldown: number): ()
	local box = boxes[name]
	if not box then
		return
	end

	for index, pip in box.pips do
		pip.BackgroundTransparency = if index <= count then 0.1 else 0.8
	end

	local onCooldown = count > 0 and cooldown > 0
	box.cooldownLabel.Visible = onCooldown
	if onCooldown then
		box.cooldownLabel.Text = tostring(math.ceil(cooldown))
	end

	local targetColor = if count <= 0 then COLOR_EMPTY elseif onCooldown then COLOR_COOLDOWN else COLOR_READY
	if box.gradientFrame.BackgroundColor3 ~= targetColor then
		local colorTween = box.colorTween
		if colorTween then
			colorTween:Cancel()
		end
		local tween = TweenService:Create(box.gradientFrame, COLOR_TWEEN, { BackgroundColor3 = targetColor })
		box.colorTween = tween
		tween:Play()
	end
end

function AbilityHUD.destroy(): ()
	for _, box in boxes do
		local colorTween = box.colorTween
		if colorTween then
			colorTween:Cancel()
		end
		box.wrapper:Destroy()
	end
	table.clear(boxes)
end

return AbilityHUD
