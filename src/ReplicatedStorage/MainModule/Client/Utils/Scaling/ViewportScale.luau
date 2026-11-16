--!strict
--!native
--!optimize 2

local Scale = require(script.Parent.Scale)

local ViewportScale = {}

ViewportScale.THRESHOLD_1440P = Scale.Constants.BREAKPOINT_HIGH
ViewportScale.SCALE_1080P = Scale.Constants.SCALE_MID
ViewportScale.MAX_SCALE = Scale.Constants.SCALE_MAX

function ViewportScale.get(): number
	return Scale.raw()
end

function ViewportScale.getValue(): any
	return Scale.get()
end

function ViewportScale.createScopedValue(scope: any): any
	return Scale.scoped(scope)
end

return ViewportScale
