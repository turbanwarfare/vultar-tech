--!strict
--!native
--!optimize 2

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local ReconWeaponBalanceConfig = require(MainModule.Shared.Config.Weapons.ReconWeaponBalanceConfig)
local ReconDetectionConfig = require(script.ReconDetectionConfig)
local GunStats = require(MainModule.Shared.Config.GunStats)
local LogBlacklist = require(MainModule.Shared.Config.LogBlacklist)

type PlayerMacroState = {
	lockedUntil: number,
	lockedPistol: string?,
	rifleName: string?,
	lastDischargeTime: number,
	chargePercent: number,
	hasSoftFriction: boolean,
	recentRifleHits: { [number]: { damage: number, timestamp: number } },
	shotHistory: { number },
	shotHistoryHead: number,
	shotHistoryCount: number,
	attemptHistory: { number },
	attemptHistoryHead: number,
	attemptHistoryCount: number,
	killHistory: { boolean },
	killHistoryHead: number,
	killHistoryCount: number,
	lastAlertTime: number,
}

local ReconAntiMacroService = {}
ReconAntiMacroService.Name = "ReconAntiMacroService"

local playerStates: { [number]: PlayerMacroState } = {}
local isInitialized = false
local playerRemovingConnection: RBXScriptConnection? = nil

local function getOrCreateState(userId: number): PlayerMacroState
	local state = playerStates[userId]
	if not state then
		state = {
			lockedUntil = 0,
			lockedPistol = nil,
			rifleName = nil,
			lastDischargeTime = 0,
			chargePercent = 0,
			hasSoftFriction = false,
			recentRifleHits = {},
			shotHistory = table.create(ReconDetectionConfig.MAX_HISTORY_SHOTS, 0),
			shotHistoryHead = 0,
			shotHistoryCount = 0,
			attemptHistory = table.create(ReconDetectionConfig.MAX_HISTORY_ATTEMPTS, 0),
			attemptHistoryHead = 0,
			attemptHistoryCount = 0,
			killHistory = table.create(ReconDetectionConfig.MAX_HISTORY_KILLS, false),
			killHistoryHead = 0,
			killHistoryCount = 0,
			lastAlertTime = 0,
		}
		playerStates[userId] = state
	end
	return state
end

local function pushCircularNumber(bufferTable: { number }, max: number, head: number, count: number, value: number): (number, number)
	local nextHead = (head % max) + 1
	bufferTable[nextHead] = value
	local nextCount = math.min(count + 1, max)
	return nextHead, nextCount
end

local function pushCircularBoolean(bufferTable: { boolean }, max: number, head: number, count: number, value: boolean): (number, number)
	local nextHead = (head % max) + 1
	bufferTable[nextHead] = value
	local nextCount = math.min(count + 1, max)
	return nextHead, nextCount
end

local function calculateChargeVarianceSignal(state: PlayerMacroState): (number, number, number)
	local count = state.shotHistoryCount
	if count < ReconDetectionConfig.MIN_SHOTS_SAMPLE then
		return 0, 0, count
	end

	local sum = 0
	for i = 1, count do
		sum += state.shotHistory[i]
	end
	local mean = sum / count

	local varSum = 0
	for i = 1, count do
		local diff = state.shotHistory[i] - mean
		varSum += diff * diff
	end
	local stddev = math.sqrt(varSum / count)

	if stddev < ReconDetectionConfig.STDDEV_THRESHOLD then
		local score = math.clamp(1 - (stddev / ReconDetectionConfig.STDDEV_THRESHOLD), 0, 1)
		return score, stddev, count
	end

	return 0, stddev, count
end

local function calculateSwitchLatencySignal(state: PlayerMacroState): (number, number, number)
	local count = state.attemptHistoryCount
	if count < ReconDetectionConfig.MIN_ATTEMPTS_SAMPLE then
		return 0, 0, count
	end

	local sum = 0
	for i = 1, count do
		sum += state.attemptHistory[i]
	end
	local avgLatency = sum / count

	if avgLatency < ReconDetectionConfig.SUB_HUMAN_LATENCY_THRESHOLD then
		local score = math.clamp(1 - (avgLatency / ReconDetectionConfig.SUB_HUMAN_LATENCY_THRESHOLD), 0, 1)
		return score, avgLatency, count
	end

	return 0, avgLatency, count
end

local function calculateKillPrecisionSignal(state: PlayerMacroState): (number, number, number)
	local count = state.killHistoryCount
	if count < ReconDetectionConfig.MIN_KILLS_SAMPLE then
		return 0, 0, count
	end

	local lethalHits = 0
	for i = 1, count do
		if state.killHistory[i] then
			lethalHits += 1
		end
	end
	local ratio = lethalHits / count

	if ratio >= ReconDetectionConfig.PRECISION_RATIO_THRESHOLD then
		local denominator = 1 - ReconDetectionConfig.PRECISION_RATIO_THRESHOLD
		local score = if denominator > 0
			then math.clamp((ratio - ReconDetectionConfig.PRECISION_RATIO_THRESHOLD) / denominator, 0, 1)
			else 1
		return score, ratio, count
	end

	return 0, ratio, count
end

local function getPlayerHeadshotUrl(userId: number): string?
	if userId <= 0 then
		return nil
	end
	local url = string.format("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%d&size=420x420&format=Png&isCircular=false", userId)
	local success, response = pcall(function()
		return HttpService:GetAsync(url)
	end)
	if success and response then
		local decodeSuccess, data = pcall(function()
			return HttpService:JSONDecode(response)
		end)
		if decodeSuccess and data and data.data and data.data[1] and data.data[1].imageUrl then
			return data.data[1].imageUrl
		end
	end
	return nil
end

local function fireWebhook(
	userId: number,
	userName: string,
	compositeScore: number,
	sCharge: number,
	stddev: number,
	shotCount: number,
	sLatency: number,
	avgLatency: number,
	attemptCount: number,
	sPrecision: number,
	lethalRatio: number,
	killCount: number
): ()
	if LogBlacklist.isBlocked() then
		return
	end

	local headshotUrl = getPlayerHeadshotUrl(userId)
	local thumbnail = if headshotUrl then { url = headshotUrl } else nil

	local chargeDetail = if sCharge >= 0.7
		then string.format("Score: %.2f | StdDev: %.4f (%d shots)\nFlagged: Charge timing was identical across all shots", sCharge, stddev, shotCount)
		else string.format("Score: %.2f | StdDev: %.4f (%d shots)", sCharge, stddev, shotCount)

	local latencyMs = math.round(avgLatency * 1000)
	local latencyDetail = if sLatency >= 0.7
		then string.format("Score: %.2f | Avg Latency: %.3fs (%d attempts)\nFlagged: Swapped to pistol in %dms (faster than human reaction time of 120ms)", sLatency, avgLatency, attemptCount, latencyMs)
		else string.format("Score: %.2f | Avg Latency: %.3fs (%d attempts)", sLatency, avgLatency, attemptCount)

	local precisionDetail = if sPrecision >= 0.7
		then string.format("Score: %.2f | Lethal Finishes: %.0f%% (%d kills)\nFlagged: Repeatedly dealt exact lethal threshold (100 HP combo)", sPrecision, lethalRatio * 100, killCount)
		else string.format("Score: %.2f | Lethal Finishes: %.0f%% (%d kills)", sPrecision, lethalRatio * 100, killCount)

	local embed = {
		title = "SUSPECTED_MACRO",
		color = 0xFF3040,
		thumbnail = thumbnail,
		fields = {
			{ name = "Player", value = string.format("%s (%d)", userName, userId), inline = true },
			{ name = "Detection Confidence", value = string.format("HIGH (%.2f/%.2f)", compositeScore, ReconDetectionConfig.COMPOSITE_FLAG_THRESHOLD), inline = true },
			{ name = "\u{200B}", value = "\u{200B}", inline = true },
			{
				name = "Charge Timing Consistency",
				value = chargeDetail,
				inline = false,
			},
			{
				name = "Pistol Switch Speed",
				value = latencyDetail,
				inline = false,
			},
			{
				name = "Lethal Combo Precision",
				value = precisionDetail,
				inline = false,
			},
		},
		footer = { text = "VULTARIAN DEFENSE INDUSTRIES" },
		timestamp = DateTime.now():ToIsoDate(),
	}

	local payload = HttpService:JSONEncode({
		username = "Vultarian Security Sentinel",
		embeds = { embed },
	})

	local success, err = pcall(function()
		return HttpService:PostAsync(ReconDetectionConfig.WEBHOOK_URL, payload, Enum.HttpContentType.ApplicationJson)
	end)
	if success then
		print("[ReconAntiMacroService] Webhook alert sent successfully for player:", userName)
	else
		warn("[ReconAntiMacroService] Failed to post webhook alert:", err)
	end
end

local function evaluateState(userId: number, userName: string, state: PlayerMacroState): ()
	local sCharge, stddev, shotCount = calculateChargeVarianceSignal(state)
	local sLatency, avgLatency, attemptCount = calculateSwitchLatencySignal(state)
	local sPrecision, lethalRatio, killCount = calculateKillPrecisionSignal(state)

	local composite = (sCharge * ReconDetectionConfig.WEIGHT_CHARGE)
		+ (sLatency * ReconDetectionConfig.WEIGHT_LATENCY)
		+ (sPrecision * ReconDetectionConfig.WEIGHT_PRECISION)

	state.hasSoftFriction = composite >= ReconDetectionConfig.SOFT_FRICTION_THRESHOLD

	if composite >= ReconDetectionConfig.COMPOSITE_FLAG_THRESHOLD then
		local now = os.time()
		if now - state.lastAlertTime >= ReconDetectionConfig.ALERT_COOLDOWN then
			state.lastAlertTime = now
			task.spawn(
				fireWebhook,
				userId,
				userName,
				composite,
				sCharge,
				stddev,
				shotCount,
				sLatency,
				avgLatency,
				attemptCount,
				sPrecision,
				lethalRatio,
				killCount
			)
		else
			print(string.format("[ReconAntiMacroService] Player %s flagged (score %.2f), on cooldown (%ds remaining)", userName, composite, ReconDetectionConfig.ALERT_COOLDOWN - (now - state.lastAlertTime)))
		end
	end
end

function ReconAntiMacroService.RegisterRifleDischarge(player: Player, gunName: string, chargePercent: number): ()
	local pairedPistol = ReconWeaponBalanceConfig.ReconPairings[gunName]
	if not pairedPistol then
		warn("[ReconAntiMacroService] No paired pistol configured for rifle:", gunName)
		return
	end

	local now = os.clock()
	local userId = player.UserId
	local state = getOrCreateState(userId)

	local clampedCharge = math.clamp(chargePercent, 0, 1)

	local lockoutDuration = 0
	if clampedCharge >= ReconWeaponBalanceConfig.MinLockoutCharge and clampedCharge <= ReconWeaponBalanceConfig.MaxLockoutCharge then
		local penalty = ReconWeaponBalanceConfig.MaxSwitchLockoutPenalty
			+ (if state.hasSoftFriction then ReconWeaponBalanceConfig.SoftFrictionPenaltyIncrease else 0)
		lockoutDuration = ReconWeaponBalanceConfig.BaseBoltCycleTime + (1 - clampedCharge) * penalty
	end

	state.lockedUntil = if lockoutDuration > 0 then now + lockoutDuration else 0
	state.lockedPistol = if lockoutDuration > 0 then pairedPistol else nil
	state.rifleName = gunName
	state.lastDischargeTime = now
	state.chargePercent = clampedCharge

	local nextHead, nextCount = pushCircularNumber(
		state.shotHistory,
		ReconDetectionConfig.MAX_HISTORY_SHOTS,
		state.shotHistoryHead,
		state.shotHistoryCount,
		clampedCharge
	)
	state.shotHistoryHead = nextHead
	state.shotHistoryCount = nextCount

	evaluateState(userId, player.Name, state)
end

function ReconAntiMacroService.RecordRifleHit(player: Player, victimUserId: number, damage: number): ()
	if victimUserId <= 0 then
		return
	end

	local userId = player.UserId
	local state = getOrCreateState(userId)
	state.recentRifleHits[victimUserId] = {
		damage = damage,
		timestamp = os.clock(),
	}
end

function ReconAntiMacroService.IsSwitchLocked(player: Player, targetWeaponName: string): boolean
	local userId = player.UserId
	local state = playerStates[userId]
	if not state then
		return false
	end

	if not state.lockedPistol or state.lockedPistol ~= targetWeaponName then
		return false
	end

	return os.clock() < state.lockedUntil
end

function ReconAntiMacroService.RecordSwitchAttempt(player: Player, targetWeaponName: string): ()
	local userId = player.UserId
	local state = playerStates[userId]
	if not state then
		return
	end

	if not state.lockedPistol or state.lockedPistol ~= targetWeaponName then
		return
	end

	local now = os.clock()
	if now >= state.lockedUntil then
		return
	end

	local latency = math.max(0, now - state.lastDischargeTime)
	local nextHead, nextCount = pushCircularNumber(
		state.attemptHistory,
		ReconDetectionConfig.MAX_HISTORY_ATTEMPTS,
		state.attemptHistoryHead,
		state.attemptHistoryCount,
		latency
	)
	state.attemptHistoryHead = nextHead
	state.attemptHistoryCount = nextCount

	evaluateState(userId, player.Name, state)
end

function ReconAntiMacroService.RegisterKill(killer: Player, victimUserId: number, finishWeaponName: string): ()
	local expectedRifle = ReconWeaponBalanceConfig.ReconPistolToRifle[finishWeaponName]
	if not expectedRifle then
		return
	end

	local userId = killer.UserId
	local state = playerStates[userId]
	if not state then
		return
	end

	local hitRecord = state.recentRifleHits[victimUserId]
	if not hitRecord then
		return
	end

	local now = os.clock()
	if now - hitRecord.timestamp > ReconDetectionConfig.RECENT_SHOT_WINDOW then
		state.recentRifleHits[victimUserId] = nil
		return
	end

	local finishStats = GunStats.get(finishWeaponName)
	if not finishStats then
		warn("[ReconAntiMacroService] GunStats not found for finish weapon:", finishWeaponName)
	end
	local finishDamage = if finishStats and finishStats.BaseDamage then finishStats.BaseDamage else 12
	local totalDamage = hitRecord.damage + finishDamage
	local isLethalClustered = math.abs(totalDamage - ReconDetectionConfig.LETHAL_TARGET_DAMAGE) <= ReconDetectionConfig.LETHAL_MARGIN

	state.recentRifleHits[victimUserId] = nil

	local nextHead, nextCount = pushCircularBoolean(
		state.killHistory,
		ReconDetectionConfig.MAX_HISTORY_KILLS,
		state.killHistoryHead,
		state.killHistoryCount,
		isLethalClustered
	)
	state.killHistoryHead = nextHead
	state.killHistoryCount = nextCount

	evaluateState(userId, killer.Name, state)
end

function ReconAntiMacroService.ClearLockout(player: Player): ()
	local state = playerStates[player.UserId]
	if state then
		state.lockedUntil = 0
		state.lockedPistol = nil
		state.rifleName = nil
		table.clear(state.recentRifleHits)
	end
end

function ReconAntiMacroService.ClearPlayer(player: Player): ()
	playerStates[player.UserId] = nil
end

function ReconAntiMacroService.GetLockoutStatus(player: Player): (boolean, number, string?)
	local state = playerStates[player.UserId]
	if not state then
		return false, 0, nil
	end
	local now = os.clock()
	local isLocked = now < state.lockedUntil
	local remaining = if isLocked then state.lockedUntil - now else 0
	return isLocked, remaining, state.lockedPistol
end

function ReconAntiMacroService.TestWebhook(player: any): (boolean, string?)
	local userId = if player and player.UserId then player.UserId else 1
	local userName = if player and player.Name then player.Name else "TestUser"
	print(string.format("[ReconAntiMacroService] Sending direct test webhook for %s (%d)...", userName, userId))

	local headshotUrl = getPlayerHeadshotUrl(userId)
	local thumbnail = if headshotUrl then { url = headshotUrl } else nil

	local embed = {
		title = "SUSPECTED_MACRO",
		color = 0xFF3040,
		thumbnail = thumbnail,
		fields = {
			{ name = "Player", value = string.format("%s (%d)", userName, userId), inline = true },
			{ name = "Detection Confidence", value = string.format("HIGH (%.2f/%.2f)", 0.75, ReconDetectionConfig.COMPOSITE_FLAG_THRESHOLD), inline = true },
			{ name = "\u{200B}", value = "\u{200B}", inline = true },
			{
				name = "Charge Timing Consistency",
				value = "Score: 1.00 | StdDev: 0.0000 (6 shots)\nFlagged: Charge timing was identical across all shots",
				inline = false,
			},
			{
				name = "Pistol Switch Speed",
				value = "Score: 1.00 | Avg Latency: 0.000s (3 attempts)\nFlagged: Swapped to pistol in 0ms (faster than human reaction time of 120ms)",
				inline = false,
			},
			{
				name = "Lethal Combo Precision",
				value = "Score: 0.00 | Lethal Finishes: 0% (0 kills)",
				inline = false,
			},
		},
		footer = { text = "VULTARIAN DEFENSE INDUSTRIES" },
		timestamp = DateTime.now():ToIsoDate(),
	}

	local payload = HttpService:JSONEncode({
		username = "Vultarian Security Sentinel",
		embeds = { embed },
	})

	local success, result = pcall(function()
		return HttpService:PostAsync(ReconDetectionConfig.WEBHOOK_URL, payload, Enum.HttpContentType.ApplicationJson)
	end)

	if success then
		print("[ReconAntiMacroService] Direct test webhook delivered successfully!")
		return true, "Success"
	else
		warn("[ReconAntiMacroService] Direct test webhook failed:", result)
		return false, tostring(result)
	end
end

function ReconAntiMacroService.init(): ()
	if isInitialized then
		return
	end
	isInitialized = true

	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		ReconAntiMacroService.ClearPlayer(player)
	end)
end

function ReconAntiMacroService.Cleanup(): ()
	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	table.clear(playerStates)
	isInitialized = false
end

return ReconAntiMacroService
