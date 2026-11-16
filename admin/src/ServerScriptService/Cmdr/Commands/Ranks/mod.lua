return {
	Name = "mod",
	Description = "Makes a player Mod. Add \"temp\" to only give it for this server.",
	Group = "Admin",
	Args = {
		{
			Type = "playerId",
			Name = "player",
			Description = "Who to rank. Works for players who aren't in this server.",
		},
		{
			Type = "rankLength",
			Name = "length",
			Description = "\"temp\" for this server only. Leave it out to save the rank.",
			Default = "perm",
		},
	},
}
