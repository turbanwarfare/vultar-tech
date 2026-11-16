--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)
local SearchEngine = require(script.Parent.SearchEngine)
local CursorHistoryGrid = require(script.Parent.CursorHistoryGrid)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

local peek: <T>(state: FusionCanBeState<T>) -> T = Fusion.peek

export type CursorHistoryGridRowProps = {
	Label: string,
	Description: string?,
	History: FusionCanBeState<{ number }>,
	RadialCursors: FusionCanBeState<{ number }>,
	OnEquip: ((cursorId: number) -> ())?,
	OnToggleRadial: ((cursorId: number) -> ())?,
	LayoutOrder: number?,
	SearchFilter: FusionCanBeState<string>?,
	SettingKey: string?,
}

local HEADER_HEIGHT = 30
local GRID_PADDING = 8
local HINT_HEIGHT = 18
local CELL_SIZE = 40
local CELL_SPACING = 6
local COLUMNS = 12
local MAX_COLLAPSED_ROWS = 3

local function CursorHistoryGridRow(scope: FusionScope, props: CursorHistoryGridRowProps): Frame
	local isHovered = scope:Value(false)
	local isManuallyExpanded = scope:Value(false)
	local hasBeenToggled = scope:Value(false)

	local historyCount = scope:Computed(function(use: FusionUseFn)
		local history = use(props.History)
		if type(history) ~= "table" then
			return 0
		end
		return #history
	end)

	local gridRowCount = scope:Computed(function(use: FusionUseFn)
		local count = use(historyCount)
		return math.max(1, math.ceil(count / COLUMNS))
	end)

	local shouldAutoCollapse = scope:Computed(function(use: FusionUseFn)
		return use(gridRowCount) > MAX_COLLAPSED_ROWS
	end)

	local isExpanded = scope:Computed(function(use: FusionUseFn)
		local toggled = use(hasBeenToggled)
		if toggled then
			return use(isManuallyExpanded)
		end
		return not use(shouldAutoCollapse)
	end)

	local displayedRowCount = scope:Computed(function(use: FusionUseFn)
		local totalRows = use(gridRowCount)
		local expanded = use(isExpanded)
		if expanded then
			return totalRows
		end
		return math.min(totalRows, MAX_COLLAPSED_ROWS)
	end)

	local displayedGridHeight = scope:Computed(function(use: FusionUseFn)
		local rows = use(displayedRowCount)
		return (CELL_SIZE * rows) + (CELL_SPACING * math.max(0, rows - 1))
	end)

	local canExpand = scope:Computed(function(use: FusionUseFn)
		return use(gridRowCount) > MAX_COLLAPSED_ROWS
	end)

	local expandButtonHeight = scope:Computed(function(use: FusionUseFn)
		return if use(canExpand) then 24 else 0
	end)

	local totalHeight = scope:Computed(function(use: FusionUseFn)
		local count = use(historyCount)
		if count == 0 then
			return HEADER_HEIGHT + GRID_PADDING + CELL_SIZE + 8
		end
		return HEADER_HEIGHT + GRID_PADDING + use(displayedGridHeight) + HINT_HEIGHT + use(expandButtonHeight) + 12
	end)

	local searchScore = scope:Computed(function(use: FusionUseFn)
		if not props.SearchFilter then return 1000 end
		local query = use(props.SearchFilter)
		if query == "" then return 1000 end
		return SearchEngine.score(query, props.Label, props.Description or "", props.SettingKey)
	end)

	local isVisible = scope:Computed(function(use: FusionUseFn)
		return use(searchScore) > 0
	end)

	local dynamicLayoutOrder = scope:Computed(function(use: FusionUseFn)
		if not props.SearchFilter then return props.LayoutOrder or 0 end
		local query = use(props.SearchFilter)
		if query == "" then return props.LayoutOrder or 0 end
		local score = use(searchScore)
		return 10000 - score
	end)

	local borderColor = scope:Computed(function(use: FusionUseFn)
		return if use(isHovered) then Theme.Border.Active else Theme.Row.Border
	end)

	local borderTransparency = scope:Computed(function(use: FusionUseFn)
		return if use(isHovered) then 0 else Theme.Row.BorderTransparency
	end)

	local shadowTransparency = scope:Computed(function(use: FusionUseFn)
		return if use(isHovered) then 0.75 else 0.82
	end)

	local animatedHeight = scope:Spring(
		totalHeight,
		Theme.Spring.Snappy.Speed
	)

	local animatedGridHeight = scope:Spring(
		displayedGridHeight,
		Theme.Spring.Snappy.Speed
	)

	local expandIndicatorRotation = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isExpanded) then 180 else 0
		end),
		Theme.Spring.Snappy.Speed
	)

	local function toggleExpand()
		hasBeenToggled:set(true)
		isManuallyExpanded:set(not peek(isManuallyExpanded))
	end

	return scope:New("Frame")({
		Name = props.Label,
		Size = scope:Computed(function(use: FusionUseFn)
			return UDim2.new(1, -24, 0, use(animatedHeight) + 4)
		end),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		LayoutOrder = dynamicLayoutOrder,
		Visible = isVisible,
		ClipsDescendants = false,

		[Fusion.OnEvent("MouseEnter")] = function()
			isHovered:set(true)
		end,

		[Fusion.OnEvent("MouseLeave")] = function()
			isHovered:set(false)
		end,

		[Fusion.Children] = {
			Shadow(scope, {
				Size = UDim2.new(1, 8, 1, 4),
				Position = UDim2.new(0.5, 0, 0.5, 2),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = 0,
				Transparency = shadowTransparency,
				ZIndex = 0,
			}),

			scope:New("Frame")({
				Name = "RowContent",
				Size = scope:Computed(function(use: FusionUseFn)
					return UDim2.new(1, 0, 0, use(animatedHeight))
				end),
				Position = UDim2.fromOffset(0, 2),
				BackgroundColor3 = Theme.Row.Background,
				BackgroundTransparency = Theme.Row.BackgroundTransparency,
				BorderSizePixel = 0,
				ZIndex = 1,
				ClipsDescendants = true,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Medium,
					}),

					scope:New("UIStroke")({
						Color = borderColor,
						Thickness = 1,
						Transparency = borderTransparency,
					}),

					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, Theme.Spacing.Medium),
						PaddingRight = UDim.new(0, 10),
					}),

					scope:New("TextLabel")({
						Name = "Label",
						Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
						BackgroundTransparency = 1,
						Text = string.upper(props.Label),
						TextColor3 = Theme.Foreground.Secondary,
						TextSize = Theme.Text.Medium,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),

					scope:New("Frame")({
						Name = "GridContainer",
						Size = scope:Computed(function(use: FusionUseFn)
							return UDim2.new(1, -8, 0, use(animatedGridHeight) + HINT_HEIGHT)
						end),
						Position = UDim2.fromOffset(0, HEADER_HEIGHT + GRID_PADDING),
						BackgroundTransparency = 1,
						ClipsDescendants = true,

						[Fusion.Children] = {
							CursorHistoryGrid(scope, {
								History = props.History,
								RadialCursors = props.RadialCursors,
								OnEquip = props.OnEquip,
								OnToggleRadial = props.OnToggleRadial,
							}),
						},
					}),

					scope:New("TextButton")({
						Name = "ExpandButton",
						Size = UDim2.new(1, -8, 0, 20),
						Position = scope:Computed(function(use: FusionUseFn)
							local gridH = use(animatedGridHeight)
							return UDim2.fromOffset(0, HEADER_HEIGHT + GRID_PADDING + gridH + HINT_HEIGHT + 4)
						end),
						BackgroundColor3 = Theme.Background.Overlay,
						BackgroundTransparency = 0.5,
						BorderSizePixel = 0,
						Text = "",
						AutoButtonColor = false,
						Visible = canExpand,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = Theme.Radius.Small,
							}),

							scope:New("TextLabel")({
								Name = "ExpandText",
								Size = UDim2.new(1, -20, 1, 0),
								Position = UDim2.fromOffset(10, 0),
								BackgroundTransparency = 1,
								Text = scope:Computed(function(use: FusionUseFn)
									local expanded = use(isExpanded)
									local totalRows = use(gridRowCount)
									local hiddenRows = totalRows - MAX_COLLAPSED_ROWS
									if expanded then
										return "COLLAPSE"
									else
										return `SHOW {hiddenRows} MORE ROW{if hiddenRows > 1 then "S" else ""}`
									end
								end),
								TextColor3 = Theme.Foreground.Subtle,
								TextSize = Theme.Text.XSmall,
								Font = Theme.Text.Semibold,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),

							scope:New("TextLabel")({
								Name = "ExpandIcon",
								Size = UDim2.new(0, 16, 1, 0),
								Position = UDim2.new(1, -16, 0, 0),
								BackgroundTransparency = 1,
								Text = "v",
								TextColor3 = Theme.Foreground.Subtle,
								TextSize = Theme.Text.Small,
								Font = Theme.Text.Bold,
								Rotation = expandIndicatorRotation,
							}),
						},

						[Fusion.OnEvent("Activated")] = toggleExpand,
					}),
				},
			}),
		},
	})
end

return CursorHistoryGridRow
