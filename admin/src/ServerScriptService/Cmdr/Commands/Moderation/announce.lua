return {
	Name = "announce",
	Aliases = { "m" },
	Description = "Shows a message at the top of everyone's screen.",
	Group = "Mod",
	Args = {
		{
			Type = "string",
			Name = "message",
			Description = "What to say.",
		},
	},
}
