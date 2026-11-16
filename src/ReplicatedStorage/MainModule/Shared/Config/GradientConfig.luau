--!strict
--!native
--!optimize 2

local GradientConfig = {}

export type GradientId = string

export type GradientDefinition = {
	id: GradientId,
	colors: ColorSequence,
	speed: number?,
}

GradientConfig.Gradients = {}

function GradientConfig.getGradientById(gradientId: GradientId): GradientDefinition?
	return GradientConfig.Gradients[gradientId]
end

return GradientConfig
