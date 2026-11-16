local Players = game:GetService("Players")

local Package = script:FindFirstAncestor("Commands").Parent
local Config = require(Package.Config)
local Ranks = require(Package.Ranks)
local Reply = require(Package.Reply)

return function(context, userIds: { number }, duration: number, reason: string?): string
	local executor = context.Executor
	local seconds = math.floor(duration)
	if seconds < 1 then
		return "The ban has to last at least 1 second."
	end
	if reason and (utf8.len(reason) or #reason) > Config.MaxTextLength then
		return `Keep the reason under {Config.MaxTextLength} characters.`
	end

	local length = Reply.Duration(seconds)
	local note = if reason and reason:match("%S") then reason else "No reason given"

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

		local ok, err = pcall(Players.BanAsync, Players, {
			UserIds = { userId },
			ApplyToUniverse = true,
			Duration = seconds,
			DisplayReason = Config.Messages.TempBan,
			PrivateReason = `Temp ban by {executor.Name} ({executor.UserId}) for {length}: {note}`,
			ExcludeAltAccounts = false,
		})
		if not ok then
			table.insert(skipped, `{name} (ban failed: {err})`)
			continue
		end

		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:Kick(Config.Messages.TempBan)
		end
		table.insert(banned, name)
	end
	return Reply.Summary(`Banned for {length}`, banned, skipped)
end
