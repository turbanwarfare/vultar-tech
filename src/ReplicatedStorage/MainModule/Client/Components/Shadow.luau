--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Types = require(MainModule.Shared.Types)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>

export type ShadowProps = {
	Size: FusionCanBeState<UDim2>?,
	Position: FusionCanBeState<UDim2>?,
	AnchorPoint: FusionCanBeState<Vector2>?,
	Spread: number?,
	OffsetX: number?,
	OffsetY: number?,
	Transparency: FusionCanBeState<number>?,
	Color: FusionCanBeState<Color3>?,
	ZIndex: number?,
}

local SHADOW_ASSET = "rbxassetid://1316045217"
local SLICE_CENTER = Rect.new(32, 32, 96, 96)

local DEFAULT_SPREAD = 24
local DEFAULT_OFFSET_Y = 4
local DEFAULT_TRANSPARENCY = 0.5
local DEFAULT_COLOR = Color3.fromRGB(0, 0, 0)

local function Shadow(scope: FusionScope, props: ShadowProps): ImageLabel
	local spread = props.Spread or DEFAULT_SPREAD
	local offsetX = props.OffsetX or 0
	local offsetY = props.OffsetY or DEFAULT_OFFSET_Y

	return scope:New("ImageLabel")({
		Name = "Shadow",
		Size = props.Size or UDim2.new(1, spread * 2, 1, spread * 2),
		Position = props.Position or UDim2.new(0.5, offsetX, 0.5, offsetY),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = SHADOW_ASSET,
		ImageColor3 = props.Color or DEFAULT_COLOR,
		ImageTransparency = props.Transparency or DEFAULT_TRANSPARENCY,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = SLICE_CENTER,
		ZIndex = props.ZIndex or 0,
	})
end

return Shadow
