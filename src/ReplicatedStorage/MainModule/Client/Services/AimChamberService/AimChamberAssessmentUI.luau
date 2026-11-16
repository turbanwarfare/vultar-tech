--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local AimChamberConfig = require(MainModule.Shared.Config.AimChamberConfig)

type AimChamberValidationPayload = AimChamberConfig.AimChamberValidationPayload
type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

local _EMPTY = ""
local _peek = Fusion.peek

local AimChamberAssessmentUI = {}

local MODAL_WIDTH = 420
local HEADER_HEIGHT = 44
local ACCENT_COLOR = Color3.fromRGB(255, 180, 60)
local TERMINAL_ICON = "rbxassetid://119015428034090"

local function WatermarkText(scope: FusionScope, text: string, alpha: any, layoutOrder: number): TextLabel
	return scope:New("TextLabel")({
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Text = string.upper(string.rep(text .. "   ", 5)),
		Font = Theme.Text.Bold,
		TextSize = 24,
		TextColor3 = Theme.Colors.White,
		TextTransparency = scope:Computed(function(use)
			return 0.95 + (1 - use(alpha)) * 0.05
		end),
		TextStrokeTransparency = 1,
		TextWrapped = true,
		LayoutOrder = layoutOrder,
		Rotation = -15,
		ZIndex = 0,
	})
end

local function StatRow(scope: FusionScope, label: any, value: any, layoutOrder: number): Frame
	return scope:New("Frame")({
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		ZIndex = 2,
		[Fusion.Children] = {
			scope:New("TextLabel")({
				Size = UDim2.new(0.5, -4, 1, 0),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use)
					local lbl = label
					if typeof(lbl) == "table" and lbl.get then
						lbl = use(lbl)
					end
					return string.upper(tostring(lbl or ""))
				end),
				Font = Theme.Text.Semibold,
				TextSize = Theme.Text.Small,
				TextColor3 = Theme.Foreground.Secondary,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			scope:New("TextLabel")({
				Size = UDim2.new(0.5, -4, 1, 0),
				Position = UDim2.new(0.5, 4, 0, 0),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use)
					local val = value
					if typeof(val) == "table" and val.get then
						val = use(val)
					end
					return string.upper(tostring(val or ""))
				end),
				Font = Theme.Text.Bold,
				TextSize = Theme.Text.Small,
				TextColor3 = Theme.Foreground.Primary,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		},
	})
end

local function PrimaryButton(
	scope: FusionScope,
	props: {
		Text: string,
		OnClick: (() -> ())?,
		IsPrimary: boolean?,
		IsDestructive: boolean?,
		LayoutOrder: number?,
		Width: UDim?,
	}
): TextButton
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)

	local buttonTheme = if props.IsDestructive then Theme.Button.Destructive elseif props.IsPrimary then Theme.Button.Primary else Theme.Button.Secondary

	local bgColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) or use(isPressed) then buttonTheme.BackgroundHover else buttonTheme.Background
		end),
		Theme.Spring.Snappy.Speed
	)

	local scale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isPressed) then 0.98 else 1
		end),
		Theme.Spring.Snappy.Speed
	)

	return scope:New("TextButton")({
		Size = UDim2.new(props.Width or UDim.new(1, 0), UDim.new(0, 38)),
		BackgroundColor3 = bgColor,
		BorderSizePixel = 0,
		Text = string.upper(props.Text),
		TextColor3 = buttonTheme.Foreground,
		TextSize = Theme.Text.Medium,
		Font = Theme.Text.Bold,
		AutoButtonColor = false,
		LayoutOrder = props.LayoutOrder,
		ZIndex = 2,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
			scope:New("UIScale")({ Scale = scale }),
		},

		[Fusion.OnEvent("MouseEnter")] = function()
			isHovered:set(true)
		end,
		[Fusion.OnEvent("MouseLeave")] = function()
			isHovered:set(false)
			isPressed:set(false)
		end,
		[Fusion.OnEvent("MouseButton1Down")] = function()
			isPressed:set(true)
		end,
		[Fusion.OnEvent("MouseButton1Up")] = function()
			isPressed:set(false)
		end,
		[Fusion.OnEvent("Activated")] = function()
			if props.OnClick then
				props.OnClick()
			end
		end,
	})
end

function AimChamberAssessmentUI.createWindow(props: {
	Visible: FusionCanBeState<boolean>,
	Payload: FusionCanBeState<AimChamberValidationPayload?>,
	OnClose: () -> (),
}): ScreenGui
	local scope = Fusion.scoped(Fusion)

	local visible = props.Visible
	local payload = props.Payload

	local isVisible = scope:Computed(function(use: FusionUseFn)
		local v = visible
		if typeof(v) == "table" then
			return use(v :: any) == true
		end
		return v == true
	end)

	local alpha = scope:Spring(
		scope:Computed(function(use)
			return if use(isVisible) then 1 else 0
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local modalScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then 1 else 0.96
		end),
		Theme.Spring.Snappy.Speed
	)
	local modalTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then 0 else 1
		end),
		Theme.Spring.Default.Speed
	)
	local overlayTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then Theme.Modal.OverlayTransparency else 1
		end),
		Theme.Spring.Default.Speed
	)

	local header = scope:New("Frame")({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundColor3 = Theme.Modal.Header,
		BackgroundTransparency = Theme.Modal.HeaderTransparency,
		BorderSizePixel = 0,
		ZIndex = 2,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 10) }),
			scope:New("Frame")({
				Name = "TitleGroup",
				Size = UDim2.new(1, -32, 1, 0),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 8),
					}),
					scope:New("ImageLabel")({
						Name = "Icon",
						Size = UDim2.fromOffset(16, 16),
						BackgroundTransparency = 1,
						Image = TERMINAL_ICON,
						ImageColor3 = ACCENT_COLOR,
					}),
					scope:New("TextLabel")({
						Name = "Title",
						Size = UDim2.fromScale(0, 1),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = "ASSESSMENT REPORT",
						TextColor3 = Theme.Foreground.Primary,
						TextSize = Theme.Text.Small,
						Font = Theme.Text.Bold,
					}),
				},
			}),
			scope:New("TextButton")({
				Name = "CloseButton",
				Size = UDim2.fromOffset(24, 24),
				Position = UDim2.fromScale(1, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Text = "X",
				Font = Theme.Text.Bold,
				TextSize = 18,
				TextColor3 = Theme.Foreground.Secondary,
				[Fusion.OnEvent("Activated")] = function()
					props.OnClose()
				end,
			}),
		},
	})

	local contentFrame = scope:New("Frame")({
		Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT),
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "WatermarkWrapper",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 0,
				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "WatermarkContainer",
						Size = UDim2.fromScale(1.5, 1.5),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 20),
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}),
							scope:ForValues(
								scope:Computed(function(use)
									local p = use(payload)
									if not p then
										return {}
									end
									local mark = p.PlayerName .. " (" .. tostring(p.UserId) .. ")"
									local rows = {}
									for _ = 1, 15 do
										table.insert(rows, mark)
									end
									return rows
								end),
								function(_use, innerScope, mark: string, index: number)
									return WatermarkText(innerScope, mark, alpha, index)
								end
							),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "ScrollContent",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 2,
				[Fusion.Children] = {
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 24),
						PaddingRight = UDim.new(0, 24),
						PaddingTop = UDim.new(0, 24),
						PaddingBottom = UDim.new(0, 24),
					}),

					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 16),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					}),

					scope:New("Frame")({
						Name = "ProfileRow",
						Size = UDim2.new(1, 0, 0, 64),
						BackgroundTransparency = 1,
						LayoutOrder = 1,
						ZIndex = 2,
						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 16),
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}),
							scope:New("ImageLabel")({
								Size = UDim2.fromOffset(64, 64),
								BackgroundColor3 = Theme.Input.Background,
								Image = scope:Computed(function(use)
									local p = use(payload)
									return if p then p.AvatarUrl else ""
								end),
								LayoutOrder = 1,
								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
									scope:New("UIStroke")({ Color = Theme.Input.Border, Transparency = Theme.Stroke.Default }),
								},
							}),
							scope:New("Frame")({
								Size = UDim2.new(0, 200, 1, 0),
								BackgroundTransparency = 1,
								LayoutOrder = 2,
								[Fusion.Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Vertical,
										SortOrder = Enum.SortOrder.LayoutOrder,
										Padding = UDim.new(0, 4),
										VerticalAlignment = Enum.VerticalAlignment.Center,
									}),
									scope:New("TextLabel")({
										Size = UDim2.new(1, 0, 0, 24),
										BackgroundTransparency = 1,
										Text = scope:Computed(function(use)
											local p = use(payload)
											return string.upper(if p then p.PlayerName else "")
										end),
										Font = Theme.Text.Bold,
										TextSize = 20,
										TextColor3 = ACCENT_COLOR,
										TextXAlignment = Enum.TextXAlignment.Left,
										LayoutOrder = 1,
									}),
									scope:New("TextLabel")({
										Size = UDim2.new(1, 0, 0, 16),
										BackgroundTransparency = 1,
										Text = scope:Computed(function(use)
											local p = use(payload)
											return string.upper(if p then "UID: " .. tostring(p.UserId) else "")
										end),
										Font = Theme.Text.Mono,
										TextSize = 14,
										TextColor3 = Theme.Foreground.Secondary,
										TextXAlignment = Enum.TextXAlignment.Left,
										LayoutOrder = 2,
									}),
									scope:New("TextLabel")({
										Size = UDim2.new(1, 0, 0, 16),
										BackgroundTransparency = 1,
										Text = scope:Computed(function(use)
											local p = use(payload)
											return string.upper(if p and p.ViaGroupRank then "VIA RANK: " .. tostring(p.ViaGroupRank) else "")
										end),
										Font = Theme.Text.Mono,
										TextSize = 14,
										TextColor3 = Theme.Foreground.Secondary,
										TextXAlignment = Enum.TextXAlignment.Left,
										LayoutOrder = 3,
									}),
								},
							}),
						},
					}),

					scope:New("Frame")({
						Name = "ResultStats",
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						LayoutOrder = 3,
						ZIndex = 2,
						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 6),
							}),
							StatRow(
								scope,
								"TIME SURVIVED:",
								scope:Computed(function(use)
									local p = use(payload)
									return if p then AimChamberConfig.formatElapsedTime(p.ElapsedTime) else ""
								end),
								1
							),
							StatRow(
								scope,
								"DEATH REASON:",
								scope:Computed(function(use)
									local p = use(payload)
									return if p then p.DeathReason else ""
								end),
								2
							),
							StatRow(
								scope,
								"AVERAGE PING:",
								scope:Computed(function(use)
									local p = use(payload)
									return if p and p.AveragePing then string.format("%.0fMS", math.round(p.AveragePing * 1000)) else "N/A"
								end),
								3
							),
							StatRow(
								scope,
								"MAX PING SPIKE:",
								scope:Computed(function(use)
									local p = use(payload)
									return if p and p.MaxPingSpike then string.format("%.0fMS", math.round(p.MaxPingSpike * 1000)) else "N/A"
								end),
								4
							),
							StatRow(
								scope,
								"SPIKES OVER 400MS:",
								scope:Computed(function(use)
									local p = use(payload)
									return if p and p.BigPingSpikesCount then tostring(p.BigPingSpikesCount) else "N/A"
								end),
								5
							),
							StatRow(
								scope,
								"PRESET:",
								scope:Computed(function(use)
									local p = use(payload)
									return if p then p.PresetId else ""
								end),
								6
							),
							StatRow(
								scope,
								"WEAPON:",
								scope:Computed(function(use)
									local p = use(payload)
									return if p then p.GunName else ""
								end),
								7
							),
							StatRow(
								scope,
								"MAX ZOMBIES:",
								scope:Computed(function(use)
									local p = use(payload)
									return if p then tostring(p.Settings.MaxZombies) else ""
								end),
								8
							),
							StatRow(
								scope,
								"ZOMBIE SPEED:",
								scope:Computed(function(use)
									local p = use(payload)
									return if p then string.format("%.1f", p.Settings.ZombieSpeed) else ""
								end),
								9
							),
							StatRow(
								scope,
								"DAMAGE ENABLED:",
								scope:Computed(function(use)
									local p = use(payload)
									return if p then tostring(p.Settings.ZombieDamageEnabled) else ""
								end),
								10
							),
							StatRow(
								scope,
								"SPAWN RATE:",
								scope:Computed(function(use)
									local p = use(payload)
									return if p then string.format("%.1f/S", p.Settings.ZombieSpawnRate) else ""
								end),
								11
							),
							StatRow(
								scope,
								"DODGE INTERVAL:",
								scope:Computed(function(use)
									local p = use(payload)
									return if p then string.format("%.1fS", p.Settings.ZombieDodgeInterval) else ""
								end),
								12
							),
							StatRow(
								scope,
								"CROUCH CHANCE:",
								scope:Computed(function(use)
									local p = use(payload)
									return if p then string.format("%.0f%%", p.Settings.ZombieCrouchChance * 100) else ""
								end),
								13
							),
						},
					}),

					scope:New("TextLabel")({
						Name = "Timestamp",
						Size = UDim2.new(1, 0, 0, 20),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use)
							local p = use(payload)
							return string.upper(if p then p.FormattedDateTime else "")
						end),
						Font = Theme.Text.Mono,
						TextSize = 16,
						TextColor3 = Theme.Foreground.Secondary,
						TextXAlignment = Enum.TextXAlignment.Center,
						LayoutOrder = 7,
						ZIndex = 2,
					}),
				},
			}),
		},
	})

	local modal = scope:New("Frame")({
		Name = "AimChamberAssessmentModal",
		Size = UDim2.fromOffset(MODAL_WIDTH, 680),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Modal.Background,
		BackgroundTransparency = Theme.Modal.BackgroundTransparency,
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
			scope:New("UIStroke")({ Color = Theme.Modal.Border, Transparency = Theme.Modal.BorderTransparency, Thickness = 1 }),
			scope:New("UIScale")({ Scale = modalScale }),
			scope:New("CanvasGroup")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				GroupTransparency = modalTransparency,
				[Fusion.Children] = {
					header,
					contentFrame,
					scope:New("Frame")({
						Size = UDim2.new(1, 0, 0, 48),
						Position = UDim2.fromScale(0, 1),
						AnchorPoint = Vector2.new(0, 1),
						BackgroundTransparency = 1,
						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
							}),
							PrimaryButton(scope, { Text = "DISMISS", IsPrimary = true, Width = UDim.new(0, 120), OnClick = props.OnClose }),
						},
					}),
				},
			}),
		},
	})

	local screenGui = scope:New("ScreenGui")({
		Name = "AimChamberAssessmentUI",
		AutoLocalize = false,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 200,
		IgnoreGuiInset = true,
		Enabled = scope:Computed(function(use)
			return use(isVisible) or use(modalTransparency) < 0.99
		end),
		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Overlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Colors.Black[900],
				BackgroundTransparency = overlayTransparency,
				Active = true,
				[Fusion.Children] = { modal },
			}),
		},
	})

	table.insert(
		scope,
		screenGui.Destroying:Connect(function()
			scope:doCleanup()
		end)
	)

	return screenGui :: ScreenGui
end

return AimChamberAssessmentUI
