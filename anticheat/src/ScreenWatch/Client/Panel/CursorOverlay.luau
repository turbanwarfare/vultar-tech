--!strict
--!native
--!optimize 2

local Root = script:FindFirstAncestor("Client").Parent
local MainModule = require(Root.Shared.Game).get()
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))

type FusionScope = any
type FusionValue<T> = any
type FusionUseFn = any

export type TrailNodeState = {
	position: FusionValue<UDim2>,
	size: FusionValue<UDim2>,
	visible: FusionValue<boolean>,
	transparency: FusionValue<number>,
}

export type CursorOverlayProps = {
	CursorPosition: FusionValue<Vector2>,
	CursorIcon: FusionValue<string>,
	CursorSize: FusionValue<Vector2?>?,
	IsWatching: FusionValue<boolean>,
	TrailNodes: { TrailNodeState },
}

local DEFAULT_CURSOR_IDS = {
	["131581677"] = true,
	["131718495"] = true,
	["131718487"] = true,
}

local function isDefaultOrIFFCursor(icon: string?): boolean
	if not icon or icon == "" then
		return true
	end
	for id in DEFAULT_CURSOR_IDS do
		if string.find(icon, id, 1, true) ~= nil then
			return true
		end
	end
	return false
end

local function CursorOverlay(scope: FusionScope, props: CursorOverlayProps): Frame
	local trailDots: { Frame } = table.create(#props.TrailNodes)

	for i, node in props.TrailNodes do
		trailDots[i] = scope:New("Frame")({
			Name = "TrailDot_" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = node.position,
			Size = node.size,
			Visible = node.visible,
			BackgroundColor3 = Color3.fromRGB(0, 255, 220),
			BackgroundTransparency = node.transparency,
			BorderSizePixel = 0,
			[Fusion.Children] = {
				scope:New("UIStroke")({
					Color = Color3.fromRGB(0, 0, 0),
					Transparency = 0.25,
					Thickness = 1,
				}),
			},
		})
	end

	return scope:New("Frame")({
		Name = "CursorOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			scope:New("Folder")({
				Name = "TrailContainer",
				[Fusion.Children] = trailDots,
			}),

			scope:New("ImageLabel")({
				Name = "FreeCursorIcon",
				Size = scope:Computed(function(use: FusionUseFn)
					local exact = if props.CursorSize then use(props.CursorSize) else nil
					if exact then
						return UDim2.fromOffset(exact.X, exact.Y)
					end
					local icon = use(props.CursorIcon)
					if isDefaultOrIFFCursor(icon) then
						return UDim2.fromOffset(243, 243)
					end
					return UDim2.fromOffset(64, 64)
				end),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = scope:Computed(function(use: FusionUseFn)
					local pos = use(props.CursorPosition)
					return UDim2.fromOffset(pos.X, pos.Y)
				end),
				Visible = props.IsWatching,
				BackgroundTransparency = 1,
				Image = props.CursorIcon,
				ImageColor3 = Color3.fromRGB(255, 255, 255),
				ScaleType = Enum.ScaleType.Fit,
				[Fusion.Children] = {
					scope:New("UIAspectRatioConstraint")({
						AspectRatio = scope:Computed(function(use: FusionUseFn)
							local exact = if props.CursorSize then use(props.CursorSize) else nil
							return if exact and exact.Y > 0 then exact.X / exact.Y else 1
						end),
						AspectType = Enum.AspectType.FitWithinMaxSize,
					}),
				},
			}),
		},
	})
end

return CursorOverlay
