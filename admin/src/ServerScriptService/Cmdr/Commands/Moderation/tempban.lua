return {
	Name = "tempban",
	Aliases = { "tban" },
	Description = "Bans players from the whole game for a while, using Roblox's ban system.",
	Group = "Mod",
	Args = {
		{
			Type = "playerIds",
			Name = "players",
			Description = "Who to ban. Works for players who already left.",
		},
		{
			Type = "duration",
			Name = "duration",
			Description = "How long, like 30m, 12h or 7d.",
		},
		{
			Type = "string",
			Name = "reason",
			Description = "Saved with the ban for staff. Banned players see a standard message.",
			Optional = true,
		},
	},
}
