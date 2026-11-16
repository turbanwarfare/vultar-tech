return {
	Name = "serverban",
	Aliases = { "ban", "sban" },
	Description = "Bans players from this server until it closes.",
	Group = "Mod",
	Args = {
		{
			Type = "playerIds",
			Name = "players",
			Description = "Who to ban. Works for players who already left.",
		},
		{
			Type = "string",
			Name = "reason",
			Description = "Shown to banned players who are in the server.",
			Optional = true,
		},
	},
}
