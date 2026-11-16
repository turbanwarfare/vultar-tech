--!strict
--!native
--!optimize 2

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Root = script.Parent
local MainModule = require(Root.Shared.Game).get()
local SWTypes = require(Root.Shared.Network.Types)
local Packages = MainModule:WaitForChild("Packages", 5)
local Trove = require(Packages:WaitForChild("Trove", 5))
local ScreenWatchConfig = require(Root.Shared.Config)
local GunStats = require(MainModule.Shared.Config.GunStats)
local PlayerCache = require(MainModule.Shared.Cache.PlayerCache)
local Network = { ScreenWatch = require(Root.Shared.Network) }
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
local Auth = require(Root.Auth)

local EXPORT_WEBHOOK_URL = "REPLACE_WITH_YOUR_WEBHOOK_URL"

local getGunService = LazyService.create(MainModule, "GunService")

type WatchSession = {
	watchers: { [Player]: boolean },
	watcherCount: number,
	targetPlayer: Player,
	trove: any,
	sampleCount: number,
	lastCameraTimestamp: number?,
	totalPing: number,
	pingSpikes: number,
	wasSpiking: boolean,
}

local BODY_PART_NAMES: { [number]: string } = {
	[1] = "Head",
	[2] = "Torso",
	[3] = "Left Arm",
	[4] = "Right Arm",
	[5] = "Left Leg",
	[6] = "Right Leg",
}

local ScreenWatchService = {}
ScreenWatchService.Name = "ScreenWatchService"


local activeWatches: { [number]: WatchSession } = {}
local watcherToTarget: { [Player]: number } = {}
local serviceConnections: { RBXScriptConnection } = {}

type PreBufferEntry = { r: number, p: any }
type PreBuffer = {
	cameras: { PreBufferEntry },
	cursors: { PreBufferEntry },
	ghosts: { PreBufferEntry },
	characterConnection: RBXScriptConnection?,
	ghostSkip: number,
}
local PRE_BUFFER_SECONDS = ScreenWatchConfig.RecordingBufferSeconds or 30
local PRE_BUFFER_TRIM_SLACK = 5
local PRE_BUFFER_CHUNK = 60
local PRE_BUFFER_CHUNK_GAP = 0.05
local PRE_BUFFER_GHOST_EVERY = 3
local preBuffers: { [number]: PreBuffer } = {}
local readyClients: { [number]: boolean } = {}

local function pushPreBuffer(list: { PreBufferEntry }, payload: any): ()
	local now = os.clock()
	table.insert(list, { r = now, p = payload })
	local cutoff = now - PRE_BUFFER_SECONDS
	if list[1].r >= cutoff - PRE_BUFFER_TRIM_SLACK then
		return
	end
	local count = #list
	local drop = 0
	while drop < count and list[drop + 1].r < cutoff do
		drop += 1
	end
	if drop > 0 then
		table.move(list, drop + 1, count, 1)
		for i = count - drop + 1, count do
			list[i] = nil
		end
	end
end

local function slicePayloads(list: { PreBufferEntry }, start: number): { any }
	local out = {}
	for i = start, math.min(start + PRE_BUFFER_CHUNK - 1, #list) do
		table.insert(out, list[i].p)
	end
	return out
end

local function sendPreBuffer(watcher: Player, buffer: PreBuffer): ()
	local oldest = math.huge
	for _, list in { buffer.cameras, buffer.cursors, buffer.ghosts } do
		if list[1] then
			oldest = math.min(oldest, list[1].r)
		end
	end
	if oldest == math.huge or not watcher.Parent then
		return
	end

	Network.ScreenWatch.sendPreBufferStart(watcher, os.clock() - oldest)
	local total = math.max(#buffer.cameras, #buffer.cursors, #buffer.ghosts)
	for start = 1, total, PRE_BUFFER_CHUNK do
		if not watcher.Parent or watcherToTarget[watcher] == nil then
			return
		end
		Network.ScreenWatch.sendPreBufferChunk(watcher, {
			cameras = slicePayloads(buffer.cameras, start),
			cursors = slicePayloads(buffer.cursors, start),
			ghosts = slicePayloads(buffer.ghosts, start),
		})
		task.wait(PRE_BUFFER_CHUNK_GAP)
	end
end

local function isAuthorized(player: Player): boolean
	return Auth.isAuthorized(player)
end

local function buildCaptureConfig(): SWTypes.ConfigPayload
	return {
		cameraSampleHz = ScreenWatchConfig.CameraSampleHz or 60,
		cursorSampleHz = ScreenWatchConfig.CursorSampleHz or 60,
		ghostSampleHz = 60,
		ghostRenderDistance = 350,
		ghostMaxCount = 16,
	}
end

local function stopSessionForTarget(targetUserId: number): ()
	local session = activeWatches[targetUserId]
	if not session then
		return
	end

	for watcher in session.watchers do
		watcherToTarget[watcher] = nil
		Network.ScreenWatch.sendWatchStateSync(watcher, {
			targetUserId = targetUserId,
			isWatching = false,
			targetName = nil,
		})
	end

	if session.targetPlayer.Parent and not preBuffers[targetUserId] then
		Network.ScreenWatch.sendStopCapture(session.targetPlayer)
	end

	session.trove:Destroy()
	activeWatches[targetUserId] = nil
end

local function unsubscribeWatcher(staffPlayer: Player, targetUserId: number?): ()
	local resolvedTargetId = targetUserId or watcherToTarget[staffPlayer]
	if not resolvedTargetId then
		return
	end

	local session = activeWatches[resolvedTargetId]
	if not session then
		watcherToTarget[staffPlayer] = nil
		return
	end

	if session.watchers[staffPlayer] then
		session.watchers[staffPlayer] = nil
		session.watcherCount -= 1
		watcherToTarget[staffPlayer] = nil

		Network.ScreenWatch.sendWatchStateSync(staffPlayer, {
			targetUserId = resolvedTargetId,
			isWatching = false,
			targetName = nil,
		})

		if session.watcherCount <= 0 then
			stopSessionForTarget(resolvedTargetId)
		end
	end
end

local function onClientReady(player: Player): ()
	readyClients[player.UserId] = true
	local session = activeWatches[player.UserId]
	if (session and session.watcherCount > 0) or preBuffers[player.UserId] then
		Network.ScreenWatch.sendStartCapture(player, buildCaptureConfig())
	end
end

local function subscribeWatcher(staffPlayer: Player, targetUserId: number): ()
	if not isAuthorized(staffPlayer) then
		return
	end
	if typeof(targetUserId) ~= "number" then
		return
	end

	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if not targetPlayer then
		return
	end
	if not readyClients[targetUserId] then
		warn(`[ScreenWatch] {staffPlayer.Name} is watching {targetPlayer.Name} but that client has not loaded ScreenWatch yet; capture will start when it does`)
	end

	local currentWatched = watcherToTarget[staffPlayer]
	if currentWatched and currentWatched ~= targetUserId then
		unsubscribeWatcher(staffPlayer, currentWatched)
	end

	local session = activeWatches[targetUserId]
	if not session then
		local sessionTrove = Trove.new()
		session = {
			watchers = {},
			watcherCount = 0,
			targetPlayer = targetPlayer,
			trove = sessionTrove,
			sampleCount = 0,
			lastCameraTimestamp = nil,
			totalPing = 0,
			pingSpikes = 0,
			wasSpiking = false,
		}
		activeWatches[targetUserId] = session

		local configPayload = buildCaptureConfig()
		Network.ScreenWatch.sendStartCapture(targetPlayer, configPayload)

		local function onTargetCharacter(_char: Model)
			task.delay(0.2, function()
				if activeWatches[targetUserId] == session and targetPlayer.Parent then
					Network.ScreenWatch.sendStartCapture(targetPlayer, buildCaptureConfig())
				end
			end)
		end

		sessionTrove:Add(targetPlayer.CharacterAdded:Connect(onTargetCharacter))
		if targetPlayer.Character then
			onTargetCharacter(targetPlayer.Character)
		end
	else
		Network.ScreenWatch.sendStartCapture(targetPlayer, buildCaptureConfig())
	end

	if not session.watchers[staffPlayer] then
		session.watchers[staffPlayer] = true
		session.watcherCount += 1
	end
	watcherToTarget[staffPlayer] = targetUserId

	Network.ScreenWatch.sendWatchStateSync(staffPlayer, {
		targetUserId = targetUserId,
		isWatching = true,
		targetName = targetPlayer.Name,
	})

	local buffer = preBuffers[targetUserId]
	if buffer then
		task.defer(sendPreBuffer, staffPlayer, buffer)
	end
end

local function onCameraStreamTarget(player: Player, payload: SWTypes.CameraPayload): ()
	local buffer = preBuffers[player.UserId]
	if buffer then
		pushPreBuffer(buffer.cameras, payload)
	end

	local session = activeWatches[player.UserId]
	if not session or session.watcherCount <= 0 then
		return
	end

	local ok, rawPing = pcall(player.GetNetworkPing, player)
	local pingMs = if ok and typeof(rawPing) == "number" then math.clamp(math.round(rawPing * 1000), 0, 65535) else 0

	session.sampleCount += 1
	session.lastCameraTimestamp = payload.timestamp
	session.totalPing += pingMs
	local avgPingMs = math.round(session.totalPing / session.sampleCount)

	if pingMs > 400 then
		if not session.wasSpiking then
			session.wasSpiking = true
			session.pingSpikes += 1
		end
	else
		session.wasSpiking = false
	end

	local gunService = getGunService()
	local matchAccuracy: number? = nil
	if gunService and gunService.getAccuracyStats then
		local fired, hit = gunService:getAccuracyStats(player.UserId)
		if fired > 0 then
			matchAccuracy = math.clamp((hit / fired) * 100, 0, 100)
		else
			matchAccuracy = 0
		end
	end

	payload.ping = pingMs
	payload.avgPing = avgPingMs
	payload.pingSpikes = session.pingSpikes
	payload.matchAccuracy = matchAccuracy

	for watcher in session.watchers do
		if watcher.Parent then
			Network.ScreenWatch.sendCameraStreamWatcher(watcher, payload)
		end
	end
end

local function onGhostStreamTarget(player: Player, payload: SWTypes.GhostPayload): ()
	local buffer = preBuffers[player.UserId]
	if buffer then
		buffer.ghostSkip = (buffer.ghostSkip + 1) % PRE_BUFFER_GHOST_EVERY
		if buffer.ghostSkip == 0 then
			pushPreBuffer(buffer.ghosts, payload)
		end
	end

	local session = activeWatches[player.UserId]
	if not session or session.watcherCount <= 0 then
		return
	end

	for watcher in session.watchers do
		if watcher.Parent then
			Network.ScreenWatch.sendGhostStreamWatcher(watcher, payload)
		end
	end
end

local DEFAULT_CURSOR_ICON = "rbxassetid://131581677"

local function sanitizeCursorIcon(icon: unknown): string
	if type(icon) ~= "string" or #icon > 128 then
		return DEFAULT_CURSOR_ICON
	end
	if string.match(icon, "^rbxassetid://%d+$") then
		return icon
	end
	if string.match(icon, "^rbxasset://[%w%._%-/]+$") then
		return icon
	end
	return DEFAULT_CURSOR_ICON
end

local function onCursorStreamTarget(player: Player, payload: SWTypes.CursorPayload): ()
	local buffer = preBuffers[player.UserId]
	if buffer then
		payload.icon = sanitizeCursorIcon(payload.icon)
		pushPreBuffer(buffer.cursors, payload)
	end

	local session = activeWatches[player.UserId]
	if not session or session.watcherCount <= 0 then
		return
	end

	payload.icon = sanitizeCursorIcon(payload.icon)

	for watcher in session.watchers do
		if watcher.Parent then
			Network.ScreenWatch.sendCursorStreamWatcher(watcher, payload)
		end
	end
end

local INPUT_NAME_ALLOWLIST: { [string]: boolean } = {
	W = true,
	A = true,
	S = true,
	D = true,
	SPRINT = true,
	CROUCH = true,
	ZOOM = true,
	RELOAD = true,
	SPACE = true,
	LMB = true,
	RMB = true,
}

local KEY_EVENT_ALLOWLIST: { [string]: boolean } = {
	["CLIENT TABBED OUT"] = true,
	["CLIENT TABBED IN"] = true,
	["SETTINGS MENU OPENED"] = true,
	["SETTINGS MENU CLOSED"] = true,
}

local keyCodeNames: { [string]: boolean } = {}
for _, keyCode in Enum.KeyCode:GetEnumItems() do
	keyCodeNames[keyCode.Name] = true
end

local function isValidKeyName(keyName: unknown): boolean
	if type(keyName) ~= "string" then
		return false
	end
	return keyCodeNames[keyName] == true or KEY_EVENT_ALLOWLIST[keyName] == true
end

local function onInputEventTarget(player: Player, payload: SWTypes.InputPayload): ()
	local session = activeWatches[player.UserId]
	if not session or session.watcherCount <= 0 then
		return
	end

	if type(payload.inputName) ~= "string" or not INPUT_NAME_ALLOWLIST[payload.inputName] then
		return
	end

	for watcher in session.watchers do
		if watcher.Parent then
			Network.ScreenWatch.sendInputEventWatcher(watcher, payload)
		end
	end
end

local function onKeyHistoryEventTarget(player: Player, payload: SWTypes.KeyHistoryPayload): ()
	local session = activeWatches[player.UserId]
	if not session or session.watcherCount <= 0 then
		return
	end

	if not isValidKeyName(payload.keyName) then
		return
	end

	for watcher in session.watchers do
		if watcher.Parent then
			Network.ScreenWatch.sendKeyHistoryEventWatcher(watcher, payload)
		end
	end
end

local function onPlayerRemoving(player: Player): ()
	if watcherToTarget[player] then
		unsubscribeWatcher(player, watcherToTarget[player])
	end

	if activeWatches[player.UserId] then
		stopSessionForTarget(player.UserId)
	end

	ScreenWatchService:SetPreBuffer(player.UserId, false)
	readyClients[player.UserId] = nil
end

function ScreenWatchService:NotifyHit(
	attackerUserId: number,
	victimUserId: number,
	damage: number,
	bodyPartIndex: number,
	isHeadshot: boolean,
	gunIndex: number,
	customVictimName: string?,
	hitOffset: Vector3?
): ()
	local session = activeWatches[attackerUserId]
	if not session or session.watcherCount <= 0 then
		return
	end

	local victimName = customVictimName or "NPC"
	if victimUserId > 0 and not customVictimName then
		local cached = PlayerCache.getByUserId(victimUserId)
		if cached and cached.player then
			victimName = cached.player.Name
		else
			local p = Players:GetPlayerByUserId(victimUserId)
			if p then
				victimName = p.Name
			end
		end
	end

	local partName = BODY_PART_NAMES[bodyPartIndex] or if isHeadshot then "Head" else "Torso"
	local weaponName = GunStats.GUN_INDEX_TO_NAME[gunIndex] or "Weapon"

	local payload: SWTypes.HitPayload = {
		targetUserId = attackerUserId,
		victimId = victimUserId,
		victimName = victimName,
		damage = math.round(damage),
		bodyPart = partName,
		isHeadshot = isHeadshot,
		weaponName = weaponName,
		timestamp = os.clock(),
		hitOffset = hitOffset,
		targetTime = session.lastCameraTimestamp,
	}

	for watcher in session.watchers do
		if watcher.Parent then
			Network.ScreenWatch.sendHitEventWatcher(watcher, payload)
		end
	end
end

function ScreenWatchService:SetPreBuffer(targetUserId: number, enabled: boolean): ()
	local existing = preBuffers[targetUserId]
	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if enabled then
		if existing or not targetPlayer then
			return
		end
		local buffer: PreBuffer = { cameras = {}, cursors = {}, ghosts = {}, ghostSkip = 0 }
		preBuffers[targetUserId] = buffer
		Network.ScreenWatch.sendStartCapture(targetPlayer, buildCaptureConfig())
		buffer.characterConnection = targetPlayer.CharacterAdded:Connect(function()
			task.delay(0.2, function()
				if preBuffers[targetUserId] == buffer and targetPlayer.Parent then
					Network.ScreenWatch.sendStartCapture(targetPlayer, buildCaptureConfig())
				end
			end)
		end)
		return
	end

	if not existing then
		return
	end
	if existing.characterConnection then
		existing.characterConnection:Disconnect()
	end
	preBuffers[targetUserId] = nil
	local session = activeWatches[targetUserId]
	if targetPlayer and not (session and session.watcherCount > 0) then
		Network.ScreenWatch.sendStopCapture(targetPlayer)
	end
end

function ScreenWatchService:OpenSelectMenu(player: Player): ()
	Network.ScreenWatch.sendOpenSelectMenu(player)
end

function ScreenWatchService:IsAuthorized(player: Player): boolean
	return isAuthorized(player)
end

function ScreenWatchService:StartWatch(staffPlayer: Player, targetPlayer: Player): ()
	subscribeWatcher(staffPlayer, targetPlayer.UserId)
end

function ScreenWatchService:StopWatch(staffPlayer: Player): ()
	unsubscribeWatcher(staffPlayer, nil)
end

function ScreenWatchService:IsWatcher(player: Player): boolean
	return watcherToTarget[player] ~= nil
end

function ScreenWatchService:GetTargetForWatcher(watcher: Player): Player?
	local targetUserId = watcherToTarget[watcher]
	if not targetUserId then
		return nil
	end
	return Players:GetPlayerByUserId(targetUserId)
end

function ScreenWatchService:GetWatchersForPlayer(targetPlayer: Player): { Player }
	local session = activeWatches[targetPlayer.UserId]
	if not session then
		return {}
	end
	local list: { Player } = {}
	for watcher in session.watchers do
		table.insert(list, watcher)
	end
	return list
end

local MAX_EXPORT_CHUNKS = 200
local MAX_EXPORT_CHUNK_LENGTH = 40960
local MAX_EXPORT_TOTAL_LENGTH = 4194304

local function generateSerialId(): string
	return string.format("VDI-%04X-%04X", Random.new():NextInteger(0, 0xFFFF), Random.new():NextInteger(0, 0xFFFF))
end

local function sanitizeSerialId(serialId: unknown): string
	if type(serialId) == "string" and string.match(serialId, "^VDI%-%x%x%x%x%-%x%x%x%x$") then
		return serialId
	end
	return generateSerialId()
end

local function sanitizeTargetName(name: unknown): string
	if type(name) ~= "string" then
		return "Unknown"
	end
	if string.match(name, "^[%w_]+$") and #name <= 20 then
		return name
	end
	return "Unknown"
end

local function handleExportLogs(staffPlayer: Player, data: { chunks: { string }, targetUserId: number, targetName: string, serialId: string? }): ()
	if not isAuthorized(staffPlayer) then
		warn("[ScreenWatch] Unauthorized log export attempt by", staffPlayer.Name)
		return
	end

	local chunks = data.chunks
	if type(chunks) ~= "table" or #chunks == 0 or #chunks > MAX_EXPORT_CHUNKS then
		warn("[ScreenWatch] Invalid export chunks from", staffPlayer.Name)
		return
	end

	local fullString = ""
	for _, chunk in chunks do
		if type(chunk) ~= "string" then
			continue
		end
		if #chunk > MAX_EXPORT_CHUNK_LENGTH then
			warn("[ScreenWatch] Oversized export chunk from", staffPlayer.Name)
			return
		end
		if #fullString + #chunk > MAX_EXPORT_TOTAL_LENGTH then
			warn("[ScreenWatch] Oversized export payload from", staffPlayer.Name)
			return
		end
		fullString ..= chunk
	end

	if #fullString == 0 then
		return
	end

	local targetName = sanitizeTargetName(data.targetName)
	local targetUserId = tonumber(data.targetUserId) or 0
	local serialId = sanitizeSerialId(data.serialId)

	task.spawn(function()
		local formattedDate = os.date("!%Y-%m-%d %H:%M:%S UTC")
		local boundary = "----WebhookBoundary" .. tostring(Random.new():NextInteger(1000000, 9999999))
		local body = "--" .. boundary .. "\r\n"
		body ..= 'Content-Disposition: form-data; name="content"\r\n\r\n'
		body ..= string.format(
			"**VDI SCREENWATCH LOG EXPORT / %s**\n**Watcher:** %s (%d)\n**Target Player:** %s (%d)\n**Date:** %s",
			serialId,
			staffPlayer.Name,
			staffPlayer.UserId,
			targetName,
			targetUserId,
			formattedDate
		) .. "\r\n"
		body ..= "--" .. boundary .. "\r\n"
		body ..= string.format('Content-Disposition: form-data; name="file"; filename="ScreenWatch_%s_%s_%d.txt"\r\n', targetName, serialId, os.time())
		body ..= "Content-Type: text/plain\r\n\r\n"
		body ..= fullString .. "\r\n"
		body ..= "--" .. boundary .. "--\r\n"

		local webhookUrl = EXPORT_WEBHOOK_URL
		if not webhookUrl or webhookUrl == "" then
			warn("[ScreenWatch] Export webhook URL is not configured.")
			return
		end

		local success, err = pcall(function()
			local response = HttpService:RequestAsync({
				Url = webhookUrl,
				Method = "POST",
				Headers = {
					["Content-Type"] = "multipart/form-data; boundary=" .. boundary,
				},
				Body = body,
			})

			if not response.Success then
				warn("[ScreenWatch] Discord webhook failed with status", response.StatusCode, "-", response.StatusMessage)
				warn("[ScreenWatch] Webhook response body:", response.Body)
			else
				print("[ScreenWatch] Successfully exported investigation log to webhook for", targetName)
			end
		end)

		if not success then
			warn("[ScreenWatch] Discord webhook file upload failed:", err)
		end
	end)
end

function ScreenWatchService:init(): () end

function ScreenWatchService:start(): ()
	Network.ScreenWatch.init()
	Network.ScreenWatch.onSubscribeWatch(subscribeWatcher)
	Network.ScreenWatch.onUnsubscribeWatch(unsubscribeWatcher)
	Network.ScreenWatch.onCameraStreamTarget(onCameraStreamTarget)
	Network.ScreenWatch.onGhostStreamTarget(onGhostStreamTarget)
	Network.ScreenWatch.onCursorStreamTarget(onCursorStreamTarget)
	Network.ScreenWatch.onInputEventTarget(onInputEventTarget)
	Network.ScreenWatch.onKeyHistoryEventTarget(onKeyHistoryEventTarget)
	Network.ScreenWatch.onClientReady(onClientReady)
	table.insert(serviceConnections, Network.ScreenWatch.onExportLogs(handleExportLogs))

	table.insert(serviceConnections, Players.PlayerRemoving:Connect(onPlayerRemoving))
end

function ScreenWatchService:Cleanup(): ()
	for _, conn in serviceConnections do
		conn:Disconnect()
	end
	table.clear(serviceConnections)

	for targetUserId in activeWatches do
		stopSessionForTarget(targetUserId)
	end
	table.clear(activeWatches)
	table.clear(watcherToTarget)
	for targetUserId in preBuffers do
		ScreenWatchService:SetPreBuffer(targetUserId, false)
	end
end

return ScreenWatchService
