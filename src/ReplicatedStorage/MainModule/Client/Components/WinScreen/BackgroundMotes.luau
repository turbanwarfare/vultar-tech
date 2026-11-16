--!native
--!optimize 2

local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)

type FusionScope = Types.FusionScope

local MOTE_COUNT = 22
local SOFT_MOTE_COUNT = 5
local MOTE_START = 0.03
local MOTE_RISE = 0.9
local MOTE_DRIFT = 80
local MOTE_SWAY = 18
local MOTE_FADE_IN = 0.12
local MOTE_FADE_OUT = 0.85

local WARM_COLORS = {
	Color3.fromRGB(255, 205, 90),
	Color3.fromRGB(255, 135, 50),
	Color3.fromRGB(255, 80, 60),
	Color3.fromRGB(255, 230, 190),
}
local SOFT_COLOR = Color3.fromRGB(255, 150, 90)

export type BackgroundMotesProps = {
	Fade: any,
}

type MoteDot = {
	frame: Frame,
	opacity: number,
}

type Mote = {
	holder: Frame,
	x: number,
	duration: number,
	offset: number,
	sway: number,
	twinkle: number,
	dots: { MoteDot },
}

local function getTwinkle(phase: number): number
	if phase < 0.45 then
		return 1 - 0.65 * (phase / 0.45)
	elseif phase < 0.55 then
		return 0.35 + 0.65 * ((phase - 0.45) / 0.1)
	elseif phase < 0.75 then
		return 1 - 0.4 * ((phase - 0.55) / 0.2)
	end
	return 0.6 + 0.4 * ((phase - 0.75) / 0.25)
end

local function createDot(scope: FusionScope, name: string, size: UDim2, color: Color3, baseTransparency: number, zIndex: number): MoteDot
	return {
		frame = scope:New("Frame")({
			Name = name,
			Size = size,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = 1,
			ZIndex = zIndex,

			[Fusion.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			},
		}),
		opacity = 1 - baseTransparency,
	}
end

local function createMote(scope: FusionScope, name: string, size: number, mote: Mote, dots: { MoteDot }): Frame
	local dotFrames: { Frame } = {}
	for _, dot in dots do
		table.insert(dotFrames, dot.frame)
	end

	mote.dots = dots
	mote.holder = scope:New("Frame")({
		Name = name,
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromScale(mote.x, 1.05),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,

		[Fusion.Children] = dotFrames,
	})
	return mote.holder
end

local function BackgroundMotes(scope: FusionScope, props: BackgroundMotesProps): Frame
	local random = Random.new(23)
	local motes: { Mote } = {}
	local holders: { Frame } = {}

	for index = 1, MOTE_COUNT do
		local size = random:NextInteger(3, 6)
		local color = WARM_COLORS[random:NextInteger(1, #WARM_COLORS)]
		local mote: Mote = {
			holder = nil :: any,
			x = random:NextNumber(0.02, 0.98),
			duration = random:NextNumber(9, 15),
			offset = random:NextNumber(0, 15),
			sway = random:NextNumber(5, 9),
			twinkle = random:NextNumber(2.5, 5),
			dots = {},
		}
		table.insert(
			holders,
			createMote(scope, `Mote{index}`, size, mote, {
				createDot(scope, "Glow", UDim2.fromOffset(size + 8, size + 8), color, 0.7, 1),
				createDot(scope, "Core", UDim2.fromScale(1, 1), color, 0.1, 2),
			})
		)
		table.insert(motes, mote)
	end

	for index = 1, SOFT_MOTE_COUNT do
		local size = random:NextInteger(30, 60)
		local mote: Mote = {
			holder = nil :: any,
			x = random:NextNumber(0.05, 0.95),
			duration = random:NextNumber(18, 26),
			offset = random:NextNumber(0, 26),
			sway = random:NextNumber(8, 12),
			twinkle = random:NextNumber(6, 9),
			dots = {},
		}
		table.insert(
			holders,
			createMote(scope, `SoftMote{index}`, size, mote, {
				createDot(scope, "Outer", UDim2.fromScale(0.8, 0.8), SOFT_COLOR, 0.9, 1),
				createDot(scope, "Inner", UDim2.fromScale(0.4, 0.4), SOFT_COLOR, 0.82, 2),
			})
		)
		table.insert(motes, mote)
	end

	local startTime = os.clock()

	local function updateMotes(): ()
		local now = os.clock() - startTime
		local visibility = 1 - Fusion.peek(props.Fade)
		for _, mote in motes do
			local elapsed = now + mote.offset
			local rise = (elapsed % mote.duration) / mote.duration
			local envelope = if rise < MOTE_FADE_IN
				then rise / MOTE_FADE_IN
				elseif rise > MOTE_FADE_OUT then (1 - rise) / (1 - MOTE_FADE_OUT)
				else 1
			local opacity = envelope * getTwinkle((elapsed % mote.twinkle) / mote.twinkle) * visibility
			local sway = -MOTE_SWAY * math.cos(2 * math.pi * now / mote.sway)

			mote.holder.Position = UDim2.new(mote.x, sway - MOTE_DRIFT * rise, 1 + MOTE_START - MOTE_RISE * rise, 0)
			for _, dot in mote.dots do
				dot.frame.BackgroundTransparency = 1 - dot.opacity * opacity
			end
		end
	end

	local connection = RunService.Heartbeat:Connect(updateMotes)
	table.insert(scope, function()
		connection:Disconnect()
	end)

	return scope:New("Frame")({
		Name = "Motes",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,

		[Fusion.Children] = holders,
	})
end

return BackgroundMotes
