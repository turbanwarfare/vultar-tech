--!native
--!optimize 2

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

local peek = Fusion.peek

export type LobbyInfo = {
	leftPlayerId: number,
	leftPlayerName: string,
	rightPlayerId: number,
	rightPlayerName: string,
	inMatch: boolean,
}

export type LobbyListProps = {
	Visible: FusionValue<boolean>,
	Enabled: FusionCanBeState<boolean>?,
	LobbyData: FusionValue<{ [number]: LobbyInfo }>,
	OnPlay: ((arenaNumber: number) -> ())?,
}

local PANEL_WIDTH = 320
local CARD_HEIGHT = 80
local SLOT_SIZE = 40
local CARD_PADDING = 8

local function AvatarSlot(scope: FusionScope, playerIdVal: FusionCanBeState<number>, playerNameVal: FusionCanBeState<string>): Frame
	local isFilled = scope:Computed(function(use)
		return use(playerIdVal) > 0
	end)

	return scope:New("Frame")({
		Name = scope:Computed(function(use)
			return if use(isFilled) then "FilledSlot_" .. use(playerNameVal) else "EmptySlot"
		end),
		Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
		BackgroundColor3 = scope:Computed(function(use)
			return if use(isFilled) then Theme.Colors.Black[800] else Theme.Lobby.SlotBackground
		end),
		BackgroundTransparency = scope:Computed(function(use)
			return if use(isFilled) then 0.5 else 0
		end),
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
			scope:Computed(function(use)
				if not use(isFilled) then
					return nil
				end
				return scope:New("ImageLabel")({
					Name = "Avatar",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(use(playerIdVal)) .. "&w=150&h=150",
					[Fusion.Children] = {
						scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
					},
				})
			end),
		},
	})
end

local function LobbyCard(
	scope: FusionScope,
	arenaNumber: number,
	infoVal: FusionValue<LobbyInfo?>,
	onPlay: ((number) -> ())?,
	staggerIndex: number,
	lobbyVisible: FusionValue<boolean>,
	cardOffsetVal: FusionValue<number>
): Frame
	local isPlayHovered = scope:Value(false)
	local playScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isPlayHovered) then 0.96 else 1
		end),
		Theme.Spring.Snappy.Speed
	)

	local playBg = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isPlayHovered) then Theme.Lobby.AccentHover else Theme.Lobby.AccentColor
		end),
		Theme.Spring.Snappy.Speed
	)

	local cardOffsetSpring = scope:Spring(cardOffsetVal, 22, 0.85)

	local cardPosition = scope:Computed(function(use: FusionUseFn)
		local visible = use(lobbyVisible)
		if not visible then
			return UDim2.fromOffset(-360, 0)
		end
		return UDim2.fromOffset(use(cardOffsetSpring), 0)
	end)

	task.spawn(function()
		task.wait(staggerIndex * 0.06)
		cardOffsetVal:set(0)
	end)

	local leftPlayerId = scope:Computed(function(use)
		local info = use(infoVal)
		return if info then info.leftPlayerId else 0
	end)
	local leftPlayerName = scope:Computed(function(use)
		local info = use(infoVal)
		return if info then info.leftPlayerName else ""
	end)
	local rightPlayerId = scope:Computed(function(use)
		local info = use(infoVal)
		return if info then info.rightPlayerId else 0
	end)
	local rightPlayerName = scope:Computed(function(use)
		local info = use(infoVal)
		return if info then info.rightPlayerName else ""
	end)

	local filledCount = scope:Computed(function(use)
		local c = 0
		if use(leftPlayerId) > 0 then
			c += 1
		end
		if use(rightPlayerId) > 0 then
			c += 1
		end
		return c
	end)

	return scope:New("Frame")({
		Name = "LobbyCard_" .. tostring(arenaNumber),
		Size = UDim2.new(1, -10, 0, CARD_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "CardContent",
				Size = UDim2.fromScale(1, 1),
				Position = cardPosition,
				BackgroundColor3 = Theme.Lobby.CardBackground,
				BackgroundTransparency = 0.35,
				BorderSizePixel = 0,
				ZIndex = 2,
				[Fusion.Children] = {
					Shadow(scope, {
						Size = UDim2.fromScale(1.1, 1.4),
						Position = UDim2.new(0.5, 0, 0.5, 2),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Spread = 8,
						Transparency = 0.65,
						ZIndex = 1,
					}),

					scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, CARD_PADDING),
						PaddingRight = UDim.new(0, CARD_PADDING),
						PaddingTop = UDim.new(0, CARD_PADDING),
						PaddingBottom = UDim.new(0, CARD_PADDING),
					}),

					scope:New("TextLabel")({
						Name = "Header",
						Size = UDim2.new(0.7, 0, 0, 16),
						Position = UDim2.fromOffset(4, 2),
						BackgroundTransparency = 1,
						Text = "SPAR (1v1) - ARENA " .. tostring(arenaNumber),
						TextColor3 = Theme.Lobby.HeaderText,
						TextSize = Theme.Text.Small,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
						ZIndex = 3,
					}),

					scope:New("TextLabel")({
						Name = "SlotCounter",
						Size = UDim2.new(0.3, 0, 0, 16),
						Position = UDim2.new(1, -4, 0, 2),
						AnchorPoint = Vector2.new(1, 0),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use)
							return tostring(use(filledCount)) .. "/2"
						end),
						TextColor3 = Theme.Lobby.MutedText,
						TextSize = Theme.Text.Small,
						Font = Theme.Text.Regular,
						TextXAlignment = Enum.TextXAlignment.Right,
						TextYAlignment = Enum.TextYAlignment.Center,
						ZIndex = 3,
					}),

					scope:New("Frame")({
						Name = "SlotsContainer",
						Size = UDim2.new(0.6, 0, 0, SLOT_SIZE),
						Position = UDim2.fromOffset(4, 26),
						BackgroundTransparency = 1,
						ZIndex = 3,
						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 8),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							AvatarSlot(scope, leftPlayerId, leftPlayerName),
							scope:New("TextLabel")({
								Name = "VS",
								Size = UDim2.fromOffset(24, SLOT_SIZE),
								BackgroundTransparency = 1,
								Text = "vs",
								TextColor3 = Color3.fromRGB(220, 220, 220),
								TextSize = 18,
								Font = Theme.Text.Semibold,
								TextXAlignment = Enum.TextXAlignment.Center,
								TextYAlignment = Enum.TextYAlignment.Center,
							}),
							AvatarSlot(scope, rightPlayerId, rightPlayerName),
						},
					}),

					scope:New("TextButton")({
						Name = "PlayButton",
						Size = UDim2.fromOffset(80, 28),
						Position = UDim2.new(1, -4, 0, 32),
						AnchorPoint = Vector2.new(1, 0),
						BackgroundColor3 = playBg,
						BorderSizePixel = 0,
						Text = "PLAY",
						TextColor3 = Theme.Lobby.ButtonText,
						TextSize = 16,
						Font = Theme.Text.Bold,
						AutoButtonColor = false,
						ZIndex = 3,
						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
							scope:New("UIScale")({ Scale = playScale }),
						},
						[Fusion.OnEvent("MouseEnter")] = function()
							isPlayHovered:set(true)
						end,
						[Fusion.OnEvent("MouseLeave")] = function()
							isPlayHovered:set(false)
						end,
						[Fusion.OnEvent("Activated")] = function()
							if onPlay then
								onPlay(arenaNumber)
							end
						end,
					}),
				},
			}),
		},
	})
end

function LobbyList(scope: FusionScope, props: LobbyListProps): ScreenGui
	local isVisible = props.Visible

	local arenaDataValues = {}
	for i = 1, 8 do
		arenaDataValues[i] = scope:Value(nil)
	end

	scope:Observer(props.LobbyData):onChange(function()
		local data = peek(props.LobbyData) or {}
		for i = 1, 8 do
			arenaDataValues[i]:set(data[i])
		end
	end)

	local initialData = peek(props.LobbyData) or {}
	for i = 1, 8 do
		arenaDataValues[i]:set(initialData[i])
	end

	local cardCache = {}
	local refreshTrigger = scope:Value(0)

	local function safeOnPlay(arenaNumber: number)
		local enabledVal = props.Enabled
		local isEnabled = true
		if enabledVal then
			isEnabled = type(enabledVal) == "table" and peek(enabledVal) or enabledVal
		end
		if isEnabled and props.OnPlay then
			props.OnPlay(arenaNumber)
		end
	end

	local scrollContent = scope:Computed(function(use: FusionUseFn)
		use(refreshTrigger)

		local cards = {}
		local count = 0

		for arenaNumber = 1, 8 do
			local infoVal = arenaDataValues[arenaNumber]
			local info = use(infoVal)
			local inMatch = info and info.inMatch or false
			local leftPlayerId = info and info.leftPlayerId or 0
			local rightPlayerId = info and info.rightPlayerId or 0
			local hasPerson = leftPlayerId > 0 or rightPlayerId > 0

			local isValid = info and not inMatch and hasPerson

			if isValid then
				count += 1
				local cached = cardCache[arenaNumber]
				if cached then
					if cached.removing then
						cached.removing = false
						cached.offsetState:set(0)
					end
					table.insert(cards, cached.frame)
				else
					local offsetState = scope:Value(-360)
					local frame = LobbyCard(scope, arenaNumber, infoVal, safeOnPlay, count, isVisible, offsetState)
					cardCache[arenaNumber] = {
						frame = frame,
						offsetState = offsetState,
						removing = false,
					}
					table.insert(cards, frame)
				end
			else
				local cached = cardCache[arenaNumber]
				if cached then
					if not cached.removing then
						cached.removing = true
						cached.offsetState:set(-360)
						task.delay(0.35, function()
							local currentCached = cardCache[arenaNumber]
							if currentCached and currentCached.removing then
								cardCache[arenaNumber] = nil
								refreshTrigger:set(peek(refreshTrigger) + 1)
							end
						end)
					end
					table.insert(cards, cached.frame)
				end
			end
		end

		return cards
	end)

	local panel = scope:New("Frame")({
		Name = "LobbyPanel",
		Size = UDim2.new(0, PANEL_WIDTH, 0.5, -34),
		Position = UDim2.new(-0.006, 16, 0.489, 32),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		[Fusion.Children] = {
			scope:New("ScrollingFrame")({
				Name = "LobbyScroll",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Theme.Colors.Black[500],
				CanvasSize = UDim2.fromScale(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ClipsDescendants = false,
				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 12),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					scrollContent,
				},
			}),
		},
	})

	return scope:New("ScreenGui")({
		Name = "MatchmakingLobby",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 15,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = props.Enabled,
		[Fusion.Children] = {
			panel,
		},
	})
end

return LobbyList
