--!strict
--!native
--!optimize 2

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LogBlacklist = require(script.Parent.Parent.Parent.Shared.Config.LogBlacklist)

local JoinLogService = {
	Joined = {},
	Left = {},
}
JoinLogService.Name = "JoinLogService"

type Kind = "join" | "leave" | "chat" | "rewards" | "purchases" | "crates" | "jackpots" | "alerts"

export type MatchRewardEntry = {
	player: Player,
	credits: number,
	won: boolean,
}

export type CrateDropEntry = {
	id: string,
	skinId: string?,
	packName: string?,
	rarity: string,
	isDuplicate: boolean,
}

type Embed = {
	title: string,
	description: string,
	color: number,
	footer: { text: string },
	timestamp: string,
}

local WEBHOOK_URL = "REPLACE_WITH_YOUR_WEBHOOK_URL"
local CHAT_WEBHOOK_URL = "REPLACE_WITH_YOUR_WEBHOOK_URL"
local ECONOMY_WEBHOOK_URL =
	"REPLACE_WITH_YOUR_WEBHOOK_URL"
local FLUSH_INTERVAL = 15
local FLUSH_JITTER = 5
local CLOSE_WAIT = 10
local MAX_DESCRIPTION_LENGTH = 2700
local MAX_QUEUED_LINES = 300

local KINDS: { Kind } = { "join", "leave", "chat", "rewards", "purchases", "crates", "jackpots", "alerts" }

local WEBHOOK_GROUPS: { { url: string, kinds: { Kind } } } = {
	{ url = WEBHOOK_URL, kinds = { "join", "leave" } },
	{ url = ECONOMY_WEBHOOK_URL, kinds = { "alerts", "jackpots" } },
	{ url = ECONOMY_WEBHOOK_URL, kinds = { "rewards" } },
	{ url = ECONOMY_WEBHOOK_URL, kinds = { "purchases", "crates" } },
	{ url = CHAT_WEBHOOK_URL, kinds = { "chat" } },
}

local KIND_STYLE = {
	join = { title = "Joined", color = 0x57F287 },
	leave = { title = "Left", color = 0xED4245 },
	chat = { title = "Chat", color = 0x5865F2 },
	rewards = { title = "Match Rewards", color = 0xFEE75C },
	purchases = { title = "Credit Purchases", color = 0x57F287 },
	crates = { title = "Crate Opens", color = 0x9B59B6 },
	jackpots = { title = "Mythic Pulls", color = 0xF0F0F5 },
	alerts = { title = "Economy Alerts", color = 0xED4245 },
} :: { [Kind]: { title: string, color: number } }

local rng = Random.new()
local placeName = ""
local joinTimes: { [number]: number } = {}
local queues = {
	join = {},
	leave = {},
	chat = {},
	rewards = {},
	purchases = {},
	crates = {},
	jackpots = {},
	alerts = {},
} :: { [Kind]: { string } }
local connections: { RBXScriptConnection } = {}
local flushThread: thread? = nil
local flushing = false
local started = false

local function getPlaceName(): string
	if placeName ~= "" then
		return placeName
	end

	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)

	if ok and info and info.Name then
		placeName = info.Name
		return placeName
	end

	return "Unknown"
end

local function escapeMarkdown(text: string): string
	return (string.gsub(text, "[\\%*_~`|>%[%]]", "\\%0"))
end

local function formatDuration(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60

	if hours > 0 then
		return string.format("%dh %02dm %02ds", hours, minutes, secs)
	elseif minutes > 0 then
		return string.format("%dm %02ds", minutes, secs)
	end

	return string.format("%ds", secs)
end

local function playerLabel(player: Player): string
	local label = `[{player.Name}](https://www.roblox.com/users/{player.UserId}/profile)`
	if player.DisplayName ~= player.Name then
		label ..= ` ({escapeMarkdown(player.DisplayName)})`
	end
	return label
end

local function enqueue(kind: Kind, line: string): ()
	if LogBlacklist.isBlocked() then
		return
	end

	local queue = queues[kind]
	table.insert(queue, line)

	local excess = #queue - MAX_QUEUED_LINES
	if excess > 0 then
		queues[kind] = table.move(queue, excess + 1, #queue, 1, {})
	end
end

local function requeue(kind: Kind, chunks: { string }, from: number): ()
	if from > #chunks then
		return
	end

	local unsent = table.move(chunks, from, #chunks, 1, {})
	local queue = queues[kind]
	queues[kind] = table.move(queue, 1, #queue, #unsent + 1, unsent)
end

local function onPlayerAdded(player: Player): ()
	if joinTimes[player.UserId] then
		return
	end

	local now = os.time()
	table.insert(JoinLogService.Joined, `{player.Name} Joined at: {DateTime.now():FormatUniversalTime("HH:mm:ss", "en-us")} UTC`)
	joinTimes[player.UserId] = now
	enqueue("join", `{playerLabel(player)} joined <t:{now}:T>`)
end

local function onPlayerRemoving(player: Player): ()
	local joinedAt = joinTimes[player.UserId]
	if not joinedAt then
		return
	end
	joinTimes[player.UserId] = nil

	local now = os.time()
	table.insert(JoinLogService.Left, `{player.Name} Left at: {DateTime.now():FormatUniversalTime("HH:mm:ss", "en-us")} UTC`)
	enqueue("leave", `{playerLabel(player)} left <t:{now}:T> · played {formatDuration(now - joinedAt)}`)
end

local CHAT_LOG_IGNORED: { [number]: true } = {}

function JoinLogService.LogChat(player: Player, filteredText: string): ()
	if not started or CHAT_LOG_IGNORED[player.UserId] then
		return
	end
	enqueue("chat", `<t:{os.time()}:T> {playerLabel(player)}: {escapeMarkdown(filteredText)}`)
end

function JoinLogService.LogMatchRewards(mapName: string, isPrivate: boolean, entries: { MatchRewardEntry }): ()
	if not started or #entries == 0 then
		return
	end

	local sorted = table.clone(entries)
	table.sort(sorted, function(a, b)
		return a.credits > b.credits
	end)

	local total = 0
	for _, entry in sorted do
		total += entry.credits
	end

	local serverType = if isPrivate then "Private" else "Public"
	enqueue("rewards", `**{escapeMarkdown(mapName)}** · {serverType} · <t:{os.time()}:T> · {total} credits total`)
	for _, entry in sorted do
		enqueue("rewards", `{playerLabel(entry.player)} · {if entry.won then "Win" else "Loss"} · {entry.credits} credits`)
	end
end

local function userLabel(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	return if player then playerLabel(player) else `[{userId}](https://www.roblox.com/users/{userId}/profile)`
end

function JoinLogService.LogCreditPurchase(userId: number, credits: number, robux: number, newBalance: number, wasDelayed: boolean): ()
	if not started then
		return
	end

	local delayedText = if wasDelayed then " · delivered after retry" else ""
	enqueue("purchases", `<t:{os.time()}:T> {userLabel(userId)} bought **{credits} credits** for {robux} R$ · balance {newBalance}{delayedText}`)
end

function JoinLogService.LogEconomyAlert(title: string, userId: number, detail: string): ()
	if not started then
		return
	end
	enqueue("alerts", `<t:{os.time()}:T> **{title}** · {userLabel(userId)} · {escapeMarkdown(detail)}`)
end

local function dropName(drop: CrateDropEntry): string
	if drop.packName and drop.skinId then
		return `{drop.skinId} {drop.packName}`
	end
	return (string.gsub(drop.id, "_PlayerCard$", " card"))
end

function JoinLogService.LogJackpot(player: Player, crateName: string, drop: CrateDropEntry): ()
	if not started then
		return
	end

	local name = dropName(drop)
	local dupText = if drop.isDuplicate then " · duplicate, refunded" else ""
	enqueue(
		"jackpots",
		`<t:{os.time()}:T> {playerLabel(player)} pulled **{escapeMarkdown(name)}** ({drop.rarity}) from **{escapeMarkdown(crateName)}**{dupText}`
	)
end

function JoinLogService.LogCrateOpen(player: Player, crateName: string, cost: number, refund: number, drops: { CrateDropEntry }): ()
	if not started or #drops == 0 then
		return
	end

	local items = table.create(#drops)
	for _, drop in drops do
		local name = dropName(drop)
		table.insert(items, `{escapeMarkdown(name)} ({drop.rarity}{if drop.isDuplicate then ", dup" else ""})`)
	end

	local refundText = if refund > 0 then ` · +{refund} refunded` else ""
	enqueue(
		"crates",
		`<t:{os.time()}:T> {playerLabel(player)} opened {#drops}x **{escapeMarkdown(crateName)}** · -{cost} credits{refundText} · {table.concat(items, ", ")}`
	)
end

local function buildChunks(lines: { string }): { string }
	local chunks: { string } = {}
	local current: { string } = {}
	local length = 0

	for _, line in lines do
		local lineLength = #line + 1
		if length + lineLength > MAX_DESCRIPTION_LENGTH and #current > 0 then
			table.insert(chunks, table.concat(current, "\n"))
			table.clear(current)
			length = 0
		end
		table.insert(current, line)
		length += lineLength
	end

	if #current > 0 then
		table.insert(chunks, table.concat(current, "\n"))
	end

	return chunks
end

local function buildEmbed(kind: Kind, description: string): Embed
	local style = KIND_STYLE[kind]

	return {
		title = `{getPlaceName()} · {style.title}`,
		description = description,
		color = style.color,
		footer = {
			text = `Place {game.PlaceId} · Server {game.JobId} · {#Players:GetPlayers()} in server`,
		},
		timestamp = DateTime.now():ToIsoDate(),
	}
end

local function post(url: string, embeds: { Embed }): boolean
	local body = HttpService:JSONEncode({ embeds = embeds, allowed_mentions = { parse = {} } })

	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Method = "POST",
			Url = url,
			Body = body,
			Headers = {
				["Content-Type"] = "application/json",
			},
		})
	end)

	if not ok then
		warn("[JoinLogService] Webhook request failed -", response)
		return false
	end

	if not response.Success then
		warn("[JoinLogService] Webhook rejected (HTTP", response.StatusCode, ")")
		return false
	end

	return true
end

local function hasPending(): boolean
	for _, kind in KINDS do
		if #queues[kind] > 0 then
			return true
		end
	end
	return false
end

local function flushGroup(url: string, kinds: { Kind }): ()
	local chunks: { [Kind]: { string } } = {}
	local count = 0
	for _, kind in kinds do
		chunks[kind] = buildChunks(queues[kind])
		queues[kind] = {}
		count = math.max(count, #chunks[kind])
	end

	local embeds: { Embed } = {}
	for index = 1, count do
		table.clear(embeds)
		for _, kind in kinds do
			local chunk = chunks[kind][index]
			if chunk then
				table.insert(embeds, buildEmbed(kind, chunk))
			end
		end

		if not post(url, embeds) then
			for _, kind in kinds do
				requeue(kind, chunks[kind], index)
			end
			break
		end

		if index < count then
			task.wait(1)
		end
	end
end

local function flush(): ()
	if flushing or not hasPending() then
		return
	end
	flushing = true

	for _, group in WEBHOOK_GROUPS do
		flushGroup(group.url, group.kinds)
	end

	flushing = false
end

local function runFlushLoop(): ()
	task.wait(rng:NextNumber(0, FLUSH_JITTER))
	while true do
		task.wait(FLUSH_INTERVAL)
		flush()
	end
end

local function onClose(): ()
	for _, player in Players:GetPlayers() do
		onPlayerRemoving(player)
	end

	local deadline = os.clock() + CLOSE_WAIT
	while flushing and os.clock() < deadline do
		task.wait(0.1)
	end

	flush()
end

function JoinLogService:init(): ()
	task.spawn(getPlaceName)
end

function JoinLogService:start(): ()
	if RunService:IsStudio() then
		return
	end
	started = true

	table.insert(connections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(connections, Players.PlayerRemoving:Connect(onPlayerRemoving))

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	flushThread = task.spawn(runFlushLoop)
	game:BindToClose(onClose)
end

function JoinLogService:Cleanup(): ()
	started = false
	if flushThread then
		task.cancel(flushThread)
		flushThread = nil
	end

	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	table.clear(joinTimes)
	for _, kind in KINDS do
		queues[kind] = {}
	end
	flushing = false
end

return JoinLogService
