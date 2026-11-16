--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

export type PickerProps = {
	Value: FusionCanBeState<number>,
	Options: { string },
	OnChange: ((number) -> ())?,
}

local function Picker(scope: FusionScope, props: PickerProps): Frame
	local options = props.Options
	local buttonHeight = 22
	local gap = 2
	local paddingH = 12

	local children: { Instance } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, gap),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),

		scope:New("UIPadding")({
			PaddingLeft = UDim.new(0, gap),
			PaddingRight = UDim.new(0, gap),
			PaddingTop = UDim.new(0, gap),
			PaddingBottom = UDim.new(0, gap),
		}),
	}

	for i, optionText in options do
		local isSelected = scope:Computed(function(use: FusionUseFn)
			return use(props.Value) == i
		end)

		local isHovered = scope:Value(false)

		local backgroundColor = scope:Computed(function(use: FusionUseFn)
			if use(isSelected) then
				return Theme.Colors.Success
			elseif use(isHovered) then
				return Theme.Background.Accent
			end
			return Theme.Background.Tertiary
		end)

		local textColor = scope:Computed(function(use: FusionUseFn)
			if use(isSelected) then
				return Theme.Foreground.Primary
			end
			return Theme.Foreground.Muted
		end)

		local buttonName = tostring(i)
		local optionLabel = string.upper(optionText)
		local button = scope:New("TextButton")({
			Name = buttonName,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = backgroundColor,
			BorderSizePixel = 0,
			Text = optionLabel,
			TextColor3 = textColor,
			TextSize = Theme.Text.Small,
			Font = Theme.Text.Bold,
			LayoutOrder = i,
			AutoButtonColor = false,

			[Fusion.Children] = {
				scope:New("UICorner")({
					CornerRadius = Theme.Radius.Small,
				}),

				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, paddingH),
					PaddingRight = UDim.new(0, paddingH),
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
					props.OnChange(i)
				end
			end,
		})

		table.insert(children, button)
	end

	return scope:New("Frame")({
		Name = "SettingsPicker",
		Size = UDim2.fromOffset(0, buttonHeight + (gap * 2)),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Background.Secondary,
		BorderSizePixel = 0,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Medium,
			}),

			scope:New("UIStroke")({
				Color = Theme.Border.Default,
				Thickness = 1,
				Transparency = 0,
			}),

			children,
		},
	})
end

return Picker
