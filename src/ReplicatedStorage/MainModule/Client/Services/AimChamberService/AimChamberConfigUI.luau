local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local AimChamberConfig = require(MainModule.Shared.Config.AimChamberConfig)
local Shadow = require(MainModule.Client.Components.Shadow)

type AimChamberSettings = AimChamberConfig.AimChamberSettings
type FusionScope = Types.FusionScope
type FusionValue<T> = Types.FusionValue<T>
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

local peek = Fusion.peek

local AimChamberConfigUI = {}

local MODAL_WIDTH = 460
local HEADER_HEIGHT = 60
local INPUT_WIDTH = 118
local INPUT_HEIGHT = 30
local ACCENT_COLOR = Color3.fromRGB(255, 180, 60)
local SETTINGS_ICON = "rbxassetid://119015428034090"
local DEFAULT_ZOMBIE_PRESET_ID = "NORMAL"

local STROKE_GRADIENT_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
})

local function formatValue(value: number, format: string?, displayAsPercent: boolean?): string
	if displayAsPercent then
		return string.format("%.0f%%", value * 100)
	end
	if format then
		return string.format(format, value)
	end
	return tostring(value)
end

local function NumberInput(
	scope: FusionScope,
	props: {
		Value: FusionValue<number>,
		Min: number,
		Max: number,
		Format: string?,
		Width: number?,
		Disabled: FusionCanBeState<boolean>?,
		Step: number?,
		DisplayAsPercent: boolean?,
	}
): Frame
	local isFocused = scope:Value(false)
	local currentText = scope:Value(formatValue(peek(props.Value), props.Format, props.DisplayAsPercent))
	local width = props.Width or INPUT_WIDTH
	local isInteger = props.Format == "%d"
	local wasClamped = scope:Value(false)

	local defaultStep = if props.DisplayAsPercent
		then 0.05
		elseif isInteger then 1
		elseif props.Format == "%.2f" then 0.01
		elseif props.Format == "%.1f" then 0.1
		else 1
	local step = props.Step or defaultStep

	local isDisabled = scope:Computed(function(use: FusionUseFn)
		local disabled = props.Disabled
		if typeof(disabled) == "table" then
			return use(disabled :: any)
		end
		return disabled == true
	end)

	scope:Observer(props.Value):onChange(function()
		if not peek(isFocused) then
			currentText:set(formatValue(peek(props.Value), props.Format, props.DisplayAsPercent))
		end
	end)

	local function commit(rawText: string)
		local cleanText = string.gsub(rawText, "%%", "")
		local typed = tonumber(cleanText)
		if typed then
			local rawValue = if props.DisplayAsPercent then typed / 100 else typed
			local clamped = math.clamp(rawValue, props.Min, props.Max)
			if clamped ~= rawValue then
				wasClamped:set(true)
				task.delay(0.4, function()
					wasClamped:set(false)
				end)
			end
			if isInteger then
				props.Value:set(math.round(clamped))
			else
				props.Value:set(clamped)
			end
		end
		currentText:set(formatValue(peek(props.Value), props.Format, props.DisplayAsPercent))
	end

	local function nudge(direction: number)
		if peek(isDisabled) then
			return
		end
		local current = peek(props.Value)
		local nextValue = math.clamp(current + step * direction, props.Min, props.Max)
		if isInteger then
			nextValue = math.round(nextValue)
		end
		props.Value:set(nextValue)
	end

	local borderColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDisabled) then
				return Theme.Border.Subtle
			end
			if use(wasClamped) then
				return Theme.Colors.Warning
			end
			return if use(isFocused) then ACCENT_COLOR else Theme.Input.Border
		end),
		Theme.Spring.Default.Speed
	)

	local bgTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDisabled) then
				return 0.35
			end
			return if use(isFocused) then 0.08 else Theme.Input.BackgroundTransparency
		end),
		Theme.Spring.Default.Speed
	)

	local function StepButton(direction: number, glyph: string)
		local hovered = scope:Value(false)
		return scope:New("TextButton")({
			Size = UDim2.fromOffset(18, INPUT_HEIGHT),
			BackgroundTransparency = 1,
			Text = glyph,
			Font = Theme.Text.Bold,
			TextSize = 13,
			AutoButtonColor = false,
			TextColor3 = scope:Computed(function(use: FusionUseFn)
				if use(isDisabled) then
					return Theme.Foreground.Disabled
				end
				return if use(hovered) then ACCENT_COLOR else Theme.Foreground.Secondary
			end),
			[Fusion.OnEvent("MouseEnter")] = function()
				hovered:set(true)
			end,
			[Fusion.OnEvent("MouseLeave")] = function()
				hovered:set(false)
			end,
			[Fusion.OnEvent("Activated")] = function()
				nudge(direction)
			end,
		})
	end

	return scope:New("Frame")({
		Size = UDim2.fromOffset(width, INPUT_HEIGHT),
		BackgroundColor3 = Theme.Input.Background,
		BackgroundTransparency = bgTransparency,
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
			scope:New("UIStroke")({
				Color = borderColor,
				Thickness = 1,
				Transparency = 0,
			}),
			scope:New("Frame")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					}),
					StepButton(-1, "-"),
					scope:New("TextBox")({
						Size = UDim2.new(1, -36, 1, 0),
						BackgroundTransparency = 1,
						Text = currentText,
						TextColor3 = scope:Computed(function(use: FusionUseFn)
							return if use(isDisabled) then Theme.Foreground.Disabled else Theme.Foreground.Primary
						end),
						TextSize = 12,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						ClearTextOnFocus = false,
						TextEditable = scope:Computed(function(use: FusionUseFn)
							return not use(isDisabled)
						end),
						[Fusion.Out("Text")] = currentText,
						[Fusion.OnEvent("Focused")] = function()
							if not peek(isDisabled) then
								isFocused:set(true)
							end
						end,
						[Fusion.OnEvent("FocusLost")] = function()
							isFocused:set(false)
							if peek(isDisabled) then
								return
							end
							commit(peek(currentText))
						end,
					}),
					StepButton(1, "+"),
				},
			}),
		},
	})
end

local function StringSelector(
	scope: FusionScope,
	props: {
		Value: FusionValue<string>,
		Options: { string },
		Width: number?,
		Disabled: FusionCanBeState<boolean>?,
	}
): Frame
	local width = props.Width or INPUT_WIDTH

	local isDisabled = scope:Computed(function(use: FusionUseFn)
		local disabled = props.Disabled
		if typeof(disabled) == "table" then
			return use(disabled :: any)
		end
		return disabled == true
	end)

	local function cycleNext()
		if peek(isDisabled) then
			return
		end
		local current = peek(props.Value)
		local idx = 1
		for i, opt in props.Options do
			if opt == current then
				idx = i
				break
			end
		end
		local nextIdx = if idx < #props.Options then idx + 1 else 1
		props.Value:set(props.Options[nextIdx])
	end

	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)

	local bgTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDisabled) then
				return 0.35
			end
			return if use(isPressed) then 0.05 elseif use(isHovered) then 0.08 else Theme.Input.BackgroundTransparency
		end),
		Theme.Spring.Default.Speed
	)

	local displayText = scope:Computed(function(use: FusionUseFn)
		return "<  " .. use(props.Value) .. "  >"
	end)

	return scope:New("TextButton")({
		Size = UDim2.fromOffset(width, INPUT_HEIGHT),
		BackgroundColor3 = Theme.Input.Background,
		BackgroundTransparency = bgTransparency,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
			scope:New("UIStroke")({
				Color = scope:Computed(function(use: FusionUseFn)
					return if use(isHovered) and not use(isDisabled) then ACCENT_COLOR else Theme.Input.Border
				end),
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Transparency = scope:Computed(function(use)
					return if use(isDisabled) then 0.5 else 0
				end),
			}),
			scope:New("TextLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = displayText,
				TextColor3 = scope:Computed(function(use: FusionUseFn)
					return if use(isDisabled) then Theme.Foreground.Disabled else Theme.Foreground.Primary
				end),
				TextSize = 10,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		},
		[Fusion.OnEvent("MouseEnter")] = function()
			isHovered:set(true)
		end,
		[Fusion.OnEvent("MouseLeave")] = function()
			isHovered:set(false)
			isPressed:set(false)
		end,
		[Fusion.OnEvent("MouseButton1Down")] = function()
			isPressed:set(true)
		end,
		[Fusion.OnEvent("MouseButton1Up")] = function()
			isPressed:set(false)
		end,
		[Fusion.OnEvent("Activated")] = cycleNext,
	})
end

local function PrimaryButton(
	scope: FusionScope,
	props: {
		Text: string,
		OnClick: (() -> ())?,
		IsPrimary: boolean?,
		IsDestructive: boolean?,
		LayoutOrder: number?,
		Disabled: FusionCanBeState<boolean>?,
		Width: UDim?,
	}
): TextButton
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)

	local isDisabled = scope:Computed(function(use: FusionUseFn)
		local disabled = props.Disabled
		if typeof(disabled) == "table" then
			return use(disabled :: any)
		end
		return disabled == true
	end)

	local buttonTheme = if props.IsDestructive then Theme.Button.Destructive elseif props.IsPrimary then Theme.Button.Primary else Theme.Button.Secondary

	local bgColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDisabled) then
				return Theme.Border.Subtle
			end
			return if use(isHovered) or use(isPressed) then buttonTheme.BackgroundHover else buttonTheme.Background
		end),
		Theme.Spring.Snappy.Speed
	)

	local scale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDisabled) then
				return 1
			end
			return if use(isPressed) then 0.97 else 1
		end),
		Theme.Spring.Snappy.Speed
	)

	return scope:New("TextButton")({
		Size = UDim2.new(props.Width or UDim.new(1, 0), UDim.new(0, 36)),
		BackgroundColor3 = bgColor,
		BorderSizePixel = 0,
		Text = props.Text,
		TextColor3 = scope:Computed(function(use: FusionUseFn)
			return if use(isDisabled) then Theme.Foreground.Disabled else buttonTheme.Foreground
		end),
		TextSize = 12,
		Font = Theme.Text.Black,
		AutoButtonColor = false,
		LayoutOrder = props.LayoutOrder,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
			scope:New("UIScale")({ Scale = scale }),
		},
		[Fusion.OnEvent("MouseEnter")] = function()
			isHovered:set(true)
		end,
		[Fusion.OnEvent("MouseLeave")] = function()
			isHovered:set(false)
			isPressed:set(false)
		end,
		[Fusion.OnEvent("MouseButton1Down")] = function()
			isPressed:set(true)
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

local function ToggleInput(scope: FusionScope, valueState: FusionValue<boolean>, disabledState: FusionCanBeState<boolean>?): Frame
	local isDisabled = scope:Computed(function(use: FusionUseFn)
		local disabled = disabledState
		if typeof(disabled) == "table" then
			return use(disabled :: any)
		end
		return disabled == true
	end)

	local isPressed = scope:Value(false)

	local bgColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDisabled) then
				return Theme.Border.Subtle
			end
			if use(valueState) then
				return ACCENT_COLOR
			end
			return Theme.Input.Background
		end),
		Theme.Spring.Snappy.Speed
	)

	local knobPosition = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(valueState) then UDim2.new(0, 33, 0.5, 0) else UDim2.new(0, 11, 0.5, 0)
		end),
		Theme.Spring.Snappy.Speed
	)

	local toggleScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDisabled) then
				return 1
			end
			return if use(isPressed) then 0.94 else 1
		end),
		Theme.Spring.Snappy.Speed
	)

	return scope:New("TextButton")({
		Size = UDim2.fromOffset(44, 22),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = bgColor,
		Text = "",
		AutoButtonColor = false,
		[Fusion.OnEvent("MouseButton1Down")] = function()
			if not peek(isDisabled) then
				isPressed:set(true)
			end
		end,
		[Fusion.OnEvent("MouseButton1Up")] = function()
			isPressed:set(false)
		end,
		[Fusion.OnEvent("MouseLeave")] = function()
			isPressed:set(false)
		end,
		[Fusion.OnEvent("Activated")] = function()
			if not peek(isDisabled) then
				valueState:set(not peek(valueState))
			end
		end,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			scope:New("UIStroke")({
				Color = Theme.Input.Border,
				Thickness = 1,
				Transparency = Theme.Stroke.Default,
			}),
			scope:New("UIScale")({ Scale = toggleScale }),
			scope:New("Frame")({
				Size = UDim2.fromOffset(14, 14),
				Position = knobPosition,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = scope:Computed(function(use: FusionUseFn)
					return if use(valueState) then Theme.Colors.Black[900] else Theme.Foreground.Primary
				end),
				[Fusion.Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }) },
			}),
		},
	})
end

local function SettingRow(
	scope: FusionScope,
	label: string,
	hint: string?,
	inputGui: GuiObject,
	layoutOrder: number,
	visibleState: any?,
	lockedState: any?
): Frame
	local rowHeight = if hint and hint ~= "" then INPUT_HEIGHT + 28 else INPUT_HEIGHT

	local labelText = if lockedState ~= nil
		then scope:Computed(function(use: FusionUseFn)
			local isLocked = if typeof(lockedState) == "table" then use(lockedState) else lockedState == true
			return if isLocked then label .. "   [LOCKED]" else label
		end)
		else label

	local labelColor = if lockedState ~= nil
		then scope:Computed(function(use: FusionUseFn)
			local isLocked = if typeof(lockedState) == "table" then use(lockedState) else lockedState == true
			return if isLocked then Theme.Colors.Warning else Theme.Foreground.Secondary
		end)
		else Theme.Foreground.Secondary

	local labelChildren: { any } = {
		scope:New("TextLabel")({
			Size = UDim2.new(1, 0, 0, INPUT_HEIGHT),
			BackgroundTransparency = 1,
			Text = labelText,
			TextColor3 = labelColor,
			TextSize = 11,
			Font = Theme.Text.Semibold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 1,
		}),
	}

	if hint and hint ~= "" then
		table.insert(
			labelChildren,
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, -3),
			})
		)
		table.insert(
			labelChildren,
			scope:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
				Text = hint,
				TextColor3 = Theme.Foreground.Disabled,
				TextSize = 10,
				TextWrapped = true,
				Font = Theme.Text.Regular,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				LayoutOrder = 2,
			})
		)
	end

	return scope:New("Frame")({
		Size = UDim2.new(1, 0, 0, rowHeight),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Visible = visibleState,
		[Fusion.Children] = {
			scope:New("Frame")({
				Size = UDim2.new(1, -INPUT_WIDTH - 10, 1, 0),
				BackgroundTransparency = 1,
				[Fusion.Children] = labelChildren,
			}),
			scope:New("Frame")({
				Size = UDim2.fromOffset(INPUT_WIDTH, INPUT_HEIGHT),
				Position = UDim2.fromScale(1, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				[Fusion.Children] = { inputGui },
			}),
		},
	})
end

local function SectionHeader(
	scope: FusionScope,
	label: string,
	description: string?,
	layoutOrder: number,
	visibleState: any?,
	onReset: (() -> ())?,
	resetDisabled: FusionCanBeState<boolean>?
): Frame
	local headerHeight = if description and description ~= "" then 38 else 24
	local resetHovered = scope:Value(false)

	local isResetDisabled = scope:Computed(function(use: FusionUseFn)
		if typeof(resetDisabled) == "table" then
			return use(resetDisabled :: any)
		end
		return resetDisabled == true
	end)

	local titleRowChildren: { any } = {
		scope:New("TextLabel")({
			Size = UDim2.new(1, if onReset then -50 else 0, 1, 0),
			BackgroundTransparency = 1,
			Text = label,
			TextColor3 = ACCENT_COLOR,
			TextSize = 11,
			Font = Theme.Text.Black,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	}

	if onReset then
		table.insert(
			titleRowChildren,
			scope:New("TextButton")({
				Name = "ResetButton",
				Size = UDim2.fromOffset(46, 16),
				Position = UDim2.fromScale(1, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Text = "RESET",
				Font = Theme.Text.Bold,
				TextSize = 9,
				AutoButtonColor = false,
				TextColor3 = scope:Computed(function(use: FusionUseFn)
					if use(isResetDisabled) then
						return Theme.Foreground.Disabled
					end
					return if use(resetHovered) then ACCENT_COLOR else Theme.Foreground.Muted
				end),
				[Fusion.OnEvent("MouseEnter")] = function()
					resetHovered:set(true)
				end,
				[Fusion.OnEvent("MouseLeave")] = function()
					resetHovered:set(false)
				end,
				[Fusion.OnEvent("Activated")] = function()
					if not peek(isResetDisabled) then
						onReset()
					end
				end,
			})
		)
	end

	local children: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
		scope:New("Frame")({
			Name = "TitleRow",
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			[Fusion.Children] = titleRowChildren,
		}),
		scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.Border.Subtle,
			BackgroundTransparency = 0,
			LayoutOrder = 3,
			[Fusion.Children] = {
				scope:New("UIGradient")({
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			},
		}),
	}

	if description and description ~= "" then
		table.insert(
			children,
			scope:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, 14),
				BackgroundTransparency = 1,
				Text = description,
				TextColor3 = Theme.Foreground.Disabled,
				TextSize = 10,
				Font = Theme.Text.Regular,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
			})
		)
	end

	return scope:New("Frame")({
		Size = UDim2.new(1, 0, 0, headerHeight),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Visible = visibleState,
		[Fusion.Children] = children,
	})
end

local function CollapsibleSection(scope: FusionScope, label: string, layoutOrder: number, rows: { any }, isVisible: any?): Frame
	local isOpen = scope:Value(false)
	local isPressed = scope:Value(false)
	local isHovered = scope:Value(false)

	local arrowRotation = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isOpen) then 90 else 0
		end),
		Theme.Spring.Snappy.Speed
	)

	local headerScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isPressed) then 0.99 else 1
		end),
		Theme.Spring.Snappy.Speed
	)

	local contentTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isOpen) then 0 else 1
		end),
		Theme.Spring.Default.Speed
	)

	local contentVisible = scope:Computed(function(use: FusionUseFn)
		return use(isOpen) or use(contentTransparency) < 0.99
	end)

	local hintText = scope:Computed(function(use: FusionUseFn)
		return if use(isOpen) then " click to collapse" else " click to expand"
	end)

	local headerBtn = scope:New("TextButton")({
		Name = "AdvancedToggle",
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Theme.Colors.Black[750],
		BackgroundTransparency = 0.5,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = 1,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
			scope:New("UIStroke")({
				Color = scope:Computed(function(use: FusionUseFn)
					return if use(isHovered) then ACCENT_COLOR else Theme.Border.Subtle
				end),
				Transparency = scope:Computed(function(use: FusionUseFn)
					return if use(isHovered) then 0.5 else 1
				end),
				Thickness = 1,
			}),
			scope:New("UIScale")({ Scale = headerScale }),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
			scope:New("Frame")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 6),
					}),
					scope:New("TextLabel")({
						Size = UDim2.fromOffset(10, 10),
						BackgroundTransparency = 1,
						Text = "▶",
						TextColor3 = ACCENT_COLOR,
						TextSize = 10,
						Font = Theme.Text.Bold,
						Rotation = arrowRotation,
					}),
					scope:New("TextLabel")({
						Size = UDim2.fromScale(0, 1),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = label,
						TextColor3 = ACCENT_COLOR,
						TextSize = 10,
						Font = Theme.Text.Black,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("TextLabel")({
						Size = UDim2.fromScale(0, 1),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = hintText,
						TextColor3 = Theme.Foreground.Disabled,
						TextSize = 10,
						Font = Theme.Text.Regular,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				},
			}),
		},
		[Fusion.OnEvent("MouseEnter")] = function()
			isHovered:set(true)
		end,
		[Fusion.OnEvent("MouseLeave")] = function()
			isHovered:set(false)
			isPressed:set(false)
		end,
		[Fusion.OnEvent("MouseButton1Down")] = function()
			isPressed:set(true)
		end,
		[Fusion.OnEvent("MouseButton1Up")] = function()
			isPressed:set(false)
		end,
		[Fusion.OnEvent("Activated")] = function()
			isOpen:set(not peek(isOpen))
		end,
	})

	local contentRows: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		scope:New("UIPadding")({
			PaddingTop = UDim.new(0, 4),
		}),
	}
	for _, row in rows do
		table.insert(contentRows, row)
	end

	local contentFrame = scope:New("CanvasGroup")({
		Name = "AdvancedContent",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		GroupTransparency = contentTransparency,
		Visible = contentVisible,
		LayoutOrder = 2,
		[Fusion.Children] = contentRows,
	})

	return scope:New("Frame")({
		Name = "CollapsibleSection",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Visible = isVisible,
		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),
			headerBtn,
			contentFrame,
		},
	})
end

local function AiWeaponSelector(scope: FusionScope, selectedWeapon: FusionValue<string>, disabledState: FusionCanBeState<boolean>?, layoutOrder: number?): Frame
	local function createAiWeaponButton(weaponId: string, displayName: string)
		local isSelected = scope:Computed(function(use: FusionUseFn)
			return use(selectedWeapon) == weaponId
		end)

		local isDisabled = scope:Computed(function(use: FusionUseFn)
			local disabled = disabledState
			if typeof(disabled) == "table" then
				return use(disabled :: any)
			end
			return disabled == true
		end)

		local isHovered = scope:Value(false)

		return scope:New("TextButton")({
			Size = UDim2.fromOffset(56, 56),
			BackgroundColor3 = scope:Spring(
				scope:Computed(function(use: FusionUseFn)
					if use(isSelected) then
						return ACCENT_COLOR
					end
					return Theme.Input.Background
				end),
				Theme.Spring.Snappy.Speed
			),
			BackgroundTransparency = scope:Spring(
				scope:Computed(function(use: FusionUseFn)
					return if use(isDisabled) and not use(isSelected) then 0.8 else 0
				end),
				Theme.Spring.Snappy.Speed
			),
			Text = "",
			AutoButtonColor = false,
			[Fusion.OnEvent("MouseEnter")] = function()
				isHovered:set(true)
			end,
			[Fusion.OnEvent("MouseLeave")] = function()
				isHovered:set(false)
			end,
			[Fusion.OnEvent("Activated")] = function()
				if not peek(isDisabled) then
					selectedWeapon:set(weaponId)
				end
			end,
			[Fusion.Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
				scope:New("UIStroke")({
					Color = scope:Computed(function(use: FusionUseFn)
						if use(isSelected) then
							return ACCENT_COLOR
						end
						return if use(isHovered) and not use(isDisabled) then ACCENT_COLOR else Theme.Input.Border
					end),
					Transparency = Theme.Stroke.Default,
					Thickness = 1,
				}),
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 2),
				}),
				scope:New("ImageLabel")({
					Size = UDim2.fromScale(0.55, 0.55),
					BackgroundTransparency = 1,
					Image = AimChamberConfig.GUN_ICONS[weaponId] or "",
					ImageColor3 = scope:Computed(function(use: FusionUseFn)
						if use(isSelected) then
							return Theme.Colors.Black[900]
						end
						if use(isDisabled) then
							return Theme.Foreground.Disabled
						end
						return Theme.Foreground.Primary
					end),
					ScaleType = Enum.ScaleType.Fit,
				}),
				scope:New("TextLabel")({
					Size = UDim2.new(1, 0, 0, 10),
					BackgroundTransparency = 1,
					Text = displayName,
					TextColor3 = scope:Computed(function(use: FusionUseFn)
						if use(isSelected) then
							return Theme.Colors.Black[900]
						end
						if use(isDisabled) then
							return Theme.Foreground.Disabled
						end
						return Theme.Foreground.Primary
					end),
					Font = Theme.Text.Bold,
					TextSize = 10,
				}),
			},
		})
	end

	return scope:New("Frame")({
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
			}),
			createAiWeaponButton("H-82", "VULTAR"),
			createAiWeaponButton("GPR", "RCL"),
		},
	})
end

local function GunSelector(
	scope: FusionScope,
	selectedGun: FusionValue<string>,
	allowedGuns: any,
	disabledState: FusionCanBeState<boolean>?,
	layoutOrder: number?,
	isVisible: any?
): Frame
	local function createGunButton(gunName: string)
		local isAllowed = scope:Computed(function(use: FusionUseFn)
			local allowed = use(allowedGuns)
			for _, g in allowed do
				if g == gunName then
					return true
				end
			end
			return false
		end)

		local isSelected = scope:Computed(function(use: FusionUseFn)
			return use(selectedGun) == gunName
		end)

		local isDisabled = scope:Computed(function(use: FusionUseFn)
			local disabled = disabledState
			if typeof(disabled) == "table" then
				return use(disabled :: any) or not use(isAllowed)
			end
			return disabled == true or not use(isAllowed)
		end)

		local isHovered = scope:Value(false)

		return scope:New("TextButton")({
			Size = UDim2.fromOffset(46, 46),
			BackgroundColor3 = scope:Spring(
				scope:Computed(function(use: FusionUseFn)
					if use(isSelected) then
						return ACCENT_COLOR
					end
					return Theme.Input.Background
				end),
				Theme.Spring.Snappy.Speed
			),
			BackgroundTransparency = scope:Spring(
				scope:Computed(function(use: FusionUseFn)
					return if use(isDisabled) and not use(isSelected) then 0.8 else 0
				end),
				Theme.Spring.Snappy.Speed
			),
			Text = "",
			AutoButtonColor = false,
			[Fusion.OnEvent("MouseEnter")] = function()
				isHovered:set(true)
			end,
			[Fusion.OnEvent("MouseLeave")] = function()
				isHovered:set(false)
			end,
			[Fusion.OnEvent("Activated")] = function()
				if not peek(isDisabled) then
					selectedGun:set(gunName)
				end
			end,
			[Fusion.Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
				scope:New("UIStroke")({
					Color = scope:Computed(function(use: FusionUseFn)
						if use(isSelected) then
							return ACCENT_COLOR
						end
						return if use(isHovered) and not use(isDisabled) then ACCENT_COLOR else Theme.Input.Border
					end),
					Transparency = Theme.Stroke.Default,
					Thickness = 1,
				}),
				scope:New("ImageLabel")({
					Size = UDim2.fromScale(0.75, 0.75),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = AimChamberConfig.GUN_ICONS[gunName] or "",
					ImageColor3 = scope:Computed(function(use: FusionUseFn)
						if use(isSelected) then
							return Theme.Colors.Black[900]
						end
						if use(isDisabled) then
							return Theme.Foreground.Disabled
						end
						return Theme.Foreground.Primary
					end),
					ScaleType = Enum.ScaleType.Fit,
				}),
				scope:New("TextLabel")({
					Size = UDim2.new(1, 0, 0, 12),
					Position = UDim2.fromScale(0.5, 1),
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					Text = gunName,
					TextColor3 = scope:Computed(function(use: FusionUseFn)
						return if use(isSelected) then Theme.Colors.Black[900] else Theme.Foreground.Disabled
					end),
					TextSize = 8,
					Font = Theme.Text.Bold,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
			},
		})
	end

	local children: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Wraps = true,
		}),
	}
	for _, gunName in AimChamberConfig.GUN_NAMES do
		table.insert(children, createGunButton(gunName))
	end

	return scope:New("Frame")({
		Size = UDim2.new(1, 0, 0, 100),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Visible = isVisible,
		[Fusion.Children] = children,
	})
end

local lastSelectedFamily: string? = nil

function AimChamberConfigUI.createWindow(props: {
	Visible: FusionCanBeState<boolean>,
	Settings: FusionCanBeState<AimChamberSettings>,
	PresetId: FusionCanBeState<string>,
	Locked: FusionCanBeState<boolean>,
	FeedbackMessage: FusionCanBeState<string>,
	FeedbackIsError: FusionCanBeState<boolean>,
	OnApply: (settings: AimChamberSettings) -> (),
	OnClose: () -> (),
}): ScreenGui
	local scope = Fusion.scoped(Fusion)

	local selectedFamily = scope:Value(lastSelectedFamily or "ZombieSurvival")
	local tier = scope:Value(if lastSelectedFamily then 2 else 1)
	local backHovered = scope:Value(false)

	scope:Observer(selectedFamily):onChange(function()
		lastSelectedFamily = peek(selectedFamily)
	end)

	local zombiePreset = scope:Value("NORMAL")
	local zombieBasePreset = scope:Value("NORMAL")
	local duelPreset = scope:Value("EASY")
	local duelBasePreset = scope:Value("EASY")

	local sMaxZombies = scope:Value(peek(props.Settings).MaxZombies)
	local sMaxZombiesEnabled = scope:Value(peek(props.Settings).MaxZombiesEnabled)
	local sZombieSpeed = scope:Value(peek(props.Settings).ZombieSpeed)
	local sDamageEnabled = scope:Value(peek(props.Settings).ZombieDamageEnabled)
	local sDamageAmount = scope:Value(peek(props.Settings).ZombieDamageAmount)
	local sSpawnRate = scope:Value(peek(props.Settings).ZombieSpawnRate)
	local sCrouchChance = scope:Value(peek(props.Settings).ZombieCrouchChance)
	local sSelectedGun = scope:Value(peek(props.Settings).SelectedGun)
	local sMinEngage = scope:Value(peek(props.Settings).MinEngageDistance)
	local sMaxEngage = scope:Value(peek(props.Settings).MaxEngageDistance)
	local sApproachAngle = scope:Value(peek(props.Settings).StrafeApproachAngle)
	local sMaxOrbitDuration = scope:Value(peek(props.Settings).MaxOrbitDuration)
	local sCommitSpeedMultiplier = scope:Value(peek(props.Settings).CommitSpeedMultiplier)
	local sJumpPower = scope:Value(peek(props.Settings).ZombieJumpPower)
	local sJumpCooldown = scope:Value(peek(props.Settings).JumpCooldown)
	local sOrbitJumpChance = scope:Value(peek(props.Settings).OrbitJumpChance)
	local sCloseRangeJumpChance = scope:Value(peek(props.Settings).CloseRangeJumpChance)
	local sBunnyHopEnabled = scope:Value(peek(props.Settings).BunnyHopEnabled)
	local sJukeChance = scope:Value(peek(props.Settings).JukeChance)
	local sJukeSpeedMultiplier = scope:Value(peek(props.Settings).JukeSpeedMultiplier)
	local sSpawnRateRampEnabled = scope:Value(peek(props.Settings).SpawnRateRampEnabled)
	local sSpawnRateRampStartRate = scope:Value(peek(props.Settings).SpawnRateRampStartRate)
	local sSpawnRateRampDuration = scope:Value(peek(props.Settings).SpawnRateRampDuration)

	local sAiDifficulty = scope:Value(peek(props.Settings).AiDifficulty or AimChamberConfig.DEFAULT_AI_DIFFICULTY)
	local sAiWeapon = scope:Value(peek(props.Settings).AiWeapon or "H-82")
	local sAiRounds = scope:Value(peek(props.Settings).AiRounds or 3)
	local sAiHealth = scope:Value(peek(props.Settings).AiHealth or 100)
	local sAiNpcAccuracy = scope:Value(peek(props.Settings).AiNpcAccuracy or 1.0)
	local sAiMovementProfile = scope:Value(peek(props.Settings).AiMovementProfile or AimChamberConfig.DEFAULT_MOVEMENT_PROFILE)

	local zombieCustomValues = {
		MaxZombies = peek(sMaxZombies),
		MaxZombiesEnabled = peek(sMaxZombiesEnabled),
		ZombieSpeed = peek(sZombieSpeed),
		ZombieDamageEnabled = peek(sDamageEnabled),
		ZombieDamageAmount = peek(sDamageAmount),
		ZombieSpawnRate = peek(sSpawnRate),
		ZombieCrouchChance = peek(sCrouchChance),
		SelectedGun = peek(sSelectedGun),
		MinEngageDistance = peek(sMinEngage),
		MaxEngageDistance = peek(sMaxEngage),
		StrafeApproachAngle = peek(sApproachAngle),
		MaxOrbitDuration = peek(sMaxOrbitDuration),
		CommitSpeedMultiplier = peek(sCommitSpeedMultiplier),
		ZombieJumpPower = peek(sJumpPower),
		JumpCooldown = peek(sJumpCooldown),
		OrbitJumpChance = peek(sOrbitJumpChance),
		CloseRangeJumpChance = peek(sCloseRangeJumpChance),
		BunnyHopEnabled = peek(sBunnyHopEnabled),
		JukeChance = peek(sJukeChance),
		JukeSpeedMultiplier = peek(sJukeSpeedMultiplier),
		SpawnRateRampEnabled = peek(sSpawnRateRampEnabled),
		SpawnRateRampStartRate = peek(sSpawnRateRampStartRate),
		SpawnRateRampDuration = peek(sSpawnRateRampDuration),
	}

	local duelCustomValues = {
		AiDifficulty = peek(sAiDifficulty),
		AiWeapon = peek(sAiWeapon),
		AiRounds = peek(sAiRounds),
		AiHealth = peek(sAiHealth),
		AiNpcAccuracy = peek(sAiNpcAccuracy),
		AiMovementProfile = peek(sAiMovementProfile),
	}

	local isProgrammaticUpdate = false

	local function saveZombieToCustom()
		zombieCustomValues.MaxZombies = peek(sMaxZombies)
		zombieCustomValues.MaxZombiesEnabled = peek(sMaxZombiesEnabled)
		zombieCustomValues.ZombieSpeed = peek(sZombieSpeed)
		zombieCustomValues.ZombieDamageEnabled = peek(sDamageEnabled)
		zombieCustomValues.ZombieDamageAmount = peek(sDamageAmount)
		zombieCustomValues.ZombieSpawnRate = peek(sSpawnRate)
		zombieCustomValues.ZombieCrouchChance = peek(sCrouchChance)
		zombieCustomValues.SelectedGun = peek(sSelectedGun)
		zombieCustomValues.MinEngageDistance = peek(sMinEngage)
		zombieCustomValues.MaxEngageDistance = peek(sMaxEngage)
		zombieCustomValues.StrafeApproachAngle = peek(sApproachAngle)
		zombieCustomValues.MaxOrbitDuration = peek(sMaxOrbitDuration)
		zombieCustomValues.CommitSpeedMultiplier = peek(sCommitSpeedMultiplier)
		zombieCustomValues.ZombieJumpPower = peek(sJumpPower)
		zombieCustomValues.JumpCooldown = peek(sJumpCooldown)
		zombieCustomValues.OrbitJumpChance = peek(sOrbitJumpChance)
		zombieCustomValues.CloseRangeJumpChance = peek(sCloseRangeJumpChance)
		zombieCustomValues.BunnyHopEnabled = peek(sBunnyHopEnabled)
		zombieCustomValues.JukeChance = peek(sJukeChance)
		zombieCustomValues.JukeSpeedMultiplier = peek(sJukeSpeedMultiplier)
		zombieCustomValues.SpawnRateRampEnabled = peek(sSpawnRateRampEnabled)
		zombieCustomValues.SpawnRateRampStartRate = peek(sSpawnRateRampStartRate)
		zombieCustomValues.SpawnRateRampDuration = peek(sSpawnRateRampDuration)
	end

	local function saveDuelToCustom()
		duelCustomValues.AiDifficulty = peek(sAiDifficulty)
		duelCustomValues.AiWeapon = peek(sAiWeapon)
		duelCustomValues.AiRounds = peek(sAiRounds)
		duelCustomValues.AiHealth = peek(sAiHealth)
		duelCustomValues.AiNpcAccuracy = peek(sAiNpcAccuracy)
		duelCustomValues.AiMovementProfile = peek(sAiMovementProfile)
	end

	local function loadZombieCustom()
		isProgrammaticUpdate = true
		sMaxZombies:set(zombieCustomValues.MaxZombies)
		sMaxZombiesEnabled:set(zombieCustomValues.MaxZombiesEnabled)
		sZombieSpeed:set(zombieCustomValues.ZombieSpeed)
		sDamageEnabled:set(zombieCustomValues.ZombieDamageEnabled)
		sDamageAmount:set(zombieCustomValues.ZombieDamageAmount)
		sSpawnRate:set(zombieCustomValues.ZombieSpawnRate)
		sCrouchChance:set(zombieCustomValues.ZombieCrouchChance)
		sSelectedGun:set(zombieCustomValues.SelectedGun)
		sMinEngage:set(zombieCustomValues.MinEngageDistance)
		sMaxEngage:set(zombieCustomValues.MaxEngageDistance)
		sApproachAngle:set(zombieCustomValues.StrafeApproachAngle)
		sMaxOrbitDuration:set(zombieCustomValues.MaxOrbitDuration)
		sCommitSpeedMultiplier:set(zombieCustomValues.CommitSpeedMultiplier)
		sJumpPower:set(zombieCustomValues.ZombieJumpPower)
		sJumpCooldown:set(zombieCustomValues.JumpCooldown)
		sOrbitJumpChance:set(zombieCustomValues.OrbitJumpChance)
		sCloseRangeJumpChance:set(zombieCustomValues.CloseRangeJumpChance)
		sBunnyHopEnabled:set(zombieCustomValues.BunnyHopEnabled)
		sJukeChance:set(zombieCustomValues.JukeChance)
		sJukeSpeedMultiplier:set(zombieCustomValues.JukeSpeedMultiplier)
		sSpawnRateRampEnabled:set(zombieCustomValues.SpawnRateRampEnabled)
		sSpawnRateRampStartRate:set(zombieCustomValues.SpawnRateRampStartRate)
		sSpawnRateRampDuration:set(zombieCustomValues.SpawnRateRampDuration)
		isProgrammaticUpdate = false
	end

	local function loadDuelCustom()
		isProgrammaticUpdate = true
		sAiDifficulty:set(duelCustomValues.AiDifficulty)
		sAiWeapon:set(duelCustomValues.AiWeapon)
		sAiRounds:set(duelCustomValues.AiRounds)
		sAiHealth:set(duelCustomValues.AiHealth)
		sAiNpcAccuracy:set(duelCustomValues.AiNpcAccuracy)
		sAiMovementProfile:set(duelCustomValues.AiMovementProfile)
		isProgrammaticUpdate = false
	end

	local function applyZombiePreset(presetId: string)
		if presetId == "CUSTOM" then
			loadZombieCustom()
			zombiePreset:set("CUSTOM")
			return
		end
		local preset = AimChamberConfig.getPreset(presetId)
		if preset then
			zombieBasePreset:set(presetId)
			isProgrammaticUpdate = true
			sMaxZombies:set(preset.Settings.MaxZombies)
			sMaxZombiesEnabled:set(preset.Settings.MaxZombiesEnabled)
			sZombieSpeed:set(preset.Settings.ZombieSpeed)
			sDamageEnabled:set(preset.Settings.ZombieDamageEnabled)
			sDamageAmount:set(preset.Settings.ZombieDamageAmount)
			sSpawnRate:set(preset.Settings.ZombieSpawnRate)
			sCrouchChance:set(preset.Settings.ZombieCrouchChance)
			sSelectedGun:set(preset.Settings.SelectedGun)
			sMinEngage:set(preset.Settings.MinEngageDistance)
			sMaxEngage:set(preset.Settings.MaxEngageDistance)
			sApproachAngle:set(preset.Settings.StrafeApproachAngle)
			sMaxOrbitDuration:set(preset.Settings.MaxOrbitDuration)
			sCommitSpeedMultiplier:set(preset.Settings.CommitSpeedMultiplier)
			sJumpPower:set(preset.Settings.ZombieJumpPower)
			sJumpCooldown:set(preset.Settings.JumpCooldown)
			sOrbitJumpChance:set(preset.Settings.OrbitJumpChance)
			sCloseRangeJumpChance:set(preset.Settings.CloseRangeJumpChance)
			sBunnyHopEnabled:set(preset.Settings.BunnyHopEnabled)
			sJukeChance:set(preset.Settings.JukeChance)
			sJukeSpeedMultiplier:set(preset.Settings.JukeSpeedMultiplier)
			sSpawnRateRampEnabled:set(preset.Settings.SpawnRateRampEnabled)
			sSpawnRateRampStartRate:set(preset.Settings.SpawnRateRampStartRate)
			sSpawnRateRampDuration:set(preset.Settings.SpawnRateRampDuration)
			zombiePreset:set(presetId)
			isProgrammaticUpdate = false
		end
	end

	local function applyDuelPreset(presetId: string)
		if presetId == "CUSTOM" then
			loadDuelCustom()
			duelPreset:set("CUSTOM")
		else
			duelBasePreset:set(presetId)
			isProgrammaticUpdate = true
			sAiDifficulty:set(presetId)
			local preset = AimChamberConfig.getPreset("AI")
			sAiWeapon:set(preset.Settings.AiWeapon or "H-82")
			sAiRounds:set(preset.Settings.AiRounds or 3)
			sAiHealth:set(preset.Settings.AiHealth or 100)
			sAiNpcAccuracy:set(1.0)
			sAiMovementProfile:set(preset.Settings.AiMovementProfile or AimChamberConfig.DEFAULT_MOVEMENT_PROFILE)
			isProgrammaticUpdate = false
		end
		duelPreset:set(presetId)
		isProgrammaticUpdate = false
	end

	local zombieFieldSignals = {
		MaxZombies = sMaxZombies,
		MaxZombiesEnabled = sMaxZombiesEnabled,
		ZombieSpeed = sZombieSpeed,
		ZombieDamageEnabled = sDamageEnabled,
		ZombieDamageAmount = sDamageAmount,
		ZombieSpawnRate = sSpawnRate,
		ZombieCrouchChance = sCrouchChance,
		SelectedGun = sSelectedGun,
		MinEngageDistance = sMinEngage,
		MaxEngageDistance = sMaxEngage,
		StrafeApproachAngle = sApproachAngle,
		MaxOrbitDuration = sMaxOrbitDuration,
		CommitSpeedMultiplier = sCommitSpeedMultiplier,
		ZombieJumpPower = sJumpPower,
		JumpCooldown = sJumpCooldown,
		OrbitJumpChance = sOrbitJumpChance,
		CloseRangeJumpChance = sCloseRangeJumpChance,
		BunnyHopEnabled = sBunnyHopEnabled,
		JukeChance = sJukeChance,
		JukeSpeedMultiplier = sJukeSpeedMultiplier,
		SpawnRateRampEnabled = sSpawnRateRampEnabled,
		SpawnRateRampStartRate = sSpawnRateRampStartRate,
		SpawnRateRampDuration = sSpawnRateRampDuration,
	}

	local duelFieldSignals = {
		AiWeapon = sAiWeapon,
		AiRounds = sAiRounds,
		AiHealth = sAiHealth,
		AiNpcAccuracy = sAiNpcAccuracy,
		AiMovementProfile = sAiMovementProfile,
	}

	local function resetZombieFields(fields: { string })
		local preset = AimChamberConfig.getPreset(DEFAULT_ZOMBIE_PRESET_ID)
		if not preset then
			return
		end
		isProgrammaticUpdate = true
		if peek(zombiePreset) ~= "CUSTOM" then
			saveZombieToCustom()
		end
		for _, key in fields do
			local signal = zombieFieldSignals[key]
			local defaultValue = preset.Settings[key]
			if signal and defaultValue ~= nil then
				signal:set(defaultValue)
				zombieCustomValues[key] = defaultValue
			end
		end
		zombiePreset:set("CUSTOM")
		isProgrammaticUpdate = false
	end

	local function resetDuelFields(fields: { string })
		local preset = AimChamberConfig.getPreset("AI")
		if not preset then
			return
		end
		isProgrammaticUpdate = true
		if peek(duelPreset) ~= "CUSTOM" then
			saveDuelToCustom()
		end
		for _, key in fields do
			local signal = duelFieldSignals[key]
			local defaultValue = preset.Settings[key]
			if signal and defaultValue ~= nil then
				signal:set(defaultValue)
				duelCustomValues[key] = defaultValue
			end
		end
		duelPreset:set("CUSTOM")
		isProgrammaticUpdate = false
	end

	local function bindZombieObserver(valueSignal, key)
		scope:Observer(valueSignal):onChange(function()
			if isProgrammaticUpdate then
				return
			end
			if peek(zombiePreset) ~= "CUSTOM" then
				saveZombieToCustom()
				zombiePreset:set("CUSTOM")
			end
			zombieCustomValues[key] = peek(valueSignal)
		end)
	end

	bindZombieObserver(sMaxZombies, "MaxZombies")
	bindZombieObserver(sMaxZombiesEnabled, "MaxZombiesEnabled")
	bindZombieObserver(sZombieSpeed, "ZombieSpeed")
	bindZombieObserver(sDamageEnabled, "ZombieDamageEnabled")
	bindZombieObserver(sDamageAmount, "ZombieDamageAmount")
	bindZombieObserver(sSpawnRate, "ZombieSpawnRate")
	bindZombieObserver(sCrouchChance, "ZombieCrouchChance")
	bindZombieObserver(sSelectedGun, "SelectedGun")
	bindZombieObserver(sMinEngage, "MinEngageDistance")
	bindZombieObserver(sMaxEngage, "MaxEngageDistance")
	bindZombieObserver(sApproachAngle, "StrafeApproachAngle")
	bindZombieObserver(sMaxOrbitDuration, "MaxOrbitDuration")
	bindZombieObserver(sCommitSpeedMultiplier, "CommitSpeedMultiplier")
	bindZombieObserver(sJumpPower, "ZombieJumpPower")
	bindZombieObserver(sJumpCooldown, "JumpCooldown")
	bindZombieObserver(sOrbitJumpChance, "OrbitJumpChance")
	bindZombieObserver(sCloseRangeJumpChance, "CloseRangeJumpChance")
	bindZombieObserver(sBunnyHopEnabled, "BunnyHopEnabled")
	bindZombieObserver(sJukeChance, "JukeChance")
	bindZombieObserver(sJukeSpeedMultiplier, "JukeSpeedMultiplier")
	bindZombieObserver(sSpawnRateRampEnabled, "SpawnRateRampEnabled")
	bindZombieObserver(sSpawnRateRampStartRate, "SpawnRateRampStartRate")
	bindZombieObserver(sSpawnRateRampDuration, "SpawnRateRampDuration")

	local function bindDuelObserver(valueSignal, key)
		scope:Observer(valueSignal):onChange(function()
			if isProgrammaticUpdate then
				return
			end
			if peek(duelPreset) ~= "CUSTOM" then
				saveDuelToCustom()
				duelPreset:set("CUSTOM")
			end
			duelCustomValues[key] = peek(valueSignal)
		end)
	end

	bindDuelObserver(sAiDifficulty, "AiDifficulty")
	bindDuelObserver(sAiWeapon, "AiWeapon")
	bindDuelObserver(sAiRounds, "AiRounds")
	bindDuelObserver(sAiHealth, "AiHealth")
	bindDuelObserver(sAiNpcAccuracy, "AiNpcAccuracy")
	bindDuelObserver(sAiMovementProfile, "AiMovementProfile")

	local currentSettingsVersion = scope:Value(0)

	local function updateLocalStateFromProps()
		local set = peek(props.Settings)
		local actPreset = peek(props.PresetId)

		local family = "ZombieSurvival"
		if actPreset == "AI" or (actPreset == "CUSTOM" and set.IsAiMode == true) then
			family = "DuelMode"
		end

		isProgrammaticUpdate = true
		if family == "ZombieSurvival" then
			zombiePreset:set(actPreset)
			if actPreset ~= "CUSTOM" then
				zombieBasePreset:set(actPreset)
			end
			sMaxZombies:set(set.MaxZombies)
			sMaxZombiesEnabled:set(set.MaxZombiesEnabled)
			sZombieSpeed:set(set.ZombieSpeed)
			sDamageEnabled:set(set.ZombieDamageEnabled)
			sDamageAmount:set(set.ZombieDamageAmount)
			sSpawnRate:set(set.ZombieSpawnRate)
			sCrouchChance:set(set.ZombieCrouchChance)
			sSelectedGun:set(set.SelectedGun)
			sMinEngage:set(set.MinEngageDistance)
			sMaxEngage:set(set.MaxEngageDistance)
			sApproachAngle:set(set.StrafeApproachAngle)
			sMaxOrbitDuration:set(set.MaxOrbitDuration)
			sCommitSpeedMultiplier:set(set.CommitSpeedMultiplier)
			sJumpPower:set(set.ZombieJumpPower)
			sJumpCooldown:set(set.JumpCooldown)
			sOrbitJumpChance:set(set.OrbitJumpChance)
			sCloseRangeJumpChance:set(set.CloseRangeJumpChance)
			sBunnyHopEnabled:set(set.BunnyHopEnabled)
			sJukeChance:set(set.JukeChance)
			sJukeSpeedMultiplier:set(set.JukeSpeedMultiplier)
			sSpawnRateRampEnabled:set(set.SpawnRateRampEnabled)
			sSpawnRateRampStartRate:set(set.SpawnRateRampStartRate)
			sSpawnRateRampDuration:set(set.SpawnRateRampDuration)

			if actPreset == "CUSTOM" then
				saveZombieToCustom()
			end
		else
			if set.IsAiMode then
				local difficulty = set.AiDifficulty or "EASY"
				local isCustom = actPreset == "CUSTOM" or difficulty == "CUSTOM" or not table.find(AimChamberConfig.AI_DIFFICULTY_NAMES, difficulty)
				if isCustom then
					duelPreset:set("CUSTOM")
					if table.find(AimChamberConfig.AI_DIFFICULTY_NAMES, difficulty) then
						duelBasePreset:set(difficulty)
					end
					sAiDifficulty:set(difficulty)
					sAiWeapon:set(set.AiWeapon or "H-82")
					sAiRounds:set(set.AiRounds or 3)
					sAiHealth:set(set.AiHealth or 100)
					sAiMovementProfile:set(set.AiMovementProfile or AimChamberConfig.DEFAULT_MOVEMENT_PROFILE)
					sAiNpcAccuracy:set(set.AiNpcAccuracy or 2.5)
				else
					duelPreset:set(difficulty)
					duelBasePreset:set(difficulty)
					sAiDifficulty:set(difficulty)
					sAiWeapon:set(set.AiWeapon or "H-82")
					sAiRounds:set(set.AiRounds or 3)
					sAiHealth:set(set.AiHealth or 100)
					sAiMovementProfile:set(set.AiMovementProfile or AimChamberConfig.DEFAULT_MOVEMENT_PROFILE)
					sAiNpcAccuracy:set(set.AiNpcAccuracy or 2.5)
				end
			end

			if actPreset == "CUSTOM" then
				saveDuelToCustom()
			end
		end
		task.defer(function()
			isProgrammaticUpdate = false
			currentSettingsVersion:set(peek(currentSettingsVersion) + 1)
		end)
	end

	scope:Observer(props.Settings):onChange(function()
		updateLocalStateFromProps()
	end)

	local localLocked = scope:Computed(function(use: FusionUseFn)
		local family = use(selectedFamily)
		if family == "ZombieSurvival" then
			local p = use(zombiePreset)
			local preset = AimChamberConfig.getPreset(p)
			return preset and preset.Locked == true
		else
			return false
		end
	end)

	local isVisible = scope:Computed(function(use: FusionUseFn)
		local v = props.Visible
		if typeof(v) == "table" then
			return use(v :: any) == true
		end
		return v == true
	end)

	scope:Observer(isVisible):onChange(function()
		if peek(isVisible) then
			local set = peek(props.Settings)
			local actPreset = peek(props.PresetId)

			local family = "ZombieSurvival"
			if actPreset == "AI" or (actPreset == "CUSTOM" and set.IsAiMode == true) then
				family = "DuelMode"
			end

			if lastSelectedFamily then
				selectedFamily:set(lastSelectedFamily)
				tier:set(2)
			else
				selectedFamily:set(family)
				tier:set(1)
			end

			updateLocalStateFromProps()
		end
	end)

	local allowedGuns = scope:Computed(function(use: FusionUseFn)
		use(currentSettingsVersion)
		local presetId = use(zombiePreset)
		local preset = AimChamberConfig.getPreset(presetId)
		if preset then
			return preset.GunRule.AllowedGuns
		end
		return AimChamberConfig.GUN_NAMES
	end)

	local modalScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then 1 else 0.95
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)
	local modalOffsetY = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then 0 else 20
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)
	local modalTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then 0 else 1
		end),
		Theme.Spring.Default.Speed,
		Theme.Spring.Default.Damping
	)
	local overlayTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then Theme.Modal.OverlayTransparency else 1
		end),
		Theme.Spring.Default.Speed,
		Theme.Spring.Default.Damping
	)

	local tierOffset = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(tier) == 1 then 0 else 1
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local header = scope:New("Frame")({
		Name = "Header",
		Size = scope:Computed(function(use)
			local t = use(tierOffset)
			return UDim2.new(1, 0, 0, 40 + (20 * t))
		end),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.XLarge }),
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 10) }),
			scope:New("Frame")({
				Name = "TitleGroup",
				Size = UDim2.new(1, -36, 1, 0),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 10),
					}),
					scope:New("ImageLabel")({
						Name = "Icon",
						Size = UDim2.fromOffset(18, 18),
						BackgroundTransparency = 1,
						Image = SETTINGS_ICON,
						ImageColor3 = ACCENT_COLOR,
					}),
					scope:New("Frame")({
						Name = "TitleTextGroup",
						Size = UDim2.fromScale(0, 1),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 0),
							}),
							scope:New("TextLabel")({
								Name = "Title",
								Size = UDim2.fromScale(0, 0),
								AutomaticSize = Enum.AutomaticSize.XY,
								BackgroundTransparency = 1,
								Text = "AIM CHAMBER CONFIG",
								TextColor3 = Theme.Foreground.Primary,
								TextSize = 13,
								Font = Theme.Text.Black,
								LayoutOrder = 1,
							}),
						},
					}),
				},
			}),

			scope:New("TextButton")({
				Name = "CloseButton",
				Size = UDim2.fromOffset(24, 24),
				Position = UDim2.fromScale(1, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Text = "X",
				Font = Theme.Text.Bold,
				TextSize = Theme.Text.Medium,
				TextColor3 = Theme.Foreground.Muted,
				AutoButtonColor = false,
				[Fusion.OnEvent("Activated")] = function()
					props.OnClose()
				end,
			}),
		},
	})

	local function ZombiePresetButton(presetId: string, displayName: string, layoutOrder: number?)
		local isSelected = scope:Computed(function(use: FusionUseFn)
			return use(zombiePreset) == presetId
		end)
		local isPressed = scope:Value(false)

		return scope:New("TextButton")({
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = layoutOrder,
			BackgroundColor3 = scope:Spring(
				scope:Computed(function(use: FusionUseFn)
					return if use(isSelected) then ACCENT_COLOR else Theme.Colors.Black[750]
				end),
				Theme.Spring.Snappy.Speed
			),
			Text = string.upper(displayName),
			TextColor3 = scope:Computed(function(use: FusionUseFn)
				return if use(isSelected) then Theme.Colors.Black[900] else Theme.Foreground.Secondary
			end),
			Font = Theme.Text.Black,
			TextSize = 11,
			AutoButtonColor = false,
			[Fusion.Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
				scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
				scope:New("UIScale")({
					Scale = scope:Spring(
						scope:Computed(function(use: FusionUseFn)
							return if use(isPressed) then 0.95 else 1
						end),
						Theme.Spring.Snappy.Speed
					),
				}),
			},
			[Fusion.OnEvent("MouseButton1Down")] = function()
				isPressed:set(true)
			end,
			[Fusion.OnEvent("MouseButton1Up")] = function()
				isPressed:set(false)
			end,
			[Fusion.OnEvent("MouseLeave")] = function()
				isPressed:set(false)
			end,
			[Fusion.OnEvent("Activated")] = function()
				applyZombiePreset(presetId)
			end,
		})
	end

	local function DuelPresetButton(presetId: string, displayName: string, layoutOrder: number?)
		local isSelected = scope:Computed(function(use: FusionUseFn)
			return use(duelPreset) == presetId
		end)
		local isPressed = scope:Value(false)

		return scope:New("TextButton")({
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = layoutOrder,
			BackgroundColor3 = scope:Spring(
				scope:Computed(function(use: FusionUseFn)
					return if use(isSelected) then ACCENT_COLOR else Theme.Colors.Black[750]
				end),
				Theme.Spring.Snappy.Speed
			),
			Text = string.upper(displayName),
			TextColor3 = scope:Computed(function(use: FusionUseFn)
				return if use(isSelected) then Theme.Colors.Black[900] else Theme.Foreground.Secondary
			end),
			Font = Theme.Text.Black,
			TextSize = 11,
			AutoButtonColor = false,
			[Fusion.Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
				scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
				scope:New("UIScale")({
					Scale = scope:Spring(
						scope:Computed(function(use: FusionUseFn)
							return if use(isPressed) then 0.95 else 1
						end),
						Theme.Spring.Snappy.Speed
					),
				}),
			},
			[Fusion.OnEvent("MouseButton1Down")] = function()
				isPressed:set(true)
			end,
			[Fusion.OnEvent("MouseButton1Up")] = function()
				isPressed:set(false)
			end,
			[Fusion.OnEvent("MouseLeave")] = function()
				isPressed:set(false)
			end,
			[Fusion.OnEvent("Activated")] = function()
				applyDuelPreset(presetId)
			end,
		})
	end

	local R = AimChamberConfig.CLAMP_RANGES

	local function rangeHint(min: number, max: number, fmt: string?): string
		local f = fmt or "%.0f"
		return string.format("(" .. f .. "-" .. f .. ")", min, max)
	end

	local function percentRangeHint(min: number, max: number): string
		return string.format("(%.0f%%-%.0f%%)", min * 100, max * 100)
	end

	local function multiplierRangeHint(min: number, max: number): string
		return string.format("(%.1fx-%.1fx)", min, max)
	end

	local scrollFrameChildren = scope:Computed(function(useChildren: FusionUseFn)
		local family = useChildren(selectedFamily)
		if family == "ZombieSurvival" then
			local zombieCustomPressed = scope:Value(false)
			return {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 6) }),

				scope:New("Frame")({
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 10,
					[Fusion.Children] = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 8),
							Wraps = true,
						}),
						ZombiePresetButton("NORMAL", "NORMAL", 1),
						ZombiePresetButton("ASSESSMENT", "ASSESSMENT", 2),
						ZombiePresetButton("HARDCORE", "HARDCORE", 3),
						scope:New("TextButton")({
							Size = UDim2.fromOffset(0, 26),
							AutomaticSize = Enum.AutomaticSize.X,
							LayoutOrder = 10,
							BackgroundColor3 = scope:Spring(
								scope:Computed(function(use: FusionUseFn)
									return if use(zombiePreset) == "CUSTOM" then ACCENT_COLOR else Theme.Colors.Black[750]
								end),
								Theme.Spring.Snappy.Speed
							),
							Text = scope:Computed(function(use: FusionUseFn)
								local base = use(zombieBasePreset)
								if base and base ~= "CUSTOM" and use(zombiePreset) == "CUSTOM" then
									return string.upper(base) .. " (CUSTOM)"
								end
								return "CUSTOM"
							end),
							TextColor3 = scope:Computed(function(use: FusionUseFn)
								return if use(zombiePreset) == "CUSTOM" then Theme.Colors.Black[900] else Theme.Foreground.Secondary
							end),
							Font = Theme.Text.Black,
							TextSize = 11,
							AutoButtonColor = false,
							[Fusion.Children] = {
								scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
								scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
								scope:New("UIScale")({
									Scale = scope:Spring(
										scope:Computed(function(use: FusionUseFn)
											return if use(zombieCustomPressed) then 0.95 else 1
										end),
										Theme.Spring.Snappy.Speed
									),
								}),
							},
							[Fusion.OnEvent("MouseButton1Down")] = function()
								zombieCustomPressed:set(true)
							end,
							[Fusion.OnEvent("MouseButton1Up")] = function()
								zombieCustomPressed:set(false)
							end,
							[Fusion.OnEvent("MouseLeave")] = function()
								zombieCustomPressed:set(false)
							end,
							[Fusion.OnEvent("Activated")] = function()
								applyZombiePreset("CUSTOM")
							end,
						}),
					},
				}),

				scope:New("Frame")({
					Name = "LockWarning",
					Size = UDim2.new(0.99, 0, 0, 30),
					BackgroundColor3 = Theme.Colors.Warning,
					BackgroundTransparency = 0.88,
					LayoutOrder = 20,
					Visible = scope:Computed(function(use: FusionUseFn)
						return use(localLocked)
					end),
					[Fusion.Children] = {
						scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
						scope:New("UIStroke")({ Color = Theme.Colors.Warning, Transparency = 0.5, Thickness = 1 }),
						scope:New("TextLabel")({
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = "SETTINGS ARE LOCKED IN ASSESSMENT MODE",
							TextColor3 = Theme.Colors.Warning,
							Font = Theme.Text.Black,
							TextSize = 11,
							TextXAlignment = Enum.TextXAlignment.Center,
						}),
					},
				}),

				SectionHeader(scope, "WEAPON", nil, 30, true, function()
					resetZombieFields({ "SelectedGun" })
				end, localLocked),
				GunSelector(scope, sSelectedGun, allowedGuns, localLocked, 40, true),

				SectionHeader(scope, "GENERAL", "Core settings that affect difficulty and pacing.", 50, true, function()
					resetZombieFields({
						"MaxZombiesEnabled",
						"MaxZombies",
						"ZombieSpeed",
						"ZombieSpawnRate",
						"SpawnRateRampEnabled",
						"SpawnRateRampStartRate",
						"SpawnRateRampDuration",
					})
				end, localLocked),

				SettingRow(
					scope,
					"CAP ZOMBIES ON MAP",
					"Limit how many zombies can exist at the same time",
					ToggleInput(scope, sMaxZombiesEnabled, localLocked),
					60,
					true,
					localLocked
				),

				SettingRow(
					scope,
					"ZOMBIE LIMIT",
					"Maximum zombies alive at once " .. rangeHint(R.MaxZombies.Min, R.MaxZombies.Max, "%.0f"),
					NumberInput(scope, { Value = sMaxZombies, Min = R.MaxZombies.Min, Max = R.MaxZombies.Max, Format = "%d", Disabled = localLocked }),
					70,
					sMaxZombiesEnabled,
					localLocked
				),

				SettingRow(
					scope,
					"ZOMBIE SPEED",
					"Zombie walk speed in studs per second " .. rangeHint(R.ZombieSpeed.Min, R.ZombieSpeed.Max, "%.0f"),
					NumberInput(scope, { Value = sZombieSpeed, Min = R.ZombieSpeed.Min, Max = R.ZombieSpeed.Max, Format = "%d", Disabled = localLocked }),
					80,
					true,
					localLocked
				),

				SettingRow(
					scope,
					"ZOMBIE SPAWN RATE",
					"Seconds between zombie spawns " .. rangeHint(R.ZombieSpawnRate.Min, R.ZombieSpawnRate.Max, "%.1f"),
					NumberInput(
						scope,
						{ Value = sSpawnRate, Min = R.ZombieSpawnRate.Min, Max = R.ZombieSpawnRate.Max, Format = "%.2f", Disabled = localLocked }
					),
					90,
					true,
					localLocked
				),

				SettingRow(
					scope,
					"RAMP UP SPAWN RATE",
					"Zombies spawn faster over time",
					ToggleInput(scope, sSpawnRateRampEnabled, localLocked),
					100,
					true,
					localLocked
				),

				SettingRow(
					scope,
					"START SPAWN RATE",
					"Initial seconds between spawns " .. rangeHint(R.SpawnRateRampStartRate.Min, R.SpawnRateRampStartRate.Max, "%.1f"),
					NumberInput(scope, {
						Value = sSpawnRateRampStartRate,
						Min = R.SpawnRateRampStartRate.Min,
						Max = R.SpawnRateRampStartRate.Max,
						Format = "%.2f",
						Disabled = localLocked,
					}),
					101,
					sSpawnRateRampEnabled,
					localLocked
				),

				SettingRow(
					scope,
					"RAMP UP DURATION",
					"Seconds to reach maximum spawn rate " .. rangeHint(R.SpawnRateRampDuration.Min, R.SpawnRateRampDuration.Max, "%.0f"),
					NumberInput(scope, {
						Value = sSpawnRateRampDuration,
						Min = R.SpawnRateRampDuration.Min,
						Max = R.SpawnRateRampDuration.Max,
						Format = "%d",
						Disabled = localLocked,
					}),
					102,
					sSpawnRateRampEnabled,
					localLocked
				),

				SectionHeader(scope, "DAMAGE", "How much damage zombies deal on touch.", 120, true, function()
					resetZombieFields({ "ZombieDamageEnabled", "ZombieDamageAmount" })
				end, localLocked),

				SettingRow(
					scope,
					"DEAL DAMAGE ON TOUCH",
					"Zombies hurt you on contact",
					ToggleInput(scope, sDamageEnabled, localLocked),
					130,
					true,
					localLocked
				),

				SettingRow(
					scope,
					"DAMAGE AMOUNT",
					"HP lost per zombie touch " .. rangeHint(R.ZombieDamageAmount.Min, R.ZombieDamageAmount.Max, "%.0f"),
					NumberInput(
						scope,
						{ Value = sDamageAmount, Min = R.ZombieDamageAmount.Min, Max = R.ZombieDamageAmount.Max, Format = "%d", Disabled = localLocked }
					),
					131,
					sDamageEnabled,
					localLocked
				),

				SectionHeader(scope, "JUMP", "Controls how often and how high zombies jump.", 150, true, function()
					resetZombieFields({
						"ZombieJumpPower",
						"JumpCooldown",
						"OrbitJumpChance",
						"CloseRangeJumpChance",
						"BunnyHopEnabled",
					})
				end, localLocked),

				SettingRow(
					scope,
					"JUMP POWER",
					"Upward jump force in studs " .. rangeHint(R.ZombieJumpPower.Min, R.ZombieJumpPower.Max, "%.0f"),
					NumberInput(scope, { Value = sJumpPower, Min = R.ZombieJumpPower.Min, Max = R.ZombieJumpPower.Max, Format = "%d", Disabled = localLocked }),
					160,
					true,
					localLocked
				),

				SettingRow(
					scope,
					"JUMP COOLDOWN",
					"Seconds required between zombie jumps " .. rangeHint(R.JumpCooldown.Min, R.JumpCooldown.Max, "%.1f"),
					NumberInput(scope, { Value = sJumpCooldown, Min = R.JumpCooldown.Min, Max = R.JumpCooldown.Max, Format = "%.2f", Disabled = localLocked }),
					170,
					true,
					localLocked
				),

				SettingRow(
					scope,
					"ORBIT JUMP CHANCE",
					"Chance of jumping while orbiting " .. percentRangeHint(R.OrbitJumpChance.Min, R.OrbitJumpChance.Max),
					NumberInput(scope, {
						Value = sOrbitJumpChance,
						Min = R.OrbitJumpChance.Min,
						Max = R.OrbitJumpChance.Max,
						Format = "%.2f",
						Disabled = localLocked,
						DisplayAsPercent = true,
					}),
					180,
					true,
					localLocked
				),

				SettingRow(
					scope,
					"CLOSE RANGE JUMP CHANCE",
					"Chance of jumping when up close " .. percentRangeHint(R.CloseRangeJumpChance.Min, R.CloseRangeJumpChance.Max),
					NumberInput(scope, {
						Value = sCloseRangeJumpChance,
						Min = R.CloseRangeJumpChance.Min,
						Max = R.CloseRangeJumpChance.Max,
						Format = "%.2f",
						Disabled = localLocked,
						DisplayAsPercent = true,
					}),
					190,
					true,
					localLocked
				),

				SettingRow(
					scope,
					"BUNNY HOP ENABLED",
					"Zombies chain jumps together dynamically",
					ToggleInput(scope, sBunnyHopEnabled, localLocked),
					200,
					true,
					localLocked
				),

				CollapsibleSection(scope, "ENGAGEMENT RANGE", 210, {
					SectionHeader(scope, "ENGAGEMENT RANGE", "Distance at which zombies switch between approaching and strafing.", 10, true, function()
						resetZombieFields({
							"MinEngageDistance",
							"MaxEngageDistance",
							"MaxOrbitDuration",
							"StrafeApproachAngle",
							"CommitSpeedMultiplier",
						})
					end, localLocked),

					SettingRow(
						scope,
						"MIN ENGAGE DISTANCE",
						"Closest distance before a zombie starts strafing " .. rangeHint(R.MinEngageDistance.Min, R.MinEngageDistance.Max, "%.0f"),
						NumberInput(
							scope,
							{ Value = sMinEngage, Min = R.MinEngageDistance.Min, Max = R.MinEngageDistance.Max, Format = "%d", Disabled = localLocked }
						),
						20,
						true,
						localLocked
					),

					SettingRow(
						scope,
						"MAX ENGAGE DISTANCE",
						"Furthest distance before a zombie gives chase " .. rangeHint(R.MaxEngageDistance.Min, R.MaxEngageDistance.Max, "%.0f"),
						NumberInput(
							scope,
							{ Value = sMaxEngage, Min = R.MaxEngageDistance.Min, Max = R.MaxEngageDistance.Max, Format = "%d", Disabled = localLocked }
						),
						30,
						true,
						localLocked
					),

					SettingRow(
						scope,
						"MAX ORBIT DURATION",
						"Seconds a zombie can orbit before charging in " .. rangeHint(R.MaxOrbitDuration.Min, R.MaxOrbitDuration.Max, "%.1f"),
						NumberInput(
							scope,
							{ Value = sMaxOrbitDuration, Min = R.MaxOrbitDuration.Min, Max = R.MaxOrbitDuration.Max, Format = "%.1f", Disabled = localLocked }
						),
						40,
						true,
						localLocked
					),

					SettingRow(
						scope,
						"APPROACH ANGLE",
						"How wide a zombie angles its approach, in degrees " .. rangeHint(R.StrafeApproachAngle.Min, R.StrafeApproachAngle.Max, "%.0f"),
						NumberInput(scope, {
							Value = sApproachAngle,
							Min = R.StrafeApproachAngle.Min,
							Max = R.StrafeApproachAngle.Max,
							Format = "%.0f",
							Disabled = localLocked,
						}),
						50,
						true,
						localLocked
					),

					SettingRow(
						scope,
						"COMMIT SPEED MULTIPLIER",
						"Speed boost while rushing the player " .. multiplierRangeHint(R.CommitSpeedMultiplier.Min, R.CommitSpeedMultiplier.Max),
						NumberInput(scope, {
							Value = sCommitSpeedMultiplier,
							Min = R.CommitSpeedMultiplier.Min,
							Max = R.CommitSpeedMultiplier.Max,
							Format = "%.2f",
							Disabled = localLocked,
						}),
						60,
						true,
						localLocked
					),
				}, true),

				CollapsibleSection(scope, "JUKE & ORBIT", 220, {
					SectionHeader(scope, "JUKE & ORBIT", "Controls dodge and feint behavior.", 10, true, function()
						resetZombieFields({ "JukeChance", "JukeSpeedMultiplier" })
					end, localLocked),

					SettingRow(
						scope,
						"JUKE CHANCE",
						"Chance of a sidestep dodge per decision " .. percentRangeHint(R.JukeChance.Min, R.JukeChance.Max),
						NumberInput(scope, {
							Value = sJukeChance,
							Min = R.JukeChance.Min,
							Max = R.JukeChance.Max,
							Format = "%.2f",
							Disabled = localLocked,
							DisplayAsPercent = true,
						}),
						20,
						true,
						localLocked
					),

					SettingRow(
						scope,
						"JUKE SPEED MULTIPLIER",
						"Speed during a juke " .. multiplierRangeHint(R.JukeSpeedMultiplier.Min, R.JukeSpeedMultiplier.Max),
						NumberInput(scope, {
							Value = sJukeSpeedMultiplier,
							Min = R.JukeSpeedMultiplier.Min,
							Max = R.JukeSpeedMultiplier.Max,
							Format = "%.2f",
							Disabled = localLocked,
						}),
						30,
						true,
						localLocked
					),
				}, true),
			}
		else
			local duelCustomPressed = scope:Value(false)
			return {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 6) }),

				scope:New("Frame")({
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 10,
					[Fusion.Children] = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 8),
							Wraps = true,
						}),
						DuelPresetButton("EASY", "EASY", 1),
						DuelPresetButton("HARD", "HARD", 2),
						scope:New("TextButton")({
							Size = UDim2.fromOffset(0, 26),
							AutomaticSize = Enum.AutomaticSize.X,
							LayoutOrder = 10,
							BackgroundColor3 = scope:Spring(
								scope:Computed(function(use: FusionUseFn)
									return if use(duelPreset) == "CUSTOM" then ACCENT_COLOR else Theme.Colors.Black[750]
								end),
								Theme.Spring.Snappy.Speed
							),
							Text = scope:Computed(function(use: FusionUseFn)
								local base = use(duelBasePreset)
								if base and base ~= "CUSTOM" and use(duelPreset) == "CUSTOM" then
									return string.upper(base) .. " (CUSTOM)"
								end
								return "CUSTOM"
							end),
							TextColor3 = scope:Computed(function(use: FusionUseFn)
								return if use(duelPreset) == "CUSTOM" then Theme.Colors.Black[900] else Theme.Foreground.Secondary
							end),
							Font = Theme.Text.Black,
							TextSize = 11,
							AutoButtonColor = false,
							[Fusion.Children] = {
								scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
								scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
								scope:New("UIScale")({
									Scale = scope:Spring(
										scope:Computed(function(use: FusionUseFn)
											return if use(duelCustomPressed) then 0.95 else 1
										end),
										Theme.Spring.Snappy.Speed
									),
								}),
							},
							[Fusion.OnEvent("MouseButton1Down")] = function()
								duelCustomPressed:set(true)
							end,
							[Fusion.OnEvent("MouseButton1Up")] = function()
								duelCustomPressed:set(false)
							end,
							[Fusion.OnEvent("MouseLeave")] = function()
								duelCustomPressed:set(false)
							end,
							[Fusion.OnEvent("Activated")] = function()
								applyDuelPreset("CUSTOM")
							end,
						}),
					},
				}),

				SectionHeader(scope, "WEAPON", nil, 20, true, function()
					resetDuelFields({ "AiWeapon" })
				end),
				AiWeaponSelector(scope, sAiWeapon, localLocked, 30),

				SectionHeader(scope, "MATCH SETTINGS", "Rounds, health, and how the bot moves.", 40, true, function()
					resetDuelFields({ "AiMovementProfile", "AiRounds", "AiHealth" })
				end),

				scope:New("Frame")({
					Name = "DuelSettingsGroup",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 50,
					[Fusion.Children] = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 8),
						}),
						SettingRow(
							scope,
							"MOVEMENT PROFILE",
							"How the bot moves during the fight",
							StringSelector(scope, { Value = sAiMovementProfile, Options = AimChamberConfig.MOVEMENT_PROFILES, Disabled = false }),
							10
						),
						SettingRow(
							scope,
							"ROUNDS",
							"Number of rounds to play " .. rangeHint(R.AiRounds.Min, R.AiRounds.Max, "%.0f"),
							NumberInput(scope, { Value = sAiRounds, Min = R.AiRounds.Min, Max = R.AiRounds.Max, Format = "%d", Disabled = false }),
							20
						),
						SettingRow(
							scope,
							"BOT HEALTH",
							"HP for both player and bot " .. rangeHint(R.AiHealth.Min, R.AiHealth.Max, "%.0f"),
							NumberInput(scope, { Value = sAiHealth, Min = R.AiHealth.Min, Max = R.AiHealth.Max, Format = "%d", Disabled = false }),
							30
						),
						SettingRow(
							scope,
							"BOT SPREAD MULTIPLIER",
							"Scales bot bullet spread. 1.0 = default, 0.1 = very accurate, 3.0 = very inaccurate",
							NumberInput(scope, {
								Value = sAiNpcAccuracy,
								Min = R.AiNpcAccuracy.Min,
								Max = R.AiNpcAccuracy.Max,
								Format = "%.1f",
								Step = 0.1,
								Disabled = false,
							}),
							40
						),
					},
				}),
			}
		end
	end)

	local scrollFrame = scope:New("ScrollingFrame")({
		Size = UDim2.new(1, 0, 1, -88),
		Position = UDim2.fromOffset(0, 32),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Colors.Black[500],
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		[Fusion.Children] = scrollFrameChildren,
	})

	local pickerVisible = scope:Computed(function(use: FusionUseFn)
		return use(tierOffset) < 0.99
	end)

	local configVisiblePage = scope:Computed(function(use: FusionUseFn)
		return use(tierOffset) > 0.01
	end)

	local leftHovered = scope:Value(false)
	local leftScale = scope:Spring(
		scope:Computed(function(use)
			return if use(leftHovered) then 1.02 else 1
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)
	local leftBorderColor = scope:Spring(
		scope:Computed(function(use)
			return if use(leftHovered) then ACCENT_COLOR else Theme.Colors.Black[750]
		end),
		Theme.Spring.Snappy.Speed
	)

	local zombieCard = scope:New("TextButton")({
		Name = "ZombieSurvivalCard",
		Size = UDim2.fromOffset(200, 300),
		BackgroundColor3 = Theme.Colors.Black[800],
		AutoButtonColor = false,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.XLarge }),
			scope:New("UIStroke")({ Color = leftBorderColor, Thickness = 1.5 }),
			scope:New("UIScale")({ Scale = leftScale }),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
				PaddingTop = UDim.new(0, 20),
				PaddingBottom = UDim.new(0, 20),
			}),
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 12),
			}),
			scope:New("ImageLabel")({
				Size = UDim2.fromOffset(140, 72),
				BackgroundTransparency = 0,
				BackgroundColor3 = Theme.Colors.Black[900],
				Image = "rbxassetid://135214895981182",
				ScaleType = Enum.ScaleType.Crop,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
					scope:New("UIStroke")({ Color = Theme.Colors.Black[750], Thickness = 1 }),
				},
			}),
			scope:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = "ZOMBIE AIM TRAINER",
				TextColor3 = Theme.Foreground.Primary,
				Font = Theme.Text.Black,
				TextSize = 16,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			scope:New("TextLabel")({
				Size = UDim2.new(1, 0, 1, -100),
				BackgroundTransparency = 1,
				Text = "Train your tracking, target switching, and flicking against waves of simulated attacking zombies.",
				TextColor3 = Theme.Foreground.Secondary,
				Font = Theme.Text.Regular,
				TextSize = 12,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
		},
		[Fusion.OnEvent("MouseEnter")] = function()
			leftHovered:set(true)
		end,
		[Fusion.OnEvent("MouseLeave")] = function()
			leftHovered:set(false)
		end,
		[Fusion.OnEvent("Activated")] = function()
			selectedFamily:set("ZombieSurvival")
			tier:set(2)
		end,
	})

	local rightHovered = scope:Value(false)
	local rightScale = scope:Spring(
		scope:Computed(function(use)
			return if use(rightHovered) then 1.02 else 1
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)
	local rightBorderColor = scope:Spring(
		scope:Computed(function(use)
			return if use(rightHovered) then ACCENT_COLOR else Theme.Colors.Black[750]
		end),
		Theme.Spring.Snappy.Speed
	)

	local duelCard = scope:New("TextButton")({
		Name = "DuelModeCard",
		Size = UDim2.fromOffset(200, 300),
		BackgroundColor3 = Theme.Colors.Black[800],
		AutoButtonColor = false,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.XLarge }),
			scope:New("UIStroke")({ Color = rightBorderColor, Thickness = 1.5 }),
			scope:New("UIScale")({ Scale = rightScale }),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
				PaddingTop = UDim.new(0, 20),
				PaddingBottom = UDim.new(0, 20),
			}),
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 12),
			}),
			scope:New("ImageLabel")({
				Size = UDim2.fromOffset(140, 72),
				BackgroundTransparency = 0,
				BackgroundColor3 = Theme.Colors.Black[900],
				Image = "rbxassetid://84307988548653",
				ScaleType = Enum.ScaleType.Crop,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
					scope:New("UIStroke")({ Color = Theme.Colors.Black[750], Thickness = 1 }),
				},
			}),
			scope:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = "BOT AIM TRAINER",
				TextColor3 = Theme.Foreground.Primary,
				Font = Theme.Text.Black,
				TextSize = 16,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			scope:New("TextLabel")({
				Size = UDim2.new(1, 0, 1, -100),
				BackgroundTransparency = 1,
				Text = "Spar against a highly reactive and mobile bot that jumps, crouches, and shoots back at you.",
				TextColor3 = Theme.Foreground.Secondary,
				Font = Theme.Text.Regular,
				TextSize = 12,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
		},
		[Fusion.OnEvent("MouseEnter")] = function()
			rightHovered:set(true)
		end,
		[Fusion.OnEvent("MouseLeave")] = function()
			rightHovered:set(false)
		end,
		[Fusion.OnEvent("Activated")] = function()
			selectedFamily:set("DuelMode")
			tier:set(2)
		end,
	})

	local pickerPage = scope:New("Frame")({
		Name = "PickerPage",
		Size = UDim2.fromScale(1, 1),
		Position = scope:Computed(function(use)
			local offset = use(tierOffset)
			return UDim2.new(-offset, -offset * 40, 0, 0)
		end),
		BackgroundTransparency = 1,
		Visible = pickerVisible,
		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 20),
			}),
			zombieCard,
			duelCard,
		},
	})

	local applyButtonText = scope:Computed(function(use: FusionUseFn)
		local fam = use(selectedFamily)
		if fam == "ZombieSurvival" then
			return "APPLY ZOMBIE AIM TRAINER SETTINGS"
		else
			return "APPLY BOT AIM TRAINER SETTINGS"
		end
	end)

	local feedbackVisible = scope:Value(false)

	scope:Observer(props.FeedbackMessage):onChange(function()
		local msg = peek(props.FeedbackMessage)
		if msg and msg ~= "" then
			feedbackVisible:set(true)
			task.delay(3, function()
				feedbackVisible:set(false)
			end)
		else
			feedbackVisible:set(false)
		end
	end)

	local feedbackTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(feedbackVisible) then 0 else 1
		end),
		Theme.Spring.Default.Speed
	)

	local feedbackColor = scope:Computed(function(use: FusionUseFn)
		return if use(props.FeedbackIsError) then Theme.Colors.Warning else ACCENT_COLOR
	end)

	local feedbackBanner = scope:New("Frame")({
		Name = "FeedbackBanner",
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = feedbackColor,
		BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
			return 0.88 + (0.12 * use(feedbackTransparency))
		end),
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
			scope:New("UIStroke")({
				Color = feedbackColor,
				Thickness = 1,
				Transparency = scope:Computed(function(use: FusionUseFn)
					return 0.5 + (0.5 * use(feedbackTransparency))
				end),
			}),
			scope:New("TextLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use: FusionUseFn)
					return string.upper(tostring(use(props.FeedbackMessage) or ""))
				end),
				Font = Theme.Text.Bold,
				TextSize = 11,
				TextColor3 = feedbackColor,
				TextTransparency = feedbackTransparency,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		},
	})

	local configPage = scope:New("Frame")({
		Name = "ConfigPage",
		Size = UDim2.fromScale(1, 1),
		Position = scope:Computed(function(use)
			local offset = use(tierOffset)
			return UDim2.new(1 - offset, (1 - offset) * 40, 0, 0)
		end),
		BackgroundTransparency = 1,
		Visible = configVisiblePage,
		[Fusion.Children] = {
			scope:New("TextButton")({
				Name = "BackButton",
				Size = UDim2.fromOffset(110, 28),
				Position = UDim2.fromScale(0, 0),
				BackgroundColor3 = Color3.fromRGB(20, 20, 20),
				BackgroundTransparency = 0.15,
				Text = "",
				AutoButtonColor = false,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
					scope:New("UIStroke")({
						Color = scope:Spring(
							scope:Computed(function(use)
								return if use(backHovered) then ACCENT_COLOR else Color3.fromRGB(75, 73, 75)
							end),
							Theme.Spring.Snappy.Speed
						),
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = 1,
					}),
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 3),
					}),
					scope:New("ImageLabel")({
						Name = "ArrowIcon",
						Size = UDim2.fromOffset(18, 18),
						BackgroundTransparency = 1,
						Image = "rbxassetid://123792095850614",
						ImageColor3 = Color3.fromRGB(220, 220, 220),
					}),
					scope:New("TextLabel")({
						Name = "ButtonText",
						Size = UDim2.fromScale(0, 1),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = "CHANGE MODE",
						TextColor3 = Color3.fromRGB(245, 245, 245),
						Font = Theme.Text.Black,
						TextSize = 11,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				},
				[Fusion.OnEvent("MouseEnter")] = function()
					backHovered:set(true)
				end,
				[Fusion.OnEvent("MouseLeave")] = function()
					backHovered:set(false)
				end,
				[Fusion.OnEvent("Activated")] = function()
					tier:set(1)
				end,
			}),
			scrollFrame,
			scope:New("Frame")({
				Size = UDim2.new(1, 0, 0, 70),
				Position = UDim2.fromScale(0, 1),
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						VerticalAlignment = Enum.VerticalAlignment.Bottom,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 6),
					}),
					PrimaryButton(scope, {
						Text = applyButtonText,
						LayoutOrder = 1,
						Disabled = false,
						IsPrimary = true,
						OnClick = function()
							local fam = peek(selectedFamily)
							if fam == "ZombieSurvival" then
								local activePresetId = peek(zombiePreset)
								if activePresetId ~= "CUSTOM" then
									props.OnApply({ PresetId = activePresetId })
								else
									local newSet: AimChamberSettings = {
										IsAiMode = false,
										MaxZombies = peek(sMaxZombies),
										MaxZombiesEnabled = peek(sMaxZombiesEnabled),
										ZombieSpeed = peek(sZombieSpeed),
										ZombieDamageEnabled = peek(sDamageEnabled),
										ZombieDamageAmount = peek(sDamageAmount),
										ZombieSpawnRate = peek(sSpawnRate),
										ZombieDodgeInterval = peek(props.Settings).ZombieDodgeInterval,
										ZombieCrouchChance = peek(sCrouchChance),
										AssessmentValidation = peek(props.Settings).AssessmentValidation,
										SelectedGun = peek(sSelectedGun),
										MinEngageDistance = peek(sMinEngage),
										MaxEngageDistance = peek(sMaxEngage),
										StrafeApproachAngle = peek(sApproachAngle),
										MaxOrbitDuration = peek(sMaxOrbitDuration),
										CommitSpeedMultiplier = peek(sCommitSpeedMultiplier),
										ApproachSpeedMultiplier = peek(props.Settings).ApproachSpeedMultiplier,
										StrafeSpeedMultiplier = peek(props.Settings).StrafeSpeedMultiplier,
										StrafeHoldMin = peek(props.Settings).StrafeHoldMin,
										StrafeHoldMax = peek(props.Settings).StrafeHoldMax,
										StrafeFlipIntervalMin = peek(props.Settings).StrafeFlipIntervalMin,
										StrafeFlipIntervalMax = peek(props.Settings).StrafeFlipIntervalMax,
										MovementJitter = peek(props.Settings).MovementJitter,
										OrbitDirectionBias = peek(props.Settings).OrbitDirectionBias,
										SeparationMaxForce = peek(props.Settings).SeparationMaxForce,
										ApproachJukeChance = peek(props.Settings).ApproachJukeChance,
										ApproachJumpChance = peek(props.Settings).ApproachJumpChance,
										ApproachCrouchChance = peek(props.Settings).ApproachCrouchChance,
										DecisionTimeStaggerMax = peek(props.Settings).DecisionTimeStaggerMax,
										ZombieJumpPower = peek(sJumpPower),
										JumpCooldown = peek(sJumpCooldown),
										OrbitJumpChance = peek(sOrbitJumpChance),
										CloseRangeJumpChance = peek(sCloseRangeJumpChance),
										BunnyHopEnabled = peek(sBunnyHopEnabled),
										BunnyHopChainChance = peek(props.Settings).BunnyHopChainChance,
										BunnyHopSpeedMultiplier = peek(props.Settings).BunnyHopSpeedMultiplier,
										BunnyHopMaxChain = peek(props.Settings).BunnyHopMaxChain,
										JukeChance = peek(sJukeChance),
										JukeSpeedMultiplier = peek(sJukeSpeedMultiplier),
										JukeJumpChance = peek(props.Settings).JukeJumpChance,
										SpawnRateRampEnabled = peek(sSpawnRateRampEnabled),
										SpawnRateRampStartRate = peek(sSpawnRateRampStartRate),
										SpawnRateRampDuration = peek(sSpawnRateRampDuration),
										AiDifficulty = nil,
									}
									props.OnApply(newSet)
								end
							else
								local activePresetId = peek(duelPreset)
								if activePresetId == "EASY" or activePresetId == "HARD" then
									props.OnApply({
										PresetId = "AI",
										AiDifficulty = activePresetId,
										AiWeapon = peek(sAiWeapon),
										AiNpcAccuracy = peek(sAiNpcAccuracy),
										AiRounds = peek(sAiRounds),
										AiHealth = peek(sAiHealth),
										AiMovementProfile = peek(sAiMovementProfile),
									})
								else
									local newSet: AimChamberSettings = {
										IsAiMode = true,
										AiDifficulty = peek(sAiDifficulty),
										AiWeapon = peek(sAiWeapon),
										AiRounds = peek(sAiRounds),
										AiHealth = peek(sAiHealth),
										AiNpcAccuracy = peek(sAiNpcAccuracy),
										AiMovementProfile = peek(sAiMovementProfile),
										MaxZombies = 1,
										MaxZombiesEnabled = false,
										ZombieSpeed = 14,
										ZombieDamageEnabled = true,
										ZombieDamageAmount = 14,
										ZombieSpawnRate = 1,
										ZombieDodgeInterval = 4,
										ZombieCrouchChance = 0,
										AssessmentValidation = false,
										SelectedGun = peek(sAiWeapon) or "H-82",
										MinEngageDistance = 14,
										MaxEngageDistance = 22,
										StrafeApproachAngle = 70,
										MaxOrbitDuration = 3.0,
										CommitSpeedMultiplier = 1.1,
										ApproachSpeedMultiplier = 1.0,
										StrafeSpeedMultiplier = 0.9,
										StrafeHoldMin = 0.55,
										StrafeHoldMax = 1.2,
										StrafeFlipIntervalMin = 0.35,
										StrafeFlipIntervalMax = 0.85,
										MovementJitter = 0.15,
										OrbitDirectionBias = 0.5,
										ZombieJumpPower = 52,
										OrbitJumpChance = 0.5,
										JumpCooldown = 0.5,
										JukeJumpChance = 0.4,
										BunnyHopEnabled = true,
										BunnyHopChainChance = 0.55,
										BunnyHopSpeedMultiplier = 1.2,
										BunnyHopMaxChain = 3,
										ApproachJukeChance = 0.1,
										SeparationMaxForce = 0,
										ApproachJumpChance = 0.5,
										ApproachCrouchChance = 0,
										CloseRangeJumpChance = 0,
										DecisionTimeStaggerMax = 0.3,
										SpawnRateRampEnabled = false,
										SpawnRateRampStartRate = 1,
										SpawnRateRampDuration = 60,
									}
									props.OnApply(newSet)
								end
							end
						end,
					}),
					feedbackBanner,
				},
			}),
		},
	})

	local contentFrame = scope:New("Frame")({
		Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT),
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		[Fusion.Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 20),
				PaddingRight = UDim.new(0, 20),
				PaddingTop = UDim.new(0, 16),
				PaddingBottom = UDim.new(0, 16),
			}),
			pickerPage,
			configPage,
		},
	})

	local modal = scope:New("Frame")({
		Name = "AimChamberModal",
		Size = scope:Computed(function(use)
			local t = use(tierOffset)
			return UDim2.fromOffset(MODAL_WIDTH, 400 + (220 * t))
		end),
		Position = scope:Computed(function(use: FusionUseFn)
			local offset = use(modalOffsetY)
			return UDim2.new(0.5, 0, 0.5, offset)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UIScale")({ Scale = modalScale }),

			Shadow(scope, {
				Size = UDim2.fromScale(1.02, 1.02),
				Position = UDim2.new(0.5, 0, 0.5, 4),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = 24,
				Transparency = scope:Computed(function(use)
					return 0.65 + (0.35 * use(modalTransparency))
				end),
				ZIndex = 0,
			}),

			scope:New("CanvasGroup")({
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(8, 8, 8),
				BackgroundTransparency = 0.35,
				GroupTransparency = modalTransparency,
				ZIndex = 1,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Radius.XLarge }),
					scope:New("UIStroke")({
						Color = Color3.fromRGB(50, 50, 55),
						Thickness = 1,
						Transparency = scope:Computed(function(use: FusionUseFn)
							return 0.5 + (0.5 * use(modalTransparency))
						end),
					}),
					scope:New("UIGradient")({
						Color = STROKE_GRADIENT_COLOR,
						Rotation = 90,
					}),
					header,
					contentFrame,
				},
			}),
		},
	})

	local overlay = scope:New("Frame")({
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Black[900],
		BackgroundTransparency = overlayTransparency,
		ZIndex = 1,
	})

	local screenGui = scope:New("ScreenGui")({
		Name = "AimChamberConfigUI",
		AutoLocalize = false,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
		IgnoreGuiInset = true,
		Enabled = scope:Computed(function(use: FusionUseFn)
			return use(isVisible) or use(modalTransparency) < 0.99
		end),
		[Fusion.Children] = {
			overlay,
			scope:New("Frame")({
				Name = "ModalContainer",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 2,
				[Fusion.Children] = { modal },
			}),
		},
	})

	return screenGui :: ScreenGui
end

return AimChamberConfigUI
