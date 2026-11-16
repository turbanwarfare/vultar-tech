--!strict
--!native
--!optimize 2
--#selene: allow(global_usage)

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local ChatConfig = require(MainModule.Shared.Config.Chat.ChatConfig)
local Constants = require(MainModule.Shared.Config.Constants)
local ChatAuth = require(script.ChatAuth)
local TextChannels = require(script.TextChannels)
local ChatTypes = require(MainModule.Shared.Network.Chat.Types)
local ChatCommands = require(MainModule.Shared.Chat.Commands)

local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local ServerUtils = require(MainModule.Shared.Utils.Game.ServerUtils)

local cosmeticService: any = nil
local diagnosticsService: any = nil
local classService: any = nil
local phaseService: any = nil
local hardpointService: any = nil
local getGroupLockService = LazyService.create(MainModule, "GroupLockService")
local getScreenWatchService = LazyService.create(MainModule, "ScreenWatchService")
local getJoinLogService = LazyService.create(MainModule, "JoinLogService")
local getStatsService = LazyService.create(MainModule, "StatsService")

type ChannelId = ChatTypes.ChannelId
type ChatMessage = ChatTypes.ChatMessage
type PlayerChatData = ChatTypes.PlayerChatData
type PlayerMeta = ChatTypes.PlayerMeta
type CacheEntry = { result: boolean, expiry: number, staleUntil: number }

local ChatService = {}
ChatService.ChatLogs = {} :: { { UserId: number, Text: string } }
ChatService.Name = "ChatService"

local systemMessageHistory: { [ChannelId]: { ChatMessage } } = {}
local channelAccess: { [number]: { [string]: boolean } } = {}
local playerBubbleVisibility: { [Player]: boolean } = {}
local connections: { RBXScriptConnection } = {}
local textSourceConnections: { [TextSource]: RBXScriptConnection } = {}
local externallyMutedPlayers: { [number]: boolean } = {}
local internalMuteOperations: { [number]: boolean } = {}
local lastPlayerCommand: { [Player]: { text: string, time: number } } = {}
local lastLeaveMessageAt: { [number]: number } = {}
local COMMAND_DEBOUNCE_INTERVAL = 0.5
local CHAT_LOG_WINDOW = 5
local CHAT_LOG_BURST = 5
local CHAT_LOG_MAX_LENGTH = 200

local chatLogWindows: { [Player]: { start: number, count: number } } = {}

local canUserChatCache: { [number]: CacheEntry } = {}
local canUsersDirectChatCache: { [string]: CacheEntry } = {}
local canUsersChatCache: { [string]: CacheEntry } = {}
local CHAT_ELIGIBILITY_CACHE_TTL = 60
local CHAT_ELIGIBILITY_NEGATIVE_TTL = 15
local CHAT_ELIGIBILITY_STALE_TTL = 900
local CHAT_ELIGIBILITY_MAX_ATTEMPTS = 4
local CHAT_ELIGIBILITY_RETRY_DELAY = 1
local CHAT_PREWARM_INITIAL_DELAY = 2
local CHAT_PREWARM_RETRY_DELAY = 2
local LEAVE_MESSAGE_COOLDOWN = 60

local COMMANDS_REMOVED_MESSAGE =
	"[ADMIN] Unknown command. Kohls commands have been removed, use the command bar (;) and type ‘help’ to see all commands. Still available in chat: :mute, :unmute, :rc, :skipphase, :end, :setpoints, !coinflip."

local function sendCommandsRemovedNotice(player: Player): ()
	ChatService:SendSystemMessage(nil, COMMANDS_REMOVED_MESSAGE, Color3.fromRGB(255, 220, 100), player)
end

local function generateMessageId(): string
	return HttpService:GenerateGUID(false)
end

local function getPlayerChatGradient(player: Player): ChatTypes.GradientConfig?
	if not cosmeticService then
		return nil
	end
	local resolved = cosmeticService:GetEquippedItem(player, "ChatGradient")
	if resolved and resolved.gradientColors and #resolved.gradientColors > 0 then
		return {
			colors = resolved.gradientColors,
			rotation = 0,
		}
	end
	return nil
end

local function logChat(player: Player, text: string): ()
	if game.PlaceId == 134407518396463 or game.PlaceId == 88634683432584 then
		return
	end
	local now = os.clock()
	local window = chatLogWindows[player]
	if not window or now - window.start >= CHAT_LOG_WINDOW then
		window = { start = now, count = 0 }
		chatLogWindows[player] = window
	end
	if window.count >= CHAT_LOG_BURST then
		return
	end
	window.count += 1

	text = string.gsub(text, "%c", " ")
	text = string.sub(text, 1, CHAT_LOG_MAX_LENGTH)

	local ok, filtered = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok or typeof(filtered) ~= "string" or filtered == "" then
		return
	end

	local logs = ChatService.ChatLogs
	table.insert(logs, { UserId = player.UserId, Text = `{player.Name}: {filtered}` })
	if #logs > 200 then
		table.move(logs, 2, #logs, 1)
		logs[#logs] = nil
	end

	local joinLogService = getJoinLogService()
	if joinLogService then
		joinLogService.LogChat(player, filtered)
	end
end

local function cacheResult<K>(store: { [K]: CacheEntry }, key: K, result: boolean): boolean
	local now = os.clock()
	local ttl = if result then CHAT_ELIGIBILITY_CACHE_TTL else CHAT_ELIGIBILITY_NEGATIVE_TTL
	local staleTtl = if result then CHAT_ELIGIBILITY_STALE_TTL else CHAT_ELIGIBILITY_NEGATIVE_TTL
	store[key] = { result = result, expiry = now + ttl, staleUntil = now + staleTtl }
	return result
end

local function readCache<K>(store: { [K]: CacheEntry }, key: K): boolean?
	local cached = store[key]
	if cached and cached.expiry > os.clock() then
		return cached.result
	end
	return nil
end

local function readCacheAllowStale<K>(store: { [K]: CacheEntry }, key: K): boolean?
	local cached = store[key]
	if not cached then
		return nil
	end
	if cached.staleUntil > os.clock() then
		return cached.result
	end
	return nil
end

local function canUserChat(userId: number): boolean
	local cached = readCache(canUserChatCache, userId)
	if cached ~= nil then
		return cached
	end

	if not Players:GetPlayerByUserId(userId) then
		return false
	end

	for attempt = 1, CHAT_ELIGIBILITY_MAX_ATTEMPTS do
		local success, result = pcall(function()
			return TextChatService:CanUserChatAsync(userId)
		end)

		if success then
			return cacheResult(canUserChatCache, userId, result == true)
		end

		if attempt < CHAT_ELIGIBILITY_MAX_ATTEMPTS then
			task.wait(CHAT_ELIGIBILITY_RETRY_DELAY)
		end
	end

	return false
end

local function canUsersDirectChat(requesterId: number, targetId: number): boolean
	local cacheKey = requesterId .. "_" .. targetId

	local cached = readCache(canUsersDirectChatCache, cacheKey)
	if cached ~= nil then
		return cached
	end

	if not Players:GetPlayerByUserId(requesterId) or not Players:GetPlayerByUserId(targetId) then
		return false
	end

	local success, eligibleUsers = pcall(function()
		return TextChatService:CanUsersDirectChatAsync(requesterId, { targetId })
	end)

	if not success then
		return false
	end

	local canChat = false
	if eligibleUsers then
		for _, eligibleId in eligibleUsers do
			if eligibleId == targetId then
				canChat = true
				break
			end
		end
	end

	return cacheResult(canUsersDirectChatCache, cacheKey, canChat)
end

local function canUsersChat(userIdFrom: number, userIdTo: number): boolean
	local cacheKey = userIdFrom .. "_" .. userIdTo

	local cached = readCache(canUsersChatCache, cacheKey)
	if cached ~= nil then
		return cached
	end

	if not Players:GetPlayerByUserId(userIdFrom) or not Players:GetPlayerByUserId(userIdTo) then
		return false
	end

	for attempt = 1, CHAT_ELIGIBILITY_MAX_ATTEMPTS do
		local success, result = pcall(function()
			return TextChatService:CanUsersChatAsync(userIdFrom, userIdTo)
		end)

		if success then
			return cacheResult(canUsersChatCache, cacheKey, result == true)
		end

		if attempt < CHAT_ELIGIBILITY_MAX_ATTEMPTS then
			task.wait(CHAT_ELIGIBILITY_RETRY_DELAY)
		end
	end

	return false
end

local function arePlayersDirectChatEligible(senderId: number, recipientId: number): boolean
	if senderId == recipientId then
		return true
	end
	if not canUsersDirectChat(senderId, recipientId) then
		return false
	end
	return canUsersDirectChat(recipientId, senderId)
end

local function arePlayersBroadcastChatEligible(senderId: number, recipientId: number): boolean
	if senderId == recipientId then
		return true
	end
	return canUsersChat(senderId, recipientId)
end

local function cachedCanUserChat(userId: number): boolean?
	return readCacheAllowStale(canUserChatCache, userId)
end

local function cachedBroadcastChatEligible(senderId: number, recipientId: number): boolean?
	return readCacheAllowStale(canUsersChatCache, senderId .. "_" .. recipientId)
end

local function cachedDirectChatEligible(senderId: number, recipientId: number): boolean?
	local forward = readCacheAllowStale(canUsersDirectChatCache, senderId .. "_" .. recipientId)
	if forward ~= true then
		return forward
	end
	return readCacheAllowStale(canUsersDirectChatCache, recipientId .. "_" .. senderId)
end

local function isEligibilityStale(userId: number, otherId: number): boolean
	return readCache(canUserChatCache, userId) == nil
		or readCache(canUserChatCache, otherId) == nil
		or readCache(canUsersChatCache, userId .. "_" .. otherId) == nil
end

local warmingPairs: { [string]: boolean } = {}

local function warmChatEligibility(senderId: number, recipientId: number): ()
	local key = senderId .. "_" .. recipientId
	if warmingPairs[key] then
		return
	end
	warmingPairs[key] = true

	task.spawn(function()
		pcall(function()
			canUserChat(senderId)
			canUserChat(recipientId)
			arePlayersBroadcastChatEligible(senderId, recipientId)
			arePlayersDirectChatEligible(senderId, recipientId)
		end)
		warmingPairs[key] = nil
	end)
end

local function refreshChannelAccess(player: Player): { ChannelId }
	local channels = ChatAuth.getVisibleChannels(player)
	local set: { [string]: boolean } = {}
	for _, channelId in channels do
		set[channelId] = true
	end
	channelAccess[player.UserId] = set
	return channels
end

local function hasChannelAccess(userId: number, channelId: string): boolean
	local set = channelAccess[userId]
	return set ~= nil and set[channelId] == true
end

local function getChannelRecipients(channelId: ChannelId, _sender: Player?): { Player }
	local recipients: { Player } = {}

	for _, player in Players:GetPlayers() do
		if ChatAuth.canAccessChannel(player, channelId) then
			table.insert(recipients, player)
		end
	end

	return recipients
end

local function addToHistory(channelId: ChannelId, message: ChatMessage): ()
	if not message.isSystem then
		return
	end

	local history = systemMessageHistory[channelId]
	if not history then
		history = {}
		systemMessageHistory[channelId] = history
	end

	table.insert(history, message)

	local overflow = #history - ChatConfig.Settings.messageHistorySize
	if overflow > 0 then
		table.move(history, overflow + 1, #history, 1)
		for i = #history, #history - overflow + 1, -1 do
			history[i] = nil
		end
	end
end

local function canUseRaidLeaderCommand(player: Player): boolean
	return ChatAuth.getAdminLevel(player) >= Constants.RANKS.SERGEANT
end

local function canUseRemoveClassCommand(player: Player): boolean
	if ChatAuth.getAdminLevel(player) >= Constants.RANKS.SERGEANT then
		return true
	end
	if ServerUtils.isPrivateServerOwner(player) then
		return true
	end
	return false
end

local function findPlayerByName(name: string): Player?
	local lowerName = string.lower(name)
	for _, p in Players:GetPlayers() do
		local lowerPlayerName = string.lower(p.Name)
		local lowerDisplayName = string.lower(p.DisplayName)
		if lowerPlayerName == lowerName or lowerDisplayName == lowerName then
			return p
		end
		if string.find(lowerPlayerName, lowerName, 1, true) or string.find(lowerDisplayName, lowerName, 1, true) then
			return p
		end
	end
	return nil
end

local function setTextSourceCanSend(userId: number, canSend: boolean): ()
	internalMuteOperations[userId] = true
	TextChannels.setCanSend(userId, canSend)
	task.delay(0.1, function()
		internalMuteOperations[userId] = nil
	end)
end

local function mutePlayerInTextChatService(player: Player): ()
	setTextSourceCanSend(player.UserId, false)
end

local function unmutePlayerInTextChatService(player: Player): ()
	if externallyMutedPlayers[player.UserId] then
		return
	end
	ChatService:RefreshSendPermissions(player)
end

local coinflipRng = Random.new()

type CommandHandler = (player: Player, args: string) -> boolean

local function requireTargetPlayer(player: Player, args: string, usage: string): Player?
	local targetName = string.match(args, "^(%S+)")
	if not targetName then
		ChatService:SendSystemMessage(nil, usage, Color3.fromRGB(255, 200, 100), player)
		return nil
	end
	local targetPlayer = findPlayerByName(targetName)
	if not targetPlayer then
		ChatService:SendSystemMessage(nil, "[SYSTEM] Cannot find that player.", Color3.fromRGB(255, 100, 100), player)
		return nil
	end
	return targetPlayer
end

local PERMISSION_DENIED_COLOR = Color3.fromRGB(255, 100, 100)

local function guardPermission(player: Player, checkFn: (Player) -> boolean, message: string?): boolean
	if checkFn(player) then
		return true
	end
	ChatService:SendSystemMessage(nil, message or "[SYSTEM] You do not have permission to use this command.", PERMISSION_DENIED_COLOR, player)
	return false
end

local function commandRaidLeader(player: Player, args: string): boolean
	if not guardPermission(player, canUseRaidLeaderCommand) then
		return true
	end
	local targetPlayer = requireTargetPlayer(player, args, "[SYSTEM] Usage: :rl <username>")
	if not targetPlayer then
		return true
	end
	if ChatAuth.isRaidLeader(targetPlayer) then
		ChatService:SendSystemMessage(
			nil,
			string.format("[SYSTEM] %s is already a raid leader.", targetPlayer.DisplayName),
			Color3.fromRGB(255, 200, 100),
			player
		)
		return true
	end
	ChatService:SetRaidLeader(targetPlayer, true, player)
	return true
end

local function commandUnraidLeader(player: Player, args: string): boolean
	if not guardPermission(player, canUseRaidLeaderCommand) then
		return true
	end
	local targetPlayer = requireTargetPlayer(player, args, "[SYSTEM] Usage: :unrl <username>")
	if not targetPlayer then
		return true
	end
	if not ChatAuth.isRaidLeader(targetPlayer) then
		ChatService:SendSystemMessage(nil, string.format("[SYSTEM] %s is not a raid leader.", targetPlayer.DisplayName), Color3.fromRGB(255, 200, 100), player)
		return true
	end
	ChatService:SetRaidLeader(targetPlayer, false, player)
	return true
end

local function commandMute(player: Player, args: string): boolean
	local targetPlayer = requireTargetPlayer(player, args, "[SYSTEM] Usage: :mute <username>")
	if not targetPlayer then
		return true
	end
	if targetPlayer == player then
		ChatService:SendSystemMessage(nil, "[SYSTEM] You cannot mute yourself.", Color3.fromRGB(255, 100, 100), player)
		return true
	end
	if not ChatAuth.canMutePlayer(player, targetPlayer) then
		ChatService:SendSystemMessage(nil, "[SYSTEM] You do not have permission to mute this player.", PERMISSION_DENIED_COLOR, player)
		return true
	end
	if ChatAuth.isPlayerMuted(targetPlayer) then
		ChatService:SendSystemMessage(nil, string.format("[SYSTEM] %s is already muted.", targetPlayer.DisplayName), Color3.fromRGB(255, 200, 100), player)
		return true
	end
	ChatAuth.mutePlayer(targetPlayer)
	mutePlayerInTextChatService(targetPlayer)
	Network.Chat.sendMuteStatus(targetPlayer, true)
	ChatService:SendSystemMessage(nil, string.format("[SYSTEM] %s has been muted.", targetPlayer.DisplayName), Color3.fromRGB(255, 150, 100), player)
	ChatService:SendSystemMessage(nil, "[SYSTEM] You have been muted.", Color3.fromRGB(255, 100, 100), targetPlayer)
	return true
end

local function commandUnmute(player: Player, args: string): boolean
	local targetPlayer = requireTargetPlayer(player, args, "[SYSTEM] Usage: :unmute <username>")
	if not targetPlayer then
		return true
	end
	if not ChatAuth.canMutePlayer(player, targetPlayer) then
		ChatService:SendSystemMessage(nil, "[SYSTEM] You do not have permission to unmute this player.", PERMISSION_DENIED_COLOR, player)
		return true
	end
	if not ChatAuth.isPlayerMuted(targetPlayer) then
		ChatService:SendSystemMessage(nil, string.format("[SYSTEM] %s is not muted.", targetPlayer.DisplayName), Color3.fromRGB(255, 200, 100), player)
		return true
	end
	ChatAuth.unmutePlayer(targetPlayer)
	unmutePlayerInTextChatService(targetPlayer)
	Network.Chat.sendMuteStatus(targetPlayer, false)
	ChatService:SendSystemMessage(nil, string.format("[SYSTEM] %s has been unmuted.", targetPlayer.DisplayName), Color3.fromRGB(255, 220, 100), player)
	ChatService:SendSystemMessage(nil, "[SYSTEM] You have been unmuted.", Color3.fromRGB(100, 255, 100), targetPlayer)
	return true
end

local function commandDump(player: Player, args: string): boolean
	if ChatAuth.getAdminLevel(player) < 250 then
		ChatService:SendSystemMessage(nil, "[SYSTEM] You do not have permission to use this command.", PERMISSION_DENIED_COLOR, player)
		return true
	end
	local targetPlayer = requireTargetPlayer(player, args, "[SYSTEM] Usage: :dump <username>")
	if not targetPlayer then
		return true
	end
	if diagnosticsService then
		diagnosticsService:RequestDump(player, targetPlayer)
	end
	return true
end

local function commandRemoveClass(player: Player, args: string): boolean
	if not guardPermission(player, canUseRemoveClassCommand) then
		return true
	end
	local targetPlayer = requireTargetPlayer(player, args, "[SYSTEM] Usage: :rc <username>")
	if not targetPlayer then
		return true
	end
	if not classService then
		ChatService:SendSystemMessage(nil, "[SYSTEM] Class system unavailable.", Color3.fromRGB(255, 100, 100), player)
		return true
	end
	if classService:GetPlayerClass(targetPlayer) == "Assault" then
		ChatService:SendSystemMessage(nil, string.format("[SYSTEM] %s is already on Assault.", targetPlayer.DisplayName), Color3.fromRGB(255, 200, 100), player)
		return true
	end
	local success = classService:SetPlayerClass(targetPlayer, "Assault")
	if success then
		ChatService:SendSystemMessage(
			nil,
			string.format("[SYSTEM] %s has been reset to Assault.", targetPlayer.DisplayName),
			Color3.fromRGB(100, 255, 100),
			player
		)
		ChatService:SendSystemMessage(nil, "[SYSTEM] Your class has been reset to Assault.", Color3.fromRGB(255, 200, 100), targetPlayer)
	else
		ChatService:SendSystemMessage(
			nil,
			string.format("[SYSTEM] Failed to reset %s's class.", targetPlayer.DisplayName),
			Color3.fromRGB(255, 100, 100),
			player
		)
	end
	return true
end

local function commandSkipPhase(player: Player, _args: string): boolean
	if not guardPermission(player, canUseRemoveClassCommand) then
		return true
	end
	if not phaseService or not phaseService:IsActive() then
		ChatService:SendSystemMessage(nil, "[SYSTEM] Phase system is not active on this map.", Color3.fromRGB(255, 100, 100), player)
		return true
	end
	if not phaseService:IsOfficial() then
		ChatService:SendSystemMessage(nil, "[SYSTEM] No active phase game running.", Color3.fromRGB(255, 100, 100), player)
		return true
	end
	if phaseService:GetCurrentPhase() == "phase3" then
		ChatService:SendSystemMessage(nil, "[SYSTEM] Cannot skip phase on the final phase, do :end to end the event.", Color3.fromRGB(255, 100, 100), player)
		return true
	end

	local economySvc = ServiceLocator.Economy()
	if economySvc then
		economySvc:FlagMatchTampered(`Command :skipphase used by {player.Name}`)
	end

	phaseService:SkipPhase(player)
	return true
end

local function commandEndGame(player: Player, args: string): boolean
	if not guardPermission(player, canUseRemoveClassCommand) then
		return true
	end
	if not phaseService or not phaseService:IsActive() then
		ChatService:SendSystemMessage(nil, "[SYSTEM] Phase system is not active on this map.", Color3.fromRGB(255, 100, 100), player)
		return true
	end
	if not phaseService:IsOfficial() then
		ChatService:SendSystemMessage(nil, "[SYSTEM] No active phase game to end.", Color3.fromRGB(255, 100, 100), player)
		return true
	end

	local economySvc = ServiceLocator.Economy()
	if economySvc then
		economySvc:FlagMatchTampered(`Command :end used by {player.Name}`)
	end

	local winnerArg = string.match(args, "^(%S+)")
	local winnerFaction: string? = nil
	if winnerArg and string.lower(winnerArg) == "raiders" then
		winnerFaction = "Raiders"
	end
	phaseService:EndGame(winnerFaction)
	ChatService:SendSystemMessage(nil, string.format("[SYSTEM] %s ended the event.", player.DisplayName), Color3.fromRGB(255, 200, 100))
	return true
end

local function commandScreenWatch(player: Player, args: string): boolean
	local screenWatchService = getScreenWatchService()
	if not screenWatchService or not screenWatchService:IsAuthorized(player) then
		ChatService:SendSystemMessage(nil, "[SYSTEM] You do not have permission to use Screenwatch.", PERMISSION_DENIED_COLOR, player)
		return true
	end
	local targetArg = string.match(args, "^(%S+)")
	if not targetArg or targetArg == "" then
		screenWatchService:OpenSelectMenu(player)
		return true
	end
	local targetPlayer: Player? = nil
	if targetArg and string.lower(targetArg) == "me" then
		targetPlayer = player
	else
		targetPlayer = requireTargetPlayer(player, args, "[SYSTEM] Usage: :sw <username> or :sw")
	end
	if not targetPlayer then
		return true
	end
	screenWatchService:StartWatch(player, targetPlayer)
	return true
end

local function commandCoinFlip(player: Player, _args: string): boolean
	if not canUseRemoveClassCommand(player) then
		ChatService:SendSystemMessage(nil, "[SYSTEM] You are not authorized to use this command.", Color3.fromRGB(255, 100, 100), player)
		return true
	end
	local result = if coinflipRng:NextInteger(0, 1) == 0 then "HEADS" else "TAILS"
	ChatService:SendSystemMessage(
		nil,
		string.format("[COINFLIP] %s flipped a coin, it landed on %s!", player.DisplayName, result),
		Color3.fromRGB(255, 220, 100)
	)
	return true
end

local function commandSetPoints(player: Player, args: string): boolean
	if not guardPermission(player, canUseRemoveClassCommand) then
		return true
	end
	local pointsStr = string.match(args, "^(%d+)%s*$")
	if not pointsStr then
		ChatService:SendSystemMessage(nil, "[SYSTEM] Usage: :setpoints <number>", Color3.fromRGB(255, 200, 100), player)
		return true
	end
	local points = tonumber(pointsStr)
	if not points then
		return true
	end
	local clampedPoints = math.clamp(points, 100, 10000)

	local economySvc = ServiceLocator.Economy()
	if economySvc then
		economySvc:FlagMatchTampered(`Command :setpoints used by {player.Name}`)
	end

	if hardpointService then
		hardpointService:SetMaxPoints(clampedPoints)
	end
	ChatService:SendSystemMessage(
		nil,
		string.format("[SYSTEM] %s has updated the terminal's max points to %d.", player.DisplayName, clampedPoints),
		Color3.fromRGB(255, 220, 100)
	)
	return true
end

local commandDispatch: { [string]: CommandHandler } = {
	["rl"] = commandRaidLeader,
	["raidleader"] = commandRaidLeader,
	["unrl"] = commandUnraidLeader,
	["unraidleader"] = commandUnraidLeader,
	["mute"] = commandMute,
	["unmute"] = commandUnmute,
	["dump"] = commandDump,
	["rc"] = commandRemoveClass,
	["removeclass"] = commandRemoveClass,
	["skipphase"] = commandSkipPhase,
	["end"] = commandEndGame,
	["screenwatch"] = commandScreenWatch,
	["sw"] = commandScreenWatch,
	["ws"] = commandScreenWatch,
	["watchscreen"] = commandScreenWatch,
	["coinflip"] = commandCoinFlip,
	["cf"] = commandCoinFlip,
	["setpoints"] = commandSetPoints,
	["grouplock"] = function(player: Player, args: string): boolean
		local svc = getGroupLockService()
		return if svc then svc:HandleGroupLock(player, args) else false
	end,
	["gl"] = function(player: Player, args: string): boolean
		local svc = getGroupLockService()
		return if svc then svc:HandleGroupLock(player, args) else false
	end,
	["ungrouplock"] = function(player: Player, _args: string): boolean
		local svc = getGroupLockService()
		return if svc then svc:HandleUnGroupLock(player, _args) else false
	end,
	["ungl"] = function(player: Player, _args: string): boolean
		local svc = getGroupLockService()
		return if svc then svc:HandleUnGroupLock(player, _args) else false
	end,
}

local function handleCommand(player: Player, content: string): boolean
	local command, args = string.match(content, "^[:!](%w+)%s*(.*)")
	if not command then
		return false
	end
	local handler = commandDispatch[string.lower(command)]
	if not handler then
		return false
	end

	local now = os.clock()
	local last = lastPlayerCommand[player]
	if last and last.text == content and (now - last.time) < COMMAND_DEBOUNCE_INTERVAL then
		return true
	end
	lastPlayerCommand[player] = { text = content, time = now }

	return handler(player, args)
end

local function getPlayerTeamName(player: Player): string?
	if player.Team then
		return player.Team.Name
	end
	return nil
end

local function getPlayerFaction(player: Player): string?
	local teamName = getPlayerTeamName(player)
	if not teamName then
		return nil
	end
	if Constants.FACTIONS.DEFENDER_TEAMS[teamName] then
		return "Defenders"
	end
	if Constants.FACTIONS.RAIDER_TEAMS[teamName] then
		return "Raiders"
	end
	return nil
end

local function applySendPermissions(player: Player): ()
	local userId = player.UserId
	local muted = ChatAuth.isPlayerMuted(player) or externallyMutedPlayers[userId] == true

	internalMuteOperations[userId] = true
	TextChannels.applyPermissions(userId, function(descriptor: TextChannels.Descriptor): boolean
		if muted then
			return false
		end

		if descriptor.kind == "game" then
			local channelId = descriptor.channelId
			if not channelId then
				return false
			end
			return hasChannelAccess(userId, channelId)
		elseif descriptor.kind == "team" then
			return getPlayerFaction(player) == descriptor.faction
		elseif descriptor.kind == "whisper" then
			local participants = descriptor.participants
			return participants ~= nil and table.find(participants, userId) ~= nil
		end

		return false
	end)
	task.delay(0.1, function()
		internalMuteOperations[userId] = nil
	end)
end

local function handleTextSourceCanSendChanged(textSource: TextSource): ()
	local userId = textSource.UserId

	if internalMuteOperations[userId] then
		return
	end

	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end

	local canSend = textSource.CanSend

	if not canSend then
		if externallyMutedPlayers[userId] then
			return
		end
		externallyMutedPlayers[userId] = true
		Network.Chat.sendMuteStatus(player, true)
		return
	end

	if externallyMutedPlayers[userId] then
		externallyMutedPlayers[userId] = nil
		applySendPermissions(player)
		if not ChatAuth.isPlayerMuted(player) then
			Network.Chat.sendMuteStatus(player, false)
		end
	end
end

local function watchPlayerSources(player: Player): ()
	local userId = player.UserId

	for _, source in TextChannels.getSources(userId) do
		if not textSourceConnections[source] then
			local connection = source:GetPropertyChangedSignal("CanSend"):Connect(function()
				handleTextSourceCanSendChanged(source)
			end)
			textSourceConnections[source] = connection
		end
	end
end

local function buildPlayerMeta(player: Player): PlayerMeta
	local chatData = ChatAuth.getPlayerChatData(player)
	local rolePrefix, roleColor = ChatAuth.getPlayerRole(player)

	local bubbleEveryone = playerBubbleVisibility[player]
	if bubbleEveryone == nil then
		bubbleEveryone = true
	end

	return {
		userId = player.UserId,
		bubbleEveryone = bubbleEveryone,
		tags = chatData.tags,
		nameColor = chatData.nameColor,
		rolePrefix = rolePrefix,
		roleColor = roleColor,
		gradient = getPlayerChatGradient(player),
	}
end

local function broadcastPlayerMeta(player: Player): ()
	Network.Chat.broadcastPlayerMeta(Players:GetPlayers(), { buildPlayerMeta(player) })
end

local function pushPlayerMetaSnapshot(player: Player): ()
	local entries: { PlayerMeta } = {}
	for _, other in Players:GetPlayers() do
		table.insert(entries, buildPlayerMeta(other))
	end
	Network.Chat.broadcastPlayerMeta({ player }, entries)
end

local function shouldDeliverMessage(message: TextChatMessage, target: TextSource, descriptor: TextChannels.Descriptor): boolean
	local source = message.TextSource
	if not source then
		return false
	end

	local senderId = source.UserId
	local recipientId = target.UserId

	local sender = Players:GetPlayerByUserId(senderId)
	local recipient = Players:GetPlayerByUserId(recipientId)
	if not sender or not recipient then
		return false
	end

	if ChatAuth.isPlayerMuted(sender) or externallyMutedPlayers[senderId] then
		return false
	end

	if descriptor.kind == "game" then
		local rawChannelId = descriptor.channelId
		if not rawChannelId then
			return false
		end
		if not hasChannelAccess(senderId, rawChannelId) then
			return false
		end
		if not hasChannelAccess(recipientId, rawChannelId) then
			return false
		end
	elseif descriptor.kind == "team" then
		local faction = descriptor.faction
		if not faction then
			return false
		end
		if getPlayerFaction(sender) ~= faction or getPlayerFaction(recipient) ~= faction then
			return false
		end
	elseif descriptor.kind == "whisper" then
		local participants = descriptor.participants
		if not participants then
			return false
		end
		if not table.find(participants, senderId) or not table.find(participants, recipientId) then
			return false
		end
	else
		return false
	end

	if senderId == recipientId then
		return true
	end

	if isEligibilityStale(senderId, recipientId) then
		warmChatEligibility(senderId, recipientId)
	end

	if cachedCanUserChat(senderId) ~= true or cachedCanUserChat(recipientId) ~= true then
		return false
	end

	if descriptor.kind == "whisper" then
		return cachedDirectChatEligible(senderId, recipientId) == true
	end

	return cachedBroadcastChatEligible(senderId, recipientId) == true
end

local function onBubbleVisibilityChanged(player: Player, everyone: boolean): ()
	playerBubbleVisibility[player] = everyone
	task.spawn(broadcastPlayerMeta, player)
end

local function onCommand(player: Player, text: string): ()
	if typeof(text) ~= "string" then
		return
	end
	if #text == 0 or #text > ChatConfig.Settings.maxMessageLength then
		return
	end

	if not ChatCommands.isAdminCommand(text) then
		if ChatCommands.looksLikeCommand(text) and not ChatCommands.isBuiltInCommand(text) then
			sendCommandsRemovedNotice(player)
		end
		return
	end

	handleCommand(player, text)
end

local function onGetPlayerData(player: Player): PlayerChatData
	return ChatAuth.getPlayerChatData(player)
end

local function onGetSystemHistory(player: Player, channelId: ChannelId): { ChatMessage }
	if typeof(channelId) ~= "string" then
		return {}
	end

	if not ChatAuth.canAccessChannel(player, channelId) then
		return {}
	end

	local history = systemMessageHistory[channelId]
	if not history then
		return {}
	end

	return table.clone(history)
end

local function onGetPlayerMeta(_player: Player): { PlayerMeta }
	local entries: { PlayerMeta } = {}
	for _, other in Players:GetPlayers() do
		table.insert(entries, buildPlayerMeta(other))
	end
	return entries
end

local function onWhisperChannelRequested(player: Player, targetUserId: number): string?
	if typeof(targetUserId) ~= "number" or targetUserId <= 0 then
		return nil
	end

	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return nil
	end

	if ChatAuth.isPlayerMuted(player) then
		ChatService:SendSystemMessage(nil, "[SYSTEM] You are muted and cannot send messages.", Color3.fromRGB(255, 100, 100), player)
		return nil
	end

	if not canUserChat(player.UserId) then
		ChatService:SendSystemMessage(nil, "[SYSTEM] Chat is not available for your account.", Color3.fromRGB(255, 100, 100), player)
		return nil
	end

	if not canUserChat(targetUserId) then
		ChatService:SendSystemMessage(nil, "[SYSTEM] This player cannot receive private messages.", Color3.fromRGB(255, 100, 100), player)
		return nil
	end

	if not arePlayersDirectChatEligible(player.UserId, targetUserId) then
		ChatService:SendSystemMessage(
			nil,
			"[SYSTEM] You cannot send private messages to this player due to privacy settings.",
			Color3.fromRGB(255, 100, 100),
			player
		)
		return nil
	end

	local channelName = TextChannels.ensureWhisper(player, targetUserId)
	if channelName then
		applySendPermissions(player)
		applySendPermissions(target)
	end
	return channelName
end

local function onPlayerRemoving(player: Player): ()
	local userId = player.UserId
	local statsService = getStatsService()
	local stats = if statsService then statsService:GetFinalStatsByUserId(userId) else nil
	playerBubbleVisibility[player] = nil
	lastPlayerCommand[player] = nil
	chatLogWindows[player] = nil
	externallyMutedPlayers[userId] = nil
	internalMuteOperations[userId] = nil
	canUserChatCache[userId] = nil
	channelAccess[userId] = nil

	if
		stats
		and stats.Kills + stats.Damage + stats.Heals + stats.Captures > 0
		and os.clock() - (lastLeaveMessageAt[userId] or -LEAVE_MESSAGE_COOLDOWN) >= LEAVE_MESSAGE_COOLDOWN
	then
		lastLeaveMessageAt[userId] = os.clock()
		ChatService:SendSystemMessage(
			nil,
			`[SYSTEM] {player.Name} left: {stats.Kills}K / {math.round(stats.Damage)}D / {math.round(stats.Heals)}H / {stats.Captures}C`,
			Color3.fromRGB(255, 100, 100)
		)
	end

	for source, connection in textSourceConnections do
		if source.UserId == userId then
			connection:Disconnect()
			textSourceConnections[source] = nil
		end
	end
	TextChannels.removePlayer(userId)

	local userIdStr = tostring(userId)

	local directChatKeysToRemove: { string } = {}
	for cacheKey in canUsersDirectChatCache do
		local sep = string.find(cacheKey, "_", 1, true)
		if sep then
			local id1 = cacheKey:sub(1, sep - 1)
			local id2 = cacheKey:sub(sep + 1)
			if id1 == userIdStr or id2 == userIdStr then
				table.insert(directChatKeysToRemove, cacheKey)
			end
		end
	end
	for _, key in directChatKeysToRemove do
		canUsersDirectChatCache[key] = nil
	end

	local chatKeysToRemove: { string } = {}
	for cacheKey in canUsersChatCache do
		local sep = string.find(cacheKey, "_", 1, true)
		if sep then
			local id1 = cacheKey:sub(1, sep - 1)
			local id2 = cacheKey:sub(sep + 1)
			if id1 == userIdStr or id2 == userIdStr then
				table.insert(chatKeysToRemove, cacheKey)
			end
		end
	end
	for _, key in chatKeysToRemove do
		canUsersChatCache[key] = nil
	end

	ChatAuth.clearPlayerCache(player)
end

local function computeCompatCount(userId: number, otherPlayers: { Player }): number
	local compatCount = 0
	for _, otherPlayer in otherPlayers do
		local otherUserId = otherPlayer.UserId
		local otherCanChat = canUserChat(otherUserId)
		local mutuallyEligible = arePlayersBroadcastChatEligible(userId, otherUserId)
		if otherCanChat and mutuallyEligible then
			compatCount += 1
		end
	end
	return compatCount
end

local function runChatEligibilityReport(player: Player): ()
	local userId = player.UserId

	if not player.Parent then
		return
	end

	local selfCanChat = canUserChat(userId)

	local otherPlayers: { Player } = {}
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player then
			table.insert(otherPlayers, otherPlayer)
		end
	end
	local totalOthers = #otherPlayers

	if not selfCanChat then
		ChatService:SendSystemMessage(
			nil,
			"[SYSTEM] Chat is not available for your account. Please complete age verification.",
			Color3.fromRGB(255, 100, 100),
			player
		)
		return
	end

	local compatCount = computeCompatCount(userId, otherPlayers)

	if compatCount == 0 and totalOthers > 0 then
		task.wait(CHAT_PREWARM_RETRY_DELAY)
		if not player.Parent then
			return
		end
		compatCount = computeCompatCount(userId, otherPlayers)
	end

	local compatColor = if compatCount == totalOthers then Color3.fromRGB(100, 255, 100) else Color3.fromRGB(255, 220, 100)
	local message = if totalOthers > 0
		then string.format("[SYSTEM] You can chat with %d out of %d players in this server due to Roblox age group restrictions.", compatCount, totalOthers)
		else "[SYSTEM] You are the only player in this server. Age group restrictions apply when other players join."

	ChatService:SendSystemMessage(nil, message, compatColor, player)
end

local function prewarmChatEligibility(player: Player): ()
	task.spawn(function()
		task.wait(CHAT_PREWARM_INITIAL_DELAY)
		runChatEligibilityReport(player)
	end)
end

local function onPlayerAdded(player: Player): ()
	task.spawn(function()
		refreshChannelAccess(player)
		TextChannels.addPlayer(player.UserId)
		local userId = player.UserId
		local blocked = false
		for _, source in TextChannels.getSources(userId) do
			if not source.CanSend then
				blocked = true
			end
		end
		if not canUserChat(userId) then
			blocked = true
		end
		if player.Parent ~= Players then
			return
		end
		if blocked then
			externallyMutedPlayers[userId] = true
		end
		applySendPermissions(player)
		watchPlayerSources(player)

		table.insert(
			connections,
			player:GetPropertyChangedSignal("Team"):Connect(function()
				applySendPermissions(player)
			end)
		)
		table.insert(
			connections,
			player.Chatted:Connect(function(text)
				logChat(player, text)
			end)
		)
		broadcastPlayerMeta(player)
		pushPlayerMetaSnapshot(player)
	end)
	prewarmChatEligibility(player)
end

function ChatService:SetRaidLeader(player: Player, isLeader: boolean, notifyPlayer: Player?): ()
	if ChatAuth.isRaidLeader(player) == isLeader then
		return
	end
	ChatAuth.setRaidLeader(player, isLeader)

	local newChannels = refreshChannelAccess(player)
	applySendPermissions(player)
	if isLeader then
		Network.Chat.sendChannelsUpdate(player, newChannels, nil)
		ChatService:SendSystemMessage(nil, "[SYSTEM] You have been made a raid leader. RAID channel is now available.", Color3.fromRGB(100, 255, 150), player)

		local raidMessage = if notifyPlayer
			then string.format("[SYSTEM] %s has been added as the raid leader by %s.", player.DisplayName, notifyPlayer.DisplayName)
			else string.format("[SYSTEM] %s has been added as the raid leader.", player.DisplayName)
		ChatService:SendSystemMessage("RAID", raidMessage, Color3.fromRGB(100, 255, 150), nil)
	else
		local raidMessage = if notifyPlayer
			then string.format("[SYSTEM] %s has been removed as the raid leader by %s.", player.DisplayName, notifyPlayer.DisplayName)
			else string.format("[SYSTEM] %s has been removed as the raid leader.", player.DisplayName)
		ChatService:SendSystemMessage("RAID", raidMessage, Color3.fromRGB(255, 150, 100), nil)

		Network.Chat.sendChannelsUpdate(player, newChannels, "GLOBAL")
		ChatService:SendSystemMessage(nil, "[SYSTEM] You have been removed as raid leader.", Color3.fromRGB(255, 150, 100), player)
	end

	if notifyPlayer then
		if isLeader then
			ChatService:SendSystemMessage(
				nil,
				string.format("[SYSTEM] %s has been made the raid leader.", player.DisplayName),
				Color3.fromRGB(255, 220, 100),
				notifyPlayer
			)
		else
			ChatService:SendSystemMessage(
				nil,
				string.format("[SYSTEM] %s has been removed as raid leader.", player.DisplayName),
				Color3.fromRGB(255, 150, 100),
				notifyPlayer
			)
		end
	end
end

function ChatService:IsRaidLeader(player: Player): boolean
	return ChatAuth.isRaidLeader(player)
end

function ChatService:SendSystemMessage(channelId: ChannelId?, content: string, color: Color3?, recipient: Player?, tags: { string }?): ()
	local targetChannel: ChannelId = channelId or "GLOBAL"
	local recipients: { Player }

	if recipient then
		recipients = { recipient }
	elseif channelId then
		recipients = getChannelRecipients(channelId)
	else
		recipients = Players:GetPlayers()
	end

	local systemMessage: ChatMessage = {
		id = generateMessageId(),
		channelId = targetChannel,
		senderId = 0,
		senderName = "SYSTEM",
		senderDisplayName = "SYSTEM",
		content = content,
		timestamp = os.time(),
		tags = tags or {},
		nameColor = color or ChatConfig.Settings.systemMessageColor,
		isSystem = true,
	}

	if not recipient then
		addToHistory(targetChannel, systemMessage)
	end

	Network.Chat.broadcastSystemChatMessage(recipients, systemMessage)
end

type GradientConfig = {
	colors: { Color3 },
	rotation: number?,
}

function ChatService:SendGradientSystemMessage(channelId: ChannelId?, content: string, gradient: GradientConfig?, recipient: Player?, tags: { string }?): ()
	local targetChannel: ChannelId = channelId or "GLOBAL"
	local recipients: { Player }

	if recipient then
		recipients = { recipient }
	elseif channelId then
		recipients = getChannelRecipients(channelId)
	else
		recipients = Players:GetPlayers()
	end

	local systemMessage: ChatMessage = {
		id = generateMessageId(),
		channelId = targetChannel,
		senderId = 0,
		senderName = "SYSTEM",
		senderDisplayName = "SYSTEM",
		content = content,
		timestamp = os.time(),
		tags = tags or {},
		nameColor = ChatConfig.Settings.systemMessageColor,
		isSystem = true,
		gradient = gradient,
	}

	if not recipient then
		addToHistory(targetChannel, systemMessage)
	end

	Network.Chat.broadcastSystemChatMessage(recipients, systemMessage)
end

function ChatService:GetPlayerChatData(player: Player): PlayerChatData
	return ChatAuth.getPlayerChatData(player)
end

function ChatService:RefreshPlayerPermissions(player: Player): ()
	ChatAuth.refreshPlayerCache(player)
	Network.Chat.sendChannelsUpdate(player, refreshChannelAccess(player), nil)
	applySendPermissions(player)
	broadcastPlayerMeta(player)
end

function ChatService:RefreshPlayerMeta(player: Player): ()
	broadcastPlayerMeta(player)
end

function ChatService:RefreshSendPermissions(player: Player): ()
	applySendPermissions(player)
end

function ChatService:init(): ()
	for _, channel in ChatConfig.Channels do
		systemMessageHistory[channel.id :: ChannelId] = {}
	end
end

function ChatService:start(): ()
	cosmeticService = LazyService.create(MainModule, "CosmeticService")()
	diagnosticsService = LazyService.create(MainModule, "DiagnosticsService")()
	classService = LazyService.create(MainModule, "ClassService")()
	phaseService = LazyService.create(MainModule, "PhaseService")()
	hardpointService = LazyService.create(MainModule, "HardpointService")()

	TextChannels.ensure()
	TextChannels.setDeliveryPolicy(shouldDeliverMessage)

	Network.Chat.onCommandReceived(onCommand)
	Network.Chat.onGetPlayerData(onGetPlayerData)
	Network.Chat.onGetPlayerMeta(onGetPlayerMeta)
	Network.Chat.onGetSystemHistory(onGetSystemHistory)
	Network.Chat.onBubbleVisibilityChanged(onBubbleVisibilityChanged)
	Network.Chat.onWhisperChannelRequested(onWhisperChannelRequested)

	if cosmeticService and typeof(cosmeticService.OnCosmeticChanged) == "function" then
		cosmeticService:OnCosmeticChanged(function(player: Player, category: string, _itemId: string)
			if category == "ChatGradient" then
				task.spawn(broadcastPlayerMeta, player)
			end
		end)
	end

	table.insert(connections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(connections, Players.PlayerRemoving:Connect(onPlayerRemoving))

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

function ChatService:Cleanup(): ()
	for _, conn in connections do
		conn:Disconnect()
	end
	for _, conn in textSourceConnections do
		conn:Disconnect()
	end
	table.clear(connections)
	table.clear(textSourceConnections)
	table.clear(systemMessageHistory)
	table.clear(channelAccess)
	table.clear(playerBubbleVisibility)
	table.clear(externallyMutedPlayers)
	table.clear(internalMuteOperations)
	table.clear(lastPlayerCommand)
	TextChannels.cleanup()
	table.clear(chatLogWindows)
	table.clear(canUserChatCache)
	table.clear(canUsersDirectChatCache)
	table.clear(canUsersChatCache)
end

return ChatService
