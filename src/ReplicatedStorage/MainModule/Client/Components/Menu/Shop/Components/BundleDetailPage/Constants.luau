--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local Theme = require(MainModule.Shared.UI.Theme)

local Constants = {}

Constants.CONTENT_WIDTH = 880
Constants.LIST_WIDTH = 300
Constants.LIST_HEADER_HEIGHT = 24
Constants.ITEM_HEIGHT = 48
Constants.ITEM_GAP = 3
Constants.LIST_PADDING = 4
Constants.DIVIDER_HEIGHT = 20
Constants.PURCHASE_BUTTON_HEIGHT = 52
Constants.HEADER_HEIGHT = 32

Constants.KILL_CARD_HEIGHT = 100
Constants.KILL_CARD_AVATAR_SIZE = Constants.KILL_CARD_HEIGHT
Constants.KILL_CARD_BG = Color3.fromRGB(18, 18, 18)
Constants.KILL_CARD_BORDER = Color3.fromRGB(200, 200, 210)
Constants.BANNER_TRANSPARENCY = 0.35

Constants.LB_ROW_HEIGHT = 34
Constants.LB_USERNAME_END = 0.38
Constants.LB_STAT_WIDTH = 0.155
Constants.LB_STAT_START = Constants.LB_USERNAME_END
Constants.LB_CORNER_RADIUS = 6
Constants.LB_LOCAL_COLOR = Color3.fromRGB(219, 182, 87)

Constants.ACCENT_COLOR = Color3.fromRGB(65, 145, 255)
Constants.GUN_SKIN_ACCENT = Color3.fromRGB(220, 75, 75)
Constants.CHAT_GRADIENT_ACCENT = Color3.fromRGB(255, 140, 60)

Constants.SHADOW_SPREAD = 6
Constants.SHADOW_OFFSET_Y = 2
Constants.SHADOW_TRANSPARENCY = 0.65

Constants.DEFAULT_NAME_COLOR = Theme.Chat.Name.Default

Constants.GRADIENT_SPEED = 0.35

return Constants
