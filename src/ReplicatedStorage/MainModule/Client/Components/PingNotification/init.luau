--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type PingNotificationProps = {
	Visible: Types.FusionValue<boolean>,
	Position: Types.FusionValue<number>,
}

local BOTTOM_PADDING_RIGHT = 290
local BOTTOM_PADDING_BOTTOM = 20

local TOP_PADDING_RIGHT = 16
local TOP_PADDING_TOP = 102

local NOTIFICATION_WIDTH = 210
local NOTIFICATION_HEIGHT = 38

local SHADOW_SPREAD = 4
local SHADOW_TRANSPARENCY = 0.5

local BORDER_COLOR = Color3.fromRGB(130, 50, 55)

local SPRING_SPEED = 35
local SPRING_DAMPING = 1

local function PingNotification(scope: FusionScope, props: PingNotificationProps): ScreenGui
	local isVisible = scope:Computed(function(use: FusionUseFn)
		return use(props.Visible)
	end)

	local positionMode = scope:Computed(function(use: FusionUseFn)
		return use(props.Position)
	end)

	local slideOffset = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			local pos = use(positionMode)
			if pos == 2 then
				return if use(isVisible) then 0 else NOTIFICATION_WIDTH + TOP_PADDING_RIGHT + 50
			else
				return if use(isVisible) then 0 else NOTIFICATION_HEIGHT + BOTTOM_PADDING_BOTTOM + 50
			end
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local framePosition = scope:Computed(function(use: FusionUseFn)
		local pos = use(positionMode)
		local offset = use(slideOffset)
		if pos == 2 then
			return UDim2.new(1, -TOP_PADDING_RIGHT + offset, 0, TOP_PADDING_TOP)
		else
			return UDim2.new(1, -BOTTOM_PADDING_RIGHT, 1, -BOTTOM_PADDING_BOTTOM + offset)
		end
	end)

	local frameAnchor = scope:Computed(function(use: FusionUseFn)
		local pos = use(positionMode)
		if pos == 2 then
			return Vector2.new(1, 0)
		else
			return Vector2.one
		end
	end)

	return scope:New("ScreenGui")({
		Name = "PingNotification",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Wrapper",
				Size = UDim2.fromOffset(NOTIFICATION_WIDTH + SHADOW_SPREAD * 2, NOTIFICATION_HEIGHT + SHADOW_SPREAD * 2),
				Position = framePosition,
				AnchorPoint = frameAnchor,
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					Shadow(scope, {
						Size = UDim2.fromOffset(NOTIFICATION_WIDTH + 20, NOTIFICATION_HEIGHT + 20),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Transparency = SHADOW_TRANSPARENCY,
						Color = BORDER_COLOR,
						ZIndex = 0,
					}),

					scope:New("Frame")({
						Name = "NotificationBox",
						Size = UDim2.fromOffset(NOTIFICATION_WIDTH, NOTIFICATION_HEIGHT),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Theme.Chat.Window.Background,
						BackgroundTransparency = Theme.Chat.Window.BackgroundTransparency,
						ClipsDescendants = true,
						ZIndex = 1,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = Theme.Radius.Medium,
							}),

							scope:New("UIStroke")({
								Color = BORDER_COLOR,
								Thickness = 1,
								Transparency = 0,
							}),

							scope:New("Frame")({
								Name = "Content",
								Size = UDim2.new(1, -24, 1, 0),
								Position = UDim2.fromScale(0.5, 0.5),
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								ZIndex = 2,

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Center,
										VerticalAlignment = Enum.VerticalAlignment.Center,
										Padding = UDim.new(0, 8),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),

									scope:New("TextLabel")({
										Name = "Icon",
										Size = UDim2.fromOffset(20, 30),
										BackgroundTransparency = 1,
										Text = "!",
										TextColor3 = Theme.Colors.White,
										TextSize = 22,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Center,
										TextYAlignment = Enum.TextYAlignment.Center,
										LayoutOrder = 1,
									}),

									scope:New("TextLabel")({
										Name = "PingText",
										Size = UDim2.fromOffset(155, 20),
										BackgroundTransparency = 1,
										Text = "YOU HAVE BEEN PINGED",
										TextColor3 = Theme.Colors.White,
										TextSize = 12,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Center,
										LayoutOrder = 2,
									}),
								},
							}),
						},
					}),
				},
			}),
		},
	})
end

return PingNotification
