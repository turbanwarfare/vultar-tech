--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type ScoreTickerProps = {
	TargetValue: number,
	StartCounting: any,
	Duration: number?,
	TextSize: number?,
	TextColor: any?,
	TextTransparency: any?,
}

local DEFAULT_DURATION = 2.5
local DIGIT_COUNT = 4

local function formatScore(value: number): string
	local clamped = math.clamp(math.floor(value), 0, 9999)
	return string.format("%04d", clamped)
end

local function easeOutExpo(t: number): number
	return if t >= 1 then 1 else 1 - math.pow(2, -10 * t)
end

local function ScoreTicker(scope: FusionScope, props: ScoreTickerProps): Frame
	local targetValue = props.TargetValue
	local startCounting = props.StartCounting
	local duration = props.Duration or DEFAULT_DURATION
	local textSize = props.TextSize or 72
	local textColor = props.TextColor or scope:Value(Theme.Colors.White)
	local textTransparency = props.TextTransparency

	local currentValue = scope:Value(0)
	local isAnimating = scope:Value(false)
	local animThread: thread? = nil

	local displayText = scope:Computed(function(use: FusionUseFn)
		return formatScore(use(currentValue))
	end)

	scope:Observer(startCounting):onChange(function()
		if Fusion.peek(startCounting) and not Fusion.peek(isAnimating) then
			isAnimating:set(true)

			animThread = task.spawn(function()
				local startTime = os.clock()
				local startVal = 0
				local endVal = targetValue

				while true do
					local elapsed = os.clock() - startTime
					local progress = math.min(elapsed / duration, 1)
					local easedProgress = easeOutExpo(progress)
					local newValue = startVal + (endVal - startVal) * easedProgress

					currentValue:set(newValue)

					if progress >= 1 then
						currentValue:set(endVal)
						break
					end

					task.wait()
				end

				animThread = nil
				isAnimating:set(false)
			end)
		end
	end)

	table.insert(scope, function()
		if animThread then
			task.cancel(animThread)
			animThread = nil
		end
	end)

	local digitLabels = {}

	for i = 1, DIGIT_COUNT do
		local digitValue = scope:Computed(function(use: FusionUseFn)
			local text = use(displayText)
			return string.sub(text, i, i)
		end)

		local digitLabel = scope:New("TextLabel")({
			Name = "Digit" .. i,
			Size = UDim2.new(0, textSize * 0.6, 1, 0),
			BackgroundTransparency = 1,
			Text = digitValue,
			TextColor3 = scope:Computed(function(use: FusionUseFn)
				if type(textColor) == "table" and textColor.get then
					return use(textColor)
				end
				return textColor
			end),
			TextTransparency = textTransparency,
			TextSize = textSize,
			Font = Theme.Text.Black,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = i,
		})

		table.insert(digitLabels, digitLabel)
	end

	return scope:New("Frame")({
		Name = "ScoreTicker",
		Size = UDim2.new(1, 0, 0, textSize + 10),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 2),
			}),

			digitLabels,
		},
	})
end

return ScoreTicker
