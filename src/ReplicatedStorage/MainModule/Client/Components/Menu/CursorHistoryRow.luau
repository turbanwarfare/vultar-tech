--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)
local SearchEngine = require(script.Parent.SearchEngine)
local Input = require(script.Parent.Input)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

export type CursorHistoryRowProps = {
	Label: string,
	Description: string?,
	Value: FusionCanBeState<number>,
	OnChange: ((number) -> ())?,
	LayoutOrder: number?,
	SearchFilter: FusionCanBeState<string>?,
	SettingKey: string?,
}

local ROW_HEIGHT = 30

local function CursorHistoryRow(scope: FusionScope, props: CursorHistoryRowProps): Frame
	local isHovered = scope:Value(false)

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
		return 10000 - score
	end)

	local borderColor = scope:Computed(function(use: FusionUseFn)
		return if use(isHovered) then Theme.Border.Active else Theme.Row.Border
	end)

	local borderTransparency = scope:Computed(function(use: FusionUseFn)
		return if use(isHovered) then 0 else Theme.Row.BorderTransparency
	end)

	local shadowTransparency = scope:Computed(function(use: FusionUseFn)
		return if use(isHovered) then 0.75 else 0.82
	end)

	local inputControl = Input(scope, {
		Value = props.Value :: FusionCanBeState<number>,
		NumberOnly = true,
		Placeholder = "CURSOR ID",
		OnSubmit = function(text: string)
			if props.OnChange then
				local num = tonumber(text)
				props.OnChange(num or 0)
			end
		end,
	})

	return scope:New("Frame")({
		Name = props.Label,
		Size = UDim2.new(1, -24, 0, ROW_HEIGHT + 4),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		LayoutOrder = dynamicLayoutOrder,
		Visible = isVisible,

		[Fusion.OnEvent("MouseEnter")] = function()
			isHovered:set(true)
		end,

		[Fusion.OnEvent("MouseLeave")] = function()
			isHovered:set(false)
		end,

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
				Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
				Position = UDim2.fromOffset(0, 2),
				BackgroundColor3 = Theme.Row.Background,
				BackgroundTransparency = Theme.Row.BackgroundTransparency,
				BorderSizePixel = 0,
				ZIndex = 1,

				[Fusion.Children] = {
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
						Size = UDim2.fromScale(0.5, 1),
						BackgroundTransparency = 1,
						Text = string.upper(props.Label),
						TextColor3 = Theme.Foreground.Secondary,
						TextSize = Theme.Text.Medium,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),

					scope:New("Frame")({
						Name = "ControlContainer",
						Size = UDim2.fromScale(0.5, 1),
						Position = UDim2.fromScale(0.5, 0),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Right,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}),

							inputControl,
						},
					}),
				},
			}),
		},
	})
end

return CursorHistoryRow
