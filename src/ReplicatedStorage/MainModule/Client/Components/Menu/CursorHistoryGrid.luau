--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

export type CursorHistoryGridProps = {
	History: FusionCanBeState<{ number }>,
	RadialCursors: FusionCanBeState<{ number }>,
	OnEquip: ((cursorId: number) -> ())?,
	OnToggleRadial: ((cursorId: number) -> ())?,
	OnRemove: ((cursorId: number) -> ())?,
}

local CELL_SIZE = 40
local CELL_SPACING = 6
local COLUMNS = 12
local MAX_RADIAL = SettingsConfig.MAX_RADIAL_CURSORS

local function CursorHistoryGrid(scope: FusionScope, props: CursorHistoryGridProps): Frame
	local historyItems = scope:Computed(function(use: FusionUseFn)
		local history = use(props.History)
		if type(history) ~= "table" then
			return {}
		end
		return history
	end)

	local radialItems = scope:Computed(function(use: FusionUseFn)
		local radial = use(props.RadialCursors)
		if type(radial) ~= "table" then
			return {}
		end
		return radial
	end)

	local radialCount = scope:Computed(function(use: FusionUseFn)
		return #use(radialItems)
	end)

	local radialLookup = scope:Computed(function(use: FusionUseFn)
		local radial = use(radialItems)
		local lookup: { [number]: boolean } = {}
		for _, cursorId in radial do
			lookup[cursorId] = true
		end
		return lookup
	end)

	local gridCells = scope:ForPairs(historyItems, function(_use, cellScope, index: number, cursorId: number)
		local isHovered = cellScope:Value(false)

		local isInRadial = cellScope:Computed(function(innerUse: FusionUseFn)
			local lookup = innerUse(radialLookup)
			return lookup[cursorId] == true
		end)

		local currentRadialCount = cellScope:Computed(function(innerUse: FusionUseFn)
			return #innerUse(radialItems)
		end)

		local backgroundColor = cellScope:Spring(
			cellScope:Computed(function(innerUse: FusionUseFn)
				local hovered = innerUse(isHovered)
				if hovered then
					return Theme.Background.Overlay
				end
				return Theme.Background.Elevated
			end),
			Theme.Spring.Snappy.Speed
		)

		local cell = cellScope:New("TextButton")({
			Name = tostring(cursorId),
			BackgroundColor3 = backgroundColor,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = index,
			ClipsDescendants = true,

			[Fusion.Children] = {
				cellScope:New("UICorner")({
					CornerRadius = Theme.Radius.Medium,
				}),

				cellScope:New("Frame")({
					Name = "SelectionBorder",
					Size = UDim2.new(1, -4, 1, -4),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					ZIndex = 10,

					[Fusion.Children] = {
						cellScope:New("UICorner")({
							CornerRadius = UDim.new(0, 4),
						}),

						cellScope:New("UIStroke")({
							Color = Color3.fromRGB(50, 150, 255),
							Thickness = 2,
							Transparency = cellScope:Computed(function(innerUse: FusionUseFn)
								local inRadial = innerUse(isInRadial)
								return if inRadial then 0 else 1
							end),
						}),
					},
				}),

				cellScope:New("ImageLabel")({
					Name = "CursorIcon",
					Size = UDim2.fromScale(0.75, 0.75),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://" .. tostring(cursorId),
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 1,
				}),
			},

			[Fusion.OnEvent("MouseEnter")] = function()
				isHovered:set(true)
			end,

			[Fusion.OnEvent("MouseLeave")] = function()
				isHovered:set(false)
			end,

			[Fusion.OnEvent("Activated")] = function()
				if props.OnEquip then
					props.OnEquip(cursorId)
				end
			end,

			[Fusion.OnEvent("MouseButton2Click")] = function()
				if props.OnToggleRadial then
					local inRadial = Fusion.peek(isInRadial)
					local count = Fusion.peek(currentRadialCount)
					if inRadial or count < MAX_RADIAL then
						props.OnToggleRadial(cursorId)
					end
				end
			end,
		})

		return index, cell
	end)

	local historyCount = scope:Computed(function(use: FusionUseFn)
		return #use(historyItems)
	end)

	local rowCount = scope:Computed(function(use: FusionUseFn)
		local count = use(historyCount)
		return math.max(1, math.ceil(count / COLUMNS))
	end)

	local gridHeight = scope:Computed(function(use: FusionUseFn)
		local rows = use(rowCount)
		return (CELL_SIZE * rows) + (CELL_SPACING * math.max(0, rows - 1))
	end)

	local isEmpty = scope:Computed(function(use: FusionUseFn)
		return use(historyCount) == 0
	end)

	return scope:New("Frame")({
		Name = "CursorHistoryGrid",
		Size = scope:Computed(function(use: FusionUseFn)
			local height = use(gridHeight)
			return UDim2.new(1, 0, 0, math.max(CELL_SIZE, height))
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Grid",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use: FusionUseFn)
					return not use(isEmpty)
				end),

				[Fusion.Children] = {
					scope:New("UIGridLayout")({
						CellSize = UDim2.fromOffset(CELL_SIZE, CELL_SIZE),
						CellPadding = UDim2.fromOffset(CELL_SPACING, CELL_SPACING),
						FillDirection = Enum.FillDirection.Horizontal,
						FillDirectionMaxCells = COLUMNS,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					gridCells,
				},
			}),

			scope:New("TextLabel")({
				Name = "EmptyText",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "NO CUSTOM CURSORS YET - ENTER A CURSOR ID ABOVE",
				TextColor3 = Theme.Foreground.Muted,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Semibold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				Visible = isEmpty,
			}),

			scope:New("TextLabel")({
				Name = "HintText",
				Size = UDim2.new(1, 0, 0, 14),
				Position = UDim2.new(0, 0, 1, 4),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use: FusionUseFn)
					local count = use(radialCount)
					return `CLICK TO EQUIP | RIGHT-CLICK TO ADD TO CURSOR MENU ({count}/{MAX_RADIAL})`
				end),
				TextColor3 = Theme.Foreground.Subtle,
				TextSize = Theme.Text.XSmall,
				Font = Theme.Text.Regular,
				TextXAlignment = Enum.TextXAlignment.Left,
				Visible = scope:Computed(function(use: FusionUseFn)
					return not use(isEmpty)
				end),
			}),
		},
	})
end

return CursorHistoryGrid
