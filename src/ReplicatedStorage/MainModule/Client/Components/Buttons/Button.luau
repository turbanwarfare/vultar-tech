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

export type ButtonVariant = "primary" | "secondary" | "destructive" | "ghost" | "outline"

export type ButtonProps = {
	Text: FusionCanBeState<string>,
	Variant: ButtonVariant?,
	Size: FusionCanBeState<UDim2>?,
	Position: FusionCanBeState<UDim2>?,
	AnchorPoint: FusionCanBeState<Vector2>?,
	LayoutOrder: number?,
	Disabled: FusionCanBeState<boolean>?,
	Loading: FusionCanBeState<boolean>?,
	ZIndex: number?,
	OnClick: (() -> ())?,
}

local VARIANT_STYLES = {
	primary = Theme.Button.Primary,
	secondary = Theme.Button.Secondary,
	destructive = Theme.Button.Destructive,
	ghost = Theme.Button.Ghost,
	outline = Theme.Button.Outline,
}

local GRADIENT_SEQUENCES = {
	primary = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(0.88, 0.88, 0.88)),
	}),
	secondary = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(0.92, 0.92, 0.92)),
	}),
	destructive = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(0.88, 0.88, 0.88)),
	}),
}

local function Button(scope: FusionScope, props: ButtonProps): TextButton
	local variant = props.Variant or "primary"
	local style = VARIANT_STYLES[variant] or Theme.Button.Primary

	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)

	local isDisabled = scope:Computed(function(use: FusionUseFn)
		local disabled = props.Disabled
		local loading = props.Loading
		if disabled and typeof(disabled) == "table" then
			if use(disabled :: any) then
				return true
			end
		elseif disabled == true then
			return true
		end
		if loading and typeof(loading) == "table" then
			if use(loading :: any) then
				return true
			end
		elseif loading == true then
			return true
		end
		return false
	end)

	local backgroundColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDisabled) then
				return Theme.Background.Tertiary
			end
			if use(isPressed) then
				return style.BackgroundHover
			end
			if use(isHovered) then
				return style.BackgroundHover
			end
			return style.Background
		end),
		Theme.Spring.Default.Speed
	)

	local textColor = scope:Computed(function(use: FusionUseFn)
		if use(isDisabled) then
			return Theme.Foreground.Disabled
		end
		return style.Foreground
	end)

	local displayText = scope:Computed(function(use: FusionUseFn)
		local loading = props.Loading
		if loading then
			local isLoading = if typeof(loading) == "table" then use(loading :: any) else loading
			if isLoading then
				return "LOADING..."
			end
		end
		local text = props.Text
		if typeof(text) == "table" then
			return use(text :: any)
		end
		return text :: string
	end)

	local scale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isPressed) and not use(isDisabled) then
				return 0.98
			end
			return 1
		end),
		Theme.Spring.Snappy.Speed
	)

	local children: { Instance } = {
		scope:New("UICorner")({
			CornerRadius = Theme.Radius.Medium,
		}),

		scope:New("UIScale")({
			Scale = scale,
		}),
	}

	local gradientSequence = GRADIENT_SEQUENCES[variant]
	if gradientSequence then
		table.insert(children, scope:New("UIGradient")({
			Color = gradientSequence,
			Rotation = 90,
		}))
	end

	if variant == "outline" then
		table.insert(children, scope:New("UIStroke")({
			Color = style.Border,
			Thickness = 1,
			Transparency = Theme.Stroke.Default,
		}))
	end

	return scope:New("TextButton")({
		Name = "Button",
		Size = props.Size or UDim2.fromOffset(120, 36),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = backgroundColor,
		BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
			if variant == "ghost" and not use(isHovered) and not use(isPressed) then
				return 1
			end
			return 0
		end),
		BorderSizePixel = 0,
		Text = displayText,
		TextColor3 = textColor,
		TextSize = Theme.Text.Medium,
		Font = Theme.Text.Bold,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		AutoButtonColor = false,

		[Fusion.Children] = children,

		[Fusion.OnEvent("MouseEnter")] = function()
			if not peek(isDisabled) then
				isHovered:set(true)
			end
		end,

		[Fusion.OnEvent("MouseLeave")] = function()
			isHovered:set(false)
			isPressed:set(false)
		end,

		[Fusion.OnEvent("MouseButton1Down")] = function()
			if not peek(isDisabled) then
				isPressed:set(true)
			end
		end,

		[Fusion.OnEvent("MouseButton1Up")] = function()
			isPressed:set(false)
		end,

		[Fusion.OnEvent("Activated")] = function()
			if not peek(isDisabled) and props.OnClick then
				props.OnClick()
			end
		end,
	})
end

return Button
