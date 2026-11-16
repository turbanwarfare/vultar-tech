--!strict
--!native
--!optimize 2

local GroupUtils = {}

function GroupUtils.isInGroup(player: Player, groupId: number, minRank: number?): boolean
	local ok, rank = pcall(player.GetRankInGroup, player, groupId)
	if not ok then
		return false
	end
	return rank >= (minRank or 1)
end

return GroupUtils
