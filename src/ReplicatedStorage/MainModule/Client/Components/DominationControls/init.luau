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

export type DominationControlsProps = {
	Visible: FusionCanBeState<boolean>,
	IsOfficial: FusionCanBeState<boolean>,
	Paused: FusionCanBeState<boolean>,
	DefenderScore: FusionValue<number>,
	HostileScore: FusionValue<number>,
	MaxScore: FusionValue<number>,
	OnClose: (() -> ())?,
	OnStart: (() -> ())?,
	OnEnd: (() -> ())?,
	OnPause: (() -> ())?,
	OnUnpause: (() -> ())?,
	OnDefenderScoreChange: ((number) -> ())?,
	OnHostileScoreChange: ((number) -> ())?,
	OnMaxScoreChange: ((number) -> ())?,
	
	CaptureTimeSeconds: FusionValue<number>,
	SpeedBonusPerPlayer: FusionValue<number>,
	SpeedBonusMaxPlayers: FusionValue<number>,
	OnCaptureTimeSecondsChange: ((number) -> ())?,
	OnSpeedBonusPerPlayerChange: ((number) -> ())?,
	OnSpeedBonusMaxPlayersChange: ((number) -> ())?,
}

local TERMINAL_ICON = "rbxassetid://119015428034090"

local MODAL_WIDTH = 320
local HEADER_HEIGHT = 44
local CONTENT_PADDING = 16
local SECTION_GAP = 14
local INPUT_WIDTH = 80
local INPUT_HEIGHT = 32

local ACCENT_COLOR = Color3.fromRGB(255, 180, 60)

local function NumberInput(scope: FusionScope, props: {
	Value: FusionValue<number>,
	Placeholder: string?,
	OnChange: ((number) -> ())?,
	Width: number?,
	Disabled: FusionCanBeState<boolean>?,
	AllowDecimals: boolean?,
}): Frame
	local isFocused = scope:Value(false)
	local function formatValue(val: number): string
		return tostring(props.AllowDecimals and val or math.floor(val))
	end
	local currentText = scope:Value(formatValue(peek(props.Value)))
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
			currentText:set(formatValue(peek(props.Value)))
		end
	end)

	local borderColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDisabled) then return Theme.Border.Subtle end
			return if use(isFocused) then Theme.Input.BorderFocused else Theme.Input.Border
		end),
		Theme.Spring.Default.Speed
	)

	local bgTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDisabled) then return Theme.Input.BackgroundTransparency + 0.2 end
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
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
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
					if peek(isDisabled) then return end
					local text = peek(currentText)
					local num = tonumber(text)
					if num and num >= 0 then
						if props.OnChange then
							props.OnChange(props.AllowDecimals and num or math.floor(num))
						end
					else
						currentText:set(formatValue(peek(props.Value)))
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
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
			scope:New("UIScale")({ Scale = scale }),
		},

		[Fusion.OnEvent("MouseEnter")] = function() isHovered:set(true) end,
		[Fusion.OnEvent("MouseLeave")] = function()
			isHovered:set(false)
			isPressed:set(false)
		end,
		[Fusion.OnEvent("MouseButton1Down")] = function() isPressed:set(true) end,
		[Fusion.OnEvent("MouseButton1Up")] = function() isPressed:set(false) end,
		[Fusion.OnEvent("Activated")] = function()
			if props.OnClick then
				props.OnClick()
			end
		end,
	})
end

local function SettingSection(scope: FusionScope, title: string, layoutOrder: number, children: { Instance }): Frame
	return scope:New("Frame")({
		Name = title:gsub("%s", EMPTY) .. "Section",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			scope:New("TextLabel")({
				Name = "Title",
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				Text = title,
				TextColor3 = ACCENT_COLOR,
				TextSize = Theme.Text.XSmall,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
			}),

			scope:New("Frame")({
				Name = "Content",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				[Fusion.Children] = children,
			}),
		},
	})
end

local function buildHeader(scope: FusionScope, closeModal: () -> ()): Frame
	return scope:New("Frame")({
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
						Text = "DOMINATION CONTROLS",
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
	})
end

local function buildActions(scope: FusionScope, props: DominationControlsProps, isOfficial: any, paused: any): Frame
	return scope:New("Frame")({
		Name = "Actions",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			scope:Computed(function(use: FusionUseFn)
				if not use(isOfficial) then
					return PrimaryButton(scope, {
						Text = "START MATCH",
						IsPrimary = true,
						OnClick = props.OnStart,
					})
				end
				return nil
			end),

			scope:Computed(function(use: FusionUseFn)
				if use(isOfficial) then
					if use(paused) then
						return PrimaryButton(scope, {
							Text = "UNPAUSE MATCH",
							IsPrimary = true,
							OnClick = props.OnUnpause,
						})
					else
						return PrimaryButton(scope, {
							Text = "PAUSE MATCH",
							OnClick = props.OnPause,
						})
					end
				end
				return nil
			end),

			scope:Computed(function(use: FusionUseFn)
				if use(isOfficial) then
					return PrimaryButton(scope, {
						Text = "END MATCH",
						IsDestructive = true,
						OnClick = props.OnEnd,
					})
				end
				return nil
			end),
		},
	})
end

local function buildContent(scope: FusionScope, props: DominationControlsProps, isOfficial: any, notOfficial: any, statusText: any, paused: any): Frame
	local defenderScoreSection = SettingSection(scope, "SET DEFENDER SCORE", 3, {
		NumberInput(scope, {
			Value = props.DefenderScore,
			Placeholder = "0",
			Disabled = notOfficial,
			OnChange = function(value: number)
				props.DefenderScore:set(value)
				if props.OnDefenderScoreChange then
					props.OnDefenderScoreChange(value)
				end
			end,
		}),
	})

	local hostileScoreSection = SettingSection(scope, "SET HOSTILE SCORE", 4, {
		NumberInput(scope, {
			Value = props.HostileScore,
			Placeholder = "0",
			Disabled = notOfficial,
			OnChange = function(value: number)
				props.HostileScore:set(value)
				if props.OnHostileScoreChange then
					props.OnHostileScoreChange(value)
				end
			end,
		}),
	})

	local maxScoreSection = SettingSection(scope, "MAX SCORE", 5, {
		NumberInput(scope, {
			Value = props.MaxScore,
			Placeholder = "1000",
			Disabled = isOfficial,
			OnChange = function(value: number)
				props.MaxScore:set(value)
				if props.OnMaxScoreChange then
					props.OnMaxScoreChange(value)
				end
			end,
		}),
	})

	return scope:New("Frame")({
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

			scope:New("TextLabel")({
				Name = "StatusText",
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				Text = statusText,
				TextColor3 = Theme.Foreground.Muted,
				TextSize = Theme.Text.XSmall,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 0,
			}),

			buildActions(scope, props, isOfficial, paused),
			defenderScoreSection,
			hostileScoreSection,
			maxScoreSection,
			
			SettingSection(scope, "CAPTURE TIME SECONDS", 6, {
				NumberInput(scope, {
					Value = props.CaptureTimeSeconds,
					Placeholder = "5",
					Disabled = isOfficial,
					OnChange = function(value: number)
						props.CaptureTimeSeconds:set(value)
						if props.OnCaptureTimeSecondsChange then
							props.OnCaptureTimeSecondsChange(value)
						end
					end,
				}),
			}),
			
			SettingSection(scope, "CAPTURE SPEED MULTIPLIER", 7, {
				NumberInput(scope, {
					Value = props.SpeedBonusPerPlayer,
					Placeholder = "0.5",
					Disabled = isOfficial,
					AllowDecimals = true,
					OnChange = function(value: number)
						props.SpeedBonusPerPlayer:set(value)
						if props.OnSpeedBonusPerPlayerChange then
							props.OnSpeedBonusPerPlayerChange(value)
						end
					end,
				}),
			}),
			
			SettingSection(scope, "MAX PLAYERS FOR SPEED MULTIPLIER", 8, {
				NumberInput(scope, {
					Value = props.SpeedBonusMaxPlayers,
					Placeholder = "3",
					Disabled = isOfficial,
					OnChange = function(value: number)
						props.SpeedBonusMaxPlayers:set(value)
						if props.OnSpeedBonusMaxPlayersChange then
							props.OnSpeedBonusMaxPlayersChange(value)
						end
					end,
				}),
			}),
		},
	})
end

local function DominationControls(scope: FusionScope, props: DominationControlsProps): ScreenGui
	local isVisible = scope:Computed(function(use: FusionUseFn)
		local visible = props.Visible
		if typeof(visible) == "table" then return use(visible :: any) end
		return visible == true
	end)

	local isOfficial = scope:Computed(function(use: FusionUseFn)
		local off = props.IsOfficial
		if typeof(off) == "table" then return use(off :: any) end
		return off == true
	end)
	
	local paused = scope:Computed(function(use: FusionUseFn)
		local isPaused = props.Paused
		if typeof(isPaused) == "table" then return use(isPaused :: any) end
		return isPaused == true
	end)

	local modalScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then 1 else 0.95
		end),
		Theme.Spring.Snappy.Speed
	)

	local modalTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then 0 else 1
		end),
		Theme.Spring.Snappy.Speed
	)

	local notOfficial = scope:Computed(function(use: FusionUseFn)
		return not use(isOfficial)
	end)

	local statusText = scope:Computed(function(use: FusionUseFn)
		if not use(isOfficial) then
			return "UNOFFICIAL"
		end
		if use(paused) then
			return "PAUSED"
		end
		return "OFFICIAL"
	end)

	local closeModal = function()
		if props.OnClose then
			props.OnClose()
		end
	end

	local overlayTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then Theme.Modal.OverlayTransparency else 1
		end),
		Theme.Spring.Default.Speed
	)

	local header = buildHeader(scope, closeModal)
	local divider = scope:New("Frame")({
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		BackgroundColor3 = Theme.Border.Default,
		BackgroundTransparency = Theme.Stroke.Subtle,
		BorderSizePixel = 0,
	})
	local content = buildContent(scope, props, isOfficial, notOfficial, statusText, paused)

	local modal = scope:New("CanvasGroup")({
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
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
			scope:New("UIStroke")({
				Color = Theme.Modal.Border,
				Thickness = 1,
				Transparency = Theme.Stroke.Default,
			}),
			scope:New("UIScale")({ Scale = modalScale }),
			header,
			divider,
			content,
		},
	})

	local modalContainer = scope:New("Frame")({
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
			modal,
		},
	})

	return scope:New("ScreenGui")({
		Name = "DominationControls",
		AutoLocalize = false,
		DisplayOrder = 100,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = scope:Computed(function(use: FusionUseFn)
			return use(modalTransparency) < 0.99
		end),

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Overlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Modal.Overlay,
				BackgroundTransparency = overlayTransparency,
				BorderSizePixel = 0,
				ZIndex = 1,
			}),
			modalContainer,
		},
	})
end

return DominationControls

