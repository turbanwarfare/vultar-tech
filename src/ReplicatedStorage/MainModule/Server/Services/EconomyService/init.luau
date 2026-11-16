--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local EconomyConfig = require(MainModule.Shared.Config.Economy.EconomyConfig)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
local Maps = require(MainModule.Shared.Config.Maps)
local ServerUtils = require(MainModule.Shared.Utils.Game.ServerUtils)
local VultarApi = require(script.VultarApi)
local PrivateServerSafeguards = require(script.PrivateServerSafeguards)

export type ReceiptInfo = {
	PurchaseId: string,
	PlayerId: number,
	ProductId: number,
	CurrencySpent: number,
	PlaceIdWherePurchased: number,
}

local EconomyService = {}
EconomyService.Name = "EconomyService"

local PROFILE_RETRY_COOLDOWN = 30

local getCosmeticService = LazyService.create(MainModule, "CosmeticService")
local getStatsService = LazyService.create(MainModule, "StatsService")
local getTeamService = LazyService.create(MainModule, "TeamService")
local getJoinLogService = LazyService.create(MainModule, "JoinLogService")

local playerBalances: { [number]: number } = {}
local profileLoading: { [number]: boolean } = {}
local lastProfileAttempt: { [number]: number } = {}
local processedReceipts: { [string]: boolean } = {}
local pendingReceiptsLogged: { [string]: boolean } = {}
local serviceConnections: { RBXScriptConnection } = {}
local isInitialized = false

local matchId: string? = nil
local matchStartTime = 0
local isMatchTampered = false
local tamperReason: string? = nil
local playerJoinMatchTimes: { [number]: number } = {}
local matchParticipationScores: { [number]: number } = {}
local matchPeak = { defenders = 0, raiders = 0, total = 0, eligible = 0 }

local SUMMARY_SETTLE_SECONDS = 3
local SUMMARY_MAX_WAIT = 60

type RewardEntry = { player: Player, credits: number, won: boolean }
type MatchSummary = {
	mapName: string,
	isPrivate: boolean,
	entries: { RewardEntry },
	outstanding: number,
	lastAdded: number,
}

local matchSummary: MatchSummary? = nil

local function setBalance(player: Player, balance: number): ()
	playerBalances[player.UserId] = balance
	Network.Economy.sendBalance(player, balance)
end

local function loadProfile(player: Player): ()
	local userId = player.UserId
	if profileLoading[userId] or playerBalances[userId] ~= nil then
		return
	end

	local lastAttempt = lastProfileAttempt[userId]
	if lastAttempt and os.clock() - lastAttempt < PROFILE_RETRY_COOLDOWN then
		return
	end

	profileLoading[userId] = true
	lastProfileAttempt[userId] = os.clock()

	local profile = VultarApi.getProfile(userId)
	profileLoading[userId] = nil

	if not profile or not player.Parent then
		return
	end

	setBalance(player, profile.credits)

	local cosmeticService = getCosmeticService()
	if cosmeticService and #profile.unlocks > 0 then
		cosmeticService:ApplyUnlocks(player, profile.unlocks)
	end
end

local function onStatChanged(player: Player, statType: string, oldValue: number, newValue: number): ()
	local delta = math.max(0, newValue - oldValue)
	if delta <= 0 then
		return
	end

	local weights = EconomyConfig.WEIGHTS
	local weight = if statType == "Captures"
		then weights.CAPTURE_BONUS
		elseif statType == "Kills" then weights.KILL_BONUS
		elseif statType == "Damage" then weights.DAMAGE_WEIGHT
		elseif statType == "Heals" then weights.HEALS_WEIGHT
		else 1
	matchParticipationScores[player.UserId] = (matchParticipationScores[player.UserId] or 0) + delta * weight
end

local function countFactions(): (number, number)
	local teamService = getTeamService()
	local defenders, raiders = 0, 0
	if not teamService then
		return defenders, raiders
	end
	for _, p in Players:GetPlayers() do
		local faction = teamService:GetPlayerFaction(p)
		if faction == "Defenders" then
			defenders += 1
		elseif faction == "Raiders" then
			raiders += 1
		end
	end
	return defenders, raiders
end

local function countEligibleMembers(): number
	local count = 0
	for _, p in Players:GetPlayers() do
		if PrivateServerSafeguards.isMemberEligible(p) then
			count += 1
		end
	end
	return count
end

local function updateMatchPeak(): ()
	local defenders, raiders = countFactions()
	matchPeak.defenders = math.max(matchPeak.defenders, defenders)
	matchPeak.raiders = math.max(matchPeak.raiders, raiders)
	matchPeak.total = math.max(matchPeak.total, #Players:GetPlayers())
	if ServerUtils.isPrivateServer() then
		matchPeak.eligible = math.max(matchPeak.eligible, countEligibleMembers())
	end
end

local function onPlayerRemoving(player: Player): ()
	local userId = player.UserId
	playerBalances[userId] = nil
	profileLoading[userId] = nil
	lastProfileAttempt[userId] = nil
	playerJoinMatchTimes[userId] = nil
	updateMatchPeak()
end

local function processReceipt(receiptInfo: ReceiptInfo): Enum.ProductPurchaseDecision
	local purchaseId = receiptInfo.PurchaseId
	if typeof(purchaseId) ~= "string" or purchaseId == "" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if processedReceipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local joinLogService = getJoinLogService()

	local creditProduct = EconomyConfig.getCreditProduct(receiptInfo.ProductId)
	if not creditProduct then
		warn(`[EconomyService] Unknown developer product ID {receiptInfo.ProductId} for player {receiptInfo.PlayerId}`)
		if joinLogService and not pendingReceiptsLogged[purchaseId] then
			pendingReceiptsLogged[purchaseId] = true
			joinLogService.LogEconomyAlert(
				"UNKNOWN PRODUCT",
				receiptInfo.PlayerId,
				`product {receiptInfo.ProductId} · {receiptInfo.CurrencySpent} R$ · purchase {purchaseId}`
			)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local newBalance, failure = VultarApi.recordPurchase(receiptInfo.PlayerId, purchaseId, creditProduct.Credits, receiptInfo.ProductId)
	if not newBalance then
		if joinLogService and not pendingReceiptsLogged[purchaseId] then
			pendingReceiptsLogged[purchaseId] = true
			joinLogService.LogEconomyAlert(
				"PAID, NOT DELIVERED YET",
				receiptInfo.PlayerId,
				`{creditProduct.Credits} credits · {receiptInfo.CurrencySpent} R$ · purchase {purchaseId} · {failure or "unknown error"} · Roblox will retry`
			)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	processedReceipts[purchaseId] = true
	local wasDelayed = pendingReceiptsLogged[purchaseId] == true
	pendingReceiptsLogged[purchaseId] = nil

	if joinLogService then
		joinLogService.LogCreditPurchase(receiptInfo.PlayerId, creditProduct.Credits, receiptInfo.CurrencySpent, newBalance, wasDelayed)
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player then
		setBalance(player, newBalance)
		Network.Economy.sendPurchaseConfirmation(player, {
			creditsGranted = creditProduct.Credits,
			productId = receiptInfo.ProductId,
			newBalance = newBalance,
		})
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function EconomyService:init(): ()
	if isInitialized then
		return
	end
	isInitialized = true

	Network.Economy.init()

	Network.Economy.onGetBalance(function(player: Player)
		loadProfile(player)
		return playerBalances[player.UserId] or 0
	end)
end

function EconomyService:start(): ()
	if not isInitialized then
		self:init()
	end

	ReplicatedStorage:SetAttribute("CratesEnabled", VultarApi.isAvailable())

	MarketplaceService.ProcessReceipt = processReceipt

	table.insert(
		serviceConnections,
		Players.PlayerAdded:Connect(function(player: Player)
			playerJoinMatchTimes[player.UserId] = os.clock()
			task.spawn(loadProfile, player)
		end)
	)
	table.insert(serviceConnections, Players.PlayerRemoving:Connect(onPlayerRemoving))

	for _, player in Players:GetPlayers() do
		playerJoinMatchTimes[player.UserId] = os.clock()
		task.spawn(loadProfile, player)
	end

	task.spawn(function()
		local statsService = getStatsService()
		if statsService and typeof(statsService.OnStatChanged) == "function" then
			table.insert(serviceConnections, statsService:OnStatChanged(onStatChanged))
		end
	end)
end

function EconomyService:GetBalance(player: Player): number
	return playerBalances[player.UserId] or 0
end

function EconomyService:CommitCrateOpen(player: Player, crateRequest: VultarApi.CrateOpenRequest): (boolean, VultarApi.CrateOpenError?)
	if playerBalances[player.UserId] == nil then
		return false, "unavailable" :: VultarApi.CrateOpenError
	end

	local newBalance: number?, err: VultarApi.CrateOpenError? = VultarApi.openCrate(player.UserId, crateRequest)
	if not newBalance then
		return false, err
	end

	if player.Parent then
		setBalance(player, newBalance)
	end
	return true, nil
end

function EconomyService:GetMatchContribution(userId: number): number
	local score = matchParticipationScores[userId] or 0
	if score > 0 then
		return score
	end

	local statsService = getStatsService()
	local player = Players:GetPlayerByUserId(userId)
	if statsService and player then
		return EconomyConfig.calculateParticipationScore(statsService:GetStats(player))
	end
	return 0
end

function EconomyService:ResetMatchParticipation(): ()
	table.clear(matchParticipationScores)
	matchId = nil
end

function EconomyService:OnMatchStarted(): ()
	matchId = HttpService:GenerateGUID(false)
	matchStartTime = os.clock()
	isMatchTampered = false
	tamperReason = nil
	table.clear(matchParticipationScores)
	table.clear(playerJoinMatchTimes)
	for _, player in Players:GetPlayers() do
		playerJoinMatchTimes[player.UserId] = matchStartTime
	end
	matchPeak = { defenders = 0, raiders = 0, total = 0, eligible = 0 }
	task.spawn(updateMatchPeak)
end

function EconomyService:GetPeakPlayerCount(): number
	return matchPeak.total
end

function EconomyService:FlagMatchTampered(reason: string): ()
	if not isMatchTampered then
		isMatchTampered = true
		tamperReason = reason
		warn(`[EconomyService] Match flagged as tampered: {reason}`)
	end
end

function EconomyService:IsMatchTampered(): (boolean, string?)
	return isMatchTampered, tamperReason
end

local function postSummaryWhenSettled(summary: MatchSummary): ()
	local startedAt = os.clock()
	repeat
		task.wait(1)
		local settled = summary.outstanding == 0 and os.clock() - summary.lastAdded >= SUMMARY_SETTLE_SECONDS
	until settled or os.clock() - startedAt >= SUMMARY_MAX_WAIT

	if matchSummary == summary then
		matchSummary = nil
	end
	local joinLogService = getJoinLogService()
	if joinLogService then
		joinLogService.LogMatchRewards(summary.mapName, summary.isPrivate, summary.entries)
	end
end

local function trackReward(mapName: string, isPrivate: boolean, player: Player, isWinner: boolean): (MatchSummary, RewardEntry)
	local summary: MatchSummary = matchSummary
		or {
			mapName = mapName,
			isPrivate = isPrivate,
			entries = {},
			outstanding = 0,
			lastAdded = os.clock(),
		}
	if matchSummary ~= summary then
		matchSummary = summary
		task.spawn(postSummaryWhenSettled, summary)
	end

	local entry: RewardEntry = { player = player, credits = 0, won = isWinner }
	table.insert(summary.entries, entry)
	summary.lastAdded = os.clock()
	return summary, entry
end

function EconomyService:AwardMatchOutcome(player: Player, isWinner: boolean, mapNameOverride: string?): boolean
	local mapName = mapNameOverride or Maps.getMapName() or "Unknown"
	local isPrivate = ServerUtils.isPrivateServer()
	local userId = player.UserId
	local summary, summaryEntry = trackReward(mapName, isPrivate, player, isWinner)

	local reward = 0
	local attendance = 1
	local score = self:GetMatchContribution(userId)

	local function sendMatchReward(credits: number): ()
		if player.Parent then
			Network.Economy.sendMatchReward(player, {
				credits = credits,
				mapName = mapName,
				mapReward = if isPrivate then PrivateServerSafeguards.getPayout(mapName, isWinner) else EconomyConfig.getMapReward(mapName),
				isWinner = isWinner,
				attendance = math.min(attendance, 1),
				score = score,
				isPrivate = isPrivate,
			})
		end
	end

	if isPrivate then
		local duration = if matchStartTime > 0 then os.clock() - matchStartTime else 0
		updateMatchPeak()
		local matchValid, matchError = PrivateServerSafeguards.validateMatch({
			IsTampered = isMatchTampered,
			TamperReason = tamperReason,
			Duration = duration,
			DefenderCount = matchPeak.defenders,
			RaiderCount = matchPeak.raiders,
			EligibleCount = matchPeak.eligible,
		})
		if not matchValid then
			warn(`[EconomyService] No private reward for {player.Name}: {matchError}`)
			return false
		end

		local playerValid, playerError = PrivateServerSafeguards.validatePlayer({
			Player = player,
			MatchDuration = duration,
			JoinTimestamp = playerJoinMatchTimes[userId] or os.clock(),
			MatchScore = self:GetMatchContribution(userId),
		})
		if not playerValid then
			warn(`[EconomyService] No private reward for {player.Name}: {playerError}`)
			return false
		end

		reward = PrivateServerSafeguards.getPayout(mapName, isWinner)
	else
		local now = os.clock()
		local duration = if matchStartTime > 0 then now - matchStartTime else 0
		local joinedAt = math.max(playerJoinMatchTimes[userId] or now, matchStartTime)
		attendance = if duration > 0 then (now - joinedAt) / duration else 1
		reward = EconomyConfig.calculateMatchReward(mapName, isWinner, attendance, score)
	end

	reward = math.floor(reward)
	if reward <= 0 then
		sendMatchReward(0)
		return false
	end

	if not matchId then
		matchId = HttpService:GenerateGUID(false)
	end

	local request = {
		txId = `match:{matchId}:{userId}`,
		credits = reward,
		map = mapName,
		win = isWinner,
		private = isPrivate,
	}

	summary.outstanding += 1
	task.spawn(function()
		local newBalance, failure = VultarApi.recordMatchReward(userId, request)
		if newBalance then
			summaryEntry.credits = reward
			if player.Parent then
				setBalance(player, newBalance)
				sendMatchReward(reward)
			end
		else
			local joinLogService = getJoinLogService()
			if joinLogService then
				joinLogService.LogEconomyAlert("MATCH REWARD REFUSED", userId, `{reward} credits · {mapName} · {failure or "unknown error"}`)
			end
		end
		summary.outstanding -= 1
	end)

	return true
end

function EconomyService:AwardMatchWin(player: Player, mapNameOverride: string?): boolean
	return self:AwardMatchOutcome(player, true, mapNameOverride)
end

function EconomyService:Cleanup(): ()
	for _, conn in serviceConnections do
		conn:Disconnect()
	end
	table.clear(serviceConnections)
	table.clear(playerBalances)
	table.clear(profileLoading)
	table.clear(lastProfileAttempt)
	table.clear(processedReceipts)
	table.clear(pendingReceiptsLogged)
	table.clear(playerJoinMatchTimes)
	table.clear(matchParticipationScores)
	matchId = nil
	matchStartTime = 0
	isMatchTampered = false
	tamperReason = nil
	isInitialized = false
end

return EconomyService
