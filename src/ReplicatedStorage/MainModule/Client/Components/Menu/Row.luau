--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)
local SearchEngine = require(script.Parent.SearchEngine)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

local peek: <T>(state: FusionCanBeState<T>) -> T = Fusion.peek

local Toggle = require(script.Parent.Toggle)
local Picker = require(script.Parent.Picker)
local Input = require(script.Parent.Input)
local CursorPicker = require(script.Parent.CursorPicker)
local Slider = require(script.Parent.Slider)
local HitmarkerPicker = require(script.Parent.HitmarkerPicker)
local FontPicker = require(script.Parent.FontPicker)

export type RowProps = {
	Label: string,
	Description: string?,
	ControlType: "Boolean" | "Pick" | "TypeIn" | "Slider" | "CursorPick" | "HitmarkerPick" | "FontPick",
	Value: FusionCanBeState<any>,
	Options: { string }?,
	Min: number?,
	Max: number?,
	Step: number?,
	OnChange: ((any) -> ())?,
	LayoutOrder: number?,
	SearchFilter: FusionCanBeState<string>?,
	SettingKey: string?,
	Restricted: FusionCanBeState<boolean>?,
}

local function Row(scope: FusionScope, props: RowProps): Frame
	local isHovered = scope:Value(false)
	local control: Instance? = nil

	local isBoolean = props.ControlType == "Boolean"

	if isBoolean then
		control = Toggle(scope, {
			Value = props.Value :: FusionCanBeState<boolean>,
			OnChange = props.OnChange :: ((boolean) -> ())?,
		})
	elseif props.ControlType == "Pick" and props.Options then
		control = Picker(scope, {
			Value = props.Value :: FusionCanBeState<number>,
			Options = props.Options,
			OnChange = props.OnChange :: ((number) -> ())?,
		})
	elseif props.ControlType == "TypeIn" then
		local label = props.Label:lower()
		local placeholder = if label:find("cursor") then "CURSOR ID" elseif label:find("sound") then "AUDIO ID" else nil
		control = Input(scope, {
			Value = props.Value :: FusionCanBeState<number>,
			NumberOnly = true,
			Placeholder = placeholder,
			OnSubmit = function(text: string)
				if props.OnChange then
					local num = tonumber(text)
					props.OnChange(num or 0)
				end
			end,
		})
	elseif props.ControlType == "CursorPick" then
		control = CursorPicker(scope, {
			Value = props.Value :: FusionCanBeState<string>,
			OnChange = props.OnChange :: ((string) -> ())?,
		})
	elseif props.ControlType == "Slider" then
		control = Slider(scope, {
			Value = props.Value :: FusionCanBeState<number>,
			Min = props.Min,
			Max = props.Max,
			Step = props.Step,
			OnChange = props.OnChange :: ((number) -> ())?,
		})
	elseif props.ControlType == "HitmarkerPick" then
		control = HitmarkerPicker(scope, {
			Value = props.Value :: FusionCanBeState<number>,
			OnChange = props.OnChange :: ((number) -> ())?,
		})
	elseif props.ControlType == "FontPick" then
		control = FontPicker(scope, {
			Value = props.Value :: FusionCanBeState<string>,
			OnChange = props.OnChange :: ((string) -> ())?,
		})
	end

	local rowHeight = 30
	if props.ControlType == "CursorPick" then
		rowHeight = 58
	elseif props.ControlType == "HitmarkerPick" then
		rowHeight = 38
	end

	local searchScore = scope:Computed(function(use: FusionUseFn)
		if not props.SearchFilter then return 1000 end
		local query = use(props.SearchFilter)
		if query == "" then return 1000 end
		return SearchEngine.score(query, props.Label, props.Description or "", props.SettingKey)
	end)

	local isVisible = scope:Computed(function(use: FusionUseFn)
		return use(searchScore) > 0
	end)

	local dynamicLayoutOrder = scope:Computed(function(use: FusionUseFn)
		if not props.SearchFilter then return props.LayoutOrder or 0 end
		local query = use(props.SearchFilter)
		if query == "" then return props.LayoutOrder or 0 end
		local score = use(searchScore)
		return (10000 - score) * 100 + (props.LayoutOrder or 0)
	end)

	local borderColor = scope:Computed(function(use: FusionUseFn)
		return if use(isHovered) then Theme.Border.Active else Theme.Row.Border
	end)

	local borderTransparency = scope:Computed(function(use: FusionUseFn)
		return if use(isHovered) then 0 else Theme.Row.BorderTransparency
	end)

	local function onRowClick()
		if isBoolean and props.OnChange then
			local currentValue = peek(props.Value)
			props.OnChange(not currentValue)
		end
	end

	local shadowTransparency = scope:Computed(function(use: FusionUseFn)
		return if use(isHovered) then 0.75 else 0.82
	end)

	local rowChildren: { Instance? } = {
		scope:New("UICorner")({
			CornerRadius = Theme.Radius.Medium,
		}),

		scope:New("UIStroke")({
			Color = borderColor,
			Thickness = 1,
			Transparency = borderTransparency,
		}),

		scope:New("UIPadding")({
			PaddingLeft = UDim.new(0, Theme.Spacing.Medium),
			PaddingRight = UDim.new(0, 10),
		}),

		scope:New("TextLabel")({
			Name = "Label",
			Size = UDim2.fromScale(0.45, 1),
			BackgroundTransparency = 1,
			Text = string.upper(props.Label),
			TextColor3 = Theme.Foreground.Secondary,
			TextSize = Theme.Text.Medium,
			Font = Theme.Text.Bold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		scope:New("Frame")({
			Name = "ControlContainer",
			Size = UDim2.fromScale(0.55, 1),
			Position = UDim2.fromScale(0.45, 0),
			BackgroundTransparency = 1,

			[Fusion.Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				control,
			},
		}),

		scope:New("TextButton")({
			Name = "Hitbox",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 0,

			[Fusion.OnEvent("MouseEnter")] = function()
				isHovered:set(true)
			end,

			[Fusion.OnEvent("MouseLeave")] = function()
				isHovered:set(false)
			end,

			[Fusion.OnEvent("Activated")] = onRowClick,
		}),

		if props.Restricted then scope:New("Frame")({
			Name = "RestrictedOverlay",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Row.Background,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			ZIndex = 2,
			Visible = scope:Computed(function(use: FusionUseFn)
				if not props.Restricted then return false end
				return use(props.Restricted)
			end),

			[Fusion.Children] = {
				scope:New("UICorner")({
					CornerRadius = Theme.Radius.Medium,
				}),

				scope:New("TextLabel")({
					Name = "LockedLabel",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "LOCKED - WINDOW RESOLUTION TOO NARROW",
					TextColor3 = Theme.Foreground.Disabled,
					TextSize = 10,
					Font = Theme.Text.Semibold,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),

				scope:New("TextButton")({
					Name = "ClickBlocker",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 3,
				}),
			},
		}) else nil,
	}

	return scope:New("Frame")({
		Name = props.Label,
		Size = UDim2.new(1, -24, 0, rowHeight + 4),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		LayoutOrder = dynamicLayoutOrder,
		Visible = isVisible,

		[Fusion.Children] = {
			Shadow(scope, {
				Size = UDim2.new(1, 8, 1, 4),
				Position = UDim2.new(0.5, 0, 0.5, 2),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = 0,
				Transparency = shadowTransparency,
				ZIndex = 0,
			}),

			scope:New("Frame")({
				Name = "RowContent",
				Size = UDim2.new(1, 0, 0, rowHeight),
				Position = UDim2.fromOffset(0, 2),
				BackgroundColor3 = Theme.Row.Background,
				BackgroundTransparency = Theme.Row.BackgroundTransparency,
				BorderSizePixel = 0,
				ZIndex = 1,

				[Fusion.Children] = rowChildren,
			}),
		},
	})
end

return Row
