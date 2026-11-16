--!strict
--!native
--!optimize 2

local ChannelNames = {}

local PREFIX = "Vultar"
local TEAM_PREFIX = PREFIX .. "Team"
local WHISPER_PREFIX = PREFIX .. "Whisper_"

ChannelNames.Prefix = PREFIX
ChannelNames.Factions = { "Defenders", "Raiders" }

function ChannelNames.forChannel(channelId: string): string
	return PREFIX .. channelId
end

function ChannelNames.forTeam(faction: string): string
	return TEAM_PREFIX .. faction
end

function ChannelNames.forWhisper(userIdA: number, userIdB: number): string
	local low = if userIdA < userIdB then userIdA else userIdB
	local high = if userIdA < userIdB then userIdB else userIdA
	return string.format("%s%d_%d", WHISPER_PREFIX, low, high)
end

function ChannelNames.gameChannelId(name: string): string?
	if string.sub(name, 1, #PREFIX) ~= PREFIX then
		return nil
	end
	local rest = string.sub(name, #PREFIX + 1)
	if string.match(rest, "^%u+$") then
		return rest
	end
	return nil
end

function ChannelNames.teamFaction(name: string): string?
	if string.sub(name, 1, #TEAM_PREFIX) ~= TEAM_PREFIX then
		return nil
	end
	local rest = string.sub(name, #TEAM_PREFIX + 1)
	if #rest == 0 then
		return nil
	end
	return rest
end

function ChannelNames.whisperParticipants(name: string): (number?, number?)
	if string.sub(name, 1, #WHISPER_PREFIX) ~= WHISPER_PREFIX then
		return nil, nil
	end
	local a, b = string.match(string.sub(name, #WHISPER_PREFIX + 1), "^(%d+)_(%d+)$")
	if not a or not b then
		return nil, nil
	end
	return tonumber(a), tonumber(b)
end

return ChannelNames
