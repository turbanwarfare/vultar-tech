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

export type KeyboardOverlayProps = {
	KeyStates: { [string]: FusionValue<boolean> },
	TargetFOV: FusionValue<number>?,
	TargetResolution: FusionValue<Vector2>?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

local function KeyBox(
	scope: FusionScope,
	props: {
		Label: string,
		IsActive: FusionValue<boolean>?,
		Width: number?,
		Height: number?,
	}
): Frame
	local active = props.IsActive or scope:Value(false)
	local width = props.Width or 36
	local height = props.Height or 36

	local bgColor = scope:Computed(function(use: FusionUseFn)
		return if use(active) then Color3.fromRGB(0, 170, 255) else Theme.Colors.Black[800]
	end)

	local textColor = scope:Computed(function(use: FusionUseFn)
		return if use(active) then Theme.Colors.White else Theme.Colors.Black[300]
	end)

	local strokeColor = scope:Computed(function(use: FusionUseFn)
		return if use(active) then Color3.fromRGB(100, 220, 255) else Theme.Colors.Black[650]
	end)

	return scope:New("Frame")({
		Name = props.Label .. "Key",
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

local function KeyboardOverlay(scope: FusionScope, props: KeyboardOverlayProps): Frame
	local states = props.KeyStates

	local resText = scope:Computed(function(use: FusionUseFn)
		local res = if props.TargetResolution then use(props.TargetResolution) else Vector2.new(1920, 1080)
		local rx = if res and res.X > 0 then math.round(res.X) else 1920
		local ry = if res and res.Y > 0 then math.round(res.Y) else 1080
		return `{rx}x{ry}`
	end)

	local fovText = scope:Computed(function(use: FusionUseFn)
		local f = if props.TargetFOV then math.round(use(props.TargetFOV) or 70) else 70
		return `FOV: {f}`
	end)

	return scope:New("Frame")({
		Name = "KeyboardOverlay",
		Size = UDim2.fromOffset(200, 168),
		Position = props.Position or UDim2.new(0, 20, 1, -188),
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
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 5),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),

			scope:New("Frame")({
				Name = "ViewportInfoBar",
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundColor3 = Theme.Colors.Black[800],
				BorderSizePixel = 0,
				LayoutOrder = 0,
				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Small,
					}),
					scope:New("UIStroke")({
						Color = Theme.Colors.Black[650],
						Thickness = 1,
					}),
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
					}),
					scope:New("TextLabel")({
						Name = "ResolutionLabel",
						Size = UDim2.fromScale(0.55, 1),
						Position = UDim2.fromScale(0, 0),
						BackgroundTransparency = 1,
						Text = resText,
						TextColor3 = Theme.Colors.White,
						TextSize = Theme.Text.XSmall,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("TextLabel")({
						Name = "FOVLabel",
						Size = UDim2.fromScale(0.45, 1),
						Position = UDim2.fromScale(0.55, 0),
						BackgroundTransparency = 1,
						Text = fovText,
						TextColor3 = Theme.Colors.White,
						TextSize = Theme.Text.XSmall,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Right,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "Row1",
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 5),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					}),
					KeyBox(scope, { Label = "Q", IsActive = states["ZOOM"] }),
					KeyBox(scope, { Label = "W", IsActive = states["W"] }),
					KeyBox(scope, { Label = "R", IsActive = states["RELOAD"] }),
					KeyBox(scope, { Label = "F", IsActive = states["SPRINT"] }),
				},
			}),

			scope:New("Frame")({
				Name = "Row2",
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 5),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					}),
					KeyBox(scope, { Label = "A", IsActive = states["A"] }),
					KeyBox(scope, { Label = "S", IsActive = states["S"] }),
					KeyBox(scope, { Label = "D", IsActive = states["D"] }),
					KeyBox(scope, { Label = "C", IsActive = states["CROUCH"] }),
				},
			}),

			scope:New("Frame")({
				Name = "Row3",
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundTransparency = 1,
				LayoutOrder = 3,
				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 5),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					}),
					KeyBox(scope, { Label = "SPACE", IsActive = states["SPACE"], Width = 160 }),
				},
			}),
		},
	})
end

return KeyboardOverlay
