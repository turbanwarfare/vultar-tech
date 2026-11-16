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

local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)

export type CursorPickerProps = {
	Value: FusionCanBeState<number>,
	OnChange: ((number) -> ())?,
}

local BUTTON_SIZE = 44

local function CursorPicker(scope: FusionScope, props: CursorPickerProps): Frame
	local cursorCount = #SettingsConfig.Cursors
	local spacing = 8

	local children: { Instance } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, spacing),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}

	for i = 1, cursorCount do
		local cursorData = SettingsConfig.Cursors[i]
		local cursorId = cursorData and cursorData.id or 0
		local cursorName = cursorData and cursorData.name or "?"
		local iconScale = cursorData and cursorData.pickerScale or 1.0

		local isSelected = scope:Computed(function(use: FusionUseFn)
			return use(props.Value) == i
		end)

		local isHovered = scope:Value(false)

		local backgroundColor = scope:Spring(
			scope:Computed(function(use: FusionUseFn)
				if use(isSelected) then
					return Theme.Colors.Success
				elseif use(isHovered) then
					return Theme.Background.Overlay
				end
				return Theme.Background.Elevated
			end),
			Theme.Spring.Gentle.Speed
		)

		local borderColor = scope:Spring(
			scope:Computed(function(use: FusionUseFn)
				if use(isSelected) then
					return Theme.Border.Active
				elseif use(isHovered) then
					return Theme.Border.Active
				end
				return Theme.Border.Default
			end),
			Theme.Spring.Gentle.Speed
		)

		local cursorIdStr = tostring(cursorId)
		local iconContent: Instance = scope:New("ImageLabel")({
			Name = "CursorIcon",
			Size = UDim2.fromScale(iconScale, iconScale),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. cursorIdStr,
			ScaleType = Enum.ScaleType.Fit,
		})

		local button = scope:New("TextButton")({
			Name = cursorName,
			Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
			BackgroundColor3 = backgroundColor,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = i,
			ClipsDescendants = true,

			[Fusion.Children] = {
				scope:New("UICorner")({
					CornerRadius = Theme.Radius.Large,
				}),

				scope:New("UIStroke")({
					Color = borderColor,
					Thickness = 1,
					Transparency = 0.1,
				}),

				iconContent,
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

	local totalWidth = (BUTTON_SIZE * cursorCount) + (spacing * (cursorCount - 1))

	return scope:New("Frame")({
		Name = "CursorPicker",
		Size = UDim2.fromOffset(totalWidth, BUTTON_SIZE),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,

		[Fusion.Children] = children,
	})
end

return CursorPicker
