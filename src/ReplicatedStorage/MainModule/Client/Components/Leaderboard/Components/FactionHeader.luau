--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)

local Constants = require(script.Parent.Parent.Constants)
local Utils = require(script.Parent.Parent.Utils)
local HeaderStatColumn = require(script.Parent.HeaderStatColumn)

local Types = require(script.Parent.Parent.Types)
type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FactionData = Types.FactionData

type PlayerStats = Types.PlayerStats

export type FactionHeaderProps = {
	Data: FusionCanBeState<FactionData>,
	Totals: FusionCanBeState<PlayerStats>?,
	IsDefenders: boolean,
	IsSpar: boolean?,
}

local function FactionHeader(scope: FusionScope, props: FactionHeaderProps): Frame
	local data = scope:Computed(function(use: FusionUseFn)
		return use(props.Data)
	end)

	local totals = if props.Totals
		then props.Totals
		else scope:Computed(function(use: FusionUseFn)
			return use(data).totals
		end)

	local iconWidth = if props.IsSpar then 0 elseif props.IsDefenders then Constants.DEFENDER_ICON_WIDTH else Constants.RAIDER_ICON_WIDTH
	local iconHeight = if props.IsSpar then 0 elseif props.IsDefenders then Constants.DEFENDER_ICON_HEIGHT else Constants.RAIDER_ICON_HEIGHT
	local iconPadding = if props.IsSpar then 0 elseif props.IsDefenders then Constants.DEFENDER_ICON_PADDING else Constants.RAIDER_ICON_PADDING
	local iconTextGap = if props.IsSpar then 0 elseif props.IsDefenders then Constants.DEFENDER_ICON_TEXT_GAP else Constants.RAIDER_ICON_TEXT_GAP
	local iconY = (Constants.HEADER_HEIGHT - iconHeight) // 2
	local textX = if props.IsSpar then 12 else (iconPadding + iconWidth + iconTextGap)

	local subTeamLabels: { any } = {
		scope:New("UIListLayout")({
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
	}

	if props.IsDefenders then
		table.insert(
			subTeamLabels,
			scope:New("TextLabel")({
				Name = "Vultarians",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, Constants.HEADER_SUBTEAM_HEIGHT),
				BackgroundTransparency = 1,
				Text = "Vultarians",
				TextColor3 = Constants.Colors.Vultarians,
				TextSize = Constants.SUBTEAM_SIZE,
				Font = Constants.Font.Title,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		)
		table.insert(
			subTeamLabels,
			scope:New("TextLabel")({
				Name = "Initiates",
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, Constants.HEADER_SUBTEAM_HEIGHT),
				BackgroundTransparency = 1,
				Text = "Initiates",
				TextColor3 = Constants.Colors.Initiates,
				TextSize = Constants.SUBTEAM_SIZE,
				Font = Constants.Font.Title,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		)
	else
		table.insert(
			subTeamLabels,
			scope:New("TextLabel")({
				Name = "Hostiles",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, Constants.HEADER_SUBTEAM_HEIGHT),
				BackgroundTransparency = 1,
				Text = "Hostiles",
				TextColor3 = Constants.Colors.Hostiles,
				TextSize = Constants.SUBTEAM_SIZE,
				Font = Constants.Font.Title,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		)
	end

	local subTeamCount = if props.IsDefenders then 2 else 1

	local headerChildren: { any } = {
		scope:New("UICorner")({ CornerRadius = UDim.new(0, Constants.CORNER_RADIUS) }),
		scope:New("UIStroke")({
			Color = Theme.Border.Default,
			Thickness = Constants.BORDER_THICKNESS,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),

		scope:New("ImageLabel")({
			Name = "Icon",
			Position = UDim2.fromOffset(iconPadding, iconY),
			Size = UDim2.fromOffset(iconWidth, iconHeight),
			BackgroundTransparency = 1,
			Visible = not props.IsSpar,
			Image = scope:Computed(function(use: FusionUseFn)
				return use(data).icon
			end),
			ImageColor3 = if props.IsDefenders then Color3.fromRGB(191, 194, 197) else Theme.Colors.White,
		}),

		scope:New("TextLabel")({
			Name = "Title",
			Position = UDim2.fromOffset(textX, Constants.HEADER_ICON_Y),
			Size = UDim2.new(0.7, -textX, 0, Constants.HEADER_TITLE_HEIGHT),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use: FusionUseFn)
				if props.IsSpar then
					return "PLAYERS [" .. tostring(use(data).playerCount) .. "]"
				end
				local title = if props.IsDefenders then Constants.Teams.DefenderTitle else Constants.Teams.RaiderTitle
				return title .. " [" .. tostring(use(data).playerCount) .. "]"
			end),
			TextColor3 = Color3.fromRGB(191, 194, 197),
			TextSize = Constants.HEADER_TITLE_SIZE,
			Font = Constants.Font.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),

		scope:New("Frame")({
			Name = "SubTeams",
			Position = UDim2.fromOffset(textX, Constants.HEADER_SUBTEAMS_Y),
			Size = UDim2.new(0.3, 0, 0, Constants.HEADER_SUBTEAM_HEIGHT * subTeamCount),
			BackgroundTransparency = 1,
			Visible = not props.IsSpar,
			[Fusion.Children] = subTeamLabels,
		}),

		scope:New("Frame")({
			Name = "StatsRow",
			Position = UDim2.fromOffset(0, Constants.HEADER_STATS_Y),
			Size = UDim2.new(1, 0, 0, Constants.HEADER_STATS_HEIGHT),
			BackgroundTransparency = 1,
			[Fusion.Children] = {
				HeaderStatColumn(scope, {
					Label = "KILLS",
					GetValue = function(use: FusionUseFn)
						return tostring(use(totals).Kills)
					end,
					Position = Constants.STAT_COLUMNS[1].pos,
				}),
				HeaderStatColumn(scope, {
					Label = "DMG",
					GetValue = function(use: FusionUseFn)
						return Utils.formatNumber(use(totals).Damage)
					end,
					Position = Constants.STAT_COLUMNS[2].pos,
				}),
				HeaderStatColumn(scope, {
					Label = "HEALS",
					GetValue = function(use: FusionUseFn)
						return Utils.formatNumber(use(totals).Heals)
					end,
					Position = Constants.STAT_COLUMNS[3].pos,
				}),
				HeaderStatColumn(scope, {
					Label = "CAPS",
					GetValue = function(use: FusionUseFn)
						return tostring(use(totals).Captures)
					end,
					Position = Constants.STAT_COLUMNS[4].pos,
				}),
			},
		}),
	}

	return scope:New("Frame")({
		Name = "Header",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Constants.Colors.PanelBackground,
		BackgroundTransparency = Constants.HEADER_BG_TRANSPARENCY,
		BorderSizePixel = 0,
		[Fusion.Children] = headerChildren,
	})
end

return FactionHeader
