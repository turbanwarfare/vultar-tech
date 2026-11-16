--!native
--!optimize 2

local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

export type SliderProps = {
	Value: FusionCanBeState<number>,
	Min: number?,
	Max: number?,
	Step: number?,
	OnChange: ((number) -> ())?,
}

local TRACK_WIDTH = 140
local TRACK_HEIGHT = 8
local THUMB_SIZE = 12
local THUMB_SIZE_ACTIVE = 14

local function Slider(scope: FusionScope, props: SliderProps): Frame
	local min = props.Min or 0
	local max = props.Max or 1
	local step = props.Step or 0.01

	local isDragging = scope:Value(false)
	local isHovered = scope:Value(false)
	local lastDragValue: number? = nil

	local normalizedValue = scope:Computed(function(use: FusionUseFn)
		local val = use(props.Value) or min
		return math.clamp((val - min) / (max - min), 0, 1)
	end)

	local thumbPosition = scope:Computed(function(use: FusionUseFn)
		return UDim2.fromScale(use(normalizedValue), 0.5)
	end)

	local trackColor = scope:Computed(function(use: FusionUseFn)
		if use(isDragging) or use(isHovered) then
			return Theme.Colors.SuccessHover
		end
		return Theme.Colors.Success
	end)

	local thumbSize = scope:Computed(function(use: FusionUseFn)
		if use(isDragging) then
			return UDim2.fromOffset(THUMB_SIZE_ACTIVE, THUMB_SIZE_ACTIVE)
		elseif use(isHovered) then
			return UDim2.fromOffset(THUMB_SIZE + 1, THUMB_SIZE + 1)
		end
		return UDim2.fromOffset(THUMB_SIZE, THUMB_SIZE)
	end)

	local thumbColor = scope:Computed(function(use: FusionUseFn)
		if use(isDragging) then
			return Theme.Colors.SuccessHover
		end
		return Theme.Foreground.Primary
	end)

	local displayValue = scope:Computed(function(use: FusionUseFn)
		local val = use(props.Value) or min
		if step >= 1 then
			return tostring(math.floor(val))
		end
		return string.format("%.2f", val)
	end)

	local track: Frame = scope:New("Frame")({
		Name = "Track",
		Size = UDim2.fromOffset(TRACK_WIDTH, TRACK_HEIGHT),
		Position = UDim2.fromScale(0, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Background.Secondary,
		BorderSizePixel = 0,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = UDim.new(0, TRACK_HEIGHT / 2),
			}),

			scope:New("Frame")({
				Name = "Fill",
				Size = scope:Computed(function(use: FusionUseFn)
					return UDim2.fromScale(use(normalizedValue), 1)
				end),
				BackgroundColor3 = trackColor,
				BorderSizePixel = 0,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, TRACK_HEIGHT / 2),
					}),
				},
			}),

			scope:New("Frame")({
				Name = "Thumb",
				Size = thumbSize,
				Position = thumbPosition,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = thumbColor,
				BorderSizePixel = 0,
				ZIndex = 2,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(1, 0),
					}),

					scope:New("UIStroke")({
						Color = Theme.Background.Primary,
						Thickness = 2,
						Transparency = 0.5,
					}),
				},
			}),
		},
	})

	local function updateValue(inputX: number)
		local trackPos = track.AbsolutePosition.X
		local trackWidth = track.AbsoluteSize.X
		local relativeX = math.clamp((inputX - trackPos) / trackWidth, 0, 1)
		local rawValue = min + relativeX * (max - min)
		local steppedValue = (rawValue / step + 0.5) // 1 * step
		local clampedValue = math.clamp(steppedValue, min, max)

		if clampedValue == lastDragValue then
			return
		end
		lastDragValue = clampedValue

		if props.OnChange then
			props.OnChange(clampedValue)
		end
	end

	local inputConnection: RBXScriptConnection? = nil
	local endConnection: RBXScriptConnection? = nil

	local function cleanupDragConnections()
		if inputConnection then
			inputConnection:Disconnect()
			inputConnection = nil
		end
		if endConnection then
			endConnection:Disconnect()
			endConnection = nil
		end
	end

	local function startDrag()
		isDragging:set(true)
		cleanupDragConnections()

		inputConnection = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				updateValue(input.Position.X)
			end
		end)

		endConnection = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				isDragging:set(false)
				lastDragValue = nil
				cleanupDragConnections()
			end
		end)
	end

	table.insert(scope, cleanupDragConnections)

	local function submitTextValue(text: string)
		local num = tonumber(text)
		if num then
			local steppedValue = (num / step + 0.5) // 1 * step
			local clampedValue = math.clamp(steppedValue, min, max)
			if props.OnChange then
				props.OnChange(clampedValue)
			end
		end
	end

	local valueTextBox: TextBox = scope:New("TextBox")({
		Name = "Value",
		Size = UDim2.fromOffset(48, 20),
		Position = UDim2.new(0, TRACK_WIDTH + 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Background.Secondary,
		BorderSizePixel = 0,
		Text = displayValue,
		TextColor3 = Theme.Foreground.Subtle,
		TextSize = Theme.Text.Small,
		Font = Theme.Text.Semibold,
		TextXAlignment = Enum.TextXAlignment.Center,
		ClearTextOnFocus = false,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = UDim.new(0, 4),
			}),

			scope:New("UIStroke")({
				Color = Theme.Border.Subtle,
				Thickness = 1,
				Transparency = 0.5,
			}),
		},
	})

	local focusLostConnection = valueTextBox.FocusLost:Connect(function()
		submitTextValue(valueTextBox.Text)
	end)
	table.insert(scope, function()
		focusLostConnection:Disconnect()
	end)

	return scope:New("Frame")({
		Name = "Slider",
		Size = UDim2.fromOffset(TRACK_WIDTH + 8 + 48, 24),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			track,

			valueTextBox,

			scope:New("TextButton")({
				Name = "Hitbox",
				Size = UDim2.fromOffset(TRACK_WIDTH, 24),
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text = "",

				[Fusion.OnEvent("MouseEnter")] = function()
					isHovered:set(true)
				end,

				[Fusion.OnEvent("MouseLeave")] = function()
					isHovered:set(false)
				end,

				[Fusion.OnEvent("MouseButton1Down")] = function()
					local mouse = UserInputService:GetMouseLocation()
					updateValue(mouse.X)
					startDrag()
				end,
			}),
		},
	})
end

return Slider
