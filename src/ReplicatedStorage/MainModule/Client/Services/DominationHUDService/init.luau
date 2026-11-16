--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local FactionUtils = require(MainModule.Shared.Utils.Game.FactionUtils)
local DominationHUD = require(MainModule.Client.Components.DominationHUD)
local DominationPointBillboard = require(MainModule.Client.Components.DominationPointBillboard)
local WinScreen = require(MainModule.Client.Components.WinScreen)
local StartScreen = require(MainModule.Client.Components.StartScreen)
local Maps = require(MainModule.Shared.Config.Maps)
local Network = require(MainModule.Shared.Network)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)
local LeaderboardService = require(MainModule.Client.Services.LeaderboardService)
local DominationConfig = require(MainModule.Shared.Config.DominationConfig)
local BlurEffect = require(MainModule.Client.Utils.UI.BlurEffect)

local DominationHUDService = {}
DominationHUDService.Name = "DominationHUDService"

local LocalPlayer = Players.LocalPlayer

type Owner = DominationHUD.Owner
type DominationPointUIState = DominationHUD.DominationPointUIState

local scope: any = nil
local hudGui: ScreenGui? = nil
local playerGui: PlayerGui? = nil

local defenderScore: any = nil
local hostileScore: any = nil
local maxScore: any = nil
local points: any = nil
local official: any = nil
local visible: any = nil
local announcementText: any = nil
local announcementVisible: any = nil

local isActive: boolean = false
local hasDeployed: boolean = false

local deployConnection: RBXScriptConnection? = nil
local characterConnection: RBXScriptConnection? = nil
local updateConnection: { Disconnect: () -> () }? = nil
local announcementConnection: { Disconnect: () -> () }? = nil
local victoryConnection: { Disconnect: () -> () }? = nil

local announcementHideThread: thread? = nil

local countdownDismissThread: thread? = nil
local countdownChainThread1: thread? = nil
local countdownChainThread2: thread? = nil
local wasCountingDown: boolean = false
local matchGameId: string = ""

local winScreenScope: any = nil
local winScreenGui: ScreenGui? = nil
local isWinScreenActive: boolean = false

local startScreenScope: any = nil
local startScreenGui: ScreenGui? = nil
local isStartScreenActive: boolean = false
local startScreenCountdown: any = nil
local startScreenMaxScore: any = nil
local startScreenDismiss: (() -> ())? = nil

local NOTIFICATION_SOUND_ID = "rbxassetid://1301600348"
local NOTIFICATION_VOLUME = 0.5
local notificationSound: Sound? = nil

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

local function playNotificationSound(): ()
	if not notificationSound then
		notificationSound = Instance.new("Sound")
		notificationSound.SoundId = NOTIFICATION_SOUND_ID
		notificationSound.Volume = NOTIFICATION_VOLUME
		notificationSound.Parent = SoundService
	end
	notificationSound:Play()
end

local function getPlayerFaction(): "Defenders" | "Raiders" | "Neutral"
	local teamName = Network.Teams.getCurrentTeam()
	if not teamName then
		return "Neutral"
	end
	return FactionUtils.getTeamFaction(teamName) :: any
end

local function updateVisibility(): ()
	if not visible then
		return
	end
	if isWinScreenActive or isStartScreenActive then
		visible:set(false)
		return
	end
	if not hasDeployed then
		visible:set(false)
		return
	end
	visible:set(true)
end

local function onCharacterAdded(_character: Model): ()
	updateVisibility()
end

local function onDeployComplete(): ()
	hasDeployed = true
	updateVisibility()
end

local function showAnnouncement(message: string, duration: number?): ()
	if not announcementText or not announcementVisible then
		return
	end

	if announcementHideThread then
		task.cancel(announcementHideThread)
		announcementHideThread = nil
	end

	announcementText:set(message)
	announcementVisible:set(true)

	local hideDuration = duration or 3
	announcementHideThread = task.delay(hideDuration, function()
		if announcementVisible then
			announcementVisible:set(false)
		end
		announcementHideThread = nil
	end)
end

local cleanupStartScreen: () -> ()
local dismissStartScreen: () -> ()

cleanupStartScreen = function(): ()
	if startScreenScope then
		startScreenScope:doCleanup()
		startScreenScope = nil
	end
	startScreenGui = nil
	startScreenCountdown = nil
	startScreenMaxScore = nil
	startScreenDismiss = nil
	isStartScreenActive = false
end

local function showStartScreen(currentMaxScore: number): ()
	if isStartScreenActive then
		return
	end
	cleanupStartScreen()
	isStartScreenActive = true

	startScreenScope = Fusion.scoped(Fusion)
	startScreenCountdown = startScreenScope:Value(5)
	startScreenMaxScore = startScreenScope:Value(currentMaxScore)

	local gui, dismissFn = StartScreen(startScreenScope, {
		Countdown = startScreenCountdown,
		MaxPoints = startScreenMaxScore,
		GameId = matchGameId,
		Mode = "Domination",
		OnDismissed = function()
			cleanupStartScreen()
			updateVisibility()
		end,
	})

	startScreenGui = gui
	startScreenDismiss = dismissFn

	if playerGui then
		startScreenGui.Parent = playerGui
	end

	if announcementVisible then
		announcementVisible:set(false)
	end
end

dismissStartScreen = function(): ()
	if not isStartScreenActive then
		return
	end
	if startScreenDismiss then
		startScreenDismiss()
	else
		cleanupStartScreen()
		updateVisibility()
	end
end

local function hideAllUI(): ()
	if visible then
		visible:set(false)
	end
	if announcementVisible then
		announcementVisible:set(false)
	end
end

local function restoreUI(): ()
	isWinScreenActive = false
	updateVisibility()
end

local function cleanupWinScreen(): ()
	BlurEffect.forceRemove("WinScreenBlur")
	if winScreenScope then
		winScreenScope:doCleanup()
		winScreenScope = nil
	end
	winScreenGui = nil
end

local function onVictory(victoryData: Network.VictoryData): ()
	if isWinScreenActive then
		return
	end
	isWinScreenActive = true
	hideAllUI()
	cleanupWinScreen()

	local faction = getPlayerFaction()
	local defendersSnapshot = LeaderboardService:GetDefendersData()
	local raidersSnapshot = LeaderboardService:GetRaidersData()

	winScreenScope = Fusion.scoped(Fusion)
	winScreenGui = WinScreen(winScreenScope, {
		VictoryData = victoryData,
		PlayerFaction = faction,
		GameId = matchGameId,
		DefendersData = defendersSnapshot,
		RaidersData = raidersSnapshot,
		OnComplete = function()
			cleanupWinScreen()
			restoreUI()
		end,
	})

	if playerGui then
		winScreenGui.Parent = playerGui
	end
end

local function onDominationUpdate(state: Network.DominationState): ()
	if not hudGui then
		return
	end

	if defenderScore then
		defenderScore:set(state.DefenderScore)
	end
	if hostileScore then
		hostileScore:set(state.HostileScore)
	end
	if maxScore then
		maxScore:set(state.MaxScore)
	end
	if official then
		official:set(state.Official)
	end

	if points then
		local uiPoints: { DominationPointUIState } = table.create(#state.Points)
		for _, pt in state.Points do
			table.insert(uiPoints, {
				Label = pt.Label,
				Owner = pt.Owner :: Owner,
				Progress = pt.Progress,
				ProgressOwner = pt.ProgressOwner :: Owner,
				Contested = pt.Contested,
			})
		end
		points:set(uiPoints)
	end

	local isCountingDown = state.CountingDown

	if isCountingDown and not wasCountingDown then
		showStartScreen(state.MaxScore)
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
end

local function onDominationAnnouncement(announcement: Network.DominationAnnouncement): ()
	if announcement.Type == "RAID_STARTING" and isStartScreenActive then
		local num = string.match(announcement.Message, "(%d+)$")
		if num and startScreenCountdown then
			local countdownNum = tonumber(num) or 5
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

	local duration = announcement.Countdown or 3
	showAnnouncement(announcement.Message, duration)

	if announcement.Type ~= "RAID_STARTING" then
		playNotificationSound()
	end
end

local function buildInitialPoints(count: number): { DominationPointUIState }
	local result: { DominationPointUIState } = table.create(count)
	local LABELS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	for i = 1, count do
		table.insert(result, {
			Label = string.sub(LABELS, i, i),
			Owner = nil,
			Progress = 0,
			ProgressOwner = nil,
			Contested = false,
		})
	end
	return result
end

local function attachBillboardToPoint(hudScope: any, ptState: any, i: number, pointsFolder: Instance): ()
	local labelText = string.sub("ABCDEFGHIJKLMNOPQRSTUVWXYZ", i, i)
	local part = pointsFolder:WaitForChild(labelText, 10) or pointsFolder:WaitForChild(tostring(i), 2)
	if part and part:IsA("BasePart") then
		local mapConfig = Maps.getConfig()
		local studsOffset: Vector3? = nil
		if mapConfig and mapConfig.PointBillboardOffsets then
			studsOffset = mapConfig.PointBillboardOffsets[labelText]
				or mapConfig.PointBillboardOffsets[tostring(i)]
				or (mapConfig.PointBillboardOffsets :: any)[i]
		end

		local billboard = DominationPointBillboard(hudScope, {
			State = ptState,
			Adornee = part,
			StudsOffset = studsOffset,
		})
		billboard.Parent = part
	end
end

local function createHUD(): ()
	if hudGui then
		return
	end

	local mapConfig = Maps.getConfig()
	local domDefaults = DominationConfig.DEFAULT
	local domPointCount: number = (mapConfig :: any).DominationPointCount or domDefaults.PointCount
	local domMaxScore: number = (mapConfig :: any).DominationMaxScore or domDefaults.MaxScore

	scope = Fusion.scoped(Fusion)

	defenderScore = scope:Value(0)
	hostileScore = scope:Value(0)
	maxScore = scope:Value(domMaxScore)
	points = scope:Value(buildInitialPoints(domPointCount))
	official = scope:Value(false)
	visible = scope:Value(false)
	announcementText = scope:Value("")
	announcementVisible = scope:Value(false)

	hudGui = DominationHUD(scope, {
		DefenderScore = defenderScore,
		HostileScore = hostileScore,
		MaxScore = maxScore,
		Points = points,
		Official = official,
		Visible = visible,
		AnnouncementText = announcementText,
		AnnouncementVisible = announcementVisible,
	})

	task.spawn(function()
		local pointsFolder = workspace:WaitForChild("DominationPoints", 10)
		if not pointsFolder then
			return
		end

		for i = 1, domPointCount do
			local ptState = scope:Computed(function(use: FusionUseFn)
				local pts = use(points)
				if not pts then
					return nil
				end
				return pts[i]
			end)
			task.spawn(attachBillboardToPoint, scope, ptState, i, pointsFolder)
		end
	end)

	if playerGui then
		hudGui.Parent = playerGui
	end
end

local function destroyHUD(): ()
	if scope then
		scope:doCleanup()
		scope = nil
	end
	hudGui = nil
	defenderScore = nil
	hostileScore = nil
	maxScore = nil
	points = nil
	official = nil
	visible = nil
	announcementText = nil
	announcementVisible = nil
end

local function fetchInitialState(): ()
	local state = Network.Domination.getState()
	if not state then
		return
	end
	onDominationUpdate(state)
end

function DominationHUDService:init(): ()
	isActive = Maps.isDominationMap()
	playerGui = PlayerGuiHelper.waitForPlayerGui()
end

function DominationHUDService:start(): ()
	if not isActive then
		return
	end

	matchGameId = generateGameId()
	createHUD()

	deployConnection = Network.Deploy.onDeployComplete(onDeployComplete)
	characterConnection = LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

	if LocalPlayer.Character then
		onCharacterAdded(LocalPlayer.Character)
	end

	updateConnection = Network.Domination.onUpdate(onDominationUpdate)
	announcementConnection = Network.Domination.onAnnouncement(onDominationAnnouncement)
	victoryConnection = Network.Domination.onVictory(onVictory)

	task.spawn(fetchInitialState)
end

function DominationHUDService:IsActive(): boolean
	return isActive
end

function DominationHUDService:Cleanup(): ()
	if deployConnection then
		deployConnection:Disconnect()
		deployConnection = nil
	end
	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end
	if announcementConnection then
		announcementConnection:Disconnect()
		announcementConnection = nil
	end
	if victoryConnection then
		victoryConnection:Disconnect()
		victoryConnection = nil
	end
	if announcementHideThread then
		task.cancel(announcementHideThread)
		announcementHideThread = nil
	end
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

	cleanupStartScreen()
	cleanupWinScreen()
	destroyHUD()

	if notificationSound then
		notificationSound:Destroy()
		notificationSound = nil
	end

	isActive = false
	hasDeployed = false
	isWinScreenActive = false
	wasCountingDown = false
end

return DominationHUDService
