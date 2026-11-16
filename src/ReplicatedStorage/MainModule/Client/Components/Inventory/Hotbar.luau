--!native
--!optimize 2

local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local InventoryConfig = require(MainModule.Shared.Config.Inventory.InventoryConfig)

local Slot = require(script.Parent.Slot)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn
type InventoryItem = InventoryConfig.InventoryItem

export type HotbarProps = {
	Items: FusionCanBeState<{ InventoryItem }>,
	EquippedSlot: FusionCanBeState<number>,
	IsEditing: FusionCanBeState<boolean>?,
	LockedOutSlot: FusionCanBeState<number>?,
	IsLockoutFlashing: FusionCanBeState<boolean>?,
	SlotSize: number?,
	SlotGap: number?,
	BottomPadding: number?,
	OnSlotActivated: ((slot: number) -> ())?,
	OnSwapSlots: ((slotA: number, slotB: number) -> ())?,
}

local DEFAULT_SLOT_SIZE = 56
local DEFAULT_SLOT_GAP = -6
local DEFAULT_BOTTOM_PADDING = 32
local SHADOW_SPREAD = 6
local SIZE_INCREASE = 0
local ALL_SLOTS = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
local EDIT_HINT_HEIGHT = 20

local function Hotbar(scope: FusionScope, props: HotbarProps): Frame
	local slotSize = props.SlotSize or DEFAULT_SLOT_SIZE
	local slotGap = props.SlotGap or DEFAULT_SLOT_GAP
	local bottomPadding = props.BottomPadding or DEFAULT_BOTTOM_PADDING

	local maxSlotSize = slotSize + SIZE_INCREASE
	local slotContainerSize = maxSlotSize + SHADOW_SPREAD * 2

	local isDragging = scope:Value(false)
	local dragSourceSlot = scope:Value(0)
	local hoveredSlot = scope:Value(0)
	local dragPosition = scope:Value(Vector2.zero)
	local dragItemName = scope:Value("")

	local inputConnection: RBXScriptConnection? = nil
	local endConnection: RBXScriptConnection? = nil

	local function cleanupDragConnections()
		if inputConnection then
			inputConnection:Disconnect()
			inputConnection = nil
		end
		if endConnection then
			endConnection:Disconnect()
			endConnection = nil
		end
	end

	table.insert(scope, cleanupDragConnections)

	local isEditingComputed = scope:Computed(function(use: FusionUseFn)
		local editing = props.IsEditing
		if typeof(editing) == "table" and (editing :: any).type == "State" then
			return use(editing :: any) or false
		end
		return (editing :: boolean?) or false
	end)

	local itemsComputed = scope:Computed(function(use: FusionUseFn)
		local items = props.Items
		if typeof(items) == "table" and (items :: any).type == "State" then
			return use(items :: any) or {}
		end
		return (items :: { InventoryItem }) or {}
	end)

	local itemsBySlot = scope:Computed(function(use: FusionUseFn)
		local items = use(itemsComputed)
		local lookup: { [number]: InventoryItem } = {}
		for _, item in items do
			lookup[item.Slot] = item
		end
		return lookup
	end)

	local equippedComputed = scope:Computed(function(use: FusionUseFn)
		local equipped = props.EquippedSlot
		if typeof(equipped) == "table" and (equipped :: any).type == "State" then
			return use(equipped :: any) or 0
		end
		return (equipped :: number) or 0
	end)

	local lockedOutComputed = scope:Computed(function(use: FusionUseFn)
		local locked = props.LockedOutSlot
		if typeof(locked) == "table" and (locked :: any).type == "State" then
			return use(locked :: any) or 0
		end
		return (locked :: number?) or 0
	end)

	local isLockoutFlashingComputed = scope:Computed(function(use: FusionUseFn)
		local flashing = props.IsLockoutFlashing
		if typeof(flashing) == "table" and (flashing :: any).type == "State" then
			return use(flashing :: any) or false
		end
		return (flashing :: boolean?) or false
	end)

	local visibleSlotCount = scope:Computed(function(use: FusionUseFn)
		local editing = use(isEditingComputed)
		if editing then
			return 9
		end
		local items = use(itemsComputed)
		return #items
	end)

	local slotsWidth = scope:Computed(function(use: FusionUseFn)
		local count = use(visibleSlotCount)
		return (slotContainerSize * count) + (slotGap * math.max(0, count - 1))
	end)

	local containerHeight = scope:Computed(function(use: FusionUseFn)
		local editing = use(isEditingComputed)
		if editing then
			return slotContainerSize + EDIT_HINT_HEIGHT
		end
		return slotContainerSize
	end)

	local containerSize = scope:Computed(function(use: FusionUseFn)
		local width = use(slotsWidth)
		local height = use(containerHeight)
		return UDim2.fromOffset(width, height)
	end)

	local containerVisible = scope:Computed(function(use: FusionUseFn)
		local editing = use(isEditingComputed)
		if editing then
			return true
		end
		local items = use(itemsComputed)
		return #items > 0
	end)

	local function startDrag(slot: number, itemName: string)
		if not Fusion.peek(isEditingComputed) then
			return
		end

		isDragging:set(true)
		dragSourceSlot:set(slot)
		dragItemName:set(itemName)
		dragPosition:set(UserInputService:GetMouseLocation())

		cleanupDragConnections()

		inputConnection = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				dragPosition:set(Vector2.new(input.Position.X, input.Position.Y))
			end
		end)

		endConnection = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local target = Fusion.peek(hoveredSlot)
				local source = Fusion.peek(dragSourceSlot)
				if target > 0 and target ~= source and props.OnSwapSlots then
					props.OnSwapSlots(source, target)
				end
				isDragging:set(false)
				dragSourceSlot:set(0)
				dragItemName:set("")
				hoveredSlot:set(0)
				cleanupDragConnections()
			end
		end)
	end

	local slots = scope:ForValues(ALL_SLOTS, function(_use: FusionUseFn, slotScope: FusionScope, slotNum: number)
		local itemForSlot = slotScope:Computed(function(innerUse: FusionUseFn)
			local lookup = innerUse(itemsBySlot)
			return lookup[slotNum]
		end)

		local itemName = slotScope:Computed(function(innerUse: FusionUseFn)
			local item = innerUse(itemForSlot)
			return if item then item.Name else ""
		end)

		local slotVisible = slotScope:Computed(function(innerUse: FusionUseFn)
			local editing = innerUse(isEditingComputed)
			if editing then
				return true
			end
			local item = innerUse(itemForSlot)
			return item ~= nil
		end)

		local isEquipped = slotScope:Computed(function(innerUse: FusionUseFn)
			return innerUse(equippedComputed) == slotNum
		end)

		local isDropTarget = slotScope:Computed(function(innerUse: FusionUseFn)
			return innerUse(isDragging) and innerUse(hoveredSlot) == slotNum and innerUse(dragSourceSlot) ~= slotNum
		end)

		local isDragSource = slotScope:Computed(function(innerUse: FusionUseFn)
			return innerUse(isDragging) and innerUse(dragSourceSlot) == slotNum
		end)

		local isLockedOut = slotScope:Computed(function(innerUse: FusionUseFn)
			local isSlotLocked = innerUse(lockedOutComputed) == slotNum
			if not isSlotLocked then
				return false
			end
			return innerUse(isLockoutFlashingComputed)
		end)

		return Slot(slotScope, {
			SlotNumber = slotNum,
			ItemName = itemName,
			IsEquipped = isEquipped,
			IsEditing = isEditingComputed,
			IsDropTarget = isDropTarget,
			IsDragSource = isDragSource,
			IsVisible = slotVisible,
			IsLockedOut = isLockedOut,
			Size = slotSize,
			OnActivated = function()
				if props.OnSlotActivated then
					props.OnSlotActivated(slotNum)
				end
			end,
			OnDragStart = function()
				local item = Fusion.peek(itemForSlot)
				if item then
					startDrag(slotNum, item.Name)
				end
			end,
			OnMouseEnter = function()
				hoveredSlot:set(slotNum)
			end,
			OnMouseLeave = function()
				if not Fusion.peek(isDragging) then
					hoveredSlot:set(0)
				end
			end,
		})
	end)

	local dragPreviewPosition = scope:Computed(function(use: FusionUseFn)
		local pos = use(dragPosition)
		return UDim2.fromOffset(pos.X, pos.Y)
	end)

	return scope:New("Frame")({
		Name = "HotbarRoot",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "HotbarContainer",
				Position = UDim2.new(0.5, 0, 1, -bottomPadding),
				AnchorPoint = Vector2.new(0.5, 1),
				Size = containerSize,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Visible = containerVisible,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "EditHint",
						Size = UDim2.new(1, 0, 0, EDIT_HINT_HEIGHT),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Text = "Drag to reorder | ` to exit",
						TextColor3 = Color3.fromRGB(255, 140, 0),
						TextSize = 11,
						Font = Enum.Font.Gotham,
						TextXAlignment = Enum.TextXAlignment.Center,
						Visible = isEditingComputed,
					}),

					scope:New("Frame")({
						Name = "SlotsFrame",
						Size = UDim2.new(1, 0, 0, slotContainerSize),
						Position = UDim2.fromScale(0.5, 1),
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, slotGap),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							slots,
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "DragPreview",
				Size = UDim2.fromOffset(50, 50),
				Position = dragPreviewPosition,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.Background.Elevated,
				BackgroundTransparency = 0.3,
				Visible = isDragging,
				ZIndex = 100,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, 6),
					}),

					scope:New("UIStroke")({
						Color = Theme.Colors.Success,
						Thickness = 2,
						Transparency = 0.2,
					}),

					scope:New("TextLabel")({
						Name = "ItemName",
						Size = UDim2.new(1, -6, 1, -6),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Text = dragItemName,
						TextColor3 = Theme.Colors.White,
						TextSize = 12,
						Font = Enum.Font.GothamBold,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				},
			}),
		},
	})
end

return Hotbar
