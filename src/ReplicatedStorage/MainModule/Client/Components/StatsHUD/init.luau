--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type StatsHUDProps = {
	Visible: Types.FusionValue<boolean>,
	Kills: Types.FusionValue<number>,
	Damage: Types.FusionValue<number>,
	Heals: Types.FusionValue<number>,
	Captures: Types.FusionValue<number>,
}

local PADDING = 16
local ROW_GAP = -2
local BOX_GAP = -2

local FPS_PING_WIDTH = 90
local FPS_PING_HEIGHT = 36

local STAT_BOX_WIDTH = 44
local STAT_BOX_WIDTH_WIDE = 62
local STAT_BOX_HEIGHT = 28

local SHADOW_SPREAD = 4
local SHADOW_OFFSET_Y = 1
local SHADOW_TRANSPARENCY = 0.7

local FPS_UPDATE_INTERVAL = 0.25
local PING_UPDATE_INTERVAL = 1

local STAT_PREFIX_K = '<font color="#787878">K:</font> '
local STAT_PREFIX_DMG = '<font color="#787878">DMG:</font> '
local STAT_PREFIX_H = '<font color="#787878">H:</font> '
local STAT_PREFIX_C = '<font color="#787878">C:</font> '

local function getStatText(prefix: string, value: number): string
	return prefix .. tostring(value)
end

local function StatsHUD(scope: FusionScope, props: StatsHUDProps): ScreenGui
	local player = Players.LocalPlayer

	local fps = scope:Value(0)
	local ping = scope:Value(0)

	local fpsAccumulator = 0
	local frameCount = 0
	local pingAccumulator = 0

	local renderConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
		frameCount += 1
		fpsAccumulator += deltaTime
		pingAccumulator += deltaTime

		if fpsAccumulator >= FPS_UPDATE_INTERVAL then
			local calculatedFps = frameCount // fpsAccumulator
			fps:set(calculatedFps)

			frameCount = 0
			fpsAccumulator = 0

			if player and pingAccumulator >= PING_UPDATE_INTERVAL then
				pingAccumulator = 0

				local ok, networkPing = pcall(player.GetNetworkPing, player)

				if ok then
					ping:set(math.floor(networkPing * 1000))
				end
			end
		end
	end)

	table.insert(scope, function()
		renderConnection:Disconnect()
	end)

	return scope:New("ScreenGui")({
		Name = "StatsHUD",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
		Enabled = props.Visible,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Container",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "MainLayout",
						Size = UDim2.fromOffset(250, 80),
						Position = UDim2.new(1, -PADDING, 0, PADDING),
						AnchorPoint = Vector2.new(1, 0),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								HorizontalAlignment = Enum.HorizontalAlignment.Right,
								VerticalAlignment = Enum.VerticalAlignment.Top,
								Padding = UDim.new(0, ROW_GAP),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							scope:New("Frame")({
								Name = "FpsPingWrapper",
								Size = UDim2.fromOffset(FPS_PING_WIDTH + SHADOW_SPREAD * 2, FPS_PING_HEIGHT + SHADOW_SPREAD * 2),
								BackgroundTransparency = 1,
								LayoutOrder = 1,

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
										Name = "FpsPingBox",
										Size = UDim2.fromOffset(FPS_PING_WIDTH, FPS_PING_HEIGHT),
										Position = UDim2.fromScale(0.5, 0.5),
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundColor3 = Theme.Chat.Window.Background,
										BackgroundTransparency = Theme.Chat.Window.BackgroundTransparency,
										ZIndex = 1,

										[Fusion.Children] = {
											scope:New("UICorner")({
												CornerRadius = Theme.Radius.Medium,
											}),

											scope:New("UIStroke")({
												Color = Theme.Chat.Window.Border,
												Thickness = 1,
												Transparency = 0,
											}),

											scope:New("Frame")({
												Name = "Content",
												Size = UDim2.new(1, -20, 0, 26),
												Position = UDim2.fromScale(0.5, 0.5),
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundTransparency = 1,

												[Fusion.Children] = {
													scope:New("UIListLayout")({
														FillDirection = Enum.FillDirection.Vertical,
														HorizontalAlignment = Enum.HorizontalAlignment.Center,
														VerticalAlignment = Enum.VerticalAlignment.Center,
														Padding = UDim.new(0, 2),
														SortOrder = Enum.SortOrder.LayoutOrder,
													}),

													scope:New("Frame")({
														Name = "FPSRow",
														Size = UDim2.new(1, 0, 0, 12),
														BackgroundTransparency = 1,
														LayoutOrder = 1,

														[Fusion.Children] = {
															scope:New("TextLabel")({
																Name = "Label",
																Size = UDim2.fromScale(0.4, 1),
																BackgroundTransparency = 1,
																Text = "FPS",
																TextColor3 = Theme.Foreground.Muted,
																TextSize = 11,
																Font = Theme.Text.Semibold,
																TextXAlignment = Enum.TextXAlignment.Left,
																TextYAlignment = Enum.TextYAlignment.Center,
															}),

															scope:New("TextLabel")({
																Name = "Value",
																Size = UDim2.fromScale(0.6, 1),
																Position = UDim2.fromScale(0.4, 0),
																BackgroundTransparency = 1,
																Text = scope:Computed(function(use: FusionUseFn)
																	return tostring(use(fps))
																end),
																TextColor3 = Theme.Colors.White,
																TextSize = 11,
																Font = Theme.Text.Bold,
																TextXAlignment = Enum.TextXAlignment.Right,
																TextYAlignment = Enum.TextYAlignment.Center,
															}),
														},
													}),

													scope:New("Frame")({
														Name = "PingRow",
														Size = UDim2.new(1, 0, 0, 12),
														BackgroundTransparency = 1,
														LayoutOrder = 2,

														[Fusion.Children] = {
															scope:New("TextLabel")({
																Name = "Label",
																Size = UDim2.fromScale(0.4, 1),
																BackgroundTransparency = 1,
																Text = "PING",
																TextColor3 = Theme.Foreground.Muted,
																TextSize = 11,
																Font = Theme.Text.Semibold,
																TextXAlignment = Enum.TextXAlignment.Left,
																TextYAlignment = Enum.TextYAlignment.Center,
															}),

															scope:New("TextLabel")({
																Name = "Value",
																Size = UDim2.fromScale(0.6, 1),
																Position = UDim2.fromScale(0.4, 0),
																BackgroundTransparency = 1,
																Text = scope:Computed(function(use: FusionUseFn)
																	return tostring(use(ping))
																end),
																TextColor3 = Theme.Colors.White,
																TextSize = 11,
																Font = Theme.Text.Bold,
																TextXAlignment = Enum.TextXAlignment.Right,
																TextYAlignment = Enum.TextYAlignment.Center,
															}),
														},
													}),
												},
											}),
										},
									}),
								},
							}),

							scope:New("Frame")({
								Name = "StatsRow",
								Size = UDim2.fromOffset(280, STAT_BOX_HEIGHT + SHADOW_SPREAD * 2),
								BackgroundTransparency = 1,
								LayoutOrder = 2,

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Right,
										VerticalAlignment = Enum.VerticalAlignment.Center,
										Padding = UDim.new(0, BOX_GAP),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),

									scope:New("Frame")({
										Name = "KillsWrapper",
										Size = UDim2.fromOffset(STAT_BOX_WIDTH + SHADOW_SPREAD * 2, STAT_BOX_HEIGHT + SHADOW_SPREAD * 2),
										BackgroundTransparency = 1,
										LayoutOrder = 1,

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
												Name = "KillsBox",
												Size = UDim2.fromOffset(STAT_BOX_WIDTH, STAT_BOX_HEIGHT),
												Position = UDim2.fromScale(0.5, 0.5),
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Theme.Chat.Window.Background,
												BackgroundTransparency = Theme.Chat.Window.BackgroundTransparency,
												ZIndex = 1,

												[Fusion.Children] = {
													scope:New("UICorner")({
														CornerRadius = Theme.Radius.Medium,
													}),

													scope:New("UIStroke")({
														Color = Theme.Chat.Window.Border,
														Thickness = 1,
														Transparency = 0,
													}),

													scope:New("TextLabel")({
														Size = UDim2.fromScale(1, 1),
														Position = UDim2.fromOffset(0, -1),
														BackgroundTransparency = 1,
														RichText = true,
														Text = scope:Computed(function(use: FusionUseFn)
															return getStatText(STAT_PREFIX_K, use(props.Kills))
														end),
														TextColor3 = Theme.Colors.White,
														TextSize = 11,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Center,
														TextYAlignment = Enum.TextYAlignment.Center,
													}),
												},
											}),
										},
									}),

									scope:New("Frame")({
										Name = "DamageWrapper",
										Size = UDim2.fromOffset(STAT_BOX_WIDTH_WIDE + SHADOW_SPREAD * 2, STAT_BOX_HEIGHT + SHADOW_SPREAD * 2),
										BackgroundTransparency = 1,
										LayoutOrder = 2,

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
												Name = "DamageBox",
												Size = UDim2.fromOffset(STAT_BOX_WIDTH_WIDE, STAT_BOX_HEIGHT),
												Position = UDim2.fromScale(0.5, 0.5),
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Theme.Chat.Window.Background,
												BackgroundTransparency = Theme.Chat.Window.BackgroundTransparency,
												ZIndex = 1,

												[Fusion.Children] = {
													scope:New("UICorner")({
														CornerRadius = Theme.Radius.Medium,
													}),

													scope:New("UIStroke")({
														Color = Theme.Chat.Window.Border,
														Thickness = 1,
														Transparency = 0,
													}),

													scope:New("TextLabel")({
														Size = UDim2.fromScale(1, 1),
														Position = UDim2.fromOffset(0, -1),
														BackgroundTransparency = 1,
														RichText = true,
														Text = scope:Computed(function(use: FusionUseFn)
															return getStatText(STAT_PREFIX_DMG, use(props.Damage))
														end),
														TextColor3 = Theme.Colors.White,
														TextSize = 11,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Center,
														TextYAlignment = Enum.TextYAlignment.Center,
													}),
												},
											}),
										},
									}),

									scope:New("Frame")({
										Name = "HealsWrapper",
										Size = UDim2.fromOffset(STAT_BOX_WIDTH + SHADOW_SPREAD * 2, STAT_BOX_HEIGHT + SHADOW_SPREAD * 2),
										BackgroundTransparency = 1,
										LayoutOrder = 3,

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
												Name = "HealsBox",
												Size = UDim2.fromOffset(STAT_BOX_WIDTH, STAT_BOX_HEIGHT),
												Position = UDim2.fromScale(0.5, 0.5),
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Theme.Chat.Window.Background,
												BackgroundTransparency = Theme.Chat.Window.BackgroundTransparency,
												ZIndex = 1,

												[Fusion.Children] = {
													scope:New("UICorner")({
														CornerRadius = Theme.Radius.Medium,
													}),

													scope:New("UIStroke")({
														Color = Theme.Chat.Window.Border,
														Thickness = 1,
														Transparency = 0,
													}),

													scope:New("TextLabel")({
														Size = UDim2.fromScale(1, 1),
														Position = UDim2.fromOffset(0, -1),
														BackgroundTransparency = 1,
														RichText = true,
														Text = scope:Computed(function(use: FusionUseFn)
															return getStatText(STAT_PREFIX_H, use(props.Heals))
														end),
														TextColor3 = Theme.Colors.White,
														TextSize = 11,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Center,
														TextYAlignment = Enum.TextYAlignment.Center,
													}),
												},
											}),
										},
									}),

									scope:New("Frame")({
										Name = "CapturesWrapper",
										Size = UDim2.fromOffset(STAT_BOX_WIDTH + SHADOW_SPREAD * 2, STAT_BOX_HEIGHT + SHADOW_SPREAD * 2),
										BackgroundTransparency = 1,
										LayoutOrder = 4,

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
												Name = "CapturesBox",
												Size = UDim2.fromOffset(STAT_BOX_WIDTH, STAT_BOX_HEIGHT),
												Position = UDim2.fromScale(0.5, 0.5),
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Theme.Chat.Window.Background,
												BackgroundTransparency = Theme.Chat.Window.BackgroundTransparency,
												ZIndex = 1,

												[Fusion.Children] = {
													scope:New("UICorner")({
														CornerRadius = Theme.Radius.Medium,
													}),

													scope:New("UIStroke")({
														Color = Theme.Chat.Window.Border,
														Thickness = 1,
														Transparency = 0,
													}),

													scope:New("TextLabel")({
														Size = UDim2.fromScale(1, 1),
														Position = UDim2.fromOffset(0, -1),
														BackgroundTransparency = 1,
														RichText = true,
														Text = scope:Computed(function(use: FusionUseFn)
															return getStatText(STAT_PREFIX_C, use(props.Captures))
														end),
														TextColor3 = Theme.Colors.White,
														TextSize = 11,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Center,
														TextYAlignment = Enum.TextYAlignment.Center,
													}),
												},
											}),
										},
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

return StatsHUD
