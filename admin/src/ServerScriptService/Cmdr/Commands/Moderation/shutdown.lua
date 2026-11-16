return {
	Name = "shutdown",
	Description = "Removes everyone and closes this server.",
	Group = "Mod",
	Args = {
		{
			Type = "positiveInteger",
			Name = "countdown",
			Description = "Seconds to wait first, with a countdown on everyone's screen.",
			Optional = true,
		},
	},
}
