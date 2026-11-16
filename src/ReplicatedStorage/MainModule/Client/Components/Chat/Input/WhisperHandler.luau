--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local PlayerCache = require(MainModule.Shared.Cache.PlayerCache)
local ChatCommands = require(MainModule.Shared.Chat.Commands)
local ChatConstants = require(MainModule.Shared.Chat.Constants)

local LocalPlayer = Players.LocalPlayer

local WhisperHandler = {}

function WhisperHandler.getWhisperInfo(text: string): (string?, string?, string?)
	local firstChar = string.sub(text, 1, 1)
	if firstChar ~= "/" then
		return nil, nil, nil
	end

	local spacePos = string.find(text, " ", 2, true)
	if not spacePos then
		return nil, nil, nil
	end

	local command = string.lower(string.sub(text, 2, spacePos - 1))
	if not ChatCommands.isWhisperCommand(command) then
		return nil, nil, nil
	end

	local originalCommand = string.sub(text, 2, spacePos - 1)
	local commandPrefix = "/" .. originalCommand .. " "

	local afterCommand = string.sub(text, spacePos + 1)
	if #afterCommand == 0 then
		return nil, nil, commandPrefix
	end

	local nextSpace = string.find(afterCommand, " ", 1, true)
	local targetName = if nextSpace then string.sub(afterCommand, 1, nextSpace - 1) else afterCommand

	local cachedPlayer = PlayerCache.findByPartial(targetName)
	if cachedPlayer and cachedPlayer.player ~= LocalPlayer then
		local actualNameInText = targetName
		local expectedName = cachedPlayer.player.Name

		if string.lower(actualNameInText) == string.lower(expectedName) then
			local fullPrefix = "/" .. originalCommand .. " " .. expectedName .. " "
			return cachedPlayer.player.DisplayName, fullPrefix, commandPrefix
		end
	end
	return nil, nil, commandPrefix
end

function WhisperHandler.processAutofill(
	newText: string,
	isDeleting: boolean,
	lastAutofillText: string
): string?
	if isDeleting then
		return nil
	end

	if lastAutofillText == newText then
		return nil
	end

	local firstChar = string.sub(newText, 1, 1)
	if firstChar ~= "/" then
		return nil
	end

	local spacePos = string.find(newText, " ", 2, true)
	if not spacePos then
		return nil
	end

	local command = string.lower(string.sub(newText, 2, spacePos - 1))
	if not ChatCommands.isWhisperCommand(command) then
		return nil
	end

	local afterCommand = string.sub(newText, spacePos + 1)
	local hasMessageContent = string.find(afterCommand, " ", 1, true)
	if hasMessageContent or #afterCommand < ChatConstants.Input.minAutofillLength then
		return nil
	end

	local cachedPlayer, matchedName = PlayerCache.findByUniquePrefix(afterCommand)
	if not cachedPlayer or not matchedName or cachedPlayer.player == LocalPlayer then
		return nil
	end

	local lowerPartial = string.lower(afterCommand)
	local lowerMatched = string.lower(matchedName)
	if lowerPartial == lowerMatched then
		return nil
	end

	local originalCommand = string.sub(newText, 2, spacePos - 1)
	return "/" .. originalCommand .. " " .. matchedName .. " "
end

function WhisperHandler.buildStyledText(
	text: string,
	prefix: string,
	targetName: string
): string?
	local commandEnd = string.find(prefix, " ", 2, true)
	if not commandEnd then
		return nil
	end

	local command = string.sub(prefix, 1, commandEnd)
	local messagePart = ""
	if #text > #prefix then
		messagePart = string.sub(text, #prefix + 1)
	end

	return string.format(
		'<font color="#888890">%s</font><font color="#FFDD44"><b>%s </b></font><font color="#C8C8D2">%s</font>',
		command,
		targetName,
		messagePart
	)
end

return WhisperHandler
