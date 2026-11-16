return {
	GroupId = 0,

	GroupRanks = {
		{ Min = 254, Max = 255, Rank = "Developer" },
		{ Min = 200, Max = 253, Rank = "Admin+" },
		{ Min = 80, Max = 100, Rank = "Admin" },
		{ Min = 50, Max = 60, Rank = "Mod" },
	},

	PrivateServer = {
		GroupRanks = { "Developer" },
		OwnerRank = "Mod",
	},

	DataStoreName = "CmdrStaffRanks",
	MessagingTopic = "CmdrStaffRanks",

	MaxTextLength = 200,

	Messages = {
		Kick = "You were kicked by a staff member.",
		ServerBan = "You are banned from this server.",
		TempBan = "You are temporarily banned from this experience.",
		Shutdown = "This server has been shut down.",
	},
}
