--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent
local Theme = require(MainModule.Shared.UI.Theme)
local GunStats = require(MainModule.Shared.Config.GunStats)

local PADDING = 20
local GAP = 5
local INFO_PANEL_WIDTH = 95
local IMAGE_PANEL_WIDTH = 150
local PANEL_HEIGHT = 68
local AMMO_BAR_HEIGHT = 4
local CORNER_RADIUS = UDim.new(0, 6)

local SHADOW_SPREAD = 6
local SHADOW_OFFSET_Y = 2
local SHADOW_TRANSPARENCY = 0.65
local PANEL_TRANSPARENCY = 0.55

local MUTED_COLOR = Theme.Foreground.Disabled
local GUN_NAME_COLOR = Theme.Foreground.Tertiary

local COLOR_NORMAL = Theme.Colors.White
local COLOR_WARNING = Color3.fromRGB(255, 170, 50)
local COLOR_CRITICAL = Color3.fromRGB(255, 80, 80)
local AMMO_WARNING_THRESHOLD = 0.35
local AMMO_CRITICAL_THRESHOLD = 0.15

local CHARGE_BAR_HEIGHT = 14
local CHARGE_BAR_GAP = 6
local CHARGE_SHADOW_PAD = 2
local CHARGE_CORNER = UDim.new(0, 3)
local CHARGE_FILL_COLOR = Color3.fromRGB(255, 140, 0)
local CHARGE_FULL_COLOR = Color3.fromRGB(255, 55, 55)
local CHARGE_FULL_SHADOW = Color3.fromRGB(200, 30, 30)
local CHARGE_DEFAULT_SHADOW = Color3.fromRGB(0, 0, 0)

local DISABLE_DELAY = 0.4

local TOTAL_WIDTH = INFO_PANEL_WIDTH + GAP + IMAGE_PANEL_WIDTH
local VISIBLE_POS = UDim2.new(1, -PADDING + SHADOW_SPREAD, 1, -PADDING + SHADOW_SPREAD)
local HIDDEN_POS = UDim2.new(1, SHADOW_SPREAD + TOTAL_WIDTH + 30, 1, -PADDING + SHADOW_SPREAD)

local SLIDE_IN_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local SLIDE_OUT_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local FILL_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local CHARGE_TWEEN = TweenInfo.new(0.05, Enum.EasingStyle.Linear)

local SHADOW_ASSET = "rbxassetid://1316045217"
local SHADOW_SLICE = Rect.new(32, 32, 96, 96)

local ammoTextCache: { [number]: string } = {}

local function getAmmoText(ammo: number): string
	local cached = ammoTextCache[ammo]
	if cached then return cached end
	local str = string.format("%03d", math.clamp(ammo, 0, 999))
	local mutedTag = '<font color="rgb(65,65,65)">'
	local result: string
	if ammo >= 100 then
		result = str
	elseif ammo >= 10 then
		result = mutedTag .. "0</font>" .. string.sub(str, 2)
	else
		result = mutedTag .. "00</font>" .. string.sub(str, 3)
	end
	ammoTextCache[ammo] = result
	return result
end

local function getBarColor(percent: number): Color3
	if percent <= AMMO_CRITICAL_THRESHOLD then
		return COLOR_CRITICAL
	elseif percent <= AMMO_WARNING_THRESHOLD then
		return COLOR_WARNING
	end
	return COLOR_NORMAL
end

local gui: ScreenGui
local container: Frame
local ammoLabel: TextLabel
local gunNameLabel: TextLabel
local gunImage: ImageLabel
local ammoBarFill: Frame
local chargeWrapper: Frame
local chargeFill: Frame
local chargePercentLabel: TextLabel
local chargeShadowImg: ImageLabel

local disableTask: thread? = nil
local slideTween: Tween? = nil
local fillTween: Tween? = nil
local chargeTween: Tween? = nil
local lastChargeFloorPct = -1
local isReady = false

local function newCorner(radius: UDim): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	return c
end

local function newStroke(): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = Theme.Border.Default
	s.Thickness = 1
	s.Transparency = Theme.Stroke.Subtle
	return s
end

local function newShadow(parent: Instance, size: UDim2, pos: UDim2, transparency: number, zIndex: number): ImageLabel
	local img = Instance.new("ImageLabel")
	img.Name = "Shadow"
	img.Size = size
	img.Position = pos
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.BackgroundTransparency = 1
	img.Image = SHADOW_ASSET
	img.ImageColor3 = Color3.new(0, 0, 0)
	img.ImageTransparency = transparency
	img.ScaleType = Enum.ScaleType.Slice
	img.SliceCenter = SHADOW_SLICE
	img.ZIndex = zIndex
	img.Parent = parent
	return img
end

local GunHUD = {}

function GunHUD.init(parent: PlayerGui): ()
	gui = Instance.new("ScreenGui")
	gui.Name = "GunHUD"
	gui.AutoLocalize = false
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.fromOffset(TOTAL_WIDTH + SHADOW_SPREAD * 2, PANEL_HEIGHT + SHADOW_SPREAD * 2)
	container.Position = HIDDEN_POS
	container.AnchorPoint = Vector2.one
	container.BackgroundTransparency = 1
	container.Parent = gui

	newShadow(container,
		UDim2.fromScale(1, 1),
		UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
		SHADOW_TRANSPARENCY,
		0
	)

	chargeWrapper = Instance.new("Frame")
	chargeWrapper.Name = "ChargeWrapper"
	chargeWrapper.Size = UDim2.fromOffset(TOTAL_WIDTH + CHARGE_SHADOW_PAD * 2, CHARGE_BAR_HEIGHT + CHARGE_SHADOW_PAD * 2)
	chargeWrapper.Position = UDim2.fromOffset(SHADOW_SPREAD - CHARGE_SHADOW_PAD, SHADOW_SPREAD - CHARGE_BAR_HEIGHT - CHARGE_BAR_GAP - CHARGE_SHADOW_PAD)
	chargeWrapper.BackgroundTransparency = 1
	chargeWrapper.Visible = false
	chargeWrapper.ZIndex = 1
	chargeWrapper.Parent = container

	chargeShadowImg = Instance.new("ImageLabel")
	chargeShadowImg.Name = "Shadow"
	chargeShadowImg.Size = UDim2.new(1, 2, 1, 0)
	chargeShadowImg.Position = UDim2.new(0.5, 0, 0.5, 1)
	chargeShadowImg.AnchorPoint = Vector2.new(0.5, 0.5)
	chargeShadowImg.BackgroundTransparency = 1
	chargeShadowImg.Image = SHADOW_ASSET
	chargeShadowImg.ImageColor3 = CHARGE_DEFAULT_SHADOW
	chargeShadowImg.ImageTransparency = 0.78
	chargeShadowImg.ScaleType = Enum.ScaleType.Slice
	chargeShadowImg.SliceCenter = SHADOW_SLICE
	chargeShadowImg.ZIndex = 0
	chargeShadowImg.Parent = chargeWrapper

	local chargeBarFrame = Instance.new("Frame")
	chargeBarFrame.Name = "ChargeBar"
	chargeBarFrame.Size = UDim2.fromOffset(TOTAL_WIDTH, CHARGE_BAR_HEIGHT)
	chargeBarFrame.Position = UDim2.fromOffset(CHARGE_SHADOW_PAD, CHARGE_SHADOW_PAD)
	chargeBarFrame.BackgroundColor3 = Theme.Background.Primary
	chargeBarFrame.BackgroundTransparency = PANEL_TRANSPARENCY
	chargeBarFrame.ClipsDescendants = true
	chargeBarFrame.ZIndex = 1
	chargeBarFrame.Parent = chargeWrapper
	newCorner(CHARGE_CORNER).Parent = chargeBarFrame
	newStroke().Parent = chargeBarFrame

	chargeFill = Instance.new("Frame")
	chargeFill.Name = "Fill"
	chargeFill.Size = UDim2.fromScale(0, 1)
	chargeFill.BackgroundColor3 = CHARGE_FILL_COLOR
	chargeFill.ZIndex = 1
	chargeFill.Parent = chargeBarFrame
	newCorner(CHARGE_CORNER).Parent = chargeFill

	chargePercentLabel = Instance.new("TextLabel")
	chargePercentLabel.Name = "Percent"
	chargePercentLabel.Size = UDim2.new(1, -12, 1, 0)
	chargePercentLabel.Position = UDim2.fromOffset(6, 0)
	chargePercentLabel.BackgroundTransparency = 1
	chargePercentLabel.Text = "0%"
	chargePercentLabel.TextColor3 = Theme.Colors.White
	chargePercentLabel.TextSize = 10
	chargePercentLabel.Font = Theme.Text.Bold
	chargePercentLabel.TextXAlignment = Enum.TextXAlignment.Right
	chargePercentLabel.TextYAlignment = Enum.TextYAlignment.Center
	chargePercentLabel.ZIndex = 2
	chargePercentLabel.Parent = chargeBarFrame

	local panels = Instance.new("Frame")
	panels.Name = "Panels"
	panels.Size = UDim2.fromOffset(TOTAL_WIDTH, PANEL_HEIGHT)
	panels.Position = UDim2.fromOffset(SHADOW_SPREAD, SHADOW_SPREAD)
	panels.BackgroundTransparency = 1
	panels.ZIndex = 1
	panels.Parent = container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panels

	local infoPanel = Instance.new("Frame")
	infoPanel.Name = "InfoPanel"
	infoPanel.Size = UDim2.fromOffset(INFO_PANEL_WIDTH, PANEL_HEIGHT)
	infoPanel.BackgroundColor3 = Theme.Background.Primary
	infoPanel.BackgroundTransparency = PANEL_TRANSPARENCY
	infoPanel.LayoutOrder = 1
	infoPanel.ZIndex = 1
	infoPanel.Parent = panels
	newCorner(CORNER_RADIUS).Parent = infoPanel
	newStroke().Parent = infoPanel

	ammoLabel = Instance.new("TextLabel")
	ammoLabel.Name = "AmmoCount"
	ammoLabel.Size = UDim2.new(1, 0, 0, 36)
	ammoLabel.Position = UDim2.fromOffset(12, 10)
	ammoLabel.BackgroundTransparency = 1
	ammoLabel.RichText = true
	ammoLabel.Text = getAmmoText(0)
	ammoLabel.TextColor3 = COLOR_NORMAL
	ammoLabel.TextSize = 32
	ammoLabel.Font = Theme.Text.Bold
	ammoLabel.TextXAlignment = Enum.TextXAlignment.Left
	ammoLabel.TextYAlignment = Enum.TextYAlignment.Center
	ammoLabel.Parent = infoPanel

	gunNameLabel = Instance.new("TextLabel")
	gunNameLabel.Name = "GunName"
	gunNameLabel.Size = UDim2.new(1, -24, 0, 18)
	gunNameLabel.Position = UDim2.fromOffset(12, 44)
	gunNameLabel.BackgroundTransparency = 1
	gunNameLabel.Text = ""
	gunNameLabel.TextColor3 = GUN_NAME_COLOR
	gunNameLabel.TextSize = 14
	gunNameLabel.Font = Theme.Text.Bold
	gunNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	gunNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	gunNameLabel.Parent = infoPanel

	local imagePanel = Instance.new("Frame")
	imagePanel.Name = "ImagePanel"
	imagePanel.Size = UDim2.fromOffset(IMAGE_PANEL_WIDTH, PANEL_HEIGHT)
	imagePanel.BackgroundColor3 = Theme.Background.Primary
	imagePanel.BackgroundTransparency = PANEL_TRANSPARENCY
	imagePanel.LayoutOrder = 2
	imagePanel.ZIndex = 1
	imagePanel.Parent = panels
	newCorner(CORNER_RADIUS).Parent = imagePanel
	newStroke().Parent = imagePanel

	gunImage = Instance.new("ImageLabel")
	gunImage.Name = "GunImage"
	gunImage.Size = UDim2.new(1, -24, 1, -24)
	gunImage.Position = UDim2.new(0.5, 0, 0.5, -4)
	gunImage.AnchorPoint = Vector2.new(0.5, 0.5)
	gunImage.BackgroundTransparency = 1
	gunImage.Image = ""
	gunImage.ImageColor3 = Theme.Colors.White
	gunImage.ScaleType = Enum.ScaleType.Fit
	gunImage.Parent = imagePanel

	local ammoBarBg = Instance.new("Frame")
	ammoBarBg.Name = "AmmoBar"
	ammoBarBg.Size = UDim2.new(1, -24, 0, AMMO_BAR_HEIGHT)
	ammoBarBg.Position = UDim2.new(0.5, 0, 1, -10)
	ammoBarBg.AnchorPoint = Vector2.new(0.5, 0)
	ammoBarBg.BackgroundColor3 = MUTED_COLOR
	ammoBarBg.Parent = imagePanel
	newCorner(UDim.new(0, 2)).Parent = ammoBarBg

	ammoBarFill = Instance.new("Frame")
	ammoBarFill.Name = "Fill"
	ammoBarFill.Size = UDim2.fromScale(1, 1)
	ammoBarFill.BackgroundColor3 = COLOR_NORMAL
	ammoBarFill.Parent = ammoBarBg
	newCorner(UDim.new(0, 2)).Parent = ammoBarFill

	gui.Parent = parent
	isReady = true
end

function GunHUD.setVisible(visible: boolean): ()
	if not isReady then return end
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
			gui.Enabled = false
		end)
	end
end

function GunHUD.getContainer(): Frame?
	return if isReady then container else nil
end

function GunHUD.setAmmo(current: number, max: number): ()
	if not isReady then return end
	ammoLabel.Text = getAmmoText(current)
	local percent = if max > 0 then math.clamp(current / max, 0, 1) else 0
	local color = getBarColor(percent)
	ammoLabel.TextColor3 = color
	ammoBarFill.BackgroundColor3 = color
	if fillTween then
		fillTween:Cancel()
	end
	fillTween = TweenService:Create(ammoBarFill, FILL_TWEEN, { Size = UDim2.fromScale(percent, 1) })
	fillTween:Play()
end

function GunHUD.setGunName(name: string): ()
	if not isReady then return end
	gunNameLabel.Text = name
	local stats = GunStats.get(name)
	gunImage.Image = if stats and stats.GunImageId then "rbxassetid://" .. tostring(stats.GunImageId) else ""
end

function GunHUD.setCharge(percent: number): ()
	if not isReady then return end
	local pFloor = math.floor(percent * 100)
	if pFloor ~= lastChargeFloorPct then
		lastChargeFloorPct = pFloor
		chargePercentLabel.Text = tostring(pFloor) .. "%"
	end
	local isFull = percent >= 1
	chargeFill.BackgroundColor3 = if isFull then CHARGE_FULL_COLOR else CHARGE_FILL_COLOR
	chargeShadowImg.ImageColor3 = if isFull then CHARGE_FULL_SHADOW else CHARGE_DEFAULT_SHADOW
	if chargeTween then
		chargeTween:Cancel()
	end
	chargeTween = TweenService:Create(chargeFill, CHARGE_TWEEN, { Size = UDim2.fromScale(percent, 1) })
	chargeTween:Play()
end

function GunHUD.setChargeVisible(visible: boolean): ()
	if not isReady then return end
	chargeWrapper.Visible = visible
end

function GunHUD.destroy(): ()
	isReady = false
	if disableTask then
		task.cancel(disableTask)
		disableTask = nil
	end
	if slideTween then
		slideTween:Cancel()
		slideTween = nil
	end
	if fillTween then
		fillTween:Cancel()
		fillTween = nil
	end
	if chargeTween then
		chargeTween:Cancel()
		chargeTween = nil
	end
	if gui then
		gui:Destroy()
	end
	lastChargeFloorPct = -1
end

return GunHUD
