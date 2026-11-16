return {
	Name = "unmod",
	Description = "Removes Mod that was given with the mod command.",
	Group = "Admin",
	Args = {
		{
			Type = "playerId",
			Name = "player",
			Description = "Who to remove it from. Works for players who aren't in this server.",
		},
	},
}
