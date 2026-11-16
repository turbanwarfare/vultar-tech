local Ranks = require(script:FindFirstAncestor("Commands").Parent.Ranks)

return function(context, userId: number, length: string): string
	return Ranks.GrantCommand(context, userId, "Admin+", length == "temp")
end
