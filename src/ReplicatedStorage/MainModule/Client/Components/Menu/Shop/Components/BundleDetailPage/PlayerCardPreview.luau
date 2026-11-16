--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)

local BundleTypes = require(script.Parent.Types)
local Constants = require(script.Parent.Constants)
local Utils = require(script.Parent.Utils)
local CardBackground = require(script.Parent.CardBackground)

type FusionScope = BundleTypes.FusionScope
type FusionUseFn = BundleTypes.FusionUseFn
type PlayerCardPreviewProps = BundleTypes.PlayerCardPreviewProps

local GRADIENT_CONFIG_NUM_SEQ_2 =
	NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0), NumberSequenceKeypoint.new(1, 0.7) })
local GRADIENT_CONFIG_NUM_SEQ = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0), NumberSequenceKeypoint.new(1, 1) })

local sessionRandomStats = Utils.generateRandomStats()

local function createKillCard(scope: FusionScope, previewImageId: any, previewIsAnimated: any, playerName: string, playerAvatar: string): Frame
	return scope:New("Frame")({
		Name = "KillCardSection",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			scope:New("TextLabel")({
				Name = "SectionLabel",
				Size = UDim2.new(1, 0, 0, 14),
				BackgroundTransparency = 1,
				Text = "KILL CARD",
				TextColor3 = Color3.fromRGB(155, 155, 165),
				TextSize = 10,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
			}),

			scope:New("CanvasGroup")({
				Name = "KillCard",
				Size = UDim2.new(1, 0, 0, Constants.KILL_CARD_HEIGHT),
				BackgroundColor3 = Constants.KILL_CARD_BG,
				BackgroundTransparency = 0.15,
				LayoutOrder = 2,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
					scope:New("UIStroke")({
						Color = Constants.KILL_CARD_BORDER,
						Thickness = 1,
						Transparency = 0.55,
					}),

					CardBackground(scope, {
						ImageId = previewImageId,
						IsAnimated = previewIsAnimated,
						Size = UDim2.fromScale(1, 1),
						Transparency = Constants.BANNER_TRANSPARENCY,
						GradientConfig = GRADIENT_CONFIG_NUM_SEQ_2,
						CornerRadius = 4,
					}),

					scope:New("ImageLabel")({
						Name = "Avatar",
						Size = UDim2.fromOffset(Constants.KILL_CARD_AVATAR_SIZE, Constants.KILL_CARD_AVATAR_SIZE),
						Position = UDim2.fromOffset(0, 0),
						BackgroundTransparency = 1,
						Image = playerAvatar,
						ZIndex = 5,
						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
						},
					}),

					scope:New("Frame")({
						Name = "LeftInfo",
						Size = UDim2.fromOffset(120, 44),
						Position = UDim2.fromOffset(Constants.KILL_CARD_AVATAR_SIZE + 10, 10),
						BackgroundTransparency = 1,
						ZIndex = 5,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								VerticalAlignment = Enum.VerticalAlignment.Top,
								Padding = UDim.new(0, -2),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							scope:New("TextLabel")({
								Name = "PlayerName",
								Size = UDim2.new(1, 0, 0, 30),
								BackgroundTransparency = 1,
								Text = playerName,
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 26,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
								LayoutOrder = 1,
							}),

							scope:New("TextLabel")({
								Name = "HP",
								Size = UDim2.new(1, 0, 0, 16),
								BackgroundTransparency = 1,
								Text = "100 HP",
								TextColor3 = Color3.fromRGB(180, 180, 185),
								TextSize = 14,
								Font = Theme.Text.Semibold,
								TextXAlignment = Enum.TextXAlignment.Left,
								LayoutOrder = 2,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "RightInfo",
						Size = UDim2.fromOffset(90, 40),
						Position = UDim2.new(1, -8, 1, -8),
						AnchorPoint = Vector2.one,
						BackgroundTransparency = 1,
						ZIndex = 5,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								VerticalAlignment = Enum.VerticalAlignment.Bottom,
								HorizontalAlignment = Enum.HorizontalAlignment.Right,
								Padding = UDim.new(0, 0),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							scope:New("TextLabel")({
								Name = "GunName",
								Size = UDim2.new(1, 0, 0, 22),
								BackgroundTransparency = 1,
								Text = "H-82",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 18,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Right,
								LayoutOrder = 1,
							}),

							scope:New("TextLabel")({
								Name = "Range",
								Size = UDim2.new(1, 0, 0, 16),
								BackgroundTransparency = 1,
								Text = "100 STUDS",
								TextColor3 = Color3.fromRGB(140, 140, 145),
								TextSize = 12,
								Font = Theme.Text.Semibold,
								TextXAlignment = Enum.TextXAlignment.Right,
								LayoutOrder = 2,
							}),
						},
					}),
				},
			}),
		},
	})
end

local function createLeaderboardRow(scope: FusionScope, previewImageId: any, previewIsAnimated: any, playerDisplayName: string, playerAvatar: string): Frame
	return scope:New("Frame")({
		Name = "LeaderboardSection",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			scope:New("TextLabel")({
				Name = "SectionLabel",
				Size = UDim2.new(1, 0, 0, 14),
				BackgroundTransparency = 1,
				Text = "LEADERBOARD",
				TextColor3 = Color3.fromRGB(155, 155, 165),
				TextSize = 10,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
			}),

			scope:New("Frame")({
				Name = "ColumnHeaders",
				Size = UDim2.new(1, 0, 0, 12),
				BackgroundTransparency = 1,
				LayoutOrder = 2,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "KillsHeader",
						Position = UDim2.fromScale(Constants.LB_STAT_START, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.fromScale(Constants.LB_STAT_WIDTH, 1),
						BackgroundTransparency = 1,
						Text = "K",
						TextColor3 = Color3.fromRGB(155, 155, 165),
						TextSize = 9,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),

					scope:New("TextLabel")({
						Name = "DamageHeader",
						Position = UDim2.fromScale(Constants.LB_STAT_START + Constants.LB_STAT_WIDTH, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.fromScale(Constants.LB_STAT_WIDTH, 1),
						BackgroundTransparency = 1,
						Text = "DMG",
						TextColor3 = Color3.fromRGB(155, 155, 165),
						TextSize = 9,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),

					scope:New("TextLabel")({
						Name = "HealsHeader",
						Position = UDim2.fromScale(Constants.LB_STAT_START + Constants.LB_STAT_WIDTH * 2, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.fromScale(Constants.LB_STAT_WIDTH, 1),
						BackgroundTransparency = 1,
						Text = "HEALS",
						TextColor3 = Color3.fromRGB(155, 155, 165),
						TextSize = 9,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),

					scope:New("TextLabel")({
						Name = "CapsHeader",
						Position = UDim2.fromScale(Constants.LB_STAT_START + Constants.LB_STAT_WIDTH * 3, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.fromScale(Constants.LB_STAT_WIDTH, 1),
						BackgroundTransparency = 1,
						Text = "CAPS",
						TextColor3 = Color3.fromRGB(155, 155, 165),
						TextSize = 9,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "PlayerRow",
				Size = UDim2.new(1, 0, 0, Constants.LB_ROW_HEIGHT),
				BackgroundTransparency = 1,
				LayoutOrder = 3,

				[Fusion.Children] = {
					CardBackground(scope, {
						ImageId = previewImageId,
						IsAnimated = previewIsAnimated,
						Size = UDim2.fromScale(1, 1),
						Transparency = 0.5,
						GradientConfig = GRADIENT_CONFIG_NUM_SEQ,
						CornerRadius = Constants.LB_CORNER_RADIUS,
					}),

					scope:New("ImageLabel")({
						Name = "Thumbnail",
						Position = UDim2.fromOffset(0, 0),
						Size = UDim2.fromOffset(Constants.LB_ROW_HEIGHT, Constants.LB_ROW_HEIGHT),
						BackgroundTransparency = 1,
						Image = playerAvatar,
						ZIndex = 2,
					}),

					scope:New("TextLabel")({
						Name = "Username",
						Position = UDim2.new(0, Constants.LB_ROW_HEIGHT + 6, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.new(Constants.LB_USERNAME_END, -(Constants.LB_ROW_HEIGHT + 12), 0, 16),
						BackgroundTransparency = 1,
						Text = playerDisplayName,
						TextColor3 = Constants.LB_LOCAL_COLOR,
						TextScaled = true,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
						ZIndex = 2,

						[Fusion.Children] = {
							scope:New("UITextSizeConstraint")({
								MaxTextSize = 14,
								MinTextSize = 8,
							}),
						},
					}),

					scope:New("TextLabel")({
						Name = "Kills",
						Position = UDim2.fromScale(Constants.LB_STAT_START, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.new(Constants.LB_STAT_WIDTH, 0, 0, 14),
						BackgroundTransparency = 1,
						Text = tostring(sessionRandomStats.Kills),
						TextColor3 = Constants.LB_LOCAL_COLOR,
						TextSize = 13,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						ZIndex = 2,
					}),

					scope:New("TextLabel")({
						Name = "Damage",
						Position = UDim2.fromScale(Constants.LB_STAT_START + Constants.LB_STAT_WIDTH, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.new(Constants.LB_STAT_WIDTH, 0, 0, 14),
						BackgroundTransparency = 1,
						Text = tostring(sessionRandomStats.Damage),
						TextColor3 = Constants.LB_LOCAL_COLOR,
						TextSize = 13,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						ZIndex = 2,
					}),

					scope:New("TextLabel")({
						Name = "Heals",
						Position = UDim2.fromScale(Constants.LB_STAT_START + Constants.LB_STAT_WIDTH * 2, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.new(Constants.LB_STAT_WIDTH, 0, 0, 14),
						BackgroundTransparency = 1,
						Text = tostring(sessionRandomStats.Heals),
						TextColor3 = Constants.LB_LOCAL_COLOR,
						TextSize = 13,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						ZIndex = 2,
					}),

					scope:New("TextLabel")({
						Name = "Captures",
						Position = UDim2.fromScale(Constants.LB_STAT_START + Constants.LB_STAT_WIDTH * 3, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.new(Constants.LB_STAT_WIDTH, 0, 0, 14),
						BackgroundTransparency = 1,
						Text = tostring(sessionRandomStats.Captures),
						TextColor3 = Constants.LB_LOCAL_COLOR,
						TextSize = 13,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						ZIndex = 2,
					}),
				},
			}),
		},
	})
end

local function PlayerCardPreview(scope: FusionScope, props: PlayerCardPreviewProps): Frame
	local selectedItem = props.SelectedItem
	local previewImageId = props.PreviewImageId
	local previewIsAnimated = props.PreviewIsAnimated

	local localPlayer = Players.LocalPlayer
	local playerName = string.upper(localPlayer.DisplayName)
	local playerDisplayName = localPlayer.DisplayName
	local playerAvatar = Utils.getPlayerAvatar(localPlayer.UserId)

	return scope:New("Frame")({
		Name = "PlayerCardPreview",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Visible = scope:Computed(function(use: FusionUseFn)
			local item = use(selectedItem)
			return item ~= nil and item.type == "PlayerCard"
		end),

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 16),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			createKillCard(scope, previewImageId, previewIsAnimated, playerName, playerAvatar),
			createLeaderboardRow(scope, previewImageId, previewIsAnimated, playerDisplayName, playerAvatar),
		},
	})
end

return PlayerCardPreview
