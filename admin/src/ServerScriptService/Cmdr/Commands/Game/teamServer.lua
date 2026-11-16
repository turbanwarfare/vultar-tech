local Package = script:FindFirstAncestor("Commands").Parent
local Ranks = require(Package.Ranks)
local Reply = require(Package.Reply)
local Vultar = require(Package.Vultar)

return function(context, players: { Player }, team: Team): string
	local teamService = Vultar.GetService("TeamService")

	local moved, skipped = {}, {}
	for _, player in players do
		local allowed, why = Ranks.CanTargetAsync(context.Executor, player.UserId)
		if not allowed then
			table.insert(skipped, `{player.Name} ({why})`)
			continue
		end

		if not (teamService and teamService:AssignPlayerToTeam(player, team.Name)) then
			player.Team = team
		end
		table.insert(moved, player.Name)
	end
	return Reply.Summary(`Moved to {team.Name}`, moved, skipped)
end
