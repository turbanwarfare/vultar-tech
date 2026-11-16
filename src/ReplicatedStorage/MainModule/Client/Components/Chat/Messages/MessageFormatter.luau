--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local ChatConfig = require(MainModule.Shared.Config.Chat.ChatConfig)
local Constants = require(MainModule.Shared.Config.Constants)
local ChatConstants = require(MainModule.Shared.Chat.Constants)
local Theme = require(MainModule.Shared.UI.Theme)
local TextSanitizer = require(MainModule.Shared.Utils.Text.TextSanitizer)
local ChatTypes = require(MainModule.Shared.Network.Chat.Types)

type ChatMessage = ChatTypes.ChatMessage

local MessageFormatter = {}

local colorHexCache: { [Color3]: string } = {}
local tagConfigCache: { [string]: { text: string?, icon: string?, backgroundColor: Color3? }? } = {}
local escapedPatternCache: { [string]: string } = {}
local escapedPatternCount = 0
local MAX_ESCAPED_PATTERN_CACHE = 100

function MessageFormatter.colorToHex(color: Color3): string
	local cached = colorHexCache[color]
	if cached then
		return cached
	end
	local hex = string.format(
		"%02X%02X%02X",
		math.floor(color.R * 255),
		math.floor(color.G * 255),
		math.floor(color.B * 255)
	)
	colorHexCache[color] = hex
	return hex
end

function MessageFormatter.getTagConfig(tagId: string): { text: string?, icon: string?, backgroundColor: Color3? }?
	local cached = tagConfigCache[tagId]
	if cached ~= nil then
		return cached
	end

	local config = ChatConfig.getTagConfig(tagId)
	tagConfigCache[tagId] = config
	return config
end

function MessageFormatter.escapePattern(text: string): string
	local cached = escapedPatternCache[text]
	if cached then
		return cached
	end
	local escaped = text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
	if escapedPatternCount < MAX_ESCAPED_PATTERN_CACHE then
		escapedPatternCache[text] = escaped
		escapedPatternCount += 1
	end
	return escaped
end

function MessageFormatter.getVultarEnduresColor(message: ChatMessage): string
	for _, tagId in message.tags do
		if tagId == "royal" then
			return Constants.VULTAR_ENDURES.ROYAL_GUARD.hex
		end
	end
	return Constants.VULTAR_ENDURES.STANDARD.hex
end

function MessageFormatter.highlightMentions(text: string, playerName: string, displayName: string): string
	local safeContent = TextSanitizer.sanitizeForChat(text)
	local mentionColor = ChatConstants.Colors.mention

	if displayName and displayName ~= "" then
		local escapedDisplayName = MessageFormatter.escapePattern(displayName)
		safeContent = safeContent:gsub("(@" .. escapedDisplayName .. ")", function(match)
			return string.format('<font color="#%s"><b>%s</b></font>', mentionColor, match)
		end)
	end

	if playerName and playerName ~= "" and playerName ~= displayName then
		local escapedPlayerName = MessageFormatter.escapePattern(playerName)
		safeContent = safeContent:gsub("(@" .. escapedPlayerName .. ")", function(match)
			return string.format('<font color="#%s"><b>%s</b></font>', mentionColor, match)
		end)
	end

	return safeContent
end

function MessageFormatter.buildTagAndRoleParts(message: ChatMessage, nameColor: Color3): (string, string)
	local tagString = ""
	if #message.tags > 0 then
		local tagParts = {}
		for _, tagId in message.tags do
			local tagConfig = MessageFormatter.getTagConfig(tagId)
			if tagConfig and tagConfig.text and tagConfig.backgroundColor then
				table.insert(tagParts, string.format(
					'<font color="#%s"><b>[%s]</b></font>',
					MessageFormatter.colorToHex(tagConfig.backgroundColor),
					tagConfig.text
				))
			end
		end
		if #tagParts > 0 then
			tagString = table.concat(tagParts, " ") .. " "
		end
	end

	local rolePrefix = message.rolePrefix or ""
	local rolePart = ""
	if rolePrefix ~= "" then
		local roleColor = message.roleColor or nameColor
		rolePart = string.format('<font color="#%s"><b>[%s]</b></font> ', MessageFormatter.colorToHex(roleColor), rolePrefix)
	end

	return tagString, rolePart
end

function MessageFormatter.getIconTags(message: ChatMessage): { string }
	local icons = {}
	for _, tagId in message.tags do
		local tagConfig = MessageFormatter.getTagConfig(tagId)
		if tagConfig and tagConfig.icon then
			table.insert(icons, tagConfig.icon)
		end
	end
	return icons
end

function MessageFormatter.buildGradientPrefix(message: ChatMessage): string
	local parts = {}

	if message.isTeamOnly then
		table.insert(parts, "[TEAM]")
	end

	for _, tagId in message.tags do
		local tagConfig = MessageFormatter.getTagConfig(tagId)
		if tagConfig and tagConfig.text then
			table.insert(parts, "[" .. tagConfig.text .. "]")
		end
	end

	if message.rolePrefix and message.rolePrefix ~= "" then
		table.insert(parts, "[" .. message.rolePrefix .. "]")
	end

	local safeDisplayName = TextSanitizer.sanitizeUsername(message.senderName)
	table.insert(parts, safeDisplayName .. ":")

	return table.concat(parts, " ")
end

function MessageFormatter.formatSystemMessage(message: ChatMessage): string
	local safeContent = TextSanitizer.sanitizeForChat(message.content)
	local nameColor = message.nameColor or Theme.Chat.Name.Default
	return string.format(
		'<font color="#%s">%s</font>',
		MessageFormatter.colorToHex(nameColor),
		safeContent
	)
end

function MessageFormatter.formatWhisperMessage(
	message: ChatMessage,
	localUserId: number,
	playerName: string,
	displayName: string
): string
	local safeDisplayName = TextSanitizer.sanitizeUsername(message.senderName)
	local whisperColor = ChatConstants.Colors.whisper

	local whisperPrefix: string
	if message.senderId == localUserId then
		local safeTargetName = TextSanitizer.sanitizeUsername(message.whisperTargetName or "Unknown")
		whisperPrefix = string.format('<font color="#%s"><b>[To %s]</b></font> ', whisperColor, safeTargetName)
	else
		whisperPrefix = string.format('<font color="#%s"><b>[From %s]</b></font> ', whisperColor, safeDisplayName)
	end

	local contentWithMentions = MessageFormatter.highlightMentions(message.content, playerName, displayName)

	return string.format(
		'%s<font color="#%s">%s</font>',
		whisperPrefix,
		whisperColor,
		contentWithMentions
	)
end

function MessageFormatter.formatVultarEnduresMessage(message: ChatMessage): string
	local safeContent = TextSanitizer.sanitizeForChat(message.content)
	local safeDisplayName = TextSanitizer.sanitizeUsername(message.senderName)
	local nameColor = message.nameColor or Theme.Chat.Name.Default
	local tagString, rolePart = MessageFormatter.buildTagAndRoleParts(message, nameColor)
	local enduresColor = MessageFormatter.getVultarEnduresColor(message)

	return string.format(
		'%s%s<font color="#%s"><b>%s:</b></font> <font color="#%s"><b>%s</b></font>',
		tagString,
		rolePart,
		MessageFormatter.colorToHex(nameColor),
		safeDisplayName,
		enduresColor,
		safeContent
	)
end

function MessageFormatter.formatStandardMessage(
	message: ChatMessage,
	playerName: string,
	displayName: string
): string
	local safeDisplayName = TextSanitizer.sanitizeUsername(message.senderName)
	local nameColor = message.nameColor or Theme.Chat.Name.Default
	local tagString, rolePart = MessageFormatter.buildTagAndRoleParts(message, nameColor)

	local teamPart = ""
	if message.isTeamOnly then
		teamPart = string.format('<font color="#%s"><b>[TEAM]</b></font> ', ChatConstants.Colors.teamPrefix)
	end

	local contentWithMentions = MessageFormatter.highlightMentions(message.content, playerName, displayName)

	return string.format(
		'%s%s%s<font color="#%s"><b>%s:</b></font> %s',
		teamPart,
		tagString,
		rolePart,
		MessageFormatter.colorToHex(nameColor),
		safeDisplayName,
		contentWithMentions
	)
end

function MessageFormatter.isVultarEndures(content: string): boolean
	local upperContent = string.upper(content)
	return string.find(upperContent, ChatConstants.Patterns.vultarEndures) ~= nil
end

return MessageFormatter
