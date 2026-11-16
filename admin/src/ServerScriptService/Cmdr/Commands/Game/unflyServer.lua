local Reply = require(script:FindFirstAncestor("Commands").Parent.Reply)

return function(context, players: { Player }): string
	local stopped = {}
	for _, player in players do
		context:SendEvent(player, "Fly", false)
		table.insert(stopped, player.Name)
	end
	return Reply.Summary("Stopped flying", stopped, {})
end
