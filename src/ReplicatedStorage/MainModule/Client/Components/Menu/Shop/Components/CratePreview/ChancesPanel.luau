--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CratesConfig = require(MainModule.Shared.Config.Cosmetics.Crates)

local Constants = require(script.Parent.Constants)
local PanelHeader = require(script.Parent.PanelHeader)

type FusionScope = Types.FusionScope
type CrateConfig = CratesConfig.CrateConfig
type CrateRarity = CratesConfig.CrateRarity

local function ChanceRow(scope: FusionScope, rarity: CrateRarity, chance: number, itemCount: number, layoutOrder: number): Frame
	local perItem = if itemCount > 0 then chance / itemCount else 0
	return scope:New("Frame")({
		Name = rarity,
		Size = UDim2.new(1, 0, 0, Constants.CHANCE_ROW_HEIGHT),
		BackgroundColor3 = Constants.PANEL_BG,
		BackgroundTransparency = Constants.PANEL_BG_TRANSPARENCY,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),

			scope:New("UIStroke")({
				Color = Constants.PANEL_BORDER,
				Thickness = 1,
				Transparency = Theme.Stroke.Strong,
			}),

			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),

			scope:New("Frame")({
				Name = "Pill",
				Size = UDim2.fromOffset(4, 18),
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = if rarity == "Mythic" then Color3.fromRGB(255, 255, 255) else CratesConfig.getRarityColor(rarity),
				BackgroundTransparency = 0.1,
				BorderSizePixel = 0,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
					if rarity == "Mythic" and CratesConfig.RarityGradients and CratesConfig.RarityGradients.Mythic then
						scope:New("UIGradient")({
							Color = CratesConfig.RarityGradients.Mythic,
							Rotation = 90,
						})
					else nil,
				},
			}),

			scope:New("TextLabel")({
				Name = "RarityName",
				Size = UDim2.new(0.35, -20, 1, 0),
				Position = UDim2.new(0, 14, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text = CratesConfig.RarityLabels[rarity] or rarity,
				TextColor3 = Constants.TITLE_TEXT,
				TextSize = Theme.Text.Medium,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),

			scope:New("Frame")({
				Name = "RightContainer",
				Size = UDim2.fromScale(0.65, 1),
				Position = UDim2.fromScale(1, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "Items",
						Size = UDim2.fromOffset(180, 20),
						Position = UDim2.new(1, -70, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundTransparency = 1,
						Text = string.format("%d ITEMS · %s EACH", itemCount, CratesConfig.formatChance(perItem)),
						TextColor3 = Constants.MUTED_TEXT,
						TextSize = Theme.Text.XSmall,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Right,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),

					scope:New("TextLabel")({
						Name = "Chance",
						Size = UDim2.fromOffset(65, 20),
						Position = UDim2.fromScale(1, 0.5),
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundTransparency = 1,
						Text = CratesConfig.formatChance(chance),
						TextColor3 = Constants.TITLE_TEXT,
						TextSize = Theme.Text.Medium + 1,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Right,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				},
			}),
		},
	})
end

export type ChancesPanelProps = {
	Crate: CrateConfig,
	LayoutOrder: number?,
}

local function ChancesPanel(scope: FusionScope, props: ChancesPanelProps): Frame
	local crate = props.Crate

	local rows: { Instance } = {
		scope:New("UIListLayout")({
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, Constants.CHANCE_ROW_GAP),
		}),
	}

	for index, rarity in CratesConfig.RarityOrder do
		local chance = CratesConfig.getChance(crate, rarity)
		local itemCount = CratesConfig.getDropCount(crate, rarity)
		if chance > 0 or itemCount > 0 then
			table.insert(rows, ChanceRow(scope, rarity, chance, itemCount, index))
		end
	end

	return scope:New("Frame")({
		Name = "Chances",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Constants.CHANCE_ROW_GAP),
			}),

			PanelHeader(scope, {
				Title = "CHANCES",
				LayoutOrder = 0,
			}),

			scope:New("Frame")({
				Name = "Content",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 1,

				[Fusion.Children] = rows,
			}),

			scope:New("TextLabel")({
				Name = "Notices",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Text = if CratesConfig.hasRoundedChances(crate)
					then `{CratesConfig.duplicateNotice()}\n{CratesConfig.ROUNDING_NOTICE}`
					else CratesConfig.duplicateNotice(),
				TextColor3 = Constants.MUTED_TEXT,
				TextSize = Theme.Text.XSmall,
				Font = Theme.Text.Semibold,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
		},
	})
end

return ChancesPanel
