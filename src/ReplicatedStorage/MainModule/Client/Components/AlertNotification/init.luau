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

export type AlertNotificationProps = {
	Visible: Types.FusionValue<boolean>,
	Title: string,
	Description: string,
	YOffset: number,
	OnClose: () -> (),
}

local TOP_PADDING_RIGHT = 16
local TOP_PADDING_TOP = 102

local NOTIFICATION_WIDTH = 260

local SHADOW_TRANSPARENCY = 0.5

local SPRING_SPEED = 35
local SPRING_DAMPING = 1

local function AlertNotification(scope: FusionScope, props: AlertNotificationProps): ScreenGui
	local isVisible = scope:Computed(function(use: FusionUseFn)
		return use(props.Visible)
	end)

	local slideOffset = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then 0 else NOTIFICATION_WIDTH + TOP_PADDING_RIGHT + 50
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local framePosition = scope:Computed(function(use: FusionUseFn)
		local offset = use(slideOffset)
		return UDim2.new(1, -TOP_PADDING_RIGHT + offset, 0, TOP_PADDING_TOP + props.YOffset)
	end)

	local frameAnchor = Vector2.new(1, 0)

	return scope:New("ScreenGui")({
		Name = "AlertNotification",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Wrapper",
				Size = UDim2.fromOffset(268, 72),
				Position = framePosition,
				AnchorPoint = frameAnchor,
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					Shadow(scope, {
						Size = UDim2.fromOffset(280, 81),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Transparency = SHADOW_TRANSPARENCY,
						Color = Color3.fromRGB(0, 0, 0),
						ZIndex = 0,
					}),

					scope:New("Frame")({
						Name = "NotificationBox",
						Size = UDim2.fromOffset(260, 66),
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
								Color = Color3.fromRGB(75, 73, 75),
								Thickness = 1,
								Transparency = 0,
							}),

							scope:New("TextLabel")({
								Name = "Title",
								Size = UDim2.new(1, -40, 0, 24),
								Position = UDim2.fromOffset(12, 8),
								BackgroundTransparency = 1,
								Text = props.Title,
								TextColor3 = Theme.Colors.White,
								TextSize = 14,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Center,
							}),
							
							scope:New("TextButton")({
								Name = "CloseButton",
								Size = UDim2.fromOffset(24, 24),
								Position = UDim2.new(1, -8, 0, 8),
								AnchorPoint = Vector2.new(1, 0),
								BackgroundTransparency = 1,
								Text = "X",
								TextColor3 = Theme.Colors.White,
								TextSize = 16,
								Font = Theme.Text.Bold,
								
								[Fusion.OnEvent("Activated")] = function()
									if props.OnClose then
										props.OnClose()
									end
								end,
							}),

							scope:New("TextLabel")({
								Name = "Description",
								Size = UDim2.new(1, -24, 1, -40),
								Position = UDim2.fromOffset(12, 32),
								BackgroundTransparency = 1,
								Text = props.Description,
								TextColor3 = Theme.Foreground.Secondary,
								TextSize = 12,
								Font = Theme.Text.Regular,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Top,
								TextWrapped = true,
								RichText = true,
							}),
						},
					}),
				},
			}),
		},
	})
end

return AlertNotification
