--!strict
--!native
--!optimize 2

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

export type ViacomPanelProps = {
	Visible: FusionValue<boolean>,
	OnClose: (() -> ())?,
}

local MODAL_WIDTH = 560
local HEADER_HEIGHT = 44
local CONTENT_PADDING = 16
local SECTION_GAP = 14
local ICON_VIACOM = "rbxassetid://134880308929198"

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
		Selected: FusionCanBeState<boolean>?,
		LayoutOrder: number?,
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

	local isSelected = scope:Computed(function(use: FusionUseFn)
		local s = props.Selected
		if typeof(s) == "table" then
			return use(s :: any)
		end
		return s == true
	end)

	local buttonTheme = if props.IsDestructive then Theme.Button.Destructive elseif props.IsPrimary then Theme.Button.Primary else Theme.Button.Secondary

	local bgColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDisabled) then
				return Theme.Colors.Black[700]
			end
			if use(isSelected) then
				return Theme.Button.Primary.BackgroundHover
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
		LayoutOrder = props.LayoutOrder,
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

local function SearchBar(
	scope: FusionScope,
	props: {
		Text: FusionValue<string>,
		OnSearch: () -> (),
		Searching: FusionCanBeState<boolean>,
		Placeholder: string?,
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
						PlaceholderText = props.Placeholder or "Search username or match ID",
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

local function formatTime(timestamp: number): string
	local success, result = pcall(os.date, "%b %d, %Y %H:%M", timestamp)
	return if success then result else "Unknown Time"
end

local function formatDuration(seconds: number): string
	if seconds < 60 then
		return string.format("%ds", seconds)
	end
	local mins = seconds // 60
	local secs = seconds % 60
	return string.format("%dm %ds", mins, secs)
end

local function CopyField(scope: FusionScope, props: { Text: string, Size: UDim2?, LayoutOrder: number? }): TextBox
	local copyBox: TextBox = nil :: any

	copyBox = scope:New("TextBox")({
		Name = "CopyField",
		Size = props.Size or UDim2.fromOffset(100, 20),
		LayoutOrder = props.LayoutOrder,
		BackgroundColor3 = Theme.Colors.Black[700],
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Text = props.Text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = Theme.Colors.SilverBright,
		TextSize = Theme.Text.XSmall,
		Font = Theme.Text.Bold,
		ClearTextOnFocus = false,
		TextEditable = true,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			}),
		},
		[Fusion.OnEvent("Focused")] = function()
			copyBox.SelectionStart = 1
			copyBox.CursorPosition = #props.Text + 1
		end,
		[Fusion.OnEvent("FocusLost")] = function()
			if copyBox.Text ~= props.Text then
				copyBox.Text = props.Text
			end
		end,
	})

	return copyBox
end

local function ExportButton(scope: FusionScope, props: { MatchId: string, LayoutOrder: number? }): TextButton
	local status = scope:Value("idle")

	local buttonText = scope:Computed(function(use: FusionUseFn)
		local s = use(status)
		if s == "sending" then
			return "SENDING..."
		elseif s == "success" then
			return "EXPORTED"
		elseif s == "error" then
			return "FAILED"
		end
		return "EXPORT"
	end)

	local bgColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			local s = use(status)
			if s == "success" then
				return Color3.fromRGB(60, 180, 90)
			elseif s == "error" then
				return Theme.Colors.Destructive
			end
			return Theme.Colors.Black[700]
		end),
		Theme.Spring.Snappy.Speed
	)

	return scope:New("TextButton")({
		Name = "ExportButton",
		Size = UDim2.fromOffset(70, 20),
		LayoutOrder = props.LayoutOrder,
		BackgroundColor3 = bgColor,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Text = buttonText,
		TextColor3 = Theme.Colors.SilverBright,
		TextSize = Theme.Text.XSmall,
		Font = Theme.Text.Bold,
		AutoButtonColor = false,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
		},
		[Fusion.OnEvent("Activated")] = function()
			if peek(status) == "sending" then
				return
			end
			status:set("sending")
			task.spawn(function()
				local result = Network.Spar.requestViacomExportMatch(props.MatchId)
				if result and result.success then
					status:set("success")
				else
					status:set("error")
				end
				task.delay(2.5, function()
					status:set("idle")
				end)
			end)
		end,
	})
end

local function MatchRecordCard(scope: FusionScope, record: any): Frame
	local matchId = record.MatchId or "N/A"
	local winnerId = record.WinnerId or 0
	local winnerName = record.WinnerName or "Tie"
	local vultarianId = record.VultarianId or 0
	local hostileId = record.HostileId or 0

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
	end

	local metaText = (record.MapName or "Unknown")
		.. "  •  "
		.. (record.GunName or "Unknown")
		.. "  •  "
		.. tostring(record.Rounds or 1)
		.. " Rounds  •  "
		.. (record.HealthOption or "100")
		.. " HP"
	if record.Duration then
		metaText = metaText .. "  •  " .. formatDuration(record.Duration)
	end

	return scope:New("Frame")({
		Name = "MatchRecordCard",
		Size = UDim2.new(1, 0, 0, 120),
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
				Name = "MatchIdRow",
				Size = UDim2.new(1, -190, 0, 20),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "MatchIdLabel",
						Size = UDim2.fromScale(0.6, 1),
						BackgroundTransparency = 1,
						Text = "ID: " .. string.sub(matchId, 1, 8) .. "...",
						TextColor3 = Theme.Colors.SilverBright,
						TextSize = Theme.Text.Small,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
					scope:New("TextLabel")({
						Name = "TimeLabel",
						Size = UDim2.fromScale(0.4, 1),
						Position = UDim2.fromScale(0.6, 0),
						BackgroundTransparency = 1,
						Text = formatTime(record.Timestamp or 0),
						TextColor3 = Theme.Foreground.Muted,
						TextSize = Theme.Text.Small,
						Font = Theme.Text.Regular,
						TextXAlignment = Enum.TextXAlignment.Right,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "ActionsRow",
				Size = UDim2.fromOffset(180, 20),
				Position = UDim2.fromScale(1, 0),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					CopyField(scope, { Text = matchId, Size = UDim2.fromOffset(104, 20), LayoutOrder = 1 }),
					ExportButton(scope, { MatchId = matchId, LayoutOrder = 2 }),
				},
			}),

			scope:New("TextLabel")({
				Name = "MetaLabel",
				Size = UDim2.new(1, 0, 0, 16),
				Position = UDim2.fromOffset(0, 22),
				BackgroundTransparency = 1,
				Text = metaText,
				TextColor3 = Theme.Foreground.Muted,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),

			scope:New("Frame")({
				Name = "Divider",
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.fromOffset(0, 40),
				BackgroundColor3 = Theme.Border.Subtle,
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
			}),

			scope:New("Frame")({
				Name = "VSPanel",
				Size = UDim2.new(1, 0, 0, 52),
				Position = UDim2.fromOffset(0, 44),
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
								Text = record.VultarianName or "Unknown",
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
								Text = record.HostileName or "Unknown",
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

local function FlagBanner(scope: FusionScope, flagData: any): Frame
	local isFeeding = flagData.flagType == "FEEDING_SUSPECTED"
	local color = if isFeeding then Theme.Colors.Destructive else Color3.fromRGB(255, 140, 0)
	
	local scoreText = ""
	if isFeeding then
		scoreText = string.format("Feeding Score: %.3f", flagData.feedingScore or 0)
	else
		scoreText = string.format("Mutual Score: %.3f", flagData.mutualScore or 0)
	end
	
	local otherId = flagData.flaggedPairIds and flagData.flaggedPairIds[1] or 0
	if otherId == flagData.searchedUserId and flagData.flaggedPairIds then
		otherId = flagData.flaggedPairIds[2] or 0
	end

	return scope:New("Frame")({
		Name = "FlagBanner_" .. (flagData.triggerMatchId or "unknown"),
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
			scope:New("UIStroke")({
				Color = color,
				Thickness = 1.5,
				Transparency = 0.2,
			}),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			}),
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			scope:New("TextLabel")({
				Name = "Icon",
				Size = UDim2.fromOffset(24, 24),
				BackgroundTransparency = 1,
				Text = "⚠",
				TextColor3 = color,
				TextSize = 20,
				Font = Theme.Text.Bold,
				LayoutOrder = 1,
			}),
			scope:New("TextLabel")({
				Name = "Message",
				Size = UDim2.new(1, -150, 1, 0),
				BackgroundTransparency = 1,
				Text = string.format("FLAGGED: %s with User %d. Match: %s", flagData.flagType, otherId, string.sub(flagData.triggerMatchId or "", 1, 8)),
				TextColor3 = color,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				LayoutOrder = 2,
			}),
			scope:New("TextLabel")({
				Name = "Score",
				Size = UDim2.fromOffset(110, 1),
				BackgroundTransparency = 1,
				Text = scoreText,
				TextColor3 = color,
				TextSize = Theme.Text.XSmall,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Center,
				LayoutOrder = 3,
			}),
		},
	})
end

local function ViacomPanel(scope: FusionScope, props: ViacomPanelProps): ScreenGui
	local currentData = scope:Value(nil :: any)
	local searchText = scope:Value("")
	local searching = scope:Value(false)
	local errorMessage = scope:Value("")
	local filterMode = scope:Value("ALL")

	local isVisible = scope:Computed(function(use: FusionUseFn)
		return use(props.Visible) == true
	end)

	local function doSearch(query: string)
		if query == "" then
			return
		end
		searching:set(true)
		errorMessage:set("")

		task.spawn(function()
			local mode = peek(filterMode)
			local isMatchIdQuery = mode == "BY_ID" or (#query > 20 and string.find(query, "%-"))

			if isMatchIdQuery then
				local record = Network.Spar.requestViacomGetMatch(query)
				searching:set(false)
				if record then
					currentData:set({ stats = nil, matches = { record } })
					errorMessage:set("")
				else
					currentData:set(nil)
					errorMessage:set("No match found with ID: " .. string.sub(query, 1, 8))
				end
			else
				local result = Network.Spar.requestViacomSearch(query)
				searching:set(false)
				if result then
					currentData:set(result)
					errorMessage:set("")
				else
					currentData:set(nil)
					errorMessage:set("No data found for '" .. query .. "'")
				end
			end
		end)
	end

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

	local allTimeWins = scope:Computed(function(use: FusionUseFn)
		local data = use(currentData)
		return if data and data.stats then FormatUtils.formatNumber(data.stats.AllTimeWins) else "0"
	end)
	local allTimeLosses = scope:Computed(function(use: FusionUseFn)
		local data = use(currentData)
		return if data and data.stats then FormatUtils.formatNumber(data.stats.AllTimeLosses) else "0"
	end)
	local allTimeKills = scope:Computed(function(use: FusionUseFn)
		local data = use(currentData)
		return if data and data.stats then FormatUtils.formatNumber(data.stats.AllTimeKills) else "0"
	end)
	local allTimeDamage = scope:Computed(function(use: FusionUseFn)
		local data = use(currentData)
		return if data and data.stats then FormatUtils.formatNumber(data.stats.AllTimeDamage) else "0"
	end)

	local allTimeWinrate = scope:Computed(function(use: FusionUseFn)
		local data = use(currentData)
		if not data or not data.stats then
			return "0%"
		end
		local wins = tonumber(data.stats.AllTimeWins) or 0
		local losses = tonumber(data.stats.AllTimeLosses) or 0
		local total = wins + losses
		if total == 0 then
			return "0%"
		end
		return string.format("%.1f%%", (wins / total) * 100)
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
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					scope:New("ImageLabel")({
						Name = "Icon",
						Size = UDim2.fromOffset(20, 20),
						BackgroundTransparency = 1,
						Image = ICON_VIACOM,
						ImageColor3 = Theme.Colors.SilverBright,
						LayoutOrder = 1,
					}),
					scope:New("TextLabel")({
						Name = "Title",
						Size = UDim2.fromScale(0, 1),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = "VIACOM INVESTIGATION PANEL",
						TextColor3 = Theme.Foreground.Primary,
						TextSize = Theme.Text.Small,
						Font = Theme.Text.Bold,
						LayoutOrder = 2,
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
				Placeholder = "Search username or paste match ID",
			}),

			scope:New("Frame")({
				Name = "FilterBar",
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					scope:New("TextLabel")({
						Name = "FilterLabel",
						Size = UDim2.fromScale(0, 1),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = "Filter:",
						TextColor3 = Theme.Foreground.Muted,
						TextSize = Theme.Text.Small,
						Font = Theme.Text.Bold,
						TextYAlignment = Enum.TextYAlignment.Center,
						LayoutOrder = 1,
					}),
					PrimaryButton(scope, {
						Text = "ALL",
						IsPrimary = false,
						Selected = scope:Computed(function(use: FusionUseFn)
							return use(filterMode) == "ALL"
						end),
						OnClick = function()
							filterMode:set("ALL")
						end,
						Size = UDim2.fromOffset(60, 28),
						LayoutOrder = 2,
					}),
					PrimaryButton(scope, {
						Text = "BY ID",
						IsPrimary = false,
						Selected = scope:Computed(function(use: FusionUseFn)
							return use(filterMode) == "BY_ID"
						end),
						OnClick = function()
							filterMode:set("BY_ID")
						end,
						Size = UDim2.fromOffset(70, 28),
						LayoutOrder = 3,
					}),
				},
			}),

			scope:Computed(function(use: FusionUseFn)
				local data = use(currentData)
				if not data or not data.flags or #data.flags == 0 then
					return nil
				end

				local flagBanners = {}
				for _, flag in data.flags do
					table.insert(flagBanners, FlagBanner(scope, flag))
				end

				return scope:New("Frame")({
					Name = "FlagBanners",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 3,
					[Fusion.Children] = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Vertical,
							Padding = UDim.new(0, 8),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						flagBanners,
					},
				})
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
						LayoutOrder = 4,
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
				local loading = use(searching)
				if loading then
					return scope:New("TextLabel")({
						Name = "LoadingLabel",
						Size = UDim2.new(1, 0, 0, 100),
						BackgroundTransparency = 1,
						Text = "LOADING...",
						TextColor3 = Theme.Foreground.Muted,
						TextSize = Theme.Text.Medium,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						LayoutOrder = 5,
					})
				end
				return nil
			end),

			scope:Computed(function(use: FusionUseFn)
				local data = use(currentData)
				local loading = use(searching)
				local errorActive = use(errorMessage) ~= ""

				if loading or errorActive or not data then
					return nil
				end

				local children: { Instance } = {}

				if data.stats then
					table.insert(
						children,
						scope:New("Frame")({
							Name = "StatsGrid",
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							LayoutOrder = 1,
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
							},
						})
					)
				end

				if data.matches and #data.matches > 0 then
					local cards: { Instance } = {}
					for _i, record in ipairs(data.matches) do
						table.insert(cards, MatchRecordCard(scope, record))
					end

					table.insert(
						children,
						scope:New("ScrollingFrame")({
							Name = "MatchHistoryScroll",
							Size = UDim2.new(1, 0, 0, 400),
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							ScrollBarThickness = 4,
							ScrollBarImageColor3 = Theme.Colors.Black[500],
							CanvasSize = UDim2.fromScale(0, 0),
							AutomaticCanvasSize = Enum.AutomaticSize.Y,
							LayoutOrder = 2,
							[Fusion.Children] = {
								scope:New("UIListLayout")({
									FillDirection = Enum.FillDirection.Vertical,
									Padding = UDim.new(0, 10),
									SortOrder = Enum.SortOrder.LayoutOrder,
								}),
								cards,
							},
						})
					)
				else
					table.insert(
						children,
						scope:New("TextLabel")({
							Name = "EmptyLabel",
							Size = UDim2.new(1, 0, 0, 60),
							BackgroundTransparency = 1,
							Text = "No matches found.",
							TextColor3 = Theme.Foreground.Muted,
							TextSize = Theme.Text.Medium,
							Font = Theme.Text.Semibold,
							TextXAlignment = Enum.TextXAlignment.Center,
							TextYAlignment = Enum.TextYAlignment.Center,
							LayoutOrder = 2,
						})
					)
				end

				return scope:New("Frame")({
					Name = "ResultsPanel",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 5,
					[Fusion.Children] = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Vertical,
							Padding = UDim.new(0, SECTION_GAP),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						children,
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
		Name = "ViacomPanel",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 18,
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

return ViacomPanel
