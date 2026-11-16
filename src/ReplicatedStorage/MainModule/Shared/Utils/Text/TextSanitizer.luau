--!strict
--!native
--!optimize 2

local TextSanitizer = {}

local HTML_ESCAPE_MAP: { [string]: string } = {
	["<"] = "&lt;",
	[">"] = "&gt;",
	["&"] = "&amp;",
	['"'] = "&quot;",
	["'"] = "&apos;",
}

local HTML_UNESCAPE_MAP: { [string]: string } = {
	lt = "<",
	gt = ">",
	amp = "&",
	quot = '"',
	apos = "'",
}

local CONTROL_CHAR_PATTERN = "[\0-\8\11\12\14-\31]"
local RICH_TEXT_PATTERN = "[<>&\"']"
local EMPTY = ""

local usernameCache: { [string]: string } = {}
local usernameCacheSize = 0
local MAX_USERNAME_CACHE_SIZE = 200

local chatSanitizeCache: { [string]: string } = {}
local chatCacheSize = 0
local MAX_CHAT_CACHE_SIZE = 100

local function escapeChar(char: string): string
	return HTML_ESCAPE_MAP[char] or char
end

function TextSanitizer.escapeRichText(text: string): string
	if not text or text == "" then
		return ""
	end
	return (text:gsub(RICH_TEXT_PATTERN, escapeChar))
end

function TextSanitizer.decodeEntities(text: string): string
	if not text or text == "" then
		return ""
	end
	return (text:gsub("&(%a+);", HTML_UNESCAPE_MAP))
end

function TextSanitizer.stripRichTextTags(text: string): string
	if not text or text == "" then
		return ""
	end
	return (text:gsub("<[^>]+>", EMPTY))
end

function TextSanitizer.sanitizeForChat(text: string): string
	if not text or text == "" then
		return ""
	end

	local cached = chatSanitizeCache[text]
	if cached then
		return cached
	end

	local sanitized = TextSanitizer.decodeEntities(text):gsub(RICH_TEXT_PATTERN, escapeChar)
	sanitized = (sanitized:gsub(CONTROL_CHAR_PATTERN, EMPTY))

	if chatCacheSize < MAX_CHAT_CACHE_SIZE then
		chatSanitizeCache[text] = sanitized
		chatCacheSize = chatCacheSize + 1
	else
		chatSanitizeCache = { [text] = sanitized }
		chatCacheSize = 1
	end

	return sanitized
end

function TextSanitizer.sanitizeUsername(name: string): string
	if not name or name == "" then
		return ""
	end

	local cached = usernameCache[name]
	if cached then
		return cached
	end

	local sanitized = name:gsub(RICH_TEXT_PATTERN, escapeChar)

	if usernameCacheSize < MAX_USERNAME_CACHE_SIZE then
		usernameCache[name] = sanitized
		usernameCacheSize = usernameCacheSize + 1
	else
		usernameCache = { [name] = sanitized }
		usernameCacheSize = 1
	end

	return sanitized
end

function TextSanitizer.clearCache(): ()
	usernameCache = {}
	usernameCacheSize = 0
	chatSanitizeCache = {}
	chatCacheSize = 0
end

return TextSanitizer
