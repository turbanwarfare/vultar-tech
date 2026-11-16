--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local FactionUtils = require(MainModule.Shared.Utils.Game.FactionUtils)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Maps = require(MainModule.Shared.Config.Maps)
local PhaseConfig = require(MainModule.Shared.Config.PhaseConfig)
local Network = require(MainModule.Shared.Network)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)
local StartScreen = require(MainModule.Client.Components.StartScreen)
local MataroWinScreen = require(MainModule.Client.Components.MataroWinScreen)
local PhaseBanner = require(MainModule.Client.Components.PhaseBanner)
local PhaseTerminalHUD = require(MainModule.Client.Components.PhaseTerminalHUD)
local LeaderboardService = require(MainModule.Client.Services.LeaderboardService)
local BlurEffect = require(MainModule.Client.Utils.UI.BlurEffect)

type PhaseOwner = PhaseTerminalHUD.PhaseOwner

local PhaseHUDService = {}
PhaseHUDService.Name = "PhaseHUDService"

local LocalPlayer = Players.LocalPlayer

local CONQUEST_DEBOUNCE = 0.2

local isActive: boolean = false
local playerGui: PlayerGui? = nil

local bannerScope: any = nil
local bannerGui: ScreenGui? = nil
local bannerText: any = nil
local bannerVisible: any = nil

local startScreenScope: any = nil
local startScreenGui: ScreenGui? = nil
local startScreenCountdown: any = nil
local startScreenMaxPoints: any = nil
local startScreenDismiss: (() -> ())? = nil
local isStartScreenActive: boolean = false

local winScreenScope: any = nil
local winScreenGui: ScreenGui? = nil
local isWinScreenActive: boolean = false

local isPhaseTermActive: boolean = false

local lastPhaseNum: number = 0
local gameStartClock: number = 0
local hasDeployed: boolean = false
local lastConquestEventClock: number = 0

local connections: { { Disconnect: () -> () } } = {}
local matchGameId: string = ""
local wasCountingDown: boolean = false
local countdownDismissThread: thread? = nil
local countdownChainThread1: thread? = nil
local countdownChainThread2: thread? = nil

local trainPollActive: boolean = false
local trainTweenProxy = Instance.new("NumberValue")
trainTweenProxy.Name = "TrainTweenProxy"
trainTweenProxy.Parent = script
local trainTweenConn: RBXScriptConnection? = nil
local trainActiveTween: Tween? = nil

local cachedDefenderParts: { BasePart }? = nil
local cachedHostileParts: { BasePart }? = nil

local updatePhaseTermVisibility: () -> ()

local function generateGameId(): string
	local seed = game.JobId .. tostring(game.PlaceId) .. tostring(game.GameId)
	local hash = 0
	for i = 1, #seed do
		hash = (hash * 31 + string.byte(seed, i)) % 2147483647
	end
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local parts = table.create(10)
	for i = 1, 10 do
		hash = (hash * 1103515245 + 12345) % 2147483647
		local idx = (hash % #chars) + 1
		parts[i] = string.sub(chars, idx, idx)
	end
	return table.concat(parts)
end

local function getPlayerFaction(): "Defenders" | "Raiders" | "Neutral"
	local teamName = Network.Teams.getCurrentTeam()
	if not teamName then
		return "Neutral"
	end
	return FactionUtils.getTeamFaction(teamName) :: any
end

local function setupTeamDoors(): ()
	local teamDoorsFolder = workspace:FindFirstChild("TeamDoors")
	if not teamDoorsFolder then
		return
	end

	local defendersFolder = teamDoorsFolder:FindFirstChild("Defenders")
	local hostilesFolder = teamDoorsFolder:FindFirstChild("Hostiles")

	if defendersFolder then
		cachedDefenderParts = {}
		for _, part in defendersFolder:GetChildren() do
			if part:IsA("BasePart") then
				table.insert(cachedDefenderParts :: { BasePart }, part :: BasePart)
			end
		end
	end

	if hostilesFolder then
		cachedHostileParts = {}
		for _, part in hostilesFolder:GetChildren() do
			if part:IsA("BasePart") then
				table.insert(cachedHostileParts :: { BasePart }, part :: BasePart)
			end
		end
	end

	local function applyTeamDoors(_character: Model)
		local faction = getPlayerFaction()
		if cachedDefenderParts then
			for _, part in cachedDefenderParts do
				part.CanCollide = faction ~= "Defenders"
			end
		end
		if cachedHostileParts then
			for _, part in cachedHostileParts do
				part.CanCollide = faction ~= "Raiders"
			end
		end
	end

	table.insert(
		connections,
		LocalPlayer.CharacterAdded:Connect(function(character: Model)
			task.defer(applyTeamDoors, character)
		end)
	)

	if LocalPlayer.Character then
		task.defer(applyTeamDoors, LocalPlayer.Character)
	end
end

local function cleanupStartScreen(): ()
	if startScreenScope then
		startScreenScope:doCleanup()
		startScreenScope = nil
	end
	startScreenGui = nil
	startScreenCountdown = nil
	startScreenMaxPoints = nil
	startScreenDismiss = nil
	isStartScreenActive = false
	updatePhaseTermVisibility()
end

local function dismissStartScreen(): ()
	if not isStartScreenActive then
		return
	end
	if startScreenDismiss then
		startScreenDismiss()
	else
		cleanupStartScreen()
	end
end

local function showStartScreen(): ()
	if isStartScreenActive then
		return
	end
	cleanupStartScreen()
	isStartScreenActive = true
	updatePhaseTermVisibility()

	startScreenScope = Fusion.scoped(Fusion)
	startScreenCountdown = startScreenScope:Value(PhaseConfig.COUNTDOWN_TIME)
	startScreenMaxPoints = startScreenScope:Value(0)

	local gui, dismissFn = StartScreen(startScreenScope, {
		Countdown = startScreenCountdown,
		MaxPoints = startScreenMaxPoints,
		GameId = matchGameId,
		Mode = "Phase",
		OnDismissed = function()
			cleanupStartScreen()
		end,
	})

	startScreenGui = gui
	startScreenDismiss = dismissFn

	if playerGui then
		startScreenGui.Parent = playerGui
	end
end

local function cleanupWinScreen(): ()
	BlurEffect.forceRemove("WinScreenBlur")
	if winScreenScope then
		winScreenScope:doCleanup()
		winScreenScope = nil
	end
	winScreenGui = nil
	isWinScreenActive = false
end

local function createBanner(): ()
	if bannerGui then
		return
	end
	bannerScope = Fusion.scoped(Fusion)
	bannerText = bannerScope:Value("")
	bannerVisible = bannerScope:Value(false)
	bannerGui = PhaseBanner(bannerScope, {
		Text = bannerText,
		Visible = bannerVisible,
	})
	if playerGui then
		bannerGui.Parent = playerGui
	end
end

local function destroyBanner(): ()
	if bannerScope then
		bannerScope:doCleanup()
		bannerScope = nil
	end
	bannerGui = nil
	bannerText = nil
	bannerVisible = nil
end

local function createPhaseTerminalHUD(): ()
	if isPhaseTermActive then
		return
	end
	isPhaseTermActive = true
	if not playerGui then
		return
	end
	local phase1Def = PhaseConfig.getPhase("phase1")
	local defaultTermTime = if phase1Def then phase1Def.TermTime else 360
	PhaseTerminalHUD.init(playerGui :: PlayerGui)
	PhaseTerminalHUD.setTermTimeRemaining(defaultTermTime)
	PhaseTerminalHUD.setConquestActive(true)
end

local function destroyPhaseTerminalHUD(): ()
	PhaseTerminalHUD.destroy()
	lastPhaseNum = 0
	isPhaseTermActive = false
end

local function setTerminalBillboards(phaseNum: number): ()
	local folder = workspace:FindFirstChild("TerminalBillboards")
	if not folder then
		return
	end
	for _, billboard in folder:GetChildren() do
		local bbGui = billboard:FindFirstChildWhichIsA("BillboardGui")
		if bbGui then
			local num = tonumber(billboard.Name:match("P(%d+)Billboard"))
			bbGui.Enabled = num == phaseNum
		end
	end
end

updatePhaseTermVisibility = function()
	PhaseTerminalHUD.setVisible(hasDeployed and not isStartScreenActive and not isWinScreenActive)
end

local function syncTermTimer(timeRemaining: number): ()
	PhaseTerminalHUD.setTermTimeRemaining(timeRemaining)
	if lastPhaseNum > 0 then
		local phaseId = PhaseConfig.PHASE_ORDER[lastPhaseNum]
		local phaseDef = phaseId and PhaseConfig.getPhase(phaseId)
		if phaseDef and phaseDef.TermTime > 0 then
			PhaseTerminalHUD.setTermProgress(math.clamp(1 - timeRemaining / phaseDef.TermTime, 0, 1))
		end
	end
end

local function updatePhaseTerminal(state: Network.PhaseState): ()
	PhaseTerminalHUD.setPhaseState(state.Phase, state.Official)

	local isLive = state.Official and not state.CountingDown
	PhaseTerminalHUD.setOwner(if isLive then state.Owner else nil)

	if state.Phase > 0 then
		local phaseId = PhaseConfig.PHASE_ORDER[state.Phase]
		local phaseDef = phaseId and PhaseConfig.getPhase(phaseId)
		if phaseDef and phaseDef.TermTime > 0 then
			if isLive then
				local remaining = state.TermTime
				PhaseTerminalHUD.setTermProgress(math.clamp(1 - remaining / phaseDef.TermTime, 0, 1))
				PhaseTerminalHUD.setTermTimeRemaining(remaining)
			else
				PhaseTerminalHUD.setTermProgress(0)
				PhaseTerminalHUD.setTermTimeRemaining(phaseDef.TermTime)
			end
		end
	else
		PhaseTerminalHUD.setTermProgress(0)
	end

	PhaseTerminalHUD.setElapsedTime(if isLive then state.RaidTime else 0)
	PhaseTerminalHUD.setOvertime(state.Overtime)
	updatePhaseTermVisibility()

	if state.Phase ~= lastPhaseNum then
		lastPhaseNum = state.Phase
		PhaseTerminalHUD.resetPhaseData()

		local phaseId = PhaseConfig.PHASE_ORDER[state.Phase]
		local phaseDef = phaseId and PhaseConfig.getPhase(phaseId)
		local isTerminalOnly = phaseDef and phaseDef.HasTerminal and not phaseDef.HasPayload
		PhaseTerminalHUD.setConquestActive(isTerminalOnly or state.ConquestActive)

		if state.Phase > 0 then
			setTerminalBillboards(state.Phase)
		end
	end

	if state.ConquestActive then
		PhaseTerminalHUD.setConquestActive(true)
	end
end

local function onPhaseUpdate(state: Network.PhaseState): ()
	local isCountingDown = state.CountingDown
	if isCountingDown and not wasCountingDown then
		showStartScreen()
	elseif not isCountingDown and wasCountingDown then
		if countdownDismissThread then
			task.cancel(countdownDismissThread)
		end
		countdownDismissThread = task.delay(3, function()
			countdownDismissThread = nil
			if isStartScreenActive then
				dismissStartScreen()
			end
		end)
	end
	wasCountingDown = isCountingDown == true

	local isLive = state.Official and not state.CountingDown
	if isLive and gameStartClock == 0 then
		gameStartClock = os.clock()
	end

	updatePhaseTerminal(state)
end

local function onPhaseAnnouncement(announcement: Network.PhaseAnnouncement): ()
	if announcement.Type == "RAID_STARTING" and isStartScreenActive then
		if announcement.Countdown and startScreenCountdown then
			local countdownNum = announcement.Countdown
			startScreenCountdown:set(countdownNum)
			if countdownNum <= 1 then
				if countdownChainThread1 then
					task.cancel(countdownChainThread1)
				end
				countdownChainThread1 = task.delay(1, function()
					countdownChainThread1 = nil
					if isStartScreenActive and startScreenCountdown then
						startScreenCountdown:set(0)
					end
					countdownChainThread2 = task.delay(1, function()
						countdownChainThread2 = nil
						dismissStartScreen()
					end)
				end)
			end
		end
		return
	end

	if
		announcement.Type == "PHASE_TRANSITION"
		or announcement.Type == "PHASE_MESSAGE"
		or announcement.Type == "OVERTIME"
		or announcement.Type == "DEFENDERS_WON"
		or announcement.Type == "RAIDERS_WON"
	then
		if bannerText and bannerVisible then
			bannerText:set(announcement.Message)
			bannerVisible:set(true)
		end
	end
end

local function findTrainModel(trainFolder: Instance): Model?
	local model = trainFolder:FindFirstChildWhichIsA("Model")
	return if model then model :: Model else nil
end

local function stopTrainTween(): ()
	if trainActiveTween then
		trainActiveTween:Cancel()
		trainActiveTween = nil
	end
	if trainTweenConn then
		trainTweenConn:Disconnect()
		trainTweenConn = nil
	end
	trainTweenProxy.Value = 0
end

local function onTrainMovement(data: Network.TrainMovementData): ()
	local trainFolder = workspace:FindFirstChild("Train")
	if not trainFolder then
		return
	end

	if trainPollActive then
		return
	end

	local trainModel = findTrainModel(trainFolder)
	if not trainModel then
		trainPollActive = true
		for _ = 1, 50 do
			task.wait(0.1)
			trainModel = findTrainModel(trainFolder)
			if trainModel then
				break
			end
		end
		trainPollActive = false
	end

	if not trainModel then
		return
	end

	task.wait(data.Delay)

	stopTrainTween()

	local capturedModel = trainModel
	trainTweenProxy.Value = 0

	trainTweenConn = trainTweenProxy:GetPropertyChangedSignal("Value"):Connect(function()
		if not capturedModel.Parent then
			return
		end
		capturedModel:PivotTo(data.StartPosition:Lerp(data.TargetPosition, trainTweenProxy.Value))
	end)

	local tween = TweenService:Create(trainTweenProxy, TweenInfo.new(data.TravelTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = 1 })
	trainActiveTween = tween
	tween:Play()

	tween.Completed:Once(function()
		if trainTweenConn then
			trainTweenConn:Disconnect()
			trainTweenConn = nil
		end
		trainActiveTween = nil
	end)
end

local function onPayloadProgress(progress: number, max: number, netPower: number): ()
	local normalizedProgress = if max > 0 then progress / max else 0
	local controlTeam: PhaseOwner = nil
	if netPower > 0 then
		controlTeam = "Raiders"
	elseif netPower < 0 then
		controlTeam = "Defenders"
	end
	PhaseTerminalHUD.setPayloadProgress(normalizedProgress, controlTeam)
	if (os.clock() - lastConquestEventClock) > CONQUEST_DEBOUNCE then
		PhaseTerminalHUD.setConquestActive(false)
	end
end

local function onConquestUi(update: Network.ConquestUpdate): ()
	lastConquestEventClock = os.clock()
	PhaseTerminalHUD.setConquestActive(true)
	if update.Action == "UpdateCaptureProgress" then
		PhaseTerminalHUD.setCaptureState(update.Progress, update.Team)
		syncTermTimer(update.TimeRemaining)
	elseif update.Action == "CaptureComplete" then
		PhaseTerminalHUD.setOwner(update.Team)
		PhaseTerminalHUD.setCaptureState(0, nil)
		syncTermTimer(update.TimeRemaining)
	end
end

local function onVictory(victoryData: Network.VictoryData): ()
	if isWinScreenActive then
		return
	end
	isWinScreenActive = true
	PhaseTerminalHUD.setVisible(false)

	cleanupWinScreen()
	isWinScreenActive = true

	local faction = getPlayerFaction()
	local phaseReached = lastPhaseNum
	local phaseId = PhaseConfig.PHASE_ORDER[phaseReached]
	local phaseDef = phaseId and PhaseConfig.getPhase(phaseId)
	local gameTime = if gameStartClock > 0 then os.clock() - gameStartClock else 0

	winScreenScope = Fusion.scoped(Fusion)
	winScreenGui = MataroWinScreen(winScreenScope, {
		VictoryData = victoryData,
		PlayerFaction = faction,
		DefendersData = LeaderboardService:GetDefendersData(),
		RaidersData = LeaderboardService:GetRaidersData(),
		GameId = matchGameId,
		PhaseReached = phaseReached,
		PhaseName = if phaseDef then phaseDef.DisplayName else "",
		GameTimeElapsed = gameTime,
		OnComplete = function()
			cleanupWinScreen()
		end,
	})

	if playerGui then
		winScreenGui.Parent = playerGui
	end
end

function PhaseHUDService:init(): ()
	local mapConfig = Maps.getConfig()
	isActive = mapConfig.RaidType == "Phase"
	playerGui = PlayerGuiHelper.waitForPlayerGui()
end

function PhaseHUDService:start(): ()
	if not isActive then
		return
	end

	matchGameId = generateGameId()

	createBanner()
	createPhaseTerminalHUD()
	setupTeamDoors()

	table.insert(connections, Network.Phase.onUpdate(onPhaseUpdate))
	table.insert(connections, Network.Phase.onAnnouncement(onPhaseAnnouncement))
	table.insert(connections, Network.Phase.onConquestUi(onConquestUi))
	table.insert(connections, Network.Phase.onPayloadProgress(onPayloadProgress))
	table.insert(connections, Network.Phase.onVictory(onVictory))
	table.insert(connections, Network.Phase.onTrainMovement(onTrainMovement))

	table.insert(
		connections,
		Network.Deploy.onDeployComplete(function()
			hasDeployed = true
			updatePhaseTermVisibility()
		end)
	)

	table.insert(
		connections,
		LocalPlayer.CharacterAdded:Connect(function()
			updatePhaseTermVisibility()
		end)
	)

	task.spawn(function()
		local initialState = Network.Phase.getState()
		if initialState then
			onPhaseUpdate(initialState)
		else
			setTerminalBillboards(1)
		end
	end)
end

function PhaseHUDService:Cleanup(): ()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)

	if countdownDismissThread then
		task.cancel(countdownDismissThread)
		countdownDismissThread = nil
	end
	if countdownChainThread1 then
		task.cancel(countdownChainThread1)
		countdownChainThread1 = nil
	end
	if countdownChainThread2 then
		task.cancel(countdownChainThread2)
		countdownChainThread2 = nil
	end

	stopTrainTween()
	if trainTweenProxy then
		trainTweenProxy:Destroy()
	end
	trainPollActive = false

	cleanupStartScreen()
	cleanupWinScreen()
	destroyBanner()
	destroyPhaseTerminalHUD()

	cachedDefenderParts = nil
	cachedHostileParts = nil

	isActive = false
	wasCountingDown = false
	hasDeployed = false
	gameStartClock = 0
	lastConquestEventClock = 0
end

return PhaseHUDService
