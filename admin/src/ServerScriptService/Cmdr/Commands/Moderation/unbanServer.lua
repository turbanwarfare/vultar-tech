local Players = game:GetService("Players")

local Package = script:FindFirstAncestor("Commands").Parent
local Moderation = require(Package.Moderation)
local Ranks = require(Package.Ranks)
local Reply = require(Package.Reply)

return function(_, userIds: { number }): string
	local unbanned, failed = {}, {}
	for _, userId in userIds do
		local name = Ranks.GetUserNameAsync(userId)
		Moderation.RemoveServerBan(userId)

		local ok, err = pcall(Players.UnbanAsync, Players, {
			UserIds = { userId },
			ApplyToUniverse = true,
		})
		if ok then
			table.insert(unbanned, name)
		else
			table.insert(failed, `{name} (game unban failed: {err})`)
		end
	end
	return Reply.Summary("Unbanned", unbanned, failed)
end
