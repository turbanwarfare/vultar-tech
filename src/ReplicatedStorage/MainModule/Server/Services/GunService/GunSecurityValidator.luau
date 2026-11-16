--!strict
--!native
--!optimize 2

local HttpService = game:GetService("HttpService")

local MainModule = script.Parent.Parent.Parent.Parent
local GunStats = require(MainModule.Shared.Config.GunStats)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

local getInventoryService = LazyService.create(MainModule, "InventoryService")

local GunSecurityValidator = {}

local DISCORD_WEBHOOK_URL =
	"REPLACE_WITH_YOUR_WEBHOOK_URL"
local ALERT_COOLDOWN_SECONDS = 20
local CONSECUTIVE_BREACH_ALERT_THRESHOLD = 6
local CONSECUTIVE_MAG_ALERT_THRESHOLD = 5
local HISTORY_SAMPLE_CAPACITY = 8
local MAX_SERVER_DELTA_SECONDS = 10
local DEFAULT_FIRE_RATE = 0.1
local MIN_FIRE_RATE_THRESHOLD = 0.03
local DEFAULT_MAX_PELLETS = 1

local DEV_EXEMPT_GUNS: { [string]: boolean } = {
	["H-94-DEV"] = true,
}

local TOOL_VARIANT_TO_BASE_NAME: { [string]: string } = {
	["H-82 INF"] = "H-82",
}
for name, stats in GunStats.Guns do
	if typeof(stats) == "table" and stats.SourceTool then
		TOOL_VARIANT_TO_BASE_NAME[name] = stats.SourceTool
	end
end

local GUN_FIRE_RATES: { [number]: number } = {}
local GUN_MAX_TOKENS: { [number]: number } = {}
local GUN_DEBT_LIMITS: { [number]: number } = {}
local GUN_MAX_PELLETS: { [number]: number } = {}
local GUN_MAX_AMMO: { [number]: number } = {}
local GUN_RECHARGE_RATES: { [number]: number } = {}
local GUN_INFINITE_AMMO: { [number]: boolean } = {}
local GUN_NAMES: { [number]: string } = {}

for gunIndex, gunName in GunStats.GUN_INDEX_TO_NAME do
	GUN_NAMES[gunIndex] = gunName
	local stats = GunStats.get(gunName)
	if stats then
		local fr = stats.FireRate or DEFAULT_FIRE_RATE
		GUN_FIRE_RATES[gunIndex] = fr
		local isAutomatic = stats.Mode == "Auto" or stats.Mode == "Medi"
		GUN_MAX_TOKENS[gunIndex] = math.max(0.5, fr * (if isAutomatic then 4.0 else 3.0))
		GUN_DEBT_LIMITS[gunIndex] = math.max(0.4, fr * (if isAutomatic then 4.0 else 2.5))
		GUN_MAX_PELLETS[gunIndex] = stats.Pellets or DEFAULT_MAX_PELLETS
		GUN_MAX_AMMO[gunIndex] = stats.MaxAmmo or 30
		GUN_RECHARGE_RATES[gunIndex] = stats.RechargePerSecond or 15
		GUN_INFINITE_AMMO[gunIndex] = stats.InfiniteAmmo == true
	else
		GUN_FIRE_RATES[gunIndex] = DEFAULT_FIRE_RATE
		GUN_MAX_TOKENS[gunIndex] = 0.5
		GUN_DEBT_LIMITS[gunIndex] = 0.4
		GUN_MAX_PELLETS[gunIndex] = DEFAULT_MAX_PELLETS
		GUN_MAX_AMMO[gunIndex] = 30
		GUN_RECHARGE_RATES[gunIndex] = 15
		GUN_INFINITE_AMMO[gunIndex] = false
	end
end

type GunIntervalBuffer = {
	samples: { number },
	head: number,
	count: number,
}

type PlayerSecurityState = {
	tokens: { [number]: number },
	lastUpdateTimes: { [number]: number },
	pendingBreaches: { [number]: number },
	magazineShots: { [number]: number },
	lastMagShotTimes: { [number]: number },
	pendingMagBreaches: { [number]: number },
	intervalBuffers: { [number]: GunIntervalBuffer },
	lastClientFrameTimeMs: { [number]: number },
	lastAlertTime: number,
}

local playerStates: { [number]: PlayerSecurityState } = {}

local function getOrCreateState(userId: number): PlayerSecurityState
	local state = playerStates[userId]
	if not state then
		state = {
			tokens = {},
			lastUpdateTimes = {},
			pendingBreaches = {},
			magazineShots = {},
			lastMagShotTimes = {},
			pendingMagBreaches = {},
			intervalBuffers = {},
			lastClientFrameTimeMs = {},
			lastAlertTime = 0,
		}
		playerStates[userId] = state
	end
	return state
end

local function formatIntervalHistory(buf: GunIntervalBuffer?): string
	if not buf or buf.count == 0 then
		return "[]"
	end

	local formatted = {}
	local capacity = HISTORY_SAMPLE_CAPACITY
	local startIdx = if buf.count < capacity then 1 else buf.head
	for i = 0, buf.count - 1 do
		local idx = ((startIdx - 1 + i) % capacity) + 1
		table.insert(formatted, string.format("%.3f", buf.samples[idx]))
	end

	return "[" .. table.concat(formatted, ", ") .. "]"
end

local function getPlayerHeadshotUrl(userId: number): string?
	if userId <= 0 then
		return nil
	end
	local url = string.format("https://thumbnails.roproxy.com/v1/users/avatar-headshot?userIds=%d&size=420x420&format=Png&isCircular=false", userId)
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

local function getPlayerPingMs(player: Player): number?
	local ok, rawPing = pcall(player.GetNetworkPing, player)
	if ok and typeof(rawPing) == "number" then
		return math.clamp(math.round(rawPing * 1000), 0, 65535)
	end
	return nil
end

local function sendWebhookAsync(
	userId: number,
	userName: string,
	weaponName: string,
	violationType: string,
	details: string,
	pingMs: number?,
	clientFrameTimeMs: number?
)
	if DISCORD_WEBHOOK_URL == "" then
		return
	end

	task.spawn(function()
		local headshotUrl = getPlayerHeadshotUrl(userId)
		local thumbnail = if headshotUrl then { url = headshotUrl } else nil

		local fpsStr = if clientFrameTimeMs and clientFrameTimeMs > 0 then string.format("~%d FPS", math.round(1000 / clientFrameTimeMs)) else "N/A"
		local pingStr = if pingMs ~= nil then string.format("%dms", pingMs) else "N/A"

		local embed = {
			author = { name = "Vultar V2" },
			title = string.format("EXPLOIT_DETECTED | %s", violationType),
			color = 0xFF3040,
			thumbnail = thumbnail,
			fields = {
				{ name = "Player", value = string.format("%s (%d)", userName, userId), inline = true },
				{ name = "Weapon", value = weaponName, inline = true },
				{ name = "Ping / FPS", value = string.format("%s | %s", pingStr, fpsStr), inline = true },
				{ name = "Details", value = details, inline = false },
			},
			footer = { text = "VULTARIAN DEFENSE INDUSTRIES" },
			timestamp = DateTime.now():ToIsoDate(),
		}

		local payload = HttpService:JSONEncode({
			username = "VDI",
			embeds = { embed },
		})

		pcall(HttpService.PostAsync, HttpService, DISCORD_WEBHOOK_URL, payload, Enum.HttpContentType.ApplicationJson)
	end)
end

local function recordViolation(player: Player, weaponName: string, violationType: string, details: string, clientFrameTimeMs: number?)
	local userId = player.UserId
	local state = getOrCreateState(userId)
	local now = os.time()

	if (now - state.lastAlertTime) >= ALERT_COOLDOWN_SECONDS then
		state.lastAlertTime = now
		local pingMs = getPlayerPingMs(player)
		sendWebhookAsync(userId, player.Name, weaponName, violationType, details, pingMs, clientFrameTimeMs)
	end
end

function GunSecurityValidator.validateEquippedWeapon(player: Player, gunIndex: number): boolean
	local expectedName = GUN_NAMES[gunIndex]
	if not expectedName then
		recordViolation(player, "Unknown", "INVALID_GUN_INDEX", "Gun index " .. tostring(gunIndex) .. " does not exist")
		return false
	end

	local char = player.Character
	local equippedTool = if char then char:FindFirstChildOfClass("Tool") else nil

	if equippedTool then
		local toolName = equippedTool.Name
		if toolName == expectedName or TOOL_VARIANT_TO_BASE_NAME[toolName] == expectedName then
			return true
		end

		recordViolation(player, expectedName, "WEAPON_SPOOF", string.format("Claimed %s but holding %s", expectedName, toolName))
		return false
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		if backpack:FindFirstChild(expectedName) then
			return true
		end
		for variantName, baseName in TOOL_VARIANT_TO_BASE_NAME do
			if baseName == expectedName and backpack:FindFirstChild(variantName) then
				return true
			end
		end
	end

	local invService = getInventoryService()
	if invService and typeof(invService.GetInventory) == "function" then
		local inv = invService:GetInventory(player)
		if inv and inv.Items then
			for _, item in inv.Items do
				local itemName = item.Name
				if itemName == expectedName or TOOL_VARIANT_TO_BASE_NAME[itemName] == expectedName then
					return true
				end
			end
		end
	end

	recordViolation(player, expectedName, "WEAPON_SPOOF", string.format("Claimed %s with no weapon equipped or in inventory", expectedName))
	return false
end

function GunSecurityValidator.validateFireRate(player: Player, gunIndex: number, clientFrameTimeMs: number?): boolean
	local gunName = GUN_NAMES[gunIndex]
	if gunName and DEV_EXEMPT_GUNS[gunName] then
		return true
	end

	local fireRate = GUN_FIRE_RATES[gunIndex]
	if not fireRate or fireRate <= MIN_FIRE_RATE_THRESHOLD then
		return true
	end

	local maxTokens = GUN_MAX_TOKENS[gunIndex] or 0.5
	local debtLimit = GUN_DEBT_LIMITS[gunIndex] or 0.4
	local now = os.clock()
	local state = getOrCreateState(player.UserId)

	if clientFrameTimeMs then
		state.lastClientFrameTimeMs[gunIndex] = clientFrameTimeMs
	end

	local lastTime = state.lastUpdateTimes[gunIndex]
	if not lastTime then
		state.lastUpdateTimes[gunIndex] = now
		state.tokens[gunIndex] = maxTokens - fireRate
		state.pendingBreaches[gunIndex] = 0
		return true
	end

	local serverDt = math.min(MAX_SERVER_DELTA_SECONDS, now - lastTime)
	state.lastUpdateTimes[gunIndex] = now

	local buf = state.intervalBuffers[gunIndex]
	if not buf then
		buf = {
			samples = table.create(HISTORY_SAMPLE_CAPACITY, 0),
			head = 1,
			count = 0,
		}
		state.intervalBuffers[gunIndex] = buf
	end

	buf.samples[buf.head] = serverDt
	buf.head = (buf.head % HISTORY_SAMPLE_CAPACITY) + 1
	if buf.count < HISTORY_SAMPLE_CAPACITY then
		buf.count += 1
	end

	local currentTokens = math.min(maxTokens, (state.tokens[gunIndex] or maxTokens) + serverDt)
	local afterShotTokens = currentTokens - fireRate

	if afterShotTokens < -debtLimit then
		local pending = (state.pendingBreaches[gunIndex] or 0) + 1
		state.pendingBreaches[gunIndex] = pending
		state.tokens[gunIndex] = -debtLimit

		if pending >= CONSECUTIVE_BREACH_ALERT_THRESHOLD then
			local historyStr = formatIntervalHistory(buf)
			recordViolation(
				player,
				gunName or "Unknown",
				"RATE_OF_FIRE_EXPLOIT",
				string.format("Server Delta: %.3fs | Allowed Rate: %.3fs\nIntervals: %s", serverDt, fireRate, historyStr),
				state.lastClientFrameTimeMs[gunIndex]
			)
		end
		return true
	end

	if afterShotTokens >= 0 then
		state.pendingBreaches[gunIndex] = 0
	end
	state.tokens[gunIndex] = afterShotTokens
	return true
end

function GunSecurityValidator.validateMagazine(player: Player, gunIndex: number): boolean
	local gunName = GUN_NAMES[gunIndex]
	if gunName and DEV_EXEMPT_GUNS[gunName] then
		return true
	end

	if GUN_INFINITE_AMMO[gunIndex] then
		return true
	end

	if player:GetAttribute("AimChamberInfiniteAmmo") == true then
		return true
	end

	local char = player.Character
	if char then
		if char:GetAttribute("AimChamberInfiniteAmmo") == true then
			return true
		end
		local tool = char:FindFirstChildOfClass("Tool")
		if tool then
			if tool:GetAttribute("InfiniteAmmo") == true then
				return true
			end
			local toolStats = GunStats.get(tool.Name)
			if toolStats and toolStats.InfiniteAmmo == true then
				return true
			end
		end
	end

	local maxAmmo = GUN_MAX_AMMO[gunIndex] or 30
	local rechargeRate = GUN_RECHARGE_RATES[gunIndex] or 15
	local state = getOrCreateState(player.UserId)
	local now = os.clock()

	local lastShot = state.lastMagShotTimes[gunIndex]
	local shotsFired = state.magazineShots[gunIndex] or 0

	if lastShot and (now - lastShot) >= math.max(0.6, 1 / rechargeRate) then
		local timeElapsed = now - lastShot
		local bulletsRegenerated = math.floor(timeElapsed * rechargeRate)
		shotsFired = math.max(0, shotsFired - bulletsRegenerated)
	end

	if shotsFired >= maxAmmo then
		local pending = (state.pendingMagBreaches[gunIndex] or 0) + 1
		state.pendingMagBreaches[gunIndex] = pending

		if pending >= CONSECUTIVE_MAG_ALERT_THRESHOLD then
			recordViolation(player, gunName or "Unknown", "NO_RELOAD_EXPLOIT", string.format("Fired %d/%d rounds without reload interval", shotsFired, maxAmmo))
		end
		return false
	end

	state.pendingMagBreaches[gunIndex] = 0
	state.magazineShots[gunIndex] = shotsFired + 1
	state.lastMagShotTimes[gunIndex] = now
	return true
end

function GunSecurityValidator.sanitizePelletCount(player: Player, gunIndex: number, hitCount: number): (boolean, number)
	local maxAllowed = GUN_MAX_PELLETS[gunIndex] or DEFAULT_MAX_PELLETS
	local gunName = GUN_NAMES[gunIndex] or "Unknown"

	if maxAllowed <= 1 and hitCount > 1 then
		recordViolation(player, gunName, "PELLET_SPOOF", string.format("Sent %d pellets on single-bullet weapon", hitCount))
		return false, 1
	end

	if hitCount > maxAllowed then
		recordViolation(player, gunName, "EXCESSIVE_PELLETS", string.format("Sent %d pellets (Max: %d)", hitCount, maxAllowed))
		return true, maxAllowed
	end

	return true, hitCount
end

function GunSecurityValidator.cleanupPlayer(player: Player)
	playerStates[player.UserId] = nil
end

function GunSecurityValidator.cleanup()
	table.clear(playerStates)
end

return GunSecurityValidator
