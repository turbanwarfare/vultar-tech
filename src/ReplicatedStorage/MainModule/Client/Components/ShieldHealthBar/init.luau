--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local COLOR_FULL = Color3.fromRGB(85, 255, 85)
local COLOR_MID  = Color3.fromRGB(255, 200, 50)
local COLOR_LOW  = Color3.fromRGB(255, 80, 80)

local BG_DARKEN = 0.25
local BG_TRANSPARENCY = 0.3

local COLOR_FULL_BG = Color3.new(COLOR_FULL.R * BG_DARKEN, COLOR_FULL.G * BG_DARKEN, COLOR_FULL.B * BG_DARKEN)
local COLOR_MID_BG  = Color3.new(COLOR_MID.R  * BG_DARKEN, COLOR_MID.G  * BG_DARKEN, COLOR_MID.B  * BG_DARKEN)
local COLOR_LOW_BG  = Color3.new(COLOR_LOW.R  * BG_DARKEN, COLOR_LOW.G  * BG_DARKEN, COLOR_LOW.B  * BG_DARKEN)

local BAR_WIDTH = 90
local BAR_HEIGHT = 5
local BAR_CORNER = UDim.new(0, 3)
local BILLBOARD_SIZE = UDim2.fromOffset(BAR_WIDTH + 16, BAR_HEIGHT + 16)
local MAX_DISTANCE = 200

local FILL_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local SHIELD_FILL_GRADIENT = ColorSequence.new(
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(180, 180, 180)
)
local SHIELD_FILL_TRANSPARENCY = NumberSequence.new(0.15, 0.3)

local function getBarColors(percent: number): (Color3, Color3)
	if percent > 0.6 then
		return COLOR_FULL, COLOR_FULL_BG
	elseif percent > 0.3 then
		return COLOR_MID, COLOR_MID_BG
	else
		return COLOR_LOW, COLOR_LOW_BG
	end
end

export type ShieldBar = {
	setHealth: (current: number, max: number) -> (),
	setVisible: (visible: boolean) -> (),
	destroy: () -> (),
}

local ShieldHealthBar = {}

function ShieldHealthBar.create(adornee: BasePart, parent: PlayerGui): ShieldBar
	local studsOffset = Vector3.new(0, adornee.Size.Y / 2 + 1.5, 0)

	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "ShieldHealthBar"
	billboardGui.Size = BILLBOARD_SIZE
	billboardGui.StudsOffset = studsOffset
	billboardGui.Adornee = adornee
	billboardGui.AlwaysOnTop = true
	billboardGui.LightInfluence = 0
	billboardGui.MaxDistance = MAX_DISTANCE
	billboardGui.ResetOnSpawn = false
	billboardGui.Enabled = false
	billboardGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	billboardGui.Parent = parent

	local anchor = Instance.new("Frame")
	anchor.Name = "Anchor"
	anchor.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT)
	anchor.Position = UDim2.fromScale(0.5, 0.5)
	anchor.AnchorPoint = Vector2.new(0.5, 0.5)
	anchor.BackgroundTransparency = 1
	anchor.Parent = billboardGui

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.fromScale(1, 1)
	track.BackgroundColor3 = COLOR_LOW_BG
	track.BackgroundTransparency = BG_TRANSPARENCY
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.ZIndex = 1
	track.Parent = anchor
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = BAR_CORNER
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = COLOR_FULL
	fill.BackgroundTransparency = 0
	fill.BorderSizePixel = 0
	fill.ZIndex = 1
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = BAR_CORNER
	fillCorner.Parent = fill
	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = SHIELD_FILL_GRADIENT
	fillGradient.Transparency = SHIELD_FILL_TRANSPARENCY
	fillGradient.Rotation = 90
	fillGradient.Parent = fill

	local fillTween: Tween? = nil

	return {
		setHealth = function(current: number, max: number)
			local percent = if max > 0 then math.clamp(current / max, 0, 1) else 0
			local barColor, bgColor = getBarColors(percent)
			fill.BackgroundColor3 = barColor
			track.BackgroundColor3 = bgColor
			if fillTween then
				fillTween:Cancel()
			end
			fillTween = TweenService:Create(fill, FILL_TWEEN, { Size = UDim2.fromScale(percent, 1) })
			fillTween:Play()
		end,
		setVisible = function(visible: boolean)
			billboardGui.Enabled = visible
		end,
		destroy = function()
			if fillTween then
				fillTween:Cancel()
			end
			billboardGui:Destroy()
		end,
	}
end

return ShieldHealthBar
