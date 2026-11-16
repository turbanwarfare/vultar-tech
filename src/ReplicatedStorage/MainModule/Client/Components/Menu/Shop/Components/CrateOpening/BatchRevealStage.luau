--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CratesConfig = require(MainModule.Shared.Config.Cosmetics.Crates)

local RevealSlot = require(script.Parent.RevealSlot)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type RollResult = CratesConfig.RollResult

export type BatchRevealStageProps = {
	Items: { RollResult },
	SlotVisibility: { Types.FusionValue<boolean> },
	BatchIndex: number,
	TotalBatches: number,
}

local function BatchRevealStage(scope: FusionScope, props: BatchRevealStageProps): Frame
	local items = props.Items
	local numItems = #items
	local slotW = 270
	local slotH = 370
	local gap = 24

	local totalWidth = (numItems * slotW) + ((numItems - 1) * gap)

	local slotChildren = {}
	for i, item in ipairs(items) do
		local visState = props.SlotVisibility[i] or scope:Value(true)
		table.insert(
			slotChildren,
			RevealSlot(scope, {
				Roll = item,
				IsVisible = visState,
				LayoutOrder = i,
				SlotIndex = i,
				Size = UDim2.fromOffset(slotW, slotH),
			})
		)
	end

	return scope:New("Frame")({
		Name = "BatchRevealStage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			if props.TotalBatches > 1 then
				scope:New("TextLabel")({
					Name = "BatchIndicator",
					Size = UDim2.new(1, 0, 0, 24),
					Position = UDim2.fromScale(0.5, 0.15),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Text = string.format("BATCH %d OF %d", props.BatchIndex, props.TotalBatches),
					TextColor3 = Color3.fromRGB(180, 185, 200),
					TextSize = 13,
					Font = Theme.Text.Bold,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
				})
			else
				nil,

			scope:New("Frame")({
				Name = "SlotsContainer",
				Size = UDim2.fromOffset(totalWidth, slotH),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, gap),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					slotChildren,
				},
			}),
		},
	})
end

return BatchRevealStage
