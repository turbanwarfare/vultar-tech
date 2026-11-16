--!nonstrict
--!native
--!optimize 2

local CUSTOM_GRADIENT_USER_ID = 0

local DEV_IDS: { [number]: boolean } = {}

return {
	{
		id = "Regal_ChatGradient",
		name = "Regal",
		category = "ChatGradient",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		gradientColors = {
			Color3.fromRGB(120, 80, 10),
			Color3.fromRGB(212, 160, 40),
			Color3.fromRGB(255, 215, 90),
			Color3.fromRGB(255, 243, 170),
			Color3.fromRGB(255, 215, 90),
			Color3.fromRGB(212, 160, 40),
			Color3.fromRGB(120, 80, 10),
		},
		gradientSpeed = 0.4,
		customCheck = function(player: Player)
			return DEV_IDS[player.UserId] == true
		end,
	},

	{
		id = "Developer_ChatGradient",
		name = "Developer Gradient",
		category = "ChatGradient",
		gamepassIds = {},
		purchaseGamepassId = 0,
		visible = false,
		gradientColors = {
			Color3.fromRGB(90, 40, 120),
			Color3.fromRGB(180, 50, 110),
			Color3.fromRGB(240, 100, 80),
			Color3.fromRGB(255, 180, 60),
			Color3.fromRGB(240, 100, 80),
			Color3.fromRGB(180, 50, 110),
			Color3.fromRGB(90, 40, 120),
		},
		gradientSpeed = 0.35,
		customCheck = function(player: Player)
			return player.UserId < 0
		end,
	},

	{
		id = "Inferno_ChatGradient",
		name = "Inferno",
		category = "ChatGradient",
		gamepassIds = { 1663742264 },
		purchaseGamepassId = 0,
		visible = false,
		gradientColors = {
			Color3.fromRGB(255, 60, 20),
			Color3.fromRGB(255, 140, 40),
			Color3.fromRGB(255, 200, 80),
			Color3.fromRGB(255, 140, 40),
			Color3.fromRGB(255, 60, 20),
			Color3.fromRGB(180, 30, 10),
			Color3.fromRGB(255, 60, 20),
		},
		gradientSpeed = 0.4,
	},

	{
		id = "Blizzard_ChatGradient",
		name = "Blizzard",
		category = "ChatGradient",
		gamepassIds = { 1661788677 },
		purchaseGamepassId = 0,
		visible = false,
		gradientColors = {
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(200, 230, 255),
			Color3.fromRGB(140, 200, 255),
			Color3.fromRGB(100, 180, 240),
			Color3.fromRGB(140, 200, 255),
			Color3.fromRGB(200, 230, 255),
			Color3.fromRGB(255, 255, 255),
		},
		gradientSpeed = 0.3,
		customCheck = function(player: Player)
			return player.UserId == CUSTOM_GRADIENT_USER_ID or player.UserId < 0
		end,
	},

	{
		id = "Freeze_ChatGradient",
		name = "Freeze",
		category = "ChatGradient",
		gamepassIds = { 1931220905 },
		purchaseGamepassId = 0,
		visible = false,
		gradientColors = {
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(200, 230, 255),
			Color3.fromRGB(140, 200, 255),
			Color3.fromRGB(100, 180, 240),
			Color3.fromRGB(140, 200, 255),
			Color3.fromRGB(200, 230, 255),
			Color3.fromRGB(255, 255, 255),
		},
		gradientSpeed = 0.3,
		customCheck = function(player: Player)
			return DEV_IDS[player.UserId] == true
		end,
	},

	{
		id = "Toxic_ChatGradient",
		name = "Toxic",
		category = "ChatGradient",
		gamepassIds = { 1763970361 },
		purchaseGamepassId = 0,
		visible = false,
		gradientColors = {
			Color3.fromRGB(140, 255, 170),
			Color3.fromRGB(0, 180, 70),
			Color3.fromRGB(0, 40, 15),
			Color3.fromRGB(100, 240, 130),
			Color3.fromRGB(0, 40, 15),
			Color3.fromRGB(0, 180, 70),
			Color3.fromRGB(140, 255, 170),
		},
		gradientSpeed = 0.35,
	},
	{
		id = "Vex_ChatGradient",
		name = "Vex",
		category = "ChatGradient",
		gamepassIds = { 1870445094 },
		purchaseGamepassId = 0,
		visible = false,
		gradientColors = {
			Color3.fromRGB(255, 130, 130),
			Color3.fromRGB(225, 35, 35),
			Color3.fromRGB(70, 0, 8),
			Color3.fromRGB(255, 80, 80),
			Color3.fromRGB(70, 0, 8),
			Color3.fromRGB(225, 35, 35),
			Color3.fromRGB(255, 130, 130),
		},
		gradientSpeed = 0.35,
	},

	{
		id = "HelloKitty_ChatGradient",
		name = "Hello Kitty",
		category = "ChatGradient",
		gamepassIds = { 1902972726 },
		purchaseGamepassId = 0,
		visible = false,
		gradientColors = {
			Color3.fromRGB(180, 12, 152),
			Color3.fromRGB(54, 8, 47),
			Color3.fromRGB(180, 12, 152),
		},
		gradientSpeed = 0.35,
	},
}
