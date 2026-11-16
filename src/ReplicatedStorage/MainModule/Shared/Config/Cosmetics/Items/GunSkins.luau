--!nonstrict
--!native
--!optimize 2

local Constants = require(script.Parent.Parent.Parent.Constants)
local GroupUtils = require(script.Parent.Parent.Parent.Parent.Utils.Game.GroupUtils)

local GROUPS = Constants.GROUPS
local GENERAL_RANK = Constants.RANKS.GENERAL

local isInGroup = GroupUtils.isInGroup

local CONTRIBUTOR_IDS: { [number]: boolean } = {}

local DEV_IDS: { [number]: boolean } = {}

local function isContributor(player: Player): boolean
	if CONTRIBUTOR_IDS[player.UserId] then
		return true
	end
	return isInGroup(player, GROUPS.VULTAR, GENERAL_RANK)
end

local function isDev(player: Player): boolean
	return DEV_IDS[player.UserId] == true
end

local function isGeneral(player: Player): boolean
	return isInGroup(player, GROUPS.VULTAR, GENERAL_RANK)
end

return {
	{ id = "Default", collection = "Default", gamepassIds = {}, purchaseGamepassId = 0 },

	{
		id = "Regal",
		collection = "Regal",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = isDev,
	},
	{
		id = "PixelGun",
		collection = "PixelGun",
		gamepassIds = { 2060795201, 2061442665 },
		purchaseGamepassId = 2060795201,
		price = 1000,
		customCheck = isDev,
	},

	{ id = "Toxic", collection = "Toxic", gamepassIds = { 1775680713, 1763970361 }, purchaseGamepassId = 1775680713 },
	{ id = "HelloKitty", collection = "HelloKitty", gamepassIds = { 1899231358, 1902972726 }, purchaseGamepassId = 1899231358, price = 1300 },
	{ id = "Freeze", collection = "Freeze", gamepassIds = { 1930998900, 1931220905 }, purchaseGamepassId = 1930998900, price = 950 },
	{ id = "Vex", collection = "Vex", gamepassIds = { 1873048751, 1870445094 }, purchaseGamepassId = 1873048751 },

	{ id = "Maxwell", collection = "Maxwell", gamepassIds = { 1587664977 }, purchaseGamepassId = 1587664977 },
	{
		id = "Ghost",
		collection = "Ghost",
		gamepassIds = { 1550436788 },
		purchaseGamepassId = 1550436788,
		visible = false,
	},
	{
		id = "Jack O Lantern",
		collection = "JackOLantern",
		gamepassIds = { 1550488613 },
		purchaseGamepassId = 1550488613,
		visible = false,
	},
	{ id = "Beast", collection = "Beast", gamepassIds = { 1359594567 }, purchaseGamepassId = 1359594567 },
	{ id = "Waves", collection = "Waves", gamepassIds = { 1360658525 }, purchaseGamepassId = 1360658525 },
	{ id = "Far Away", collection = "FarAway", gamepassIds = { 1360850484 }, purchaseGamepassId = 1360850484 },
	{ id = "Commando", collection = "Commando", gamepassIds = { 1360202535 }, purchaseGamepassId = 1360202535 },
	{ id = "Volatil", collection = "Volatil", gamepassIds = { 1360760509 }, purchaseGamepassId = 1360760509 },
	{ id = "Clones", collection = "Clones", gamepassIds = { 1359826580 }, purchaseGamepassId = 1359826580 },
	{ id = "Magma", collection = "Magma", gamepassIds = { 1360700510 }, purchaseGamepassId = 1360700510 },
	{ id = "Punished", collection = "Punished", gamepassIds = { 1359362616 }, purchaseGamepassId = 1359362616 },
	{ id = "Digi", collection = "Digi", gamepassIds = { 1359784609 }, purchaseGamepassId = 1359784609 },

	{ id = "EVA", collection = "EVA", gamepassIds = { 1247160252 }, purchaseGamepassId = 1247160252 },
	{ id = "Fantastique", collection = "Fantastique", gamepassIds = { 1244086092 }, purchaseGamepassId = 1244086092 },
	{ id = "Glitch", collection = "Glitch", gamepassIds = { 1244564660 }, purchaseGamepassId = 1244564660 },
	{ id = "Green", collection = "Green", gamepassIds = { 1244730528 }, purchaseGamepassId = 1244730528 },
	{ id = "Moo", collection = "Moo", gamepassIds = { 1247610102 }, purchaseGamepassId = 1247610102 },
	{ id = "Night", collection = "Night", gamepassIds = { 1246942473 }, purchaseGamepassId = 1246942473 },
	{ id = "Samurai", collection = "Samurai", gamepassIds = { 1247672226 }, purchaseGamepassId = 1247672226 },
	{ id = "Tech", collection = "Tech", gamepassIds = { 1244153905 }, purchaseGamepassId = 1244153905 },

	{
		id = "DT",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player): boolean
			return isInGroup(player, GROUPS.DREADTROOPERS) or isGeneral(player)
		end,
	},
	{
		id = "RG",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player): boolean
			return isInGroup(player, GROUPS.ROYAL_GUARD) or isGeneral(player)
		end,
	},
	{
		id = "VDI",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player): boolean
			return isInGroup(player, GROUPS.VDI, 40) or isGeneral(player)
		end,
	},

	{ id = "Halloween", gamepassIds = {}, purchaseGamepassId = 0, visible = false },

	{
		id = "GeneralCustom",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player): boolean
			return isGeneral(player)
		end,
	},

	{
		id = "Contributors",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = isContributor,
	},
	{
		id = "Contributors_1",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = isContributor,
	},
	{
		id = "Contributors_2",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player): boolean
			return isContributor(player)
		end,
	},

	{
		id = "Invisible",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = isDev,
	},
	{
		id = "Guinea",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = isDev,
	},
	{
		id = "Jeep",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = isDev,
	},
	{
		id = "5NSO",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player): boolean
			return isInGroup(player, GROUPS.FIVE_NSO, 1) or isDev(player)
		end,
	},
	{
		id = "Fish",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player): boolean
			return isDev(player)
		end,
	},
	{
		id = "Test_Skin",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player): boolean
			return isDev(player)
		end,
	},
	{
		id = "Test_Skin2",
		collection = "Test_Skin2",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(): boolean
			return false
		end,
	},
	{
		id = "AoD",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player): boolean
			return isInGroup(player, 16762182) or isDev(player)
		end,
	},
	{
		id = "Squirrel",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = isDev,
	},
	{
		id = "Capybara",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = isDev,
	},
	{
		id = "Racoon",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = isDev,
	},
	{
		id = "Animated",
		collection = "Animated",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = isDev,
	},
}
