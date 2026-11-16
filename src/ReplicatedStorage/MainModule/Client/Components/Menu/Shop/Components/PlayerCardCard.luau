--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

local PriceCache = require(script.Parent.Parent.Cache.PriceCache)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionValue<T> = Types.FusionValue<T>

local TRANSPARENCY_NUM_SEQ_2 = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.1), NumberSequenceKeypoint.new(0.55, 0.45), NumberSequenceKeypoint.new(0.8, 0.8), NumberSequenceKeypoint.new(1, 1), })
local TRANSPARENCY_NUM_SEQ = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.95), NumberSequenceKeypoint.new(0.75, 0.75), NumberSequenceKeypoint.new(1, 0.55), })
local COLOR_CLR_SEQ = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 120, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 80, 200)), })

local CORNER_RADIUS = 8
local LB_ROW_HEIGHT = 52
local LB_USERNAME_END = 0.40
local LB_STAT_WIDTH = 0.15
local LB_STAT_START = LB_USERNAME_END
local LB_LOCAL_COLOR = Color3.fromRGB(219, 182, 87)

local rng = Random.new()

local function getPlayerAvatar(userId: number): string
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
end

local function generateRandomStats(): { Kills: number, Damage: number, Heals: number, Captures: number }
	return {
		Kills = rng:NextInteger(1, 50),
		Damage = rng:NextInteger(2000, 8000),
		Heals = rng:NextInteger(500, 3000),
		Captures = rng:NextInteger(0, 10),
	}
end

export type PlayerCardCardProps = {
	CardId: string,
	CardName: string,
	ImageId: string,
	GamepassId: number,
	LayoutOrder: number,
	IsAnimated: boolean?,
	OnClick: () -> (),
}

local function PlayerCardCard(scope: FusionScope, props: PlayerCardCardProps): Frame
	local isHovered = scope:Value(false)
	local price = scope:Value(0)

	PriceCache.getPriceAsync(props.GamepassId, price)

	local localPlayer = Players.LocalPlayer
	local playerDisplayName = localPlayer and localPlayer.DisplayName or "Player"
	local playerAvatar = localPlayer and getPlayerAvatar(localPlayer.UserId) or ""
	local stats = generateRandomStats()

	local cardScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 1.03 else 1
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local leaderboardTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0 else 1
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local pureImageTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 1 else 0
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local bgTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0.88 else 0.92
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local borderTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0.3 else 0.5
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local priceText = scope:Computed(function(use: FusionUseFn)
		local p = use(price)
		if p == -1 then
			return "OWNED"
		elseif p > 0 then
			return tostring(p) .. " R$"
		else
			return "..."
		end
	end)

	local priceColor = scope:Computed(function(use: FusionUseFn)
		local p = use(price)
		if p == -1 then
			return Color3.fromRGB(100, 200, 255)
		else
			return Color3.fromRGB(0, 200, 100)
		end
	end)

	return scope:New("Frame")({
		Name = props.CardId,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "ScaleContainer",
				Size = UDim2.fromScale(1, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIScale")({ Scale = cardScale }),

					scope:New("CanvasGroup")({
						Name = "Card",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Color3.fromRGB(30, 32, 40),
						BackgroundTransparency = bgTransparency,
						BorderSizePixel = 0,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER_RADIUS) }),

							scope:New("UIStroke")({
								Color = Color3.fromRGB(100, 105, 120),
								Thickness = 1,
								Transparency = borderTransparency,
							}),

							scope:New("Frame")({
								Name = "PreviewArea",
								Size = UDim2.new(1, -16, 1, -50),
								Position = UDim2.new(0.5, 0, 0, 8),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundTransparency = 1,
								ClipsDescendants = true,

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),

									scope:New("CanvasGroup")({
										Name = "PureImageView",
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										GroupTransparency = pureImageTransparency,
										ZIndex = 2,

										[Fusion.Children] = {
											scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
											scope:New("ImageLabel")({
												Name = "Image",
												Size = UDim2.fromScale(1, 1),
												BackgroundTransparency = 1,
												Image = props.ImageId,
												ScaleType = Enum.ScaleType.Crop,
												[Fusion.Children] = {
													scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
												},
											}),
										},
									}),

									scope:New("CanvasGroup")({
										Name = "LeaderboardView",
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										GroupTransparency = leaderboardTransparency,
										ZIndex = 1,

										[Fusion.Children] = {
											scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),

											scope:New("Frame")({
												Name = "ColumnHeaders",
												Size = UDim2.new(1, 0, 0, 18),
												Position = UDim2.new(0, 0, 0.5, -LB_ROW_HEIGHT / 2 - 22),
												BackgroundTransparency = 1,

												[Fusion.Children] = {
													scope:New("TextLabel")({
														Name = "KillsHeader",
														Position = UDim2.fromScale(LB_STAT_START, 0.5),
														AnchorPoint = Vector2.new(0, 0.5),
														Size = UDim2.fromScale(LB_STAT_WIDTH, 1),
														BackgroundTransparency = 1,
														Text = "K",
														TextColor3 = Color3.fromRGB(100, 100, 110),
														TextSize = 11,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Center,
													}),

													scope:New("TextLabel")({
														Name = "DamageHeader",
														Position = UDim2.fromScale(LB_STAT_START + LB_STAT_WIDTH, 0.5),
														AnchorPoint = Vector2.new(0, 0.5),
														Size = UDim2.fromScale(LB_STAT_WIDTH, 1),
														BackgroundTransparency = 1,
														Text = "DMG",
														TextColor3 = Color3.fromRGB(100, 100, 110),
														TextSize = 11,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Center,
													}),

													scope:New("TextLabel")({
														Name = "HealsHeader",
														Position = UDim2.fromScale(LB_STAT_START + LB_STAT_WIDTH * 2, 0.5),
														AnchorPoint = Vector2.new(0, 0.5),
														Size = UDim2.fromScale(LB_STAT_WIDTH, 1),
														BackgroundTransparency = 1,
														Text = "HEAL",
														TextColor3 = Color3.fromRGB(100, 100, 110),
														TextSize = 11,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Center,
													}),

													scope:New("TextLabel")({
														Name = "CapsHeader",
														Position = UDim2.fromScale(LB_STAT_START + LB_STAT_WIDTH * 3, 0.5),
														AnchorPoint = Vector2.new(0, 0.5),
														Size = UDim2.fromScale(LB_STAT_WIDTH, 1),
														BackgroundTransparency = 1,
														Text = "CAP",
														TextColor3 = Color3.fromRGB(100, 100, 110),
														TextSize = 11,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Center,
													}),
												},
											}),

											scope:New("Frame")({
												Name = "PlayerRow",
												Size = UDim2.new(1, -8, 0, LB_ROW_HEIGHT),
												Position = UDim2.fromScale(0.5, 0.5),
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundTransparency = 1,

												[Fusion.Children] = {
													scope:New("Frame")({
														Name = "CardBackground",
														Size = UDim2.fromScale(1, 1),
														BackgroundTransparency = 1,
														ClipsDescendants = true,

														[Fusion.Children] = {
															scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),

															scope:New("ImageLabel")({
																Name = "Background",
																Size = UDim2.fromScale(1.6, 1),
																BackgroundTransparency = 1,
																Image = props.ImageId,
																ImageTransparency = 0.15,
																ScaleType = Enum.ScaleType.Crop,

																[Fusion.Children] = {
																	scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
																	scope:New("UIGradient")({
																		Transparency = TRANSPARENCY_NUM_SEQ_2,
																		Rotation = 0,
																	}),
																},
															}),
														},
													}),

													scope:New("ImageLabel")({
														Name = "Avatar",
														Position = UDim2.fromOffset(2, 0),
														Size = UDim2.fromOffset(LB_ROW_HEIGHT, LB_ROW_HEIGHT),
														BackgroundTransparency = 1,
														Image = playerAvatar,
														ZIndex = 2,
													}),

													scope:New("TextLabel")({
														Name = "Username",
														Position = UDim2.new(0, LB_ROW_HEIGHT + 8, 0.5, 0),
														AnchorPoint = Vector2.new(0, 0.5),
														Size = UDim2.new(LB_USERNAME_END, -(LB_ROW_HEIGHT + 12), 0, 18),
														BackgroundTransparency = 1,
														Text = playerDisplayName,
														TextColor3 = LB_LOCAL_COLOR,
														TextScaled = true,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Left,
														TextYAlignment = Enum.TextYAlignment.Center,
														ZIndex = 2,

														[Fusion.Children] = {
															scope:New("UITextSizeConstraint")({
																MaxTextSize = 14,
																MinTextSize = 9,
															}),
														},
													}),

													scope:New("TextLabel")({
														Name = "Kills",
														Position = UDim2.fromScale(LB_STAT_START, 0.5),
														AnchorPoint = Vector2.new(0, 0.5),
														Size = UDim2.new(LB_STAT_WIDTH, 0, 0, 16),
														BackgroundTransparency = 1,
														Text = tostring(stats.Kills),
														TextColor3 = LB_LOCAL_COLOR,
														TextSize = 13,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Center,
														ZIndex = 2,
													}),

													scope:New("TextLabel")({
														Name = "Damage",
														Position = UDim2.fromScale(LB_STAT_START + LB_STAT_WIDTH, 0.5),
														AnchorPoint = Vector2.new(0, 0.5),
														Size = UDim2.new(LB_STAT_WIDTH, 0, 0, 16),
														BackgroundTransparency = 1,
														Text = tostring(stats.Damage),
														TextColor3 = LB_LOCAL_COLOR,
														TextSize = 13,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Center,
														ZIndex = 2,
													}),

													scope:New("TextLabel")({
														Name = "Heals",
														Position = UDim2.fromScale(LB_STAT_START + LB_STAT_WIDTH * 2, 0.5),
														AnchorPoint = Vector2.new(0, 0.5),
														Size = UDim2.new(LB_STAT_WIDTH, 0, 0, 16),
														BackgroundTransparency = 1,
														Text = tostring(stats.Heals),
														TextColor3 = LB_LOCAL_COLOR,
														TextSize = 13,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Center,
														ZIndex = 2,
													}),

													scope:New("TextLabel")({
														Name = "Captures",
														Position = UDim2.fromScale(LB_STAT_START + LB_STAT_WIDTH * 3, 0.5),
														AnchorPoint = Vector2.new(0, 0.5),
														Size = UDim2.new(LB_STAT_WIDTH, 0, 0, 16),
														BackgroundTransparency = 1,
														Text = tostring(stats.Captures),
														TextColor3 = LB_LOCAL_COLOR,
														TextSize = 13,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Center,
														ZIndex = 2,
													}),
												},
											}),
										},
									}),
								},
							}),

							scope:New("Frame")({
								Name = "BottomFade",
								Size = UDim2.new(1, 0, 0, 60),
								Position = UDim2.fromScale(0, 1),
								AnchorPoint = Vector2.new(0, 1),
								BackgroundColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								ZIndex = 4,

								[Fusion.Children] = {
									scope:New("UIGradient")({
										Rotation = 90,
										Transparency = TRANSPARENCY_NUM_SEQ,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "TextContainer",
								Size = UDim2.new(1, 0, 0, 48),
								Position = UDim2.fromScale(0, 1),
								AnchorPoint = Vector2.new(0, 1),
								BackgroundTransparency = 1,
								ZIndex = 5,

								[Fusion.Children] = {
									scope:New("TextLabel")({
										Name = "CardName",
										Size = UDim2.new(1, -20, 0, 22),
										Position = UDim2.fromOffset(10, 4),
										BackgroundTransparency = 1,
										Text = string.upper(props.CardName),
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextSize = 15,
										Font = Enum.Font.GothamBold,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Center,
										TextTruncate = Enum.TextTruncate.AtEnd,

										[Fusion.Children] = {
											scope:New("UIStroke")({
												Color = Color3.fromRGB(0, 0, 0),
												Thickness = 1.2,
												Transparency = 0.4,
											}),
										},
									}),

									scope:New("TextLabel")({
										Name = "Price",
										Size = UDim2.new(1, -20, 0, 18),
										Position = UDim2.fromOffset(10, 26),
										BackgroundTransparency = 1,
										Text = priceText,
										TextColor3 = priceColor,
										TextSize = 14,
										Font = Enum.Font.GothamBold,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Center,

										[Fusion.Children] = {
											scope:New("UIStroke")({
												Color = Color3.fromRGB(0, 0, 0),
												Thickness = 1.2,
												Transparency = 0.4,
											}),
										},
									}),

									if props.IsAnimated then scope:New("Frame")({
										Name = "AnimatedBadge",
										Size = UDim2.fromOffset(65, 18),
										Position = UDim2.new(1, -8, 0, 4),
										AnchorPoint = Vector2.new(1, 0),
										BackgroundColor3 = Color3.fromRGB(180, 100, 220),
										BorderSizePixel = 0,
										ZIndex = 6,

										[Fusion.Children] = {
											scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
											scope:New("UIGradient")({
												Color = COLOR_CLR_SEQ,
												Rotation = 90,
											}),
											scope:New("TextLabel")({
												Size = UDim2.fromScale(1, 1),
												BackgroundTransparency = 1,
												Text = "ANIMATED",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextSize = 9,
												Font = Enum.Font.GothamBold,
											}),
										},
									}) else nil,
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
								[Fusion.OnEvent("Activated")] = props.OnClick,
							}),
						},
					}),
				},
			}),
		},
	})
end

return PlayerCardCard
