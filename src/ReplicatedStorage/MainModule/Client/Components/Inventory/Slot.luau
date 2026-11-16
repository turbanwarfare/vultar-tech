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

export type SlotProps = {
	SlotNumber: number,
	ItemName: FusionCanBeState<string>,
	IsEquipped: FusionCanBeState<boolean>,
	IsEditing: FusionCanBeState<boolean>?,
	IsDropTarget: FusionCanBeState<boolean>?,
	IsDragSource: FusionCanBeState<boolean>?,
	IsVisible: FusionCanBeState<boolean>?,
	IsLockedOut: FusionCanBeState<boolean>?,
	Size: number?,
	OnActivated: (() -> ())?,
	OnDragStart: (() -> ())?,
	OnMouseEnter: (() -> ())?,
	OnMouseLeave: (() -> ())?,
	OnHoverChanged: ((isHovered: boolean) -> ())?,
}

local DEFAULT_SIZE = 56

local SHADOW_SPREAD = 6
local SHADOW_OFFSET_Y = 2
local SHADOW_TRANSPARENCY = 0.7
local PANEL_TRANSPARENCY = 0.55
local CORNER_RADIUS = UDim.new(0, 6)
local DROP_TARGET_BORDER = Theme.Colors.Success
local LOCKOUT_BORDER = Theme.Colors.Destructive
local DRAG_SOURCE_EXTRA_TRANSPARENCY = 0.4

local function Slot(scope: FusionScope, props: SlotProps): Frame
	local size = props.Size or DEFAULT_SIZE
	local containerSize = size + SHADOW_SPREAD * 2

	local isHovered = scope:Value(false)

	local itemNameComputed = scope:Computed(function(use: FusionUseFn)
		local name = props.ItemName
		if typeof(name) == "table" and (name :: any).type == "State" then
			return use(name :: any) or ""
		end
		return (name :: string) or ""
	end)

	local isVisibleComputed = scope:Computed(function(use: FusionUseFn)
		local visible = props.IsVisible
		if visible == nil then
			return true
		end
		if typeof(visible) == "table" and (visible :: any).type == "State" then
			return use(visible :: any)
		end
		return visible :: boolean
	end)

	local isEquippedComputed = scope:Computed(function(use: FusionUseFn)
		local equipped = props.IsEquipped
		if typeof(equipped) == "table" and (equipped :: any).type == "State" then
			return use(equipped :: any)
		end
		return equipped :: boolean
	end)

	local isEditingComputed = scope:Computed(function(use: FusionUseFn)
		local editing = props.IsEditing
		if editing == nil then
			return false
		end
		if typeof(editing) == "table" and (editing :: any).type == "State" then
			return use(editing :: any) or false
		end
		return editing :: boolean
	end)

	local isDropTargetComputed = scope:Computed(function(use: FusionUseFn)
		local target = props.IsDropTarget
		if target == nil then
			return false
		end
		if typeof(target) == "table" and (target :: any).type == "State" then
			return use(target :: any) or false
		end
		return target :: boolean
	end)

	local isDragSourceComputed = scope:Computed(function(use: FusionUseFn)
		local source = props.IsDragSource
		if source == nil then
			return false
		end
		if typeof(source) == "table" and (source :: any).type == "State" then
			return use(source :: any) or false
		end
		return source :: boolean
	end)

	local isLockedOutComputed = scope:Computed(function(use: FusionUseFn)
		local locked = props.IsLockedOut
		if locked == nil then
			return false
		end
		if typeof(locked) == "table" and (locked :: any).type == "State" then
			return use(locked :: any) or false
		end
		return locked :: boolean
	end)

	local panelSizeUDim = UDim2.fromOffset(size, size)

	local strokeColor = scope:Computed(function(use: FusionUseFn)
		if use(isLockedOutComputed) then
			return LOCKOUT_BORDER
		end
		if use(isDropTargetComputed) then
			return DROP_TARGET_BORDER
		end
		if use(isEquippedComputed) then
			return Theme.Inventory.Slot.BorderEquipped
		end
		return Theme.Border.Default
	end)

	local strokeThickness = scope:Computed(function(use: FusionUseFn)
		if use(isLockedOutComputed) or use(isDropTargetComputed) then
			return 2
		end
		return 1
	end)

	local strokeTransparency = scope:Computed(function(use: FusionUseFn)
		if use(isLockedOutComputed) then
			return 0
		end
		if use(isDropTargetComputed) then
			return 0
		end
		if use(isEquippedComputed) then
			return Theme.Inventory.Slot.BorderEquippedTransparency
		end
		return Theme.Stroke.Subtle
	end)

	local panelTransparency = scope:Computed(function(use: FusionUseFn)
		if use(isDragSourceComputed) then
			return PANEL_TRANSPARENCY + DRAG_SOURCE_EXTRA_TRANSPARENCY
		end
		return PANEL_TRANSPARENCY
	end)

	local textTransparency = scope:Computed(function(use: FusionUseFn)
		if use(isDragSourceComputed) then
			return DRAG_SOURCE_EXTRA_TRANSPARENCY
		end
		return 0
	end)

	return scope:New("Frame")({
		Name = "Slot" .. props.SlotNumber,
		Size = UDim2.fromOffset(containerSize, containerSize),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.SlotNumber,
		Visible = isVisibleComputed,

		[Fusion.Children] = {
			Shadow(scope, {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = 0,
				Transparency = SHADOW_TRANSPARENCY,
				ZIndex = 0,
			}),

			scope:New("Frame")({
				Name = "Panel",
				Size = panelSizeUDim,
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.Background.Primary,
				BackgroundTransparency = panelTransparency,
				BorderSizePixel = 0,
				ZIndex = 1,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = CORNER_RADIUS,
					}),

					scope:New("UIStroke")({
						Color = strokeColor,
						Thickness = strokeThickness,
						Transparency = strokeTransparency,
					}),

					scope:New("TextLabel")({
						Name = "SlotNumber",
						Size = UDim2.fromOffset(20, 20),
						Position = UDim2.fromOffset(6, 4),
						BackgroundTransparency = 1,
						Text = tostring(props.SlotNumber),
						TextColor3 = Theme.Foreground.Tertiary,
						TextTransparency = textTransparency,
						TextSize = 12,
						Font = Enum.Font.GothamBlack,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						ZIndex = 2,
					}),

					scope:New("TextLabel")({
						Name = "ItemName",
						Size = UDim2.new(1, -8, 1, -8),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Text = itemNameComputed,
						TextColor3 = Theme.Colors.White,
						TextTransparency = textTransparency,
						TextSize = 14,
						Font = Enum.Font.GothamBold,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						ZIndex = 2,
					}),

					scope:New("TextButton")({
						Name = "Hitbox",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 10,

						[Fusion.OnEvent("MouseEnter")] = function()
							isHovered:set(true)
							if props.OnHoverChanged then
								props.OnHoverChanged(true)
							end
							if props.OnMouseEnter then
								props.OnMouseEnter()
							end
						end,

						[Fusion.OnEvent("MouseLeave")] = function()
							isHovered:set(false)
							if props.OnHoverChanged then
								props.OnHoverChanged(false)
							end
							if props.OnMouseLeave then
								props.OnMouseLeave()
							end
						end,

						[Fusion.OnEvent("Activated")] = function()
							if props.OnActivated then
								props.OnActivated()
							end
						end,

						[Fusion.OnEvent("MouseButton1Down")] = function()
							if Fusion.peek(isEditingComputed) and props.OnDragStart then
								props.OnDragStart()
							end
						end,
					}),
				},
			}),
		},
	})
end

return Slot
