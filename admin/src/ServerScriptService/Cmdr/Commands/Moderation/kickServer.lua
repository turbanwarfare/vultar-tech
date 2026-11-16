local Package = script:FindFirstAncestor("Commands").Parent
local Config = require(Package.Config)
local Moderation = require(Package.Moderation)
local Ranks = require(Package.Ranks)
local Reply = require(Package.Reply)

return function(context, players: { Player }, reason: string?): string
	local executor = context.Executor
	local filteredReason, reasonError = Moderation.FilterReasonAsync(executor, reason)
	if reasonError then
		return reasonError
	end

	local kicked, skipped = {}, {}
	for _, player in players do
		local allowed, why = Ranks.CanTargetAsync(executor, player.UserId)
		if allowed then
			Moderation.KickAsync(executor, player, Config.Messages.Kick, filteredReason)
			table.insert(kicked, player.Name)
		else
			table.insert(skipped, `{player.Name} ({why})`)
		end
	end
	return Reply.Summary("Kicked", kicked, skipped)
end
