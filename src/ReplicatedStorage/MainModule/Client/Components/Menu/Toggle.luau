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

local peek: <T>(state: FusionCanBeState<T>) -> T = Fusion.peek

export type ToggleProps = {
	Value: FusionCanBeState<boolean>,
	OnChange: ((boolean) -> ())?,
}

local function Toggle(scope: FusionScope, props: ToggleProps): TextButton
	local isHovered = scope:Value(false)

	local isOn = scope:Computed(function(use: FusionUseFn)
		local val = use(props.Value)
		return val == true
	end)

	local backgroundColor = scope:Computed(function(use: FusionUseFn)
		local value = use(isOn)
		local hovered = use(isHovered)
		if value then
			return if hovered then Theme.Toggle.On.BackgroundHover else Theme.Toggle.On.Background
		else
			return if hovered then Theme.Toggle.Off.BackgroundHover else Theme.Toggle.Off.Background
		end
	end)

	return scope:New("TextButton")({
		Name = "Toggle",
		Size = UDim2.fromOffset(80, 18),
		BackgroundColor3 = backgroundColor,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Large,
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
				local currentValue = peek(props.Value)
				props.OnChange(not currentValue)
			end
		end,
	})
end

return Toggle
