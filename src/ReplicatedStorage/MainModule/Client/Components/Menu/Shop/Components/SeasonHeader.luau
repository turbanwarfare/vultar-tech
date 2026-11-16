--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

local ShopConstants = require(script.Parent.Parent.ShopConstants)

type FusionScope = Types.FusionScope

local TRANSPARENCY_NUM_SEQ = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1), })

export type SeasonHeaderProps = {
	SeasonKey: string,
	LayoutOrder: number,
}

local SeasonHeader = {}

function SeasonHeader.create(scope: FusionScope, props: SeasonHeaderProps): Frame
	local config = ShopConstants.SEASON_CONFIG[props.SeasonKey] or {
		name = "OTHER",
		subtitle = "",
		accent = Color3.fromRGB(150, 150, 150),
	}

	return scope:New("Frame")({
		Name = "SeasonHeader_" .. props.SeasonKey,
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Line",
				Size = UDim2.new(1, 0, 0, 2),
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = config.accent,
				BackgroundTransparency = 0.7,

				[Fusion.Children] = {
					scope:New("UIGradient")({
						Transparency = TRANSPARENCY_NUM_SEQ,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "LabelContainer",
				Size = UDim2.fromOffset(0, 32),
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.Colors.Gray[950],

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 20),
						PaddingRight = UDim.new(0, 20),
					}),
					scope:New("UIStroke")({
						Color = config.accent,
						Thickness = 1,
						Transparency = 0.5,
					}),

					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 12),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),

					scope:New("TextLabel")({
						Name = "SeasonName",
						Size = UDim2.fromScale(0, 1),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = config.name,
						TextColor3 = config.accent,
						TextSize = 14,
						Font = Theme.Text.Bold,
						LayoutOrder = 1,
					}),

					if config.subtitle ~= "" then scope:New("TextLabel")({
						Name = "Subtitle",
						Size = UDim2.fromScale(0, 1),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = "— " .. config.subtitle,
						TextColor3 = Theme.Colors.Gray[500],
						TextSize = 12,
						Font = Theme.Text.Medium,
						LayoutOrder = 2,
					}) else nil,
				},
			}),
		},
	})
end

return SeasonHeader
