--!strict

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Theme = require(MainModule.Shared.UI.Theme)

local Constants = {}

Constants.TABS = { "Settings", "Shop", "Inventory", "Avatar", "Keybinds", "Rules" }

Constants.SIDEBAR_WIDTH = Theme.Settings.Sidebar.Width
Constants.RIGHT_SIDEBAR_WIDTH_BOTTOM = 160
Constants.RIGHT_SIDEBAR_WIDTH_RIGHT = 480
Constants.SIDEBAR_GAP = 16

Constants.SMOOTH_DAMPING = 2.5
Constants.SPRING_SPEED = 40

Constants.MIN_PREVIEW_RIGHT_VIEWPORT_WIDTH = 1560

Constants.BUTTON_COLORS = {
	Reset = {
		Background = Color3.fromRGB(100, 40, 40),
		BackgroundHover = Color3.fromRGB(140, 50, 50),
		Stroke = Color3.fromRGB(130, 55, 55),
		StrokeHover = Color3.fromRGB(180, 80, 80),
	},
	Share = {
		Background = Color3.fromRGB(45, 80, 130),
		BackgroundHover = Color3.fromRGB(55, 100, 160),
		Stroke = Color3.fromRGB(70, 110, 160),
		StrokeHover = Color3.fromRGB(90, 140, 200),
	},
}

return Constants
