--!strict
--!native
--!optimize 2

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local UISound = {}

local SOUNDS = {
	Swipe = "rbxassetid://0",
	Background = "rbxassetid://88816395307065",
	CrateMusic = "rbxassetid://74369589608673",
}

local BACKGROUND_VOLUME = 0.25
local CRATE_MUSIC_VOLUME = 0.38
local CRATE_MUSIC_DUCKED_VOLUME = 0.05
local FADE_DURATION = 0.5
local DUCK_DURATION = 0.35

local FADE_TWEEN_INFO = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DUCK_TWEEN_INFO = TweenInfo.new(DUCK_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local soundInstances: { [string]: Sound } = {}
local activeTweens: { [string]: Tween } = {}
local isBackgroundFadedIn = false
local isCrateTabActive = false
local isCrateOpeningActive = false

local function cancelTween(key: string)
	if activeTweens[key] then
		activeTweens[key]:Cancel()
		activeTweens[key] = nil
	end
end

local function tweenSoundVolume(name: string, targetVolume: number, tweenInfo: TweenInfo)
	local sound = soundInstances[name]
	if not sound then return end

	cancelTween(name)

	if targetVolume > 0 and not sound.IsPlaying then
		sound:Play()
	end

	local tween = TweenService:Create(sound, tweenInfo, { Volume = targetVolume })
	activeTweens[name] = tween
	tween:Play()

	if targetVolume == 0 then
		tween.Completed:Once(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed and sound.Volume == 0 then
				sound:Stop()
			end
		end)
	end
end

function UISound.init(): ()
	isBackgroundFadedIn = false
	isCrateTabActive = false
	isCrateOpeningActive = false

	for name, soundId in SOUNDS do
		local sound = Instance.new("Sound")
		sound.Name = "UI_" .. name
		sound.SoundId = soundId
		sound.Looped = (name == "Background" or name == "CrateMusic")
		sound.Volume = if sound.Looped then 0 else 0.5
		sound.Parent = SoundService
		soundInstances[name] = sound
	end
end

function UISound.play(name: string): ()
	local sound = soundInstances[name]
	if sound then
		sound:Play()
	end
end

function UISound.fadeInBackground(): ()
	isBackgroundFadedIn = true

	if isCrateTabActive then
		tweenSoundVolume("Background", 0, FADE_TWEEN_INFO)
		local targetVol = if isCrateOpeningActive then CRATE_MUSIC_DUCKED_VOLUME else CRATE_MUSIC_VOLUME
		tweenSoundVolume("CrateMusic", targetVol, FADE_TWEEN_INFO)
	else
		tweenSoundVolume("CrateMusic", 0, FADE_TWEEN_INFO)
		tweenSoundVolume("Background", BACKGROUND_VOLUME, FADE_TWEEN_INFO)
	end
end

function UISound.fadeOutBackground(): ()
	isBackgroundFadedIn = false
	tweenSoundVolume("Background", 0, FADE_TWEEN_INFO)
	tweenSoundVolume("CrateMusic", 0, FADE_TWEEN_INFO)
end

function UISound.setCrateTabActive(active: boolean): ()
	if isCrateTabActive == active then return end
	isCrateTabActive = active

	if not isBackgroundFadedIn then
		tweenSoundVolume("Background", 0, FADE_TWEEN_INFO)
		tweenSoundVolume("CrateMusic", 0, FADE_TWEEN_INFO)
		return
	end

	if active then
		tweenSoundVolume("Background", 0, FADE_TWEEN_INFO)
		local targetVol = if isCrateOpeningActive then CRATE_MUSIC_DUCKED_VOLUME else CRATE_MUSIC_VOLUME
		tweenSoundVolume("CrateMusic", targetVol, FADE_TWEEN_INFO)
	else
		tweenSoundVolume("CrateMusic", 0, FADE_TWEEN_INFO)
		tweenSoundVolume("Background", BACKGROUND_VOLUME, FADE_TWEEN_INFO)
	end
end

function UISound.setCrateOpeningActive(active: boolean): ()
	if isCrateOpeningActive == active then return end
	isCrateOpeningActive = active

	if not isBackgroundFadedIn or not isCrateTabActive then return end

	local targetVolume = if active then CRATE_MUSIC_DUCKED_VOLUME else CRATE_MUSIC_VOLUME
	tweenSoundVolume("CrateMusic", targetVolume, DUCK_TWEEN_INFO)
end

function UISound.cleanup(): ()
	for key in activeTweens do
		cancelTween(key)
	end
	table.clear(activeTweens)

	isBackgroundFadedIn = false
	isCrateTabActive = false
	isCrateOpeningActive = false

	for _, sound in soundInstances do
		sound:Destroy()
	end
	table.clear(soundInstances)
end

return UISound
