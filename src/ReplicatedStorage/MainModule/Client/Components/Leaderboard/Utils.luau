--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local StatsConfig = require(MainModule.Shared.Config.Stats.StatsConfig)
local Maps = require(MainModule.Shared.Config.Maps)
local Constants = require(script.Parent.Constants)

type PlayerStats = StatsConfig.PlayerStats

local Utils = {}

function Utils.formatNumber(n: number): string
	return tostring(math.floor(n))
end

function Utils.getStatValue(stats: PlayerStats, key: string): string
	if key == "Kills" then
		return tostring(stats.Kills)
	elseif key == "Damage" then
		return Utils.formatNumber(stats.Damage)
	elseif key == "Heals" then
		return Utils.formatNumber(stats.Heals)
	elseif key == "Captures" then
		return tostring(stats.Captures)
	end
	return "0"
end

function Utils.isSpectator(teamName: string?): boolean
	return Maps.getTeamFaction(teamName) == "Neutral"
end

function Utils.getTextColor(isLocalPlayer: boolean, isSpectator: boolean): Color3
	if isLocalPlayer then
		return Constants.Colors.LocalPlayer
	elseif isSpectator then
		return Constants.Colors.SpectatorText
	end
	return Constants.Colors.DefaultText
end

function Utils.getTextTransparency(isSpectator: boolean, _isLocalPlayer: boolean): number
	if isSpectator then
		return Constants.SPECTATOR_TEXT_TRANSPARENCY
	end
	return 0
end

function Utils.createEntryKey(entry: StatsConfig.LeaderboardEntry): string
	return tostring(entry.UserId)
end

return Utils
