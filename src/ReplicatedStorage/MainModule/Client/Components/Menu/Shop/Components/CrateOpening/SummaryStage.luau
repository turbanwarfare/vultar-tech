--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CratesConfig = require(MainModule.Shared.Config.Cosmetics.Crates)
local FormatUtils = require(MainModule.Shared.Utils.Text.FormatUtils)

local RevealSlot = require(script.Parent.RevealSlot)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type RollResult = CratesConfig.RollResult

local GOLD_COLOR = CratesConfig.getRarityColor("Rare")
local OPEN_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 255, 66)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 255, 116)),
})

local CELL_WIDTH = 210
local CELL_HEIGHT = 285
local CELL_GAP = 14
local ROW_BUFFER_MOUNT = CELL_HEIGHT + CELL_GAP
local ROW_BUFFER_UNMOUNT = ROW_BUFFER_MOUNT + 60

export type SummaryStageProps = {
	Results: { RollResult },
	TotalRefund: number,
	OnClose: () -> (),
}

local function SummaryStage(scope: FusionScope, props: SummaryStageProps): Frame
	local results = props.Results
	local isHovered = scope:Value(false)

	local btnScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 1.04 else 1
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local canvasPosition = scope:Value(Vector2.zero)
	local absoluteSize = scope:Value(Vector2.new(1000, 450))

	local colsPerRow = scope:Computed(function(use: FusionUseFn)
		local sz = use(absoluteSize)
		local availableWidth = math.max(CELL_WIDTH, sz.X - 32)
		return math.max(1, (availableWidth + CELL_GAP) // (CELL_WIDTH + CELL_GAP))
	end)

	local slotChildren = {}
	for i, item in ipairs(results) do
		local visState = scope:Value(true)

		local useStaticArtComputed: Types.FusionCanBeState<boolean>
		if #results <= 3 then
			useStaticArtComputed = scope:Value(false)
		else
			local isSlotMounted = scope:Value(false)

			local function evaluateVisibility()
				local cols = Fusion.peek(colsPerRow)
				local row = (i - 1) // math.max(1, cols)
				local itemTop = row * (CELL_HEIGHT + CELL_GAP)
				local itemBottom = itemTop + CELL_HEIGHT

				local scrollPos = Fusion.peek(canvasPosition)
				local sz = Fusion.peek(absoluteSize)
				local scrollY = scrollPos.Y
				local viewH = sz.Y

				local currentMounted = Fusion.peek(isSlotMounted)
				local currentBuffer = if currentMounted then ROW_BUFFER_UNMOUNT else ROW_BUFFER_MOUNT
				local shouldBeMounted = (itemBottom >= (scrollY - currentBuffer)) and (itemTop <= (scrollY + viewH + currentBuffer))

				if shouldBeMounted ~= currentMounted then
					isSlotMounted:set(shouldBeMounted)
				end
			end

			evaluateVisibility()

			table.insert(scope, scope:Observer(canvasPosition):onChange(evaluateVisibility))
			table.insert(scope, scope:Observer(absoluteSize):onChange(evaluateVisibility))
			table.insert(scope, scope:Observer(colsPerRow):onChange(evaluateVisibility))

			useStaticArtComputed = scope:Computed(function(use: FusionUseFn)
				return not use(isSlotMounted)
			end)
		end

		table.insert(
			slotChildren,
			RevealSlot(scope, {
				Roll = item,
				IsVisible = visState,
				LayoutOrder = i,
				Size = UDim2.fromOffset(CELL_WIDTH, CELL_HEIGHT),
				UseStaticArt = useStaticArtComputed,
				IsHoverable = true,
			})
		)
	end

	local count = #results
	local itemWord = if count == 1 then "ITEM" else "ITEMS"
	local formattedRefund = FormatUtils.formatNumberWithCommas(props.TotalRefund)
	local subtitleText = if props.TotalRefund > 0
		then string.format("%d %s UNBOXED  +%s CR DUPLICATE REFUND", count, itemWord, formattedRefund)
		else string.format("%d %s UNBOXED", count, itemWord)

	local frame = scope:New("Frame")({
		Name = "SummaryStage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "SummaryHeader",
				Size = UDim2.new(1, 0, 0, 68),
				Position = UDim2.new(0.5, 0, 0, 18),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "Title",
						Size = UDim2.new(1, 0, 0, 32),
						BackgroundTransparency = 1,
						Text = "CRATE SUMMARY",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 28,
						Font = Theme.Text.Black,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),

					scope:New("TextLabel")({
						Name = "Subtitle",
						Size = UDim2.new(1, 0, 0, 22),
						Position = UDim2.fromOffset(0, 34),
						BackgroundTransparency = 1,
						Text = subtitleText,
						TextColor3 = if props.TotalRefund > 0 then GOLD_COLOR else Color3.fromRGB(170, 175, 190),
						TextSize = 16,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				},
			}),

			if #results <= 3
				then scope:New("Frame")({
					Name = "SlotsContainer",
					Size = UDim2.fromOffset((#results * (CELL_WIDTH + 10)) + ((#results - 1) * CELL_GAP) + 32, CELL_HEIGHT + 32),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					ClipsDescendants = false,

					[Fusion.Children] = {
						scope:New("UIPadding")({
							PaddingLeft = UDim.new(0, 16),
							PaddingRight = UDim.new(0, 16),
							PaddingTop = UDim.new(0, 16),
							PaddingBottom = UDim.new(0, 16),
						}),

						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Padding = UDim.new(0, CELL_GAP),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),

						slotChildren,
					},
				})
				else scope:New("ScrollingFrame")({
					Name = "ResultsGridFrame",
					Size = UDim2.new(0.92, 0, 1, -164),
					Position = UDim2.new(0.5, 0, 0, 94),
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 4,
					ScrollBarImageColor3 = Theme.Scrollbar.Thumb,
					ScrollBarImageTransparency = 0.4,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					CanvasSize = UDim2.fromOffset(0, 0),
					ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
					ClipsDescendants = true,

					[Fusion.Out("CanvasPosition")] = canvasPosition,
					[Fusion.Out("AbsoluteSize")] = absoluteSize,

					[Fusion.Children] = {
						scope:New("UIPadding")({
							PaddingLeft = UDim.new(0, 16),
							PaddingRight = UDim.new(0, 16),
							PaddingTop = UDim.new(0, 8),
							PaddingBottom = UDim.new(0, 16),
						}),

						scope:New("UIGridLayout")({
							CellSize = UDim2.fromOffset(CELL_WIDTH, CELL_HEIGHT),
							CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP),
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),

						slotChildren,
					},
				}),

			scope:New("Frame")({
				Name = "BottomButtonContainer",
				Size = UDim2.fromOffset(220, 44),
				Position = UDim2.new(0.5, 0, 1, -18),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIScale")({ Scale = btnScale }),

					scope:New("Frame")({
						Name = "ButtonBackground",
						Size = UDim2.fromScale(1, 1),
						BorderSizePixel = 0,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),

							scope:New("UIGradient")({
								Color = OPEN_GRADIENT,
								Rotation = 270,
							}),

							scope:New("UIStroke")({
								Color = Color3.fromRGB(255, 255, 255),
								Thickness = 1,
								Transparency = 0.35,
							}),

							scope:New("TextButton")({
								Name = "ContinueButton",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = "CONTINUE",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = Theme.Text.Large,
								Font = Theme.Text.Black,
								AutoButtonColor = false,

								[Fusion.OnEvent("MouseEnter")] = function()
									isHovered:set(true)
								end,
								[Fusion.OnEvent("MouseLeave")] = function()
									isHovered:set(false)
								end,
								[Fusion.OnEvent("Activated")] = props.OnClose,
							}),
						},
					}),
				},
			}),
		},
	})

	return frame
end

return SummaryStage
