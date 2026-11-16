--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>

export type ShadowProps = {
	Size: UDim2?,
	Transparency: number?,
	ZIndex: number?,
}

local BLACK = Color3.new(0, 0, 0)
local SHADOW_LAYER_NAMES = { "Shadow1", "Shadow2", "Shadow3", "Shadow4", "Shadow5" }
local SHADOW_LAYERS = {
	{ spread = 3, transparency = 0.88 },
	{ spread = 6, transparency = 0.90 },
	{ spread = 12, transparency = 0.92 },
	{ spread = 20, transparency = 0.94 },
	{ spread = 32, transparency = 0.96 },
}

local function Shadow(scope: FusionScope, props: ShadowProps?): Frame
	local p = props or {}
	local baseZIndex = p.ZIndex or 0
	local baseTransparency = p.Transparency or 0

	local shadowLayers: { Instance } = {}

	for i, layer in ipairs(SHADOW_LAYERS) do
		table.insert(shadowLayers, scope:New("Frame")({
			Name = SHADOW_LAYER_NAMES[i],
			Size = UDim2.new(1, layer.spread * 2, 1, layer.spread * 2),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = BLACK,
			BackgroundTransparency = layer.transparency + baseTransparency,
			BorderSizePixel = 0,
			ZIndex = baseZIndex - i,

			[Fusion.Children] = {
				scope:New("UICorner")({
					CornerRadius = UDim.new(0, 4 + layer.spread // 3),
				}),
			},
		}))
	end

	return scope:New("Frame")({
		Name = "ShadowContainer",
		Size = p.Size or UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = baseZIndex,

		[Fusion.Children] = shadowLayers,
	})
end

return Shadow
