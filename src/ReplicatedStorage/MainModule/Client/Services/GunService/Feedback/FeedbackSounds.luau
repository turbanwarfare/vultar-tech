--!strict
--!native
--!optimize 2

local SoundService = game:GetService("SoundService")

local Constants = require(script.Parent.Parent.Constants)
local Cache = require(script.Parent.Parent.Cache)

local FeedbackSounds = {}

local hitSounds: { Sound } = {}
local headshotSound: Sound? = nil
local killSound: Sound? = nil
local customKillSound: Sound? = nil
local gprHitSound: Sound? = nil
local soundIndex: number = 1

local SOUND_POOL_SIZE = Constants.Pool.SoundPoolSize

local function syncCustomKillSound(): ()
	local sound = customKillSound
	if not sound then
		return
	end
	local customId = Cache.getCustomKillSoundId()
	local wanted = if customId > 0 then `rbxassetid://{customId}` else ""
	if sound.SoundId ~= wanted then
		sound.SoundId = wanted
	end
end

function FeedbackSounds.init(): ()
	for i = 1, SOUND_POOL_SIZE do
		local sound = Instance.new("Sound")
		sound.SoundId = Constants.Sounds.Hit
		sound.Volume = 0.5
		sound.Parent = SoundService
		hitSounds[i] = sound
	end

	headshotSound = Instance.new("Sound")
	headshotSound.SoundId = Constants.Sounds.Headshot
	headshotSound.Volume = 0.7

	killSound = Instance.new("Sound")
	killSound.SoundId = Constants.Sounds.Kill
	killSound.Volume = 0.8

	customKillSound = Instance.new("Sound")
	customKillSound.Volume = 0.8

	gprHitSound = Instance.new("Sound")
	gprHitSound.SoundId = "rbxasset://sounds/metalgrass2.mp3"
	gprHitSound.PlaybackSpeed = 1.5
	gprHitSound.Volume = 1

	headshotSound.Parent = SoundService
	killSound.Parent = SoundService
	customKillSound.Parent = SoundService
	Cache.onCustomKillSoundChanged(syncCustomKillSound)
	syncCustomKillSound()
	gprHitSound.Parent = SoundService
end

function FeedbackSounds.playHit(isHeadshot: boolean, gunName: string?): ()
	if Cache.getHitSoundsEnabled() then
		if gunName == "GPR" and gprHitSound then
			gprHitSound:Play()
		else
			local sound = hitSounds[soundIndex]
			soundIndex = soundIndex % SOUND_POOL_SIZE + 1
			sound:Play()

			if isHeadshot and headshotSound then
				headshotSound:Play()
			end
		end
	end
end

function FeedbackSounds.playKill(): ()
	if not Cache.getKillSoundsEnabled() or not killSound or not customKillSound then
		return
	end
	syncCustomKillSound()
	local sound = if customKillSound.SoundId ~= "" and customKillSound.IsLoaded then customKillSound else killSound
	sound:Play()
end

function FeedbackSounds.cleanup(): ()
	for _, sound in hitSounds do
		sound:Destroy()
	end
	table.clear(hitSounds)

	if headshotSound then
		headshotSound:Destroy()
		headshotSound = nil
	end

	if killSound then
		killSound:Destroy()
		killSound = nil
	end

	Cache.onCustomKillSoundChanged(nil)
	if customKillSound then
		customKillSound:Destroy()
		customKillSound = nil
	end

	if gprHitSound then
		gprHitSound:Destroy()
		gprHitSound = nil
	end

	soundIndex = 1
end

return FeedbackSounds
