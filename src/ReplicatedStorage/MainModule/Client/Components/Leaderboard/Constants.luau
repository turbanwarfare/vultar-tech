--!native
--!optimize 2

local Constants = {}

local DEFAULT_LAYOUT = {
	CONTAINER_WIDTH = 1060,
	CONTAINER_HEIGHT = 700,
	ROW_HEIGHT = 38,
	HEADER_HEIGHT = 76,
	PANEL_GAP = 6,
	HEADER_GAP = 6,

	HEADER_TITLE_SIZE = 18,
	HEADER_LABEL_SIZE = 15,
	HEADER_VALUE_SIZE = 16,
	ROW_USERNAME_MAX_SIZE = 16,
	ROW_USERNAME_MIN_SIZE = 10,
	ROW_STAT_SIZE = 16,
	SUBTEAM_SIZE = 15,

	DEFENDER_ICON_PADDING = 6,
	DEFENDER_ICON_TEXT_GAP = 4,
	RAIDER_ICON_PADDING = 12,
	RAIDER_ICON_TEXT_GAP = 8,
	HEADER_ICON_Y = 8,
	HEADER_TITLE_HEIGHT = 22,

	HEADER_STATS_Y = 40,
	HEADER_STATS_HEIGHT = 34,
	HEADER_SUBTEAMS_Y = 30,
	HEADER_SUBTEAM_HEIGHT = 14,

	DEFENDER_ICON_WIDTH = 60,
	DEFENDER_ICON_HEIGHT = 52,
	RAIDER_ICON_WIDTH = 42,
	RAIDER_ICON_HEIGHT = 52,

	ROW_USERNAME_OFFSET = 6,
	ROW_USERNAME_HEIGHT = 18,
	ROW_STAT_HEIGHT = 18,
}

local SMALL_LAYOUT = {
	CONTAINER_WIDTH = 940,
	CONTAINER_HEIGHT = 640,
	ROW_HEIGHT = 30,
	HEADER_HEIGHT = 58,
	PANEL_GAP = 4,
	HEADER_GAP = 3,

	HEADER_TITLE_SIZE = 18,
	HEADER_LABEL_SIZE = 14,
	HEADER_VALUE_SIZE = 16,
	ROW_USERNAME_MAX_SIZE = 16,
	ROW_USERNAME_MIN_SIZE = 10,
	ROW_STAT_SIZE = 15,
	SUBTEAM_SIZE = 15,

	DEFENDER_ICON_PADDING = 4,
	DEFENDER_ICON_TEXT_GAP = 3,
	RAIDER_ICON_PADDING = 8,
	RAIDER_ICON_TEXT_GAP = 6,
	HEADER_ICON_Y = 6,
	HEADER_TITLE_HEIGHT = 22,

	HEADER_STATS_Y = 28,
	HEADER_STATS_HEIGHT = 28,
	HEADER_SUBTEAMS_Y = 26,
	HEADER_SUBTEAM_HEIGHT = 14,

	DEFENDER_ICON_WIDTH = 46,
	DEFENDER_ICON_HEIGHT = 40,
	RAIDER_ICON_WIDTH = 32,
	RAIDER_ICON_HEIGHT = 40,

	ROW_USERNAME_OFFSET = 4,
	ROW_USERNAME_HEIGHT = 17,
	ROW_STAT_HEIGHT = 16,
}

local LAYOUTS = {
	DEFAULT_LAYOUT,
	SMALL_LAYOUT,
}

local function applyLayout(layout: { [string]: number }): ()
	for key, value in layout do
		(Constants :: any)[key] = value
	end
end

function Constants.applySize(mode: number): ()
	local layout = LAYOUTS[mode] or DEFAULT_LAYOUT
	applyLayout(layout)

	Constants.USERNAME_END = 0.38
	Constants.STAT_WIDTH = 0.155
	Constants.STAT_START = Constants.USERNAME_END

	Constants.STAT_COLUMNS = {
		{ key = "Kills", label = "KILLS", pos = Constants.STAT_START },
		{ key = "Damage", label = "DMG", pos = Constants.STAT_START + Constants.STAT_WIDTH },
		{ key = "Heals", label = "HEALS", pos = Constants.STAT_START + Constants.STAT_WIDTH * 2 },
		{ key = "Captures", label = "CAPS", pos = Constants.STAT_START + Constants.STAT_WIDTH * 3 },
	}
end

Constants.applySize(1)

Constants.HEADER_BG_TRANSPARENCY = 0.30
Constants.LIST_BG_TRANSPARENCY = 0.50
Constants.SPECTATOR_TEXT_TRANSPARENCY = 0.3

Constants.Colors = {
	PanelBackground = Color3.fromRGB(22, 22, 22),
	LocalPlayer = Color3.fromRGB(219, 182, 87),
	SpectatorText = Color3.fromRGB(140, 140, 140),
	Vultarians = Color3.fromRGB(180, 60, 60),
	Initiates = Color3.fromRGB(140, 140, 140),
	Hostiles = Color3.fromRGB(80, 140, 220),
	HeaderLabel = Color3.fromRGB(140, 140, 140),
	ScrollBar = Color3.fromRGB(80, 80, 80),
	DefaultText = Color3.fromRGB(255, 255, 255),
}

Constants.Teams = {
	Spectators = "Spectators",
	DefenderTitle = "IMPERIUM OF VULTAR",
	RaiderTitle = "HOSTILE FORCES",
}

Constants.Font = {
	Title = Enum.Font.BuilderSansExtraBold,
	Bold = Enum.Font.BuilderSansBold,
	Label = Enum.Font.BuilderSansMedium,
}

Constants.SCROLL_BAR_THICKNESS = 4
Constants.SCROLL_BAR_TRANSPARENCY = 0.3
Constants.CORNER_RADIUS = 6
Constants.BORDER_THICKNESS = 1
Constants.SEPARATOR_THICKNESS = 2

return Constants
