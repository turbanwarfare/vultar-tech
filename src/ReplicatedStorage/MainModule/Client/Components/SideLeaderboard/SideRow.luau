--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages   = MainModule:WaitForChild("Packages", 5)
local Fusion     = require(Packages:WaitForChild("Fusion", 5))

local Constants       = require(MainModule.Client.Components.Leaderboard.Constants)
local Utils           = require(MainModule.Client.Components.Leaderboard.Utils)
local PlayerStatsStore = require(MainModule.Client.Components.Leaderboard.PlayerStatsStore)

local Types = require(MainModule.Client.Components.Leaderboard.Types)
type FusionScope         = Types.FusionScope
type FusionUseFn         = Types.FusionUseFn
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type LeaderboardEntry    = Types.LeaderboardEntry

local ROW_HEIGHT      = 26
local ROW_LEFT_INDENT = 10
local AVATAR_SIZE     = 20
local AVATAR_LEFT     = 8
local AVATAR_OFFSET   = AVATAR_LEFT + AVATAR_SIZE + 6

local BLOCK_BG       = Color3.fromRGB(10, 10, 16)
local BLOCK_BG_ALPHA = 0.48
local BLOCK_CORNER   = 5

local STAT_SECTION_START = 0.56
local STAT_SLOT          = (1 - STAT_SECTION_START) / 4
local STAT_KEYS          = { "Kills", "Damage", "Heals", "Captures" }
local STAT_IS_RAW        = { true, false, false, true }
local STAT_WIDTH = 0.105

local PANEL_WIDTH = 420
local ROW_WIDTH   = PANEL_WIDTH - ROW_LEFT_INDENT
local STAT_CENTERS = {
	(( STAT_SECTION_START + STAT_SLOT * 0.5) * PANEL_WIDTH - ROW_LEFT_INDENT) / ROW_WIDTH,
	(( STAT_SECTION_START + STAT_SLOT * 1.5) * PANEL_WIDTH - ROW_LEFT_INDENT) / ROW_WIDTH,
	(( STAT_SECTION_START + STAT_SLOT * 2.5) * PANEL_WIDTH - ROW_LEFT_INDENT) / ROW_WIDTH,
	(( STAT_SECTION_START + STAT_SLOT * 3.5) * PANEL_WIDTH - ROW_LEFT_INDENT) / ROW_WIDTH,
}

local COLOR_LOCAL    = Color3.fromRGB(255, 255, 255)
local COLOR_DEFAULT  = Color3.fromRGB(185, 185, 200)
local COLOR_SPECTATOR = Color3.fromRGB(115, 115, 132)
local formatStat = Utils.formatNumber

local function getTextColor(isLocal: boolean, isSpectator: boolean): Color3
	if isLocal     then return COLOR_LOCAL end
	if isSpectator then return COLOR_SPECTATOR end
	return COLOR_DEFAULT
end

export type SideRowProps = {
	Entry         : LeaderboardEntry,
	IsLocalPlayer : boolean,
	LayoutOrder   : FusionCanBeState<number>?,
	StatsStore    : PlayerStatsStore.PlayerStatsStore?,
}

local function SideRow(scope: FusionScope, props: SideRowProps): Frame
	local entry      = props.Entry
	local isLocal    = props.IsLocalPlayer
	local isSpectator = Utils.isSpectator(entry.Team)

	local textColor  = getTextColor(isLocal, isSpectator)
	local statsStore = props.StatsStore
	local playerStats = statsStore and statsStore:getPlayerStats(entry.UserId) or nil

	local children: { any } = {
		scope:New("UICorner")({ CornerRadius = UDim.new(0, BLOCK_CORNER) }),
	}

	table.insert(children, scope:New("ImageLabel")({
		Name               = "Avatar",
		Position           = UDim2.fromOffset(AVATAR_LEFT, (ROW_HEIGHT - AVATAR_SIZE) / 2),
		Size               = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE),
		BackgroundTransparency = 1,
		Image              = "rbxthumb://type=AvatarHeadShot&id=" .. entry.UserId .. "&w=150&h=150",
		ImageTransparency  = if isSpectator then 0.4 else 0,
		ZIndex             = 2,
	}))

	local usernameFont = if isLocal then Constants.Font.Title else Constants.Font.Bold
	table.insert(children, scope:New("TextLabel")({
		Name               = "Username",
		Position           = UDim2.new(0, AVATAR_OFFSET, 0.5, 0),
		AnchorPoint        = Vector2.new(0, 0.5),
		Size               = UDim2.new(STAT_SECTION_START - 0.01, -AVATAR_OFFSET, 0, 13),
		BackgroundTransparency = 1,
		Text               = entry.Username or entry.DisplayName,
		TextColor3         = textColor,
		TextSize           = 12,
		Font               = usernameFont,
		TextXAlignment     = Enum.TextXAlignment.Left,
		TextYAlignment     = Enum.TextYAlignment.Center,
		TextTruncate       = Enum.TextTruncate.AtEnd,
		ZIndex             = 2,
	}))

	for i, statKey in STAT_KEYS do
		local isRaw   = STAT_IS_RAW[i]
		local statText: any

		if playerStats then
			local statValue = (playerStats :: any)[statKey]
			if statValue then
				statText = scope:Computed(function(use: FusionUseFn)
					return formatStat(use(statValue), isRaw)
				end)
			else
				statText = formatStat((entry.Stats :: any)[statKey] or 0, isRaw)
			end
		else
			statText = formatStat((entry.Stats :: any)[statKey] or 0, isRaw)
		end

		table.insert(children, scope:New("TextLabel")({
			Name               = statKey,
			Position           = UDim2.fromScale(STAT_CENTERS[i], 0.5),
			AnchorPoint        = Vector2.new(0.5, 0.5),
			Size               = UDim2.new(STAT_WIDTH, 0, 0, 12),
			BackgroundTransparency = 1,
			Text               = statText,
			TextColor3         = textColor,
			TextSize           = 11,
			Font               = Constants.Font.Bold,
			TextXAlignment     = Enum.TextXAlignment.Center,
			TextYAlignment     = Enum.TextYAlignment.Center,
			ZIndex             = 2,
		}))
	end

	return scope:New("Frame")({
		Name                  = "SideRow_" .. entry.UserId,
		Size                  = UDim2.new(1, -ROW_LEFT_INDENT, 0, ROW_HEIGHT),
		BackgroundColor3      = BLOCK_BG,
		BackgroundTransparency = BLOCK_BG_ALPHA,
		BorderSizePixel       = 0,
		LayoutOrder           = props.LayoutOrder or 0,
		ZIndex                = 2,
		[Fusion.Children]     = children,
	})
end

return SideRow
