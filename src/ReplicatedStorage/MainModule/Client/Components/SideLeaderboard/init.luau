--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))

local TweenService = game:GetService("TweenService")

local Constants = require(MainModule.Client.Components.Leaderboard.Constants)
local LeaderboardUtils = require(MainModule.Client.Components.Leaderboard.Utils)
local PlayerStatsStore = require(MainModule.Client.Components.Leaderboard.PlayerStatsStore)
local Maps = require(MainModule.Shared.Config.Maps)
local SideRow = require(script.SideRow)

local Types = require(MainModule.Client.Components.Leaderboard.Types)
type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FactionData = Types.FactionData
type LeaderboardEntry = Types.LeaderboardEntry

local PANEL_WIDTH = 420
local COLUMN_HEADER_HEIGHT = 22
local INFO_TAB_HEIGHT = 28
local CARD_GAP = 3
local BLOCK_CORNER = 5
local PANEL_TOP_OFFSET = 102
local MAX_PANEL_HEIGHT = 450

local BLOCK_BG = Color3.fromRGB(10, 10, 16)
local BLOCK_BG_ALPHA = 0.48
local INFO_TAB_ALPHA = 0.30

local WHITE = Color3.fromRGB(255, 255, 255)
local INFO_TAB_TOTAL_COLOR = Color3.fromRGB(235, 235, 250)

local STAT_SECTION_START = 0.56
local STAT_SLOT = (1 - STAT_SECTION_START) / 4
local STAT_KEYS = { "Kills", "Damage", "Heals", "Captures" }
local STAT_IS_RAW = { true, false, false, true }
local STAT_COL_LABELS = { "KILLS", "DMG", "HEALS", "CAPS" }
local STAT_CENTERS = {
	STAT_SECTION_START + STAT_SLOT * 0.5,
	STAT_SECTION_START + STAT_SLOT * 1.5,
	STAT_SECTION_START + STAT_SLOT * 2.5,
	STAT_SECTION_START + STAT_SLOT * 3.5,
}
local STAT_WIDTH = 0.105

local OPEN_POSITION = UDim2.new(1, -6, 0, PANEL_TOP_OFFSET)
local CLOSED_POSITION = UDim2.new(1, PANEL_WIDTH + 20, 0, PANEL_TOP_OFFSET)

local SLIDE_TWEEN_IN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SLIDE_TWEEN_OUT = TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DISABLE_DELAY = 0.40

export type SideLeaderboardProps = {
	DefendersData: FusionCanBeState<FactionData>,
	RaidersData: FusionCanBeState<FactionData>,
	LocalUserId: number,
	LocalUsername: string,
	StatsStore: PlayerStatsStore.PlayerStatsStore?,
	Visible: FusionCanBeState<boolean>?,
}

type RowState = {
	entry: LeaderboardEntry,
	orderValue: any,
}

local formatStat = LeaderboardUtils.formatNumber

local function buildRowMap(scope: FusionScope, entries: { LeaderboardEntry }, rowCache: { [string]: RowState }): { [string]: RowState }
	local result: { [string]: RowState } = {}
	for i, entry in entries do
		local key = tostring(entry.UserId)
		local cached = rowCache[key]
		if cached then
			cached.orderValue:set(i)
			cached.entry = entry
			result[key] = cached
		else
			local state: RowState = { entry = entry, orderValue = scope:Value(i) }
			rowCache[key] = state
			result[key] = state
		end
	end
	for key in rowCache do
		if not result[key] then
			rowCache[key] = nil
		end
	end
	return result
end

local function buildColumnHeader(scope: FusionScope, localUsername: string): Frame
	local children: { any } = {
		scope:New("UICorner")({ CornerRadius = UDim.new(0, BLOCK_CORNER) }),
		scope:New("TextLabel")({
			Name = "UsernameLbl",
			Position = UDim2.new(0, 10, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.new(STAT_SECTION_START - 0.03, -10, 0, 12),
			BackgroundTransparency = 1,
			Text = localUsername,
			TextColor3 = WHITE,
			TextSize = 12,
			Font = Constants.Font.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 2,
		}),
	}
	for i, label in STAT_COL_LABELS do
		table.insert(
			children,
			scope:New("TextLabel")({
				Name = label .. "Lbl",
				Position = UDim2.fromScale(STAT_CENTERS[i], 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(STAT_WIDTH, 0, 0, 11),
				BackgroundTransparency = 1,
				Text = label,
				TextColor3 = WHITE,
				TextSize = 10,
				Font = Constants.Font.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 2,
			})
		)
	end
	return scope:New("Frame")({
		Name = "ColumnHeader",
		Size = UDim2.new(1, 0, 0, COLUMN_HEADER_HEIGHT),
		BackgroundColor3 = BLOCK_BG,
		BackgroundTransparency = BLOCK_BG_ALPHA,
		BorderSizePixel = 0,
		ZIndex = 3,
		[Fusion.Children] = children,
	})
end

local function buildInfoTab(scope: FusionScope, teamColor: Color3, sectionLabel: string, entriesState: FusionCanBeState<{ LeaderboardEntry }>): Frame
	local children: { any } = {
		scope:New("UICorner")({ CornerRadius = UDim.new(0, BLOCK_CORNER) }),
		scope:New("TextLabel")({
			Name = "Label",
			Position = UDim2.new(0, 10, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.new(STAT_SECTION_START - 0.04, -10, 0, 14),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use: FusionUseFn)
				return sectionLabel .. " (" .. tostring(#use(entriesState)) .. ")"
			end),
			TextColor3 = WHITE,
			TextSize = 13,
			Font = Constants.Font.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,
		}),
	}
	for i, statKey in STAT_KEYS do
		local isRaw = STAT_IS_RAW[i]
		table.insert(
			children,
			scope:New("TextLabel")({
				Name = statKey .. "Total",
				Position = UDim2.fromScale(STAT_CENTERS[i], 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(STAT_WIDTH, 0, 0, 12),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use: FusionUseFn)
					local total = 0
					for _, entry in use(entriesState) do
						total += (entry.Stats :: any)[statKey] or 0
					end
					return formatStat(total, isRaw)
				end),
				TextColor3 = INFO_TAB_TOTAL_COLOR,
				TextSize = 11,
				Font = Constants.Font.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 2,
			})
		)
	end
	return scope:New("Frame")({
		Name = "InfoTab",
		Size = UDim2.new(1, 0, 0, INFO_TAB_HEIGHT),
		BackgroundColor3 = teamColor,
		BackgroundTransparency = INFO_TAB_ALPHA,
		BorderSizePixel = 0,
		LayoutOrder = 0,
		ZIndex = 2,
		[Fusion.Children] = children,
	})
end

local function buildSection(
	scope: FusionScope,
	entriesState: FusionCanBeState<{ LeaderboardEntry }>,
	teamColor: Color3,
	sectionLabel: string,
	layoutOrder: number,
	localUserId: number,
	statsStore: PlayerStatsStore.PlayerStatsStore?
): Frame
	local rowCache: { [string]: RowState } = {}

	local rowDataMap = scope:Computed(function(use: FusionUseFn)
		return buildRowMap(scope, use(entriesState), rowCache)
	end)

	local sectionVisible = scope:Computed(function(use: FusionUseFn)
		return #use(entriesState) > 0
	end)

	return scope:New("Frame")({
		Name = sectionLabel,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Visible = sectionVisible,
		ZIndex = 1,
		[Fusion.Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, CARD_GAP),
			}),
			buildInfoTab(scope, teamColor, sectionLabel, entriesState),
			scope:ForPairs(rowDataMap, function(_use: FusionUseFn, itemScope: FusionScope, key: string, rowData: RowState)
				return key,
					SideRow(itemScope, {
						Entry = rowData.entry,
						IsLocalPlayer = rowData.entry.UserId == localUserId,
						LayoutOrder = rowData.orderValue,
						StatsStore = statsStore,
					})
			end),
		},
	})
end

local function SideLeaderboard(scope: FusionScope, props: SideLeaderboardProps): ScreenGui
	local localUserId = props.LocalUserId
	local localUsername = props.LocalUsername
	local statsStore = props.StatsStore
	local visibleProp = props.Visible

	local isSpar = Maps.isSparMode() or Maps.isAimMode()
	local sections: { Frame } = {}

	if isSpar then
		local entriesState = scope:Computed(function(use: FusionUseFn)
			local defenders = use(props.DefendersData).entries
			local raiders = use(props.RaidersData).entries
			local result: { LeaderboardEntry } = {}
			for _, entry in defenders do
				table.insert(result, entry)
			end
			for _, entry in raiders do
				table.insert(result, entry)
			end
			table.sort(result, function(a, b)
				return a.Stats.Kills > b.Stats.Kills
			end)
			return result
		end)

		table.insert(sections, buildSection(scope, entriesState, Color3.fromRGB(60, 60, 70), "PLAYERS", 1, localUserId, statsStore))
	else
		for index, teamConfig in Maps.getTeams() do
			local teamName = teamConfig.Name
			local faction = teamConfig.Faction
			local entriesState = scope:Computed(function(use: FusionUseFn)
				local sourceData = if faction == "Defenders" then use(props.DefendersData) else use(props.RaidersData)
				local result: { LeaderboardEntry } = {}
				for _, entry in sourceData.entries do
					if entry.Team == teamName then
						table.insert(result, entry)
					end
				end
				return result
			end)

			table.insert(
				sections,
				buildSection(
					scope,
					entriesState,
					teamConfig.Color.Color,
					string.upper(teamConfig.DisplayName or teamConfig.Name),
					teamConfig.Order or index,
					localUserId,
					statsStore
				)
			)
		end
	end

	local initialOpen = if visibleProp ~= nil then Fusion.peek(visibleProp) else false
	local guiEnabled = scope:Value(initialOpen)
	local disableTask: thread? = nil

	local sidePanel = scope:New("Frame")({
		Name = "SidePanel",
		AnchorPoint = Vector2.new(1, 0),
		Position = if initialOpen then OPEN_POSITION else CLOSED_POSITION,
		Size = UDim2.fromOffset(PANEL_WIDTH, MAX_PANEL_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		[Fusion.Children] = {
			buildColumnHeader(scope, localUsername),
			scope:New("ScrollingFrame")({
				Name = "SideScroll",
				Position = UDim2.fromOffset(0, COLUMN_HEADER_HEIGHT),
				Size = UDim2.new(1, 0, 1, -COLUMN_HEADER_HEIGHT),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 2,
				ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120),
				ScrollBarImageTransparency = 0.45,
				CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ClipsDescendants = true,
				[Fusion.Children] = {
					scope:New("UIPadding")({ PaddingTop = UDim.new(0, CARD_GAP) }),
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, CARD_GAP),
					}),
					sections,
				},
			}),
		},
	}) :: Frame

	local slideTween: Tween? = nil

	if visibleProp ~= nil then
		scope:Observer(visibleProp):onBind(function()
			local open = Fusion.peek(visibleProp :: FusionCanBeState<boolean>)
			if open then
				if disableTask then
					task.cancel(disableTask)
					disableTask = nil
				end
				guiEnabled:set(true)
			else
				disableTask = task.delay(DISABLE_DELAY, function()
					disableTask = nil
					if not Fusion.peek(visibleProp :: FusionCanBeState<boolean>) then
						guiEnabled:set(false)
					end
				end)
			end
			if slideTween then
				slideTween:Cancel()
			end
			slideTween =
				TweenService:Create(sidePanel, if open then SLIDE_TWEEN_IN else SLIDE_TWEEN_OUT, { Position = if open then OPEN_POSITION else CLOSED_POSITION })
			slideTween:Play()
		end)
	end

	table.insert(scope, function()
		if disableTask then
			task.cancel(disableTask)
		end
		if slideTween then
			slideTween:Cancel()
		end
	end)

	return scope:New("ScreenGui")({
		Name = "SideLeaderboard",
		AutoLocalize = false,
		DisplayOrder = 150,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		Enabled = guiEnabled,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		[Fusion.Children] = {
			sidePanel,
		},
	})
end

return SideLeaderboard
