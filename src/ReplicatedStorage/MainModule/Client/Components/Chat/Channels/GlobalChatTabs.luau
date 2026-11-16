--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local ChatTypes = require(MainModule.Shared.Network.Chat.Types)
local ChatConstants = require(MainModule.Shared.Chat.Constants)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn
type GlobalFilter = ChatTypes.GlobalFilter

export type GlobalChatTabsProps = {
	CurrentFilter: FusionCanBeState<GlobalFilter>,
	Visible: FusionCanBeState<boolean>,
	OnFilterChange: (filter: GlobalFilter) -> (),
	Width: number?,
}

local UI = ChatConstants.UI
local TAB_HEIGHT = UI.tabsHeight
local TAB_WIDTH = 60
local TAB_GAP = UI.elementGap
local CONTAINER_WIDTH = TAB_WIDTH * 2 + TAB_GAP
local ANIMATION_SPEED = ChatConstants.Animation.speed
local ANIMATION_DAMPING = ChatConstants.Animation.damping

local SHADOW_SPREAD = 4
local SHADOW_OFFSET_Y = 1
local SHADOW_TRANSPARENCY = 0.7

local function TabButton(
	scope: FusionScope,
	tabId: GlobalFilter,
	label: string,
	currentFilter: FusionCanBeState<GlobalFilter>,
	onClick: () -> ()
): Frame
	local isHovered = scope:Value(false)

	local isSelected = scope:Computed(function(use: FusionUseFn)
		local current = currentFilter
		if typeof(current) == "table" then
			return use(current :: any) == tabId
		end
		return current == tabId
	end)

	local textColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isSelected) then
				return Theme.Colors.White
			elseif use(isHovered) then
				return Theme.Foreground.Secondary
			end
			return Theme.Foreground.Muted
		end),
		Theme.Spring.Default.Speed,
		1
	)

	return scope:New("Frame")({
		Name = tabId,
		Size = UDim2.new(0, TAB_WIDTH, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,

		[Fusion.Children] = {
			scope:New("TextLabel")({
				Name = "Label",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = label,
				TextColor3 = textColor,
				TextSize = 11,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 2,
			}),

			scope:New("Frame")({
				Name = "Underline",
				Size = scope:Spring(
					scope:Computed(function(use: FusionUseFn)
						return UDim2.new(if use(isSelected) then 0.7 else 0, 0, 0, 2)
					end),
					Theme.Spring.Default.Speed,
					1
				),
				Position = UDim2.new(0.5, 0, 1, -4),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Theme.Colors.White,
				BackgroundTransparency = scope:Spring(
					scope:Computed(function(use: FusionUseFn)
						return if use(isSelected) then 0 else 1
					end),
					Theme.Spring.Default.Speed,
					1
				),
				BorderSizePixel = 0,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, 1),
					}),
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

				[Fusion.OnEvent("Activated")] = function()
					onClick()
				end,
			}),
		},
	})
end

local function GlobalChatTabs(scope: FusionScope, props: GlobalChatTabsProps): Frame
	local isVisible = scope:Computed(function(use: FusionUseFn)
		local vis = props.Visible
		if typeof(vis) == "table" then
			return use(vis :: any)
		end
		return vis :: boolean
	end)

	local transparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then 0 else 1
		end),
		ANIMATION_SPEED,
		ANIMATION_DAMPING
	)

	local positionY = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then -SHADOW_SPREAD else -(TAB_HEIGHT + SHADOW_SPREAD)
		end),
		ANIMATION_SPEED,
		ANIMATION_DAMPING
	)

	return scope:New("Frame")({
		Name = "GlobalChatTabs",
		Size = UDim2.fromOffset(CONTAINER_WIDTH + SHADOW_SPREAD * 2, TAB_HEIGHT + SHADOW_SPREAD * 2),
		Position = scope:Computed(function(use: FusionUseFn)
			return UDim2.fromOffset(-SHADOW_SPREAD, use(positionY))
		end),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use: FusionUseFn)
			return use(transparency) < 0.99
		end),

		[Fusion.Children] = {
			Shadow(scope, {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = 0,
				Transparency = scope:Computed(function(use: FusionUseFn)
					return SHADOW_TRANSPARENCY + use(transparency) * (1 - SHADOW_TRANSPARENCY)
				end),
				ZIndex = 0,
			}),

			scope:New("Frame")({
				Name = "TabsContainer",
				Size = UDim2.fromOffset(CONTAINER_WIDTH, TAB_HEIGHT),
				Position = UDim2.fromOffset(SHADOW_SPREAD, SHADOW_SPREAD),
				BackgroundColor3 = Theme.Chat.Input.Background,
				BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
					local base = Theme.Chat.Input.BackgroundTransparency
					return base + use(transparency) * (1 - base)
				end),
				BorderSizePixel = 0,
				ZIndex = 1,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Medium,
					}),

					scope:New("UIStroke")({
						Color = Theme.Chat.Input.Border,
						Thickness = 1,
						Transparency = scope:Computed(function(use: FusionUseFn)
							return 0.3 + use(transparency) * 0.7
						end),
					}),

					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, TAB_GAP),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),

					TabButton(scope, "ALL", "ALL", props.CurrentFilter, function()
						props.OnFilterChange("ALL")
					end),

					TabButton(scope, "TEAM", "TEAM", props.CurrentFilter, function()
						props.OnFilterChange("TEAM")
					end),
				},
			}),
		},
	})
end

return GlobalChatTabs
