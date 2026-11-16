--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local GunStats = require(MainModule.Shared.Config.GunStats)
local FactionUtils = require(MainModule.Shared.Utils.Game.FactionUtils)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
local Signal = require(MainModule.Shared.Utils.State.Signal)

local DamageProcessor = require(script.DamageProcessor)
local HealProcessor = require(script.HealProcessor)
local ReplicationManager = require(script.ReplicationManager)
local GunSecurityValidator = require(script.GunSecurityValidator)
local AimChamberLink = require(script.AimChamberLink)

local getReconAntiMacroService = LazyService.create(MainModule, "ReconAntiMacroService")

local GunService = {}
GunService.Name = "GunService"
GunService.HitObserved = Signal.new()
GunService.ShotObserved = Signal.new()

local MAX_HITS_PER_FRAME = 12
local MAX_HEALS_PER_FRAME = 12
local MAX_REPLICATES_PER_FRAME = 24
local MAX_HIT_EVENTS_PER_SECOND = 20
local MAX_HEAL_EVENTS_PER_SECOND = 20
local MAX_LOW_CHARGE_EVENTS_PER_SECOND = 2

local isInitialized = false
local playerRemovingConnection: RBXScriptConnection? = nil

local hitEventCounts: { [Player]: number } = {}
local hitEventResetTimes: { [Player]: number } = {}
local healEventCounts: { [Player]: number } = {}
local healEventResetTimes: { [Player]: number } = {}
local lowChargeEventCounts: { [Player]: number } = {}
local lowChargeEventResetTimes: { [Player]: number } = {}

local matchShotsFired: { [number]: number } = {}
local matchShotsHit: { [number]: number } = {}
local killShotsFired: { [number]: number } = {}

local function checkRateLimit(player: Player, counts: { [Player]: number }, resetTimes: { [Player]: number }, maxPerSecond: number): boolean
	local now = os.clock()
	local resetTime = resetTimes[player]
	if not resetTime or now >= resetTime then
		resetTimes[player] = now + 1
		counts[player] = 1
		return true
	end
	local count = (counts[player] or 0) + 1
	counts[player] = count
	return count <= maxPerSecond
end

function GunService:init(): ()
	Network.Gun.init()
	DamageProcessor.init()
	HealProcessor.init()
	ReplicationManager.init()

	isInitialized = true
end

function GunService:start(): ()
	if not isInitialized then
		self:init()
	end

	Network.Gun.onShotHit(function(player, targetId, damage, head, localOffset, bodyPart, gunIndex, origin, target, clientFireTime)
		if not checkRateLimit(player, hitEventCounts, hitEventResetTimes, MAX_HIT_EVENTS_PER_SECOND) then
			return
		end

		if not GunSecurityValidator.validateEquippedWeapon(player, gunIndex) then
			return
		end
		if not GunSecurityValidator.validateFireRate(player, gunIndex, clientFireTime) then
			return
		end
		if not GunSecurityValidator.validateMagazine(player, gunIndex) then
			return
		end
		
		GunService.HitObserved:Fire(player, targetId, localOffset, bodyPart, head, gunIndex, origin, target, clientFireTime)
		AimChamberLink.recordPlayerShot(player, 1)
		DamageProcessor.applyDamageImmediate(player, targetId, damage, head, localOffset, bodyPart, gunIndex, target)
		ReplicationManager.queue(player, origin, target, gunIndex)
	end)

	Network.Gun.onHits(function(player, hits, count, gunIndex, clientFireTime)
		if not checkRateLimit(player, hitEventCounts, hitEventResetTimes, MAX_HIT_EVENTS_PER_SECOND) then
			return
		end

		if not GunSecurityValidator.validateEquippedWeapon(player, gunIndex) then
			return
		end
		if not GunSecurityValidator.validateFireRate(player, gunIndex, clientFireTime) then
			return
		end
		if not GunSecurityValidator.validateMagazine(player, gunIndex) then
			return
		end
		local isValid, allowedCount = GunSecurityValidator.sanitizePelletCount(player, gunIndex, count)
		if not isValid then
			return
		end

		count = math.min(count, allowedCount, MAX_HITS_PER_FRAME)
		for i = 1, count do
			local hit = hits[i]
			if hit then
				GunService.HitObserved:Fire(player, hit.targetId, hit.pos, hit.bodyPart or 2, hit.head, gunIndex, nil, nil, clientFireTime)
			end
		end
		DamageProcessor.processBatch(player, hits, count, gunIndex)
	end)

	Network.Gun.onHeals(function(player, heals, count)
		if not checkRateLimit(player, healEventCounts, healEventResetTimes, MAX_HEAL_EVENTS_PER_SECOND) then
			return
		end
		count = math.min(count, MAX_HEALS_PER_FRAME)
		HealProcessor.processBatch(player, heals, count)
	end)

	Network.Gun.onMediBeam(function(player, action, targetId)
		if action ~= "start" and action ~= "stop" then
			return
		end
		Network.Gun.broadcastMediBeam(player, player.UserId, action, targetId)
	end)

	Network.Gun.onLowCharge(function(player)
		if not checkRateLimit(player, lowChargeEventCounts, lowChargeEventResetTimes, MAX_LOW_CHARGE_EVENTS_PER_SECOND) then
			return
		end

		local character = player.Character
		if not character then
			return
		end
		local tool = character:FindFirstChildOfClass("Tool")
		if not tool then
			return
		end
		local stats = GunStats.get(tool.Name)
		if not stats or stats.Mode ~= "Medi" then
			return
		end

		local healerId = player.UserId
		for _, other in Players:GetPlayers() do
			if other ~= player and (FactionUtils.areSameFaction(player, other) or FactionUtils.isSpectator(other)) then
				Network.Gun.sendLowChargeToClient(other, healerId)
			end
		end
	end)

	Network.Gun.onReplicate(function(player, replicateData, count)
		count = math.min(count, MAX_REPLICATES_PER_FRAME)
		local userId = player.UserId
		if not AimChamberLink.hasActiveMatch(player) then
			matchShotsFired[userId] = (matchShotsFired[userId] or 0) + count
			killShotsFired[userId] = (killShotsFired[userId] or 0) + count
		end
		
		AimChamberLink.recordPlayerShot(player, count)
		for i = 1, count do
			local data = replicateData[i]
			if data then
				ReplicationManager.queue(player, data.origin, data.target, data.gunIndex)
				GunService.ShotObserved:Fire(player, data.gunIndex, data.origin, data.target)
				local gunName = data.gunIndex and GunStats.GUN_INDEX_TO_NAME[data.gunIndex]
				if gunName == "BR-50" or gunName == "H-50" then
					local antiMacroSvc = getReconAntiMacroService()
					if antiMacroSvc then
						antiMacroSvc.RegisterRifleDischarge(player, gunName, 0)
					end
				end
			end
		end
	end)

	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		GunSecurityValidator.cleanupPlayer(player)
		Network.Gun.clearMediBeamState(player.UserId)
		hitEventCounts[player] = nil
		hitEventResetTimes[player] = nil
		healEventCounts[player] = nil
		healEventResetTimes[player] = nil
		lowChargeEventCounts[player] = nil
		lowChargeEventResetTimes[player] = nil
		local userId = player.UserId
		matchShotsFired[userId] = nil
		matchShotsHit[userId] = nil
		killShotsFired[userId] = nil
	end)
end

function GunService:Cleanup(): ()
	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	GunSecurityValidator.cleanup()
	DamageProcessor.cleanup()
	HealProcessor.cleanup()
	ReplicationManager.cleanup()
	isInitialized = false
end

function GunService:getAccuracyStats(userId: number): (number, number, number)
	return matchShotsFired[userId] or 0, matchShotsHit[userId] or 0, killShotsFired[userId] or 0
end

function GunService:resetKillShotsFired(userId: number): ()
	killShotsFired[userId] = 0
end

function GunService.registerValidHit(userId: number, count: number): ()
	matchShotsHit[userId] = (matchShotsHit[userId] or 0) + count
end

return GunService
