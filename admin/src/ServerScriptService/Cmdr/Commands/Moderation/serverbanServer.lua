local Players = game:GetService("Players")

local Package = script:FindFirstAncestor("Commands").Parent
local Config = require(Package.Config)
local Moderation = require(Package.Moderation)
local Ranks = require(Package.Ranks)
local Reply = require(Package.Reply)

return function(context, userIds: { number }, reason: string?): string
	local executor = context.Executor
	local filteredReason, reasonError = Moderation.FilterReasonAsync(executor, reason)
	if reasonError then
		return reasonError
	end

	local banned, skipped = {}, {}
	for _, userId in userIds do
		local name = Ranks.GetUserNameAsync(userId)
		if userId == executor.UserId then
			table.insert(skipped, `{name} (that's you)`)
			continue
		end

		local allowed, why = Ranks.CanTargetAsync(executor, userId)
		if not allowed then
			table.insert(skipped, `{name} ({why})`)
			continue
		end

		Moderation.ServerBan(userId)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			Moderation.KickAsync(executor, player, Config.Messages.ServerBan, filteredReason)
		end
		table.insert(banned, name)
	end
	return Reply.Summary("Banned from this server", banned, skipped)
end
