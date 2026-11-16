--!native
--!optimize 2

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)
local Network = require(MainModule.Shared.Network)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local BlurEffect = require(MainModule.Client.Utils.UI.BlurEffect)
local AvatarViewportLoader = require(MainModule.Client.Utils.AvatarViewportLoader)
local PostGameLeaderboard = require(MainModule.Client.Components.WinScreen.PostGameLeaderboard)
local CreditsTracker = require(MainModule.Client.Components.WinScreen.CreditsTracker)
local CreditsModal = require(MainModule.Client.Components.WinScreen.CreditsModal)
local WinCamera = require(MainModule.Client.Components.WinScreen.WinCamera)

local SOUND_VICTORY = "rbxassetid://112637915387187"
local SOUND_LOSS = "rbxassetid://102764785026253"
local MUSIC_VOLUME = 0.5
local MUSIC_FADE_DURATION = 1.0
local MUSIC_FADE_TWEEN_INFO = TweenInfo.new(MUSIC_FADE_DURATION)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type MataroWinScreenProps = {
	VictoryData: Network.VictoryData,
	PlayerFaction: "Defenders" | "Raiders" | "Neutral",
	GameId: string,
	DefendersData: PostGameLeaderboard.FactionData,
	RaidersData: PostGameLeaderboard.FactionData,
	PhaseReached: number,
	PhaseName: string,
	GameTimeElapsed: number,
	OnComplete: () -> (),
}

local VULTAR_ICON = "rbxassetid://98751546690059"
local HOSTILES_ICON = "rbxassetid://0"

local DEFENDER_COLOR_BRIGHT = Color3.fromRGB(220, 80, 80)
local HOSTILE_COLOR_BRIGHT = Color3.fromRGB(80, 145, 235)

local CORNER_RADIUS = 6
local SMALL_CORNER = 4
local SHADOW_SPREAD = 4
local SHADOW_OFFSET_Y = 2
local SHADOW_TRANSPARENCY = 0.7

local AVATAR_WIDTH = 260
local AVATAR_HEIGHT = 320
local AVATAR_WIDTH_CENTER = 300
local AVATAR_HEIGHT_CENTER = 370
local LABEL_CARD_HEIGHT = 38
local STAT_CARD_HEIGHT = 48
local LABEL_CARD_HEIGHT_CENTER = 44
local STAT_CARD_HEIGHT_CENTER = 54
local CARD_SPACING = 12
local MVP_COLUMN_GAP = 40

local INTRO_DELAY = 0.15
local VICTORY_TEXT_DELAY = 0.5
local TEAM_TEXT_DELAY = 0.5
local LOGO_DELAY = 0.5
local INFO_ROW_DELAY = 0.8
local TRANSITION_DELAY = 3.4

local HEADER_APPEAR_DELAY = 0.5
local MVP_POP_DELAY = 0.6
local FINAL_FADE_TIME = 1.2

local SPRING_SPEED = 20
local SPRING_DAMPING = 1

local NEVER_RESTORE_GUIS: { [string]: boolean } = {
	["DeathScreen"] = true,
	["VDIKillReport"] = true,
	["HurtScreen"] = true,
	["LoadingScreen"] = true,
	["StartScreen"] = true,
	["WinScreen"] = true,
	["MataroWinScreen"] = true,
}

local function createBlur(): BlurEffect
	return BlurEffect.getOrCreate("WinScreenBlur", 0)
end

local function disableBackgroundGuis(): { ScreenGui }
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return {}
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return {}
	end

	local disabled: { ScreenGui } = {}
	for _, child in playerGui:GetChildren() do
		if child:IsA("ScreenGui") and child.Name ~= "MataroWinScreen" and child.Enabled then
			child.Enabled = false
			if not NEVER_RESTORE_GUIS[child.Name] then
				table.insert(disabled, child)
			end
		end
	end

	return disabled
end

local function restoreBackgroundGuis(disabled: { ScreenGui }): ()
	for _, gui in disabled do
		if gui and gui.Parent and not NEVER_RESTORE_GUIS[gui.Name] then
			gui.Enabled = true
		end
	end
end

local function formatGameTime(totalSeconds: number): string
	local clamped = math.max(0, totalSeconds)
	local minutes = clamped // 60
	local seconds = math.floor(clamped % 60)
	return string.format("%d:%02d", minutes, seconds)
end

local function loadAvatarModel(userId: number): Model?
	return AvatarViewportLoader.loadFromUserId(userId)
end

local function buildMVPLabelCard(
	scope: FusionScope,
	labelText: string,
	labelH: number,
	avatarW: number,
	columnAlpha: any,
	labelSize: number
): Frame
	return scope:New("Frame")({
		Name = "LabelCardWrapper",
		Size = UDim2.fromOffset(avatarW, labelH),
		Position = UDim2.new(0.5, 0, 0, 52),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			Shadow(scope, {
				Size = UDim2.new(1, SHADOW_SPREAD * 2, 1, SHADOW_SPREAD * 2),
				Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = SHADOW_SPREAD,
				Transparency = scope:Computed(function(use: FusionUseFn)
					return SHADOW_TRANSPARENCY + (1 - use(columnAlpha)) * (1 - SHADOW_TRANSPARENCY)
				end),
				ZIndex = 0,
			}),
			scope:New("Frame")({
				Name = "LabelCard",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Chat.Window.Background,
				BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
					return 0.4 + (1 - use(columnAlpha)) * 0.6
				end),
				ZIndex = 1,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, SMALL_CORNER) }),
					scope:New("UIStroke")({
						Color = Theme.Chat.Window.Border,
						Thickness = 1,
						Transparency = scope:Computed(function(use: FusionUseFn)
							return 0.3 + (1 - use(columnAlpha)) * 0.7
						end),
					}),
					scope:New("TextLabel")({
						Name = "Label",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = labelText,
						TextColor3 = Theme.Colors.White,
						TextTransparency = scope:Computed(function(use: FusionUseFn)
							return 0.1 + (1 - use(columnAlpha)) * 0.9
						end),
						TextSize = labelSize,
						Font = Theme.Text.Bold,
						ZIndex = 2,
					}),
				},
			}),
		},
	})
end

local function buildMVPAvatarCard(scope: FusionScope, avatarH: number, avatarW: number, columnAlpha: any): Frame
	return scope:New("Frame")({
		Name = "AvatarCardWrapper",
		Size = UDim2.fromOffset(avatarW, avatarH),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			Shadow(scope, {
				Size = UDim2.new(1, SHADOW_SPREAD * 2 + 6, 1, SHADOW_SPREAD * 2 + 6),
				Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y + 3),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = SHADOW_SPREAD + 3,
				Transparency = scope:Computed(function(use: FusionUseFn)
					return (SHADOW_TRANSPARENCY - 0.15) + (1 - use(columnAlpha)) * (1 - SHADOW_TRANSPARENCY + 0.15)
				end),
				ZIndex = 0,
			}),
			scope:New("Frame")({
				Name = "AvatarCard",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Chat.Window.Background,
				BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
					return 0.35 + (1 - use(columnAlpha)) * 0.65
				end),
				ClipsDescendants = true,
				ZIndex = 1,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER_RADIUS) }),
					scope:New("UIStroke")({
						Color = Theme.Chat.Window.Border,
						Thickness = 1,
						Transparency = scope:Computed(function(use: FusionUseFn)
							return 0.25 + (1 - use(columnAlpha)) * 0.75
						end),
					}),
					scope:New("Frame")({
						Name = "ViewportContainer",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						ZIndex = 2,
						Visible = scope:Computed(function(use: FusionUseFn)
							return use(columnAlpha) > 0.05
						end),
					}),
				},
			}),
		},
	})
end

local function buildMVPStatCard(
	scope: FusionScope,
	statH: number,
	avatarW: number,
	columnAlpha: any,
	value: number,
	statSuffix: string,
	statSize: number
): Frame
	return scope:New("Frame")({
		Name = "StatCardWrapper",
		Size = UDim2.fromOffset(avatarW, statH),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			Shadow(scope, {
				Size = UDim2.new(1, SHADOW_SPREAD * 2, 1, SHADOW_SPREAD * 2),
				Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = SHADOW_SPREAD,
				Transparency = scope:Computed(function(use: FusionUseFn)
					return SHADOW_TRANSPARENCY + (1 - use(columnAlpha)) * (1 - SHADOW_TRANSPARENCY)
				end),
				ZIndex = 0,
			}),
			scope:New("Frame")({
				Name = "StatCard",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Chat.Window.Background,
				BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
					return 0.4 + (1 - use(columnAlpha)) * 0.6
				end),
				ZIndex = 1,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, SMALL_CORNER) }),
					scope:New("UIStroke")({
						Color = Theme.Chat.Window.Border,
						Thickness = 1,
						Transparency = scope:Computed(function(use: FusionUseFn)
							return 0.3 + (1 - use(columnAlpha)) * 0.7
						end),
					}),
					scope:New("TextLabel")({
						Name = "StatValue",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = `{value} {statSuffix}`,
						TextColor3 = Theme.Colors.White,
						TextTransparency = scope:Computed(function(use: FusionUseFn)
							return 1 - use(columnAlpha)
						end),
						TextSize = statSize,
						Font = Theme.Text.Black,
						ZIndex = 2,
					}),
				},
			}),
		},
	})
end

local function MVPColumn(
	scope: FusionScope,
	labelText: string,
	statSuffix: string,
	player: Network.TopPlayer?,
	visible: any,
	isCenter: boolean
): Frame
	local avatarW = if isCenter then AVATAR_WIDTH_CENTER else AVATAR_WIDTH
	local avatarH = if isCenter then AVATAR_HEIGHT_CENTER else AVATAR_HEIGHT
	local labelH = if isCenter then LABEL_CARD_HEIGHT_CENTER else LABEL_CARD_HEIGHT
	local statH = if isCenter then STAT_CARD_HEIGHT_CENTER else STAT_CARD_HEIGHT
	local usernameSize = if isCenter then 30 else 24
	local labelSize = if isCenter then 16 else 13
	local statSize = if isCenter then 24 else 18

	local columnAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(visible) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local columnScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(visible) then 1 else 0.88
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local userId = player and player.UserId or 0
	local displayName = player and player.DisplayName or "---"
	local value = player and player.Value or 0

	local viewportFrame: ViewportFrame? = nil
	local worldModel: WorldModel? = nil
	local avatarModel: Model? = nil
	local camera: Camera? = nil

	local function setupViewport()
		if not viewportFrame then
			return
		end

		viewportFrame.Ambient = Color3.fromRGB(140, 145, 155)
		viewportFrame.LightColor = Color3.fromRGB(255, 255, 255)
		viewportFrame.LightDirection = Vector3.new(-0.4, -0.7, -0.4).Unit

		worldModel = Instance.new("WorldModel")

		camera = Instance.new("Camera")
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 45
		viewportFrame.CurrentCamera = camera
		camera.Parent = viewportFrame
		worldModel.Parent = viewportFrame

		if userId > 0 then
			task.spawn(function()
				local model = loadAvatarModel(userId)
				if model and worldModel then
					avatarModel = model
					model.Parent = worldModel

					local rootPart = model:FindFirstChild("Torso") :: BasePart?
					if not rootPart then
						rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?
					end
					if rootPart then
						local currentPivot = model:GetPivot()
						model:PivotTo(currentPivot * CFrame.Angles(0, math.rad(180), 0))

						local npcPosition = rootPart.Position
						local cameraDistance = if isCenter then 6.0 else 6.5
						local cameraHeight = if isCenter then 0.6 else 0.8
						local angleRad = math.rad(200)

						local cameraOffset = Vector3.new(
							math.sin(angleRad) * cameraDistance,
							cameraHeight,
							math.cos(angleRad) * cameraDistance
						)
						local cameraPosition = npcPosition + cameraOffset
						local lookAt = npcPosition + Vector3.new(0, 0.2, 0)

						if camera then
							camera.CFrame = CFrame.new(cameraPosition, lookAt)
						end
					end
				end
			end)
		end
	end

	local function cleanup()
		if avatarModel then
			avatarModel:Destroy()
			avatarModel = nil
		end
		if worldModel then
			worldModel:Destroy()
			worldModel = nil
		end
		camera = nil
		viewportFrame = nil
	end

	table.insert(scope, cleanup)

	local totalHeight = labelH + CARD_SPACING + avatarH + CARD_SPACING + statH + 54

	local container = scope:New("Frame")({
		Name = labelText,
		Size = UDim2.fromOffset(avatarW, totalHeight),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("UIScale")({
				Scale = columnScale,
			}),

			scope:New("TextLabel")({
				Name = "Username",
				Size = UDim2.new(1, 0, 0, 44),
				Position = UDim2.fromScale(0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Text = string.upper(displayName),
				TextColor3 = Theme.Colors.White,
				TextTransparency = scope:Computed(function(use: FusionUseFn)
					return 1 - use(columnAlpha)
				end),
				TextSize = usernameSize,
				Font = Theme.Text.Black,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 10,
			}),

			buildMVPLabelCard(scope, labelText, labelH, avatarW, columnAlpha, labelSize),

			(function()
				local card = buildMVPAvatarCard(scope, avatarH, avatarW, columnAlpha)
				card.Position = UDim2.new(0.5, 0, 0, 52 + labelH + CARD_SPACING)
				return card
			end)(),

			(function()
				local card = buildMVPStatCard(scope, statH, avatarW, columnAlpha, value, statSuffix, statSize)
				card.Position = UDim2.new(0.5, 0, 0, 52 + labelH + CARD_SPACING + avatarH + CARD_SPACING)
				return card
			end)(),
		},
	})

	task.defer(function()
		local avatarCardWrapper = container:FindFirstChild("AvatarCardWrapper")
		if avatarCardWrapper then
			local avatarCard = avatarCardWrapper:FindFirstChild("AvatarCard")
			if avatarCard then
				local viewportContainer = avatarCard:FindFirstChild("ViewportContainer")
				if viewportContainer then
					viewportFrame = Instance.new("ViewportFrame")
					viewportFrame.Name = "AvatarViewport"
					viewportFrame.Size = UDim2.fromScale(1, 1)
					viewportFrame.BackgroundTransparency = 1
					viewportFrame.ZIndex = 3
					viewportFrame.Parent = viewportContainer
					setupViewport()
				end
			end
		end
	end)

	return container
end

local function MataroWinScreen(scope: FusionScope, props: MataroWinScreenProps): ScreenGui
	local victoryData = props.VictoryData
	local playerFaction = props.PlayerFaction
	local onComplete = props.OnComplete
	local defendersData = props.DefendersData
	local raidersData = props.RaidersData

	local isPlayerDefender = playerFaction == "Defenders"
	local isPlayerRaider = playerFaction == "Raiders"
	local isSpectator = playerFaction == "Neutral"
	local didPlayerWin = (isPlayerDefender and victoryData.WinningTeam == "Defenders")
		or (isPlayerRaider and victoryData.WinningTeam == "Hostiles")

	local defendersWon = victoryData.WinningTeam == "Defenders"
	local soundId = if didPlayerWin or isSpectator then SOUND_VICTORY else SOUND_LOSS
	local winnerColor = if defendersWon then DEFENDER_COLOR_BRIGHT else HOSTILE_COLOR_BRIGHT
	local winnerIcon = if defendersWon then VULTAR_ICON else HOSTILES_ICON

	local music = Instance.new("Sound")
	music.Name = "WinScreenMusic"
	music.SoundId = soundId
	music.Volume = MUSIC_VOLUME
	music.Parent = SoundService
	music:Play()

	table.insert(scope, function()
		if music then
			local fadeOut = TweenService:Create(music, MUSIC_FADE_TWEEN_INFO, { Volume = 0 })
			fadeOut:Play()
			fadeOut.Completed:Once(function()
				music:Destroy()
			end)
		end
	end)

	WinCamera.start(scope)
	local credits = CreditsTracker(scope)
	local creditsModalOpen = scope:Value(false)

	local teamVictoryText = if defendersWon then "VULTARIAN VICTORY" else "HOSTILE VICTORY"
	local resultText = if didPlayerWin or isSpectator then "VICTORY" else "DEFEAT"
	local gameId = props.GameId
	local phaseName = props.PhaseName
	local gameTimeText = formatGameTime(props.GameTimeElapsed)

	local myTeamTopPlayers = if isPlayerDefender then victoryData.DefenderTopPlayers else victoryData.HostileTopPlayers

	local backgroundVisible = scope:Value(false)
	local victoryTextVisible = scope:Value(false)
	local teamTextVisible = scope:Value(false)
	local logoVisible = scope:Value(false)
	local infoRowVisible = scope:Value(false)
	local headerVisible = scope:Value(false)
	local killsVisible = scope:Value(false)
	local damageVisible = scope:Value(false)
	local healsVisible = scope:Value(false)
	local transitionToLeaderboard = scope:Value(false)
	local leaderboardVisible = scope:Value(false)
	local mvpScreenVisible = scope:Value(false)
	local isClosing = scope:Value(false)
	local tabToggledDuringVictoryPhase = scope:Value(false)
	local currentPhase = scope:Value("loading")

	local compactVictoryVisible = scope:Computed(function(use: FusionUseFn)
		return use(tabToggledDuringVictoryPhase) or use(transitionToLeaderboard) or use(headerVisible)
	end)

	local blur = createBlur()
	table.insert(scope, function()
		if blur and blur.Parent then
			blur.Size = 0
			blur:Destroy()
		end
		BlurEffect.forceRemove("WinScreenBlur")
	end)

	local disabledBackgroundGuis = disableBackgroundGuis()
	local backgroundGuisRestored = false

	local function restoreBackgroundUIOnce(): ()
		if backgroundGuisRestored then
			return
		end

		backgroundGuisRestored = true
		restoreBackgroundGuis(disabledBackgroundGuis)
	end

	table.insert(scope, restoreBackgroundUIOnce)

	local backgroundAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isClosing) then
				return 0
			end
			return if use(backgroundVisible) then 0.72 else 0
		end),
		12,
		1
	)

	local blurSize = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isClosing) then
				return 0
			end
			return if use(backgroundVisible) then 24 else 0
		end),
		12,
		1
	)

	scope:Observer(blurSize):onChange(function()
		blur.Size = Fusion.peek(blurSize)
	end)

	local victoryAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isClosing) then
				return 0
			end
			return if use(victoryTextVisible) or use(tabToggledDuringVictoryPhase) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local victoryY = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(compactVictoryVisible) then
				return 0.03
			end
			return 0.15
		end),
		14,
		1
	)

	local victoryScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(transitionToLeaderboard) then
				return 0.55
			end
			if use(tabToggledDuringVictoryPhase) then
				return 0.7
			end
			if not use(victoryTextVisible) then
				return 0.9
			end
			return 1
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local teamTextAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isClosing) then
				return 0
			end
			return if use(teamTextVisible) or use(tabToggledDuringVictoryPhase) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local logoAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isClosing) or use(compactVictoryVisible) then
				return 0
			end
			return if use(logoVisible) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local logoScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(compactVictoryVisible) then
				return 0.6
			end
			return if use(logoVisible) then 1 else 0.7
		end),
		18,
		1
	)

	local infoRowAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isClosing) or use(compactVictoryVisible) then
				return 0
			end
			return if use(infoRowVisible) then 0.6 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local resultTextOffsetY = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(compactVictoryVisible) then 0 else 140
		end),
		14,
		1
	)

	local teamTextOffsetY = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(compactVictoryVisible) then 84 else 224
		end),
		14,
		1
	)

	local tabInputConnection: RBXScriptConnection?
	local lastTabPressTime = 0
	local TAB_TOGGLE_COOLDOWN = 0.3

	local function setupTabDetection()
		if tabInputConnection then
			tabInputConnection:Disconnect()
			tabInputConnection = nil
		end

		tabInputConnection = UserInputService.InputBegan:Connect(function(input: InputObject, _: boolean)
			if input.KeyCode ~= Enum.KeyCode.Tab then
				return
			end
			if Fusion.peek(currentPhase) ~= "victoryPhase" or Fusion.peek(transitionToLeaderboard) then
				return
			end

			local currentTime = os.clock()
			if currentTime - lastTabPressTime < TAB_TOGGLE_COOLDOWN then
				return
			end
			lastTabPressTime = currentTime

			local leaderboardService = ServiceLocator.Leaderboard()
			if leaderboardService and leaderboardService.IsVisible then
				tabToggledDuringVictoryPhase:set(not leaderboardService:IsVisible())
			end
		end)
	end

	table.insert(scope, function()
		if tabInputConnection then
			tabInputConnection:Disconnect()
			tabInputConnection = nil
		end

		local leaderboardService = ServiceLocator.Leaderboard()
		if leaderboardService and leaderboardService.SetBlocked then
			leaderboardService:SetBlocked(false)
		end
	end)

	local mvpStaggerStarted = false

	local function openMVPScreen()
		if Fusion.peek(mvpScreenVisible) then
			return
		end
		mvpScreenVisible:set(true)
		currentPhase:set("mvpPhase")

		if not mvpStaggerStarted then
			mvpStaggerStarted = true
			task.spawn(function()
				task.wait(HEADER_APPEAR_DELAY)
				killsVisible:set(true)
				task.wait(MVP_POP_DELAY)
				damageVisible:set(true)
				task.wait(MVP_POP_DELAY)
				healsVisible:set(true)
			end)
		end
	end

	local function closeMVPScreen()
		killsVisible:set(false)
		damageVisible:set(false)
		healsVisible:set(false)
		mvpStaggerStarted = false
		mvpScreenVisible:set(false)
		currentPhase:set("leaderboardPhase")
	end

	task.spawn(function()
		task.wait(INTRO_DELAY)
		backgroundVisible:set(true)
		currentPhase:set("victoryPhase")

		setupTabDetection()

		task.wait(VICTORY_TEXT_DELAY)
		victoryTextVisible:set(true)
		task.wait(TEAM_TEXT_DELAY)
		teamTextVisible:set(true)
		task.wait(LOGO_DELAY)
		logoVisible:set(true)
		task.wait(INFO_ROW_DELAY)
		infoRowVisible:set(true)
		task.wait(TRANSITION_DELAY)

		if tabInputConnection then
			tabInputConnection:Disconnect()
			tabInputConnection = nil
		end

		local leaderboardService = ServiceLocator.Leaderboard()
		if leaderboardService and leaderboardService.SetBlocked then
			leaderboardService:SetBlocked(true)
		end

		victoryTextVisible:set(true)
		teamTextVisible:set(true)
		transitionToLeaderboard:set(true)
		currentPhase:set("leaderboardPhase")
		task.wait(HEADER_APPEAR_DELAY)
		headerVisible:set(true)
		leaderboardVisible:set(true)
	end)

	local function closeScreen()
		if Fusion.peek(isClosing) then
			return
		end
		isClosing:set(true)
		currentPhase:set("closing")

		blur.Size = 0
		BlurEffect.forceRemove("WinScreenBlur")

		if tabInputConnection then
			tabInputConnection:Disconnect()
			tabInputConnection = nil
		end

		leaderboardVisible:set(false)
		mvpScreenVisible:set(false)

		local leaderboardService = ServiceLocator.Leaderboard()
		if leaderboardService and leaderboardService.SetBlocked then
			leaderboardService:SetBlocked(false)
		end

		restoreBackgroundUIOnce()

		task.delay(FINAL_FADE_TIME, function()
			BlurEffect.forceRemove("WinScreenBlur")
			if onComplete then
				onComplete()
			end
		end)
	end

	local columnHeightSide = LABEL_CARD_HEIGHT + CARD_SPACING + AVATAR_HEIGHT + CARD_SPACING + STAT_CARD_HEIGHT + 54
	local columnHeightCenter = LABEL_CARD_HEIGHT_CENTER
		+ CARD_SPACING
		+ AVATAR_HEIGHT_CENTER
		+ CARD_SPACING
		+ STAT_CARD_HEIGHT_CENTER
		+ 54
	local maxColumnHeight = math.max(columnHeightSide, columnHeightCenter)
	local totalMVPWidth = AVATAR_WIDTH + MVP_COLUMN_GAP + AVATAR_WIDTH_CENTER + MVP_COLUMN_GAP + AVATAR_WIDTH

	local leaderboardBodyVisible = scope:Computed(function(use: FusionUseFn)
		return use(leaderboardVisible) and not use(mvpScreenVisible)
	end)

	return scope:New("ScreenGui")({
		Name = "MataroWinScreen",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Background",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
					return 1 - use(backgroundAlpha)
				end),
				Visible = scope:Computed(function(use: FusionUseFn)
					return use(backgroundAlpha) > 0.001
				end),
				BorderSizePixel = 0,
				ZIndex = 1,
			}),

			scope:New("Frame")({
				Name = "VictorySection",
				Size = UDim2.fromScale(1, 1),
				Position = scope:Computed(function(use: FusionUseFn)
					return UDim2.fromScale(0.5, use(victoryY))
				end),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				ZIndex = 6,

				[Fusion.Children] = {
					scope:New("UIScale")({
						Scale = victoryScale,
					}),

					scope:New("Frame")({
						Name = "LogoContainer",
						Size = UDim2.fromOffset(120, 120),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIScale")({
								Scale = logoScale,
							}),

							scope:New("ImageLabel")({
								Name = "TeamLogo",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Image = winnerIcon,
								ImageColor3 = winnerColor,
								ImageTransparency = scope:Computed(function(use: FusionUseFn)
									return 0.08 + (1 - use(logoAlpha)) * 0.92
								end),
								ScaleType = Enum.ScaleType.Fit,
							}),
						},
					}),

					scope:New("TextLabel")({
						Name = "ResultText",
						Size = UDim2.fromOffset(700, 80),
						Position = scope:Computed(function(use: FusionUseFn)
							return UDim2.new(0.5, 0, 0, use(resultTextOffsetY))
						end),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Text = resultText,
						TextColor3 = Theme.Colors.White,
						TextTransparency = scope:Computed(function(use: FusionUseFn)
							return 1 - use(victoryAlpha)
						end),
						TextSize = 76,
						Font = Theme.Text.Black,
					}),

					scope:New("TextLabel")({
						Name = "TeamVictoryText",
						Size = UDim2.fromOffset(700, 30),
						Position = scope:Computed(function(use: FusionUseFn)
							return UDim2.new(0.5, 0, 0, use(teamTextOffsetY))
						end),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Text = teamVictoryText,
						TextColor3 = winnerColor,
						TextTransparency = scope:Computed(function(use: FusionUseFn)
							return 0.1 + (1 - use(teamTextAlpha)) * 0.9
						end),
						TextSize = 18,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),

					scope:New("Frame")({
						Name = "InfoStack",
						Size = UDim2.fromOffset(500, 50),
						Position = UDim2.new(0.5, 0, 0, 270),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Top,
								Padding = UDim.new(0, 6),
							}),

							scope:New("TextLabel")({
								Name = "PhaseName",
								Size = UDim2.new(1, 0, 0, 18),
								BackgroundTransparency = 1,
								Text = string.upper(phaseName),
								TextColor3 = Theme.Foreground.Primary,
								TextTransparency = scope:Computed(function(use: FusionUseFn)
									return 1 - use(infoRowAlpha) * 0.7
								end),
								TextSize = 12,
								Font = Theme.Text.Bold,
								LayoutOrder = 1,
							}),

							scope:New("TextLabel")({
								Name = "GameDetails",
								Size = UDim2.new(1, 0, 0, 16),
								BackgroundTransparency = 1,
								Text = gameTimeText .. "   |   " .. gameId,
								TextColor3 = Theme.Foreground.Secondary,
								TextTransparency = scope:Computed(function(use: FusionUseFn)
									return 1 - use(infoRowAlpha) * 0.5
								end),
								TextSize = 11,
								Font = Theme.Text.Semibold,
								LayoutOrder = 2,
							}),
						},
					}),
				},
			}),

			scope:Computed(function(use: FusionUseFn)
				if not use(transitionToLeaderboard) then
					return nil
				end
				return PostGameLeaderboard(scope, {
					DefendersData = defendersData,
					RaidersData = raidersData,
					DefendersWon = defendersWon,
					TopPlayers = myTeamTopPlayers,
					Visible = leaderboardBodyVisible,
					OnClose = closeScreen,
					OnOpenMVP = openMVPScreen,
					CreditsBalance = credits.Balance,
					CreditsEarned = credits.Earned,
					CreditsReward = credits.Reward,
					CreditsPurchasable = credits.Purchasable,
					OnBalanceClick = function()
						creditsModalOpen:set(true)
					end,
				})
			end),

			scope:New("Frame")({
				Name = "MVPScreen",
				Size = UDim2.fromScale(1, 0.85),
				Position = UDim2.fromScale(0.5, 0.09),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				ZIndex = 8,
				Visible = scope:Computed(function(use: FusionUseFn)
					return use(mvpScreenVisible)
				end),

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "MVPRow",
						Size = UDim2.fromOffset(totalMVPWidth, maxColumnHeight),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("Frame")({
								Name = "DamageWrapper",
								Size = UDim2.fromOffset(AVATAR_WIDTH, columnHeightSide),
								Position = UDim2.fromScale(0, 0.5),
								AnchorPoint = Vector2.new(0, 0.5),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									MVPColumn(
										scope,
										"TOP DAMAGE",
										"DAMAGE",
										myTeamTopPlayers and myTeamTopPlayers.Damage,
										damageVisible,
										false
									),
								},
							}),

							scope:New("Frame")({
								Name = "KillsWrapper",
								Size = UDim2.fromOffset(AVATAR_WIDTH_CENTER, columnHeightCenter),
								Position = UDim2.fromScale(0.5, 0.5),
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									MVPColumn(
										scope,
										"TOP KILLS",
										"KILLS",
										myTeamTopPlayers and myTeamTopPlayers.Kills,
										killsVisible,
										true
									),
								},
							}),

							scope:New("Frame")({
								Name = "HealsWrapper",
								Size = UDim2.fromOffset(AVATAR_WIDTH, columnHeightSide),
								Position = UDim2.fromScale(1, 0.5),
								AnchorPoint = Vector2.new(1, 0.5),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									MVPColumn(
										scope,
										"TOP HEALS",
										"HEALS",
										myTeamTopPlayers and myTeamTopPlayers.Heals,
										healsVisible,
										false
									),
								},
							}),
						},
					}),

					scope:New("TextButton")({
						Name = "ReturnButton",
						Size = UDim2.fromOffset(180, 44),
						Position = UDim2.fromScale(0.5, 0.94),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Theme.Chat.Window.Background,
						BackgroundTransparency = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								return if use(mvpScreenVisible) then Theme.Chat.Window.BackgroundTransparency else 1
							end),
							SPRING_SPEED,
							SPRING_DAMPING
						),
						Text = "RETURN",
						TextColor3 = Theme.Colors.White,
						TextTransparency = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								return if use(mvpScreenVisible) then 0 else 1
							end),
							SPRING_SPEED,
							SPRING_DAMPING
						),
						TextSize = 16,
						Font = Theme.Text.Bold,
						AutoButtonColor = false,

						[Fusion.OnEvent("Activated")] = closeMVPScreen,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
							scope:New("UIStroke")({
								Color = Theme.Colors.White,
								Thickness = 1.5,
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Transparency = scope:Spring(
									scope:Computed(function(use: FusionUseFn)
										return if use(mvpScreenVisible) then 0.4 else 1
									end),
									SPRING_SPEED,
									SPRING_DAMPING
								),
							}),
						},
					}),
				},
			}),

			CreditsModal(scope, { Visible = creditsModalOpen }),
		},
	})
end

return MataroWinScreen
