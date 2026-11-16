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

export type InputProps = {
	Value: FusionCanBeState<number>,
	Placeholder: string?,
	OnSubmit: ((string) -> ())?,
	Size: UDim2?,
	NumberOnly: boolean?,
}

local function Input(scope: FusionScope, props: InputProps): Frame
	local isFocused = scope:Value(false)

	local borderColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isFocused) then
				return Theme.Input.BorderFocused
			end
			return Theme.Input.Border
		end),
		Theme.Spring.Default.Speed
	)

	local displayText = scope:Computed(function(use: FusionUseFn)
		local value = use(props.Value)
		if value == 0 then
			return ""
		end
		return string.format("%.0f", value)
	end)

	local textBoxInstance: TextBox? = nil

	local textBox = scope:New("TextBox")({
		Name = "TextBox",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = displayText,
		PlaceholderText = props.Placeholder or "CURSOR ID",
		PlaceholderColor3 = Theme.Input.Placeholder,
		TextColor3 = Theme.Input.Text,
		TextSize = Theme.Text.Small,
		Font = Theme.Text.Semibold,
		TextXAlignment = Enum.TextXAlignment.Center,
		ClearTextOnFocus = false,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Small,
			}),
		},

		[Fusion.OnEvent("Focused")] = function()
			isFocused:set(true)
		end,

		[Fusion.OnEvent("FocusLost")] = function(enterPressed: boolean, _inputObj: InputObject)
			isFocused:set(false)

			if enterPressed and props.OnSubmit and textBoxInstance then
				local text = textBoxInstance.Text
				if props.NumberOnly then
					local num = tonumber(text)
					if num and num > 0 then
						props.OnSubmit(string.format("%.0f", num))
					elseif text == "" or num == 0 then
						textBoxInstance.Text = ""
						props.OnSubmit("0")
					end
				else
					props.OnSubmit(text)
				end
			end
		end,
	})

	textBoxInstance = textBox :: TextBox

	return scope:New("Frame")({
		Name = "Input",
		Size = props.Size or UDim2.fromOffset(120, 20),
		BackgroundColor3 = Theme.Input.Background,
		BorderSizePixel = 0,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Small,
			}),

			scope:New("UIStroke")({
				Color = borderColor,
				Thickness = 1,
				Transparency = Theme.Input.BorderTransparency,
			}),

			textBox,
		},
	})
end

return Input
