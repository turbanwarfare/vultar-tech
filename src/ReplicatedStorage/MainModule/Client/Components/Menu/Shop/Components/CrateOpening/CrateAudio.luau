--!strict
--!native
--!optimize 2

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local CrateAudio = {}

local AUDIO_REGISTRY: { [string]: string } = {
	BoxChargeUp = "rbxassetid://119091876232528",
	BoxLidPop = "rbxassetid://74574444991136",
	BoxRevealWhoosh = "rbxassetid://93793342329453",
	AnticipationShake = "rbxassetid://72500887678395",
	HeavyImpactThud = "rbxassetid://127659074743226",

	UncommonChime = "rbxassetid://102771574969417",
	RareStarburst = "rbxassetid://132689858015056",
	LegendaryWhoosh = "rbxassetid://111519265351354",
	LegendaryStinger = "rbxassetid://105406797322536",
	MythicBass = "rbxassetid://113203917006664",
	MythicAscension = "rbxassetid://80641899029934",
	DuplicateRefund = "rbxassetid://137214707166921",

	CrateMusic = "rbxassetid://74369589608673",
}

local poolFolder: Folder? = nil
local soundPool: { [string]: { Sound } } = {}
local poolIndex: { [string]: number } = {}
local isPreloaded = false

local POOL_SIZE_PER_ASSET = 2

function CrateAudio.init(): ()
	if poolFolder then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "CrateAudioPool"
	folder.Parent = SoundService
	poolFolder = folder

	local assetList: { string } = {}
	for _, assetId in AUDIO_REGISTRY do
		table.insert(assetList, assetId)
	end

	for _, assetId in AUDIO_REGISTRY do
		soundPool[assetId] = {}
		poolIndex[assetId] = 1

		for i = 1, POOL_SIZE_PER_ASSET do
			local sound = Instance.new("Sound")
			sound.Name = string.format("PoolSound_%s_%d", string.sub(assetId, -6), i)
			sound.SoundId = assetId
			sound.Volume = 0.8
			sound.PlaybackSpeed = 1.0
			sound.Parent = folder
			table.insert(soundPool[assetId], sound)
		end
	end

	task.spawn(function()
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(assetList)
		end)
		if ok then
			isPreloaded = true
		else
			warn("[CrateAudio] ContentProvider preload warning: " .. tostring(err))
		end
	end)
end

function CrateAudio.isPreloaded(): boolean
	return isPreloaded
end

function CrateAudio.play(soundCfg: any, defaultVolume: number?, defaultSpeed: number?): (number, Sound?)
	local startTick = os.clock()
	if not soundCfg then
		return startTick, nil
	end

	local soundId = if typeof(soundCfg) == "table" then soundCfg.AssetId else soundCfg
	if not soundId or soundId == "" or soundId == "rbxassetid://" then
		return startTick, nil
	end

	local volume = if typeof(soundCfg) == "table" and soundCfg.Volume then soundCfg.Volume else (defaultVolume or 0.85)
	local playbackSpeed = if typeof(soundCfg) == "table" and soundCfg.PlaybackSpeed then soundCfg.PlaybackSpeed else (defaultSpeed or 1.0)

	if not poolFolder then
		CrateAudio.init()
	end

	local pool = soundPool[soundId]
	local soundInstance: Sound

	if pool and #pool > 0 then
		local idx = poolIndex[soundId] or 1
		soundInstance = pool[idx]
		poolIndex[soundId] = (idx % #pool) + 1
	else
		soundInstance = Instance.new("Sound")
		soundInstance.SoundId = soundId
		soundInstance.Ended:Once(function()
			soundInstance:Destroy()
		end)
		soundInstance.Parent = poolFolder or SoundService
	end

	local timePos = if typeof(soundCfg) == "table" and soundCfg.TimePosition then soundCfg.TimePosition else 0
	soundInstance.Volume = volume
	soundInstance.PlaybackSpeed = playbackSpeed
	soundInstance.TimePosition = timePos
	soundInstance:Play()

	return startTick, soundInstance
end

function CrateAudio.playAll(soundsList: { any }, defaultVolume: number?): number
	local startTick = os.clock()
	if not soundsList or #soundsList == 0 then
		return startTick
	end

	for _, snd in soundsList do
		CrateAudio.play(snd, defaultVolume)
	end

	return startTick
end

function CrateAudio.measureSync(_eventName: string, _visualTick: number, _soundTick: number): () end

return CrateAudio
