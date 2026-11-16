--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)
local EconomyConfig = require(MainModule.Shared.Config.Economy.EconomyConfig)
local FormatUtils = require(MainModule.Shared.Utils.Text.FormatUtils)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type CreditsStripProps = {
	Width: number,
	Alpha: any,
	Balance: any,
	Earned: any,
	Reward: any,
	Purchasable: any,
	OnBalanceClick: (() -> ())?,
}

local STRIP_HEIGHT = 60
local STRIP_CORNER = 8
local PROGRESS_WIDTH = 240
local CREDITS_ICON = "rbxassetid://0"
local TIMES = "\u{00D7}"
local DOT = "\u{00B7}"

local LINE_COLOR = Color3.fromRGB(110, 110, 110)
local LABEL_COLOR = Color3.fromRGB(170, 170, 178)
local VALUE_COLOR = Color3.fromRGB(255, 255, 254)
local TICK_COLOR = Color3.fromRGB(150, 150, 158)
local CR_COLOR = Color3.fromRGB(130, 130, 135)
local FILL_COLOR = Color3.fromRGB(240, 240, 240)

local WEIGHTS = EconomyConfig.WEIGHTS
local RULES = EconomyConfig.REWARD_RULES

local function getProgress(score: number): number
	return math.clamp((score - WEIGHTS.MIN_WEIGHTED_SCORE) / (WEIGHTS.FULL_WEIGHTED_SCORE - WEIGHTS.MIN_WEIGHTED_SCORE), 0, 1)
end

local function getPerformance(score: number): number
	return RULES.MIN_PERFORMANCE_SHARE + (1 - RULES.MIN_PERFORMANCE_SHARE) * getProgress(score)
end

local function formatMultiplier(value: number): string
	return string.format("%s%.2f", TIMES, value)
end

local function formatNumber(value: number): string
	return FormatUtils.formatNumberWithCommas(math.round(value))
end

local function CreditsStrip(scope: FusionScope, props: CreditsStripProps): Frame
	local alpha = props.Alpha
	local reward = props.Reward

	local function fade(base: number): any
		return scope:Computed(function(use: FusionUseFn)
			return base + (1 - use(alpha)) * (1 - base)
		end)
	end

	local function fromReward(format: (data: any) -> string, fallback: string): any
		return scope:Computed(function(use: FusionUseFn)
			local data = use(reward)
			return if data then format(data) else fallback
		end)
	end

	local showDetails = scope:Computed(function(use: FusionUseFn)
		local data = use(reward)
		return not (data and data.isPrivate)
	end)

	local progressRatio = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			local data = use(reward)
			return if data then getProgress(data.score) else 0
		end),
		18,
		1
	)

	local function createText(name: string, text: any, font: Enum.Font, size: number, color: Color3, order: number, extra: { [string]: any }?): TextLabel
		local labelProps: { [string]: any } = {
			Name = name,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Text = text,
			Font = font,
			TextSize = size,
			TextColor3 = color,
			TextTransparency = fade(0),
			LayoutOrder = order,
			ZIndex = 2,
		}
		for key, value in extra or {} do
			labelProps[key] = value
		end
		return scope:New("TextLabel")(labelProps)
	end

	local function createDivider(name: string, order: number, height: number, visible: any?): Frame
		return scope:New("Frame")({
			Name = name,
			Size = UDim2.new(0, 1, height, 0),
			BackgroundColor3 = LINE_COLOR,
			BackgroundTransparency = fade(0.4),
			BorderSizePixel = 0,
			LayoutOrder = order,
			Visible = visible,
		})
	end

	local function createRewardItem(name: string, labelText: any, valueText: any, order: number, visible: any?): Frame
		return scope:New("Frame")({
			Name = name,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Visible = visible,

			[Fusion.Children] = {
				scope:New("UIListLayout")({
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 2),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				createText("Label", labelText, Theme.Text.Semibold, 11, LABEL_COLOR, 1),
				createText("Score", valueText, Theme.Text.Bold, 14, VALUE_COLOR, 2),
			},
		})
	end

	local creditsPill = scope:New("Frame")({
		Name = "CreditsPill",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = 2,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			scope:New("ImageLabel")({
				Name = "Icon",
				Size = UDim2.fromOffset(34, 34),
				BackgroundTransparency = 1,
				Image = CREDITS_ICON,
				ImageTransparency = fade(0),
				ScaleType = Enum.ScaleType.Fit,
				LayoutOrder = 1,
				ZIndex = 2,
			}),
			scope:New("Frame")({
				Name = "Holder",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				LayoutOrder = 2,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 2),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					createText("Label", "CREDITS EARNED", Theme.Text.Bold, 11, LABEL_COLOR, 1, { TextXAlignment = Enum.TextXAlignment.Left }),
					scope:New("Frame")({
						Name = "Pill",
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						LayoutOrder = 2,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 6),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							createText(
								"Amount",
								scope:Computed(function(use: FusionUseFn)
									return "+" .. formatNumber(use(props.Earned))
								end),
								Theme.Text.Bold,
								24,
								VALUE_COLOR,
								2,
								{ TextXAlignment = Enum.TextXAlignment.Left }
							),
							createText("CR", "CR", Theme.Text.Bold, 11, CR_COLOR, 3),
						},
					}),
				},
			}),
		},
	})

	local rewards = scope:New("Frame")({
		Name = "Rewards",
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		LayoutOrder = 3,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 16),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			scope:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Fill }),
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 6) }),

			createRewardItem(
				"Map",
				fromReward(function(data: any)
					return string.upper(data.mapName)
				end, "MAP"),
				fromReward(function(data: any)
					return formatNumber(data.mapReward)
				end, "-"),
				1
			),
			createDivider("Divider1", 2, 0.35),
			createRewardItem(
				"Outcome",
				fromReward(function(data: any)
					return if data.isWinner then "WIN" else "LOSS"
				end, "RESULT"),
				fromReward(function(data: any)
					return formatMultiplier(if data.isWinner then 1 else RULES.LOSS_SHARE)
				end, "-"),
				3
			),
			createDivider("Divider2", 4, 0.35, showDetails),
			createRewardItem(
				"Playtime",
				"PLAYTIME",
				fromReward(function(data: any)
					return string.format("%d%%", math.round(data.attendance * 100))
				end, "-"),
				5,
				showDetails
			),
			createDivider("Divider3", 6, 0.35, showDetails),
			createRewardItem(
				"Score",
				"PERFORMANCE",
				fromReward(function(data: any)
					return formatMultiplier(getPerformance(data.score))
				end, "-"),
				7,
				showDetails
			),
		},
	})

	local progress = scope:New("Frame")({
		Name = "Progress",
		Size = UDim2.fromOffset(PROGRESS_WIDTH, 44),
		BackgroundTransparency = 1,
		LayoutOrder = 1,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			scope:New("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				LayoutOrder = 1,

				[Fusion.Children] = {
					createText("Today", "POINTS", Theme.Text.Bold, 11, VALUE_COLOR, 1, {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					createText(
						"DailyValue",
						fromReward(function(data: any)
							return `<font color="#FFFFFF">{formatNumber(data.score)}</font> / {WEIGHTS.FULL_WEIGHTED_SCORE}`
						end, `- / {WEIGHTS.FULL_WEIGHTED_SCORE}`),
						Theme.Text.Bold,
						11,
						LABEL_COLOR,
						2,
						{
							RichText = true,
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.fromScale(1, 0.5),
							TextXAlignment = Enum.TextXAlignment.Right,
						}
					),
				},
			}),
			scope:New("Frame")({
				Name = "Bar",
				Size = UDim2.new(1, 0, 0, 8),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = fade(0.5),
				BorderSizePixel = 0,
				LayoutOrder = 2,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
					scope:New("UIStroke")({
						Color = LINE_COLOR,
						Thickness = 1,
						Transparency = fade(0.3),
					}),
					scope:New("Frame")({
						Name = "Fill",
						Size = scope:Computed(function(use: FusionUseFn)
							return UDim2.fromScale(use(progressRatio), 1)
						end),
						BackgroundColor3 = FILL_COLOR,
						BackgroundTransparency = fade(0),
						BorderSizePixel = 0,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
						},
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Ticks",
				Size = UDim2.new(1, 0, 0, 12),
				BackgroundTransparency = 1,
				LayoutOrder = 3,

				[Fusion.Children] = {
					createText("Min", `{WEIGHTS.MIN_WEIGHTED_SCORE} {DOT} {formatMultiplier(RULES.MIN_PERFORMANCE_SHARE)}`, Theme.Text.Bold, 9, TICK_COLOR, 1, {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					createText("Max", `{formatMultiplier(1)} {DOT} {WEIGHTS.FULL_WEIGHTED_SCORE}`, Theme.Text.Bold, 9, TICK_COLOR, 2, {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						TextXAlignment = Enum.TextXAlignment.Right,
					}),
				},
			}),
		},
	})

	local extra = scope:New("Frame")({
		Name = "Extra",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Visible = showDetails,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			progress,
			createDivider("Divider1", 2, 0.7),
		},
	})

	local balanceHover = scope:Value(false)

	local balance = scope:New("TextButton")({
		Name = "Balance",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
			if use(props.Purchasable) and use(balanceHover) then
				return 1 - 0.1 * use(alpha)
			end
			return 1
		end),
		Text = "",
		AutoButtonColor = false,
		Interactable = props.Purchasable,
		LayoutOrder = 5,

		[Fusion.OnEvent("MouseEnter")] = function()
			balanceHover:set(true)
		end,
		[Fusion.OnEvent("MouseLeave")] = function()
			balanceHover:set(false)
		end,
		[Fusion.OnEvent("Activated")] = function()
			if props.OnBalanceClick and Fusion.peek(props.Purchasable) then
				props.OnBalanceClick()
			end
		end,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("UIListLayout")({
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			createText("Label", "BALANCE", Theme.Text.Bold, 11, LABEL_COLOR, 1, { TextXAlignment = Enum.TextXAlignment.Right }),
			scope:New("Frame")({
				Name = "Row",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				LayoutOrder = 2,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					scope:New("ImageLabel")({
						Name = "Icon",
						Size = UDim2.fromOffset(20, 20),
						BackgroundTransparency = 1,
						Image = CREDITS_ICON,
						ImageTransparency = fade(0),
						ScaleType = Enum.ScaleType.Fit,
						LayoutOrder = 1,
						ZIndex = 2,
					}),
					createText(
						"Amount",
						scope:Computed(function(use: FusionUseFn)
							return formatNumber(use(props.Balance))
						end),
						Theme.Text.Bold,
						24,
						VALUE_COLOR,
						2,
						{ TextXAlignment = Enum.TextXAlignment.Right }
					),
				},
			}),
		},
	})

	return scope:New("Frame")({
		Name = "Credits",
		Size = UDim2.fromOffset(props.Width, STRIP_HEIGHT),
		BackgroundTransparency = 1,
		LayoutOrder = 3,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "CompactMVPStrip",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Chat.Window.Background,
				BackgroundTransparency = fade(Theme.Chat.Window.BackgroundTransparency),
				BorderSizePixel = 0,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, STRIP_CORNER) }),
					scope:New("UIStroke")({
						Color = LINE_COLOR,
						Thickness = 1,
						Transparency = fade(0.3),
					}),
					Shadow(scope, {
						Size = UDim2.new(1, 8, 1, 8),
						Position = UDim2.new(0.5, 0, 0.5, 1),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Spread = 0,
						Transparency = fade(0.7),
						ZIndex = 0,
					}),
					scope:New("Frame")({
						Name = "SlotsRow",
						Size = UDim2.new(1, -24, 1, 0),
						Position = UDim2.fromOffset(12, 0),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 14),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							creditsPill,
							createDivider("Divider1", 2, 0.7),
							rewards,
							extra,
							balance,
						},
					}),
				},
			}),
		},
	})
end

return CreditsStrip
