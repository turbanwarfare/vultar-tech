--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type NoChatBadgeProps = {
	Adornee: Types.FusionValue<BasePart?>,
}

local function NoChatBadge(scope: FusionScope, props: NoChatBadgeProps): BillboardGui
	local badge = scope:New("Frame")({
		Name = "NoChatBadge",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Chat.Window.Background,
		BackgroundTransparency = Theme.Chat.Window.BackgroundTransparency,
		[Fusion.Children] = {
			Shadow(scope, {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.new(0.5, 0, 0.5, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = 0,
				Transparency = 0.7,
				ZIndex = 0,
			}),
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Medium,
			}),
			scope:New("TextLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "NO CHAT",
				TextColor3 = Theme.Colors.White,
				TextSize = 10,
				Font = Theme.Text.Bold,
				[Fusion.Children] = {
					scope:New("UIStroke")({
						Color = Theme.Chat.Window.Border,
						Thickness = 1,
						Transparency = 0,
					}),
				},
			}),
		},
	})

	return scope:New("BillboardGui")({
		Name = "NoChatBadgeGUI",
		Size = UDim2.fromOffset(58, 20),
		StudsOffset = Vector3.new(0, 2.5, 0),
		StudsOffsetWorldSpace = Vector3.zero,
		SizeOffset = Vector2.new(0, 1.7),
		Adornee = props.Adornee,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = math.huge,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		[Fusion.Children] = {
			badge,
		},
	})
end

return NoChatBadge
