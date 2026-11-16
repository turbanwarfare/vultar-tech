--!strict
--!native
--!optimize 2

local SoundService = game:GetService("SoundService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local FormatUtils = require(MainModule.Shared.Utils.Text.FormatUtils)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionValue<T> = Types.FusionValue<T>

local TRANSPARENCY_NUM_SEQ = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0.2),
	NumberSequenceKeypoint.new(1, 0.8),
})

local CREDITS_ICON = "rbxassetid://0"
local HEIGHT = 40

local TICK_SOUND_ID = "rbxassetid://72500887678395"
local CHIME_SOUND_ID = "rbxassetid://137214707166921"

local rng = Random.new()

local function getOrCreateSound(name: string, soundId: string, volume: number): Sound
	local sound = SoundService:FindFirstChild(name) :: Sound?
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = soundId
		sound.Volume = volume
		sound.Parent = SoundService
	end
	return sound
end

local function playTickSound()
	pcall(function()
		local sound = getOrCreateSound("Balance_Tick", TICK_SOUND_ID, 0.18)
		sound.PlaybackSpeed = 0.95 + rng:NextNumber() * 0.2
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
	end)
end

local function playChimeSound()
	pcall(function()
		local sound = getOrCreateSound("Balance_Chime", CHIME_SOUND_ID, 0.3)
		sound.PlaybackSpeed = 1.05
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
	end)
end

export type CreditsDisplayProps = {
	Balance: FusionCanBeState<number>,
	OnClick: (() -> ())?,
	OnAddCredits: (() -> ())?,
	ShowAddCredits: boolean?,
	Position: FusionCanBeState<UDim2>?,
	AnchorPoint: Vector2?,
	ZIndex: number?,
	Visible: FusionCanBeState<boolean>?,
}

local function CreditsDisplay(scope: FusionScope, props: CreditsDisplayProps): Frame
	local function resolveBalance(): number
		local raw = if typeof(props.Balance) == "table"
			then Fusion.peek(props.Balance :: any)
			elseif typeof(props.Balance) == "function" then (props.Balance :: any)()
			else props.Balance
		return tonumber(raw) or 0
	end

	local initialBal = resolveBalance()
	local lastBalance = initialBal

	local displayedBalance = scope:Value(initialBal)
	local isHovered = scope:Value(false)
	local isPlusHovered = scope:Value(false)

	local amountScale = scope:Value(1.0)
	local amountColor = scope:Value(Color3.new(1, 1, 1))

	local strokeFlashColor = scope:Value(Theme.Border.Default)
	local isFlashingStroke = scope:Value(false)

	local rollThread: thread? = nil
	local flashColorThread: thread? = nil

	local borderTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isFlashingStroke) then
				return 0.05
			end
			return if use(isHovered) then 0.1 else 0.4
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local strokeColor = scope:Spring(strokeFlashColor, 14, 0.75)

	local amountScaleSpring = scope:Spring(amountScale, 28, 0.6)

	local amountColorSpring = scope:Spring(amountColor, 12, 0.8)

	local plusScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isPlusHovered) then 1.12 else 1
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local amountText = scope:Computed(function(use: FusionUseFn)
		local num = use(displayedBalance)
		return FormatUtils.formatNumberWithCommas(math.round(num))
	end)

	local function handlePlusClick()
		if props.OnAddCredits then
			props.OnAddCredits()
		elseif props.OnClick then
			props.OnClick()
		end
	end

	local function onBalanceChange()
		local targetBalance = resolveBalance()
		if targetBalance == lastBalance then
			return
		end

		local delta = targetBalance - lastBalance
		lastBalance = targetBalance

		local startVal = Fusion.peek(displayedBalance)
		local diff = targetBalance - startVal

		if diff == 0 then
			displayedBalance:set(targetBalance)
			return
		end

		local isPositive = delta > 0

		if isPositive then
			amountScale:set(1.2)
			amountColor:set(Color3.fromRGB(80, 255, 145))
			strokeFlashColor:set(Color3.fromRGB(80, 255, 145))
		else
			amountScale:set(0.92)
			amountColor:set(Color3.fromRGB(255, 95, 95))
			strokeFlashColor:set(Color3.fromRGB(255, 95, 95))
		end
		isFlashingStroke:set(true)

		if flashColorThread then
			task.cancel(flashColorThread)
			flashColorThread = nil
		end
		flashColorThread = task.spawn(function()
			task.wait(0.08)
			amountScale:set(1.0)
			task.wait(0.35)
			amountColor:set(Color3.new(1, 1, 1))
			strokeFlashColor:set(Theme.Border.Default)
			isFlashingStroke:set(false)
			flashColorThread = nil
		end)

		if rollThread then
			task.cancel(rollThread)
			rollThread = nil
		end

		local duration = math.clamp(0.4 + math.log10(math.abs(diff) + 1) * 0.12, 0.45, 0.85)

		rollThread = task.spawn(function()
			local startTime = os.clock()
			local lastTickTime = 0

			while true do
				local elapsed = os.clock() - startTime
				local progress = math.min(elapsed / duration, 1)
				local easedProgress = if progress >= 1 then 1 else 1 - math.pow(2, -10 * progress)
				local currentVal = math.round(startVal + diff * easedProgress)

				displayedBalance:set(currentVal)

				local now = os.clock()
				if progress < 0.9 and (now - lastTickTime) >= 0.055 then
					lastTickTime = now
					playTickSound()
				end

				if progress >= 1 then
					displayedBalance:set(targetBalance)
					if isPositive then
						playChimeSound()
					end
					break
				end

				task.wait()
			end
			rollThread = nil
		end)
	end

	if typeof(props.Balance) == "table" then
		scope:Observer(props.Balance :: any):onChange(onBalanceChange)
	end

	table.insert(scope, function()
		if rollThread then
			task.cancel(rollThread)
			rollThread = nil
		end
		if flashColorThread then
			task.cancel(flashColorThread)
			flashColorThread = nil
		end
	end)

	return scope:New("Frame")({
		Name = "CreditsDisplayContainer",
		Size = UDim2.fromOffset(0, HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = props.Position or UDim2.new(1, -20, 0, 32),
		AnchorPoint = props.AnchorPoint or Vector2.new(1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex or 5,
		Visible = props.Visible,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "CreditsPill",
				Size = UDim2.fromOffset(0, HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
				ZIndex = 2,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),

					scope:New("UIStroke")({
						Color = strokeColor,
						Thickness = 1,
						Transparency = borderTransparency,
					}),

					scope:New("UIGradient")({
						Rotation = 90,
						Transparency = TRANSPARENCY_NUM_SEQ,
					}),

					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 10),
						PaddingRight = UDim.new(0, 8),
					}),

					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					scope:New("ImageLabel")({
						Name = "Icon",
						Size = UDim2.fromOffset(21, 18),
						BackgroundTransparency = 1,
						Image = CREDITS_ICON,
						ScaleType = Enum.ScaleType.Fit,
						LayoutOrder = 1,
						ZIndex = 2,
					}),

					scope:New("TextLabel")({
						Name = "Amount",
						Size = UDim2.fromOffset(0, HEIGHT),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = amountText,
						TextColor3 = amountColorSpring,
						TextSize = Theme.Text.Title - 2,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
						LayoutOrder = 2,
						ZIndex = 2,

						[Fusion.Children] = {
							scope:New("UIScale")({ Scale = amountScaleSpring }),
						},
					}),

					scope:New("TextLabel")({
						Name = "CR",
						Size = UDim2.fromOffset(0, 16),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = "CR",
						TextColor3 = Color3.fromRGB(130, 130, 135),
						TextSize = Theme.Text.Small + 1,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
						LayoutOrder = 3,
						ZIndex = 2,
					}),

					scope:New("Frame")({
						Name = "PlusContainer",
						Size = UDim2.fromOffset(26, 26),
						BackgroundTransparency = 1,
						Visible = props.ShowAddCredits ~= false,
						LayoutOrder = 4,
						ZIndex = 4,

						[Fusion.Children] = {
							scope:New("UIScale")({ Scale = plusScale }),

							scope:New("TextButton")({
								Name = "PlusButton",
								Size = UDim2.fromScale(1, 1),
								BackgroundColor3 = Color3.fromRGB(0, 195, 100),
								BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
									return if use(isPlusHovered) then 0 else 0.15
								end),
								Text = "+",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 18,
								Font = Theme.Text.Black,
								AutoButtonColor = false,
								ZIndex = 5,

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),

									scope:New("UIStroke")({
										Color = Color3.fromRGB(150, 255, 180),
										Thickness = 1,
										Transparency = scope:Computed(function(use: FusionUseFn)
											return if use(isPlusHovered) then 0.1 else 0.4
										end),
									}),
								},

								[Fusion.OnEvent("MouseEnter")] = function()
									isPlusHovered:set(true)
								end,
								[Fusion.OnEvent("MouseLeave")] = function()
									isPlusHovered:set(false)
								end,
								[Fusion.OnEvent("Activated")] = handlePlusClick,
							}),
						},
					}),
				},
			}),

			scope:New("TextButton")({
				Name = "Hitbox",
				Size = UDim2.new(1, -34, 1, 0),
				Position = UDim2.fromScale(0, 0),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 1,

				[Fusion.OnEvent("MouseEnter")] = function()
					isHovered:set(true)
				end,
				[Fusion.OnEvent("MouseLeave")] = function()
					isHovered:set(false)
				end,
				[Fusion.OnEvent("Activated")] = handlePlusClick,
			}),
		},
	})
end

return CreditsDisplay
