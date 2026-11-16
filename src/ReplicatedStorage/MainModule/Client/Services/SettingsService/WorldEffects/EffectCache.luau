--!strict
--!native
--!optimize 2

local Constants = require(script.Parent.Constants)

export type EffectState = {
	materialsEnabled: boolean,
	particlesEnabled: boolean,
	decalsEnabled: boolean,
	dynamicLightsEnabled: boolean,
}

local EffectCache = {}

local originalMaterials: { [BasePart]: Enum.Material } = {}
local originalTransparency: { [BasePart]: number } = {}
local originalDecalTransparency: { [Instance]: number } = {}
local cachedParticles: { [Instance]: boolean } = {}
local cachedLights: { [Instance]: boolean } = {}
local cachedDecals: { [Instance]: boolean } = {}

local descendantAddedConnection: RBXScriptConnection? = nil
local descendantRemovingConnection: RBXScriptConnection? = nil

local effectState: EffectState = {
	materialsEnabled = true,
	particlesEnabled = true,
	decalsEnabled = true,
	dynamicLightsEnabled = true,
}

local function isValidPart(part: BasePart): boolean
	if part:IsA("Terrain") then
		return false
	end
	if part.Name == "Baseplate" then
		return false
	end
	return true
end

local function isDescendantOfTool(instance: Instance): boolean
	local current = instance.Parent
	while current do
		if current:IsA("Tool") or current:IsA("BackpackItem") then
			return true
		end
		current = current.Parent
	end
	return false
end

local function ignoresWorldParticleSetting(instance: Instance): boolean
	local current: Instance? = instance
	while current do
		if current:GetAttribute("IgnoreWorldParticles") == true then
			return true
		end
		current = current.Parent
	end
	return false
end

local TRANSPARENT_MATERIALS = {
	[Enum.Material.Glass] = true,
	[Enum.Material.ForceField] = true,
	[Enum.Material.Neon] = true,
}

local function shouldSkipMaterialChange(part: BasePart): boolean
	if part.Transparency > 0 then
		return true
	end
	if TRANSPARENT_MATERIALS[part.Material] then
		return true
	end
	return false
end

function EffectCache.storeMaterial(part: BasePart): ()
	if originalMaterials[part] == nil then
		originalMaterials[part] = part.Material
		originalTransparency[part] = part.Transparency
	end
end

function EffectCache.getOriginalMaterial(part: BasePart): Enum.Material?
	return originalMaterials[part]
end

function EffectCache.getOriginalTransparency(part: BasePart): number?
	return originalTransparency[part]
end

function EffectCache.iterateMaterials(): { [BasePart]: Enum.Material }
	return originalMaterials
end

function EffectCache.iterateParticles(): { [Instance]: boolean }
	return cachedParticles
end

function EffectCache.iterateLights(): { [Instance]: boolean }
	return cachedLights
end

function EffectCache.iterateDecals(): { [Instance]: boolean }
	return cachedDecals
end

function EffectCache.getOriginalDecalTransparency(decal: Instance): number?
	return originalDecalTransparency[decal]
end

function EffectCache.setEffectState(state: EffectState): ()
	effectState = state
end

function EffectCache.updateEffectState(key: string, value: boolean): ()
	if key == "materials" then
		effectState.materialsEnabled = value
	elseif key == "particles" then
		effectState.particlesEnabled = value
	elseif key == "decals" then
		effectState.decalsEnabled = value
	elseif key == "dynamicLights" then
		effectState.dynamicLightsEnabled = value
	end
	if not value then
		EffectCache.init()
	end
end

function EffectCache.init(): ()
	if descendantAddedConnection then
		return
	end
	task.spawn(function()
		local descendants = workspace:GetDescendants()
		local startTime = os.clock()
		local processed = 0

		for _, descendant in descendants do
			if descendant:IsA("BasePart") and isValidPart(descendant) then
				EffectCache.storeMaterial(descendant)
				if not effectState.materialsEnabled and not shouldSkipMaterialChange(descendant) then
					descendant.Material = Enum.Material.SmoothPlastic
				end
			elseif Constants.isParticleClass(descendant.ClassName) then
				if not isDescendantOfTool(descendant) and not ignoresWorldParticleSetting(descendant) then
					cachedParticles[descendant] = true
					if not effectState.particlesEnabled then
						(descendant :: any).Enabled = false
					end
				end
			elseif Constants.isLightClass(descendant.ClassName) then
				if not isDescendantOfTool(descendant) then
					cachedLights[descendant] = true
					if not effectState.dynamicLightsEnabled then
						(descendant :: any).Enabled = false
					end
				end
			elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
				local decal = descendant :: Decal
				cachedDecals[descendant] = true
				if originalDecalTransparency[descendant] == nil then
					originalDecalTransparency[descendant] = decal.Transparency
				end
				if not effectState.decalsEnabled then
					decal.Transparency = 1
				end
			end

			processed += 1
			if processed % Constants.BATCH_SIZE == 0 then
				local elapsed = os.clock() - startTime
				if elapsed > Constants.YIELD_THRESHOLD then
					task.wait()
					startTime = os.clock()
				end
			end
		end
	end)

	descendantAddedConnection = workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") and isValidPart(descendant) then
			EffectCache.storeMaterial(descendant)
			if not effectState.materialsEnabled and not shouldSkipMaterialChange(descendant) then
				descendant.Material = Enum.Material.SmoothPlastic
			end
		elseif Constants.isParticleClass(descendant.ClassName) then
			if not isDescendantOfTool(descendant) and not ignoresWorldParticleSetting(descendant) then
				cachedParticles[descendant] = true
				if not effectState.particlesEnabled then
					(descendant :: any).Enabled = false
				end
			else
				cachedParticles[descendant] = nil
			end
		elseif Constants.isLightClass(descendant.ClassName) then
			if not isDescendantOfTool(descendant) then
				cachedLights[descendant] = true
				if not effectState.dynamicLightsEnabled then
					(descendant :: any).Enabled = false
				end
			end
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			local decal = descendant :: Decal
			cachedDecals[descendant] = true
			if originalDecalTransparency[descendant] == nil then
				originalDecalTransparency[descendant] = decal.Transparency
			end
			if not effectState.decalsEnabled then
				decal.Transparency = 1
			end
		end
	end)

	descendantRemovingConnection = workspace.DescendantRemoving:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			originalMaterials[descendant] = nil
			originalTransparency[descendant] = nil
		elseif Constants.isParticleClass(descendant.ClassName) then
			cachedParticles[descendant] = nil
		elseif Constants.isLightClass(descendant.ClassName) then
			cachedLights[descendant] = nil
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			cachedDecals[descendant] = nil
			originalDecalTransparency[descendant] = nil
		end
	end)
end

function EffectCache.cleanup(): ()
	if descendantAddedConnection then
		descendantAddedConnection:Disconnect()
		descendantAddedConnection = nil
	end

	if descendantRemovingConnection then
		descendantRemovingConnection:Disconnect()
		descendantRemovingConnection = nil
	end

	table.clear(originalMaterials)
	table.clear(originalTransparency)
	table.clear(originalDecalTransparency)
	table.clear(cachedParticles)
	table.clear(cachedLights)
	table.clear(cachedDecals)
end

return EffectCache
