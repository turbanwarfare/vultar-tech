--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionValue<T> = Types.FusionValue<T>

local SIDEBAR_WIDTH = 28
local INDICATOR_WIDTH = 6
local INDICATOR_HEIGHT = 28
local INDICATOR_GAP = 8
local ARROW_SIZE = 16
local ARROW_PADDING = 12

local ACCENT_COLOR = Theme.Store.Tab.Accent
local INACTIVE_COLOR = Color3.fromRGB(100, 105, 115)
local ARROW_COLOR = Color3.fromRGB(140, 145, 155)
local ARROW_HOVER_COLOR = Color3.fromRGB(200, 205, 215)
local BACKGROUND_COLOR = Color3.fromRGB(20, 22, 28)

export type PageSidebarProps = {
	PageCount: number,
	CurrentPage: FusionValue<number>,
	OnPageChange: (page: number) -> (),
}

local function createArrow(
	scope: FusionScope,
	direction: "up" | "down",
	onClick: () -> (),
	canClick: FusionValue<boolean>
): Frame
	local isHovered = scope:Value(false)
	local rotation = if direction == "up" then -90 else 90

	local arrowColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if not use(canClick) then
				return Color3.fromRGB(60, 62, 68)
			end
			return if use(isHovered) then ARROW_HOVER_COLOR else ARROW_COLOR
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	return scope:New("Frame")({
		Name = `Arrow_{direction}`,
		Size = UDim2.new(1, 0, 0, ARROW_SIZE + ARROW_PADDING),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("TextLabel")({
				Name = "ArrowIcon",
				Size = UDim2.fromOffset(ARROW_SIZE, ARROW_SIZE),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Text = "▶",
				TextColor3 = arrowColor,
				TextSize = 10,
				Font = Enum.Font.GothamBold,
				Rotation = rotation,
			}),

			scope:New("TextButton")({
				Name = "Hitbox",
				Size = UDim2.fromScale(1, 1),
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
					if Fusion.peek(canClick) then
						onClick()
					end
				end,
			}),
		},
	})
end

local function createPageIndicator(
	scope: FusionScope,
	pageIndex: number,
	currentPage: FusionValue<number>,
	onClick: () -> ()
): Frame
	local isHovered = scope:Value(false)

	local indicatorColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			local current = use(currentPage)
			if current == pageIndex then
				return ACCENT_COLOR
			end
			return if use(isHovered) then Color3.fromRGB(140, 145, 155) else INACTIVE_COLOR
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local indicatorWidth = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			local current = use(currentPage)
			return if current == pageIndex then INDICATOR_WIDTH + 2 else INDICATOR_WIDTH
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	return scope:New("Frame")({
		Name = `Indicator_{pageIndex}`,
		Size = UDim2.new(1, 0, 0, INDICATOR_HEIGHT),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Bar",
				Size = scope:Computed(function(use: FusionUseFn)
					return UDim2.new(0, use(indicatorWidth), 1, 0)
				end),
				Position = UDim2.fromScale(0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = indicatorColor,
				BorderSizePixel = 0,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 2) }),
				},
			}),

			scope:New("TextButton")({
				Name = "Hitbox",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 10,

				[Fusion.OnEvent("MouseEnter")] = function()
					isHovered:set(true)
				end,
				[Fusion.OnEvent("MouseLeave")] = function()
					isHovered:set(false)
				end,
				[Fusion.OnEvent("Activated")] = onClick,
			}),
		},
	})
end

local function PageSidebar(scope: FusionScope, props: PageSidebarProps): Frame
	local pageCount = props.PageCount
	local currentPage = props.CurrentPage
	local onPageChange = props.OnPageChange

	local canGoUp = scope:Computed(function(use: FusionUseFn)
		return use(currentPage) > 1
	end)

	local canGoDown = scope:Computed(function(use: FusionUseFn)
		return use(currentPage) < pageCount
	end)

	local function goUp()
		local current = Fusion.peek(currentPage)
		if current > 1 then
			onPageChange(current - 1)
		end
	end

	local function goDown()
		local current = Fusion.peek(currentPage)
		if current < pageCount then
			onPageChange(current + 1)
		end
	end

	local indicatorChildren: { Instance } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, INDICATOR_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for i = 1, pageCount do
		local indicator = createPageIndicator(scope, i, currentPage, function()
			onPageChange(i)
		end)
		indicator.LayoutOrder = i
		table.insert(indicatorChildren, indicator)
	end

	local indicatorsHeight = pageCount * INDICATOR_HEIGHT + (pageCount - 1) * INDICATOR_GAP
	local totalHeight = indicatorsHeight + (ARROW_SIZE + ARROW_PADDING) * 2 + 16

	return scope:New("Frame")({
		Name = "PageSidebar",
		Size = UDim2.fromOffset(SIDEBAR_WIDTH, totalHeight),
		Position = UDim2.new(0, -45, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = BACKGROUND_COLOR,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),

			scope:New("UIStroke")({
				Color = Color3.fromRGB(50, 52, 58),
				Thickness = 1,
				Transparency = 0.5,
			}),

			scope:New("Frame")({
				Name = "Content",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					scope:New("Frame")({
						Name = "ArrowUp",
						Size = UDim2.new(1, 0, 0, ARROW_SIZE + ARROW_PADDING),
						BackgroundTransparency = 1,
						LayoutOrder = 1,

						[Fusion.Children] = {
							createArrow(scope, "up", goUp, canGoUp),
						},
					}),

					scope:New("Frame")({
						Name = "Indicators",
						Size = UDim2.new(1, 0, 0, indicatorsHeight),
						BackgroundTransparency = 1,
						LayoutOrder = 2,

						[Fusion.Children] = indicatorChildren,
					}),

					scope:New("Frame")({
						Name = "ArrowDown",
						Size = UDim2.new(1, 0, 0, ARROW_SIZE + ARROW_PADDING),
						BackgroundTransparency = 1,
						LayoutOrder = 3,

						[Fusion.Children] = {
							createArrow(scope, "down", goDown, canGoDown),
						},
					}),
				},
			}),
		},
	})
end

return PageSidebar
