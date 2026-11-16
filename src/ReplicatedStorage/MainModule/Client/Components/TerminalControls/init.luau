--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)

type FusionScope = Types.FusionScope
type FusionValue<T> = Types.FusionValue<T>
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

local EMPTY = ""
local peek: <T>(state: FusionCanBeState<T>) -> T = Fusion.peek

export type TerminalControlsProps = {
	Visible: FusionCanBeState<boolean>,
	IsOfficial: FusionCanBeState<boolean>,
	IsPaused: FusionCanBeState<boolean>,
	IsCountingDown: FusionCanBeState<boolean>,
	MaxPoints: FusionValue<number>,
	RotationMin: FusionValue<number>,
	RotationMax: FusionValue<number>,
	DefenderScore: FusionValue<number>,
	HostileScore: FusionValue<number>,
	DefaultMaxPoints: number,
	DefaultRotationMin: number,
	DefaultRotationMax: number,
	OnClose: (() -> ())?,
	OnStart: (() -> ())?,
	OnPause: (() -> ())?,
	OnUnpause: (() -> ())?,
	OnReset: (() -> ())?,
	OnMaxPointsChange: ((number) -> ())?,
	OnRotationRangeChange: ((number, number) -> ())?,
	OnScoresChange: ((number, number) -> ())?,
}

local TERMINAL_ICON = "rbxassetid://119015428034090"

local MODAL_WIDTH = 320
local HEADER_HEIGHT = 44
local CONTENT_PADDING = 16
local SECTION_GAP = 14
local INPUT_WIDTH = 65
local INPUT_HEIGHT = 32

local ACCENT_COLOR = Color3.fromRGB(255, 180, 60)
local DEFENDER_COLOR = Color3.fromRGB(180, 50, 50)
local HOSTILE_COLOR = Color3.fromRGB(50, 110, 200)

local function NumberInput(scope: FusionScope, props: {
	Value: FusionValue<number>,
	Placeholder: string?,
	OnChange: ((number) -> ())?,
	Width: number?,
	Disabled: FusionCanBeState<boolean>?,
}): Frame
	local isFocused = scope:Value(false)
	local currentText = scope:Value(tostring(peek(props.Value)))
	local width = props.Width or INPUT_WIDTH

	local isDisabled = scope:Computed(function(use: FusionUseFn)
		local disabled = props.Disabled
		if typeof(disabled) == "table" then
			return use(disabled :: any)
		end
		return disabled == true
	end)

	scope:Observer(props.Value):onChange(function()
		if not peek(isFocused) then
			currentText:set(tostring(peek(props.Value)))
		end
	end)

	local borderColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDisabled) then
				return Theme.Border.Subtle
			end
			return if use(isFocused) then Theme.Input.BorderFocused else Theme.Input.Border
		end),
		Theme.Spring.Default.Speed
	)

	local bgTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDisabled) then
				return Theme.Input.BackgroundTransparency + 0.2
			end
			return if use(isFocused) then Theme.Input.BackgroundFocusedTransparency else Theme.Input.BackgroundTransparency
		end),
		Theme.Spring.Default.Speed
	)

	local textColor = scope:Computed(function(use: FusionUseFn)
		return if use(isDisabled) then Theme.Foreground.Disabled else Theme.Input.Text
	end)

	return scope:New("Frame")({
		Name = "NumberInput",
		Size = UDim2.fromOffset(width, INPUT_HEIGHT),
		BackgroundColor3 = Theme.Input.Background,
		BackgroundTransparency = bgTransparency,
		BorderSizePixel = 0,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Medium,
			}),

			scope:New("UIStroke")({
				Color = borderColor,
				Thickness = 1,
				Transparency = Theme.Stroke.Default,
			}),

			scope:New("TextBox")({
				Name = "Input",
				Size = UDim2.new(1, -12, 1, 0),
				Position = UDim2.fromOffset(6, 0),
				BackgroundTransparency = 1,
				Text = currentText,
				PlaceholderText = props.Placeholder or "",
				PlaceholderColor3 = Theme.Input.Placeholder,
				TextColor3 = textColor,
				TextSize = Theme.Text.Medium,
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
					local text = peek(currentText)
					local num = tonumber(text)
					if num and num > 0 then
						if props.OnChange then
							props.OnChange(math.floor(num))
						end
					else
						currentText:set(tostring(peek(props.Value)))
					end
				end,
			}),
		},
	})
end

local function PrimaryButton(scope: FusionScope, props: {
	Text: string,
	OnClick: (() -> ())?,
	IsPrimary: boolean?,
	IsDestructive: boolean?,
}): TextButton
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)

	local buttonTheme = if props.IsDestructive then Theme.Button.Destructive
		elseif props.IsPrimary then Theme.Button.Primary
		else Theme.Button.Secondary

	local bgColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) or use(isPressed) then buttonTheme.BackgroundHover else buttonTheme.Background
		end),
		Theme.Spring.Snappy.Speed
	)

	local scale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isPressed) then 0.98 else 1
		end),
		Theme.Spring.Snappy.Speed
	)

	return scope:New("TextButton")({
		Name = props.Text:gsub("%s", EMPTY) .. "Button",
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = bgColor,
		BorderSizePixel = 0,
		Text = props.Text,
		TextColor3 = buttonTheme.Foreground,
		TextSize = Theme.Text.Medium,
		Font = Theme.Text.Bold,
		AutoButtonColor = false,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Medium,
			}),

			scope:New("UIScale")({
				Scale = scale,
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
			if props.OnClick then
				props.OnClick()
			end
		end,
	})
end

local function ResetLink(scope: FusionScope, props: {
	OnClick: (() -> ())?,
	Disabled: FusionCanBeState<boolean>?,
}): TextButton
	local isHovered = scope:Value(false)

	local isDisabled = scope:Computed(function(use: FusionUseFn)
		local disabled = props.Disabled
		if typeof(disabled) == "table" then
			return use(disabled :: any)
		end
		return disabled == true
	end)

	local textColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDisabled) then
				return Theme.Foreground.Disabled
			end
			return if use(isHovered) then ACCENT_COLOR else Theme.Foreground.Muted
		end),
		Theme.Spring.Default.Speed
	)

	return scope:New("TextButton")({
		Name = "ResetLink",
		Size = UDim2.fromOffset(40, 16),
		BackgroundTransparency = 1,
		Text = "Reset",
		TextColor3 = textColor,
		TextSize = Theme.Text.XSmall,
		Font = Theme.Text.Semibold,
		AutoButtonColor = false,

		[Fusion.OnEvent("MouseEnter")] = function()
			isHovered:set(true)
		end,

		[Fusion.OnEvent("MouseLeave")] = function()
			isHovered:set(false)
		end,

		[Fusion.OnEvent("Activated")] = function()
			if not peek(isDisabled) and props.OnClick then
				props.OnClick()
			end
		end,
	})
end

local function SettingSection(scope: FusionScope, props: {
	Title: string,
	LayoutOrder: number?,
	ResetCallback: (() -> ())?,
	Disabled: FusionCanBeState<boolean>?,
	Children: { Instance },
}): Frame
	return scope:New("Frame")({
		Name = props.Title:gsub("%s", EMPTY) .. "Section",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			scope:New("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				LayoutOrder = 1,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "Title",
						Size = UDim2.new(1, -50, 1, 0),
						BackgroundTransparency = 1,
						Text = props.Title,
						TextColor3 = ACCENT_COLOR,
						TextSize = Theme.Text.XSmall,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),

					if props.ResetCallback then scope:New("Frame")({
						Name = "ResetContainer",
						Size = UDim2.new(0, 40, 1, 0),
						Position = UDim2.fromScale(1, 0),
						AnchorPoint = Vector2.new(1, 0),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							ResetLink(scope, {
								OnClick = props.ResetCallback,
								Disabled = props.Disabled,
							}),
						},
					}) else nil,
				},
			}),

			scope:New("Frame")({
				Name = "Content",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,

				[Fusion.Children] = props.Children,
			}),
		},
	})
end

local function TerminalControls(scope: FusionScope, props: TerminalControlsProps): ScreenGui
	local isVisible = scope:Computed(function(use: FusionUseFn)
		local visible = props.Visible
		if typeof(visible) == "table" then
			return use(visible :: any)
		end
		return visible == true
	end)

	local isOfficial = scope:Computed(function(use: FusionUseFn)
		local official = props.IsOfficial
		if typeof(official) == "table" then
			return use(official :: any)
		end
		return official == true
	end)

	local isPaused = scope:Computed(function(use: FusionUseFn)
		local paused = props.IsPaused
		if typeof(paused) == "table" then
			return use(paused :: any)
		end
		return paused == true
	end)

	local modalScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return use(isVisible) and 1 or 0.96
		end),
		Theme.Spring.Snappy.Speed
	)

	local modalTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return use(isVisible) and 0 or 1
		end),
		Theme.Spring.Default.Speed
	)

	local overlayTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then Theme.Modal.OverlayTransparency else 1
		end),
		Theme.Spring.Default.Speed
	)

	local function closeModal()
		if props.OnClose then
			props.OnClose()
		end
	end

	local maxPointsSection = SettingSection(scope, {
		Title = "MAX POINTS",
		LayoutOrder = 2,
		ResetCallback = function()
			props.MaxPoints:set(props.DefaultMaxPoints)
			if props.OnMaxPointsChange then
				props.OnMaxPointsChange(props.DefaultMaxPoints)
			end
		end,
		Children = {
			NumberInput(scope, {
				Value = props.MaxPoints,
				Placeholder = tostring(props.DefaultMaxPoints),
				Width = 80,
				OnChange = function(value: number)
					props.MaxPoints:set(value)
					if props.OnMaxPointsChange then
						props.OnMaxPointsChange(value)
					end
				end,
			}),
		},
	})

	local rotationSection = SettingSection(scope, {
		Title = "ROTATION TIME (seconds)",
		LayoutOrder = 3,
		Disabled = isOfficial,
		ResetCallback = function()
			if peek(isOfficial) then return end
			props.RotationMin:set(props.DefaultRotationMin)
			props.RotationMax:set(props.DefaultRotationMax)
			if props.OnRotationRangeChange then
				props.OnRotationRangeChange(props.DefaultRotationMin, props.DefaultRotationMax)
			end
		end,
		Children = {
			scope:New("Frame")({
				Name = "RotationInputs",
				Size = UDim2.new(1, 0, 0, INPUT_HEIGHT),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 8),
					}),

					scope:New("TextLabel")({
						Name = "FromLabel",
						Size = UDim2.fromOffset(32, INPUT_HEIGHT),
						BackgroundTransparency = 1,
						Text = "FROM",
						TextColor3 = Theme.Foreground.Muted,
						TextSize = Theme.Text.XSmall,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 1,
					}),

					scope:New("Frame")({
						Name = "MinWrapper",
						Size = UDim2.fromOffset(INPUT_WIDTH, INPUT_HEIGHT),
						BackgroundTransparency = 1,
						LayoutOrder = 2,
						[Fusion.Children] = {
							NumberInput(scope, {
								Value = props.RotationMin,
								Placeholder = tostring(props.DefaultRotationMin),
								Disabled = isOfficial,
								OnChange = function(value: number)
									local currentMax = peek(props.RotationMax)
									if value > currentMax then
										props.RotationMax:set(value)
									end
									props.RotationMin:set(value)
									if props.OnRotationRangeChange then
										props.OnRotationRangeChange(value, math.max(currentMax, value))
									end
								end,
							}),
						},
					}),

					scope:New("TextLabel")({
						Name = "ToLabel",
						Size = UDim2.fromOffset(16, INPUT_HEIGHT),
						BackgroundTransparency = 1,
						Text = "TO",
						TextColor3 = Theme.Foreground.Muted,
						TextSize = Theme.Text.XSmall,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						LayoutOrder = 3,
					}),

					scope:New("Frame")({
						Name = "MaxWrapper",
						Size = UDim2.fromOffset(INPUT_WIDTH, INPUT_HEIGHT),
						BackgroundTransparency = 1,
						LayoutOrder = 4,
						[Fusion.Children] = {
							NumberInput(scope, {
								Value = props.RotationMax,
								Placeholder = tostring(props.DefaultRotationMax),
								Disabled = isOfficial,
								OnChange = function(value: number)
									local currentMin = peek(props.RotationMin)
									if value < currentMin then
										props.RotationMin:set(value)
									end
									props.RotationMax:set(value)
									if props.OnRotationRangeChange then
										props.OnRotationRangeChange(math.min(currentMin, value), value)
									end
								end,
							}),
						},
					}),
				},
			}),
		},
	})

	local notOfficial = scope:Computed(function(use: FusionUseFn)
		return not use(isOfficial)
	end)

	local scoresSection = SettingSection(scope, {
		Title = "SCORES",
		LayoutOrder = 4,
		Disabled = notOfficial,
		ResetCallback = function()
			if not peek(isOfficial) then return end
			props.DefenderScore:set(0)
			props.HostileScore:set(0)
			if props.OnScoresChange then
				props.OnScoresChange(0, 0)
			end
		end,
		Children = {
			scope:New("Frame")({
				Name = "ScoresInputs",
				Size = UDim2.new(1, 0, 0, INPUT_HEIGHT),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 8),
					}),

					scope:New("TextLabel")({
						Name = "DefenderLabel",
						Size = UDim2.fromOffset(55, INPUT_HEIGHT),
						BackgroundTransparency = 1,
						Text = "VULTAR",
						TextColor3 = DEFENDER_COLOR,
						TextSize = Theme.Text.XSmall,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 1,
					}),

					scope:New("Frame")({
						Name = "DefenderWrapper",
						Size = UDim2.fromOffset(INPUT_WIDTH, INPUT_HEIGHT),
						BackgroundTransparency = 1,
						LayoutOrder = 2,
						[Fusion.Children] = {
							NumberInput(scope, {
								Value = props.DefenderScore,
								Placeholder = "0",
								Disabled = notOfficial,
								OnChange = function(value: number)
									props.DefenderScore:set(value)
									if props.OnScoresChange then
										props.OnScoresChange(value, peek(props.HostileScore))
									end
								end,
							}),
						},
					}),

					scope:New("TextLabel")({
						Name = "HostileLabel",
						Size = UDim2.fromOffset(55, INPUT_HEIGHT),
						BackgroundTransparency = 1,
						Text = "HOSTILE",
						TextColor3 = HOSTILE_COLOR,
						TextSize = Theme.Text.XSmall,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						LayoutOrder = 3,
					}),

					scope:New("Frame")({
						Name = "HostileWrapper",
						Size = UDim2.fromOffset(INPUT_WIDTH, INPUT_HEIGHT),
						BackgroundTransparency = 1,
						LayoutOrder = 4,
						[Fusion.Children] = {
							NumberInput(scope, {
								Value = props.HostileScore,
								Placeholder = "0",
								Disabled = notOfficial,
								OnChange = function(value: number)
									props.HostileScore:set(value)
									if props.OnScoresChange then
										props.OnScoresChange(peek(props.DefenderScore), value)
									end
								end,
							}),
						},
					}),
				},
			}),
		},
	})

	return scope:New("ScreenGui")({
		Name = "TerminalControls",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 15,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = isVisible,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Overlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Modal.Overlay,
				BackgroundTransparency = overlayTransparency,
				BorderSizePixel = 0,
				ZIndex = 1,
			}),

			scope:New("Frame")({
				Name = "ModalContainer",
				Size = UDim2.fromOffset(MODAL_WIDTH + 16, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 2,

				[Fusion.Children] = {
					Shadow(scope, {
						Size = UDim2.fromScale(1, 1),
						Position = UDim2.new(0.5, 0, 0.5, 3),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Spread = 8,
						Transparency = 0.5,
						ZIndex = 0,
					}),

					scope:New("CanvasGroup")({
						Name = "Modal",
						Size = UDim2.new(1, -16, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						Position = UDim2.fromOffset(8, 8),
						BackgroundColor3 = Theme.Modal.Background,
						BackgroundTransparency = Theme.Modal.BackgroundTransparency,
						BorderSizePixel = 0,
						GroupTransparency = modalTransparency,
						ZIndex = 1,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = Theme.Radius.Large,
							}),

							scope:New("UIStroke")({
								Color = Theme.Modal.Border,
								Thickness = 1,
								Transparency = Theme.Stroke.Default,
							}),

							scope:New("UIScale")({
								Scale = modalScale,
							}),

							scope:New("Frame")({
								Name = "Header",
								Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
								BackgroundColor3 = Theme.Modal.Header,
								BackgroundTransparency = Theme.Modal.HeaderTransparency,
								BorderSizePixel = 0,

								[Fusion.Children] = {
									scope:New("UIPadding")({
										PaddingLeft = UDim.new(0, 14),
										PaddingRight = UDim.new(0, 10),
									}),

									scope:New("Frame")({
										Name = "TitleGroup",
										Size = UDim2.new(1, -32, 1, 0),
										BackgroundTransparency = 1,

										[Fusion.Children] = {
											scope:New("UIListLayout")({
												FillDirection = Enum.FillDirection.Horizontal,
												VerticalAlignment = Enum.VerticalAlignment.Center,
												Padding = UDim.new(0, 8),
											}),

											scope:New("ImageLabel")({
												Name = "Icon",
												Size = UDim2.fromOffset(16, 16),
												BackgroundTransparency = 1,
												Image = TERMINAL_ICON,
												ImageColor3 = ACCENT_COLOR,
											}),

											scope:New("TextLabel")({
												Name = "Title",
												Size = UDim2.fromScale(0, 1),
												AutomaticSize = Enum.AutomaticSize.X,
												BackgroundTransparency = 1,
												Text = "TERMINAL CONTROLS",
												TextColor3 = Theme.Foreground.Primary,
												TextSize = Theme.Text.Small,
												Font = Theme.Text.Bold,
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
										TextColor3 = Theme.Foreground.Muted,
										TextSize = Theme.Text.Medium,
										Font = Theme.Text.Bold,

										[Fusion.OnEvent("Activated")] = closeModal,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "Divider",
								Size = UDim2.new(1, 0, 0, 1),
								Position = UDim2.fromOffset(0, HEADER_HEIGHT),
								BackgroundColor3 = Theme.Border.Default,
								BackgroundTransparency = Theme.Stroke.Subtle,
								BorderSizePixel = 0,
							}),

							scope:New("Frame")({
								Name = "Content",
								Size = UDim2.fromScale(1, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								Position = UDim2.fromOffset(0, HEADER_HEIGHT),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									scope:New("UIPadding")({
										PaddingLeft = UDim.new(0, CONTENT_PADDING),
										PaddingRight = UDim.new(0, CONTENT_PADDING),
										PaddingTop = UDim.new(0, CONTENT_PADDING),
										PaddingBottom = UDim.new(0, CONTENT_PADDING),
									}),

									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Vertical,
										Padding = UDim.new(0, SECTION_GAP),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),

									scope:New("Frame")({
										Name = "Actions",
										Size = UDim2.fromScale(1, 0),
										AutomaticSize = Enum.AutomaticSize.Y,
										BackgroundTransparency = 1,
										LayoutOrder = 1,

										[Fusion.Children] = {
											scope:New("UIListLayout")({
												FillDirection = Enum.FillDirection.Horizontal,
												HorizontalAlignment = Enum.HorizontalAlignment.Center,
												Padding = UDim.new(0, 8),
											}),

											scope:Computed(function(use: FusionUseFn)
												if not use(isOfficial) then
													return scope:New("Frame")({
														Name = "StartWrapper",
														Size = UDim2.new(1, 0, 0, 38),
														BackgroundTransparency = 1,
														[Fusion.Children] = {
															PrimaryButton(scope, {
																Text = "START RAID",
																IsPrimary = true,
																OnClick = props.OnStart,
															}),
														},
													})
												end
												return nil
											end),

											scope:Computed(function(use: FusionUseFn)
												if use(isOfficial) then
													return scope:New("Frame")({
														Name = "OfficialButtons",
														Size = UDim2.new(1, 0, 0, 38),
														BackgroundTransparency = 1,
														[Fusion.Children] = {
															scope:New("UIListLayout")({
																FillDirection = Enum.FillDirection.Horizontal,
																HorizontalAlignment = Enum.HorizontalAlignment.Center,
																Padding = UDim.new(0, 8),
															}),

															scope:New("Frame")({
																Name = "PauseWrapper",
																Size = UDim2.new(0.5, -4, 1, 0),
																BackgroundTransparency = 1,
																LayoutOrder = 1,
																[Fusion.Children] = {
																	PrimaryButton(scope, {
																		Text = if use(isPaused) then "RESUME" else "PAUSE",
																		IsPrimary = use(isPaused),
																		OnClick = if use(isPaused) then props.OnUnpause else props.OnPause,
																	}),
																},
															}),

															scope:New("Frame")({
																Name = "ResetWrapper",
																Size = UDim2.new(0.5, -4, 1, 0),
																BackgroundTransparency = 1,
																LayoutOrder = 2,
																[Fusion.Children] = {
																	PrimaryButton(scope, {
																		Text = "RESET",
																		IsDestructive = true,
																		OnClick = props.OnReset,
																	}),
																},
															}),
														},
													})
												end
												return nil
											end),
										},
									}),

									maxPointsSection,
									rotationSection,
									scoresSection,
								},
							}),
						},
					}),
				},
			}),
		},
	})
end

return TerminalControls
