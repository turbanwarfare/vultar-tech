--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local LobbyList = require(MainModule.Client.Components.LobbyList)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)
local Network = require(MainModule.Shared.Network)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)

local ArenaLobbyClient = {}

local scope: any = nil
local lobbyGui: ScreenGui? = nil
local playerGui: PlayerGui? = nil
local lobbyData: any = nil
local lobbyVisible: any = nil
local toggleButton: ScreenGui? = nil

local inMatchState: any = nil
local loadingActive: any = nil
local currentArena: number? = nil

local ICON_EXPAND = "rbxassetid://81045999480314"
local ICON_COLLAPSE = "rbxassetid://123792095850614"

function ArenaLobbyClient.createToggleButton(): ()
	if toggleButton then
		return
	end

	local toggleScope = Fusion.scoped(Fusion)
	local isHovered = toggleScope:Value(false)

	local btnBg = toggleScope:Spring(
		toggleScope:Computed(function(use)
			return if use(isHovered) then Theme.Colors.Black[650] else Theme.Colors.Black[800]
		end),
		Theme.Spring.Snappy.Speed
	)

	local btnIcon = toggleScope:Computed(function(use)
		return if use(lobbyVisible) then ICON_COLLAPSE else ICON_EXPAND
	end)

	local isEnabled = toggleScope:Computed(function(use)
		return not use(inMatchState) and not use(loadingActive)
	end)

	toggleButton = toggleScope:New("ScreenGui")({
		Name = "LobbyToggle",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 16,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
		Enabled = isEnabled,
		[Fusion.Children] = {
			toggleScope:New("TextButton")({
				Name = "ToggleBtn",
				Size = UDim2.fromOffset(36, 36),
				Position = UDim2.new(-0.006, 16, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = btnBg,
				BackgroundTransparency = 0.35,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				[Fusion.Children] = {
					Shadow(toggleScope, {
						Size = UDim2.fromScale(1.2, 1.2),
						Position = UDim2.new(0.5, 0, 0.5, 2),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Spread = 8,
						Transparency = 0.65,
						ZIndex = 0,
					}),
					toggleScope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
					toggleScope:New("UIStroke")({
						Color = Theme.Chat.Window.Border,
						Thickness = 1,
						Transparency = 0.5,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					toggleScope:New("ImageLabel")({
						Name = "Icon",
						Size = UDim2.fromOffset(20, 20),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = btnIcon,
						ImageColor3 = Theme.Colors.White,
					}),
				},
				[Fusion.OnEvent("MouseEnter")] = function()
					isHovered:set(true)
				end,
				[Fusion.OnEvent("MouseLeave")] = function()
					isHovered:set(false)
				end,
				[Fusion.OnEvent("Activated")] = function()
					if lobbyVisible then
						lobbyVisible:set(not Fusion.peek(lobbyVisible))
					end
				end,
			}),
		},
	})

	if scope then
		table.insert(scope, function()
			toggleScope:doCleanup()
		end)
	end
end

function ArenaLobbyClient.createUI(): ()
	if lobbyGui then
		return
	end

	scope = Fusion.scoped(Fusion)
	lobbyData = scope:Value({})
	lobbyVisible = scope:Value(true)
	inMatchState = scope:Value(false)
	loadingActive = scope:Value(false)

	local function checkLoading()
		local ls = playerGui and playerGui:FindFirstChild("VultarLoadingScreen")
		local active = false
		if ls and ls:IsA("ScreenGui") and ls.Enabled then
			active = true
		end
		if loadingActive then
			loadingActive:set(active)
		end
	end

	if playerGui then
		local childAddedConn = playerGui.ChildAdded:Connect(function(child)
			if child.Name == "VultarLoadingScreen" then
				checkLoading()
				child:GetPropertyChangedSignal("Enabled"):Connect(checkLoading)
				child.Destroying:Connect(function()
					task.defer(checkLoading)
				end)
			end
		end)
		table.insert(scope, childAddedConn)

		for _, child in playerGui:GetChildren() do
			if child.Name == "VultarLoadingScreen" then
				checkLoading()
				local conn = child:GetPropertyChangedSignal("Enabled"):Connect(checkLoading)
				table.insert(scope, conn)
				local destConn = child.Destroying:Connect(function()
					task.defer(checkLoading)
				end)
				table.insert(scope, destConn)
			end
		end
	end
	local isEnabled = scope:Computed(function(use)
		return not use(inMatchState) and not use(loadingActive)
	end)

	lobbyGui = LobbyList(scope, {
		Visible = lobbyVisible,
		Enabled = isEnabled,
		LobbyData = lobbyData,
		OnPlay = function(arenaNumber: number)
			Network.Spar.sendLobbyJoin(arenaNumber)
		end,
	})

	if playerGui then
		lobbyGui.Parent = playerGui
	end

	table.insert(
		scope,
		Network.Spar.onLobbyState(function(data: any)
			if lobbyData then
				lobbyData:set(data or {})
			end
		end)
	)

	table.insert(
		scope,
		Network.Spar.onMatchStarted(function(arenaNumber: number)
			currentArena = arenaNumber
			inMatchState:set(true)
		end)
	)

	table.insert(
		scope,
		Network.Spar.onArenaStatus(function(arenaNumber: number, statusType: string)
			if statusType == "matchEnd" and currentArena == arenaNumber then
				currentArena = nil
				inMatchState:set(false)
			end
		end)
	)
end

function ArenaLobbyClient.init(): ()
	playerGui = PlayerGuiHelper.waitForPlayerGui()
end

function ArenaLobbyClient.start(): ()
	ArenaLobbyClient.createUI()
	ArenaLobbyClient.createToggleButton()
end

function ArenaLobbyClient.cleanup(): ()
	if scope then
		scope:doCleanup()
		scope = nil
	end
	lobbyGui = nil
	lobbyData = nil
	lobbyVisible = nil
	toggleButton = nil
	inMatchState = nil
	loadingActive = nil
	currentArena = nil
end

return ArenaLobbyClient
