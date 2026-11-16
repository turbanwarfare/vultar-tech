--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local FactionUtils = require(MainModule.Shared.Utils.Game.FactionUtils)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local TerminalHUD = require(MainModule.Client.Components.TerminalHUD)
local WinScreen = require(MainModule.Client.Components.WinScreen)
local StartScreen = require(MainModule.Client.Components.StartScreen)
local Maps = require(MainModule.Shared.Config.Maps)
local Network = require(MainModule.Shared.Network)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)
local LeaderboardService = require(MainModule.Client.Services.LeaderboardService)
local BlurEffect = require(MainModule.Client.Utils.UI.BlurEffect)

local TerminalService = {}
TerminalService.Name = "TerminalService"

local LocalPlayer = Players.LocalPlayer

type Owner = TerminalHUD.Owner

local scope: any = nil
local hudGui: ScreenGui? = nil
local playerGui: PlayerGui? = nil

local defenderScore: any = nil
local hostileScore: any = nil
local maxPoints: any = nil
local owner: any = nil
local official: any = nil
local visible: any = nil
local announcementText: any = nil
local announcementVisible: any = nil

local isActive: boolean = false
local hasDeployed: boolean = false

local deployConnection: RBXScriptConnection? = nil
local characterConnection: RBXScriptConnection? = nil
local characterRemovingConnection: RBXScriptConnection? = nil
local hardpointUpdateConnection: RBXScriptConnection? = nil
local hardpointAnnouncementConnection: RBXScriptConnection? = nil
local hardpointVictoryConnection: RBXScriptConnection? = nil
local announcementHideThread: thread? = nil
local countdownDismissThread: thread? = nil
local countdownChainThread1: thread? = nil
local countdownChainThread2: thread? = nil

local winScreenScope: any = nil
local winScreenGui: ScreenGui? = nil
local isWinScreenActive: boolean = false

local startScreenScope: any = nil
local startScreenGui: ScreenGui? = nil
local isStartScreenActive: boolean = false
local startScreenCountdown: any = nil
local startScreenMaxPoints: any = nil
local startScreenDismiss: (() -> ())? = nil
local wasCountingDown: boolean = false
local matchGameId: string = ""
local cleanupStartScreen: () -> ()
local dismissStartScreen: () -> ()

local MARKER_ASSET = "rbxassetid://70911598639762"
local RING_ASSET = "rbxassetid://118320612601922"
local NEUTRAL_COLOR = Color3.fromRGB(255, 255, 255)
local DEFENDER_COLOR = Color3.fromRGB(170, 0, 0)
local HOSTILE_COLOR = Color3.fromRGB(0, 85, 255)

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

local NOTIFICATION_SOUND_ID = "rbxassetid://1301600348"
local NOTIFICATION_VOLUME = 0.5
local notificationSound: Sound? = nil

local RING_SIZE = 18
local MARKER_SIZE = 20

type TerminalVisuals = {
	marker: ImageLabel?,
	ring: ImageLabel?,
	markerPart: Part?,
	ringPart: Part?,
	rotationTween: Tween?,
}

local terminalVisuals: { [string]: TerminalVisuals } = {}
local terminalVisualConnection: RBXScriptConnection? = nil

local COLOR_TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RING_ROTATION_INFO = TweenInfo.new(12, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 0)

local function getOwnerColor(ownerValue: Owner): Color3
	if ownerValue == "Defenders" then
		return DEFENDER_COLOR
	elseif ownerValue == "Hostiles" then
		return HOSTILE_COLOR
	end
	return NEUTRAL_COLOR
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

local function cleanupExistingVisualParts(terminalPart: BasePart): ()
	local existingRing = terminalPart:FindFirstChild("TerminalRingPart")
	if existingRing then
		existingRing:Destroy()
	end
	local existingMarker = terminalPart:FindFirstChild("TerminalMarkerPart")
	if existingMarker then
		existingMarker:Destroy()
	end
end

local function createTerminalVisuals(terminalPart: BasePart): TerminalVisuals
	cleanupExistingVisualParts(terminalPart)

	local terminalPos = terminalPart.Position

	local ringPart = Instance.new("Part")
	ringPart.Name = "TerminalRingPart"
	ringPart.Size = Vector3.new(RING_SIZE, 0.05, RING_SIZE)
	ringPart.Position = Vector3.new(terminalPos.X, terminalPos.Y + 0.1, terminalPos.Z)
	ringPart.Anchored = true
	ringPart.CanCollide = false
	ringPart.CanQuery = false
	ringPart.CanTouch = false
	ringPart.Transparency = 1
	ringPart.Parent = terminalPart

	local ringSurfaceGui = Instance.new("SurfaceGui")
	ringSurfaceGui.Name = "RingSurfaceGui"
	ringSurfaceGui.Face = Enum.NormalId.Top
	ringSurfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	ringSurfaceGui.PixelsPerStud = 50
	ringSurfaceGui.Adornee = ringPart
	ringSurfaceGui.Parent = ringPart

	local ring = Instance.new("ImageLabel")
	ring.Name = "Ring"
	ring.Size = UDim2.fromScale(1, 1)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.Image = RING_ASSET
	ring.ImageColor3 = NEUTRAL_COLOR
	ring.Parent = ringSurfaceGui

	local markerPart = Instance.new("Part")
	markerPart.Name = "TerminalMarkerPart"
	markerPart.Size = Vector3.new(MARKER_SIZE, 0.05, MARKER_SIZE)
	markerPart.Position = Vector3.new(terminalPos.X, terminalPos.Y + 15, terminalPos.Z)
	markerPart.Anchored = true
	markerPart.CanCollide = false
	markerPart.CanQuery = false
	markerPart.CanTouch = false
	markerPart.Transparency = 1
	markerPart.Parent = terminalPart

	local markerBillboard = Instance.new("BillboardGui")
	markerBillboard.Name = "TerminalMarker"
	markerBillboard.Size = UDim2.fromOffset(25, 25)
	markerBillboard.AlwaysOnTop = true
	markerBillboard.Adornee = markerPart
	markerBillboard.Parent = markerPart

	local marker = Instance.new("ImageLabel")
	marker.Name = "Marker"
	marker.Size = UDim2.fromScale(1, 1)
	marker.Position = UDim2.fromScale(0.5, 0.5)
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.BackgroundTransparency = 1
	marker.Image = MARKER_ASSET
	marker.ImageColor3 = NEUTRAL_COLOR
	marker.Parent = markerBillboard

	local rotationTween = TweenService:Create(ring, RING_ROTATION_INFO, { Rotation = 360 })
	rotationTween:Play()

	return {
		marker = marker,
		ring = ring,
		markerPart = markerPart,
		ringPart = ringPart,
		rotationTween = rotationTween,
	}
end

local function updateTerminalColor(pointName: string, color: Color3): ()
	local visuals = terminalVisuals[pointName]
	if not visuals then
		return
	end

	if visuals.marker then
		local markerTween = TweenService:Create(visuals.marker, COLOR_TWEEN_INFO, { ImageColor3 = color })
		markerTween:Play()
	end

	if visuals.ring then
		local ringTween = TweenService:Create(visuals.ring, COLOR_TWEEN_INFO, { ImageColor3 = color })
		ringTween:Play()
	end
end

local function removeTerminalVisuals(pointName: string): ()
	local visuals = terminalVisuals[pointName]
	if not visuals then
		return
	end

	if visuals.rotationTween then
		visuals.rotationTween:Cancel()
	end

	if visuals.markerPart then
		visuals.markerPart:Destroy()
	end

	if visuals.ringPart then
		visuals.ringPart:Destroy()
	end

	terminalVisuals[pointName] = nil
end

local function clearAllTerminalVisuals(): ()
	for pointName, _ in terminalVisuals do
		removeTerminalVisuals(pointName)
	end
end

local function onTerminalVisual(pointName: string, action: string, color: Color3?): ()
	if action == "Start" then
		local terminalPointsFolder = workspace:FindFirstChild("TerminalPoints")
		if not terminalPointsFolder then
			return
		end

		local terminalPart = terminalPointsFolder:FindFirstChild(pointName)
		if not terminalPart or not terminalPart:IsA("BasePart") then
			return
		end

		if not terminalVisuals[pointName] then
			terminalVisuals[pointName] = createTerminalVisuals(terminalPart)
		end

		updateTerminalColor(pointName, color or NEUTRAL_COLOR)
	elseif action == "Capture" then
		if color then
			updateTerminalColor(pointName, color)
		end
	elseif action == "End" then
		removeTerminalVisuals(pointName)
	end
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

local function onCharacterRemoving(_character: Model): () end

local function onDeployComplete(): ()
	hasDeployed = true
	updateVisibility()
end

local function createHUD(): ()
	if hudGui then
		return
	end

	local mapConfig = Maps.getConfig()

	scope = Fusion.scoped(Fusion)

	defenderScore = scope:Value(0)
	hostileScore = scope:Value(0)
	maxPoints = scope:Value(mapConfig.DefaultPoints)
	owner = scope:Value(nil :: Owner)
	official = scope:Value(false)
	visible = scope:Value(false)
	announcementText = scope:Value("")
	announcementVisible = scope:Value(false)

	hudGui = TerminalHUD(scope, {
		DefenderScore = defenderScore,
		HostileScore = hostileScore,
		MaxPoints = maxPoints,
		Owner = owner,
		Official = official,
		Visible = visible,
		AnnouncementText = announcementText,
		AnnouncementVisible = announcementVisible,
	})

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
	maxPoints = nil
	owner = nil
	official = nil
	visible = nil
	announcementText = nil
	announcementVisible = nil
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

cleanupStartScreen = function(): ()
	if startScreenScope then
		startScreenScope:doCleanup()
		startScreenScope = nil
	end
	startScreenGui = nil
	startScreenCountdown = nil
	startScreenMaxPoints = nil
	startScreenDismiss = nil
	isStartScreenActive = false
end

local function showStartScreen(currentMaxPoints: number): ()
	if isStartScreenActive then
		return
	end

	cleanupStartScreen()

	isStartScreenActive = true

	startScreenScope = Fusion.scoped(Fusion)
	startScreenCountdown = startScreenScope:Value(5)
	startScreenMaxPoints = startScreenScope:Value(currentMaxPoints)

	local gui, dismissFn = StartScreen(startScreenScope, {
		Countdown = startScreenCountdown,
		MaxPoints = startScreenMaxPoints,
		GameId = matchGameId,
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

local function onHardpointUpdate(state: Network.HardpointState): ()
	if not hudGui then
		return
	end

	if maxPoints then
		maxPoints:set(state.MaxPoints)
	end
	if defenderScore then
		defenderScore:set(state.DefenderScore)
	end
	if hostileScore then
		hostileScore:set(state.HostileScore)
	end
	if owner then
		owner:set(state.Owner)
	end
	if official then
		official:set(state.Official)
	end

	local isCountingDown = state.CountingDown

	if isCountingDown and not wasCountingDown then
		showStartScreen(state.MaxPoints)
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

local function onHardpointAnnouncement(announcement: Network.HardpointAnnouncement): ()
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

local function getPlayerFaction(): "Defenders" | "Raiders" | "Neutral"
	local teamName = Network.Teams.getCurrentTeam()
	if not teamName then
		return "Neutral"
	end
	return FactionUtils.getTeamFaction(teamName) :: any
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

function TerminalService:init(): ()
	local mapConfig = Maps.getConfig()
	isActive = mapConfig.Hardpoint
	playerGui = PlayerGuiHelper.waitForPlayerGui()
end

local function fetchInitialState(): ()
	local state = Network.Hardpoint.getState()
	if not state then
		return
	end

	onHardpointUpdate(state)

	if state.Official and state.CurrentPointName then
		clearAllTerminalVisuals()
		local ownerColor = getOwnerColor(state.Owner)
		onTerminalVisual(state.CurrentPointName, "Start", ownerColor)
	end
end

function TerminalService:start(): ()
	if not isActive then
		return
	end

	matchGameId = generateGameId()
	createHUD()

	deployConnection = Network.Deploy.onDeployComplete(onDeployComplete)
	characterConnection = LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
	characterRemovingConnection = LocalPlayer.CharacterRemoving:Connect(onCharacterRemoving)

	if LocalPlayer.Character then
		onCharacterAdded(LocalPlayer.Character)
	end

	hardpointUpdateConnection = Network.Hardpoint.onUpdate(onHardpointUpdate)
	hardpointAnnouncementConnection = Network.Hardpoint.onAnnouncement(onHardpointAnnouncement)
	hardpointVictoryConnection = Network.Hardpoint.onVictory(onVictory)
	terminalVisualConnection = Network.Hardpoint.onTerminalVisual(onTerminalVisual)

	task.spawn(fetchInitialState)
end

function TerminalService:SetVisible(isVisible: boolean): ()
	if visible then
		visible:set(isVisible)
	end
end

function TerminalService:Update(newMaxPoints: number, newDefenderScore: number, newHostileScore: number, newOwner: Owner): ()
	if not hudGui then
		return
	end

	if maxPoints then
		maxPoints:set(newMaxPoints)
	end
	if defenderScore then
		defenderScore:set(newDefenderScore)
	end
	if hostileScore then
		hostileScore:set(newHostileScore)
	end
	if owner then
		owner:set(newOwner)
	end
end

function TerminalService:SetOwner(newOwner: Owner): ()
	if owner then
		owner:set(newOwner)
	end
end

function TerminalService:SetMaxPoints(points: number): ()
	if maxPoints then
		maxPoints:set(points)
	end
end

function TerminalService:AddDefenderScore(amount: number): ()
	if defenderScore then
		local current = Fusion.peek(defenderScore)
		defenderScore:set(current + amount)
	end
end

function TerminalService:AddHostileScore(amount: number): ()
	if hostileScore then
		local current = Fusion.peek(hostileScore)
		hostileScore:set(current + amount)
	end
end

function TerminalService:Reset(): ()
	if defenderScore then
		defenderScore:set(0)
	end
	if hostileScore then
		hostileScore:set(0)
	end
	if owner then
		owner:set(nil)
	end
	cleanupStartScreen()
	wasCountingDown = false
end

function TerminalService:GetState(): {
	defenderScore: number,
	hostileScore: number,
	maxPoints: number,
	owner: Owner,
}
	return {
		defenderScore = defenderScore and Fusion.peek(defenderScore) or 0,
		hostileScore = hostileScore and Fusion.peek(hostileScore) or 0,
		maxPoints = maxPoints and Fusion.peek(maxPoints) or 0,
		owner = owner and Fusion.peek(owner) or nil,
	}
end

function TerminalService:IsActive(): boolean
	return isActive
end

function TerminalService:HasDeployed(): boolean
	return hasDeployed
end

function TerminalService:Cleanup(): ()
	if deployConnection then
		deployConnection:Disconnect()
		deployConnection = nil
	end

	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end

	if characterRemovingConnection then
		characterRemovingConnection:Disconnect()
		characterRemovingConnection = nil
	end

	if hardpointUpdateConnection then
		hardpointUpdateConnection:Disconnect()
		hardpointUpdateConnection = nil
	end

	if hardpointAnnouncementConnection then
		hardpointAnnouncementConnection:Disconnect()
		hardpointAnnouncementConnection = nil
	end

	if hardpointVictoryConnection then
		hardpointVictoryConnection:Disconnect()
		hardpointVictoryConnection = nil
	end

	if terminalVisualConnection then
		terminalVisualConnection:Disconnect()
		terminalVisualConnection = nil
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
	clearAllTerminalVisuals()
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

return TerminalService
