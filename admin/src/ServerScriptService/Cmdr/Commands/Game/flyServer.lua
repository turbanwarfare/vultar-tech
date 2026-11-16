local Reply = require(script:FindFirstAncestor("Commands").Parent.Reply)

return function(context, players: { Player }): string
	local flying, skipped = {}, {}
	for _, player in players do
		if player.Character then
			context:SendEvent(player, "Fly", true)
			table.insert(flying, player.Name)
		else
			table.insert(skipped, `{player.Name} (no character)`)
		end
	end
	return Reply.Summary("Flying", flying, skipped)
end
