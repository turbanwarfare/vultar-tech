--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

local peek: <T>(state: FusionCanBeState<T>) -> T = Fusion.peek

export type SectionProps = {
	Title: string,
	Children: { Instance },
	LayoutOrder: number?,
	SearchFilter: FusionCanBeState<string>?,
	BestScore: FusionCanBeState<number>?,
}

local TITLE_HEIGHT = 36
local ROW_PADDING = 6
local HORIZONTAL_PADDING = 14
local CONTENT_VERTICAL_PADDING = 8

local SECTION_GRADIENT_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.new(0.7, 0.7, 0.7)),
})

local function Section(scope: FusionScope, props: SectionProps): Frame
	local isCollapsed = scope:Value(false)
	local isHovered = scope:Value(false)
	local contentSize = scope:Value(Vector2.zero)

	local collapseIndicatorRotation = scope:Computed(function(use: FusionUseFn)
		return if use(isCollapsed) then 0 else 90
	end)

	local borderColor = scope:Computed(function(use: FusionUseFn)
		return if use(isHovered) then Theme.Border.Active else Theme.Section.Divider
	end)

	local isSearching = scope:Computed(function(use: FusionUseFn)
		if not props.SearchFilter then return false end
		local query = use(props.SearchFilter)
		return query ~= ""
	end)

	local isVisible = scope:Computed(function(use: FusionUseFn)
		if not props.SearchFilter then return true end
		local query = use(props.SearchFilter)
		if query == "" then return true end
		return use(contentSize).Y > 0
	end)

	local dynamicLayoutOrder = scope:Computed(function(use: FusionUseFn)
		if not props.SearchFilter or not props.BestScore then return props.LayoutOrder or 0 end
		local query = use(props.SearchFilter)
		if query == "" then return props.LayoutOrder or 0 end
		local bestScore = use(props.BestScore)
		return 10000 - bestScore
	end)

	local contentLayout = scope:New("UIListLayout")({
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, ROW_PADDING),
		SortOrder = Enum.SortOrder.LayoutOrder,

		[Fusion.Out("AbsoluteContentSize")] = contentSize,
	})

	local contentChildren: { Instance } = {
		contentLayout,
	}

	for i, child in props.Children do
		if typeof(child) == "Instance" then
			child.LayoutOrder = i
		end
		table.insert(contentChildren, child)
	end

	local contentHeight = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			local shouldShow = use(isSearching) or not use(isCollapsed)
			if shouldShow then
				return use(contentSize).Y + (CONTENT_VERTICAL_PADDING * 2)
			end
			return 0
		end),
		Theme.Spring.Snappy.Speed
	)

	local contentFrame = scope:New("Frame")({
		Name = "Content",
		Size = scope:Computed(function(use: FusionUseFn)
			return UDim2.new(1, 0, 0, use(contentHeight))
		end),
		BackgroundTransparency = 1,
		ClipsDescendants = true,

		[Fusion.Children] = {
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, CONTENT_VERTICAL_PADDING),
				PaddingBottom = UDim.new(0, CONTENT_VERTICAL_PADDING),
			}),
			unpack(contentChildren),
		},
	})

	return scope:New("Frame")({
		Name = props.Title,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = dynamicLayoutOrder,
		Visible = isVisible,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, ROW_PADDING),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			scope:New("Frame")({
				Name = "TitleBarWrapper",
				Size = UDim2.new(1, 0, 0, TITLE_HEIGHT + 4),
				BackgroundTransparency = 1,
				LayoutOrder = 0,

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
						Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
						Position = UDim2.fromOffset(0, 2),
						BackgroundColor3 = Theme.Section.Background,
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
								Size = UDim2.new(1, -HORIZONTAL_PADDING * 2 - 20, 1, 0),
								Position = UDim2.fromOffset(HORIZONTAL_PADDING, 0),
								BackgroundTransparency = 1,
								Text = string.upper(props.Title),
								TextColor3 = Theme.Section.Text,
								TextSize = Theme.Text.Large,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 2,
							}),

							scope:New("TextLabel")({
								Name = "CollapseIndicator",
								Size = UDim2.new(0, 12, 1, 0),
								Position = UDim2.new(1, -HORIZONTAL_PADDING - 12, 0, 0),
								BackgroundTransparency = 1,
								Text = ">",
								TextColor3 = Theme.Section.Text,
								TextSize = Theme.Text.Small,
								Font = Theme.Text.Bold,
								Rotation = collapseIndicatorRotation,
								ZIndex = 2,
							}),

							scope:New("TextButton")({
								Name = "Hitbox",
								Size = UDim2.fromScale(1, 1),
								Position = UDim2.fromScale(0, 0),
								BackgroundTransparency = 1,
								Text = "",
								ZIndex = 10,

								[Fusion.OnEvent("MouseEnter")] = function()
									isHovered:set(true)
								end,

								[Fusion.OnEvent("MouseLeave")] = function()
									isHovered:set(false)
								end,

								[Fusion.OnEvent("Activated")] = function()
									isCollapsed:set(not peek(isCollapsed))
								end,
							}),
						},
					}),
				},
			}),

			contentFrame,
		},
	})
end

return Section
