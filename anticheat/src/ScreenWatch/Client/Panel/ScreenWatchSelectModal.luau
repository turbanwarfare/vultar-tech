--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = script:FindFirstAncestor("Client").Parent
local MainModule = require(Root.Shared.Game).get()
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)

type FusionScope = any
type FusionValue<T> = any
type FusionUseFn = any

export type ScreenWatchSelectModalProps = {
	Visible: FusionValue<boolean>,
	OnSelectTarget: (player: Player) -> (),
	OnClose: () -> (),
}

export type PlayerEntry = {
	player: Player,
	userId: number,
	name: string,
	teamName: string,
	isDefender: boolean,
	isSpectator: boolean,
	suspectScore: number?,
}

local SUSPECTS_REMOTE_NAME = "VultarACSuspects"

local function sortEntries(a: PlayerEntry, b: PlayerEntry): boolean
	local scoreA, scoreB = a.suspectScore or 0, b.suspectScore or 0
	if scoreA ~= scoreB then
		return scoreA > scoreB
	end
	return a.name < b.name
end

local STROKE_GRADIENT_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
})

local BLUE_BTN_COLOR = Color3.fromRGB(0, 120, 255)
local BLUE_BTN_HOVER = Color3.fromRGB(30, 145, 255)
local BLUE_BTN_PRESS = Color3.fromRGB(0, 95, 205)

local EYE_ICON = "rbxassetid://119015428034090"

local function classifyPlayer(player: Player): PlayerEntry
	local team = player.Team
	local tName = if team then team.Name else "None"
	local lower = string.lower(tName)

	local isDef = string.find(lower, "vultar") ~= nil or string.find(lower, "initiate") ~= nil or string.find(lower, "defender") ~= nil

	local isSpec = string.find(lower, "spec") ~= nil

	return {
		player = player,
		userId = player.UserId,
		name = player.Name,
		teamName = tName,
		isDefender = isDef,
		isSpectator = isSpec,
	}
end

local function SectionHeader(
	scope: FusionScope,
	props: {
		Title: string,
		Count: FusionValue<number>,
		Color: Color3,
		Visible: FusionValue<boolean>,
	}
): Frame
	return scope:New("Frame")({
		Name = "SectionHeader_" .. props.Title,
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = Color3.fromRGB(18, 18, 22),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Visible = props.Visible,
		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Small,
			}),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
			scope:New("TextLabel")({
				Name = "Title",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use: FusionUseFn)
					local c = use(props.Count) or 0
					return string.format("%s [%d]", props.Title, c)
				end),
				TextColor3 = props.Color,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		},
	})
end

local function PlayerSelectRow(scope: FusionScope, entry: PlayerEntry, onSelect: (player: Player) -> ()): Frame
	local teamColor = if entry.isDefender
		then Color3.fromRGB(255, 75, 75)
		elseif entry.isSpectator then Color3.fromRGB(150, 150, 150)
		else Color3.fromRGB(0, 180, 240)

	local headshotUrl = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(entry.userId) .. "&w=150&h=150"

	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)

	local btnBgColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isPressed) then
				return BLUE_BTN_PRESS
			elseif use(isHovered) then
				return BLUE_BTN_HOVER
			else
				return BLUE_BTN_COLOR
			end
		end),
		Theme.Spring.Snappy.Speed
	)

	return scope:New("Frame")({
		Name = "PlayerRow_" .. entry.name,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Colors.Black[800],
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Medium,
			}),
			scope:New("UIStroke")({
				Color = Color3.fromRGB(45, 45, 50),
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			}),

			scope:New("ImageLabel")({
				Name = "Headshot",
				Size = UDim2.fromOffset(24, 24),
				Position = UDim2.new(0, 6, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.fromRGB(12, 12, 14),
				BorderSizePixel = 0,
				Image = headshotUrl,
				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Small,
					}),
					scope:New("UIStroke")({
						Color = Color3.fromRGB(50, 50, 55),
						Thickness = 1,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					}),
				},
			}),

			scope:New("TextLabel")({
				Name = "Username",
				Size = UDim2.new(1, if entry.suspectScore then -232 else -182, 1, 0),
				Position = UDim2.new(0, 36, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text = entry.name,
				TextColor3 = Theme.Colors.White,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),

			if entry.suspectScore
				then scope:New("TextLabel")({
					Name = "SuspectBadge",
					Size = UDim2.fromOffset(44, 24),
					Position = UDim2.new(1, -186, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Color3.fromRGB(120, 20, 25),
					BorderSizePixel = 0,
					Text = string.format("%.0f%%", entry.suspectScore * 100),
					TextColor3 = Color3.fromRGB(255, 140, 140),
					TextSize = Theme.Text.XSmall,
					Font = Theme.Text.Bold,
					[Fusion.Children] = {
						scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
					},
				})
				else nil,

			scope:New("Frame")({
				Name = "TeamBadge",
				Size = UDim2.fromOffset(64, 24),
				Position = UDim2.new(1, -138, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.fromRGB(14, 14, 16),
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Medium,
					}),
					scope:New("UIStroke")({
						Color = Color3.fromRGB(50, 50, 55),
						Thickness = 1,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					}),
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = entry.teamName,
						TextColor3 = teamColor,
						TextSize = Theme.Text.XSmall,
						Font = Theme.Text.Bold,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
				},
			}),

			scope:New("TextButton")({
				Name = "WatchButton",
				Size = UDim2.fromOffset(64, 24),
				Position = UDim2.new(1, -70, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = btnBgColor,
				BorderSizePixel = 0,
				Text = "WATCH",
				TextColor3 = Theme.Colors.White,
				TextSize = 11,
				Font = Theme.Text.Black,
				AutoButtonColor = false,
				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Medium,
					}),
					scope:New("UIStroke")({
						Color = Color3.fromRGB(80, 160, 255),
						Thickness = 1,
						Transparency = 0.4,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					}),
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
					onSelect(entry.player)
				end,
			}),
		},
	})
end

local function ScreenWatchSelectModal(scope: FusionScope, props: ScreenWatchSelectModalProps): ScreenGui
	local searchQuery = scope:Value("")
	local defendersList = scope:Value({})
	local hostilesList = scope:Value({})
	local spectatorsList = scope:Value({})
	local defenderCount = scope:Value(0)
	local hostileCount = scope:Value(0)
	local spectatorCount = scope:Value(0)

	local hasDefenders = scope:Computed(function(use: FusionUseFn)
		return (use(defenderCount) or 0) > 0
	end)
	local hasHostiles = scope:Computed(function(use: FusionUseFn)
		return (use(hostileCount) or 0) > 0
	end)
	local hasSpectators = scope:Computed(function(use: FusionUseFn)
		return (use(spectatorCount) or 0) > 0
	end)

	local suspects: { [number]: number } = {}

	local function refreshList()
		if not Fusion.peek(props.Visible) then
			return
		end
		local query = string.lower(Fusion.peek(searchQuery) or "")

		local defs: { PlayerEntry } = {}
		local hosts: { PlayerEntry } = {}
		local specs: { PlayerEntry } = {}

		for _, p in Players:GetPlayers() do
			local entry = classifyPlayer(p)
			entry.suspectScore = suspects[p.UserId]
			if query ~= "" then
				local matchName = string.find(string.lower(entry.name), query, 1, true) ~= nil
				local matchTeam = string.find(string.lower(entry.teamName), query, 1, true) ~= nil
				if not (matchName or matchTeam) then
					continue
				end
			end

			if entry.isDefender then
				table.insert(defs, entry)
			elseif entry.isSpectator then
				table.insert(specs, entry)
			else
				table.insert(hosts, entry)
			end
		end

		table.sort(defs, sortEntries)
		table.sort(hosts, sortEntries)
		table.sort(specs, sortEntries)

		defendersList:set(defs)
		hostilesList:set(hosts)
		spectatorsList:set(specs)
		defenderCount:set(#defs)
		hostileCount:set(#hosts)
		spectatorCount:set(#specs)
	end

	local connAdded = Players.PlayerAdded:Connect(refreshList)
	local connRemoving = Players.PlayerRemoving:Connect(refreshList)
	table.insert(scope, connAdded)
	table.insert(scope, connRemoving)

	task.spawn(function()
		local remote = ReplicatedStorage:WaitForChild(SUSPECTS_REMOTE_NAME, 60)
		if not remote or not remote:IsA("RemoteEvent") then
			return
		end
		table.insert(scope, remote.OnClientEvent:Connect(function(list)
			table.clear(suspects)
			if type(list) == "table" then
				for _, suspect in list do
					if type(suspect) == "table" and type(suspect.userId) == "number" then
						suspects[suspect.userId] = tonumber(suspect.score) or 0
					end
				end
			end
			refreshList()
		end))
	end)

	local teamConns: { RBXScriptConnection } = {}
	local function bindPlayerTeams()
		for _, c in teamConns do
			c:Disconnect()
		end
		table.clear(teamConns)
		for _, p in Players:GetPlayers() do
			table.insert(teamConns, p:GetPropertyChangedSignal("Team"):Connect(refreshList))
		end
	end

	bindPlayerTeams()
	local connPlayerAddedTeams = Players.PlayerAdded:Connect(function()
		bindPlayerTeams()
		refreshList()
	end)
	table.insert(scope, connPlayerAddedTeams)
	table.insert(scope, function()
		for _, c in teamConns do
			c:Disconnect()
		end
		table.clear(teamConns)
	end)

	local obsVisible = scope:Observer(props.Visible):onChange(function()
		if Fusion.peek(props.Visible) then
			refreshList()
		end
	end)
	table.insert(scope, obsVisible)

	refreshList()

	local isVisible = scope:Computed(function(use: FusionUseFn)
		local v = props.Visible
		if typeof(v) == "table" then
			return use(v :: any) == true
		end
		return v == true
	end)

	local closeHovered = scope:Value(false)

	local header = scope:New("Frame")({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.XLarge,
			}),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("Frame")({
				Name = "TitleGroup",
				Size = UDim2.new(1, -36, 1, 0),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 10),
					}),
					scope:New("ImageLabel")({
						Name = "Icon",
						Size = UDim2.fromOffset(18, 18),
						BackgroundTransparency = 1,
						Image = EYE_ICON,
						ImageColor3 = Color3.fromRGB(0, 160, 255),
					}),
					scope:New("TextLabel")({
						Name = "Title",
						Size = UDim2.fromScale(0, 0),
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						Text = "VDI SCREENWATCH",
						TextColor3 = Theme.Foreground.Primary,
						TextSize = 13,
						Font = Theme.Text.Black,
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
				TextSize = Theme.Text.Medium,
				TextColor3 = scope:Computed(function(use: FusionUseFn)
					return if use(closeHovered) then Theme.Colors.White else Theme.Foreground.Muted
				end),
				AutoButtonColor = false,
				[Fusion.OnEvent("MouseEnter")] = function()
					closeHovered:set(true)
				end,
				[Fusion.OnEvent("MouseLeave")] = function()
					closeHovered:set(false)
				end,
				[Fusion.OnEvent("Activated")] = function()
					props.OnClose()
				end,
			}),
		},
	})

	local modal = scope:New("Frame")({
		Name = "ScreenWatchSelectModal",
		Size = UDim2.fromOffset(460, 480),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("ImageLabel")({
				Name = "Shadow",
				Size = UDim2.fromScale(1.03, 1.03),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://1316045217",
				ImageColor3 = Color3.fromRGB(0, 0, 0),
				ImageTransparency = 0.7,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(32, 32, 96, 96),
				SliceScale = 1,
				ZIndex = 0,
			}),

			scope:New("CanvasGroup")({
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(8, 8, 8),
				BackgroundTransparency = 0.35,
				ZIndex = 1,
				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.XLarge,
					}),
					scope:New("UIStroke")({
						Color = Color3.fromRGB(50, 50, 55),
						Thickness = 1,
						Transparency = 0.5,
					}),
					scope:New("UIGradient")({
						Color = STROKE_GRADIENT_COLOR,
						Rotation = 90,
					}),

					header,

					scope:New("Frame")({
						Name = "ContentBody",
						Size = UDim2.new(1, 0, 1, -44),
						Position = UDim2.fromOffset(0, 44),
						BackgroundTransparency = 1,
						[Fusion.Children] = {
							scope:New("UIPadding")({
								PaddingLeft = UDim.new(0, 14),
								PaddingRight = UDim.new(0, 14),
								PaddingTop = UDim.new(0, 12),
								PaddingBottom = UDim.new(0, 12),
							}),

							scope:New("Frame")({
								Name = "SearchContainer",
								Size = UDim2.new(1, 0, 0, 32),
								BackgroundColor3 = Theme.Colors.Black[850],
								BackgroundTransparency = 0.15,
								BorderSizePixel = 0,
								[Fusion.Children] = {
									scope:New("UICorner")({
										CornerRadius = Theme.Radius.Medium,
									}),
									scope:New("UIStroke")({
										Color = Color3.fromRGB(50, 50, 55),
										Thickness = 1,
									}),
									scope:New("UIPadding")({
										PaddingLeft = UDim.new(0, 10),
										PaddingRight = UDim.new(0, 10),
									}),
									scope:New("TextBox")({
										Name = "SearchInput",
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										PlaceholderText = "Search for a player",
										PlaceholderColor3 = Theme.Colors.Black[400],
										Text = "",
										TextColor3 = Theme.Colors.White,
										TextSize = Theme.Text.Small,
										Font = Theme.Text.Regular,
										TextXAlignment = Enum.TextXAlignment.Left,
										ClearTextOnFocus = false,
										[Fusion.OnEvent("FocusLost")] = function() end,
										[Fusion.OnChange("Text")] = function(newText: string)
											searchQuery:set(newText)
											refreshList()
										end,
									}),
								},
							}),

							scope:New("ScrollingFrame")({
								Name = "PlayerList",
								Size = UDim2.new(1, 0, 1, -40),
								Position = UDim2.fromOffset(0, 40),
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
								ScrollBarThickness = 3,
								ScrollBarImageColor3 = Theme.Colors.Black[500],
								CanvasSize = UDim2.fromScale(0, 0),
								AutomaticCanvasSize = Enum.AutomaticSize.Y,
								[Fusion.Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Vertical,
										SortOrder = Enum.SortOrder.LayoutOrder,
										Padding = UDim.new(0, 5),
									}),

									SectionHeader(scope, {
										Title = "VULTARIANS & INITIATES",
										Count = defenderCount,
										Color = Color3.fromRGB(255, 80, 80),
										Visible = hasDefenders,
									}),

									scope:ForValues(defendersList, function(_use: FusionUseFn, innerScope: FusionScope, entry: PlayerEntry)
										return PlayerSelectRow(innerScope, entry, props.OnSelectTarget)
									end),

									SectionHeader(scope, {
										Title = "HOSTILES",
										Count = hostileCount,
										Color = Color3.fromRGB(0, 190, 255),
										Visible = hasHostiles,
									}),

									scope:ForValues(hostilesList, function(_use: FusionUseFn, innerScope: FusionScope, entry: PlayerEntry)
										return PlayerSelectRow(innerScope, entry, props.OnSelectTarget)
									end),

									SectionHeader(scope, {
										Title = "SPECTATORS",
										Count = spectatorCount,
										Color = Color3.fromRGB(150, 150, 150),
										Visible = hasSpectators,
									}),

									scope:ForValues(spectatorsList, function(_use: FusionUseFn, innerScope: FusionScope, entry: PlayerEntry)
										return PlayerSelectRow(innerScope, entry, props.OnSelectTarget)
									end),
								},
							}),
						},
					}),
				},
			}),
		},
	})

	local overlay = scope:New("Frame")({
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Black[900],
		BackgroundTransparency = Theme.Modal.OverlayTransparency,
		ZIndex = 1,
	})

	return scope:New("ScreenGui")({
		Name = "ScreenWatchSelectGui",
		AutoLocalize = false,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 105,
		IgnoreGuiInset = true,
		Enabled = isVisible,
		[Fusion.Children] = {
			overlay,
			scope:New("Frame")({
				Name = "ModalContainer",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 2,
				[Fusion.Children] = { modal },
			}),
		},
	})
end

return ScreenWatchSelectModal
