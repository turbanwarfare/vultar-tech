--!strict
--!native
--!optimize 2

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local Constants = require(script.Constants)
local EffectCache = require(script.EffectCache)

local WorldEffects = {}

local originalShaderStates: { [Instance]: boolean } = {}
local originalAtmosphereParent: Instance? = nil
local originalAtmosphere: Atmosphere? = nil
local originalGlobalShadows: boolean = true
local footstepConnections: { [Player]: RBXScriptConnection } = {}
local worldConnections: { RBXScriptConnection } = {}

local footstepsEnabled = true

local function storeShaderStates(): ()
	for _, className in Constants.POST_PROCESSING_CLASSES do
		for _, effect in Lighting:GetChildren() do
			if effect.ClassName == className then
				if originalShaderStates[effect] == nil then
					originalShaderStates[effect] = (effect :: any).Enabled
				end
			end
		end
	end

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere and not originalAtmosphere then
		originalAtmosphere = atmosphere
		originalAtmosphereParent = atmosphere.Parent
	end
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

local function applyMaterialsOff(): ()
	for part, _material in EffectCache.iterateMaterials() do
		if part and part.Parent then
			if not shouldSkipMaterialChange(part) then
				part.Material = Enum.Material.SmoothPlastic
			end
		end
	end
end

local function restoreMaterials(): ()
	for part, material in EffectCache.iterateMaterials() do
		if part and part.Parent then
			part.Material = material
			local originalTrans = EffectCache.getOriginalTransparency(part)
			if originalTrans ~= nil then
				part.Transparency = originalTrans
			end
		end
	end
end

local function applyShadersOff(): ()
	storeShaderStates()
	for _, className in Constants.POST_PROCESSING_CLASSES do
		for _, effect in Lighting:GetChildren() do
			if effect.ClassName == className then
				(effect :: any).Enabled = false
			end
		end
	end

	if originalAtmosphere then
		originalAtmosphere.Parent = nil
	end
end

local function restoreShaders(): ()
	for effect, enabled in originalShaderStates do
		if effect then
			(effect :: any).Enabled = enabled
		end
	end

	if originalAtmosphere and originalAtmosphereParent then
		originalAtmosphere.Parent = originalAtmosphereParent
	end
end

local function applyShadowsOff(): ()
	originalGlobalShadows = Lighting.GlobalShadows
	Lighting.GlobalShadows = false
end

local function restoreShadows(): ()
	Lighting.GlobalShadows = originalGlobalShadows
end

local function muteFootsteps(character: Model): ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local rootPart = humanoid.RootPart
	if rootPart then
		local runningSound = rootPart:FindFirstChild("Running") :: Sound?
		if runningSound and runningSound:IsA("Sound") then
			runningSound.Volume = 0
		end
	end

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Sound") and (descendant.Name == "Running" or descendant.Name == "Footsteps" or descendant.Name == "FootstepSound") then
			descendant.Volume = 0
		end
	end
end

local function unmuteFootsteps(character: Model): ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local rootPart = humanoid.RootPart
	if rootPart then
		local runningSound = rootPart:FindFirstChild("Running") :: Sound?
		if runningSound and runningSound:IsA("Sound") then
			runningSound.Volume = Constants.DEFAULT_FOOTSTEP_VOLUME
		end
	end

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Sound") and (descendant.Name == "Running" or descendant.Name == "Footsteps" or descendant.Name == "FootstepSound") then
			descendant.Volume = Constants.DEFAULT_FOOTSTEP_VOLUME
		end
	end
end

local function setupCharacterFootsteps(player: Player): ()
	if footstepConnections[player] then
		footstepConnections[player]:Disconnect()
	end

	local function onCharacterAdded(character: Model)
		task.wait(0.5)
		if not footstepsEnabled then
			muteFootsteps(character)
		end
	end

	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	footstepConnections[player] = player.CharacterAdded:Connect(onCharacterAdded)
end

local function applyFootstepsOff(): ()
	for _, player in Players:GetPlayers() do
		if player.Character then
			muteFootsteps(player.Character)
		end
	end
end

local function restoreFootsteps(): ()
	for _, player in Players:GetPlayers() do
		if player.Character then
			unmuteFootsteps(player.Character)
		end
	end
end

local function applyParticlesOff(): ()
	for particle in EffectCache.iterateParticles() do
		if particle and particle.Parent then
			if particle:GetAttribute("IgnoreWorldParticles") ~= true then
				(particle :: any).Enabled = false
			end
		end
	end
end

local function restoreParticles(): ()
	for particle in EffectCache.iterateParticles() do
		if particle and particle.Parent then
			(particle :: any).Enabled = true
		end
	end
end

local function applyDecalsOff(): ()
	for decal in EffectCache.iterateDecals() do
		if decal and decal.Parent then
			(decal :: Decal).Transparency = 1
		end
	end
end

local function restoreDecals(): ()
	for decal in EffectCache.iterateDecals() do
		if decal and decal.Parent then
			local originalTransparency = EffectCache.getOriginalDecalTransparency(decal)
			if originalTransparency ~= nil then
				(decal :: Decal).Transparency = originalTransparency
			end
		end
	end
end

local function applyDynamicLightsOff(): ()
	for light in EffectCache.iterateLights() do
		if light and light.Parent then
			(light :: any).Enabled = false
		end
	end
end

local function restoreDynamicLights(): ()
	for light in EffectCache.iterateLights() do
		if light and light.Parent then
			(light :: any).Enabled = true
		end
	end
end

function WorldEffects.setTime(mode: number): ()
	local numMode = tonumber(mode) or 2
	if numMode == 1 then
		Lighting.ClockTime = Constants.DAY_TIME
	else
		Lighting.ClockTime = Constants.NIGHT_TIME
	end
end

function WorldEffects.init(): ()
	originalGlobalShadows = Lighting.GlobalShadows
	storeShaderStates()

	for _, player in Players:GetPlayers() do
		setupCharacterFootsteps(player)
	end

	table.insert(
		worldConnections,
		Players.PlayerAdded:Connect(function(player)
			setupCharacterFootsteps(player)
		end)
	)

	table.insert(
		worldConnections,
		Players.PlayerRemoving:Connect(function(player)
			if footstepConnections[player] then
				footstepConnections[player]:Disconnect()
				footstepConnections[player] = nil
			end
		end)
	)
end

function WorldEffects.setMaterials(enabled: boolean): ()
	EffectCache.updateEffectState("materials", enabled)
	if enabled then
		restoreMaterials()
	else
		applyMaterialsOff()
	end
end

function WorldEffects.setShaders(enabled: boolean): ()
	if enabled then
		restoreShaders()
	else
		applyShadersOff()
	end
end

function WorldEffects.setShadows(enabled: boolean): ()
	if enabled then
		restoreShadows()
	else
		applyShadowsOff()
	end
end

function WorldEffects.setFootsteps(enabled: boolean): ()
	footstepsEnabled = enabled
	if enabled then
		restoreFootsteps()
	else
		applyFootstepsOff()
	end
end

function WorldEffects.setParticles(enabled: boolean): ()
	EffectCache.updateEffectState("particles", enabled)
	if enabled then
		restoreParticles()
	else
		applyParticlesOff()
	end
end

function WorldEffects.setDecals(enabled: boolean): ()
	EffectCache.updateEffectState("decals", enabled)
	if enabled then
		restoreDecals()
	else
		applyDecalsOff()
	end
end

function WorldEffects.setDynamicLights(enabled: boolean): ()
	EffectCache.updateEffectState("dynamicLights", enabled)
	if enabled then
		restoreDynamicLights()
	else
		applyDynamicLightsOff()
	end
end

function WorldEffects.applySetting(key: string, value: any): ()
	if key == "Materials" then
		WorldEffects.setMaterials(value == true)
	elseif key == "Shaders" then
		WorldEffects.setShaders(value == true)
	elseif key == "Shadows" then
		WorldEffects.setShadows(value == true)
	elseif key == "CharacterFootsteps" then
		WorldEffects.setFootsteps(value == true)
	elseif key == "Particles" then
		WorldEffects.setParticles(value == true)
	elseif key == "Decals" then
		WorldEffects.setDecals(value == true)
	elseif key == "DynamicLights" then
		WorldEffects.setDynamicLights(value == true)
	elseif key == "Time" then
		WorldEffects.setTime(value :: number)
	end
end

function WorldEffects.applyAll(settings: { [string]: any }): ()
	if settings.Materials ~= nil then
		WorldEffects.setMaterials(settings.Materials == true)
	end
	if settings.Shaders ~= nil then
		WorldEffects.setShaders(settings.Shaders == true)
	end
	if settings.Shadows ~= nil then
		WorldEffects.setShadows(settings.Shadows == true)
	end
	if settings.CharacterFootsteps ~= nil then
		WorldEffects.setFootsteps(settings.CharacterFootsteps == true)
	end
	if settings.Particles ~= nil then
		WorldEffects.setParticles(settings.Particles == true)
	end
	if settings.Decals ~= nil then
		WorldEffects.setDecals(settings.Decals == true)
	end
	if settings.DynamicLights ~= nil then
		WorldEffects.setDynamicLights(settings.DynamicLights == true)
	end
	if settings.Time ~= nil then
		WorldEffects.setTime(settings.Time)
	end
end

function WorldEffects.cleanup(): ()
	EffectCache.cleanup()

	for _, conn in worldConnections do
		conn:Disconnect()
	end
	table.clear(worldConnections)

	for player, connection in footstepConnections do
		connection:Disconnect()
		footstepConnections[player] = nil
	end

	table.clear(originalShaderStates)
	originalAtmosphere = nil
	originalAtmosphereParent = nil
end

return WorldEffects
