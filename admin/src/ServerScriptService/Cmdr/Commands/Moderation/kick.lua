return {
	Name = "kick",
	Description = "Removes players from the server.",
	Group = "Mod",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Who to kick.",
		},
		{
			Type = "string",
			Name = "reason",
			Description = "Shown to the kicked players.",
			Optional = true,
		},
	},
}
