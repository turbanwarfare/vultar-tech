--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)
local Maps = require(MainModule.Shared.Config.Maps)

local Constants = require(script.Parent.Parent.Constants)
local PlayerRow = require(script.Parent.PlayerRow)
local PlayerStatsStore = require(script.Parent.Parent.PlayerStatsStore)

local Types = require(script.Parent.Parent.Types)
type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FactionData = Types.FactionData
type LeaderboardEntry = Types.LeaderboardEntry

export type PlayerListProps = {
	Data: FusionCanBeState<FactionData>,
	LocalUserId: number,
	StatsStore: PlayerStatsStore.PlayerStatsStore?,
	OnRowClick: ((userId: number, cardImageId: string?, isAnimatedCard: boolean) -> ())?,
}

type RowState = {
	entry: LeaderboardEntry,
	orderValue: Types.FusionValue<number>,
	showSeparator: boolean,
}

local function buildRowKey(entry: LeaderboardEntry): string
	return tostring(entry.UserId) .. "|" .. (entry.CardImageId or "") .. "|" .. tostring(entry.IsAnimatedCard == true) .. "|" .. (entry.Team or "")
end

local function buildRowDataMap(scope: FusionScope, entries: { LeaderboardEntry }, rowCache: { [string]: RowState }): { [string]: RowState }
	local result: { [string]: RowState } = {}

	local lastDefendersTeam: string? = nil

	for i, entry in entries do
		local isDefenders = entry.Team ~= nil and Maps.getTeamFaction(entry.Team) == "Defenders"

		local showSep = false
		if isDefenders and lastDefendersTeam and entry.Team ~= lastDefendersTeam then
			showSep = true
		end
		
		if isDefenders then
			lastDefendersTeam = entry.Team
		end

		local key = buildRowKey(entry)

		local cached = rowCache[key]
		if cached and cached.showSeparator == showSep then
			cached.orderValue:set(i)
			cached.entry = entry
			result[key] = cached
		else
			local newState: RowState = { entry = entry, orderValue = scope:Value(i), showSeparator = showSep }
			rowCache[key] = newState
			result[key] = newState
		end
	end

	for key in rowCache do
		if not result[key] then
			rowCache[key] = nil
		end
	end

	return result
end

local function PlayerList(scope: FusionScope, props: PlayerListProps): Frame
	local data = scope:Computed(function(use: FusionUseFn)
		return use(props.Data)
	end)

	local localUserId = props.LocalUserId
	local statsStore = props.StatsStore
	local onRowClick = props.OnRowClick

	local rowCache: { [string]: RowState } = {}

	local rowDataMap = scope:Computed(function(use: FusionUseFn)
		return buildRowDataMap(scope, use(data).entries, rowCache)
	end)

	return scope:New("Frame")({
		Name = "PlayerListContainer",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Constants.Colors.PanelBackground,
		BackgroundTransparency = Constants.LIST_BG_TRANSPARENCY,
		BorderSizePixel = 0,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, Constants.CORNER_RADIUS) }),
			scope:New("UIStroke")({
				Color = Theme.Border.Default,
				Thickness = Constants.BORDER_THICKNESS,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),

			scope:New("ScrollingFrame")({
				Name = "PlayerList",
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = Constants.SCROLL_BAR_THICKNESS,
				ScrollBarImageColor3 = Constants.Colors.ScrollBar,
				ScrollBarImageTransparency = Constants.SCROLL_BAR_TRANSPARENCY,
				CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ClipsDescendants = true,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 0),
					}),

					scope:ForPairs(rowDataMap, function(_use: FusionUseFn, itemScope: FusionScope, key: string, rowData: RowState)
						local entry = rowData.entry
						local isLocal = entry.UserId == localUserId
						local entryUserId = entry.UserId
						local entryCardImageId = entry.CardImageId
						local entryIsAnimatedCard = entry.IsAnimatedCard == true

						return key,
							PlayerRow(itemScope, {
								Entry = entry,
								IsLocalPlayer = isLocal,
								LayoutOrder = rowData.orderValue,
								ShowSeparator = rowData.showSeparator,
								StatsStore = statsStore,
								IsFirstRow = Fusion.peek(rowData.orderValue) == 1,
								OnClick = if onRowClick
									then function()
										onRowClick(entryUserId, entryCardImageId, entryIsAnimatedCard)
									end
									else nil,
							})
					end),
				},
			}),
		},
	})
end

return PlayerList
