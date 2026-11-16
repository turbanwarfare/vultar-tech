return {
	Name = "watch",
	Aliases = { "w" },
	Description = "Points your camera at a player. Use it on yourself to stop.",
	Group = "Mod",
	Args = {
		{
			Type = "player",
			Name = "target",
			Description = "Who to watch. Pick yourself to stop watching.",
		},
	},
}
