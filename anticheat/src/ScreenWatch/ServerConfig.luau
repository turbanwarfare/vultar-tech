--!strict

export type GroupPermission = {
	GroupId: number,
	MinRank: number,
}

local ServerConfig = {}

ServerConfig.StaffWhitelist = {} :: { number }

ServerConfig.AllowedGroups = {
	{ GroupId = 0, MinRank = 120 },
	{ GroupId = 0, MinRank = 200 },
} :: { GroupPermission }

return ServerConfig
