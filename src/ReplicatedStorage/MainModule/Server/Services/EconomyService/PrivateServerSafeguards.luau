--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Constants = require(MainModule.Shared.Config.Constants)
local RankCache = require(MainModule.Server.Cache.RankCache)

local PrivateServerSafeguards = {}

local MAP_PAYOUTS: { [string]: { Win: number, Loss: number } } = {
	["Mataro"] = { Win = 100, Loss = 50 },
	["Nova"] = { Win = 35, Loss = 15 },
	["Onyx"] = { Win = 50, Loss = 25 },
	["Surrex"] = { Win = 60, Loss = 30 },
	["Pitgrounds"] = { Win = 50, Loss = 25 },
	["Overwatch"] = { Win = 60, Loss = 30 },
	["Silo"] = { Win = 25, Loss = 10 },
	["Ironworks"] = { Win = 50, Loss = 25 },
	["Default"] = { Win = 10, Loss = 5 },
}

PrivateServerSafeguards.MIN_MATCH_DURATION = 800
PrivateServerSafeguards.MIN_TOTAL_PLAYERS = 8
PrivateServerSafeguards.MIN_FACTION_PLAYERS = 6
PrivateServerSafeguards.MIN_ELIGIBLE_PLAYERS = 6
PrivateServerSafeguards.MIN_ATTENDANCE_RATIO = 0.4
PrivateServerSafeguards.MIN_PARTICIPATION_SCORE = 200

export type MatchValidationParams = {
	IsTampered: boolean,
	TamperReason: string?,
	Duration: number,
	DefenderCount: number,
	RaiderCount: number,
	EligibleCount: number,
}

export type PlayerValidationParams = {
	Player: Player,
	MatchDuration: number,
	JoinTimestamp: number,
	MatchScore: number,
}

function PrivateServerSafeguards.isMemberEligible(player: Player): boolean
	return RankCache.isInGroup(player, Constants.GROUPS.VULTAR, 1) or RankCache.isInGroup(player, Constants.GROUPS.VIA, 1)
end

function PrivateServerSafeguards.getPayout(mapName: string, isWinner: boolean): number
	local entry = MAP_PAYOUTS[mapName] or MAP_PAYOUTS["Default"]
	return if isWinner then entry.Win else entry.Loss
end

function PrivateServerSafeguards.validateMatch(params: MatchValidationParams): (boolean, string?)
	if params.IsTampered then
		return false, `Match was manually tampered or altered: {params.TamperReason or "Unknown reason"}`
	end

	if params.Duration < PrivateServerSafeguards.MIN_MATCH_DURATION then
		return false, `Match duration ({math.floor(params.Duration)}s) below minimum {PrivateServerSafeguards.MIN_MATCH_DURATION}s`
	end

	local totalPlayers = params.DefenderCount + params.RaiderCount
	if totalPlayers < PrivateServerSafeguards.MIN_TOTAL_PLAYERS then
		return false, `Total players ({totalPlayers}) below minimum {PrivateServerSafeguards.MIN_TOTAL_PLAYERS}`
	end

	if params.DefenderCount < PrivateServerSafeguards.MIN_FACTION_PLAYERS or params.RaiderCount < PrivateServerSafeguards.MIN_FACTION_PLAYERS then
		return false, `Teams under minimum: {params.DefenderCount} Defenders vs {params.RaiderCount} Raiders`
	end

	if params.EligibleCount < PrivateServerSafeguards.MIN_ELIGIBLE_PLAYERS then
		return false, `Vultar/VIA members ({params.EligibleCount}) below minimum {PrivateServerSafeguards.MIN_ELIGIBLE_PLAYERS}`
	end

	return true, nil
end

function PrivateServerSafeguards.validatePlayer(params: PlayerValidationParams): (boolean, string?)
	if not PrivateServerSafeguards.isMemberEligible(params.Player) then
		return false, "Player is not in Vultar or VIA"
	end

	local timeInMatch = os.clock() - params.JoinTimestamp
	local minRequiredTime = params.MatchDuration * PrivateServerSafeguards.MIN_ATTENDANCE_RATIO
	if timeInMatch < minRequiredTime then
		return false, `Attendance ({math.floor(timeInMatch)}s) below required {math.floor(minRequiredTime)}s`
	end

	if params.MatchScore < PrivateServerSafeguards.MIN_PARTICIPATION_SCORE then
		return false, `Combat score ({params.MatchScore}) below minimum {PrivateServerSafeguards.MIN_PARTICIPATION_SCORE}`
	end

	return true, nil
end

return PrivateServerSafeguards
