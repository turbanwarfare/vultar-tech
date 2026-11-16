--!native
--!optimize 2

local Players = game:GetService("Players")
local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local FormatUtils = require(MainModule.Shared.Utils.Text.FormatUtils)
local Shadow = require(MainModule.Client.Components.Shadow)
local Network = require(MainModule.Shared.Network)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionValue<T> = Types.FusionValue<T>
type FusionUseFn = Types.FusionUseFn

local peek: <T>(state: FusionCanBeState<T>) -> T = Fusion.peek

export type PlayerLookupProps = {
	Visible: FusionValue<boolean>,
	OnClose: (() -> ())?,
}

local MODAL_WIDTH = 380
local HEADER_HEIGHT = 44
local CONTENT_PADDING = 16
local SECTION_GAP = 14
local ICON_STATS = "rbxassetid://95734475402045" 

local function PrimaryButton(
	scope: FusionScope,
	props: {
		Text: string,
		OnClick: (() -> ())?,
		IsPrimary: boolean?,
		IsDestructive: boolean?,
		Size: UDim2?,
		Position: UDim2?,
		Disabled: FusionCanBeState<boolean>?,
	}
): TextButton
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)

	local isDisabled = scope:Computed(function(use: FusionUseFn)
		local d = props.Disabled
		if typeof(d) == "table" then
			return use(d :: any)
		end
		return d == true
	end)

	local buttonTheme = if props.IsDestructive then Theme.Button.Destructive elseif props.IsPrimary then Theme.Button.Primary else Theme.Button.Secondary

	local bgColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDisabled) then
				return Theme.Colors.Black[700]
			end
			return if use(isHovered) or use(isPressed) then buttonTheme.BackgroundHover else buttonTheme.Background
		end),
		Theme.Spring.Snappy.Speed
	)

	local scale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDisabled) then
				return 1
			end
			return if use(isPressed) then 0.98 else 1
		end),
		Theme.Spring.Snappy.Speed
	)

	return scope:New("TextButton")({
		Name = props.Text:gsub("%s", "") .. "Button",
		Size = props.Size or UDim2.new(1, 0, 0, 38),
		Position = props.Position or UDim2.fromScale(0, 0),
		BackgroundColor3 = bgColor,
		BorderSizePixel = 0,
		Text = props.Text,
		TextColor3 = scope:Computed(function(use: FusionUseFn)
			return if use(isDisabled) then Theme.Foreground.Disabled else buttonTheme.Foreground
		end),
		TextSize = Theme.Text.Medium,
		Font = Theme.Text.Bold,
		AutoButtonColor = false,
		Active = scope:Computed(function(use: FusionUseFn)
			return not use(isDisabled)
		end),

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
			scope:New("UIScale")({ Scale = scale }),
		},

		[Fusion.OnEvent("MouseEnter")] = function()
			if not peek(isDisabled) then
				isHovered:set(true)
			end
		end,
		[Fusion.OnEvent("MouseLeave")] = function()
			isHovered:set(false)
			isPressed:set(false)
		end,
		[Fusion.OnEvent("MouseButton1Down")] = function()
			if not peek(isDisabled) then
				isPressed:set(true)
			end
		end,
		[Fusion.OnEvent("MouseButton1Up")] = function()
			isPressed:set(false)
		end,
		[Fusion.OnEvent("Activated")] = function()
			if not peek(isDisabled) and props.OnClick then
				props.OnClick()
			end
		end,
	})
end

local function StatCard(scope: FusionScope, label: string, valueState: FusionCanBeState<string>): Frame
	return scope:New("Frame")({
		Name = label:gsub("%s", "") .. "Card",
		BackgroundColor3 = Theme.Colors.Black[800],
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
			scope:New("UIStroke")({
				Color = Theme.Border.Subtle,
				Thickness = 1,
				Transparency = Theme.Stroke.Default,
			}),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			}),
			scope:New("TextLabel")({
				Name = "Label",
				Size = UDim2.new(1, 0, 0, 14),
				BackgroundTransparency = 1,
				Text = label:upper(),
				TextColor3 = Theme.Foreground.Muted,
				TextSize = Theme.Text.XSmall,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("TextLabel")({
				Name = "Value",
				Size = UDim2.new(1, 0, 1, -14),
				Position = UDim2.fromOffset(0, 14),
				BackgroundTransparency = 1,
				Text = valueState,
				TextColor3 = Theme.Foreground.Primary,
				TextSize = Theme.Text.Large,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Bottom,
			}),
		},
	})
end

local function SearchBar(
	scope: FusionScope,
	props: {
		Text: FusionValue<string>,
		OnSearch: () -> (),
		Searching: FusionCanBeState<boolean>,
	}
)
	local isFocused = scope:Value(false)

	local bgTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isFocused) then Theme.Input.BackgroundFocusedTransparency else Theme.Input.BackgroundTransparency
		end),
		Theme.Spring.Default.Speed
	)

	local borderColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isFocused) then Theme.Input.BorderFocused else Theme.Input.Border
		end),
		Theme.Spring.Default.Speed
	)

	return scope:New("Frame")({
		Name = "SearchBar",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "InputFrame",
				Size = UDim2.new(1, -90, 1, 0),
				BackgroundColor3 = Theme.Input.Background,
				BackgroundTransparency = bgTransparency,
				BorderSizePixel = 0,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
					scope:New("UIStroke")({
						Color = borderColor,
						Thickness = 1,
						Transparency = Theme.Stroke.Default,
					}),
					scope:New("TextBox")({
						Name = "Input",
						Size = UDim2.new(1, -16, 1, 0),
						Position = UDim2.fromOffset(8, 0),
						BackgroundTransparency = 1,
						Text = props.Text,
						PlaceholderText = "Search username",
						PlaceholderColor3 = Theme.Input.Placeholder,
						TextColor3 = Theme.Input.Text,
						TextSize = Theme.Text.Medium,
						Font = Theme.Text.Semibold,
						TextXAlignment = Enum.TextXAlignment.Left,
						ClearTextOnFocus = false,
						TextEditable = scope:Computed(function(use: FusionUseFn)
							return not use(props.Searching)
						end),
						[Fusion.Out("Text")] = props.Text,
						[Fusion.OnEvent("Focused")] = function()
							isFocused:set(true)
						end,
						[Fusion.OnEvent("FocusLost")] = function(enterPressed: boolean)
							isFocused:set(false)
							if enterPressed then
								props.OnSearch()
							end
						end,
					}),
				},
			}),

			PrimaryButton(scope, {
				Text = "SEARCH",
				IsPrimary = true,
				OnClick = props.OnSearch,
				Size = UDim2.new(0, 80, 1, 0),
				Position = UDim2.new(1, -80, 0, 0),
				Disabled = props.Searching,
			}),
		},
	})
end

local function PlayerLookup(scope: FusionScope, props: PlayerLookupProps): ScreenGui
	local currentStats = scope:Value(nil :: any)
	local searchText = scope:Value("")
	local searching = scope:Value(false)
	local errorMessage = scope:Value("")

	local isVisible = scope:Computed(function(use: FusionUseFn)
		return use(props.Visible) == true
	end)

	local function doSearch(username: string)
		if username == "" then
			return
		end
		searching:set(true)
		errorMessage:set("")

		task.spawn(function()
			local result = Network.Spar.requestPlayerStats(username)
			searching:set(false)

			if result then
				currentStats:set(result)
				errorMessage:set("")
			else
				currentStats:set(nil)
				errorMessage:set("No stats found for username '" .. username .. "'")
			end
		end)
	end

	scope:Observer(props.Visible):onChange(function()
		if peek(props.Visible) and not peek(currentStats) then
			local localPlayer = Players.LocalPlayer
			if localPlayer then
				doSearch(localPlayer.Name)
			end
		end
	end)

	local statsUpdateConn = Network.Stats.onStatsUpdated(function(data)
		if not data or not data.cardChanged or not data.userId then
			return
		end
		local stats = peek(currentStats)
		if stats and stats.userId == data.userId then
			local updatedStats = table.clone(stats)
			updatedStats.cardImageId = data.cardImageId
			updatedStats.isAnimatedCard = data.isAnimatedCard
			currentStats:set(updatedStats)
		end
	end)
	table.insert(scope, statsUpdateConn)

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

	local usernameText = scope:Computed(function(use: FusionUseFn)
		local stats = use(currentStats)
		return if stats then stats.username else "..."
	end)

	local rankName = scope:Computed(function(use: FusionUseFn)
		local stats = use(currentStats)
		return if stats then stats.rankName else "UNPROVEN"
	end)

	local rankColor = scope:Computed(function(use: FusionUseFn)
		local stats = use(currentStats)
		return if stats then stats.rankColor else Color3.fromRGB(160, 160, 160)
	end)

	local isNotOwnStats = scope:Computed(function(use: FusionUseFn)
		local stats = use(currentStats)
		local localPlayer = Players.LocalPlayer
		if stats and localPlayer then
			return stats.username:lower() ~= localPlayer.Name:lower()
		end
		return false
	end)

	local allTimeWins = scope:Computed(function(use: FusionUseFn)
		local stats = use(currentStats)
		return if stats then FormatUtils.formatNumber(stats.AllTimeWins) else "0"
	end)
	local allTimeLosses = scope:Computed(function(use: FusionUseFn)
		local stats = use(currentStats)
		return if stats then FormatUtils.formatNumber(stats.AllTimeLosses) else "0"
	end)
	local allTimeKills = scope:Computed(function(use: FusionUseFn)
		local stats = use(currentStats)
		return if stats then FormatUtils.formatNumber(stats.AllTimeKills) else "0"
	end)
	local allTimeDamage = scope:Computed(function(use: FusionUseFn)
		local stats = use(currentStats)
		return if stats then FormatUtils.formatNumber(stats.AllTimeDamage) else "0"
	end)
	local weeklyWins = scope:Computed(function(use: FusionUseFn)
		local stats = use(currentStats)
		return if stats then FormatUtils.formatNumber(stats.WeeklyWins) else "0"
	end)
	local weeklyKills = scope:Computed(function(use: FusionUseFn)
		local stats = use(currentStats)
		return if stats then FormatUtils.formatNumber(stats.WeeklyKills) else "0"
	end)
	local monthlyWins = scope:Computed(function(use: FusionUseFn)
		local stats = use(currentStats)
		return if stats then FormatUtils.formatNumber(stats.MonthlyWins) else "0"
	end)

	local allTimeWinrate = scope:Computed(function(use: FusionUseFn)
		local stats = use(currentStats)
		if not stats then
			return "0%"
		end
		local wins = tonumber(stats.AllTimeWins) or 0
		local losses = tonumber(stats.AllTimeLosses) or 0
		local total = wins + losses
		if total == 0 then
			return "0%"
		else
			return string.format("%.1f%%", (wins / total) * 100)
		end
	end)

	local lookupCardImageId = scope:Computed(function(use: FusionUseFn)
		local stats = use(currentStats)
		return if stats and stats.cardImageId and stats.cardImageId ~= "" and stats.cardImageId ~= "Default_PlayerCard" then stats.cardImageId else ""
	end)

	local header = scope:New("Frame")({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundColor3 = Theme.Modal.Header,
		BackgroundTransparency = Theme.Modal.HeaderTransparency,
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 10),
			}),
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
						Image = ICON_STATS,
						ImageColor3 = Theme.Colors.SilverBright,
					}),
					scope:New("TextLabel")({
						Name = "Title",
						Size = UDim2.fromScale(0, 1),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = "PLAYER LOOKUP",
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
				TextColor3 = Theme.Foreground.Muted,
				TextSize = Theme.Text.Medium,
				Font = Theme.Text.Bold,
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
		BackgroundColor3 = Theme.Border.Default,
		BackgroundTransparency = Theme.Stroke.Subtle,
		BorderSizePixel = 0,
	})

	local content = scope:New("Frame")({
		Name = "Content",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, CONTENT_PADDING),
				PaddingRight = UDim.new(0, CONTENT_PADDING),
				PaddingTop = UDim.new(0, CONTENT_PADDING),
				PaddingBottom = UDim.new(0, CONTENT_PADDING),
			}),
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, SECTION_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			SearchBar(scope, {
				Text = searchText,
				OnSearch = function()
					doSearch(peek(searchText))
				end,
				Searching = searching,
			}),

			scope:Computed(function(use: FusionUseFn)
				if use(isNotOwnStats) then
					return PrimaryButton(scope, {
						Text = "VIEW MY STATS",
						OnClick = function()
							local localPlayer = Players.LocalPlayer
							if localPlayer then
								searchText:set("")
								doSearch(localPlayer.Name)
							end
						end,
						Size = UDim2.new(1, 0, 0, 28),
						Disabled = searching,
					})
				end
				return nil
			end),

			scope:Computed(function(use: FusionUseFn)
				local err = use(errorMessage)
				if err ~= "" then
					return scope:New("Frame")({
						Name = "ErrorPanel",
						Size = UDim2.new(1, 0, 0, 60),
						BackgroundColor3 = Theme.Colors.Destructive,
						BackgroundTransparency = 0.9,
						BorderSizePixel = 0,
						LayoutOrder = 3,
						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
							scope:New("UIStroke")({
								Color = Theme.Colors.Destructive,
								Thickness = 1,
								Transparency = 0.5,
							}),
							scope:New("TextLabel")({
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = err,
								TextColor3 = Theme.Colors.Destructive,
								TextSize = Theme.Text.Medium,
								Font = Theme.Text.Semibold,
								TextWrapped = true,
								TextXAlignment = Enum.TextXAlignment.Center,
								TextYAlignment = Enum.TextYAlignment.Center,
							}),
						},
					})
				end
				return nil
			end),

			scope:Computed(function(use: FusionUseFn)
				local stats = use(currentStats)
				local loading = use(searching)
				local errorActive = use(errorMessage) ~= ""

				if loading then
					return scope:New("TextLabel")({
						Name = "LoadingLabel",
						Size = UDim2.new(1, 0, 0, 100),
						BackgroundTransparency = 1,
						Text = "LOADING STATS...",
						TextColor3 = Theme.Foreground.Muted,
						TextSize = Theme.Text.Medium,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					})
				elseif errorActive or not stats then
					return nil
				end

				return scope:New("Frame")({
					Name = "StatsPanel",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					[Fusion.Children] = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Vertical,
							Padding = UDim.new(0, SECTION_GAP),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),

						scope:New("Frame")({
							Name = "PlayerBanner",
							Size = UDim2.new(1, 0, 0, 50),
							BackgroundColor3 = Theme.Colors.Black[800],
							BackgroundTransparency = 0.6,
							BorderSizePixel = 0,
							LayoutOrder = 1,
							ClipsDescendants = true,
							[Fusion.Children] = {
								scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
								scope:New("UIStroke")({
									Color = Theme.Border.Subtle,
									Thickness = 1,
									Transparency = Theme.Stroke.Default,
								}),
								scope:New("UIPadding")({
									PaddingLeft = UDim.new(0, 12),
									PaddingRight = UDim.new(0, 12),
									PaddingTop = UDim.new(0, 8),
									PaddingBottom = UDim.new(0, 8),
								}),
								scope:New("ImageLabel")({
									Name = "CustomBannerBackground",
									Size = UDim2.fromScale(1, 1),
									Position = UDim2.fromScale(0, 0),
									BackgroundTransparency = 1,
									Image = lookupCardImageId,
									ImageTransparency = 0.6,
									ScaleType = Enum.ScaleType.Crop,
									ZIndex = 1,
									Visible = scope:Computed(function(use2: FusionUseFn)
										return use2(lookupCardImageId) ~= ""
									end),
									[Fusion.Children] = {
										scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
									},
								}),
								scope:New("ImageLabel")({
									Name = "Headshot",
									Size = UDim2.fromOffset(34, 34),
									Position = UDim2.fromScale(0, 0.5),
									AnchorPoint = Vector2.new(0, 0.5),
									BackgroundTransparency = 1,
									ZIndex = 2,
									Image = scope:Computed(function(use2: FusionUseFn)
										local stats2 = use2(currentStats)
										return if stats2
												and stats2.userId
												and stats2.userId > 0
											then "rbxthumb://type=AvatarHeadShot&id=" .. stats2.userId .. "&w=150&h=150"
											else "rbxassetid://0"
									end),
									[Fusion.Children] = {
										scope:New("UICorner")({ CornerRadius = Theme.Radius.Full }),
									},
								}),
								scope:New("TextLabel")({
									Name = "UsernameLabel",
									Size = UDim2.new(1, -162, 1, 0),
									Position = UDim2.new(0, 42, 0.5, 0),
									AnchorPoint = Vector2.new(0, 0.5),
									BackgroundTransparency = 1,
									ZIndex = 2,
									Text = usernameText,
									TextColor3 = Theme.Foreground.Primary,
									TextSize = Theme.Text.Large,
									Font = Theme.Text.Bold,
									TextXAlignment = Enum.TextXAlignment.Left,
									TextYAlignment = Enum.TextYAlignment.Center,
									TextTruncate = Enum.TextTruncate.AtEnd,
								}),
								scope:New("Frame")({
									Name = "Badge",
									Size = UDim2.fromOffset(110, 24),
									Position = UDim2.fromScale(0.98, 0.5),
									AnchorPoint = Vector2.new(1, 0.5),
									BackgroundColor3 = rankColor,
									BackgroundTransparency = 0.85,
									ZIndex = 2,
									[Fusion.Children] = {
										scope:New("UICorner")({ CornerRadius = Theme.Radius.Full }),
										scope:New("UIStroke")({
											Color = rankColor,
											Thickness = 1,
											Transparency = 0.5,
										}),
										scope:New("TextLabel")({
											Size = UDim2.fromScale(1, 1),
											BackgroundTransparency = 1,
											Text = rankName,
											TextColor3 = rankColor,
											TextSize = Theme.Text.XSmall,
											Font = Theme.Text.Bold,
											TextXAlignment = Enum.TextXAlignment.Center,
											TextYAlignment = Enum.TextYAlignment.Center,
										}),
									},
								}),
							},
						}),

						scope:New("Frame")({
							Name = "StatsGrid",
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							LayoutOrder = 2,
							[Fusion.Children] = {
								scope:New("UIGridLayout")({
									CellSize = UDim2.new(0.5, -6, 0, 48),
									CellPadding = UDim2.fromOffset(12, 8),
									SortOrder = Enum.SortOrder.LayoutOrder,
								}),
								StatCard(scope, "All-time Wins", allTimeWins),
								StatCard(scope, "All-time Losses", allTimeLosses),
								StatCard(scope, "Winrate", allTimeWinrate),
								StatCard(scope, "All-time Kills", allTimeKills),
								StatCard(scope, "All-time Damage", allTimeDamage),
								StatCard(scope, "Weekly Wins", weeklyWins),
								StatCard(scope, "Weekly Kills", weeklyKills),
								StatCard(scope, "Monthly Wins", monthlyWins),
							},
						}),
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
		Name = "PlayerLookup",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 16,
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

return PlayerLookup
