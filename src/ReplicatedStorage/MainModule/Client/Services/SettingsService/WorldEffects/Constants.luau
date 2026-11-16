--!strict
--!native
--!optimize 2


local Constants = {}

Constants.POST_PROCESSING_CLASSES = {
	"BloomEffect",
	"BlurEffect",
	"ColorCorrectionEffect",
	"DepthOfFieldEffect",
	"SunRaysEffect",
}

Constants.PARTICLE_CLASSES = {
	"ParticleEmitter",
	"Fire",
	"Smoke",
	"Sparkles",
	"Trail",
}

Constants.LIGHT_CLASSES = {
	"PointLight",
	"SpotLight",
	"SurfaceLight",
}

local PARTICLE_CLASS_SET: { [string]: boolean } = {}
for _, className in Constants.PARTICLE_CLASSES do
	PARTICLE_CLASS_SET[className] = true
end

local LIGHT_CLASS_SET: { [string]: boolean } = {}
for _, className in Constants.LIGHT_CLASSES do
	LIGHT_CLASS_SET[className] = true
end

Constants.BATCH_SIZE = 100
Constants.YIELD_THRESHOLD = 0.004

Constants.DAY_TIME = 14
Constants.NIGHT_TIME = 0

Constants.DEFAULT_FOOTSTEP_VOLUME = 0.65

function Constants.isParticleClass(className: string): boolean
	return PARTICLE_CLASS_SET[className] == true
end

function Constants.isLightClass(className: string): boolean
	return LIGHT_CLASS_SET[className] == true
end

return Constants
