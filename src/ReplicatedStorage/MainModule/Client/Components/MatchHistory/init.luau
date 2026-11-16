--!native
--!optimize 2

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionValue<T> = Types.FusionValue<T>
type FusionUseFn = Types.FusionUseFn

export type MatchHistoryProps = {
	Visible: FusionValue<boolean>,
	OnClose: (() -> ())?,
	HistoryData: FusionValue<{ any }>,
	Loading: FusionValue<boolean>,
}

local MODAL_WIDTH = 500
local HEADER_HEIGHT = 44
local CONTENT_PADDING = 16
local ICON_HISTORY = "rbxassetid://126942755236234"

local function formatTime(timestamp: number): string
	local success, result = pcall(os.date, "%b %d, %H:%M", timestamp)
	return if success then result else "Unknown Time"
end

local function formatDuration(seconds: number): string
	local mins = seconds // 60
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", mins, secs)
end

local function MatchCard(scope: FusionScope, record: any): Frame
	if record.IsAiMode ~= nil then
		local isAi = record.IsAiMode
		local preset = record.PresetId or "CUSTOM"
		local difficulty = record.Difficulty or "NORMAL"
		local elapsedTime = record.ElapsedTime or 0
		local playerKills = record.PlayerKills or 0
		local botKills = record.BotKills or 0
		local accuracy = record.Accuracy or 0
		local gunName = record.GunName or "H-82"
		local timestamp = record.Timestamp or 0

		local titleText = if isAi then "BOT AIM TRAINER" else "ZOMBIE AIM TRAINER"
		local subText = if isAi then `DIFFICULTY: {difficulty}` else `PRESET: {preset}`

		local scoreText = ""
		local resultText = ""
		local resultColor = Theme.Foreground.Primary

		if isAi then
			scoreText = `{playerKills} - {botKills}`
			local localName = localPlayer and localPlayer.Name or ""
			local didWin = record.WinnerName == localName
			
			if record.LeftMatch then
				resultText = "LEFT MATCH"
				resultColor = Theme.Colors.Destructive
			else
				resultText = if didWin then "VICTORY" else "DEFEAT"
				resultColor = if didWin then Theme.Colors.Success else Theme.Colors.Destructive
			end
		else
			scoreText = `{playerKills} Kills`
			resultText = `{formatDuration(elapsedTime)} Survived`
			resultColor = Theme.Colors.Success
		end

		local accuracyText = string.format("Accuracy: %.2f%%", accuracy * 100)

		return scope:New("Frame")({
			Name = "MatchCard",
			Size = UDim2.new(1, 0, 0, 96),
			BackgroundColor3 = Theme.Colors.Black[800],
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			[Fusion.Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
					PaddingTop = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 8),
				}),

				scope:New("Frame")({
					Name = "MetaRow",
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					[Fusion.Children] = {
						scope:New("TextLabel")({
							Name = "ModeLabel",
							Size = UDim2.fromScale(0.68, 1),
							BackgroundTransparency = 1,
							Text = `{titleText}  •  {subText}  •  {gunName}`,
							TextColor3 = Theme.Foreground.Muted,
							TextSize = Theme.Text.Small,
							Font = Theme.Text.Bold,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Center,
						}),
						scope:New("TextLabel")({
							Name = "TimeLabel",
							Size = UDim2.fromScale(0.32, 1),
							Position = UDim2.fromScale(0.68, 0),
							BackgroundTransparency = 1,
							Text = formatTime(timestamp),
							TextColor3 = Theme.Foreground.Muted,
							TextSize = Theme.Text.Small,
							Font = Theme.Text.Regular,
							TextXAlignment = Enum.TextXAlignment.Right,
							TextYAlignment = Enum.TextYAlignment.Center,
						}),
					},
				}),

				scope:New("Frame")({
					Name = "Divider",
					Size = UDim2.new(1, 0, 0, 1),
					Position = UDim2.fromOffset(0, 24),
					BackgroundColor3 = Theme.Border.Subtle,
					BackgroundTransparency = 0.5,
					BorderSizePixel = 0,
				}),

				scope:New("Frame")({
					Name = "ContentPanel",
					Size = UDim2.new(1, 0, 0, 52),
					Position = UDim2.fromOffset(0, 28),
					BackgroundTransparency = 1,
					[Fusion.Children] = {
						scope:New("Frame")({
							Name = "ScoreFrame",
							Size = UDim2.fromScale(0.6, 1),
							BackgroundTransparency = 1,
							[Fusion.Children] = {
								scope:New("TextLabel")({
									Size = UDim2.fromScale(1, 0.5),
									BackgroundTransparency = 1,
									Text = scoreText,
									TextColor3 = Theme.Foreground.Primary,
									Font = Theme.Text.Bold,
									TextSize = Theme.Text.Large,
									TextXAlignment = Enum.TextXAlignment.Left,
									TextYAlignment = Enum.TextYAlignment.Center,
								}),
								scope:New("TextLabel")({
									Size = UDim2.fromScale(1, 0.5),
									Position = UDim2.fromScale(0, 0.5),
									BackgroundTransparency = 1,
									Text = accuracyText,
									TextColor3 = Theme.Foreground.Muted,
									Font = Theme.Text.Regular,
									TextSize = Theme.Text.Small,
									TextXAlignment = Enum.TextXAlignment.Left,
									TextYAlignment = Enum.TextYAlignment.Center,
								}),
							},
						}),
						scope:New("Frame")({
							Name = "ResultFrame",
							Size = UDim2.fromScale(0.4, 1),
							Position = UDim2.fromScale(0.6, 0),
							BackgroundTransparency = 1,
							[Fusion.Children] = {
								scope:New("TextLabel")({
									Size = UDim2.fromScale(1, 1),
									BackgroundTransparency = 1,
									Text = resultText,
									TextColor3 = resultColor,
									Font = Theme.Text.Black,
									TextSize = Theme.Text.Medium,
									TextXAlignment = Enum.TextXAlignment.Right,
									TextYAlignment = Enum.TextYAlignment.Center,
								}),
							},
						}),
					},
				}),
			},
		})
	end

	local vultarianId = record.VultarianId or 0
	local hostileId = record.HostileId or 0
	local winnerId = record.WinnerId or 0
	local winnerName = record.WinnerName or "Tie"

	local winnerText = ""
	local winnerColor = Theme.Foreground.Muted
	if winnerName == "Tie" or winnerId == 0 then
		winnerText = "DRAW"
		winnerColor = Theme.Colors.SilverBright
	elseif winnerId == vultarianId then
		winnerText = record.VultarianName:upper() .. " WIN"
		winnerColor = Color3.fromRGB(255, 70, 70)
	elseif winnerId == hostileId then
		winnerText = record.HostileName:upper() .. " WIN"
		winnerColor = Color3.fromRGB(70, 150, 255)
	else
		winnerText = winnerName:upper() .. " WIN"
		winnerColor = Theme.Colors.White
	end

	local scoreText = "VS"
	if record.VultarianWins ~= nil and record.HostileWins ~= nil then
		scoreText = tostring(record.VultarianWins) .. " - " .. tostring(record.HostileWins)
	else
		if winnerName == "Tie" or winnerId == 0 then
			scoreText = "0 - 0"
		elseif winnerId == vultarianId then
			scoreText = "1 - 0"
		elseif winnerId == hostileId then
			scoreText = "0 - 1"
		end
	end

	return scope:New("Frame")({
		Name = "MatchCard",
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = Theme.Colors.Black[800],
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			}),

			scope:New("Frame")({
				Name = "MetaRow",
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "MapLabel",
						Size = UDim2.fromScale(0.68, 1),
						BackgroundTransparency = 1,
						Text = record.MapName
							.. "  •  "
							.. record.GunName
							.. "  •  "
							.. tostring(record.Rounds)
							.. " Rounds  •  "
							.. record.HealthOption
							.. " HP",
						TextColor3 = Theme.Foreground.Muted,
						TextSize = Theme.Text.Small,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
					scope:New("TextLabel")({
						Name = "TimeLabel",
						Size = UDim2.fromScale(0.32, 1),
						Position = UDim2.fromScale(0.68, 0),
						BackgroundTransparency = 1,
						Text = formatTime(record.Timestamp),
						TextColor3 = Theme.Foreground.Muted,
						TextSize = Theme.Text.Small,
						Font = Theme.Text.Regular,
						TextXAlignment = Enum.TextXAlignment.Right,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "Divider",
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.fromOffset(0, 24),
				BackgroundColor3 = Theme.Border.Subtle,
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
			}),

			scope:New("Frame")({
				Name = "VSPanel",
				Size = UDim2.new(1, 0, 0, 52),
				Position = UDim2.fromOffset(0, 28),
				BackgroundTransparency = 1,
				[Fusion.Children] = {

					scope:New("Frame")({
						Name = "VultarianPlayer",
						Size = UDim2.fromScale(0.4, 1),
						BackgroundTransparency = 1,
						[Fusion.Children] = {
							scope:New("ImageLabel")({
								Name = "Avatar",
								Size = UDim2.fromOffset(36, 36),
								Position = UDim2.fromScale(0, 0.5),
								AnchorPoint = Vector2.new(0, 0.5),
								BackgroundTransparency = 1,
								Image = if vultarianId > 0
									then "rbxthumb://type=AvatarHeadShot&id=" .. tostring(vultarianId) .. "&w=150&h=150"
									else "rbxassetid://0",
								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = Theme.Radius.Full }),
									scope:New("UIStroke")({
										Color = Color3.fromRGB(255, 50, 50),
										Thickness = 1.5,
									}),
								},
							}),
							scope:New("TextLabel")({
								Name = "Name",
								Size = UDim2.new(1, -44, 1, 0),
								Position = UDim2.fromOffset(44, 0),
								BackgroundTransparency = 1,
								Text = record.VultarianName,
								TextColor3 = Theme.Foreground.Primary,
								TextSize = Theme.Text.Medium,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Center,
								TextTruncate = Enum.TextTruncate.AtEnd,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "VSFrame",
						Size = UDim2.fromScale(0.2, 1),
						Position = UDim2.fromScale(0.4, 0),
						BackgroundTransparency = 1,
						[Fusion.Children] = {
							scope:New("TextLabel")({
								Name = "VS",
								Size = UDim2.fromScale(1, 0.5),
								BackgroundTransparency = 1,
								Text = scoreText,
								TextColor3 = Theme.Colors.SilverBright,
								TextSize = Theme.Text.Medium,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Center,
								TextYAlignment = Enum.TextYAlignment.Bottom,
							}),
							scope:New("TextLabel")({
								Name = "Result",
								Size = UDim2.fromScale(1, 0.5),
								Position = UDim2.fromScale(0, 0.5),
								BackgroundTransparency = 1,
								Text = winnerText,
								TextColor3 = winnerColor,
								TextSize = Theme.Text.XSmall,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Center,
								TextYAlignment = Enum.TextYAlignment.Center,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "HostilePlayer",
						Size = UDim2.fromScale(0.4, 1),
						Position = UDim2.fromScale(0.6, 0),
						BackgroundTransparency = 1,
						[Fusion.Children] = {
							scope:New("ImageLabel")({
								Name = "Avatar",
								Size = UDim2.fromOffset(36, 36),
								Position = UDim2.fromScale(1, 0.5),
								AnchorPoint = Vector2.new(1, 0.5),
								BackgroundTransparency = 1,
								Image = if hostileId > 0
									then "rbxthumb://type=AvatarHeadShot&id=" .. tostring(hostileId) .. "&w=150&h=150"
									else "rbxassetid://0",
								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = Theme.Radius.Full }),
									scope:New("UIStroke")({
										Color = Color3.fromRGB(50, 130, 255),
										Thickness = 1.5,
									}),
								},
							}),
							scope:New("TextLabel")({
								Name = "Name",
								Size = UDim2.new(1, -44, 1, 0),
								Position = UDim2.fromOffset(0, 0),
								BackgroundTransparency = 1,
								Text = record.HostileName,
								TextColor3 = Theme.Foreground.Primary,
								TextSize = Theme.Text.Medium,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Right,
								TextYAlignment = Enum.TextYAlignment.Center,
								TextTruncate = Enum.TextTruncate.AtEnd,
							}),
						},
					}),
				},
			}),
		},
	})
end

local function FilterTab(scope: FusionScope, name: string, selectedFilter: FusionValue<string>, tabWidth: number?): TextButton
	local isHovered = scope:Value(false)
	local isSelected = scope:Computed(function(use: FusionUseFn)
		return use(selectedFilter) == name
	end)

	local bgColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isSelected) then
				return Theme.Colors.Success
			end
			return if use(isHovered) then Theme.Colors.Black[650] else Theme.Colors.Black[750]
		end),
		Theme.Spring.Snappy.Speed
	)

	local textColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isSelected) then
				return Theme.Colors.White
			end
			return if use(isHovered) then Theme.Colors.White else Theme.Colors.Black[200]
		end),
		Theme.Spring.Snappy.Speed
	)

	local width = tabWidth or 0.25

	return scope:New("TextButton")({
		Name = name:gsub("%s", "") .. "Tab",
		Size = UDim2.new(width, -6, 1, 0),
		BackgroundColor3 = bgColor,
		BorderSizePixel = 0,
		Text = name,
		TextColor3 = textColor,
		TextSize = Theme.Text.Small,
		Font = Theme.Text.Bold,
		AutoButtonColor = false,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
		},
		[Fusion.OnEvent("MouseEnter")] = function()
			isHovered:set(true)
		end,
		[Fusion.OnEvent("MouseLeave")] = function()
			isHovered:set(false)
		end,
		[Fusion.OnEvent("Activated")] = function()
			selectedFilter:set(name)
		end,
	})
end

function MatchHistory(scope: FusionScope, props: MatchHistoryProps): ScreenGui
	local isVisible = props.Visible
	local selectedFilter = scope:Value("ALL TIME")
	local selectedOutcomeFilter = scope:Value("ALL")

	local overlayTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then 0.5 else 1
		end),
		Theme.Spring.Snappy.Speed
	)

	local modalTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then 0 else 1
		end),
		Theme.Spring.Snappy.Speed
	)

	local modalScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isVisible) then 1 else 0.9
		end),
		Theme.Spring.Snappy.Speed
	)

	local header = scope:New("Frame")({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, CONTENT_PADDING),
				PaddingRight = UDim.new(0, CONTENT_PADDING),
			}),
			scope:New("ImageLabel")({
				Name = "Icon",
				Size = UDim2.fromOffset(20, 20),
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Image = ICON_HISTORY,
				ImageColor3 = Theme.Colors.White,
			}),
			scope:New("TextLabel")({
				Name = "Title",
				Size = UDim2.new(1, -60, 1, 0),
				Position = UDim2.fromOffset(28, 0),
				BackgroundTransparency = 1,
				Text = "MATCH HISTORY",
				TextColor3 = Theme.Foreground.Primary,
				TextSize = Theme.Text.Medium,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
			scope:New("TextButton")({
				Name = "CloseButton",
				Size = UDim2.fromOffset(24, 24),
				Position = UDim2.fromScale(1, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Text = "X",
				TextColor3 = Theme.Foreground.Muted,
				TextSize = 20,
				Font = Enum.Font.GothamMedium,
				[Fusion.OnEvent("Activated")] = function()
					if props.OnClose then
						props.OnClose()
					end
				end,
			}),
		},
	})

	local divider = scope:New("Frame")({
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		BackgroundColor3 = Theme.Border.Subtle,
		BorderSizePixel = 0,
	})

	local content = scope:New("Frame")({
		Name = "Content",
		Size = UDim2.new(1, 0, 0, 460),
		Position = UDim2.fromOffset(0, HEADER_HEIGHT + 1),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, CONTENT_PADDING),
				PaddingRight = UDim.new(0, CONTENT_PADDING),
				PaddingTop = UDim.new(0, CONTENT_PADDING),
				PaddingBottom = UDim.new(0, CONTENT_PADDING),
			}),

			scope:New("TextLabel")({
				Name = "TimePeriodLabel",
				Size = UDim2.new(1, 0, 0, 14),
				BackgroundTransparency = 1,
				Text = "Time Period",
				TextColor3 = Theme.Foreground.Muted,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),

			scope:New("Frame")({
				Name = "TimeframeFilterBar",
				Size = UDim2.new(1, 0, 0, 24),
				Position = UDim2.fromOffset(0, 18),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					FilterTab(scope, "LAST DAY", selectedFilter, 0.25),
					FilterTab(scope, "LAST WEEK", selectedFilter, 0.25),
					FilterTab(scope, "LAST MONTH", selectedFilter, 0.25),
					FilterTab(scope, "ALL TIME", selectedFilter, 0.25),
				},
			}),

			scope:New("TextLabel")({
				Name = "ResultLabel",
				Size = UDim2.new(1, 0, 0, 14),
				Position = UDim2.fromOffset(0, 50),
				BackgroundTransparency = 1,
				Text = "Filter",
				TextColor3 = Theme.Foreground.Muted,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),

			scope:New("Frame")({
				Name = "OutcomeFilterBar",
				Size = UDim2.new(1, 0, 0, 24),
				Position = UDim2.fromOffset(0, 68),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					FilterTab(scope, "ALL", selectedOutcomeFilter, 0.33),
					FilterTab(scope, "WINS", selectedOutcomeFilter, 0.33),
					FilterTab(scope, "LOSSES", selectedOutcomeFilter, 0.33),
				},
			}),

			scope:Computed(function(use: FusionUseFn)
				if not use(props.Loading) then
					return nil
				end
				return scope:New("TextLabel")({
					Name = "LoadingLabel",
					Size = UDim2.new(1, 0, 1, -100),
					Position = UDim2.fromOffset(0, 100),
					BackgroundTransparency = 1,
					Text = "LOADING MATCH HISTORY...",
					TextColor3 = Theme.Foreground.Muted,
					TextSize = Theme.Text.Medium,
					Font = Theme.Text.Bold,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
				})
			end),

			scope:Computed(function(use: FusionUseFn)
				if use(props.Loading) then
					return nil
				end

				local records = use(props.HistoryData) or {}
				local filter = use(selectedFilter)
				local outcomeFilter = use(selectedOutcomeFilter)
				local now = os.time()
				local limit = 0

				if filter == "LAST DAY" then
					limit = now - 24 * 60 * 60
				elseif filter == "LAST WEEK" then
					limit = now - 7 * 24 * 60 * 60
				elseif filter == "LAST MONTH" then
					limit = now - 30.44 * 24 * 60 * 60
				end

				local filtered = {}
				local localUserId = localPlayer and localPlayer.UserId or 0

				for _, rec in records do
					local timestamp = rec.Timestamp or 0
					local isTimeOk = (filter == "ALL TIME" or timestamp >= limit)
					if isTimeOk then
						local isOutcomeOk = false
						if outcomeFilter == "ALL" then
							isOutcomeOk = true
						elseif outcomeFilter == "WINS" then
							if rec.IsAiMode ~= nil then
								local localName = localPlayer and localPlayer.Name or ""
								isOutcomeOk = if rec.IsAiMode then (rec.WinnerName == localName) else true
							else
								isOutcomeOk = (rec.WinnerId == localUserId)
							end
						elseif outcomeFilter == "LOSSES" then
							if rec.IsAiMode ~= nil then
								local localName = localPlayer and localPlayer.Name or ""
								isOutcomeOk = if rec.IsAiMode then (rec.WinnerName ~= localName) else false
							else
								isOutcomeOk = (rec.WinnerId ~= localUserId and rec.WinnerId ~= 0 and rec.WinnerName ~= "Tie")
							end
						end

						if isOutcomeOk then
							table.insert(filtered, rec)
						end
					end
				end

				if #filtered == 0 then
					return scope:New("TextLabel")({
						Name = "EmptyLabel",
						Size = UDim2.new(1, 0, 1, -100),
						Position = UDim2.fromOffset(0, 100),
						BackgroundTransparency = 1,
						Text = "No matches played yet.",
						TextColor3 = Theme.Foreground.Muted,
						TextSize = Theme.Text.Medium,
						Font = Theme.Text.Semibold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					})
				end

				local cards = {}
				for _i, record in ipairs(filtered) do
					table.insert(cards, MatchCard(scope, record))
				end

				return scope:New("ScrollingFrame")({
					Name = "HistoryScroll",
					Size = UDim2.new(1, 0, 1, -100),
					Position = UDim2.fromOffset(0, 100),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 4,
					ScrollBarImageColor3 = Theme.Colors.Black[500],
					CanvasSize = UDim2.fromScale(0, 0),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					[Fusion.Children] = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Vertical,
							Padding = UDim.new(0, 10),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						cards,
					},
				})
			end),
		},
	})

	local modal = scope:New("CanvasGroup")({
		Name = "Modal",
		Size = UDim2.new(1, -16, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Theme.Modal.Background,
		BackgroundTransparency = Theme.Modal.BackgroundTransparency,
		BorderSizePixel = 0,
		GroupTransparency = modalTransparency,
		ZIndex = 1,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
			scope:New("UIStroke")({
				Color = Theme.Modal.Border,
				Thickness = 1,
				Transparency = Theme.Stroke.Default,
			}),
			scope:New("UIScale")({ Scale = modalScale }),
			header,
			divider,
			content,
		},
	})

	local modalContainer = scope:New("Frame")({
		Name = "ModalContainer",
		Size = UDim2.fromOffset(MODAL_WIDTH + 16, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 2,
		[Fusion.Children] = {
			Shadow(scope, {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.new(0.5, 0, 0.5, 3),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = 8,
				Transparency = 0.5,
				ZIndex = 0,
			}),
			modal,
		},
	})

	return scope:New("ScreenGui")({
		Name = "MatchHistory",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 17,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = isVisible,
		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Overlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Modal.Overlay,
				BackgroundTransparency = overlayTransparency,
				BorderSizePixel = 0,
				ZIndex = 1,
			}),
			modalContainer,
		},
	})
end

return MatchHistory
