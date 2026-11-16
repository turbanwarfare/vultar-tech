--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

export type HitmarkerPickerProps = {
	Value: FusionCanBeState<number>,
	OnChange: ((number) -> ())?,
}

local function HitmarkerPicker(scope: FusionScope, props: HitmarkerPickerProps): Frame
	local buttons: { Instance } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
		}),
	}

	for index, asset in SettingsConfig.HitmarkerAssets do
		local isSelected = scope:Computed(function(use: FusionUseFn)
			return use(props.Value) == index
		end)

		local isHovered = scope:Value(false)

		local borderColor = scope:Spring(
			scope:Computed(function(use: FusionUseFn)
				if use(isSelected) then
					return Theme.Border.Active
				elseif use(isHovered) then
					return Theme.Border.Active
				end
				return Theme.Border.Default
			end),
			Theme.Spring.Default.Speed
		)

		local button = scope:New("TextButton")({
			Name = "Hitmarker" .. index,
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = Theme.Background.Secondary,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = index,

			[Fusion.Children] = {
				scope:New("UICorner")({
					CornerRadius = Theme.Radius.Small,
				}),

				scope:New("UIStroke")({
					Color = borderColor,
					Thickness = scope:Computed(function(use: FusionUseFn)
						return if use(isSelected) then 2 else 1
					end),
				}),

				scope:New("ImageLabel")({
					Name = "Icon",
					Size = asset.size or UDim2.fromScale(0.8, 0.8),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = asset.id,
					ImageColor3 = scope:Computed(function(use: FusionUseFn)
						if use(isSelected) then
							return Theme.Colors.SuccessHover
						end
						return Theme.Foreground.Primary
					end),
				}),
			},

			[Fusion.OnEvent("MouseEnter")] = function()
				isHovered:set(true)
			end,

			[Fusion.OnEvent("MouseLeave")] = function()
				isHovered:set(false)
			end,

			[Fusion.OnEvent("Activated")] = function()
				if props.OnChange then
					props.OnChange(index)
				end
			end,
		})

		table.insert(buttons, button)
	end

	return scope:New("Frame")({
		Name = "HitmarkerPicker",
		Size = UDim2.fromOffset(256, 28),
		BackgroundTransparency = 1,

		[Fusion.Children] = buttons,
	})
end

return HitmarkerPicker
