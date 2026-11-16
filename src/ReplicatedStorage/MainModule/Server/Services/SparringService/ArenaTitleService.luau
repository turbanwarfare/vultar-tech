--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local SparConfig = require(MainModule.Shared.Config.SparConfig)

local ArenaTitleService = {}

function ArenaTitleService.GetRankForWins(wins: number): (string, Color3)
	local rankName = "UNPROVEN"
	local rankColor = Color3.fromRGB(160, 160, 160)

	for _, rank in SparConfig.TITLE_THRESHOLDS do
		if wins >= rank.Wins then
			rankName = rank.Name
			rankColor = rank.Color
		else
			break
		end
	end

	return rankName, rankColor
end

function ArenaTitleService.GetUnlockedTitles(wins: number): { string }
	local titles: { string } = {}
	for _, rank in SparConfig.TITLE_THRESHOLDS do
		if wins >= rank.Wins then
			table.insert(titles, rank.Name)
		end
	end
	return titles
end

function ArenaTitleService.CheckTitleUnlock(player: Player, _previousWins: number, _currentWins: number)
	if not player then
		return
	end

end

function ArenaTitleService.cleanup()

end

return ArenaTitleService
