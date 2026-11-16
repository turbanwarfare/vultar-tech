--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Buttons = require(MainModule.Client.Components.Buttons)
local StoreHubRedirects = require(MainModule.Shared.Config.StoreHubRedirects)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionCanBeState<T> = Types.FusionCanBeState<T>

export type StoreHubRedirectPromptProps = {
	Visible: FusionCanBeState<boolean>,
	GamepassId: FusionCanBeState<number?>,
	Teleporting: FusionCanBeState<boolean>?,
	StatusText: FusionCanBeState<string>?,
	OnTakeMeThere: () -> (),
	OnStayHere: () -> (),
}

local function StoreHubRedirectPrompt(scope: FusionScope, props: StoreHubRedirectPromptProps): Frame
	local modalVisible = scope:Computed(function(use: FusionUseFn)
		return use(props.Visible)
	end)

	local backgroundTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(modalVisible) then Theme.Modal.OverlayTransparency else 1
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local modalScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(modalVisible) then 1 else 0.97
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local modalTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(modalVisible) then 0 else 1
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local targetHubName = scope:Computed(function(use: FusionUseFn)
		local gamepassId = use(props.GamepassId)
		if gamepassId then
			local hub = StoreHubRedirects.getHubForGamepass(gamepassId)
			if hub then
				return string.upper(hub.displayName)
			end
		end
		return "VULTARIAN MILITARY RESERVE STORE HUB"
	end)

	local statusText = scope:Computed(function(use: FusionUseFn)
		if not props.StatusText then
			return ""
		end
		return use(props.StatusText)
	end)

	return scope:New("Frame")({
		Name = "StoreHubRedirectPrompt",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		ZIndex = Theme.ZIndex.Modal,
		Visible = modalVisible,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Overlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Modal.Overlay,
				BackgroundTransparency = backgroundTransparency,
				BorderSizePixel = 0,
				ZIndex = Theme.ZIndex.Modal,
			}),

			scope:New("CanvasGroup")({
				Name = "ModalContainer",
				Size = UDim2.fromOffset(520, 300),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.Modal.Background,
				BackgroundTransparency = Theme.Modal.BackgroundTransparency,
				BorderSizePixel = 0,
				GroupTransparency = modalTransparency,
				ZIndex = Theme.ZIndex.Modal + 1,

				[Fusion.Children] = {
					scope:New("UIScale")({
						Scale = modalScale,
					}),

					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Large,
					}),

					scope:New("UIStroke")({
						Color = Theme.Modal.Border,
						Thickness = 1,
					}),

					scope:New("Frame")({
						Name = "Header",
						Size = UDim2.new(1, 0, 0, 54),
						BackgroundColor3 = Theme.Modal.Header,
						BackgroundTransparency = Theme.Modal.HeaderTransparency,
						BorderSizePixel = 0,
						ZIndex = Theme.ZIndex.Modal + 2,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = Theme.Radius.Large,
							}),

							scope:New("Frame")({
								Name = "HeaderMask",
								Size = UDim2.fromScale(1, 0.5),
								Position = UDim2.fromScale(0, 1),
								AnchorPoint = Vector2.new(0, 1),
								BackgroundColor3 = Theme.Modal.Header,
								BorderSizePixel = 0,
								ZIndex = Theme.ZIndex.Modal + 2,
							}),

							scope:New("TextLabel")({
								Name = "Title",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = "STORE HUB REQUIRED",
								TextColor3 = Theme.Foreground.Primary,
								TextSize = 20,
								Font = Theme.Text.Bold,
								ZIndex = Theme.ZIndex.Modal + 3,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "Content",
						Size = UDim2.new(1, -56, 1, -126),
						Position = UDim2.fromOffset(28, 72),
						BackgroundTransparency = 1,
						ZIndex = Theme.ZIndex.Modal + 2,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								Padding = UDim.new(0, 14),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							scope:New("TextLabel")({
								Name = "Body",
								Size = UDim2.new(1, 0, 0, 92),
								BackgroundTransparency = 1,
								Text = "Due to Roblox's May 29 update, we can no longer sell cross game gamepasses here. To complete this purchase, we need to send you to the correct Vultarian Military Reserve store hub.",
								TextColor3 = Theme.Foreground.Secondary,
								TextSize = 19,
								Font = Theme.Text.Semibold,
								TextWrapped = true,
								TextXAlignment = Enum.TextXAlignment.Center,
								TextYAlignment = Enum.TextYAlignment.Center,
								LayoutOrder = 1,
								ZIndex = Theme.ZIndex.Modal + 3,
							}),

							scope:New("TextLabel")({
								Name = "TargetHub",
								Size = UDim2.new(1, 0, 0, 20),
								BackgroundTransparency = 1,
								Text = targetHubName,
								TextColor3 = Theme.Colors.SuccessHover,
								TextSize = 13,
								Font = Theme.Text.Bold,
								TextWrapped = true,
								TextXAlignment = Enum.TextXAlignment.Center,
								LayoutOrder = 2,
								ZIndex = Theme.ZIndex.Modal + 3,
							}),

							scope:New("TextLabel")({
								Name = "Status",
								Size = UDim2.new(1, 0, 0, 18),
								BackgroundTransparency = 1,
								Text = statusText,
								TextColor3 = Theme.Colors.Destructive,
								TextSize = 12,
								Font = Theme.Text.Semibold,
								TextWrapped = true,
								TextXAlignment = Enum.TextXAlignment.Center,
								Visible = scope:Computed(function(use: FusionUseFn)
									return use(statusText) ~= ""
								end),
								LayoutOrder = 3,
								ZIndex = Theme.ZIndex.Modal + 3,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "Buttons",
						Size = UDim2.new(1, -56, 0, 42),
						Position = UDim2.new(0, 28, 1, -62),
						BackgroundTransparency = 1,
						ZIndex = Theme.ZIndex.Modal + 2,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								Padding = UDim.new(0, 14),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							Buttons.Button(scope, {
								Text = "TAKE ME THERE",
								Variant = "primary",
								Size = UDim2.fromOffset(190, 40),
								LayoutOrder = 1,
								Loading = props.Teleporting,
								ZIndex = Theme.ZIndex.Modal + 3,
								OnClick = props.OnTakeMeThere,
							}),

							Buttons.Button(scope, {
								Text = "STAY HERE",
								Variant = "secondary",
								Size = UDim2.fromOffset(150, 40),
								LayoutOrder = 2,
								ZIndex = Theme.ZIndex.Modal + 3,
								OnClick = props.OnStayHere,
							}),
						},
					}),
				},
			}),
		},
	})
end

return StoreHubRedirectPrompt
