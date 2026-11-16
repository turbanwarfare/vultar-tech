--!nonstrict
--!native
--!optimize 2

local Constants = require(script.Parent.Parent.Parent.Constants)
local GroupUtils = require(script.Parent.Parent.Parent.Parent.Utils.Game.GroupUtils)
local Types = require(script.Parent.Parent.Types)

type ItemConfig = Types.ItemConfig

local GROUPS = Constants.GROUPS
local GENERAL_RANK = 250

local isInGroup = GroupUtils.isInGroup

local DEVELOPER_IDS: { [number]: boolean } = {}
local CONTRIBUTOR_IDS: { [number]: boolean } = {}

local customSkinOwners: { [number]: boolean } = {}

local function isDeveloper(player: Player): boolean
	return DEVELOPER_IDS[player.UserId] == true
end

local function hasCustomSkins(player: Player): boolean
	return customSkinOwners[player.UserId] == true
end

local function isContributor(player: Player): boolean
	return CONTRIBUTOR_IDS[player.UserId] == true
end

local function isGeneralOrHigher(player: Player): boolean
	return isInGroup(player, GROUPS.VULTAR, GENERAL_RANK)
end

return {
	{
		id = "StarWarsDev_PlayerCard",
		name = "Star Wars DEVELOPER",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://107118604553677",
		visible = false,
		customCheck = function(player: Player)
			return isInGroup(player, GROUPS.ROYAL_GUARD) or isDeveloper(player)
		end,
	},
	{
		id = "Eclipse_PlayerCard",
		name = "Eclipse",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://97692965224333",
		visible = false,
		customCheck = function(player: Player)
			return isDeveloper(player)
		end,
	},

	{
		id = "DT_GunSkin",
		name = "DT",
		category = "GunSkin",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player)
			return isInGroup(player, GROUPS.DREADTROOPERS) or isGeneralOrHigher(player)
		end,
	},
	{
		id = "Testing_Skin",
		name = "idk lol",
		category = "GunSkin",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player)
			return hasCustomSkins(player)
		end,
	},
	{
		id = "RG_GunSkin",
		name = "RG",
		category = "GunSkin",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player)
			return isInGroup(player, GROUPS.ROYAL_GUARD) or isGeneralOrHigher(player)
		end,
	},
	{
		id = "VDI_GunSkin",
		name = "VDI",
		category = "GunSkin",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player)
			return isInGroup(player, GROUPS.VDI, 40) or isGeneralOrHigher(player)
		end,
	},

	{
		id = "Contributors_GunSkin",
		name = "Contributors",
		category = "GunSkin",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player)
			return isContributor(player) or isGeneralOrHigher(player)
		end,
	},
	{
		id = "Contributors1_GunSkin",
		name = "Contributors",
		category = "GunSkin",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		isNew = true,
		season = "2",
		customCheck = function(player: Player)
			return isContributor(player) or isGeneralOrHigher(player)
		end,
	},
	{
		id = "Vex_GunSkin",
		name = "Vex",
		category = "GunSkin",
		gamepassIds = { 1870445094, 1873048751 },
		purchaseGamepassId = 1873048751,
		visible = true,
		isNew = true,
		season = "3",
		customCheck = function(player: Player)
			return isContributor(player) or isGeneralOrHigher(player)
		end,
	},
	{
		id = "Freeze_GunSkin",
		name = "Freeze",
		category = "GunSkin",
		gamepassIds = { 1931220905, 1930998900 },
		purchaseGamepassId = 1930998900,
		visible = true,
		isNew = true,
		season = "3",
		customCheck = function(player: Player)
			return isContributor(player) or isGeneralOrHigher(player)
		end,
	},
	{
		id = "Freeze_PlayerCard",
		name = "Freeze Banner",
		category = "PlayerCard",
		gamepassIds = { 1933394265, 1931220905 },
		purchaseGamepassId = 1933394265,
		imageId = "rbxassetid://93932951856854",
		visible = false,
		customCheck = function(player: Player)
			return isDeveloper(player)
		end,
	},
	{
		id = "Invisible_GunSkin",
		name = "Invisible",
		category = "GunSkin",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		isNew = true,
		season = "2",
		customCheck = isDeveloper,
	},
	{
		id = "Guinea_GunSkin",
		name = "Guinea",
		category = "GunSkin",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		isNew = true,
		season = "2",
		customCheck = isDeveloper,
	},
	{
		id = "Jeep_GunSkin",
		name = "Jeep",
		category = "GunSkin",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		isNew = true,
		season = "2",
		customCheck = isDeveloper,
	},
	{
		id = "Fish_GunSkin",
		name = "Fish",
		category = "GunSkin",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = isDeveloper,
	},
	{
		id = "AoD_GunSkin",
		name = "AoD",
		category = "GunSkin",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player)
			return isInGroup(player, 16762182) or isDeveloper(player)
		end,
	},
	{
		id = "GeneralCustom_GunSkin",
		name = "GeneralCustom",
		category = "GunSkin",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player)
			return isGeneralOrHigher(player)
		end,
	},
	{
		id = "S_CORE",
		name = "Subzero",
		category = "GunSkin",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player)
			return isInGroup(player, GROUPS.SUBZERO) or isDeveloper(player)
		end,
	},
	{
		id = "Scooter",
		name = "Scooter",
		category = "GunSkin",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = function(player: Player)
			return isDeveloper(player)
		end,
	},
	{
		id = "RoyalGuard_ChatGradient",
		name = "Royal Guard",
		category = "ChatGradient",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		gradientColors = {
			Color3.fromRGB(83, 37, 37),
			Color3.fromRGB(83, 37, 37),
			Color3.fromRGB(185, 158, 20),
			Color3.fromRGB(185, 158, 20),
			Color3.fromRGB(185, 158, 20),
			Color3.fromRGB(83, 37, 37),
			Color3.fromRGB(83, 37, 37),
		},
		gradientSpeed = 0.35,
		customCheck = function(player: Player)
			return isInGroup(player, GROUPS.ROYAL_GUARD) or isGeneralOrHigher(player)
		end,
	},
	{
		id = "Dreadtrooper_ChatGradient",
		name = "Dreadtrooper",
		category = "ChatGradient",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		gradientColors = {
			Color3.fromRGB(192, 197, 206),
			Color3.fromRGB(192, 197, 206),
			Color3.fromRGB(15, 15, 15),
			Color3.fromRGB(5, 5, 5),
			Color3.fromRGB(15, 15, 15),
			Color3.fromRGB(192, 197, 206),
			Color3.fromRGB(192, 197, 206),
		},
		gradientSpeed = 0.35,
		customCheck = function(player: Player)
			return isInGroup(player, GROUPS.DREADTROOPERS) or isGeneralOrHigher(player)
		end,
	},

	{
		id = "Night_Animated_PlayerCard",
		name = "Night (Animated)",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://96004881347366",
		isAnimated = true,
		visible = false,
		customCheck = isDeveloper,
	},
	{
		id = "Volatil_Animated_PlayerCard",
		name = "Volatil (Animated)",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://122284747350886",
		isAnimated = true,
		visible = false,
		customCheck = isDeveloper,
	},
	{
		id = "5NSO",
		name = "5NSO",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://80116167386558",
		visible = false,
		customCheck = function(player: Player)
			return isInGroup(player, GROUPS.FIVE_NSO) or isGeneralOrHigher(player)
		end,
	},
	{
		id = "Aeternus",
		name = "Aeternus",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://136476104127525",
		visible = false,
		customCheck = function(player: Player)
			return isInGroup(player, GROUPS.AETERNUS) or isDeveloper(player)
		end,
	},
	{
		id = "VAK/VAC",
		name = "VAK",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://96622714408291",
		visible = false,
		customCheck = function(player: Player)
			return isInGroup(player, GROUPS.VAK) or isInGroup(player, GROUPS.VAC) or isDeveloper(player)
		end,
	},
	{
		id = "Dreadtrooper",
		name = "DT",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://98549329141432",
		visible = false,
		customCheck = function(player: Player)
			return isInGroup(player, GROUPS.DREADTROOPERS) or isDeveloper(player)
		end,
	},
	{
		id = "Developer Custom",
		name = "Developer Custom",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://124545420085909",
		visible = false,
		customCheck = function(player: Player)
			return isDeveloper(player)
		end,
	},
	{
		id = "Custom_1",
		name = "Custom",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://0",
		visible = false,
		customCheck = function(player: Player)
			return hasCustomSkins(player)
		end,
	},
	{
		id = "Custom_2",
		name = "Custom 2",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://0",
		visible = false,
		customCheck = function(player: Player)
			return hasCustomSkins(player)
		end,
	},
	{
		id = "Custom_3",
		name = "testing",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://0",
		visible = false,
		customCheck = function(player: Player)
			return hasCustomSkins(player)
		end,
	},
	{
		id = "Custom_4",
		name = "Test_Skin2",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://0",
		visible = false,
		customCheck = function(player: Player)
			return hasCustomSkins(player)
		end,
	},
	{
		id = "Placeholder",
		name = "Placeholder",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://0",
		visible = false,
		customCheck = function(player: Player)
			return hasCustomSkins(player)
		end,
	},
	{
		id = "5NSO_SPRING",
		name = "5NSO Spring Raid Challenge",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://121759285072498",
		visible = false,
		customCheck = function(player: Player)
			return isInGroup(player, GROUPS.FIVE_NSO) or isGeneralOrHigher(player)
		end,
	},
	{
		id = "Frostborne_PlayerCard",
		name = "Frostborne Banner",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://102296324628323",
		visible = false,
		customCheck = function(player: Player)
			return isInGroup(player, 34266706) or isDeveloper(player)
		end,
	},
	{
		id = "SubZero",
		name = "Sub Zero",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://132078576474278",
		visible = false,
		customCheck = function(player: Player)
			return isInGroup(player, GROUPS.SUBZERO) or isGeneralOrHigher(player)
		end,
	},
	{
		id = "SOB",
		name = "SOB",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://99889241384307",
		visible = false,
		customCheck = function(player: Player)
			return isInGroup(player, GROUPS.SOB) or isGeneralOrHigher(player)
		end,
	},
	{
		id = "GAR_SOB",
		name = "GAR SOB",
		category = "PlayerCard",
		gamepassIds = {},
		purchaseGamepassId = 0,
		imageId = "rbxassetid://83186398339532",
		visible = false,
		customCheck = function(player: Player)
			return isInGroup(player, GROUPS.GAR_SOB) or isGeneralOrHigher(player) or isDeveloper(player)
		end,
	},
} :: { ItemConfig }
