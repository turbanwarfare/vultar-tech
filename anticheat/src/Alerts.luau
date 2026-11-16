--!nonstrict

local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Config)
local Signals = require(script.Parent.Signals)

local Alerts = {}

local chatService = nil
local gunNames: { [number]: string } = {}
local lastAlertAt: { [number]: number } = {}

function Alerts.init(vultar, mainModule: Instance): ()
	chatService = vultar.GetService("ChatService")
	local ok, GunStats = pcall(require, mainModule.Shared.Config.GunStats)
	if ok and GunStats and GunStats.GUN_INDEX_TO_NAME then
		gunNames = GunStats.GUN_INDEX_TO_NAME
	end
end

local function headshotUrl(userId: number): string?
	local url = string.format("https://thumbnails.roproxy.com/v1/users/avatar-headshot?userIds=%d&size=420x420&format=Png&isCircular=false", userId)
	local ok, response = pcall(HttpService.GetAsync, HttpService, url)
	if not ok then
		return nil
	end
	local decoded, data = pcall(HttpService.JSONDecode, HttpService, response)
	if decoded and data and data.data and data.data[1] then
		return data.data[1].imageUrl
	end
	return nil
end

local function severityIcon(level: number): string
	return if level >= 0.8 then "🔴" elseif level >= 0.4 then "🟠" else "🟡"
end

local function confidenceLabel(score: number): string
	return if score >= 0.8 then "very likely" elseif score >= 0.6 then "likely" else "worth a look"
end

function Alerts.describe(result): string
	local parts = {}
	for _, detail in result.details do
		table.insert(parts, detail.text)
	end
	return table.concat(parts, " ")
end

local function postWebhook(player: Player, result, isTest: boolean): ()
	if Config.WebhookUrl == "" then
		return
	end

	local lines = {}
	for _, detail in result.details do
		table.insert(lines, string.format("%s %s", severityIcon(detail.level), detail.text))
	end
	if #lines == 0 then
		table.insert(lines, "No single reason stands out.")
	end

	local primaryTitle = Signals.SIGNAL_TITLES[result.primary] or "AIM"
	local weapon = if result.topGunIndex then gunNames[result.topGunIndex] or ("Gun " .. tostring(result.topGunIndex)) else "Unknown"
	local fpsText = if result.fps and result.fps > 0 then string.format("~%d FPS", result.fps) else "? FPS"
	local thumb = headshotUrl(player.UserId)

	local embed = {
		title = string.format("%s | %s", if isTest then "AIMBOT_TEST" else "AIMBOT_SUSPECTED", primaryTitle),
		color = if result.score >= 0.8 then 0xED4245 elseif result.score >= 0.6 then 0xE67E22 else 0xFEE75C,
		thumbnail = if thumb then { url = thumb } else nil,
		fields = {
			{ name = "Player", value = string.format("%s (%d)", player.Name, player.UserId), inline = true },
			{ name = "Weapon", value = weapon, inline = true },
			{ name = "Ping / FPS", value = string.format("%dms | %s", result.pingMs or 0, fpsText), inline = true },
			{ name = "Confidence", value = string.format("%.0f%% (%s)", result.score * 100, confidenceLabel(result.score)), inline = true },
			{ name = "Window", value = string.format("%d hits / %d shots in %d min", result.hits, result.shots, math.round(Config.TimeWindow / 60)), inline = true },
			{ name = "Details", value = table.concat(lines, "\n"), inline = false },
		},
		footer = { text = Config.WebhookFooter },
		timestamp = DateTime.now():ToIsoDate(),
	}

	local body = HttpService:JSONEncode({ embeds = { embed }, allowed_mentions = { parse = {} } })
	local ok, err = pcall(HttpService.PostAsync, HttpService, Config.WebhookUrl, body, Enum.HttpContentType.ApplicationJson)
	if not ok then
		warn("[AC] Webhook failed:", err)
	end
end

function Alerts.maybeAlert(player: Player, result): boolean
	if result.score < Config.AlertThreshold or not result.eligible then
		return false
	end

	local now = os.clock()
	local last = lastAlertAt[player.UserId]
	if last and now - last < Config.AlertCooldown then
		return false
	end
	lastAlertAt[player.UserId] = now

	task.spawn(postWebhook, player, result, false)

	if not Config.SilentMode and chatService then
		local first = result.details[1]
		local text = string.format(
			"[AC] %s · %.0f%% %s · %s · %s",
			player.Name,
			result.score * 100,
			confidenceLabel(result.score),
			Signals.SIGNAL_TITLES[result.primary] or "AIM",
			if first then first.text else "high overall score"
		)
		pcall(chatService.SendSystemMessage, chatService, Config.StaffChannel, text, Color3.fromRGB(255, 120, 120), nil, { Config.AlertTag })
	end
	return true
end

function Alerts.clear(userId: number): ()
	lastAlertAt[userId] = nil
end

function Alerts.test(player: Player): boolean
	postWebhook(player, {
		score = 0.74,
		primary = "cluster",
		signals = { cluster = 0.9, silentAim = 0.5, switch = 0, headshot = 0.4, accuracy = 0.2 },
		details = {
			{ level = 0.9, text = "Shots land on the exact same spot of the head on moving players: 23 hits all within 0.08 studs. Real players spread out." },
			{ level = 0.5, text = "2 shots hit a player their cursor wasn't on (the shot was aimed somewhere else)." },
			{ level = 0.4, text = "83% of their hits are headshots (30 hits)." },
		},
		hits = 30,
		shots = 45,
		eligible = true,
		topGunIndex = nil,
		pingMs = 48,
		fps = 144,
	}, true)
	return true
end

return Alerts
