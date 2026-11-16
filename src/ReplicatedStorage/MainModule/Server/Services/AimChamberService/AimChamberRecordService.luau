--!strict
--!native
--!optimize 2

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local AimChamberConfig = require(MainModule.Shared.Config.AimChamberConfig)
local RankCache = require(MainModule.Server.Cache.RankCache)

type AimChamberSettings = AimChamberConfig.AimChamberSettings
type AimChamberDeathReason = AimChamberConfig.AimChamberDeathReason
type AimChamberRunRecord = AimChamberConfig.AimChamberRunRecord

local runRecordsStore = DataStoreService:GetDataStore(AimChamberConfig.DATASTORE.RUN_RECORDS_STORE)
local runTimeIndexStore = DataStoreService:GetOrderedDataStore(AimChamberConfig.DATASTORE.RUN_TIME_INDEX_STORE)
local matchHistoryStore = DataStoreService:GetDataStore("AimChamberHistory_v1")

local AimChamberRecordService = {}

local webhookCooldowns: { [number]: { lastSent: number, count: number } } = {}

local function generateRecordId(): string
	return HttpService:GenerateGUID(false)
end

local function isStage2Initiate(player: Player): boolean
	local groupId = AimChamberConfig.GROUPS.VIA
	local stage2Rank = AimChamberConfig.STAGE_2_RANK

	local rank = RankCache.getPlayerRank(player, groupId)
	return rank == stage2Rank
end

local function getAvatarUrl(userId: number): string
	return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150"
end

local function formatTimestamp(timestamp: number): string
	local dt = DateTime.fromUnixTimestamp(timestamp)
	return dt:FormatLocalTime("YYYY-MM-DD HH:mm:ss", "en-us")
end

local function checkWebhookRateLimit(userId: number): boolean
	local now = os.clock()
	local data = webhookCooldowns[userId]
	if not data then
		data = { lastSent = 0, count = 0 }
		webhookCooldowns[userId] = data
	end

	local window = AimChamberConfig.WEBHOOK.RATE_LIMIT_WINDOW
	local maxPerWindow = AimChamberConfig.WEBHOOK.RATE_LIMIT_MAX

	if (now - data.lastSent) > window then
		data.count = 0
		data.lastSent = now
	end

	if data.count >= maxPerWindow then
		return false
	end

	data.count += 1
	data.lastSent = now
	return true
end

local function sendWebhook(embed: { [string]: any }): ()
	local webhookUrl = "REPLACE_WITH_YOUR_WEBHOOK_URL"
	if not webhookUrl or webhookUrl == "" then
		return
	end

	local payload = HttpService:JSONEncode({
		username = AimChamberConfig.WEBHOOK.USERNAME,
		embeds = { embed },
	})

	pcall(HttpService.PostAsync, HttpService, webhookUrl, payload)
end

function AimChamberRecordService.sendAnomalyWebhook(player: Player, anomalyType: string, details: string, rawPayload: any?): ()
	if not checkWebhookRateLimit(player.UserId) then
		return
	end

	local embed = {
		title = "Aim Trainer Alert",
		color = 0xFF4444,
		fields = {
			{ name = "Player", value = string.format("%s (%d)", player.Name, player.UserId), inline = true },
			{ name = "Type", value = anomalyType, inline = true },
			{ name = "Details", value = details, inline = false },
		},
		footer = { text = AimChamberConfig.WEBHOOK.FOOTER_TEXT },
		timestamp = DateTime.now():ToIsoDate(),
	}

	if rawPayload then
		local payloadStr = tostring(rawPayload)
		if #payloadStr > 1000 then
			payloadStr = payloadStr:sub(1, 1000) .. "..."
		end
		table.insert(embed.fields, {
			name = "Raw Payload",
			value = "```" .. payloadStr .. "```",
			inline = false,
		})
	end

	task.spawn(sendWebhook, embed)
end

function AimChamberRecordService.buildRunRecord(
	player: Player,
	presetId: string,
	settings: AimChamberSettings,
	deathReason: AimChamberDeathReason,
	elapsedTime: number,
	startTimestamp: number
): AimChamberRunRecord
	local countsForValidation = false

	if deathReason ~= "LeftMidMatch" and settings.AssessmentValidation then
		countsForValidation = isStage2Initiate(player)
	end

	return {
		RecordId = generateRecordId(),
		UserId = player.UserId,
		PlayerName = player.Name,
		DisplayName = player.DisplayName,
		PresetId = presetId,
		Settings = table.clone(settings),
		GunName = settings.SelectedGun,
		DeathReason = deathReason,
		ElapsedTime = elapsedTime,
		Timestamp = startTimestamp,
		ServerTimestamp = os.time(),
		CountsForValidation = countsForValidation,
		AvatarUrl = getAvatarUrl(player.UserId),
	}
end

function AimChamberRecordService.buildValidationPayload(
	player: Player,
	record: AimChamberRunRecord,
	match: any
): {
	PlayerName: string,
	UserId: number,
	AvatarUrl: string,
	PresetId: string,
	Settings: AimChamberSettings,
	GunName: string,
	FormattedDateTime: string,
	DeathReason: AimChamberDeathReason,
	ElapsedTime: number,
	ZombieSpawnRate: number,
	AveragePing: number,
	MaxPingSpike: number,
	BigPingSpikesCount: number,
	ViaGroupRank: string,
}
	local averagePing = 0
	if match and match.PingCount and match.PingCount > 0 then
		averagePing = match.PingSum / match.PingCount
	end

	local viaRank = ""
	pcall(function()
		viaRank = player:GetRoleInGroup(AimChamberConfig.GROUPS.VIA)
	end)

	return {
		PlayerName = player.Name,
		UserId = player.UserId,
		AvatarUrl = record.AvatarUrl,
		PresetId = record.PresetId,
		Settings = table.clone(record.Settings),
		GunName = record.GunName,
		FormattedDateTime = formatTimestamp(record.ServerTimestamp),
		DeathReason = record.DeathReason,
		ElapsedTime = record.ElapsedTime,
		ZombieSpawnRate = record.Settings.ZombieSpawnRate,
		AveragePing = averagePing,
		MaxPingSpike = match and match.MaxPingSpike or 0,
		BigPingSpikesCount = match and match.BigPingSpikesCount or 0,
		ViaGroupRank = viaRank,
	}
end

function AimChamberRecordService.saveRunRecord(record: AimChamberRunRecord): ()
	local key = AimChamberConfig.DATASTORE.RUN_RECORDS_KEY_PREFIX .. record.RecordId

	pcall(function()
		runRecordsStore:SetAsync(key, record)
	end)

	pcall(function()
		runTimeIndexStore:SetAsync(record.RecordId, record.ServerTimestamp)
	end)
end

function AimChamberRecordService.checkAnomalies(player: Player, record: AimChamberRunRecord): ()
	if record.Settings.AssessmentValidation and record.DeathReason ~= "LeftMidMatch" then
		if record.ElapsedTime < AimChamberConfig.ANOMALY_THRESHOLDS.SUSPICIOUSLY_SHORT_TIME then
			AimChamberRecordService.sendAnomalyWebhook(
				player,
				"Suspiciously Short Assessment",
				string.format(
					"Survived only %.2f seconds in Assessment mode (threshold: %ds)",
					record.ElapsedTime,
					AimChamberConfig.ANOMALY_THRESHOLDS.SUSPICIOUSLY_SHORT_TIME
				)
			)
		end
	end
end

function AimChamberRecordService.checkAmmoAnomaly(player: Player, anomalyType: string): ()
	AimChamberRecordService.sendAnomalyWebhook(player, "Ammo Warning", anomalyType)
end

function AimChamberRecordService.getPlayerHistory(player: Player): { any }
	local key = "History_" .. player.UserId
	local success, history = pcall(function()
		return matchHistoryStore:GetAsync(key)
	end)
	if success and type(history) == "table" then
		return history
	end
	return {}
end

function AimChamberRecordService.savePlayerHistory(player: Player, history: { any }): ()
	local key = "History_" .. player.UserId
	pcall(function()
		matchHistoryStore:SetAsync(key, history)
	end)
end

local playerRemovingConn: RBXScriptConnection? = nil

function AimChamberRecordService.start(): ()
	playerRemovingConn = Players.PlayerRemoving:Connect(function(player: Player)
		webhookCooldowns[player.UserId] = nil
	end)
end

function AimChamberRecordService.cleanup(): ()
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	table.clear(webhookCooldowns)
end

return AimChamberRecordService
