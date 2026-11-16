return {
	Name = "unadmin+",
	Description = "Removes Admin+ that was given with the admin+ command.",
	Group = "Developer",
	Args = {
		{
			Type = "playerId",
			Name = "player",
			Description = "Who to remove it from. Works for players who aren't in this server.",
		},
	},
}
