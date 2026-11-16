--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CratesConfig = require(MainModule.Shared.Config.Cosmetics.Crates)
local Shadow = require(MainModule.Client.Components.Shadow)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type CrateConfig = CratesConfig.CrateConfig

local PANEL_BG = Color3.fromRGB(20, 20, 20)
local PANEL_BG_TRANSPARENCY = 0.2
local PANEL_BORDER = Color3.fromRGB(140, 140, 160)
local PANEL_BORDER_TRANSPARENCY = 0.3

local function getPlayerGui(): PlayerGui?
	local localPlayer = Players.LocalPlayer
	if localPlayer then
		return localPlayer:FindFirstChildOfClass("PlayerGui")
	end
	return nil
end

export type CrateInfoModalProps = {
	Crate: CrateConfig,
	OnClose: () -> (),
	ZIndex: number?,
}

local function CrateInfoModal(scope: FusionScope, props: CrateInfoModalProps): ScreenGui
	local crate = props.Crate
	local isCloseHovered = scope:Value(false)

	local hasRounding = CratesConfig.hasRoundedChances(crate)
	local roundingHeight = if hasRounding then 32 else 0

	local oddsRows: { Instance } = {
		scope:New("UIListLayout")({
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	}

	for idx, entry in crate.odds do
		local rColor = CratesConfig.getRarityColor(entry.rarity)
		local itemCount = CratesConfig.getDropCount(crate, entry.rarity)
		local perItem = if itemCount > 0 then entry.chance / itemCount else 0

		local row = scope:New("Frame")({
			Name = "OddsRow_" .. entry.rarity,
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = PANEL_BG,
			BackgroundTransparency = PANEL_BG_TRANSPARENCY,
			BorderSizePixel = 0,
			LayoutOrder = idx,

			[Fusion.Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),

				scope:New("UIStroke")({
					Color = PANEL_BORDER,
					Thickness = 1,
					Transparency = PANEL_BORDER_TRANSPARENCY,
				}),

				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
				}),

				scope:New("Frame")({
					Name = "Pill",
					Size = UDim2.fromOffset(4, 16),
					Position = UDim2.fromScale(0, 0.5),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = if entry.rarity == "Mythic" then Color3.fromRGB(255, 255, 255) else rColor,
					BorderSizePixel = 0,

					[Fusion.Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0, 2) }),
						if entry.rarity == "Mythic"
								and CratesConfig.RarityGradients
								and CratesConfig.RarityGradients.Mythic
							then scope:New("UIGradient")({
								Color = CratesConfig.RarityGradients.Mythic,
								Rotation = 90,
							})
							else nil,
					},
				}),

				scope:New("TextLabel")({
					Name = "RarityName",
					Size = UDim2.fromScale(0.3, 1),
					Position = UDim2.fromOffset(12, 0),
					BackgroundTransparency = 1,
					Text = CratesConfig.RarityLabels[entry.rarity] or entry.rarity,
					TextColor3 = Color3.fromRGB(230, 230, 235),
					TextSize = Theme.Text.Small,
					Font = Theme.Text.Bold,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),

				scope:New("TextLabel")({
					Name = "ItemsCount",
					Size = UDim2.fromScale(0.48, 1),
					Position = UDim2.fromScale(0.3, 0),
					BackgroundTransparency = 1,
					Text = string.format("%d ITEMS · %s EACH", itemCount, CratesConfig.formatChance(perItem)),
					TextColor3 = Color3.fromRGB(140, 145, 160),
					TextSize = 11,
					Font = Theme.Text.Semibold,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),

				scope:New("TextLabel")({
					Name = "ChancePercent",
					Size = UDim2.fromScale(0.22, 1),
					Position = UDim2.fromScale(1, 0),
					AnchorPoint = Vector2.new(1, 0),
					BackgroundTransparency = 1,
					Text = CratesConfig.formatChance(entry.chance),
					TextColor3 = rColor,
					TextSize = Theme.Text.Small + 1,
					Font = Theme.Text.Black,
					TextXAlignment = Enum.TextXAlignment.Right,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),
			},
		})

		table.insert(oddsRows, row)
	end

	return scope:New("ScreenGui")({
		Name = "CrateDetailsModalGui",
		AutoLocalize = false,
		DisplayOrder = 100010,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = getPlayerGui(),

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Overlay",
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0, 0),
				BackgroundColor3 = Theme.Modal.Overlay,
				BackgroundTransparency = Theme.Modal.OverlayTransparency,
				BorderSizePixel = 0,
				Active = true,
				ZIndex = 1,
			}),

			scope:New("Frame")({
				Name = "DialogCard",
				Size = UDim2.fromOffset(450, 460),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = PANEL_BG,
				BackgroundTransparency = PANEL_BG_TRANSPARENCY,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Active = true,
				ZIndex = 2,

				[Fusion.Children] = {
					Shadow(scope, {
						Size = UDim2.new(1, 24, 1, 24),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Spread = 12,
						Transparency = 0.5,
						ZIndex = 0,
					}),

					scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),

					scope:New("UIStroke")({
						Color = PANEL_BORDER,
						Thickness = 1,
						Transparency = PANEL_BORDER_TRANSPARENCY,
						BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					}),

					scope:New("ImageLabel")({
						Name = "Stripes",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = Theme.Patterns.DiagonalStripes.Fat,
						ImageColor3 = Theme.Section.Stripe.Color,
						ImageTransparency = 0.94,
						ScaleType = Enum.ScaleType.Tile,
						TileSize = UDim2.fromOffset(48, 48),
						ZIndex = 1,
					}),

					scope:New("Frame")({
						Name = "Content",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						ZIndex = 3,

						[Fusion.Children] = {
							scope:New("UIPadding")({
								PaddingLeft = UDim.new(0, 22),
								PaddingRight = UDim.new(0, 22),
								PaddingTop = UDim.new(0, 16),
								PaddingBottom = UDim.new(0, 16),
							}),

							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 10),
							}),

							scope:New("Frame")({
								Name = "Header",
								Size = UDim2.new(1, 0, 0, 32),
								BackgroundTransparency = 1,
								LayoutOrder = 1,

								[Fusion.Children] = {
									scope:New("TextLabel")({
										Name = "Title",
										Size = UDim2.new(1, -36, 1, 0),
										Position = UDim2.fromOffset(0, 0),
										BackgroundTransparency = 1,
										Text = "DETAILS",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextSize = 18,
										Font = Theme.Text.Black,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Center,
									}),

									scope:New("TextButton")({
										Name = "CloseButton",
										Size = UDim2.fromOffset(26, 26),
										Position = UDim2.fromScale(1, 0.5),
										AnchorPoint = Vector2.new(1, 0.5),
										BackgroundTransparency = 1,
										Text = "X",
										TextColor3 = scope:Computed(function(use: FusionUseFn)
											return if use(isCloseHovered) then Color3.fromRGB(255, 255, 255) else Theme.Foreground.Muted
										end),
										TextSize = 15,
										Font = Theme.Text.Bold,
										AutoButtonColor = false,
										ZIndex = 4,

										[Fusion.OnEvent("MouseEnter")] = function()
											isCloseHovered:set(true)
										end,
										[Fusion.OnEvent("MouseLeave")] = function()
											isCloseHovered:set(false)
										end,
										[Fusion.OnEvent("Activated")] = props.OnClose,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "OddsSection",
								Size = UDim2.new(1, 0, 0, 24 + (#crate.odds * 32 + math.max(0, #crate.odds - 1) * 6) + roundingHeight),
								BackgroundTransparency = 1,
								LayoutOrder = 2,

								[Fusion.Children] = {
									scope:New("TextLabel")({
										Name = "SectionTitle",
										Size = UDim2.new(1, 0, 0, 20),
										Position = UDim2.fromOffset(0, 0),
										BackgroundTransparency = 1,
										Text = "CHANCES",
										TextColor3 = Color3.fromRGB(160, 165, 180),
										TextSize = 11,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Center,
									}),

									scope:New("Frame")({
										Name = "OddsList",
										Size = UDim2.new(1, 0, 0, #crate.odds * 32 + math.max(0, #crate.odds - 1) * 6),
										Position = UDim2.fromOffset(0, 24),
										BackgroundTransparency = 1,

										[Fusion.Children] = oddsRows,
									}),

									scope:New("TextLabel")({
										Name = "RoundingNotice",
										Size = UDim2.new(1, 0, 0, 28),
										Position = UDim2.new(0, 0, 1, -28),
										BackgroundTransparency = 1,
										Text = CratesConfig.ROUNDING_NOTICE,
										TextColor3 = Color3.fromRGB(140, 145, 160),
										TextSize = 10,
										Font = Theme.Text.Regular,
										TextWrapped = true,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Top,
										Visible = hasRounding,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "DescriptionSection",
								Size = UDim2.new(1, 0, 0, 36),
								BackgroundTransparency = 1,
								LayoutOrder = 4,

								[Fusion.Children] = {
									scope:New("TextLabel")({
										Name = "DescriptionText",
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = "Crates contain exclusive cosmetic gun skins and player cards. Items unlocked are added immediately to your inventory.",
										TextColor3 = Color3.fromRGB(170, 175, 190),
										TextSize = 11.5,
										Font = Theme.Text.Regular,
										TextWrapped = true,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Top,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "DuplicateNotice",
								Size = UDim2.new(1, 0, 0, 60),
								BackgroundColor3 = PANEL_BG,
								BackgroundTransparency = PANEL_BG_TRANSPARENCY,
								BorderSizePixel = 0,
								LayoutOrder = 3,

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),

									scope:New("UIStroke")({
										Color = PANEL_BORDER,
										Thickness = 1,
										Transparency = PANEL_BORDER_TRANSPARENCY,
									}),

									scope:New("UIPadding")({
										PaddingLeft = UDim.new(0, 12),
										PaddingRight = UDim.new(0, 12),
										PaddingTop = UDim.new(0, 8),
										PaddingBottom = UDim.new(0, 8),
									}),

									scope:New("TextLabel")({
										Name = "DuplicateTitle",
										Size = UDim2.new(1, 0, 0, 16),
										BackgroundTransparency = 1,
										Text = "DUPLICATE ITEM CONVERSION",
										TextColor3 = CratesConfig.getRarityColor("Rare"),
										TextSize = 11,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Center,
									}),

									scope:New("TextLabel")({
										Name = "DuplicateBody",
										Size = UDim2.new(1, 0, 0, 26),
										Position = UDim2.fromOffset(0, 18),
										BackgroundTransparency = 1,
										Text = CratesConfig.duplicateNotice(),
										TextColor3 = Color3.fromRGB(190, 195, 210),
										TextSize = 11,
										Font = Theme.Text.Regular,
										TextWrapped = true,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Top,
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

return CrateInfoModal
