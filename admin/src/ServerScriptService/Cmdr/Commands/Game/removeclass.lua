return {
	Name = "removeclass",
	Aliases = { "rc" },
	Description = "Resets players' class to Assault.",
	Group = "Admin",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Whose class to reset.",
		},
	},
}
