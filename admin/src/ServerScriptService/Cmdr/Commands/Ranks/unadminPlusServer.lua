local Ranks = require(script:FindFirstAncestor("Commands").Parent.Ranks)

return function(context, userId: number): string
	return Ranks.RevokeCommand(context, userId, "Admin+")
end
