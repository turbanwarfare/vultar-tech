--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local ChatConfig = require(MainModule.Shared.Config.Chat.ChatConfig)

local Commands = {}

Commands.Whisper = {
	w = true,
	whisper = true,
	msg = true,
	dm = true,
}

Commands.Team = {
	t = true,
	team = true,
}

Commands.All = {
	a = true,
	all = true,
}

Commands.Admin = {
	rl = true,
	raidleader = true,
	unrl = true,
	unraidleader = true,
	mute = true,
	unmute = true,
	dump = true,
	rc = true,
	removeclass = true,
	skipphase = true,
	["end"] = true,
	screenwatch = true,
	sw = true,
	ws = true,
	watchscreen = true,
	coinflip = true,
	cf = true,
	setpoints = true,
	official = true,
	grouplock = true,
	gl = true,
	ungrouplock = true,
	ungl = true,
}

export type CommandResult = {
	handled: boolean,
	channelId: string?,
	filter: string?,
	message: string?,
	isTeamOnly: boolean,
	whisperTarget: Player?,
}

function Commands.isWhisperCommand(command: string): boolean
	return Commands.Whisper[string.lower(command)] == true
end

function Commands.isTeamCommand(command: string): boolean
	return Commands.Team[string.lower(command)] == true
end

function Commands.isAllCommand(command: string): boolean
	return Commands.All[string.lower(command)] == true
end

function Commands.isAdminCommand(text: string): boolean
	local command = string.match(text, "^[:!](%w+)")
	return command ~= nil and Commands.Admin[string.lower(command)] == true
end

function Commands.isBuiltInCommand(text: string): boolean
	local command = string.match(text, "^[:!](%w+)")
	if not command then
		return false
	end
	command = string.lower(command)
	return Commands.Admin[command] == true or Commands.Whisper[command] == true or Commands.Team[command] == true or Commands.All[command] == true
end

function Commands.looksLikeCommand(text: string): boolean
	local _word, rest = string.match(text, "^[:!](%a%a+)(.*)$")
	if not _word then
		return false
	end
	return rest == "" or string.match(rest, "^%s") ~= nil
end

function Commands.parse(text: string, findPlayerByPartial: ((name: string) -> Player?)?): CommandResult
	local result: CommandResult = {
		handled = false,
		channelId = nil,
		filter = nil,
		message = nil,
		isTeamOnly = false,
		whisperTarget = nil,
	}

	local firstChar = string.sub(text, 1, 1)
	if firstChar ~= "/" then
		return result
	end

	local spacePos = string.find(text, " ", 2, true)
	local command: string
	local remainder: string?

	if spacePos then
		command = string.sub(text, 2, spacePos - 1)
		local rest = string.sub(text, spacePos + 1)
		if #rest == 0 then
			remainder = nil
		else
			remainder = rest
		end
	else
		command = string.sub(text, 2)
		remainder = nil
	end

	local lowerCommand = string.lower(command)

	if Commands.Whisper[lowerCommand] then
		result.handled = true
		if remainder and findPlayerByPartial then
			local nextSpace = string.find(remainder, " ", 1, true)
			local targetName: string
			local messageContent: string?

			if nextSpace then
				targetName = string.sub(remainder, 1, nextSpace - 1)
				local msgContent = string.sub(remainder, nextSpace + 1)
				if #msgContent == 0 then
					messageContent = nil
				else
					messageContent = msgContent
				end
			else
				targetName = remainder
				messageContent = nil
			end

			local targetPlayer = findPlayerByPartial(targetName)
			if targetPlayer then
				result.whisperTarget = targetPlayer
				result.message = messageContent
			end
		end
		return result
	end

	if Commands.Team[lowerCommand] then
		result.handled = true
		result.channelId = "GLOBAL"
		result.filter = "TEAM"
		result.message = remainder
		result.isTeamOnly = true
		return result
	end

	if Commands.All[lowerCommand] then
		result.handled = true
		result.channelId = "GLOBAL"
		result.filter = "ALL"
		result.message = remainder
		result.isTeamOnly = false
		return result
	end

	local channelId = ChatConfig.getChannelIdFromCommand(lowerCommand)
	if channelId then
		result.handled = true
		result.channelId = channelId
		result.message = remainder
		return result
	end

	return result
end

return Commands
