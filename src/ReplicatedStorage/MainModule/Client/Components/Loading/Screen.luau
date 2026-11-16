--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

type FusionScope = Types.FusionScope

local DeployButton = require(script.Parent.DeployButton)
local CreditsButton = require(script.Parent.CreditsButton)
local Constants = require(MainModule.Shared.Config.Constants)

export type ScreenProps = {
	OnDeploy: (() -> ())?,
	OnCredits: (() -> ())?,
}

local function Screen(scope: FusionScope, props: ScreenProps): ScreenGui
	local player = Players.LocalPlayer
	local playerName = if player then player.Name else "Player"

	local gui = scope:New("ScreenGui")({
		Name = "VultarLoadingScreen",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 999999,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Background",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Colors.Black[950],
				BorderSizePixel = 0,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.None,
					}),

					scope:New("ImageLabel")({
						Name = "BackgroundImage",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = Constants.LOADING_SCREEN_IMAGE,
						ScaleType = Enum.ScaleType.Crop,
						ImageTransparency = 0,
					}),

					scope:New("Frame")({
						Name = "TopSection",
						Size = UDim2.new(1, 0, 0, 100),
						Position = UDim2.fromScale(0.5, 0.08),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("TextLabel")({
								Name = "Welcome",
								Size = UDim2.new(1, 0, 0, 20),
								Position = UDim2.fromScale(0.5, 0),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundTransparency = 1,
								Text = "WELCOME",
								TextColor3 = Theme.Foreground.Tertiary,
								TextSize = 14,
								Font = Theme.Text.Regular,
							}),

							scope:New("TextLabel")({
								Name = "PlayerName",
								Size = UDim2.new(1, 0, 0, 35),
								Position = UDim2.fromScale(0.5, 0.25),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundTransparency = 1,
								Text = string.upper(playerName),
								TextColor3 = Theme.Foreground.Primary,
								TextSize = Theme.Text.Display,
								Font = Theme.Text.Bold,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "ButtonContainer",
						Size = UDim2.fromOffset(320, 120),
						Position = UDim2.fromScale(0.5, 0.55),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, Theme.Spacing.Small),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							DeployButton(scope, {
								Size = UDim2.new(1, 0, 0, 55),
								LayoutOrder = 1,
								OnClick = props.OnDeploy,
							}),

							CreditsButton(scope, {
								Size = UDim2.new(1, 0, 0, 40),
								LayoutOrder = 2,
								OnClick = props.OnCredits,
							}),
						},
					}),
				},
			}),
		},
	})
	return gui
end

return Screen
