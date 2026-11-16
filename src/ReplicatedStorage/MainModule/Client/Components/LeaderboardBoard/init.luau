--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

local Network = require(MainModule.Shared.Network)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionValue<T> = Types.FusionValue<T>
type FusionUseFn = Types.FusionUseFn

local peek = Fusion.peek

export type LeaderboardEntry = {
	Rank: number,
	UserId: number,
	Username: string,
	Score: number,
}

export type LeaderboardBoardProps = {
	Stat: string,
	DefaultScope: string,
	Label: string,
	Face: Enum.NormalId?,
	PixelsPerStud: number?,
	FetchFn: ((stat: string, scope: string) -> any)?,
}

local ROW_HEIGHT = 60
local AVATAR_SIZE = 44

local function TabButton(scope: FusionScope, label: string, selectedTab: FusionValue<string>)
	local isHovered = scope:Value(false)
	local isSelected = scope:Computed(function(use)
		return use(selectedTab) == label
	end)

	local bgCol = scope:Spring(
		scope:Computed(function(use)
			if use(isSelected) then
				return Theme.Lobby.AccentColor
			elseif use(isHovered) then
				return Theme.Colors.Black[750]
			else
				return Theme.Lobby.CardBackground
			end
		end),
		Theme.Spring.Snappy.Speed
	)

	local textCol = scope:Computed(function(use)
		return if use(isSelected) then Theme.Lobby.ButtonText else Theme.Lobby.MutedText
	end)

	local buttonScale = scope:Spring(
		scope:Computed(function(use)
			return if use(isHovered) and not use(isSelected) then 0.98 else 1
		end),
		Theme.Spring.Snappy.Speed
	)

	return scope:New("TextButton")({
		Name = "Tab_" .. label,
		Size = UDim2.fromOffset(160, 40),
		BackgroundColor3 = bgCol,
		BorderSizePixel = 0,
		Text = label,
		TextColor3 = textCol,
		TextSize = 24,
		Font = Theme.Text.Bold,
		AutoButtonColor = false,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
			scope:New("UIScale")({ Scale = buttonScale }),
		},
		[Fusion.OnEvent("MouseEnter")] = function()
			isHovered:set(true)
		end,
		[Fusion.OnEvent("MouseLeave")] = function()
			isHovered:set(false)
		end,
		[Fusion.OnEvent("Activated")] = function()
			selectedTab:set(label)
		end,
	})
end

local function LeaderboardRow(scope: FusionScope, entry: LeaderboardEntry)
	local alternateBg = entry.Rank % 2 == 0
	local rowColor = if alternateBg then Theme.Lobby.CardBackground else Theme.Lobby.SlotBackground

	local rankColor = Theme.Lobby.HeaderText
	if entry.Rank == 1 then
		rankColor = Theme.Gold
	elseif entry.Rank == 2 then
		rankColor = Theme.Silver
	elseif entry.Rank == 3 then
		rankColor = Theme.Bronze
	end

	return scope:New("Frame")({
		Name = "Row_" .. tostring(entry.Rank),
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundColor3 = rowColor,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		LayoutOrder = entry.Rank,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
			}),

			scope:New("TextLabel")({
				Name = "Rank",
				Size = UDim2.new(0, 60, 1, 0),
				BackgroundTransparency = 1,
				Text = "#" .. tostring(entry.Rank),
				TextColor3 = rankColor,
				TextSize = if entry.Rank <= 3 then 45 else 25,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),

			scope:New("Frame")({
				Name = "AvatarFrame",
				Size = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE),
				Position = UDim2.new(0, 70, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Theme.Lobby.SlotBackground,
				BorderSizePixel = 0,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
					scope:New("ImageLabel")({
						Name = "Avatar",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(entry.UserId) .. "&w=150&h=150",
						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
						},
					}),
				},
			}),

			scope:New("TextLabel")({
				Name = "Username",
				Size = UDim2.new(0.5, -150, 1, 0),
				Position = UDim2.fromOffset(130, 0),
				BackgroundTransparency = 1,
				Text = entry.Username,
				TextColor3 = Theme.Lobby.HeaderText,
				TextSize = 25,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),

			scope:New("TextLabel")({
				Name = "Score",
				Size = UDim2.fromScale(0.4, 1),
				Position = UDim2.fromScale(1, 0),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Text = tostring(entry.Score),
				TextColor3 = Theme.Lobby.MutedText,
				TextSize = 25,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		},
	})
end

local function LeaderboardBoard(scope: FusionScope, props: LeaderboardBoardProps): SurfaceGui
	local defaultTab = "ALL-TIME"
	if props.DefaultScope == "Monthly" then
		defaultTab = "MONTHLY"
	elseif props.DefaultScope == "Daily" then
		defaultTab = "DAILY"
	end

	local selectedTab = scope:Value(defaultTab)
	local entries = scope:Value({})
	local isLoading = scope:Value(false)

	local function refresh()
		isLoading:set(true)
		task.spawn(function()
			local statName = props.Stat
			local scopeName = peek(selectedTab)
			local success, data
			if props.FetchFn then
				success, data = pcall(props.FetchFn, statName, scopeName)
			else
				success, data = pcall(Network.Spar.requestLeaderboard, statName, scopeName)
			end
			if success and type(data) == "table" then
				entries:set(data)
			else
				entries:set({})
			end
			isLoading:set(false)
		end)
	end

	scope:Observer(selectedTab):onChange(refresh)

	task.spawn(refresh)

	local refreshLoop = task.spawn(function()
		while true do
			task.wait(60)
			refresh()
		end
	end)
	table.insert(scope, function()
		task.cancel(refreshLoop)
	end)

	local rowsList = scope:Computed(function(use: FusionUseFn, rowScope: FusionScope)
		local list = use(entries) or {}
		local rows = {}
		for _, entry in ipairs(list) do
			table.insert(rows, LeaderboardRow(rowScope, entry))
		end

		if #rows == 0 then
			local msg = if use(isLoading) then "Loading data..." else "No entries found."
			table.insert(
				rows,
				rowScope:New("TextLabel")({
					Name = "StatusMsg",
					Size = UDim2.new(1, 0, 0, 100),
					BackgroundTransparency = 1,
					Text = msg,
					TextColor3 = Theme.Lobby.MutedText,
					TextSize = Theme.Text.Large,
					Font = Theme.Text.Semibold,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
				})
			)
		end

		return rows
	end)

	return scope:New("SurfaceGui")({
		Name = "LeaderboardBoardGui",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = props.PixelsPerStud or 60,
		Face = props.Face or Enum.NormalId.Right,
		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "MainFrame",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Lobby.Background,
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				[Fusion.Children] = {
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 32),
						PaddingRight = UDim.new(0, 32),
						PaddingTop = UDim.new(0, 32),
						PaddingBottom = UDim.new(0, 32),
					}),

					scope:New("TextLabel")({
						Name = "Title",
						Size = UDim2.new(1, 0, 0, 48),
						BackgroundTransparency = 1,
						Text = props.Label,
						TextColor3 = Theme.Lobby.HeaderText,
						TextSize = 36,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),

					scope:New("Frame")({
						Name = "Tabs",
						Size = UDim2.new(1, 0, 0, 50),
						Position = UDim2.fromOffset(0, 64),
						BackgroundTransparency = 1,
						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 16),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							TabButton(scope, "ALL-TIME", selectedTab),
							TabButton(scope, "MONTHLY", selectedTab),
							TabButton(scope, "DAILY", selectedTab),
						},
					}),

					scope:New("ScrollingFrame")({
						Name = "EntriesScroll",
						Size = UDim2.new(1, 0, 1, -190),
						Position = UDim2.fromOffset(0, 130),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 6,
						ScrollBarImageColor3 = Theme.Colors.Black[500],
						CanvasSize = UDim2.fromScale(0, 0),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, 8),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							rowsList,
						},
					}),

					scope:New("TextLabel")({
						Name = "Footer",
						Size = UDim2.new(1, 0, 0, 24),
						Position = UDim2.new(0, 0, 1, -24),
						BackgroundTransparency = 1,
						Text = "SORTED BY TOP 100",
						TextColor3 = Theme.Lobby.MutedText,
						TextSize = 26,
						Font = Theme.Text.Semibold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				},
			}),
		},
	})
end

return LeaderboardBoard
