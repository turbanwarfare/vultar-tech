--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent
local Theme = require(MainModule.Shared.UI.Theme)

local SHADOW_ASSET = "rbxassetid://1316045217"
local SHADOW_SLICE = Rect.new(32, 32, 96, 96)

local PADDING = 20
local BOX_SIZE = 68
local BOX_GAP = 5
local CORNER_RADIUS = UDim.new(0, 6)

local SHADOW_SPREAD = 6
local SHADOW_OFFSET_Y = 2
local SHADOW_TRANSPARENCY = 0.65
local PANEL_TRANSPARENCY = 0.55

local GUN_HUD_WIDTH = 250
local GUN_TO_ABILITY_GAP = 8
local RIGHT_OFFSET = PADDING + GUN_HUD_WIDTH + GUN_TO_ABILITY_GAP

local TOTAL_WIDTH = BOX_SIZE + BOX_GAP + BOX_SIZE

local DISABLE_DELAY = 0.4

local CROSS_LENGTH = 28
local CROSS_THICKNESS = 10
local CROSS_CORNER = UDim.new(0, 2)

local ICON_SIZE = 32
local SHIELD_ICON = "rbxassetid://81384430558523"

local GRADIENT_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0.95),
	NumberSequenceKeypoint.new(1, 0.1),
})

local VISIBLE_POS = UDim2.new(1, -RIGHT_OFFSET + SHADOW_SPREAD, 1, -PADDING + SHADOW_SPREAD)
local HIDDEN_POS = UDim2.new(1, SHADOW_SPREAD + TOTAL_WIDTH + 30, 1, -PADDING + SHADOW_SPREAD)

local SLIDE_IN_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local SLIDE_OUT_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local COLOR_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local COLOR_READY = Color3.fromRGB(40, 180, 80)
local COLOR_ACTIVE = Color3.fromRGB(30, 100, 220)
local COLOR_COOLDOWN = Color3.fromRGB(200, 45, 45)

export type AbilityState = "ready" | "active" | "cooldown"

local ABILITY_COLORS: { [AbilityState]: Color3 } = {
	ready    = COLOR_READY,
	active   = COLOR_ACTIVE,
	cooldown = COLOR_COOLDOWN,
}

local COOLDOWN_STRINGS: { [number]: string } = {}
for i = 0, 60 do
	COOLDOWN_STRINGS[i] = tostring(i)
end

local FlagBearerAbilityHUD = {}

local isReady = false
local isVisible = false

local gui: ScreenGui
local container: Frame

local shieldGradient: Frame
local shieldCooldownLabel: TextLabel
local shieldColorTween: Tween? = nil

local healGradient: Frame
local healCooldownLabel: TextLabel
local healColorTween: Tween? = nil

local disableTask: thread? = nil
local slideTween: Tween? = nil

local function buildAbilityBox(
	parent: Frame,
	layoutOrder: number,
	keybindLabel: string,
	iconId: string?
): (Frame, TextLabel, TextLabel)
	local box = Instance.new("Frame")
	box.Name = keybindLabel .. "Box"
	box.Size = UDim2.fromOffset(BOX_SIZE, BOX_SIZE)
	box.BackgroundColor3 = Theme.Background.Primary
	box.BackgroundTransparency = PANEL_TRANSPARENCY
	box.LayoutOrder = layoutOrder
	box.Parent = parent

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

	if iconId then
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
		icon.Position = UDim2.fromScale(0.5, 0.55)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = iconId
		icon.ImageColor3 = Theme.Colors.White
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = 2
		icon.Parent = box
	else
		local cross = Instance.new("Frame")
		cross.Name = "CrossContainer"
		cross.Size = UDim2.fromOffset(CROSS_LENGTH, CROSS_LENGTH)
		cross.Position = UDim2.fromScale(0.5, 0.55)
		cross.AnchorPoint = Vector2.new(0.5, 0.5)
		cross.BackgroundTransparency = 1
		cross.ZIndex = 2
		cross.Parent = box

		local h = Instance.new("Frame")
		h.Name = "Horizontal"
		h.Size = UDim2.fromOffset(CROSS_LENGTH, CROSS_THICKNESS)
		h.Position = UDim2.fromScale(0.5, 0.5)
		h.AnchorPoint = Vector2.new(0.5, 0.5)
		h.BackgroundColor3 = Theme.Colors.White
		h.Parent = cross
		local hc = Instance.new("UICorner")
		hc.CornerRadius = CROSS_CORNER
		hc.Parent = h

		local v = Instance.new("Frame")
		v.Name = "Vertical"
		v.Size = UDim2.fromOffset(CROSS_THICKNESS, CROSS_LENGTH)
		v.Position = UDim2.fromScale(0.5, 0.5)
		v.AnchorPoint = Vector2.new(0.5, 0.5)
		v.BackgroundColor3 = Theme.Colors.White
		v.Parent = cross
		local vc = Instance.new("UICorner")
		vc.CornerRadius = CROSS_CORNER
		vc.Parent = v
	end

	local keybind = Instance.new("TextLabel")
	keybind.Name = "Keybind"
	keybind.Size = UDim2.fromOffset(24, 16)
	keybind.Position = UDim2.fromOffset(6, 4)
	keybind.BackgroundTransparency = 1
	keybind.Text = "[" .. keybindLabel .. "]"
	keybind.TextColor3 = Theme.Foreground.Tertiary
	keybind.TextSize = 12
	keybind.Font = Theme.Text.Bold
	keybind.TextXAlignment = Enum.TextXAlignment.Left
	keybind.ZIndex = 3
	keybind.Parent = box

	local cooldownLbl = Instance.new("TextLabel")
	cooldownLbl.Name = "Cooldown"
	cooldownLbl.Size = UDim2.fromOffset(24, 16)
	cooldownLbl.Position = UDim2.new(1, -6, 0, 4)
	cooldownLbl.AnchorPoint = Vector2.new(1, 0)
	cooldownLbl.BackgroundTransparency = 1
	cooldownLbl.Text = ""
	cooldownLbl.TextColor3 = Theme.Colors.White
	cooldownLbl.TextSize = 12
	cooldownLbl.Font = Theme.Text.Bold
	cooldownLbl.TextXAlignment = Enum.TextXAlignment.Right
	cooldownLbl.Visible = false
	cooldownLbl.ZIndex = 3
	cooldownLbl.Parent = box

	return gradientFrame, cooldownLbl, keybind
end

local function applyAbilityState(
	gradientFrame: Frame,
	cooldownLabel: TextLabel,
	colorTween: Tween?,
	state: AbilityState,
	cd: number?
): Tween
	local targetColor = ABILITY_COLORS[state]
	if colorTween then
		colorTween:Cancel()
	end
	local newTween = TweenService:Create(gradientFrame, COLOR_TWEEN, { BackgroundColor3 = targetColor })
	newTween:Play()

	local cooldown = cd or 0
	local isCooldownVisible = state == "cooldown" and cooldown > 0
	cooldownLabel.Visible = isCooldownVisible
	if isCooldownVisible then
		local ceilVal = math.ceil(cooldown)
		cooldownLabel.Text = COOLDOWN_STRINGS[ceilVal] or tostring(ceilVal)
	end

	return newTween
end

function FlagBearerAbilityHUD.init(parent: PlayerGui): ()
	gui = Instance.new("ScreenGui")
	gui.Name = "FlagBearerAbilityHUD"
	gui.AutoLocalize = false
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.fromOffset(TOTAL_WIDTH + SHADOW_SPREAD * 2, BOX_SIZE + SHADOW_SPREAD * 2)
	container.Position = HIDDEN_POS
	container.AnchorPoint = Vector2.one
	container.BackgroundTransparency = 1
	container.Parent = gui

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
	shadow.Parent = container

	local boxes = Instance.new("Frame")
	boxes.Name = "Boxes"
	boxes.Size = UDim2.fromOffset(TOTAL_WIDTH, BOX_SIZE)
	boxes.Position = UDim2.fromOffset(SHADOW_SPREAD, SHADOW_SPREAD)
	boxes.BackgroundTransparency = 1
	boxes.ZIndex = 1
	boxes.Parent = container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, BOX_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = boxes

	local shieldKeyLbl: TextLabel
	local healKeyLbl: TextLabel

	shieldGradient, shieldCooldownLabel, shieldKeyLbl = buildAbilityBox(boxes, 1, "G", SHIELD_ICON)
	healGradient, healCooldownLabel, healKeyLbl = buildAbilityBox(boxes, 2, "E", nil)

	local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
	task.spawn(function()
		local settingsService = nil
		while not settingsService do
			settingsService = LazyService.create(MainModule, "SettingsService")()
			if not settingsService then
				task.wait(0.1)
			end
		end
		
		shieldKeyLbl.Text = "[" .. (settingsService:GetKeybind("FlagBearerShield") or "G") .. "]"
		healKeyLbl.Text = "[" .. (settingsService:GetKeybind("FlagBearerHeal") or "E") .. "]"
		settingsService.KeybindChanged:Connect(function(key, value)
			if key == "FlagBearerShield" then
				shieldKeyLbl.Text = "[" .. value .. "]"
			elseif key == "FlagBearerHeal" then
				healKeyLbl.Text = "[" .. value .. "]"
			end
		end)
	end)

	gui.Parent = parent
	isReady = true
end

function FlagBearerAbilityHUD.setVisible(visible: boolean): ()
	if not isReady then return end
	isVisible = visible
	if visible then
		if disableTask then
			task.cancel(disableTask)
			disableTask = nil
		end
		gui.Enabled = true
		if slideTween then
			slideTween:Cancel()
		end
		slideTween = TweenService:Create(container, SLIDE_IN_TWEEN, { Position = VISIBLE_POS })
		slideTween:Play()
	else
		if slideTween then
			slideTween:Cancel()
		end
		slideTween = TweenService:Create(container, SLIDE_OUT_TWEEN, { Position = HIDDEN_POS })
		slideTween:Play()
		disableTask = task.delay(DISABLE_DELAY, function()
			disableTask = nil
			if not isVisible then
				gui.Enabled = false
			end
		end)
	end
end

function FlagBearerAbilityHUD.setShieldState(state: AbilityState, cd: number?): ()
	if not isReady then return end
	shieldColorTween = applyAbilityState(shieldGradient, shieldCooldownLabel, shieldColorTween, state, cd)
end

function FlagBearerAbilityHUD.setHealState(state: AbilityState, cd: number?): ()
	if not isReady then return end
	healColorTween = applyAbilityState(healGradient, healCooldownLabel, healColorTween, state, cd)
end

function FlagBearerAbilityHUD.destroy(): ()
	if disableTask then
		task.cancel(disableTask)
	end
	if slideTween then
		slideTween:Cancel()
	end
	if shieldColorTween then
		shieldColorTween:Cancel()
	end
	if healColorTween then
		healColorTween:Cancel()
	end
	if isReady then
		gui:Destroy()
	end
	isReady = false
	isVisible = false
	disableTask = nil
	slideTween = nil
	shieldColorTween = nil
	healColorTween = nil
end

return FlagBearerAbilityHUD
