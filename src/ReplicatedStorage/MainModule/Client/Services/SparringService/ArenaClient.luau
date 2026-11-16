--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local Workspace = workspace
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local localPlayer = Players.LocalPlayer

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Icon = require(Packages:WaitForChild("TopbarPlus", 5))
local Theme = require(MainModule.Shared.UI.Theme)
local SparConfig = require(MainModule.Shared.Config.SparConfig)
local Network = require(MainModule.Shared.Network)
local ArenaHUD = require(script.Parent.ArenaHUD)

local ArenaClient = {}

local FAST_IN = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
local SLOW_OUT = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local BACK_OUT = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local BACK_OUT_ALT = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local EXPO_OUT_ALT = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local FAST_IN_ALT = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
local SLOW_OUT_ALT = TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local SNAPPY_PUNCH_IN = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SNAPPY_ALPHA_IN = TweenInfo.new(0.12, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local SNAPPY_PUNCH_OUT = TweenInfo.new(0.10, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

local activeGUIs: { [number]: SurfaceGui } = {}
local activeLowerGUIs: { [number]: SurfaceGui } = {}
local countdownTimers: { [number]: { thread: thread?, currentCount: number, isCountingDown: boolean } } = {}
local lastLocalSelectionTimes = {}
local isSoloMode = false
local soloPlayerName = "AI_Player"

local lastSelections = {
	Gun = SparConfig.DEFAULT_GUN,
	Health = SparConfig.DEFAULT_HEALTH,
	Rounds = SparConfig.DEFAULT_ROUNDS,
	Forcefield = SparConfig.DEFAULT_FORCEFIELD_DURATION,
	Versus = true,
}

local activeVersusHUDs: { [number]: ScreenGui } = {}
local transitionOverlays: { [number]: ScreenGui } = {}
local hudIsSuddenDeathValues: { [number]: any } = {}

local hudScoreValues: { [number]: { p1: any, p2: any } } = {}
local hudTimerValues: { [number]: any } = {}
local hudVisibleValues: { [number]: any } = {}
local hudModeLabelValues: { [number]: any } = {}
local hudScopes: { [number]: any } = {}
local hudFirstToValues: { [number]: any } = {}

local localPlayerOnPad: { [number]: boolean } = {}
local playerOnPadValues: { [number]: any } = {}
local matchActiveValues: { [number]: any } = {}
local isCountingDownValues: { [number]: any } = {}
local topbarIcons: { [number]: any } = {}
local countdownValueValues: { [number]: any } = {}
local lastChangeTextValues: { [number]: any } = {}
local playersCountOnPadsValues: { [number]: any } = {}

local selectedMapValues: { [number]: any } = {}
local selectedGunValues: { [number]: any } = {}
local selectedHealthValues: { [number]: any } = {}
local selectedRoundsValues: { [number]: any } = {}
local selectedForcefieldValues: { [number]: any } = {}
local showVersusGUIValues: { [number]: any } = {}
local instantRespawnValues: { [number]: any } = {}

local arenaStatus: {
	[number]: {
		inMatch: boolean,
		p1: string,
		p2: string,
		p1Wins: number,
		p2Wins: number,
		round: number,
		totalRounds: number,
		map: string,
	},
} =
	{}

local PULSE_TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local highlightTweens: { [Highlight]: Tween } = {}

local function startHighlightTween(hl: Highlight)
	if highlightTweens[hl] then
		return
	end
	local tween = TweenService:Create(hl, PULSE_TWEEN_INFO, { FillTransparency = 1, OutlineTransparency = 1 })
	tween:Play()
	highlightTweens[hl] = tween
end

local function stopHighlightTween(hl: Highlight)
	local tween = highlightTweens[hl]
	if tween then
		tween:Cancel()
		tween:Destroy()
		highlightTweens[hl] = nil
	end
end

local function cleanupSpawnProtectionLocally(arenaNumber: number)
	local status = arenaStatus[arenaNumber]
	if not status then
		return
	end

	local function cleanPlayer(pName: string)
		local p = Players:FindFirstChild(pName)
		if p and p.Character then
			for _, child in p.Character:GetChildren() do
				if child:IsA("ForceField") then
					child:Destroy()
				end
			end

			local hl = p.Character:FindFirstChild("SpawnHighlight")
			if hl then
				stopHighlightTween(hl)
				hl:Destroy()
			end
		end
	end

	cleanPlayer(status.p1)
	cleanPlayer(status.p2)
end

CollectionService:GetInstanceAddedSignal("SpawnHighlight"):Connect(function(instance)
	if instance:IsA("Highlight") then
		startHighlightTween(instance)
	end
end)

CollectionService:GetInstanceRemovedSignal("SpawnHighlight"):Connect(function(instance)
	if instance:IsA("Highlight") then
		stopHighlightTween(instance)
	end
end)

for _, instance in CollectionService:GetTagged("SpawnHighlight") do
	if instance:IsA("Highlight") then
		startHighlightTween(instance)
	end
end

local overlayScopes: { [number]: any } = {}
local matchRevealTimes: { [number]: number } = {}

local MAP_NAMES = SparConfig.MAP_NAMES
local GUN_NAMES = SparConfig.GUN_NAMES
local HEALTH_OPTIONS = SparConfig.HEALTH_OPTIONS
local ROUNDS_OPTIONS = SparConfig.ROUNDS_OPTIONS

local MAX_CUSTOM_HEALTH = SparConfig.MAX_CUSTOM_HEALTH
local MAX_CUSTOM_ROUNDS = SparConfig.MAX_CUSTOM_ROUNDS

function ArenaClient.enableSoloMode()
	isSoloMode = true
	print("[ArenaClient] Solo mode enabled - simulating AI opponent")
end

function ArenaClient.disableSoloMode()
	isSoloMode = false
	print("[ArenaClient] Solo mode disabled")
end

function ArenaClient.setSoloPlayerName(name: string)
	soloPlayerName = name
end

local function simulateAISelection(arenaNumber: number)
	if not isSoloMode then
		return
	end
	task.wait(Random.new():NextInteger(1, 3))
	local options = {
		map = MAP_NAMES[Random.new():NextInteger(1, #MAP_NAMES)],
		gun = GUN_NAMES[Random.new():NextInteger(1, #GUN_NAMES)],
		health = HEALTH_OPTIONS[Random.new():NextInteger(1, #HEALTH_OPTIONS)],
		rounds = ROUNDS_OPTIONS[Random.new():NextInteger(1, #ROUNDS_OPTIONS)],
	}
	for category, value in options do
		task.wait(0.5)
		Network.Spar.sendSelectOption(arenaNumber, category, value)
	end
end

local function updateHUDState(arenaNumber: number, data: { [string]: any })
	local scores = hudScoreValues[arenaNumber]
	if scores then
		if data.p1Wins ~= nil then
			scores.p1:set(data.p1Wins)
		end
		if data.p2Wins ~= nil then
			scores.p2:set(data.p2Wins)
		end
	end
	if data.timerText ~= nil and hudTimerValues[arenaNumber] then
		hudTimerValues[arenaNumber]:set(data.timerText)
	end
	if data.modeLabel ~= nil and hudModeLabelValues[arenaNumber] then
		hudModeLabelValues[arenaNumber]:set(data.modeLabel)
	end

	if data.totalRounds ~= nil and hudFirstToValues[arenaNumber] then
		hudFirstToValues[arenaNumber]:set(data.totalRounds)
	end
	if data.isSuddenDeath ~= nil and hudIsSuddenDeathValues[arenaNumber] then
		hudIsSuddenDeathValues[arenaNumber]:set(data.isSuddenDeath)
	end
end

local function teardownVersusHUD(arenaNumber: number)
	local visValue = hudVisibleValues[arenaNumber]
	if visValue then
		visValue:set(false)
	end

	task.delay(0.5, function()
		local hud = activeVersusHUDs[arenaNumber]
		if hud and hud.Parent then
			hud:Destroy()
		end
		local scope = hudScopes[arenaNumber]
		if scope then
			Fusion.doCleanup(scope)
		end
		activeVersusHUDs[arenaNumber] = nil
		hudScopes[arenaNumber] = nil
		hudScoreValues[arenaNumber] = nil
		hudTimerValues[arenaNumber] = nil
		hudVisibleValues[arenaNumber] = nil
		hudModeLabelValues[arenaNumber] = nil
		hudFirstToValues[arenaNumber] = nil
		hudIsSuddenDeathValues[arenaNumber] = nil
	end)

	if topbarIcons[arenaNumber] then
		topbarIcons[arenaNumber]:destroy()
		topbarIcons[arenaNumber] = nil
	end
end

local function tween(instance: Instance, info: TweenInfo, props: { [string]: any })
	local t = TweenService:Create(instance, info, props)
	t:Play()
	t.Completed:Wait()
	t:Destroy()
end

local function playTweens(tweens: { Tween })
	local done = 0
	local total = #tweens
	local thread = coroutine.running()
	for _, t in tweens do
		t.Completed:Once(function()
			done += 1
			if done >= total then
				task.spawn(thread)
			end
		end)
		t:Play()
	end
	if done < total then
		coroutine.yield()
	end
end

local function destroyTweens(tweens: { Tween })
	for _, t in tweens do
		t:Destroy()
	end
end

local function tweenAll(tweens: { Tween })
	playTweens(tweens)
	destroyTweens(tweens)
end

local activeTimers: { [number]: thread } = {}

local function startLocalTimer(arenaNumber: number)
	if activeTimers[arenaNumber] then
		task.cancel(activeTimers[arenaNumber])
	end

	updateHUDState(arenaNumber, { timerText = "0:00" })

	activeTimers[arenaNumber] = task.spawn(function()
		local elapsed = 0
		while true do
			task.wait(1)
			if not arenaStatus[arenaNumber] or not arenaStatus[arenaNumber].inMatch then
				activeTimers[arenaNumber] = nil
				break
			end
			elapsed += 1
			local mins = (elapsed // 60)
			local secs = math.floor(elapsed % 60)
			local timerText = string.format("%d:%02d", mins, secs)
			updateHUDState(arenaNumber, { timerText = timerText })
		end
	end)
end

local function stopLocalTimer(arenaNumber: number)
	if activeTimers[arenaNumber] then
		task.cancel(activeTimers[arenaNumber])
		activeTimers[arenaNumber] = nil
	end
end

local lastCoverRevealSequence: { [number]: number } = {}

local function playTransitionSequence(
	arenaNumber: number,
	mapName: string,
	_gunName: string,
	_healthName: string,
	rounds: number,
	showVersusGUI: boolean,
	p1Player: Player?,
	p2Player: Player?,
	revealAt: number,
	forcefieldDuration: number
)
	local playerGui = localPlayer and localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	local sequenceId = os.clock()
	lastCoverRevealSequence[arenaNumber] = sequenceId

	if transitionOverlays[arenaNumber] then
		transitionOverlays[arenaNumber]:Destroy()
		transitionOverlays[arenaNumber] = nil
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ArenaTransition_" .. arenaNumber
	screenGui.AutoLocalize = false
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 250
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui
	transitionOverlays[arenaNumber] = screenGui

	local pillFrame = Instance.new("Frame")
	pillFrame.Name = "PillFrame"
	pillFrame.Size = UDim2.fromOffset(110, 110)
	pillFrame.Position = UDim2.fromScale(0.5, 0.5)
	pillFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	pillFrame.BackgroundColor3 = Theme.Chat.Window.Background
	pillFrame.BackgroundTransparency = Theme.Chat.Window.BackgroundTransparency
	pillFrame.BorderSizePixel = 0
	pillFrame.ZIndex = 8
	pillFrame.Parent = screenGui

	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = Theme.Radius.Large
	pillCorner.Parent = pillFrame

	local pillStroke = Instance.new("UIStroke")
	pillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	pillStroke.Color = Theme.Chat.Window.Border
	pillStroke.Thickness = 1
	pillStroke.Transparency = 0
	pillStroke.Parent = pillFrame

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0
	uiScale.Parent = pillFrame

	local numberLabel = Instance.new("TextLabel")
	numberLabel.Name = "Number"
	numberLabel.Size = UDim2.fromScale(1, 1)
	numberLabel.BackgroundTransparency = 1
	numberLabel.Text = ""
	numberLabel.TextColor3 = Theme.Colors.White
	numberLabel.TextTransparency = 1
	numberLabel.Font = Theme.Text.Black
	numberLabel.TextScaled = true
	numberLabel.ZIndex = 10
	numberLabel.Parent = pillFrame

	local vsLabel = Instance.new("TextLabel")
	vsLabel.Name = "VSLabel"
	vsLabel.Size = UDim2.fromScale(1, 0.08)
	vsLabel.Position = UDim2.fromScale(0, 0.43)
	vsLabel.BackgroundTransparency = 1
	vsLabel.Text = "VS"
	vsLabel.TextColor3 = Theme.Colors.SilverBright
	vsLabel.TextTransparency = 1
	vsLabel.Font = Theme.Text.Black
	vsLabel.TextScaled = true
	vsLabel.ZIndex = 8
	vsLabel.Parent = screenGui

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Size = UDim2.fromScale(1, 0.025)
	subtitleLabel.Position = UDim2.fromScale(0, 0.525)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = string.upper(mapName)
	subtitleLabel.TextColor3 = Theme.Foreground.Muted
	subtitleLabel.TextTransparency = 1
	subtitleLabel.Font = Theme.Text.Bold
	subtitleLabel.TextScaled = true
	subtitleLabel.ZIndex = 8
	subtitleLabel.Parent = screenGui

	tween(vsLabel, SLOW_OUT, { TextTransparency = 0 })
	tween(subtitleLabel, SLOW_OUT, { TextTransparency = 0.35 })

	task.wait(0.4)

	tweenAll({
		TweenService:Create(vsLabel, FAST_IN, { TextTransparency = 1 }),
		TweenService:Create(subtitleLabel, FAST_IN_ALT, { TextTransparency = 1 }),
	})

	task.wait(0.12)
	if transitionOverlays[arenaNumber] ~= screenGui then
		screenGui:Destroy()
		return
	end

	local countdownColors = {
		[5] = Theme.Colors.White,
		[4] = Theme.Colors.White,
		[3] = Theme.Colors.White,
		[2] = Theme.Foreground.Secondary,
		[1] = Theme.Colors.Destructive,
	}

	local countdownPunchInTweens = {
		TweenService:Create(uiScale, SNAPPY_PUNCH_IN, { Scale = 1 }),
		TweenService:Create(numberLabel, SNAPPY_ALPHA_IN, { TextTransparency = 0 }),
		TweenService:Create(pillStroke, SNAPPY_ALPHA_IN, { Transparency = 0 }),
	}
	local countdownPunchOutTweens = {
		TweenService:Create(uiScale, SNAPPY_PUNCH_OUT, { Scale = 1.25 }),
		TweenService:Create(numberLabel, SNAPPY_PUNCH_OUT, { TextTransparency = 1 }),
		TweenService:Create(pillStroke, SNAPPY_PUNCH_OUT, { Transparency = 1 }),
	}

	forcefieldDuration = tonumber(forcefieldDuration) or tonumber(SparConfig.DEFAULT_FORCEFIELD_DURATION) or 3

	if revealAt == -1 then
		while not matchRevealTimes[arenaNumber] do
			task.wait(0.05)
			if transitionOverlays[arenaNumber] ~= screenGui then
				screenGui:Destroy()
				destroyTweens(countdownPunchInTweens)
				destroyTweens(countdownPunchOutTweens)
				return
			end
		end
		revealAt = matchRevealTimes[arenaNumber]
		matchRevealTimes[arenaNumber] = nil
	else
		revealAt = (type(revealAt) == "number" and revealAt > 0) and revealAt or (workspace:GetServerTimeNow() + forcefieldDuration)
	end

	local serverRevealAt = revealAt
	local totalRemaining = math.max(0, serverRevealAt - workspace:GetServerTimeNow())
	local startCount = math.clamp(math.ceil(totalRemaining), 1, math.max(1, math.floor(forcefieldDuration + 0.5)))

	if showVersusGUI then
		for countdownTime = startCount, 1, -1 do
			local col = countdownColors[countdownTime] or Theme.Colors.White

			numberLabel.Text = tostring(countdownTime)
			numberLabel.TextColor3 = col
			pillStroke.Color = col
			uiScale.Scale = 0.35
			numberLabel.TextTransparency = 0
			pillFrame.BackgroundTransparency = Theme.Chat.Window.BackgroundTransparency
			pillStroke.Transparency = 0.4

			playTweens(countdownPunchInTweens)

			local secondEndTime = serverRevealAt - (countdownTime - 1)
			local waitToPunchOut = secondEndTime - workspace:GetServerTimeNow() - 0.10
			if waitToPunchOut > 0 then
				task.wait(waitToPunchOut)
			end
			if transitionOverlays[arenaNumber] ~= screenGui then
				screenGui:Destroy()
				destroyTweens(countdownPunchInTweens)
				destroyTweens(countdownPunchOutTweens)
				return
			end

			playTweens(countdownPunchOutTweens)

			local waitToEnd = secondEndTime - workspace:GetServerTimeNow()
			if waitToEnd > 0 then
				task.wait(waitToEnd)
			end
			if transitionOverlays[arenaNumber] ~= screenGui then
				screenGui:Destroy()
				destroyTweens(countdownPunchInTweens)
				destroyTweens(countdownPunchOutTweens)
				return
			end
		end

		destroyTweens(countdownPunchInTweens)
		destroyTweens(countdownPunchOutTweens)
	else
		numberLabel.TextTransparency = 1
		pillStroke.Transparency = 1
		pillFrame.BackgroundTransparency = 1

		local remaining = serverRevealAt - workspace:GetServerTimeNow()
		if remaining > 0 then
			task.wait(remaining)
		end
	end

	local mySequenceId = sequenceId

	if lastCoverRevealSequence[arenaNumber] == mySequenceId then
		cleanupSpawnProtectionLocally(arenaNumber)
		Network.Spar.sendRevealArena(arenaNumber, 1)
	end

	startLocalTimer(arenaNumber)

	if showVersusGUI then
		numberLabel.Text = "FIGHT"
		numberLabel.TextColor3 = Theme.Colors.Success
		pillStroke.Color = Theme.Colors.Success
		uiScale.Scale = 0.2
		numberLabel.TextTransparency = 0
		pillStroke.Transparency = 0.3

		tweenAll({
			TweenService:Create(uiScale, BACK_OUT, { Scale = 1.15 }),
			TweenService:Create(numberLabel, EXPO_OUT_ALT, { TextTransparency = 0 }),
			TweenService:Create(pillStroke, EXPO_OUT_ALT, { Transparency = 0 }),
		})

		task.wait(0.35)

		tweenAll({
			TweenService:Create(numberLabel, FAST_IN_ALT, { TextTransparency = 1 }),
			TweenService:Create(pillStroke, FAST_IN_ALT, { Transparency = 1 }),
			TweenService:Create(uiScale, SLOW_OUT, { Scale = 1.4 }),
			TweenService:Create(pillFrame, SLOW_OUT, { BackgroundTransparency = 1 }),
		})
		task.wait(0.15)
	else
		task.wait(0.15)
	end

	screenGui:Destroy()
	if transitionOverlays[arenaNumber] == screenGui then
		transitionOverlays[arenaNumber] = nil
	end

	local lp = localPlayer
	if not lp then
		return
	end

	if not arenaStatus[arenaNumber] or not arenaStatus[arenaNumber].inMatch then
		print("[ArenaClient] Match ended during transition. Aborting HUD creation.")
		return
	end

	local existingHUD = activeVersusHUDs[arenaNumber]
	if existingHUD and existingHUD.Parent then
		existingHUD:Destroy()
	end

	local hudScope = Fusion.scoped(Fusion)

	if rounds >= 5 and not topbarIcons[arenaNumber] then
		local icon = Icon.new()
		icon:setLabel("EXIT MATCH")
		icon:bindEvent("selected", function()
			if topbarIcons[arenaNumber] then
				topbarIcons[arenaNumber]:deselect()
				Network.Spar.fireExitMatch(arenaNumber)
			end
		end)
		topbarIcons[arenaNumber] = icon
	end

	local status = arenaStatus[arenaNumber]
	local initP1 = if status then status.p1Wins else 0
	local initP2 = if status then status.p2Wins else 0
	local initSD = if status then status.isSuddenDeath else false

	local p1ScoreValue = hudScope:Value(initP1)
	local p2ScoreValue = hudScope:Value(initP2)
	local timerValue = hudScope:Value("0:00")
	local visibleValue = hudScope:Value(true)
	local modeLabelValue = hudScope:Value("SPREAD OFF")

	local firstToValue = hudScope:Value(rounds)
	local isSuddenDeathValue = hudScope:Value(initSD)

	hudScopes[arenaNumber] = hudScope
	hudScoreValues[arenaNumber] = { p1 = p1ScoreValue, p2 = p2ScoreValue }
	hudTimerValues[arenaNumber] = timerValue
	hudVisibleValues[arenaNumber] = visibleValue
	hudModeLabelValues[arenaNumber] = modeLabelValue
	hudFirstToValues[arenaNumber] = firstToValue
	hudIsSuddenDeathValues[arenaNumber] = isSuddenDeathValue

	local p1 = p1Player or lp
	local p2 = p2Player or lp

	local versusHUD = ArenaHUD.createVersusHUD({
		Player1 = p1,
		Player2 = p2,
		Player1Score = p1ScoreValue,
		Player2Score = p2ScoreValue,
		FirstTo = firstToValue,
		ModeLabel = modeLabelValue,
		TimerText = timerValue,
		Visible = visibleValue,
		IsSuddenDeath = isSuddenDeathValue,
	})

	versusHUD.Parent = playerGui
	activeVersusHUDs[arenaNumber] = versusHUD

	print("[ArenaClient] Versus HUD created for arena", arenaNumber)
end

local function playResultSequence(arenaNumber: number, didWin: boolean, enderName: string?)
	local playerGui = localPlayer and localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	if transitionOverlays[arenaNumber] then
		transitionOverlays[arenaNumber]:Destroy()
		transitionOverlays[arenaNumber] = nil
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ArenaResult_" .. arenaNumber
	screenGui.AutoLocalize = false
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 260
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui
	transitionOverlays[arenaNumber] = screenGui

	local pillFrame = Instance.new("Frame")
	pillFrame.Name = "ResultPill"
	pillFrame.Size = UDim2.fromOffset(320, 90)
	pillFrame.Position = UDim2.fromScale(0.5, 0.5)
	pillFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	pillFrame.BackgroundColor3 = Theme.Chat.Window.Background
	pillFrame.BackgroundTransparency = Theme.Chat.Window.BackgroundTransparency
	pillFrame.BorderSizePixel = 0
	pillFrame.ZIndex = 8
	pillFrame.Parent = screenGui

	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = Theme.Radius.Large
	pillCorner.Parent = pillFrame

	local resultColor = if didWin then Theme.Colors.Success else Theme.Colors.Destructive

	local pillStroke = Instance.new("UIStroke")
	pillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	pillStroke.Color = resultColor
	pillStroke.Thickness = 2
	pillStroke.Transparency = 0.3
	pillStroke.Parent = pillFrame

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0
	uiScale.Parent = pillFrame

	local resultLabel = Instance.new("TextLabel")
	resultLabel.Name = "ResultText"
	resultLabel.Size = UDim2.fromScale(1, 0.6)
	resultLabel.Position = UDim2.fromScale(0, 0.08)
	resultLabel.BackgroundTransparency = 1
	resultLabel.Text = if didWin then "VICTORY" else "DEFEAT"
	resultLabel.TextColor3 = resultColor
	resultLabel.TextTransparency = 1
	resultLabel.Font = Theme.Text.Black
	resultLabel.TextScaled = true
	resultLabel.ZIndex = 10
	resultLabel.Parent = pillFrame

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Size = UDim2.fromScale(1, 0.28)
	subtitleLabel.Position = UDim2.fromScale(0, 0.68)
	subtitleLabel.BackgroundTransparency = 1

	local subtitleText = if didWin then "Well played" else "Better luck next time"
	if enderName and enderName ~= "" then
		subtitleText = "The match was ended by " .. enderName
	end

	subtitleLabel.Text = subtitleText
	subtitleLabel.TextColor3 = Theme.Foreground.Muted
	subtitleLabel.TextTransparency = 1
	subtitleLabel.Font = Theme.Text.Bold
	subtitleLabel.TextScaled = true
	subtitleLabel.ZIndex = 10
	subtitleLabel.Parent = pillFrame

	uiScale.Scale = 0.2
	tweenAll({
		TweenService:Create(uiScale, BACK_OUT_ALT, { Scale = 1 }),
		TweenService:Create(resultLabel, EXPO_OUT_ALT, { TextTransparency = 0 }),
		TweenService:Create(pillStroke, EXPO_OUT_ALT, { Transparency = 0 }),
		TweenService:Create(subtitleLabel, SLOW_OUT_ALT, { TextTransparency = 0.3 }),
	})

	task.wait(2.8)

	tweenAll({
		TweenService:Create(uiScale, FAST_IN_ALT, { Scale = 1.15 }),
		TweenService:Create(resultLabel, FAST_IN_ALT, { TextTransparency = 1 }),
		TweenService:Create(subtitleLabel, FAST_IN_ALT, { TextTransparency = 1 }),
		TweenService:Create(pillStroke, FAST_IN_ALT, { Transparency = 1 }),
		TweenService:Create(pillFrame, FAST_IN_ALT, { BackgroundTransparency = 1 }),
	})

	screenGui:Destroy()
	if transitionOverlays[arenaNumber] == screenGui then
		transitionOverlays[arenaNumber] = nil
	end
end

local function playRoundTransitionSequence(
	arenaNumber: number,
	currentRound: number,
	_totalRounds: number,
	roundWinnerUserId: number?,
	isMatchPoint: boolean?,
	isSuddenDeath: boolean?,
	revealAt: number?,
	forcefieldDuration: number
)
	local playerGui = localPlayer and localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	local sequenceId = os.clock()
	lastCoverRevealSequence[arenaNumber] = sequenceId

	if transitionOverlays[arenaNumber] then
		transitionOverlays[arenaNumber]:Destroy()
		transitionOverlays[arenaNumber] = nil
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ArenaRoundTransition_" .. arenaNumber
	screenGui.AutoLocalize = false
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 250
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui
	transitionOverlays[arenaNumber] = screenGui

	local irVal = false
	if instantRespawnValues[arenaNumber] then
		irVal = Fusion.peek(instantRespawnValues[arenaNumber])
	end

	local wait1 = if irVal then 0.6 else 1.8
	local wait2 = if irVal then 0.1 else 0.3
	local wait3 = if irVal then 0.1 else 0.3

	local pillFrame = Instance.new("Frame")
	pillFrame.Name = "ResultPill"
	pillFrame.Size = UDim2.fromOffset(320, 90)
	pillFrame.Position = UDim2.fromScale(0.5, 0.5)
	pillFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	pillFrame.BackgroundColor3 = Theme.Chat.Window.Background
	pillFrame.BackgroundTransparency = Theme.Chat.Window.BackgroundTransparency
	pillFrame.BorderSizePixel = 0
	pillFrame.ZIndex = 8
	pillFrame.Parent = screenGui

	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = Theme.Radius.Large
	pillCorner.Parent = pillFrame

	local isWon = (roundWinnerUserId == localPlayer.UserId)
	local isLost = (roundWinnerUserId ~= nil and roundWinnerUserId ~= localPlayer.UserId)

	local resultText = "ROUND TIE"
	local resultColor = Theme.Colors.SilverBright
	local subtitleText = "Round Tie"

	if isWon then
		resultText = "ROUND WON"
		resultColor = Theme.Colors.Success
		subtitleText = "Well played"
	elseif isLost then
		resultText = "ROUND LOSS"
		resultColor = Theme.Colors.Destructive
		subtitleText = "Better luck next time"
	end

	if isSuddenDeath then
		subtitleText = "SUDDEN DEATH"
	elseif isMatchPoint then
		subtitleText = "MATCH POINT"
	end

	local pillStroke = Instance.new("UIStroke")
	pillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	pillStroke.Color = resultColor
	pillStroke.Thickness = 2
	pillStroke.Transparency = 0.3
	pillStroke.Parent = pillFrame

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0
	uiScale.Parent = pillFrame

	local resultLabel = Instance.new("TextLabel")
	resultLabel.Name = "ResultText"
	resultLabel.Size = UDim2.fromScale(1, 0.6)
	resultLabel.Position = UDim2.fromScale(0, 0.08)
	resultLabel.BackgroundTransparency = 1
	resultLabel.Text = resultText
	resultLabel.TextColor3 = resultColor
	resultLabel.TextTransparency = 1
	resultLabel.Font = Theme.Text.Black
	resultLabel.TextScaled = true
	resultLabel.ZIndex = 10
	resultLabel.Parent = pillFrame

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Size = UDim2.fromScale(1, 0.28)
	subtitleLabel.Position = UDim2.fromScale(0, 0.68)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = subtitleText
	subtitleLabel.TextColor3 = if isSuddenDeath then Theme.Colors.Warning else (if isMatchPoint then Theme.Colors.Warning else Theme.Foreground.Muted)
	subtitleLabel.TextTransparency = 1
	subtitleLabel.Font = Theme.Text.Bold
	subtitleLabel.TextScaled = true
	subtitleLabel.ZIndex = 10
	subtitleLabel.Parent = pillFrame

	uiScale.Scale = 0.2
	tweenAll({
		TweenService:Create(uiScale, BACK_OUT_ALT, { Scale = 1 }),
		TweenService:Create(resultLabel, EXPO_OUT_ALT, { TextTransparency = 0 }),
		TweenService:Create(pillStroke, EXPO_OUT_ALT, { Transparency = 0 }),
		TweenService:Create(subtitleLabel, SLOW_OUT_ALT, { TextTransparency = if isSuddenDeath or isMatchPoint then 0 else 0.3 }),
	})

	task.wait(wait1)
	if transitionOverlays[arenaNumber] ~= screenGui then
		screenGui:Destroy()
		return
	end

	tweenAll({
		TweenService:Create(uiScale, FAST_IN_ALT, { Scale = 1.15 }),
		TweenService:Create(resultLabel, FAST_IN_ALT, { TextTransparency = 1 }),
		TweenService:Create(subtitleLabel, FAST_IN_ALT, { TextTransparency = 1 }),
		TweenService:Create(pillStroke, FAST_IN_ALT, { Transparency = 1 }),
		TweenService:Create(pillFrame, FAST_IN_ALT, { BackgroundTransparency = 1 }),
	})

	task.wait(wait2)
	if transitionOverlays[arenaNumber] ~= screenGui then
		screenGui:Destroy()
		return
	end

	pillFrame:Destroy()

	local headerLabel = Instance.new("TextLabel")
	headerLabel.BackgroundTransparency = 1
	headerLabel.TextColor3 = Theme.Colors.SilverBright
	headerLabel.TextTransparency = 1
	headerLabel.Font = Theme.Text.Bold
	headerLabel.TextScaled = true
	headerLabel.ZIndex = 8
	if isSuddenDeath then
		headerLabel.Size = UDim2.fromScale(1, 0.08)
		headerLabel.Position = UDim2.fromScale(0, 0.22)
		headerLabel.Text = string.format("SUDDEN DEATH\nROUND %d", currentRound)
		headerLabel.TextColor3 = Theme.Colors.Warning
	else
		headerLabel.Size = UDim2.fromScale(1, 0.04)
		headerLabel.Position = UDim2.fromScale(0, 0.35)
		headerLabel.Text = string.format("ROUND %d", currentRound)
		headerLabel.TextColor3 = Theme.Colors.SilverBright
	end

	headerLabel.Parent = screenGui

	local countdownPill = Instance.new("Frame")
	countdownPill.Size = UDim2.fromOffset(110, 110)
	countdownPill.Position = UDim2.fromScale(0.5, 0.5)
	countdownPill.AnchorPoint = Vector2.new(0.5, 0.5)
	countdownPill.BackgroundColor3 = Theme.Chat.Window.Background
	countdownPill.BackgroundTransparency = Theme.Chat.Window.BackgroundTransparency
	countdownPill.BorderSizePixel = 0
	countdownPill.ZIndex = 8
	countdownPill.Parent = screenGui

	local countdownCorner = Instance.new("UICorner")
	countdownCorner.CornerRadius = Theme.Radius.Large
	countdownCorner.Parent = countdownPill

	local countdownStroke = Instance.new("UIStroke")
	countdownStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	countdownStroke.Color = Theme.Chat.Window.Border
	countdownStroke.Thickness = 1
	countdownStroke.Transparency = 0
	countdownStroke.Parent = countdownPill

	local countdownScale = Instance.new("UIScale")
	countdownScale.Scale = 0
	countdownScale.Parent = countdownPill

	local numberLabel = Instance.new("TextLabel")
	numberLabel.Size = UDim2.fromScale(1, 1)
	numberLabel.BackgroundTransparency = 1
	numberLabel.Text = ""
	numberLabel.TextColor3 = Theme.Colors.White
	numberLabel.TextTransparency = 1
	numberLabel.Font = Theme.Text.Black
	numberLabel.TextScaled = true
	numberLabel.ZIndex = 10
	numberLabel.Parent = countdownPill

	tween(headerLabel, SLOW_OUT_ALT, { TextTransparency = 0.25 })
	task.wait(wait3)

	local countdownColors = {
		[5] = Theme.Colors.White,
		[4] = Theme.Colors.White,
		[3] = Theme.Colors.White,
		[2] = Theme.Foreground.Secondary,
		[1] = Theme.Colors.Destructive,
	}

	local countdownPunchInTweens = {
		TweenService:Create(countdownScale, SNAPPY_PUNCH_IN, { Scale = 1 }),
		TweenService:Create(numberLabel, SNAPPY_ALPHA_IN, { TextTransparency = 0 }),
		TweenService:Create(countdownStroke, SNAPPY_ALPHA_IN, { Transparency = 0 }),
	}
	local countdownPunchOutTweens = {
		TweenService:Create(countdownScale, SNAPPY_PUNCH_OUT, { Scale = 1.25 }),
		TweenService:Create(numberLabel, SNAPPY_PUNCH_OUT, { TextTransparency = 1 }),
		TweenService:Create(countdownStroke, SNAPPY_PUNCH_OUT, { Transparency = 1 }),
	}

	forcefieldDuration = tonumber(forcefieldDuration) or tonumber(SparConfig.DEFAULT_FORCEFIELD_DURATION) or 3
	local showVersusGUI = true
	if showVersusGUIValues[arenaNumber] then
		showVersusGUI = Fusion.peek(showVersusGUIValues[arenaNumber])
	end

	if revealAt == -1 then
		while not matchRevealTimes[arenaNumber] do
			task.wait(0.05)
			if transitionOverlays[arenaNumber] ~= screenGui then
				screenGui:Destroy()
				destroyTweens(countdownPunchInTweens)
				destroyTweens(countdownPunchOutTweens)
				return
			end
		end
		revealAt = matchRevealTimes[arenaNumber]
		matchRevealTimes[arenaNumber] = nil
	else
		revealAt = (type(revealAt) == "number" and revealAt > 0) and revealAt or (workspace:GetServerTimeNow() + forcefieldDuration)
	end

	local serverRevealAt = revealAt
	local totalRemaining = math.max(0, serverRevealAt - workspace:GetServerTimeNow())
	local startCount = math.clamp(math.ceil(totalRemaining), 1, math.max(1, math.floor(forcefieldDuration + 0.5)))

	if showVersusGUI then
		for countdownTime = startCount, 1, -1 do
			local col = countdownColors[countdownTime] or Theme.Colors.White
			numberLabel.Text = tostring(countdownTime)
			numberLabel.TextColor3 = col
			countdownStroke.Color = col
			countdownScale.Scale = 0.35
			numberLabel.TextTransparency = 0
			countdownStroke.Transparency = 0.4

			playTweens(countdownPunchInTweens)

			local secondEndTime = serverRevealAt - (countdownTime - 1)
			local waitToPunchOut = secondEndTime - workspace:GetServerTimeNow() - 0.10
			if waitToPunchOut > 0 then
				task.wait(waitToPunchOut)
			end
			if transitionOverlays[arenaNumber] ~= screenGui then
				screenGui:Destroy()
				destroyTweens(countdownPunchInTweens)
				destroyTweens(countdownPunchOutTweens)
				return
			end

			playTweens(countdownPunchOutTweens)

			local waitToEnd = secondEndTime - workspace:GetServerTimeNow()
			if waitToEnd > 0 then
				task.wait(waitToEnd)
			end
			if transitionOverlays[arenaNumber] ~= screenGui then
				screenGui:Destroy()
				destroyTweens(countdownPunchInTweens)
				destroyTweens(countdownPunchOutTweens)
				return
			end
		end

		destroyTweens(countdownPunchInTweens)
		destroyTweens(countdownPunchOutTweens)
	else
		numberLabel.TextTransparency = 1
		countdownStroke.Transparency = 1
		countdownPill.BackgroundTransparency = 1

		local remaining = serverRevealAt - workspace:GetServerTimeNow()
		if remaining > 0 then
			task.wait(remaining)
		end
	end

	local mySequenceId = sequenceId

	if lastCoverRevealSequence[arenaNumber] == mySequenceId then
		cleanupSpawnProtectionLocally(arenaNumber)
		Network.Spar.sendRevealArena(arenaNumber, currentRound)
	end

	startLocalTimer(arenaNumber)

	if showVersusGUI then
		numberLabel.Text = "FIGHT"
		numberLabel.TextColor3 = Theme.Colors.Success
		countdownStroke.Color = Theme.Colors.Success
		countdownScale.Scale = 0.2
		numberLabel.TextTransparency = 0
		countdownStroke.Transparency = 0.3

		tweenAll({
			TweenService:Create(countdownScale, BACK_OUT_ALT, { Scale = 1.15 }),
			TweenService:Create(numberLabel, EXPO_OUT_ALT, { TextTransparency = 0 }),
			TweenService:Create(countdownStroke, EXPO_OUT_ALT, { Transparency = 0 }),
		})

		task.wait(0.35)

		tweenAll({
			TweenService:Create(numberLabel, FAST_IN_ALT, { TextTransparency = 1 }),
			TweenService:Create(countdownStroke, FAST_IN_ALT, { Transparency = 1 }),
			TweenService:Create(countdownScale, SLOW_OUT_ALT, { Scale = 1.4 }),
			TweenService:Create(countdownPill, SLOW_OUT_ALT, { BackgroundTransparency = 1 }),
			TweenService:Create(headerLabel, FAST_IN_ALT, { TextTransparency = 1 }),
		})
		task.wait(0.15)
	else
		tweenAll({
			TweenService:Create(headerLabel, FAST_IN_ALT, { TextTransparency = 1 }),
		})
		task.wait(0.15)
	end

	screenGui:Destroy()
	if transitionOverlays[arenaNumber] == screenGui then
		transitionOverlays[arenaNumber] = nil
	end
end

local function buildMatchStatusOverlay(scope: any, arenaNumber: number): Frame?
	local status = arenaStatus[arenaNumber]
	if not status or not status.inMatch then
		return nil
	end

	local p1Player = Players:FindFirstChild(status.p1)
	local p1UserId = if p1Player then p1Player.UserId else 0
	local p2Player = Players:FindFirstChild(status.p2)
	local p2UserId = if p2Player then p2Player.UserId else 0

	local overlay = scope:New("Frame")({
		Name = "MatchStatusOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		ZIndex = 100,
	})

	local vsFrame = scope:New("Frame")({
		Name = "VSFrame",
		Parent = overlay,
		Position = UDim2.fromScale(0.5, 0.35),
		Size = UDim2.fromScale(0.7, 0.35),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	})

	scope:New("Frame")({
		Name = "P1Panel",
		Parent = vsFrame,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(0.25, 0.8),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			scope:New("ImageLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.4,
				Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(p1UserId) .. "&w=150&h=150",
				ScaleType = Enum.ScaleType.Crop,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Color3.fromRGB(255, 50, 50),
						Thickness = 1.5,
					}),
				},
			}),
		},
	})

	scope:New("TextLabel")({
		Name = "VSText",
		Parent = vsFrame,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.2, 0.4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Text = "VS",
		TextColor3 = Color3.fromRGB(255, 200, 50),
		TextSize = 36,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
	})

	scope:New("Frame")({
		Name = "P2Panel",
		Parent = vsFrame,
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromScale(0.25, 0.8),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			scope:New("ImageLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.4,
				Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(p2UserId) .. "&w=150&h=150",
				ScaleType = Enum.ScaleType.Crop,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Color3.fromRGB(50, 130, 255),
						Thickness = 1.5,
					}),
				},
			}),
		},
	})

	local infoFrame = scope:New("Frame")({
		Name = "InfoFrame",
		Parent = overlay,
		Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.fromScale(0.5, 0.12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	})

	scope:New("TextLabel")({
		Name = "RoundInfo",
		Parent = infoFrame,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = string.format(
			"Round %d  |  First to %d  |  %s: %d  -  %s: %d",
			status.round,
			status.totalRounds,
			status.p1,
			status.p1Wins,
			status.p2,
			status.p2Wins
		),
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
	})

	return overlay :: Frame
end

local function updateArenaStatusOverlay(arenaNumber: number)
	local gui = activeGUIs[arenaNumber]
	if not gui or not gui.Parent then
		return
	end

	local existingScope = overlayScopes[arenaNumber]
	if existingScope then
		overlayScopes[arenaNumber] = nil
		Fusion.doCleanup(existingScope)
		overlayScopes[arenaNumber] = nil
	end

	local existingOverlay = gui:FindFirstChild("MatchStatusOverlay")
	if existingOverlay then
		existingOverlay:Destroy()
	end

	local status = arenaStatus[arenaNumber]
	if not status or not status.inMatch then
		return
	end

	local overlayScope = Fusion.scoped(Fusion)
	overlayScopes[arenaNumber] = overlayScope

	local overlay = buildMatchStatusOverlay(overlayScope, arenaNumber)
	if overlay then
		overlay.Parent = gui
	end
end

local function findScreenMeshPart(arenaNumber: number): MeshPart?
	local arenasFolder = Workspace:FindFirstChild("Arenas")
	if not arenasFolder then
		warn("[ArenaClient] Arenas folder not found in workspace")
		return nil
	end

	local arenaFolder = arenasFolder:FindFirstChild(tostring(arenaNumber))
	if not arenaFolder then
		warn("[ArenaClient] Arena " .. tostring(arenaNumber) .. " not found")
		return nil
	end

	local screenModel = arenaFolder:FindFirstChild("ScreenModel")
	if not screenModel then
		warn("[ArenaClient] ScreenModel not found in arena " .. tostring(arenaNumber))
		return nil
	end

	local screenPart = screenModel:WaitForChild("Screen", 5)
	if not screenPart then
		for _, child in screenModel:GetChildren() do
			if child:IsA("MeshPart") and child.Name ~= "LowerScreen" then
				screenPart = child
				break
			end
		end
	end

	if not screenPart then
		warn("[ArenaClient] Screen MeshPart not found in ScreenModel for arena " .. tostring(arenaNumber))
		return nil
	end

	return screenPart :: MeshPart
end

local function buildMapItem(scope: any, itemName: string, imageId: string?, selectedValue: any, onSelect: (string) -> (), isDisabled: any): Frame
	local isSelected = scope:Computed(function(use)
		return use(selectedValue) == itemName
	end)

	local isRandom = string.lower(itemName) == "random"

	local frame = scope:New("Frame")({
		Name = itemName .. "_Item",
		Size = UDim2.new(1, 0, 0, 90),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	})

	scope:New("ImageButton")({
		Name = "Hitbox",
		Parent = frame,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = scope:Computed(function(use)
			return if use(isDisabled) then Theme.Colors.Black[900] else (if use(isSelected) then Theme.Colors.Black[650] else Theme.Colors.Black[800])
		end),
		BackgroundTransparency = scope:Computed(function(use)
			return if use(isDisabled) then 0.6 else (if use(isSelected) then 0.1 else 0.25)
		end),
		ImageTransparency = 1,
		Active = scope:Computed(function(use)
			return not use(isDisabled)
		end),
		ClipsDescendants = true,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = scope:Computed(function(use)
					return if use(isSelected) then Theme.Colors.SilverBright else Theme.Border.Default
				end),
				Thickness = scope:Computed(function(use)
					return if use(isSelected) then 3 else 1.5
				end),
				Transparency = scope:Computed(function(use)
					return if use(isDisabled) then 0.8 else (if use(isSelected) then 0 else 0.6)
				end),
			}),
			if isRandom
				then scope:New("Frame")({
					Name = "RandomMapCollage",
					Size = UDim2.new(1, 0, 0, 64),
					Position = UDim2.fromOffset(0, 0),
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					ZIndex = 2,
					[Fusion.Children] = {
						scope:New("Frame")({
							Name = "Slice1",
							Size = UDim2.fromScale(0.333, 1),
							Position = UDim2.fromScale(0, 0),
							ClipsDescendants = true,
							BackgroundTransparency = 1,
							ZIndex = 2,
							[Fusion.Children] = {
								scope:New("ImageLabel")({
									Name = "Image",
									Size = UDim2.fromScale(1, 1),
									Position = UDim2.fromOffset(0, 0),
									BackgroundColor3 = Theme.Colors.Black[900],
									BackgroundTransparency = 0.3,
									Image = SparConfig.MAP_IMAGES["CQCCover"] or "rbxassetid://99770742830127",
									ScaleType = Enum.ScaleType.Crop,
									ImageTransparency = scope:Computed(function(use)
										return if use(isDisabled) then 0.5 else 0
									end),
									ZIndex = 2,
								}),
							},
						}),
						scope:New("Frame")({
							Name = "Divider1",
							Size = UDim2.new(0, 1, 1, 0),
							Position = UDim2.fromScale(0.333, 0),
							BackgroundColor3 = Theme.Colors.White,
							BackgroundTransparency = 0.65,
							ZIndex = 4,
						}),
						scope:New("Frame")({
							Name = "Slice2",
							Size = UDim2.fromScale(0.334, 1),
							Position = UDim2.fromScale(0.333, 0),
							ClipsDescendants = true,
							BackgroundTransparency = 1,
							ZIndex = 2,
							[Fusion.Children] = {
								scope:New("ImageLabel")({
									Name = "Image",
									Size = UDim2.fromScale(1, 1),
									Position = UDim2.fromOffset(0, 0),
									BackgroundColor3 = Theme.Colors.Black[900],
									BackgroundTransparency = 0.3,
									Image = SparConfig.MAP_IMAGES["MQC"] or "rbxassetid://123795244827924",
									ScaleType = Enum.ScaleType.Crop,
									ImageTransparency = scope:Computed(function(use)
										return if use(isDisabled) then 0.5 else 0
									end),
									ZIndex = 2,
								}),
							},
						}),
						scope:New("Frame")({
							Name = "Divider2",
							Size = UDim2.new(0, 1, 1, 0),
							Position = UDim2.fromScale(0.667, 0),
							BackgroundColor3 = Theme.Colors.White,
							BackgroundTransparency = 0.65,
							ZIndex = 4,
						}),
						scope:New("Frame")({
							Name = "Slice3",
							Size = UDim2.fromScale(0.333, 1),
							Position = UDim2.fromScale(0.667, 0),
							ClipsDescendants = true,
							BackgroundTransparency = 1,
							ZIndex = 2,
							[Fusion.Children] = {
								scope:New("ImageLabel")({
									Name = "Image",
									Size = UDim2.fromScale(1, 1),
									Position = UDim2.fromOffset(0, 0),
									BackgroundColor3 = Theme.Colors.Black[900],
									BackgroundTransparency = 0.3,
									Image = SparConfig.MAP_IMAGES["LQC"] or "rbxassetid://123301899618441",
									ScaleType = Enum.ScaleType.Crop,
									ImageTransparency = scope:Computed(function(use)
										return if use(isDisabled) then 0.5 else 0
									end),
									ZIndex = 2,
								}),
							},
						}),
					},
				})
				else scope:New("ImageLabel")({
					Name = "MapImage",
					Size = UDim2.new(1, 0, 0, 64),
					Position = UDim2.fromOffset(0, 0),
					BackgroundColor3 = Theme.Colors.Black[900],
					BackgroundTransparency = 0.3,
					Image = imageId or "",
					ScaleType = Enum.ScaleType.Crop,
					ImageTransparency = scope:Computed(function(use)
						return if use(isDisabled) then 0.5 else 0
					end),
					ZIndex = 2,
				}),
			scope:New("TextLabel")({
				Name = "MapName",
				Size = UDim2.new(1, -8, 0, 22),
				Position = UDim2.fromOffset(4, 66),
				BackgroundTransparency = 1,
				Text = itemName,
				TextColor3 = scope:Computed(function(use)
					return if use(isSelected) then Theme.Colors.White else Theme.Foreground.Secondary
				end),
				TextTransparency = scope:Computed(function(use)
					return if use(isDisabled) then 0.6 else 0
				end),
				TextSize = 13,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 2,
			}),
		},
		[Fusion.OnEvent("Activated")] = function(_self: ImageButton)
			if not Fusion.peek(isDisabled) then
				onSelect(itemName)
			end
		end,
	})

	return frame :: Frame
end

local function buildItem(
	scope: any,
	itemName: string,
	displayName: string,
	imageId: string?,
	selectedValue: any,
	onSelect: (string) -> (),
	isDisabled: any
): Frame
	local hasImage = imageId ~= nil and imageId ~= ""
	local itemHeight = if hasImage then 56 else 44

	local isSelected = scope:Computed(function(use)
		return use(selectedValue) == itemName
	end)

	local frame = scope:New("Frame")({
		Name = itemName .. "_Item",
		Size = UDim2.new(1, 0, 0, itemHeight),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	})

	scope:New("ImageButton")({
		Name = "Hitbox",
		Parent = frame,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = scope:Computed(function(use)
			return if use(isDisabled) then Theme.Colors.Black[900] else (if use(isSelected) then Theme.Colors.Black[650] else Theme.Colors.Black[800])
		end),
		BackgroundTransparency = scope:Computed(function(use)
			return if use(isDisabled) then 0.6 else (if use(isSelected) then 0.1 else 0.25)
		end),
		ImageTransparency = 1,
		Active = scope:Computed(function(use)
			return not use(isDisabled)
		end),
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = scope:Computed(function(use)
					return if use(isDisabled) then Theme.Border.Default else (if use(isSelected) then Theme.Colors.SilverBright else Theme.Border.Default)
				end),
				Thickness = scope:Computed(function(use)
					return if use(isSelected) then 3 else 1.5
				end),
				Transparency = scope:Computed(function(use)
					return if use(isDisabled) then 0.8 else (if use(isSelected) then 0 else 0.6)
				end),
			}),
			if hasImage
				then scope:New("ImageLabel")({
					Name = "Icon",
					Size = UDim2.fromOffset(44, 44),
					Position = UDim2.new(0, 4, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Image = imageId :: any,
					ScaleType = Enum.ScaleType.Fit,
					ImageTransparency = scope:Computed(function(use)
						return if use(isDisabled) then 0.6 else 0
					end),
					ZIndex = 2,
				})
				else nil,
			scope:New("TextLabel")({
				Name = "Name",
				Position = UDim2.fromOffset(if hasImage then 54 else 8, 0),
				Size = UDim2.new(1, if hasImage then -58 else -16, 1, 0),
				BackgroundTransparency = 1,
				Text = displayName,
				TextColor3 = scope:Computed(function(use)
					return if use(isDisabled) then Theme.Foreground.Secondary else (if use(isSelected) then Theme.Colors.White else Theme.Foreground.Secondary)
				end),
				TextTransparency = scope:Computed(function(use)
					return if use(isDisabled) then 0.6 else 0
				end),
				TextSize = if hasImage then 16 else 18,
				Font = if hasImage then Theme.Text.Semibold else Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 2,
			}),
		},
		[Fusion.OnEvent("Activated")] = function(_self: ImageButton)
			if not Fusion.peek(isDisabled) then
				onSelect(itemName)
			end
		end,
	})

	return frame :: Frame
end

local function buildCategoryColumn(
	scope: any,
	title: string,
	items: { string },
	getImageId: ((string) -> string?)?,
	selectedValue: any,
	onSelect: (string) -> (),
	isDisabled: any,
	isMapColumn: boolean?,
	customInputCategory: string?,
	maxCustomValue: number?
): Frame
	local column = scope:New("Frame")({
		Name = title .. "Column",
		Size = UDim2.new(0.192, -2, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	})

	scope:New("Frame")({
		Name = "TitleBar",
		Parent = column,
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = Theme.Colors.Black[800],
		BackgroundTransparency = 0.3,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
			scope:New("TextLabel")({
				Size = UDim2.new(1, -8, 1, 0),
				Position = UDim2.fromOffset(4, 0),
				BackgroundTransparency = 1,
				Text = title,
				TextColor3 = Theme.Colors.SilverBright,
				TextSize = 14,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		},
	})

	local customFooterH = if customInputCategory then 58 else 0

	local itemsContainer = scope:New("Frame")({
		Name = "ItemsContainer",
		Parent = column,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30 - customFooterH),
		BackgroundColor3 = Theme.Colors.Black[850],
		BackgroundTransparency = 0.2,
		ClipsDescendants = true,
	})

	scope:New("UICorner")({
		Parent = itemsContainer,
		CornerRadius = Theme.Radius.Small,
	})

	local scrollFrame = scope:New("ScrollingFrame")({
		Name = "ItemList",
		Parent = itemsContainer,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.Scrollbar.Thumb,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.fromScale(0, 0),
		ClipsDescendants = false,
	})

	scope:New("UIListLayout")({
		Parent = scrollFrame,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	scope:New("UIPadding")({
		Parent = scrollFrame,
		PaddingTop = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
	})

	for _, itemName in items do
		local imageId = getImageId and getImageId(itemName) or nil
		local item: Frame
		if isMapColumn then
			item = buildMapItem(scope, itemName, imageId, selectedValue, onSelect, isDisabled)
		else
			item = buildItem(scope, itemName, itemName, imageId, selectedValue, onSelect, isDisabled)
		end
		item.Parent = scrollFrame
	end

	if customInputCategory then
		local feedbackValue = scope:Value("")

		local customFooter = scope:New("Frame")({
			Name = "CustomFooter",
			Parent = column,
			Position = UDim2.new(0, 0, 1, -customFooterH),
			Size = UDim2.new(1, 0, 0, customFooterH),
			BackgroundColor3 = Theme.Colors.Black[850],
			BackgroundTransparency = 0.2,
			[Fusion.Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
				scope:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Theme.Border.Default,
					Thickness = 1,
					Transparency = Theme.Stroke.Default,
				}),
			},
		})

		scope:New("TextLabel")({
			Name = "CustomLabel",
			Parent = customFooter,
			Position = UDim2.fromOffset(6, 5),
			Size = UDim2.new(0.55, -8, 0, 16),
			BackgroundTransparency = 1,
			Text = "CUSTOM " .. customInputCategory,
			TextColor3 = Theme.Colors.SilverBright,
			TextSize = 11,
			Font = Theme.Text.Bold,
			TextXAlignment = Enum.TextXAlignment.Left,
		})

		if maxCustomValue then
			scope:New("TextLabel")({
				Name = "MaxHint",
				Parent = customFooter,
				Position = UDim2.new(0.55, 0, 0, 5),
				Size = UDim2.new(0.45, -6, 0, 16),
				BackgroundTransparency = 1,
				Text = "max " .. tostring(maxCustomValue),
				TextColor3 = Theme.Foreground.Muted,
				TextSize = 10,
				Font = Theme.Text.Regular,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
		end

		scope:New("TextLabel")({
			Name = "FeedbackLabel",
			Parent = customFooter,
			Position = UDim2.fromOffset(6, 21),
			Size = UDim2.new(1, -12, 0, 12),
			BackgroundTransparency = 1,
			Text = feedbackValue,
			TextColor3 = Theme.Colors.Destructive,
			TextSize = 9,
			Font = Theme.Text.Regular,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})

		local customBox = scope:New("TextBox")({
			Name = "CustomInput",
			Parent = customFooter,
			Position = UDim2.fromOffset(6, 28),
			Size = UDim2.new(1, -52, 0, 24),
			BackgroundColor3 = Theme.Colors.Black[800],
			BackgroundTransparency = 0.2,
			PlaceholderText = "Type a number...",
			PlaceholderColor3 = Theme.Foreground.Muted,
			Text = "",
			TextColor3 = Theme.Colors.White,
			TextSize = 13,
			Font = Theme.Text.Regular,
			ClearTextOnFocus = false,
			[Fusion.Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
				scope:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Theme.Border.Default,
					Thickness = 1,
					Transparency = Theme.Stroke.Default,
				}),
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 6),
					PaddingRight = UDim.new(0, 4),
				}),
			},
		})

		local function tryApplyCustomValue()
			if Fusion.peek(isDisabled) then
				return
			end

			local raw = customBox.Text
			local numStr = raw:match("^%s*(%d+)%s*$")
			if not numStr then
				feedbackValue:set("Enter a whole number.")
				task.delay(2.5, function()
					feedbackValue:set("")
				end)
				return
			end

			local num = tonumber(numStr)
			if not num or num <= 0 then
				feedbackValue:set("Value must be greater than 0.")
				task.delay(2.5, function()
					feedbackValue:set("")
				end)
				return
			end

			if maxCustomValue and num > maxCustomValue then
				feedbackValue:set("Max is " .. tostring(maxCustomValue) .. ".")
				task.delay(2.5, function()
					feedbackValue:set("")
				end)
				return
			end

			feedbackValue:set("")
			onSelect(numStr)
			selectedValue:set(numStr)
		end

		scope:New("TextButton")({
			Name = "SetButton",
			Parent = customFooter,
			Position = UDim2.new(1, -44, 0, 28),
			Size = UDim2.fromOffset(40, 24),
			BackgroundColor3 = Theme.Colors.Black[650],
			BackgroundTransparency = scope:Computed(function(use)
				return if use(isDisabled) then 0.6 else 0.1
			end),
			Text = "SET",
			TextColor3 = Theme.Colors.White,
			TextSize = 12,
			Font = Theme.Text.Bold,
			Active = scope:Computed(function(use)
				return not use(isDisabled)
			end),
			[Fusion.Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
				scope:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Theme.Colors.SilverBright,
					Thickness = 1,
					Transparency = 0.5,
				}),
			},
			[Fusion.OnEvent("Activated")] = function(_self: TextButton)
				tryApplyCustomValue()
			end,
		})

		local customBoxFocusLostConn = customBox.FocusLost:Connect(function(enterPressed: boolean)
			if enterPressed then
				tryApplyCustomValue()
			end
		end)
		table.insert(scope, customBoxFocusLostConn)
	end

	return column :: Frame
end

local function buildArenaSelectionGUI(arenaNumber: number): SurfaceGui?
	local scope = Fusion.scoped(Fusion)

	local selectedMap = scope:Value(SparConfig.DEFAULT_MAP)
	selectedMapValues[arenaNumber] = selectedMap
	local selectedGun = scope:Value(SparConfig.DEFAULT_GUN)
	selectedGunValues[arenaNumber] = selectedGun
	local selectedHealth = scope:Value(SparConfig.DEFAULT_HEALTH)
	selectedHealthValues[arenaNumber] = selectedHealth
	local selectedRounds = scope:Value(lastSelections.Rounds or SparConfig.DEFAULT_ROUNDS)
	selectedRoundsValues[arenaNumber] = selectedRounds
	local selectedForcefield = scope:Value(lastSelections.Forcefield or SparConfig.DEFAULT_FORCEFIELD_DURATION)
	selectedForcefieldValues[arenaNumber] = selectedForcefield
	local showVersusGUI = scope:Value(true)
	showVersusGUIValues[arenaNumber] = showVersusGUI
	local instantRespawn = scope:Value(false)
	instantRespawnValues[arenaNumber] = instantRespawn

	local countdownValue = scope:Value(0)
	countdownValueValues[arenaNumber] = countdownValue

	local isCountingDown = scope:Value(false)
	isCountingDownValues[arenaNumber] = isCountingDown

	local lastChangeText = scope:Value("Last change: None")
	lastChangeTextValues[arenaNumber] = lastChangeText

	local playersCountOnPads = scope:Value(0)
	playersCountOnPadsValues[arenaNumber] = playersCountOnPads

	local playerOnPad = scope:Value(localPlayerOnPad[arenaNumber] or false)
	playerOnPadValues[arenaNumber] = playerOnPad

	local matchActive = scope:Value(false)
	matchActiveValues[arenaNumber] = matchActive
	local isDisabled = scope:Computed(function(use)
		return use(matchActive) or not use(playerOnPad)
	end)

	local playerName = localPlayer and localPlayer.Name or "Player"
	local isSolo = isSoloMode

	local screenPart = findScreenMeshPart(arenaNumber)
	if not screenPart then
		warn("[ArenaClient] Cannot create SurfaceGui for arena " .. tostring(arenaNumber) .. " - no screen part found")
		return nil
	end

	local surfaceGui = scope:New("SurfaceGui")({
		Name = "ArenaSelection_" .. arenaNumber,
		Adornee = screenPart,
		Parent = screenPart,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50,
		ResetOnSpawn = false,
		Enabled = true,
		AlwaysOnTop = false,
	})

	scope:New("Frame")({
		Name = "Background",
		Parent = surfaceGui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Background.Primary,
		BackgroundTransparency = Theme.Transparency.Subtle,
	})

	local panel = scope:New("Frame")({
		Name = "SelectionPanel",
		Parent = surfaceGui,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.9),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Background.Primary,
		BackgroundTransparency = 0.1,
	})

	scope:New("UICorner")({ Parent = panel, CornerRadius = Theme.Radius.Large })
	scope:New("UIStroke")({
		Parent = panel,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Theme.Border.Default,
		Thickness = 2,
		Transparency = Theme.Stroke.Default,
	})

	local headerHeight = 0.07
	local header = scope:New("Frame")({
		Name = "Header",
		Parent = panel,
		Size = UDim2.fromScale(1, headerHeight),
		BackgroundColor3 = Theme.Background.Tertiary,
		BackgroundTransparency = Theme.Transparency.Subtle,
	})

	scope:New("UICorner")({ Parent = header, CornerRadius = Theme.Radius.Large })
	scope:New("UIStroke")({
		Parent = header,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Theme.Border.Default,
		Thickness = 1.5,
		Transparency = Theme.Stroke.Default,
	})
	scope:New("Frame")({
		Name = "HeaderDivider",
		Parent = header,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Border.Default,
		BackgroundTransparency = Theme.Stroke.Strong,
	})

	scope:New("TextLabel")({
		Name = "ArenaTitle",
		Parent = header,
		Position = UDim2.fromScale(0.03, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromScale(0.4, 0.65),
		BackgroundTransparency = 1,
		Text = "ARENA " .. tostring(arenaNumber),
		TextColor3 = Theme.Colors.White,
		TextSize = 20,
		Font = Theme.Text.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	scope:New("TextLabel")({
		Name = "LastChange",
		Parent = header,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, -400, 1, 0),
		BackgroundTransparency = 1,
		Text = lastChangeText,
		TextColor3 = Theme.Colors.SilverBright,
		TextSize = 16,
		Font = Theme.Text.Bold,
	})

	if isSolo then
		scope:New("TextLabel")({
			Name = "SoloIndicator",
			Parent = header,
			Position = UDim2.fromScale(0.97, 0.5),
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.fromScale(0.3, 0.6),
			BackgroundTransparency = 1,
			Text = "VDI MODE",
			TextColor3 = Color3.fromRGB(255, 200, 50),
			TextSize = 16,
			Font = Theme.Text.Bold,
		})
	end

	local catRow = scope:New("Frame")({
		Name = "CategoriesRow",
		Parent = panel,
		Position = UDim2.fromScale(0.02, headerHeight + 0.01),
		Size = UDim2.fromScale(0.96, 1 - (headerHeight + 0.1)),
		BackgroundTransparency = 1,
	})

	scope:New("UIListLayout")({
		Parent = catRow,
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0.01, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})

	local function makeColumn(
		title: string,
		items: { string },
		getImg: ((string) -> string?)?,
		selected: any,
		onChange: (string) -> (),
		isMapCol: boolean?,
		customInput: string?,
		maxCustom: number?
	)
		local col = buildCategoryColumn(scope, title, items, getImg, selected, function(value)
			selected:set(value)
			Network.Spar.sendSelectOption(arenaNumber, string.lower(title), value)
			local key = string.lower(title)
			if key == "maps" or key == "map" then
				lastSelections.Map = value
				lastLocalSelectionTimes[arenaNumber] = lastLocalSelectionTimes[arenaNumber] or {}
				lastLocalSelectionTimes[arenaNumber]["map"] = os.clock()
			elseif key == "guns" or key == "gun" then
				lastSelections.Gun = value
				lastLocalSelectionTimes[arenaNumber] = lastLocalSelectionTimes[arenaNumber] or {}
				lastLocalSelectionTimes[arenaNumber]["gun"] = os.clock()
			elseif key == "health" then
				lastSelections.Health = value
				lastLocalSelectionTimes[arenaNumber] = lastLocalSelectionTimes[arenaNumber] or {}
				lastLocalSelectionTimes[arenaNumber]["health"] = os.clock()
			elseif key == "rounds" then
				lastSelections.Rounds = value
				lastLocalSelectionTimes[arenaNumber] = lastLocalSelectionTimes[arenaNumber] or {}
				lastLocalSelectionTimes[arenaNumber]["rounds"] = os.clock()
			elseif key == "forcefield" then
				lastSelections.Forcefield = value
				lastLocalSelectionTimes[arenaNumber] = lastLocalSelectionTimes[arenaNumber] or {}
				lastLocalSelectionTimes[arenaNumber]["forcefield"] = os.clock()
			end

			if isSoloMode then
				simulateAISelection(arenaNumber)
			end
			onChange(value)
		end, isDisabled, isMapCol, customInput, maxCustom)
		col.Parent = catRow
	end

	makeColumn("MAPS", MAP_NAMES, function(n)
		return SparConfig.MAP_IMAGES[n]
	end, selectedMap, function(_) end, true, nil, nil)

	makeColumn("GUNS", GUN_NAMES, function(n)
		return SparConfig.GUN_ICONS[n]
	end, selectedGun, function(_) end, false, nil, nil)

	makeColumn("HEALTH", HEALTH_OPTIONS, nil, selectedHealth, function(_) end, false, "HEALTH", MAX_CUSTOM_HEALTH)

	makeColumn("ROUNDS", ROUNDS_OPTIONS, nil, selectedRounds, function(_) end, false, "ROUNDS", MAX_CUSTOM_ROUNDS)

	makeColumn("FORCEFIELD", SparConfig.FORCEFIELD_OPTIONS, nil, selectedForcefield, function(_) end, false, nil, nil)

	local bottomBarHeight = 0.1
	local bottomBar = scope:New("Frame")({
		Name = "BottomBar",
		Parent = panel,
		Position = UDim2.fromScale(0, 0.906),
		Size = UDim2.fromScale(1, bottomBarHeight),
		BackgroundTransparency = 1,
	})

	scope:New("TextButton")({
		Name = "VersusToggle",
		Parent = bottomBar,
		Position = UDim2.fromScale(0.07, 0.5),
		Size = UDim2.fromScale(0.12, 0.55),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = scope:Computed(function(use)
			return if use(showVersusGUI) then Theme.Colors.Success else Theme.Colors.Black[700]
		end),
		Text = scope:Computed(function(use)
			return if use(showVersusGUI) then "COUNTDOWN: ON" else "COUNTDOWN: OFF"
		end),
		TextColor3 = Theme.Colors.White,
		TextSize = 12,
		Font = Theme.Text.Bold,
		Active = scope:Computed(function(use)
			return not use(isDisabled)
		end),
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
		},
		[Fusion.OnEvent("Activated")] = function(_self: TextButton)
			if Fusion.peek(isDisabled) then
				return
			end
			local newVal = not Fusion.peek(showVersusGUI)
			showVersusGUI:set(newVal)
			lastSelections.Versus = newVal
			Network.Spar.sendToggleSetting(arenaNumber, "showVersusGUI")
			lastChangeText:set(playerName .. " toggled Versus GUI " .. (if newVal then "ON" else "OFF"))
		end,
	})

	scope:New("TextButton")({
		Name = "InstantToggle",
		Parent = bottomBar,
		Position = UDim2.fromScale(0.21, 0.5),
		Size = UDim2.fromScale(0.15, 0.55),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = scope:Computed(function(use)
			local roundsNum = tonumber(use(selectedRounds)) or 1
			if roundsNum <= 1 then
				return Theme.Colors.Black[700]
			end
			return if use(instantRespawn) then Theme.Colors.Success else Theme.Colors.Black[700]
		end),
		Text = scope:Computed(function(use)
			return if use(instantRespawn) then "INSTANT: ON" else "INSTANT: OFF"
		end),
		TextColor3 = scope:Computed(function(use)
			local roundsNum = tonumber(use(selectedRounds)) or 1
			if roundsNum <= 1 then
				return Theme.Colors.Black[400]
			end
			return Theme.Colors.White
		end),
		TextSize = 12,
		Font = Theme.Text.Bold,
		Active = scope:Computed(function(use)
			local roundsNum = tonumber(use(selectedRounds)) or 1
			return not use(isDisabled) and roundsNum > 1
		end),
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
		},
		[Fusion.OnEvent("Activated")] = function(_self: TextButton)
			if Fusion.peek(isDisabled) then
				return
			end
			local roundsNum = tonumber(Fusion.peek(selectedRounds)) or 1
			if roundsNum <= 1 then
				return
			end
			local newVal = not Fusion.peek(instantRespawn)
			instantRespawn:set(newVal)
			Network.Spar.sendToggleSetting(arenaNumber, "instantRespawn")
			lastChangeText:set(playerName .. " toggled Instant Respawn " .. (if newVal then "ON" else "OFF"))
		end,
	})

	scope:New("TextButton")({
		Name = "StartButton",
		Parent = bottomBar,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.35, 0.7),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = scope:Computed(function(use)
			if use(isDisabled) then
				return Theme.Colors.Black[700]
			end
			local count = use(playersCountOnPads)
			if count < 2 and not isSoloMode then
				return Theme.Colors.Black[700]
			end
			return if use(isCountingDown) then Theme.Colors.Warning else Theme.Colors.Success
		end),
		Text = scope:Computed(function(use)
			if use(isDisabled) then
				return "STAND ON PAD"
			end
			local count = use(playersCountOnPads)
			if count < 2 and not isSoloMode then
				return "NEED ANOTHER PLAYER TO START"
			end
			local timerVal = use(countdownValue)
			local counting = use(isCountingDown)
			return if counting then "CANCEL (" .. tostring(timerVal) .. ")" else "START DUEL"
		end),
		TextColor3 = Theme.Colors.White,
		TextSize = 18,
		Font = Theme.Text.Bold,
		Active = scope:Computed(function(use)
			if use(isDisabled) then
				return false
			end
			local count = use(playersCountOnPads)
			if count < 2 and not isSoloMode then
				return false
			end
			return true
		end),
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = scope:Computed(function(use)
					if use(isDisabled) then
						return Theme.Border.Default
					end
					local count = use(playersCountOnPads)
					if count < 2 and not isSoloMode then
						return Theme.Border.Default
					end
					return if use(isCountingDown) then Theme.Colors.Warning else Theme.Colors.Success
				end),
				Thickness = 2,
			}),
		},
		[Fusion.OnEvent("Activated")] = function(_self: TextButton)
			if Fusion.peek(isDisabled) then
				return
			end
			local count = Fusion.peek(playersCountOnPads)
			if count < 2 and not isSoloMode then
				return
			end

			Network.Spar.sendStartMatch(
				arenaNumber,
				Fusion.peek(selectedMap),
				Fusion.peek(selectedGun),
				Fusion.peek(selectedHealth),
				Fusion.peek(selectedRounds),
				Fusion.peek(showVersusGUI),
				Fusion.peek(instantRespawn),
				isSoloMode,
				Fusion.peek(selectedForcefield)
			)
		end,
	})

	local screenModel = screenPart and screenPart.Parent
	local lowerScreenPart = screenModel and screenModel:WaitForChild("LowerScreen", 5) :: MeshPart?
	if lowerScreenPart then
		local lowerGui = scope:New("SurfaceGui")({
			Name = "ArenaLowerSelection_" .. arenaNumber,
			Parent = lowerScreenPart,
			Adornee = lowerScreenPart,
			Face = Enum.NormalId.Front,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 50,
			ResetOnSpawn = false,
			Enabled = true,
			AlwaysOnTop = false,
		})
		activeLowerGUIs[arenaNumber] = lowerGui

		local lowerPanel = scope:New("Frame")({
			Name = "LowerSelectionPanel",
			Parent = lowerGui,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Background.Primary,
			BackgroundTransparency = 0,
			[Fusion.Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
				scope:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Theme.Border.Default,
					Thickness = 2,
					Transparency = Theme.Stroke.Default,
				}),
				scope:New("UIPadding")({
					PaddingTop = UDim.new(0.1, 0),
					PaddingBottom = UDim.new(0.1, 0),
					PaddingLeft = UDim.new(0.1, 0),
					PaddingRight = UDim.new(0.1, 0),
				}),
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0.08, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			},
		})

		local function applyConfig(map, gun, health, rounds, vs, configName)
			selectedMap:set(map)
			Network.Spar.sendSelectOption(arenaNumber, "maps", map)

			selectedGun:set(gun)
			Network.Spar.sendSelectOption(arenaNumber, "guns", gun)

			selectedHealth:set(health)
			Network.Spar.sendSelectOption(arenaNumber, "health", health)

			selectedRounds:set(rounds)
			Network.Spar.sendSelectOption(arenaNumber, "rounds", rounds)

			if Fusion.peek(showVersusGUI) ~= vs then
				showVersusGUI:set(vs)
				Network.Spar.sendToggleSetting(arenaNumber, "showVersusGUI")
			end

			lastSelections.Map = map
			lastSelections.Gun = gun
			lastSelections.Health = health
			lastSelections.Rounds = rounds
			lastSelections.Versus = vs

			lastChangeText:set(playerName .. " loaded " .. configName)
		end

		local function PresetButton(btnText, onClick)
			local isBtnHovered = scope:Value(false)
			local btnBgColor = scope:Spring(
				scope:Computed(function(use)
					if use(isDisabled) then
						return Theme.Colors.Black[800]
					elseif use(isBtnHovered) then
						return Theme.Colors.Black[650]
					else
						return Theme.Colors.Black[800]
					end
				end),
				Theme.Spring.Snappy.Speed
			)
			local btnTextColor = scope:Computed(function(use)
				return if use(isDisabled) then Theme.Foreground.Muted else Theme.Colors.White
			end)
			local btnBorderColor = scope:Spring(
				scope:Computed(function(use)
					if use(isDisabled) then
						return Theme.Border.Default
					elseif use(isBtnHovered) then
						return Theme.Colors.SilverBright
					else
						return Theme.Border.Default
					end
				end),
				Theme.Spring.Snappy.Speed
			)

			return scope:New("TextButton")({
				Name = btnText:gsub("%s+", "") .. "Btn",
				Parent = lowerPanel,
				Size = UDim2.fromScale(0.9, 0.4),
				BackgroundColor3 = btnBgColor,
				BackgroundTransparency = scope:Computed(function(use)
					return if use(isDisabled) then 0.6 else 0.1
				end),
				Text = btnText,
				TextColor3 = btnTextColor,
				TextSize = 22,
				Font = Theme.Text.Bold,
				Active = scope:Computed(function(use)
					return not use(isDisabled)
				end),
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = btnBorderColor,
						Thickness = 2.5,
						Transparency = scope:Computed(function(use)
							return if use(isDisabled) then 0.8 else 0.2
						end),
					}),
				},
				[Fusion.OnEvent("MouseEnter")] = function()
					if not Fusion.peek(isDisabled) then
						isBtnHovered:set(true)
					end
				end,
				[Fusion.OnEvent("MouseLeave")] = function()
					isBtnHovered:set(false)
				end,
				[Fusion.OnEvent("Activated")] = function()
					if Fusion.peek(isDisabled) then
						return
					end
					onClick()
				end,
			})
		end

		PresetButton("DEFAULT CONFIG", function()
			applyConfig(
				SparConfig.DEFAULT_MAP,
				SparConfig.DEFAULT_GUN,
				SparConfig.DEFAULT_HEALTH,
				SparConfig.DEFAULT_ROUNDS,
				SparConfig.DEFAULT_VERSUS ~= false,
				"Default Config"
			)
		end)

		PresetButton("LAST CONFIG", function()
			applyConfig(lastSelections.Map, lastSelections.Gun, lastSelections.Health, lastSelections.Rounds, lastSelections.Versus, "Last Config")
		end)
	end

	return surfaceGui :: SurfaceGui
end

function ArenaClient.init() end

function ArenaClient.start()
	Network.Spar.init()

	if isSoloMode then
		print("[ArenaClient] Starting in SOLO MODE with AI opponent: " .. soloPlayerName)
	end

	Network.Spar.onPadStatus(function(arenaNumber: number, isOnPad: boolean)
		if not localPlayer then
			return
		end
		localPlayerOnPad[arenaNumber] = isOnPad
		local padValue = playerOnPadValues[arenaNumber]
		if padValue then
			padValue:set(isOnPad)
		end
	end)

	Network.Spar.onLobbyState(function(data: any)
		if type(data) == "table" then
			for arenaNum, stateData in pairs(data) do
				local num = tonumber(arenaNum) or arenaNum
				local leftId = stateData.leftPlayerId or 0
				local rightId = stateData.rightPlayerId or 0
				local count = 0
				if leftId ~= 0 then
					count += 1
				end
				if rightId ~= 0 then
					count += 1
				end
				local val = playersCountOnPadsValues[num]
				if val then
					val:set(count)
				end
				if stateData.selections then
					local times = lastLocalSelectionTimes[num] or {}
					if selectedMapValues[num] and (os.clock() - (times["map"] or 0) > 1.5) then
						selectedMapValues[num]:set(stateData.selections.map)
					end
					if selectedGunValues[num] and (os.clock() - (times["gun"] or 0) > 1.5) then
						selectedGunValues[num]:set(stateData.selections.gun)
					end
					if selectedHealthValues[num] and (os.clock() - (times["health"] or 0) > 1.5) then
						selectedHealthValues[num]:set(stateData.selections.health)
					end
					if selectedRoundsValues[num] and (os.clock() - (times["rounds"] or 0) > 1.5) then
						selectedRoundsValues[num]:set(stateData.selections.rounds)
					end
					if showVersusGUIValues[num] then
						showVersusGUIValues[num]:set(stateData.selections.showVersusGUI)
					end
					if instantRespawnValues[num] then
						local irVal = stateData.selections.instantRespawn == true
						instantRespawnValues[num]:set(irVal)
					end
				end
			end
		end
	end)

	Network.Spar.onMatchStarted(
		function(
			arenaNumber: number,
			mapName: string,
			gunName: string,
			healthName: string,
			rounds: number,
			showVersusGUI: boolean,
			player1Id: number,
			player2Id: number,
			revealAt: number,
			forcefieldDuration: number
		)
			print("[ArenaClient] Match started for arena", arenaNumber, "- playing transition sequence")

			local p1Player = Players:GetPlayerByUserId(player1Id)
			local p2Player = Players:GetPlayerByUserId(player2Id)

			task.spawn(
				playTransitionSequence,
				arenaNumber,
				mapName,
				gunName,
				healthName,
				rounds,
				showVersusGUI,
				p1Player,
				p2Player,
				revealAt,
				forcefieldDuration
			)
		end
	)

	Network.Spar.onArenaStatus(function(arenaNumber: number, statusType: string, data: string)
		local isCountingDown = isCountingDownValues[arenaNumber]
		local countdownValue = countdownValueValues[arenaNumber]
		local lastChangeText = lastChangeTextValues[arenaNumber]
		local matchActive = matchActiveValues[arenaNumber]

		if statusType == "matchRevealAt" then
			matchRevealTimes[arenaNumber] = tonumber(data)
		elseif statusType == "countdownStart" then
			local success, parsed = pcall(function()
				return HttpService:JSONDecode(data)
			end)
			local startVal = success and parsed.value or SparConfig.COUNTDOWN_DURATION
			if isCountingDown then
				isCountingDown:set(true)
			end
			if countdownValue then
				countdownValue:set(startVal)
			end
			if lastChangeText then
				lastChangeText:set("Countdown starting...")
			end
		elseif statusType == "countdownTick" then
			local success, parsed = pcall(function()
				return HttpService:JSONDecode(data)
			end)
			local tickVal = success and parsed.value or 0
			if countdownValue then
				countdownValue:set(tickVal)
			end
		elseif statusType == "countdownCancel" then
			if isCountingDown then
				isCountingDown:set(false)
			end
			if countdownValue then
				countdownValue:set(0)
			end
			if lastChangeText then
				local success, parsed = pcall(function()
					return HttpService:JSONDecode(data)
				end)
				if success and parsed and parsed.reason then
					lastChangeText:set(parsed.reason)
				else
					lastChangeText:set("Countdown cancelled")
				end
			end
			if matchActive then
				matchActive:set(false)
			end
		elseif statusType == "selectionChanged" then
			local success, parsed = pcall(function()
				return HttpService:JSONDecode(data)
			end)
			if success and parsed then
				local k = string.lower(parsed.type)
				if (k == "maps" or k == "map") and selectedMapValues[arenaNumber] then
					selectedMapValues[arenaNumber]:set(parsed.value)
				elseif (k == "guns" or k == "gun") and selectedGunValues[arenaNumber] then
					selectedGunValues[arenaNumber]:set(parsed.value)
				elseif k == "health" and selectedHealthValues[arenaNumber] then
					selectedHealthValues[arenaNumber]:set(parsed.value)
				elseif k == "rounds" and selectedRoundsValues[arenaNumber] then
					selectedRoundsValues[arenaNumber]:set(parsed.value)
					if (tonumber(parsed.value) or 1) <= 1 and instantRespawnValues[arenaNumber] then
						instantRespawnValues[arenaNumber]:set(false)
					end
				elseif k == "forcefield" and selectedForcefieldValues[arenaNumber] then
					selectedForcefieldValues[arenaNumber]:set(parsed.value)
				elseif k == "showversusgui" and showVersusGUIValues[arenaNumber] then
					showVersusGUIValues[arenaNumber]:set(parsed.value)
				elseif k == "instantrespawn" and instantRespawnValues[arenaNumber] then
					instantRespawnValues[arenaNumber]:set(parsed.value == true)
				end

				if lastChangeText then
					lastChangeText:set(parsed.playerName .. " changed " .. tostring(parsed.type) .. " to " .. tostring(parsed.value))
				end
			end
		elseif statusType == "countdownComplete" then
			if isCountingDown then
				isCountingDown:set(false)
			end
			if countdownValue then
				countdownValue:set(0)
			end
			if lastChangeText then
				lastChangeText:set("Match started!")
			end
			if matchActive then
				matchActive:set(true)
			end
		elseif statusType == "matchStart" or statusType == "roundUpdate" then
			local success, parsed = pcall(function()
				return HttpService:JSONDecode(data)
			end)
			if success then
				arenaStatus[arenaNumber] = {
					inMatch = true,
					p1 = parsed.p1 or "Player1",
					p2 = parsed.p2 or "Player2",
					p1Wins = parsed.p1Wins or 0,
					p2Wins = parsed.p2Wins or 0,
					round = parsed.round or 1,
					totalRounds = parsed.totalRounds or 1,
					map = parsed.map or "",
					isSuddenDeath = parsed.isSuddenDeath or false,
				}
				updateArenaStatusOverlay(arenaNumber)

				updateHUDState(arenaNumber, {
					p1Wins = parsed.p1Wins,
					p2Wins = parsed.p2Wins,
					timerText = parsed.timerText,
					modeLabel = parsed.modeLabel,
					totalRounds = parsed.totalRounds,
					isSuddenDeath = parsed.isSuddenDeath,
				})
			end
		elseif statusType == "matchEnd" then
			stopLocalTimer(arenaNumber)

			local gui = activeGUIs[arenaNumber]
			if gui then
				while true do
					local overlay = gui:FindFirstChild("MatchStatusOverlay")
					if overlay then
						overlay:Destroy()
					else
						break
					end
				end
			end
			local existingScope = overlayScopes[arenaNumber]
			if existingScope then
				Fusion.doCleanup(existingScope)
				overlayScopes[arenaNumber] = nil
			end

			local winnerName = ""
			local enderName = ""
			local ok, parsed = pcall(function()
				return HttpService:JSONDecode(data)
			end)
			if ok and parsed then
				if parsed.winner then
					winnerName = parsed.winner
				end
				if parsed.enderName then
					enderName = parsed.enderName
				end
				if parsed.p1Wins and parsed.p2Wins then
					updateHUDState(arenaNumber, {
						p1Wins = parsed.p1Wins,
						p2Wins = parsed.p2Wins,
					})
				end
			end

			local isParticipant = false
			if localPlayer then
				local myId = localPlayer.UserId
				local p1Id = if ok and parsed then parsed.player1Id else nil
				local p2Id = if ok and parsed then parsed.player2Id else nil
				isParticipant = (p1Id == myId) or (p2Id == myId)
			end

			local didWin = localPlayer and localPlayer.Name == winnerName

			arenaStatus[arenaNumber] = nil

			local matchActiveValue = matchActiveValues[arenaNumber]
			if matchActiveValue then
				matchActiveValue:set(false)
			end

			teardownVersusHUD(arenaNumber)

			if isParticipant then
				task.spawn(playResultSequence, arenaNumber, didWin == true, enderName)
			end
		end
	end)

	Network.Spar.onRoundTransition(
		function(
			arenaNumber: number,
			currentRound: number,
			totalRounds: number,
			roundWinnerUserId: number?,
			isMatchPoint: boolean?,
			isSuddenDeath: boolean?,
			revealAt: number,
			forcefieldDuration: number
		)
			task.spawn(
				playRoundTransitionSequence,
				arenaNumber,
				currentRound,
				totalRounds,
				roundWinnerUserId,
				isMatchPoint,
				isSuddenDeath,
				revealAt,
				forcefieldDuration
			)
		end
	)

	local arenasFolder = Workspace:FindFirstChild("Arenas")
	local attempts = 0
	while not arenasFolder and attempts < 10 do
		task.wait(0.5)
		arenasFolder = Workspace:FindFirstChild("Arenas")
		attempts += 1
	end

	if not arenasFolder then
		warn("[ArenaClient] Cannot start - Arenas folder not found in workspace after waiting")
		return
	end

	local createdCount = 0
	for _, child in arenasFolder:GetChildren() do
		local arenaNumber = tonumber(child.Name)
		if arenaNumber and arenaNumber >= 1 and arenaNumber <= 8 then
			if not activeGUIs[arenaNumber] then
				local gui = buildArenaSelectionGUI(arenaNumber)
				if gui then
					activeGUIs[arenaNumber] = gui
					createdCount += 1
					print("[ArenaClient] Created UI for arena " .. arenaNumber)
				end
			end
		end
	end

	print(string.format("[ArenaClient] Created UI for %d out of 8 arenas", createdCount))
end

function ArenaClient.cleanup()
	for _, timer in countdownTimers do
		if timer and timer.thread then
			coroutine.close(timer.thread)
			timer.thread = nil
		end
	end
	table.clear(countdownTimers)

	for _, gui in activeGUIs do
		if gui and gui.Parent then
			gui:Destroy()
		end
	end
	table.clear(activeGUIs)

	for _, gui in activeLowerGUIs do
		if gui and gui.Parent then
			gui:Destroy()
		end
	end
	table.clear(activeLowerGUIs)

	for _, hud in activeVersusHUDs do
		if hud and hud.Parent then
			hud:Destroy()
		end
	end
	table.clear(activeVersusHUDs)

	for _, overlay in transitionOverlays do
		if overlay and overlay.Parent then
			overlay:Destroy()
		end
	end
	table.clear(transitionOverlays)

	for _, scope in hudScopes do
		Fusion.doCleanup(scope)
	end
	table.clear(hudScopes)
	table.clear(hudScoreValues)
	table.clear(hudTimerValues)
	table.clear(hudVisibleValues)
	table.clear(hudModeLabelValues)
	table.clear(hudFirstToValues)
	table.clear(matchActiveValues)

	for _, scope in overlayScopes do
		Fusion.doCleanup(scope)
	end
	table.clear(overlayScopes)
	table.clear(matchRevealTimes)
end

function ArenaClient.toggleSoloMode()
	if isSoloMode then
		ArenaClient.disableSoloMode()
	else
		ArenaClient.enableSoloMode()
	end
end

return ArenaClient
