return {
	Name = "unban",
	Description = "Lifts server bans and temp bans.",
	Group = "Mod",
	Args = {
		{
			Type = "playerIds",
			Name = "players",
			Description = "Who to unban.",
		},
	},
}
