--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local Constants = require(MainModule.Shared.Config.Constants)
local PlayerCache = require(MainModule.Shared.Cache.PlayerCache)
local GunStats = require(MainModule.Shared.Config.GunStats)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
local FactionUtils = require(MainModule.Shared.Utils.Game.FactionUtils)
local DamageProcessor = require(script.Parent.DamageProcessor)

local HealProcessor = {}

local getHardpointService = LazyService.create(MainModule, "HardpointService")
local getPhaseService = LazyService.create(MainModule, "PhaseService")
local getDominationService = LazyService.create(MainModule, "DominationService")
local getStatsService = LazyService.create(MainModule, "StatsService")
local MIN_PLAYERS_FOR_STATS = Constants.STATS.MIN_PLAYERS

local MEDI_HEAL_AMOUNT: number = (function(): number
	local mediStats = GunStats.get("Medi+")
	if mediStats and mediStats.HealAmount then
		return mediStats.HealAmount
	end
	return 3
end)()

local function shouldCountStats(): boolean
	local hardpoint = getHardpointService()
	if hardpoint and hardpoint:IsOfficial() then
		return PlayerCache.getCount() >= MIN_PLAYERS_FOR_STATS
	end
	local phase = getPhaseService()
	if phase and phase:IsOfficial() then
		return PlayerCache.getCount() >= MIN_PLAYERS_FOR_STATS
	end
	local domination = getDominationService()
	if domination and domination:IsOfficial() then
		return PlayerCache.getCount() >= MIN_PLAYERS_FOR_STATS
	end
	return false
end

local FACTION_NEUTRAL = "Neutral"
local FACTION_NONE = ""

local humanoidCache: { [number]: Humanoid? } = {}
local playerCache: { [number]: Player? } = {}
local CACHE_LIFETIME = 5
local lastCacheUpdate: number = 0

local moduleConnections: { RBXScriptConnection } = {}

local function refreshCache(): ()
	local now = os.clock()
	if now - lastCacheUpdate < CACHE_LIFETIME then return end

	lastCacheUpdate = now
	table.clear(humanoidCache)
	table.clear(playerCache)
end

local function canHeal(healer: Player, target: Player): boolean
	if healer == target then
		return false
	end

	local healerFaction = FactionUtils.getPlayerFaction(healer)
	if healerFaction == FACTION_NEUTRAL or healerFaction == FACTION_NONE then
		return false
	end

	local targetFaction = FactionUtils.getPlayerFaction(target)
	if targetFaction == FACTION_NEUTRAL or targetFaction == FACTION_NONE then
		return false
	end

	return healerFaction == targetFaction
end

local function getCachedPlayer(userId: number): Player?
	local cached = playerCache[userId]
	if cached then
		return cached
	end

	local player = Players:GetPlayerByUserId(userId)
	playerCache[userId] = player
	return player
end

local function getCachedHumanoid(userId: number): Humanoid?
	local cached = humanoidCache[userId]
	if cached and cached.Parent then
		return cached
	end

	local player = getCachedPlayer(userId)
	if not player then
		humanoidCache[userId] = nil
		return nil
	end

	local char = player.Character
	if not char then
		humanoidCache[userId] = nil
		return nil
	end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	humanoidCache[userId] = humanoid
	return humanoid
end

function HealProcessor.init(): ()

	table.insert(moduleConnections, Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		humanoidCache[userId] = nil
		playerCache[userId] = nil
	end))
end

function HealProcessor.cleanup(): ()
	for _, conn in moduleConnections do
		conn:Disconnect()
	end
	table.clear(moduleConnections)
	table.clear(humanoidCache)
	table.clear(playerCache)
end

function HealProcessor.processBatch(healer: Player, heals: { { targetId: number, healAmount: number, pos: Vector3 } }, count: number): ()
	refreshCache()

	for i = 1, count do
		local heal = heals[i]
		if heal then
			HealProcessor.applyHeal(healer, heal)
		end
	end
end

function HealProcessor.applyHeal(healer: Player, heal: { targetId: number, healAmount: number, pos: Vector3 }): ()
	debug.profilebegin("HealProcessor::applyHeal")
	local targetPlayer = getCachedPlayer(heal.targetId)
	if not targetPlayer then return end

	if not canHeal(healer, targetPlayer) then return end

	local humanoid = getCachedHumanoid(heal.targetId)
	if not humanoid then return end

	local hp = humanoid.Health
	local maxHP = humanoid.MaxHealth
	if hp <= 0 then return end
	if hp >= maxHP then return end

	local actualHeal = math.min(MEDI_HEAL_AMOUNT, maxHP - hp)
	humanoid.Health = hp + actualHeal

	local statsSvc = getStatsService()
	if statsSvc then
		statsSvc:AddHeal(healer, actualHeal)
	end

	if shouldCountStats() and statsSvc then
		statsSvc:AddHealGlobal(healer, actualHeal)
	end
	
	DamageProcessor.registerHeal(heal.targetId, actualHeal)
	
	debug.profileend()
end

return HealProcessor
