--!strict
--!native
--!optimize 2

local DEV_IDS: { [number]: boolean } = {}

local function isDev(player: Player): boolean
	return DEV_IDS[player.UserId] == true
end

return {
	{ id = "Default_PlayerCard", collection = "Default", gamepassIds = {}, purchaseGamepassId = 0 },

	{
		id = "Regal_PlayerCard",
		collection = "Regal",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		customCheck = isDev,
	},
	{
		id = "PixelGun_PlayerCard",
		collection = "PixelGun",
		gamepassIds = { 2062084566, 2061442665 },
		purchaseGamepassId = 2062084566,
		customCheck = isDev,
	},

	{
		id = "Toxic_PlayerCard",
		collection = "Toxic",
		gamepassIds = { 1777664253, 1763970361 },
		purchaseGamepassId = 1777664253,
		name = "Toxic",
		imageId = "rbxassetid://138636472807093",
	},

	{ id = "HelloKitty_PlayerCard", collection = "HelloKitty", gamepassIds = { 1903128749, 1902972726 }, purchaseGamepassId = 1903128749 },
	{ id = "Vex_PlayerCard", collection = "Vex", gamepassIds = { 1870713038, 1870445094 }, purchaseGamepassId = 1870713038 },
	{ id = "Freeze_PlayerCard", collection = "Freeze", gamepassIds = { 1933394265, 1931220905 }, purchaseGamepassId = 1933394265 },

	{ id = "Ghost_PlayerCard", collection = "Ghost", gamepassIds = { 1550636270, 1550410577, 1550310725 }, purchaseGamepassId = 1550636270, visible = false },
	{
		id = "JackOLantern_PlayerCard",
		collection = "JackOLantern",
		gamepassIds = { 1550540402, 1550262618, 1550084668 },
		purchaseGamepassId = 1550540402,
		visible = false,
	},
	{ id = "Halloween_PlayerCard", collection = "Halloween", gamepassIds = {}, purchaseGamepassId = 0, visible = false },

	{ id = "Beast_PlayerCard", collection = "Beast", gamepassIds = { 1361036464, 1360274538, 1360622501 }, purchaseGamepassId = 1361036464 },
	{ id = "Beamer_PlayerCard", collection = "Beamer", gamepassIds = { 1359198522, 1361162389, 1361198404 }, purchaseGamepassId = 1359198522 },
	{ id = "Byte_PlayerCard", collection = "Byte", gamepassIds = { 1360084480, 1360364507, 1359028546 }, purchaseGamepassId = 1360084480 },
	{ id = "Commando_PlayerCard", collection = "Commando", gamepassIds = { 1360670451, 1359742508, 1359990521 }, purchaseGamepassId = 1360670451 },
	{ id = "Digi_PlayerCard", collection = "Digi", gamepassIds = { 1359326568, 1360568489, 1359374533 }, purchaseGamepassId = 1359326568 },
	{ id = "FarAway_PlayerCard", collection = "FarAway", gamepassIds = { 1358950584, 1361168428, 1359864544 }, purchaseGamepassId = 1358950584 },
	{ id = "Koenig_PlayerCard", collection = "Koenig", gamepassIds = { 1361186436, 1360778436, 1361390421 }, purchaseGamepassId = 1361186436 },
	{ id = "Punished_PlayerCard", collection = "Punished", gamepassIds = { 1360952442, 1359900515, 1361024452 }, purchaseGamepassId = 1360952442 },
	{ id = "Punisher_PlayerCard", collection = "Punisher", gamepassIds = { 1359564578, 1358986594, 1359612586 }, purchaseGamepassId = 1359564578 },
	{ id = "Vette_PlayerCard", collection = "Vette", gamepassIds = { 1359446565, 1361516445, 1360892492 }, purchaseGamepassId = 1359446565 },
	{ id = "Volatil_PlayerCard", collection = "Volatil", gamepassIds = { 1360592486, 1359260577, 1360262530 }, purchaseGamepassId = 1360592486 },
	{ id = "Waves_PlayerCard", collection = "Waves", gamepassIds = { 1358974601, 1359386573, 1359936534 }, purchaseGamepassId = 1358974601 },
	{ id = "Arc_PlayerCard", collection = "Arc", gamepassIds = { 1367788971, 1365959080, 1367290989 }, purchaseGamepassId = 1367788971 },

	{ id = "Cloud_PlayerCard", collection = "Cloud", gamepassIds = { 1235879483, 1237573861, 1236009220 }, purchaseGamepassId = 1235879483 },
	{ id = "Cloud_Animated_PlayerCard", collection = "Cloud_Animated", gamepassIds = { 1663742264 }, purchaseGamepassId = 0, visible = true },
	{ id = "Apocolypse_PlayerCard", collection = "Apocolypse", gamepassIds = { 1235813570, 1236236632, 1236540304 }, purchaseGamepassId = 1235813570 },
	{ id = "Lit_PlayerCard", collection = "Lit", gamepassIds = { 1235921441, 1235779763, 1236478410 }, purchaseGamepassId = 1235921441 },
	{ id = "Dead_PlayerCard", collection = "Dead", gamepassIds = { 1240036356, 1235887458, 1236029291 }, purchaseGamepassId = 1240036356 },
	{ id = "Space_PlayerCard", collection = "Space", gamepassIds = { 1238504393, 1236922347, 1238846277 }, purchaseGamepassId = 1238504393 },
	{ id = "ISeeYou_PlayerCard", collection = "ISeeYou", gamepassIds = { 1235909491, 1237008139, 1237690018 }, purchaseGamepassId = 1235909491 },
	{ id = "GT3RS_PlayerCard", collection = "GT3RS", gamepassIds = { 1239838537, 1236077132, 1235869437 }, purchaseGamepassId = 1239838537 },
	{ id = "Duty_PlayerCard", collection = "Duty", gamepassIds = { 1235811744, 1236192933, 1236380555 }, purchaseGamepassId = 1235811744 },
	{ id = "Meow_PlayerCard", collection = "Meow", gamepassIds = { 1237362014, 1236630487, 1236095052 }, purchaseGamepassId = 1237362014 },
	{ id = "Berserk_PlayerCard", collection = "Berserk", gamepassIds = { 1236660259, 1238918187, 1239748541 }, purchaseGamepassId = 1236660259 },
	{ id = "BeautifulDeath_PlayerCard", collection = "BeautifulDeath", gamepassIds = { 1239032133, 1236732340, 1236103064 }, purchaseGamepassId = 1239032133 },
	{ id = "Night_PlayerCard", collection = "Night", gamepassIds = { 1235779773, 1235891575, 1236922343 }, purchaseGamepassId = 1235779773 },
	{ id = "Vultar_PlayerCard", collection = "Vultar", gamepassIds = { 1236660263, 1239632641, 1236043264 }, purchaseGamepassId = 1236660263 },
}
