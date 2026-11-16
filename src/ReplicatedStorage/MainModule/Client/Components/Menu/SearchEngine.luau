--!strict
--!native
--!optimize 2

local EMPTY = ""
local SearchEngine = {}

local scoreCache: { [string]: number } = {}
local lastCacheQuery: string = ""
local _CACHE_MAX_SIZE = 200

local function getCacheKey(query: string, label: string, settingKey: string?): string
	return query .. "|" .. label .. "|" .. (settingKey or "")
end

local function clearCacheIfQueryChanged(query: string): ()
	if query ~= lastCacheQuery then
		table.clear(scoreCache)
		lastCacheQuery = query
	end
end

local SYNONYMS: { [string]: { string } } = {
	dmg = { "damage" },
	damage = { "dmg" },
	dam = { "damage" },

	hitmarker = { "hit indicator", "hitindicators" },
	hitmarkers = { "hit indicator", "hitindicators" },
	["hit marker"] = { "hit indicator", "hitindicators" },
	["hit markers"] = { "hit indicator", "hitindicators" },

	["hit indicator"] = { "hitmarker", "hitmarkers" },
	["hit indicators"] = { "hitmarker", "hitmarkers" },
	hitindicator = { "hitmarker" },
	hitindicators = { "hitmarker" },

	circle = { "kill indicator", "killindicator" },
	skull = { "kill indicator", "killindicator" },

	outline = { "hit highlight", "hithighlight", "team esp", "teamesp", "heal highlight" },
	glow = { "highlight", "esp" },

	gun = { "holster", "holsters", "weapon" },
	weapon = { "holster", "holsters", "gun" },

	laser = { "ray", "raytype", "tracer", "beam" },
	tracer = { "ray", "raytype", "laser", "beam" },
	beam = { "ray", "raytype", "laser", "tracer" },

	esp = { "highlight", "team esp", "teamesp" },

	crosshair = { "cursor", "reticle" },
	cursor = { "crosshair", "reticle" },
	reticle = { "cursor", "crosshair" },

	heal = { "health", "hp", "medic" },
	health = { "heal", "hp" },
	hp = { "heal", "health" },

	kill = { "elimination", "elim", "frag" },
	elim = { "kill", "elimination" },
	frag = { "kill", "elimination" },

	sound = { "audio", "sfx" },
	audio = { "sound", "sfx" },
	sfx = { "sound", "audio" },

	num = { "number" },
	number = { "num", "numbers" },
	numbers = { "number", "num" },
}

local SETTING_KEYWORDS: { [string]: { string } } = {
	HitIndicators = { "hitmarker", "hitmarkers", "hit marker", "crosshair hit" },
	HitColor = { "hitmarker color" },
	HitHeadshotRed = { "headshot", "crit" },
	HitPreset = { "hitmarker style" },
	HitmarkerRotation = { "spin", "rotate" },
	HitmarkerSpeed = { "rotation speed" },

	DamageIndicators = { "damage number", "dmg", "dmg number", "floating damage", "hurt" },
	DamageIndicatorType = { "expand", "stack" },
	DamageIndicatorStickTo = { "position", "follow" },
	StackKillFlash = { "kill flash", "red flash", "kill indicator", "elimination" },
	DamageIndicatorFont = { "font", "typeface", "text font", "text style", "damage font", "indicator font" },
	DamageIndicatorSize = { "text size", "font size" },
	DamageIndicatorOutline = { "stroke", "border" },
	BloodIndicator = { "gore", "splatter" },

	HitHighlights = { "glow", "outline", "limb highlight", "body part" },
	HitHighlightTransparency = { "opacity" },
	HitHighlightThickness = { "width", "stroke" },
	HitHighlightFadeIn = { "animation" },
	HitHighlightDuration = { "time", "length" },
	HitHighlightHeadColor = { "headshot color" },
	HitHighlightBodyColor = { "body color" },

	HealIndicators = { "health", "hp", "medic", "healing" },
	HealNumberIndicators = { "heal number", "health number" },
	HealIndicatorFont = { "heal font", "heal indicator font", "healing font", "heal typeface", "heal style" },
	HealIndicatorSize = { "text size", "heal size" },
	HealIndicatorType = { "expand", "stack", "animation" },
	HealHighlights = { "heal glow", "outline", "green highlight" },
	HealHighlightTransparency = { "opacity" },

	KillIndicators = { "kill confirm", "elimination", "skull", "circle", "frag" },
	KillIndicatorType = { "circle", "skull", "hitmarker" },
	KillIndicatorColor = { "kill color" },
	KillIndicatorSize = { "scale" },
	KillIndicatorTransparency = { "opacity" },
	KillIndicatorPosition = { "location" },

	KillFeed = { "death log", "elimination feed" },
	KillFeedPosition = { "location" },
	KillFeedTextSize = { "font size" },

	TeamESP = { "teammate", "friendly", "ally", "team highlight", "outline", "glow" },
	TeamESP_Highlight = { "fill", "glow" },
	TeamESP_HighlightColor = { "team color" },
	TeamESP_HighlightTransparency = { "opacity" },
	TeamESP_Overhead = { "nametag" },
	OOCIndicatorPosition = { "charge", "medic", "out of charge", "empty", "medigun" },

	Ping = { "marker", "waypoint", "callout" },
	PingHighlightColor = { "marker color" },
	PingHighlightFill = { "solid" },
	AnimatedPingHighlight = { "pulse" },
	PingNotificationPosition = { "notification" },

	CursorStyle = { "crosshair", "reticle", "aim" },
	CustomCursorId = { "custom crosshair", "decal id" },
	IFF = { "friend foe", "enemy cursor" },

	RayType = { "tracer", "bullet", "beam", "laser", "projectile" },
	RaySpeed = { "tracer speed" },
	RayStickToBarrel = { "attached" },
	MuzzleFlash = { "gun flash", "barrel flash" },
	HitIndicatorSize = { "hitmarker size", "crosshair size", "hit size", "marker size" },

	Materials = { "texture" },
	Particles = { "effect", "vfx" },
	Shaders = { "lighting", "bloom" },
	Shadows = { "shade" },
	Time = { "day", "night" },

	WeaponSounds = { "gun sound", "fire sound" },
	HitSounds = { "impact sound" },
	KillSounds = { "elimination sound" },

	StatsHUD = { "statistics" },
	HurtScreen = { "damage screen", "red overlay", "vignette" },
	HurtScreenType = { "hurt type", "screen type", "border", "vignette" },
	PreviewPosition = { "settings preview" },
	MenuTransparency = { "background opacity" },

	Holsters = { "weapon back", "gun back", "sling", "gun", "weapon" },
	Decals = { "texture", "bullet hole" },
	DynamicLights = { "point light" },
	CharacterFootsteps = { "walking sound", "step sound" },
}

local function normalizeString(str: string): string
	str = str:lower()
	str = str:gsub("[^%w%s]", EMPTY)
	str = str:gsub("%s+", " ")
	str = str:gsub("^%s+", EMPTY):gsub("%s+$", EMPTY)
	return str
end

local function levenshteinDistance(s1: string, s2: string): number
	local len1, len2 = #s1, #s2
	if len1 == 0 then return len2 end
	if len2 == 0 then return len1 end

	if len1 > len2 then
		s1, s2 = s2, s1
		len1, len2 = len2, len1
	end

	local prevRow: { number } = {}
	local currRow: { number } = {}

	for j = 0, len2 do
		prevRow[j + 1] = j
	end

	for i = 1, len1 do
		currRow[1] = i
		local c1 = s1:sub(i, i)

		for j = 1, len2 do
			local c2 = s2:sub(j, j)
			local cost = if c1 == c2 then 0 else 1

			currRow[j + 1] = math.min(
				prevRow[j + 1] + 1,
				currRow[j] + 1,
				prevRow[j] + cost
			)
		end

		prevRow, currRow = currRow, prevRow
	end

	return prevRow[len2 + 1]
end

local function buildSearchableText(label: string, description: string, settingKey: string?): string
	local parts: { string } = {}

	table.insert(parts, normalizeString(label))
	table.insert(parts, normalizeString(description))

	if settingKey then
		local keyWithSpaces = settingKey:gsub("([A-Z])", " %1"):gsub("_", " ")
		table.insert(parts, normalizeString(keyWithSpaces))
		table.insert(parts, normalizeString(settingKey))

		local keywords = SETTING_KEYWORDS[settingKey]
		if keywords then
			for _, keyword in keywords do
				table.insert(parts, normalizeString(keyword))
			end
		end
	end

	return table.concat(parts, " ")
end

local function fuzzyMatchWord(needle: string, word: string): boolean
	if #needle < 4 or #word < 3 then
		return false
	end

	local distance = levenshteinDistance(needle, word)
	local maxAllowed = math.max(1, math.floor(#needle * 0.3))
	return distance <= maxAllowed
end

local function scoreTokenInText(token: string, searchableText: string, normalizedKey: string): number
	if normalizedKey:find(token, 1, true) then
		return 100
	end

	if searchableText:find(token, 1, true) then
		return 80
	end

	local synonyms = SYNONYMS[token]
	if synonyms then
		for _, syn in synonyms do
			if searchableText:find(syn, 1, true) then
				return 60
			end
		end
	end

	for word in searchableText:gmatch("%S+") do
		if fuzzyMatchWord(token, word) then
			return 30
		end
	end

	if #token >= 3 then
		for word in searchableText:gmatch("%S+") do
			if word:sub(1, #token) == token then
				return 50
			end
		end
	end

	return 0
end

function SearchEngine.score(query: string, label: string, description: string, settingKey: string?): number
	if query == "" then
		return 1000
	end

	clearCacheIfQueryChanged(query)

	local cacheKey = getCacheKey(query, label, settingKey)
	local cached = scoreCache[cacheKey]
	if cached then
		return cached
	end

	local normalizedQuery = normalizeString(query)
	if normalizedQuery == "" then
		scoreCache[cacheKey] = 1000
		return 1000
	end

	local normalizedKey = settingKey and normalizeString(settingKey) or normalizeString(label)
	local searchableText = buildSearchableText(label, description, settingKey)

	local queryNoSpaces = normalizedQuery:gsub("%s+", EMPTY)
	local keyNoSpaces = normalizedKey:gsub("%s+", EMPTY)

	if queryNoSpaces == keyNoSpaces then
		scoreCache[cacheKey] = 1000
		return 1000
	end

	if settingKey and SETTING_KEYWORDS[settingKey] then
		for _, kw in SETTING_KEYWORDS[settingKey] do
			local kwNorm = normalizeString(kw):gsub("%s+", EMPTY)
			if kwNorm == queryNoSpaces then
				scoreCache[cacheKey] = 960
				return 960
			end
		end
	end

	if keyNoSpaces:find(queryNoSpaces, 1, true) then
		local matchRatio = #queryNoSpaces / #keyNoSpaces
		local score = 900 + math.floor(matchRatio * 50)
		scoreCache[cacheKey] = score
		return score
	end

	if queryNoSpaces:find(keyNoSpaces, 1, true) then
		scoreCache[cacheKey] = 850
		return 850
	end

	local tokens: { string } = {}
	for word in normalizedQuery:gmatch("%S+") do
		table.insert(tokens, word)
	end

	if #tokens == 0 then
		return 1000
	end

	local matchedCount = 0
	local totalScore = 0
	local keyMatchCount = 0

	for _, token in tokens do
		local tokenScore = scoreTokenInText(token, searchableText, normalizedKey)
		if tokenScore > 0 then
			matchedCount += 1
			totalScore += tokenScore

			if normalizedKey:find(token, 1, true) then
				keyMatchCount += 1
			end
		end
	end

	local requiredMatches: number
	if #tokens == 1 then
		requiredMatches = 1
	elseif #tokens == 2 then
		requiredMatches = 2
	else
		requiredMatches = math.ceil(#tokens * 0.7)
	end

	if matchedCount < requiredMatches then
		scoreCache[cacheKey] = 0
		return 0
	end

	local matchPercentage = matchedCount / #tokens
	local keyMatchBonus = keyMatchCount * 20
	local finalScore = math.floor(totalScore * matchPercentage) + keyMatchBonus

	scoreCache[cacheKey] = finalScore
	return finalScore
end

function SearchEngine.matches(query: string, label: string, description: string, settingKey: string?): boolean
	return SearchEngine.score(query, label, description, settingKey) > 0
end

return SearchEngine
