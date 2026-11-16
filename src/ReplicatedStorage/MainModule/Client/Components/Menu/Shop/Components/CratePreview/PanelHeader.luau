--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)

local Constants = require(script.Parent.Constants)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>

local SECTION_GRADIENT_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(178, 178, 178)),
})

export type PanelHeaderProps = {
	Title: string,
	Detail: FusionCanBeState<string>?,
	LayoutOrder: number?,
}

local function PanelHeader(scope: FusionScope, props: PanelHeaderProps): Frame
	local titleBarChildren: { Instance } = {
		scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),

		scope:New("UIStroke")({
			Color = Constants.PANEL_BORDER,
			Thickness = 1,
			Transparency = Theme.Stroke.Strong,
		}),

		scope:New("ImageLabel")({
			Name = "Stripes",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Theme.Patterns.DiagonalStripes.Fat,
			ImageColor3 = Theme.Section.Stripe.Color,
			ImageTransparency = Theme.Section.Stripe.Transparency,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(Theme.Section.Stripe.TileSize, Theme.Section.Stripe.TileSize),
			ZIndex = 1,
		}),

		scope:New("UIGradient")({
			Color = SECTION_GRADIENT_SEQUENCE,
			Rotation = 90,
		}),

		scope:New("TextLabel")({
			Name = "Title",
			Size = UDim2.new(1, -Constants.HEADER_TEXT_INSET * 2 - 90, 1, 0),
			Position = UDim2.fromOffset(Constants.HEADER_TEXT_INSET, 0),
			BackgroundTransparency = 1,
			Text = string.upper(props.Title),
			TextColor3 = Theme.Section.Text,
			TextSize = Theme.Text.Large,
			Font = Theme.Text.Bold,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,
		}),
	}

	if props.Detail then
		table.insert(
			titleBarChildren,
			scope:New("TextLabel")({
				Name = "Detail",
				Size = UDim2.fromOffset(120, Constants.HEADER_HEIGHT),
				Position = UDim2.new(1, -Constants.HEADER_TEXT_INSET, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Text = props.Detail,
				TextColor3 = Constants.MUTED_TEXT,
				TextSize = Theme.Text.Medium,
				Font = Theme.Text.Black,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 5,
			})
		)
	end

	return scope:New("Frame")({
		Name = "TitleBarWrapper",
		Size = UDim2.new(1, 0, 0, Constants.HEADER_HEIGHT + 4),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,

		[Fusion.Children] = {
			Shadow(scope, {
				Size = UDim2.new(1, 8, 1, 4),
				Position = UDim2.new(0.5, 0, 0.5, 2),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = 0,
				Transparency = 0.78,
				ZIndex = 0,
			}),

			scope:New("Frame")({
				Name = "TitleBar",
				Size = UDim2.new(1, 0, 0, Constants.HEADER_HEIGHT),
				Position = UDim2.fromOffset(0, 2),
				BackgroundColor3 = Theme.Section.Background,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				ZIndex = 1,

				[Fusion.Children] = titleBarChildren,
			}),
		},
	})
end

return PanelHeader
