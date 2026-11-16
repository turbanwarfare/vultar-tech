--!nonstrict
--!native
--!optimize 2

local Constants = require(script.Parent.Parent.Constants)

local ChatConfig = {}

ChatConfig.MAIN_GROUP_ID = Constants.GROUPS.VULTAR
ChatConfig.ROYAL_GROUP_ID = Constants.GROUPS.ROYAL_GUARD
ChatConfig.TRAINING_GROUP_ID = Constants.GROUPS.VIA
ChatConfig.DT_GROUP_ID = Constants.GROUPS.DREADTROOPERS

ChatConfig.Channels = {
	{
		id = "GLOBAL",
		name = "GLOBAL",
		icon = "rbxassetid://98751546690059",
		color = Color3.fromRGB(180, 180, 185),
		order = 1,
	},
	{
		id = "OFFICER",
		name = "OFFICER",
		icon = "rbxassetid://105485886032455",
		color = Color3.fromRGB(180, 180, 185),
		order = 2,
	},
	{
		id = "HICOM",
		name = "HICOM",
		icon = "rbxassetid://85345278524858",
		color = Color3.fromRGB(180, 180, 185),
		order = 3,
	},
	{
		id = "RAID",
		name = "RAID",
		icon = "rbxassetid://97774994526788",
		color = Color3.fromRGB(180, 180, 185),
		order = 4,
	},
	{
		id = "ROYAL",
		name = "ROYAL",
		icon = "rbxassetid://137934867321047",
		color = Color3.fromRGB(180, 180, 185),
		order = 5,
	},
	{
		id = "DREAD",
		name = "DREAD",
		icon = "rbxassetid://105801552657804",
		iconSize = Vector2.new(38, 30),
		color = Color3.fromRGB(180, 180, 185),
		order = 6,
	},
}

ChatConfig.ChannelRequirements = {
	GLOBAL = { type = "all" },
	OFFICER = { type = "rank", groupId = Constants.GROUPS.VULTAR, minRank = 80 },
	HICOM = { type = "rank", groupId = Constants.GROUPS.VULTAR, minRank = 200 },
	RAID = { type = "raid" },
	ROYAL = { type = "group", groupId = Constants.GROUPS.ROYAL_GUARD },
	DREAD = {
		type = "any",
		requirements = {
			{ type = "group", groupId = Constants.GROUPS.DREADTROOPERS },
			{ type = "whitelist", userIds = {} },
		},
	},
}

ChatConfig.Roles = {
	{ groupId = Constants.GROUPS.VULTAR, name = "Imperator", prefix = "Imperator", color = Color3.fromRGB(98, 37, 209), rank = 255 },
	{ groupId = Constants.GROUPS.VULTAR, name = "Developer", prefix = "DEV", color = Color3.fromRGB(92, 144, 179), rank = 254 },
	{ groupId = Constants.GROUPS.VULTAR, name = "Supreme General", prefix = "SGEN", color = Color3.fromRGB(98, 37, 209), rank = 252 },
	{ groupId = Constants.GROUPS.VULTAR, name = "General", prefix = "GEN", color = Color3.fromRGB(190, 104, 98), rank = 250 },
	{ groupId = Constants.GROUPS.VULTAR, name = "Colonel", prefix = "COL", color = Color3.fromRGB(86, 36, 36), rank = 200 },
	{ groupId = Constants.GROUPS.VULTAR, name = "Major", prefix = "MAJ", color = Color3.fromRGB(163, 75, 75), rank = 100 },
	{ groupId = Constants.GROUPS.VULTAR, name = "Captain", prefix = "CPT", color = Color3.fromRGB(163, 75, 75), rank = 90 },
	{ groupId = Constants.GROUPS.VULTAR, name = "Lieutenant", prefix = "LT", color = Color3.fromRGB(163, 75, 75), rank = 80 },
	{ groupId = Constants.GROUPS.VULTAR, name = "Retired Vultarian", prefix = "RET", color = Color3.fromRGB(60, 62, 95), rank = 70 },
	{ groupId = Constants.GROUPS.VULTAR, name = "Warrant Officer", prefix = "WO", color = Color3.fromRGB(255, 89, 89), rank = 60 },
	{ groupId = Constants.GROUPS.VULTAR, name = "Sergeant", prefix = "SGT", color = Color3.fromRGB(255, 89, 89), rank = 50 },
	{ groupId = Constants.GROUPS.VULTAR, name = "Corporal", prefix = "CPL", color = Color3.fromRGB(255, 89, 89), rank = 40 },
	{ groupId = Constants.GROUPS.VULTAR, name = "Lance Corporal", prefix = "LCPL", color = Color3.fromRGB(255, 89, 89), rank = 30 },
	{ groupId = Constants.GROUPS.VULTAR, name = "Private First Class", prefix = "PFC", color = Color3.fromRGB(255, 89, 89), rank = 20 },
	{ groupId = Constants.GROUPS.VULTAR, name = "Private", prefix = "PVT", color = Color3.fromRGB(255, 89, 89), rank = 10 },
	{ groupId = Constants.GROUPS.VIA, name = "Stage 3", prefix = "S3", color = Color3.fromRGB(99, 95, 98), rank = 120 },
	{ groupId = Constants.GROUPS.VIA, name = "Stage 2", prefix = "S2", color = Color3.fromRGB(99, 95, 98), rank = 110 },
	{ groupId = Constants.GROUPS.VIA, name = "Stage 1", prefix = "S1", color = Color3.fromRGB(99, 95, 98), rank = 100 },
}

ChatConfig.Tags = {
	{
		id = "royal",
		text = "RG",
		textColor = Color3.fromRGB(255, 255, 255),
		backgroundColor = Color3.fromRGB(185, 158, 20),
		priority = 90,
		requirement = { type = "group", groupId = Constants.GROUPS.ROYAL_GUARD },
	},
	{
		id = "dt",
		text = "DT",
		textColor = Color3.fromRGB(40, 40, 45),
		backgroundColor = Color3.fromRGB(192, 197, 206),
		priority = 80,
		requirement = { type = "group", groupId = Constants.GROUPS.DREADTROOPERS },
	},
	{
		id = "viacom",
		text = "VIACOM",
		textColor = Color3.fromRGB(255, 255, 255),
		backgroundColor = Color3.fromRGB(255, 89, 89),
		priority = 70,
		requirement = { type = "ranks", groupId = Constants.GROUPS.VIA, ranks = { 150, 170 } },
	},
}

ChatConfig.NameColors = {
	{ requirement = { type = "rank", groupId = Constants.GROUPS.VULTAR, minRank = 255 }, color = Color3.fromRGB(98, 37, 209) },
	{ requirement = { type = "rank", groupId = Constants.GROUPS.VULTAR, minRank = 254 }, color = Color3.fromRGB(92, 144, 179) },
	{ requirement = { type = "rank", groupId = Constants.GROUPS.VULTAR, minRank = 252 }, color = Color3.fromRGB(98, 37, 209) },
	{ requirement = { type = "rank", groupId = Constants.GROUPS.VULTAR, minRank = 250 }, color = Color3.fromRGB(190, 104, 98) },
	{ requirement = { type = "rank", groupId = Constants.GROUPS.VULTAR, minRank = 200 }, color = Color3.fromRGB(86, 36, 36) },
	{ requirement = { type = "rank", groupId = Constants.GROUPS.VULTAR, minRank = 80 }, color = Color3.fromRGB(163, 75, 75) },
	{ requirement = { type = "rank", groupId = Constants.GROUPS.VULTAR, minRank = 50 }, color = Color3.fromRGB(255, 89, 89) },
	{ requirement = { type = "rank", groupId = Constants.GROUPS.VULTAR, minRank = 1 }, color = Color3.fromRGB(255, 89, 89) },
}

ChatConfig.Settings = {
	maxMessageLength = 200,
	messageHistorySize = 50,
	rateLimitMessages = 60,
	rateLimitWindow = 10,
	systemMessageColor = Color3.fromRGB(255, 230, 100),
}

local channelCommandCache: { [string]: string }? = nil

local tagConfigCache: { [string]: { text: string?, icon: string?, textColor: Color3?, backgroundColor: Color3? } } = {}
for _, tag in ChatConfig.Tags do
	tagConfigCache[tag.id] = {
		text = tag.text,
		icon = tag.icon,
		textColor = tag.textColor,
		backgroundColor = tag.backgroundColor,
	}
end

function ChatConfig.getTagConfig(tagId: string): { text: string?, icon: string?, textColor: Color3?, backgroundColor: Color3? }?
	return tagConfigCache[tagId]
end

local channelConfigCache: { [string]: { name: string, icon: string, iconSize: Vector2?, iconOffsetY: number?, color: Color3, order: number } } = {}
for _, channel in ChatConfig.Channels do
	channelConfigCache[channel.id] = {
		name = channel.name,
		icon = channel.icon,
		iconSize = channel.iconSize,
		iconOffsetY = (channel :: any).iconOffsetY,
		color = channel.color,
		order = channel.order,
	}
end

function ChatConfig.getChannelConfig(channelId: string): { name: string, icon: string, iconSize: Vector2?, iconOffsetY: number?, color: Color3, order: number }?
	return channelConfigCache[channelId]
end

function ChatConfig.getChannelIdFromCommand(command: string): string?
	if not channelCommandCache then
		local cache: { [string]: string } = {}
		for _, channel in ChatConfig.Channels do
			local lowerId = string.lower(channel.id)
			local lowerName = string.lower(channel.name)
			cache[lowerId] = channel.id
			if lowerName ~= lowerId then
				cache[lowerName] = channel.id
			end
		end
		cache["g"] = "GLOBAL"
		cache["o"] = "OFFICER"
		cache["h"] = "HICOM"
		cache["r"] = "RAID"
		cache["d"] = "DREAD"
		channelCommandCache = cache
	end
	return (channelCommandCache :: { [string]: string })[string.lower(command)]
end

return ChatConfig
