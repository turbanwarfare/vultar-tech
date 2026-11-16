--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))

export type ScaledValue = any
export type ScaledUDim2 = any
export type ScaledUDim = any

local HEIGHT_BREAKPOINT_HIGH = 1080
local HEIGHT_BREAKPOINT_MID = 800
local HEIGHT_BREAKPOINT_LOW = 600

local WIDTH_BREAKPOINT_HIGH = 1920
local WIDTH_BREAKPOINT_MID = 1400
local WIDTH_BREAKPOINT_LOW = 1000

local SCALE_MAX = 1.0
local SCALE_MID = 0.85
local SCALE_MIN = 0.75

local TEXT_PRESETS = {
	Tiny = 10,
	Small = 12,
	Medium = 14,
	Default = 16,
	Large = 18,
	XLarge = 22,
	XXLarge = 28,
	Header = 32,
	Title = 40,
	Display = 56,
}

local SPACING_PRESETS = {
	None = 0,
	Tiny = 2,
	Small = 4,
	Medium = 8,
	Default = 12,
	Large = 16,
	XLarge = 24,
	XXLarge = 32,
	Huge = 48,
}

local PADDING_PRESETS = {
	None = 0,
	Tiny = 2,
	Small = 4,
	Medium = 8,
	Default = 12,
	Large = 16,
	XLarge = 24,
	XXLarge = 32,
	Huge = 48,
}

local CORNER_PRESETS = {
	None = 0,
	Small = 4,
	Medium = 8,
	Default = 12,
	Large = 16,
	XLarge = 24,
	Full = 9999,
}

local STROKE_PRESETS = {
	Thin = 1,
	Default = 2,
	Medium = 3,
	Thick = 4,
}

local camera = workspace.CurrentCamera

local scaleValue: any = nil
local connection: RBXScriptConnection? = nil
local initialized = false

local pxCache: { [number]: ScaledValue } = {}
local textCache: { [string]: ScaledValue } = {}
local spacingCache: { [string]: ScaledValue } = {}
local paddingCache: { [string]: ScaledValue } = {}
local cornerCache: { [string]: ScaledValue } = {}
local strokeCache: { [string]: ScaledValue } = {}
local offsetCache: { [string]: ScaledUDim2 } = {}
local udimCache: { [string]: ScaledUDim } = {}

local function calculateScaleFromDimension(value: number, high: number, mid: number, low: number): number
	if value >= high then
		return SCALE_MAX
	elseif value >= mid then
		local t = (value - mid) / (high - mid)
		return SCALE_MID + t * (SCALE_MAX - SCALE_MID)
	elseif value >= low then
		local t = (value - low) / (mid - low)
		return SCALE_MIN + t * (SCALE_MID - SCALE_MIN)
	else
		return SCALE_MIN
	end
end

local function calculateScale(): number
	if not camera then
		return SCALE_MAX
	end

	local viewportSize = camera.ViewportSize
	local heightScale = calculateScaleFromDimension(
		viewportSize.Y,
		HEIGHT_BREAKPOINT_HIGH,
		HEIGHT_BREAKPOINT_MID,
		HEIGHT_BREAKPOINT_LOW
	)
	local widthScale = calculateScaleFromDimension(
		viewportSize.X,
		WIDTH_BREAKPOINT_HIGH,
		WIDTH_BREAKPOINT_MID,
		WIDTH_BREAKPOINT_LOW
	)

	return math.min(heightScale, widthScale)
end

local moduleScope: any = nil

local function ensureInitialized()
	if initialized then
		return
	end
	initialized = true

	moduleScope = Fusion.scoped(Fusion)
	scaleValue = moduleScope:Value(calculateScale())

	if camera then
		connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if scaleValue then
				scaleValue:set(calculateScale())
			end
		end)
	end

	for name, baseSize in TEXT_PRESETS do
		textCache[name] = moduleScope:Computed(function(use)
			return math.round(use(scaleValue :: any) * baseSize)
		end)
	end

	for name, baseSize in SPACING_PRESETS do
		spacingCache[name] = moduleScope:Computed(function(use)
			return math.round(use(scaleValue :: any) * baseSize)
		end)
	end

	for name, baseSize in PADDING_PRESETS do
		paddingCache[name] = moduleScope:Computed(function(use)
			return math.round(use(scaleValue :: any) * baseSize)
		end)
	end

	for name, baseSize in CORNER_PRESETS do
		if baseSize == 9999 then
			cornerCache[name] = moduleScope:Computed(function()
				return 9999
			end)
		else
			cornerCache[name] = moduleScope:Computed(function(use)
				return math.round(use(scaleValue :: any) * baseSize)
			end)
		end
	end

	for name, baseSize in STROKE_PRESETS do
		strokeCache[name] = moduleScope:Computed(function(use)
			return math.max(1, math.round(use(scaleValue :: any) * baseSize))
		end)
	end
end

local Scale = {}

function Scale.px(baseSize: number): ScaledValue
	ensureInitialized()

	if not pxCache[baseSize] then
		pxCache[baseSize] = moduleScope:Computed(function(use)
			return math.round(use(scaleValue :: any) * baseSize)
		end)
	end

	return pxCache[baseSize]
end

function Scale.offset(x: number, y: number): ScaledUDim2
	ensureInitialized()

	local key = x .. "," .. y
	if not offsetCache[key] then
		offsetCache[key] = moduleScope:Computed(function(use)
			local scale = use(scaleValue :: any)
			return UDim2.fromOffset(math.round(x * scale), math.round(y * scale))
		end)
	end

	return offsetCache[key]
end

function Scale.udim(s: number, offsetPx: number): ScaledUDim
	ensureInitialized()

	local key = s .. "," .. offsetPx
	if not udimCache[key] then
		udimCache[key] = moduleScope:Computed(function(use)
			local scale = use(scaleValue :: any)
			return UDim.new(s, math.round(offsetPx * scale))
		end)
	end

	return udimCache[key]
end

function Scale.get(): any
	ensureInitialized()
	return scaleValue
end

function Scale.raw(): number
	ensureInitialized()
	return Fusion.peek(scaleValue)
end

function Scale.now(baseSize: number): number
	ensureInitialized()
	return math.round(Fusion.peek(scaleValue) * baseSize)
end

Scale.Text = setmetatable({} :: { [string | number]: ScaledValue }, {
	__index = function(_, key: string | number): ScaledValue?
		ensureInitialized()
		if type(key) == "number" then
			return Scale.px(key)
		elseif type(key) == "string" then
			return textCache[key]
		end
		return nil
	end,
})

Scale.Spacing = setmetatable({} :: { [string | number]: ScaledValue }, {
	__index = function(_, key: string | number): ScaledValue?
		ensureInitialized()
		if type(key) == "number" then
			return Scale.px(key)
		elseif type(key) == "string" then
			return spacingCache[key]
		end
		return nil
	end,
})

Scale.Padding = setmetatable({} :: { [string | number]: ScaledValue }, {
	__index = function(_, key: string | number): ScaledValue?
		ensureInitialized()
		if type(key) == "number" then
			return Scale.px(key)
		elseif type(key) == "string" then
			return paddingCache[key]
		end
		return nil
	end,
})

Scale.Corner = setmetatable({} :: { [string | number]: ScaledValue }, {
	__index = function(_, key: string | number): ScaledValue?
		ensureInitialized()
		if type(key) == "number" then
			return Scale.px(key)
		elseif type(key) == "string" then
			return cornerCache[key]
		end
		return nil
	end,
})

Scale.Stroke = setmetatable({} :: { [string | number]: ScaledValue }, {
	__index = function(_, key: string | number): ScaledValue?
		ensureInitialized()
		if type(key) == "number" then
			if not pxCache[-key] then
				pxCache[-key] = moduleScope:Computed(function(use)
					return math.max(1, math.round(use(scaleValue :: any) * key))
				end)
			end
			return pxCache[-key]
		elseif type(key) == "string" then
			return strokeCache[key]
		end
		return nil
	end,
})

function Scale.scoped(scope: any): any
	ensureInitialized()

	local scopedValue = scope:Value(calculateScale())

	if camera then
		local scopedConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			scopedValue:set(calculateScale())
		end)
		table.insert(scope, function()
			scopedConnection:Disconnect()
		end)
	end

	return scopedValue
end

function Scale.cleanup()
	if connection then
		connection:Disconnect()
		connection = nil
	end

	if moduleScope then
		Fusion.doCleanup(moduleScope)
		moduleScope = nil
	end

	table.clear(pxCache)
	table.clear(textCache)
	table.clear(spacingCache)
	table.clear(paddingCache)
	table.clear(cornerCache)
	table.clear(strokeCache)
	table.clear(offsetCache)
	table.clear(udimCache)

	scaleValue = nil
	initialized = false
end

Scale.Presets = {
	Text = TEXT_PRESETS,
	Spacing = SPACING_PRESETS,
	Padding = PADDING_PRESETS,
	Corner = CORNER_PRESETS,
	Stroke = STROKE_PRESETS,
}

Scale.Constants = {
	HEIGHT_BREAKPOINT_HIGH = HEIGHT_BREAKPOINT_HIGH,
	HEIGHT_BREAKPOINT_MID = HEIGHT_BREAKPOINT_MID,
	HEIGHT_BREAKPOINT_LOW = HEIGHT_BREAKPOINT_LOW,
	WIDTH_BREAKPOINT_HIGH = WIDTH_BREAKPOINT_HIGH,
	WIDTH_BREAKPOINT_MID = WIDTH_BREAKPOINT_MID,
	WIDTH_BREAKPOINT_LOW = WIDTH_BREAKPOINT_LOW,
	SCALE_MAX = SCALE_MAX,
	SCALE_MID = SCALE_MID,
	SCALE_MIN = SCALE_MIN,
}

return Scale
