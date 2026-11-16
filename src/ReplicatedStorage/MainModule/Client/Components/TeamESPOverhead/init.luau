--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local SettingsEnums = require(MainModule.Shared.Config.Settings.SettingsEnums)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type TeamESPOverheadProps = {
	DisplayName: Types.FusionValue<string>,
	Health: Types.FusionValue<number>,
	MaxHealth: Types.FusionValue<number>,
	Mode: Types.FusionValue<number>,
	Adornee: Types.FusionValue<BasePart?>,
}

local COLOR_FULL = Color3.fromRGB(85, 255, 85)
local COLOR_MID = Color3.fromRGB(255, 200, 50)
local COLOR_LOW = Color3.fromRGB(255, 80, 80)
local COLOR_DEAD = Color3.fromRGB(0, 0, 0)
local COLOR_GODDED = Color3.fromRGB(255, 195, 60)
local COLOR_WHITE = Theme.Colors.White
local COLOR_STROKE = Color3.fromRGB(60, 60, 60)
local COLOR_BAR_BG = Color3.fromRGB(35, 35, 38)
local COLOR_STROKE_LIGHT = Color3.fromRGB(255, 255, 255)

local GODDED_THRESHOLD = 999999

local BAR_WIDTH = 40
local BAR_HEIGHT = 4
local BAR_CORNER_RADIUS = UDim.new(0, BAR_HEIGHT / 2)
local NAME_SIZE = 11
local CONDENSED_SIZE = 10
local MAX_NAME_LENGTH = 12
local VERTICAL_OFFSET = 2.5

local MODE_CONDENSED = SettingsEnums.TeamESPOverhead.Condensed

local SIZE_BILLBOARD = UDim2.fromOffset(100, 40)
local SIZE_FULL = UDim2.fromScale(1, 1)
local SIZE_NAME = UDim2.new(1, 0, 0, NAME_SIZE)
local SIZE_BAR = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT)
local POS_CENTER = UDim2.fromScale(0.5, 0.5)
local POS_NAME = UDim2.fromScale(0.5, 0)
local POS_BAR = UDim2.new(0.5, 0, 0, NAME_SIZE + 3)
local POS_ZERO = UDim2.fromScale(0, 0)
local ANCHOR_CENTER = Vector2.new(0.5, 0.5)
local ANCHOR_TOP_CENTER = Vector2.new(0.5, 0)
local OFFSET_VERTICAL = Vector3.new(0, VERTICAL_OFFSET, 0)
local OFFSET_ZERO = Vector3.zero

local function TeamESPOverhead(scope: FusionScope, props: TeamESPOverheadProps): BillboardGui
	local displayState = scope:Computed(function(use: FusionUseFn)
		local health = use(props.Health)
		local maxHealth = use(props.MaxHealth)
		local mode = use(props.Mode)
		local displayName = use(props.DisplayName)

		local isCondensed = mode == MODE_CONDENSED
		local truncatedName = if #displayName <= MAX_NAME_LENGTH
			then displayName
			else string.sub(displayName, 1, MAX_NAME_LENGTH)

		local isGodded = health >= GODDED_THRESHOLD
			or health == math.huge
			or maxHealth >= GODDED_THRESHOLD
			or maxHealth == math.huge

		local percent: number
		if isGodded then
			percent = 1
		elseif maxHealth <= 0 then
			percent = 0
		else
			local ratio = health / maxHealth
			percent = if ratio == ratio then math.clamp(ratio, 0, 1) else 1
		end

		local barColor: Color3
		if isGodded then
			barColor = COLOR_GODDED
		elseif percent <= 0 then
			barColor = COLOR_DEAD
		elseif percent > 0.5 then
			barColor = COLOR_MID:Lerp(COLOR_FULL, (percent - 0.5) * 2)
		else
			barColor = COLOR_LOW:Lerp(COLOR_MID, percent * 2)
		end

		local nameColor: Color3
		if percent <= 0 and not isGodded then
			nameColor = COLOR_DEAD
		elseif not isCondensed or isGodded or percent > 0.5 then
			nameColor = COLOR_WHITE
		else
			nameColor = COLOR_LOW:Lerp(COLOR_MID, percent * 2)
		end

		local healthStr = if isGodded then "inf" else tostring(math.round(health))

		return {
			isCondensed = isCondensed,
			truncatedName = truncatedName,
			percent = percent,
			barColor = barColor,
			nameColor = nameColor,
			condensedText = truncatedName .. " • " .. healthStr,
		}
	end)

	local condensedText = scope:Computed(function(use: FusionUseFn)
		return use(displayState).condensedText
	end)

	local nameColor = scope:Computed(function(use: FusionUseFn)
		return use(displayState).nameColor
	end)

	local barColor = scope:Computed(function(use: FusionUseFn)
		return use(displayState).barColor
	end)

	local healthPercent = scope:Computed(function(use: FusionUseFn)
		return use(displayState).percent
	end)

	local truncatedName = scope:Computed(function(use: FusionUseFn)
		return use(displayState).truncatedName
	end)

	local isCondensed = scope:Computed(function(use: FusionUseFn)
		return use(displayState).isCondensed
	end)

	local condensedLabel = scope:New("TextLabel")({
		Name = "CondensedLabel",
		Size = SIZE_FULL,
		Position = POS_CENTER,
		AnchorPoint = ANCHOR_CENTER,
		BackgroundTransparency = 1,
		Text = condensedText,
		TextColor3 = nameColor,
		TextStrokeColor3 = COLOR_STROKE,
		TextStrokeTransparency = 0.5,
		TextSize = CONDENSED_SIZE,
		Font = Theme.Text.Bold,
		Visible = isCondensed,
	})

	local detailedNameLabel = scope:New("TextLabel")({
		Name = "DetailedName",
		Size = SIZE_NAME,
		Position = POS_NAME,
		AnchorPoint = ANCHOR_TOP_CENTER,
		BackgroundTransparency = 1,
		Text = truncatedName,
		TextColor3 = nameColor,
		TextStrokeColor3 = COLOR_STROKE,
		TextStrokeTransparency = 0.5,
		TextSize = NAME_SIZE,
		Font = Theme.Text.Bold,
	})

	local healthBarContainer = scope:New("Frame")({
		Name = "HealthBar",
		Size = SIZE_BAR,
		Position = POS_BAR,
		AnchorPoint = ANCHOR_TOP_CENTER,
		BackgroundColor3 = COLOR_BAR_BG,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = BAR_CORNER_RADIUS,
			}),
			scope:New("UIStroke")({
				Color = COLOR_STROKE_LIGHT,
				Thickness = 1,
				Transparency = 0.85,
			}),
			scope:New("Frame")({
				Name = "HealthFill",
				Size = scope:Computed(function(use: FusionUseFn)
					return UDim2.fromScale(use(healthPercent), 1)
				end),
				Position = POS_ZERO,
				BackgroundColor3 = barColor,
				BorderSizePixel = 0,
				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = BAR_CORNER_RADIUS,
					}),
				},
			}),
		},
	})

	local detailedContainer = scope:New("Frame")({
		Name = "DetailedContainer",
		Size = SIZE_FULL,
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use: FusionUseFn)
			return not use(isCondensed)
		end),
		[Fusion.Children] = {
			detailedNameLabel,
			healthBarContainer,
		},
	})

	return scope:New("BillboardGui")({
		Name = "TeamESPOverhead",
		Size = SIZE_BILLBOARD,
		StudsOffset = OFFSET_VERTICAL,
		StudsOffsetWorldSpace = OFFSET_ZERO,
		Adornee = props.Adornee,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = math.huge,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		[Fusion.Children] = {
			condensedLabel,
			detailedContainer,
		},
	})
end

return TeamESPOverhead
