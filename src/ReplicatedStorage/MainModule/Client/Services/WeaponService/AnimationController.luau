--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local GunStats = require(MainModule.Shared.Config.GunStats)
local WeaponConfig = require(MainModule.Shared.Config.Weapons.WeaponConfig)

local AnimationController = {}

local DEFAULT_FADE_TIME = WeaponConfig.AnimationFadeTime
AnimationController.FireFadeTime = 0.04
AnimationController.SprintFireFadeTime = 0.13
AnimationController.SprintToFireFadeTime = 0.22

local animator: Animator? = nil
local loadedAnimations: { [string]: AnimationTrack } = {}
local trackCache: { [string]: AnimationTrack } = {}

local LOOPED_TRACKS: { [string]: boolean } = {
	Idle = true,
	Sprint = true,
	Crouch = true,
}

local function usesClassAnimationSet(toolName: string): boolean
	local stats = GunStats.get(toolName)
	if not stats or not stats.Animations or not stats.Animations.Idle then
		return true
	end
	local config = WeaponConfig.getToolConfig(toolName)
	if not config then
		return true
	end
	return ("rbxassetid://" .. tostring(stats.Animations.Idle)) == config.Animations.Idle
end

local function getPriority(name: string): Enum.AnimationPriority
	if name == "Fire" then
		return Enum.AnimationPriority.Action4
	end
	return Enum.AnimationPriority.Action
end

local function configureTrack(track: AnimationTrack, name: string): AnimationTrack
	track.Looped = LOOPED_TRACKS[name] == true
	track.Priority = getPriority(name)
	return track
end

local function getOrCreateTrack(assetId: string, name: string): AnimationTrack?
	if not animator then
		return nil
	end

	local cached = trackCache[assetId]
	if cached then
		return configureTrack(cached, name)
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = assetId
	local track = animator:LoadAnimation(animation)
	animation:Destroy()

	trackCache[assetId] = configureTrack(track, name)
	return track
end

local function addTrack(name: string, assetId: string): ()
	local track = getOrCreateTrack(assetId, name)
	if track then
		loadedAnimations[name] = track
	end
end

function AnimationController.setAnimator(newAnimator: Animator?): ()
	if animator == newAnimator then
		return
	end

	AnimationController.clearTrackCache()
	animator = newAnimator
end

function AnimationController.clearTrackCache(): ()
	for _, track in trackCache do
		track:Stop(0)
		track:Destroy()
	end
	table.clear(trackCache)
	table.clear(loadedAnimations)
end

function AnimationController.warmTrackCache(): ()
	if not animator then
		return
	end

	for _, classConfig in WeaponConfig.Classes do
		for name, id in classConfig.Animations do
			getOrCreateTrack(id, name)
		end
	end

	for _, stats in GunStats.Guns do
		if not stats.Animations then
			continue
		end
		for name, numId in stats.Animations do
			getOrCreateTrack("rbxassetid://" .. tostring(numId), name)
		end
	end
end

function AnimationController.loadAnimations(tool: Tool): ()
	AnimationController.stopAll(0)
	table.clear(loadedAnimations)

	local stats = GunStats.get(tool.Name)
	local config = WeaponConfig.getToolConfig(tool.Name)

	if usesClassAnimationSet(tool.Name) then
		if config then
			for name, id in config.Animations do
				addTrack(name, id)
			end
		end
		if stats and stats.Animations and stats.Animations.Fire then
			addTrack("Fire", "rbxassetid://" .. tostring(stats.Animations.Fire))
		end
		return
	end

	if stats and stats.Animations then
		for name, id in stats.Animations do
			addTrack(name, "rbxassetid://" .. tostring(id))
		end
	end

	if config then
		for name, id in config.Animations do
			if loadedAnimations[name] then
				continue
			end
			addTrack(name, id)
		end
	end
end

function AnimationController.unloadAnimations(fadeTime: number?): ()
	AnimationController.stopAll(fadeTime or DEFAULT_FADE_TIME)
	table.clear(loadedAnimations)
end

function AnimationController.play(name: string, fadeTime: number?, weight: number?, speed: number?): ()
	local track = loadedAnimations[name]
	if not track then
		return
	end

	local resolvedFadeTime = if fadeTime ~= nil then fadeTime else DEFAULT_FADE_TIME
	local resolvedWeight = weight or 1
	local resolvedSpeed = speed or 1

	if name == "Fire" and track.IsPlaying then
		track:Stop(0)
	elseif track.IsPlaying then
		track:AdjustWeight(resolvedWeight, resolvedFadeTime)
		track:AdjustSpeed(resolvedSpeed)
		return
	end

	track:Play(resolvedFadeTime, resolvedWeight, resolvedSpeed)
end

function AnimationController.stop(name: string, fadeTime: number?): ()
	local track = loadedAnimations[name]
	if track and track.IsPlaying then
		track:Stop(if fadeTime ~= nil then fadeTime else DEFAULT_FADE_TIME)
	end
end

function AnimationController.stopAll(fadeTime: number?): ()
	local resolvedFadeTime = if fadeTime ~= nil then fadeTime else DEFAULT_FADE_TIME
	for _, track in loadedAnimations do
		if track.IsPlaying then
			track:Stop(resolvedFadeTime)
		end
	end
end

function AnimationController.applyAnimationChanges(playNames: { string }, stopNames: { string }, fadeTime: number?): ()
	for _, name in stopNames do
		AnimationController.stop(name, fadeTime)
	end
	for _, name in playNames do
		AnimationController.play(name, fadeTime)
	end
end

function AnimationController.adjustCrouchSpeed(isRunning: boolean): ()
	local track = loadedAnimations["Crouch"]
	if track and track.IsPlaying then
		track:AdjustSpeed(if isRunning then 1 else 0)
	end
end

function AnimationController.getCrouchTrack(): AnimationTrack?
	return loadedAnimations["Crouch"]
end

function AnimationController.getTrack(name: string): AnimationTrack?
	return loadedAnimations[name]
end

return AnimationController
