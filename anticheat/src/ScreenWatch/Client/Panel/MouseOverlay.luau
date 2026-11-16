--!strict
--!native
--!optimize 2

local Root = script:FindFirstAncestor("Client").Parent
local MainModule = require(Root.Shared.Game).get()
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)

type FusionScope = any
type FusionValue<T> = any
type FusionUseFn = any

export type MouseOverlayProps = {
	MouseStates: { [string]: FusionValue<boolean> },
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

local function MouseBtn(
	scope: FusionScope,
	props: {
		Label: string,
		IsActive: FusionValue<boolean>?,
		Width: number?,
		Height: number?,
	}
): Frame
	local active = props.IsActive or scope:Value(false)
	local width = props.Width or 52
	local height = props.Height or 30

	local bgColor = scope:Computed(function(use: FusionUseFn)
		return if use(active)
			then Color3.fromRGB(220, 50, 50)
			else Theme.Colors.Black[800]
	end)

	local textColor = scope:Computed(function(use: FusionUseFn)
		return if use(active)
			then Theme.Colors.White
			else Theme.Colors.Black[300]
	end)

	local strokeColor = scope:Computed(function(use: FusionUseFn)
		return if use(active)
			then Color3.fromRGB(255, 100, 100)
			else Theme.Colors.Black[650]
	end)

	return scope:New("Frame")({
		Name = props.Label .. "Btn",
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = bgColor,
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Small,
			}),
			scope:New("UIStroke")({
				Color = strokeColor,
				Thickness = 1,
			}),
			scope:New("TextLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = props.Label,
				TextColor3 = textColor,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
			}),
		},
	})
end

local function MouseOverlay(scope: FusionScope, props: MouseOverlayProps): Frame
	local states = props.MouseStates

	return scope:New("Frame")({
		Name = "MouseOverlay",
		Size = UDim2.fromOffset(130, 44),
		Position = props.Position or UDim2.new(0, 230, 1, -64),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Theme.Colors.Black[900],
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Medium,
			}),
			scope:New("UIStroke")({
				Color = Theme.Colors.Black[650],
				Thickness = 1,
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 7),
				PaddingBottom = UDim.new(0, 7),
				PaddingLeft = UDim.new(0, 7),
				PaddingRight = UDim.new(0, 7),
			}),
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),

			MouseBtn(scope, { Label = "LMB", IsActive = states["LMB"], Width = 54, Height = 30 }),
			MouseBtn(scope, { Label = "RMB", IsActive = states["RMB"], Width = 54, Height = 30 }),
		},
	})
end

return MouseOverlay
