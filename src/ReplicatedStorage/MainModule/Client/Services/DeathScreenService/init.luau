--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local NewDeathScreen = require(MainModule.Client.Components.NewDeathScreen)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)
local Network = require(MainModule.Shared.Network)
local GunCache = require(MainModule.Client.Services.GunService.Cache)
local GunStats = require(MainModule.Shared.Config.GunStats)
local FactionUtils = require(MainModule.Shared.Utils.Game.FactionUtils)
local Maps = require(MainModule.Shared.Config.Maps)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local FadeGroup = require(MainModule.Client.Utils.UI.FadeGroup)
local Profile = require(MainModule.Shared.Utils.Debug.Profile)
local DeathScreenFill = require(script.DeathScreenFill)
local HitDots = require(script.HitDots)

export type DeathScreenData = {
	killerUserId: number,
	killerName: string,
	gunName: string,
	range: number,
	killerHealth: number,
	playerCardImage: string?,
	isAnimatedCard: boolean?,
}

export type DeathScreenPhase = "hidden" | "visible" | "fadeout"

type Ui = {
	gui: ScreenGui,
	uiScale: UIScale,
	sections: { GuiObject },
	killer: DeathScreenFill.KillerLabels,
	card: DeathScreenFill.CardLabels,
	time: TextLabel,
	filler: Frame,
	reportButtonFrame: Frame,
	reportButton: TextButton,
	report: Frame,
	closeButton: TextButton,
	receivedList: ScrollingFrame,
	dealtList: Frame,
	totals: DeathScreenFill.ReportLabels,
	dotFrame: Frame,
	view: ViewportFrame,
	camera: Camera,
	world: WorldModel,
}

local DeathScreenService = {}
DeathScreenService.Name = "DeathScreenService"

local TEST_MODE = false
local COUNTDOWN_SOUND_ID = "rbxassetid://97753242022817"
local COUNTDOWN_SOUND_OFFSET = 0.131
local DESIGN_WIDTH = 1920
local DESIGN_HEIGHT = 1080
local MAX_DEALT_ROWS = 3
local UI_SIZE = 0.75
local FADE_IN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local player = Players.LocalPlayer

local isInitialized = false
local isSuspended = false

local scope: any = nil
local ui: Ui? = nil
local phase: DeathScreenPhase = "hidden"
local currentRespawnDuration = 5
local currentData: DeathScreenData? = nil
local currentHasKillLog = false

local reportScope: any = nil
local reportLoading = false

local testData: DeathScreenData? = nil
local countdownThread: thread? = nil
local testCycleThread: thread? = nil
local characterConnection: RBXScriptConnection? = nil
local deathConnection: { Disconnect: () -> () }? = nil
local countdownSound: Sound? = nil
local connections: { RBXScriptConnection } = {}
local fade: FadeGroup.FadeGroup? = nil

local function find(root: Instance, ...: string): any
	local node: Instance = root
	for _, name in { ... } do
		local nextNode = node:FindFirstChild(name)
		if not nextNode then
			error(`[DeathScreenService] Missing {name} under {node:GetFullName()}`)
		end
		node = nextNode
	end
	return node
end

local function gunImageFor(gunName: string?): string
	local stats = if gunName then GunStats.get(gunName) else nil
	if not stats or not stats.GunImageId then
		return ""
	end
	return "rbxassetid://" .. tostring(stats.GunImageId)
end

local function playerNameFor(userId: number): string
	local target = Players:GetPlayerByUserId(userId)
	return if target then target.Name else "Unknown"
end

local function stopCountdownSound(): ()
	if countdownSound then
		countdownSound:Stop()
		countdownSound:Destroy()
		countdownSound = nil
	end
end

local function playCountdownSound(): ()
	stopCountdownSound()

	if not GunCache.getCountdownSoundsEnabled() then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = COUNTDOWN_SOUND_ID
	sound.Volume = 1
	sound.TimePosition = COUNTDOWN_SOUND_OFFSET
	sound.Parent = SoundService
	sound:Play()
	countdownSound = sound

	sound.Ended:Once(function()
		if countdownSound == sound then
			sound:Destroy()
			countdownSound = nil
		end
	end)
end

local function cancelCountdownThread(): ()
	if countdownThread then
		task.cancel(countdownThread)
		countdownThread = nil
	end
end

local function cancelTestCycleThread(): ()
	if testCycleThread then
		task.cancel(testCycleThread)
		testCycleThread = nil
	end
end

local function cleanupCharacterConnection(): ()
	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end
end

local function attach(child: Instance, parent: Instance): ()
	child.Parent = parent
end

local function getCamera(): Camera?
	return workspace.CurrentCamera
end

local function updateScale(): ()
	local current = ui
	local camera = getCamera()
	if not current or not camera then
		return
	end
	local size = camera.ViewportSize
	local scale = math.min(size.X / DESIGN_WIDTH, size.Y / DESIGN_HEIGHT) * UI_SIZE
	current.uiScale.Scale = scale
	local canvas = current.uiScale.Parent :: GuiObject
	canvas.Size = UDim2.fromOffset(size.X / scale, size.Y / scale)
end

local function buildUi(): Ui?
	if ui then
		return ui
	end

	scope = Fusion.scoped(Fusion)
	local gui = Profile.run("Vultar::NewDeathScreen::create", NewDeathScreen.create, scope)
	local canvas = find(gui, "Canvas")
	local info = find(canvas, "Content", "Info")
	local stats = find(info, "Stats")
	local respawn = find(canvas, "RespawnContent")
	local report = find(canvas, "Report")
	local view = find(report, "VP", "View")

	local built: Ui = {
		gui = gui,
		uiScale = find(canvas, "UIScale"),
		sections = { find(gui, "Overlay"), find(canvas, "Eliminated"), find(canvas, "Content"), respawn },
		killer = {
			avatar = find(canvas, "Content", "Avatar"),
			killerName = find(info, "KillerName"),
			teamIcon = find(stats, "TeamGroup", "Icon"),
			team = find(stats, "TeamGroup", "Team"),
			gunImage = find(stats, "GunGroup", "GunImage"),
			gun = find(stats, "GunGroup", "Gun"),
			studs = find(stats, "Studs"),
			hp = find(stats, "HP"),
		},
		card = {
			box = find(canvas, "Content", "CardBox"),
			static = find(canvas, "Content", "CardBox", "CardImage"),
		},
		time = find(respawn, "Time"),
		filler = find(respawn, "RespawnBar", "Filler"),
		reportButtonFrame = find(respawn, "DeathReport"),
		reportButton = find(respawn, "DeathReport", "Extend", "Button"),
		report = report,
		closeButton = find(report, "Close", "Extend", "Button"),
		receivedList = find(report, "List"),
		dealtList = find(report, "Outgoing"),
		totals = {
			receivedSummary = find(report, "IncomingHeader", "Summary"),
			totalTaken = find(report, "Total", "Value"),
			dealtSummary = find(report, "OutgoingHeader", "Summary"),
			accuracy = find(report, "Accuracy"),
			matchAccuracy = find(report, "MatchAccuracy"),
		},
		dotFrame = find(report, "VP"),
		view = view,
		camera = find(view, "Camera"),
		world = find(view, "WorldModel"),
	}
	built.view.CurrentCamera = built.camera
	ui = built

	local camera = getCamera()
	if camera then
		table.insert(connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))
	end
	updateScale()

	local playerGui = PlayerGuiHelper.waitForPlayerGui()
	if playerGui then
		gui.Parent = playerGui
	end

	return built
end

local function setSectionsVisible(visible: boolean): ()
	local current = ui
	if not current then
		return
	end
	for _, section in current.sections do
		section.Visible = visible
	end
end

local function clearReport(): ()
	if reportScope then
		Profile.run("Vultar::DeathScreen::clearReport", reportScope.doCleanup, reportScope)
		reportScope = nil
	end
end

local function closeReport(): ()
	local current = ui
	if not current then
		return
	end
	current.report.Visible = false
	clearReport()
	if phase == "hidden" then
		current.gui.Enabled = false
	end
end

local function loadAvatarModel(): Model?
	local character = player.Character
	if character then
		local ok, result = pcall(function()
			local wasArchivable = character.Archivable
			character.Archivable = true
			local clone = character:Clone()
			character.Archivable = wasArchivable
			return clone
		end)
		if ok and result then
			return result
		end
	end

	local ok, result = pcall(function()
		local description = Players:GetHumanoidDescriptionFromUserId(player.UserId)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	if ok and result then
		return result
	end

	return nil
end

local function applyRowStyle(row: Frame, headshot: boolean): ()
	local style = if headshot then NewDeathScreen.Styles.Row.Headshot else NewDeathScreen.Styles.Row.Normal
	find(row, "GunName").TextColor3 = style.TextColor
	find(row, "Dmg").TextColor3 = style.TextColor
	find(row, "GunImage").ImageColor3 = style.GunImageColor
	local part = row:FindFirstChild("Part")
	if part and part:IsA("TextLabel") then
		part.TextColor3 = style.PartColor
	end
end

local function rowLabels(row: Frame): DeathScreenFill.RowLabels
	return {
		gunName = find(row, "GunName"),
		gunImage = find(row, "GunImage"),
		damage = find(row, "Dmg"),
		playerName = find(row, "Name"),
		bodyPart = row:FindFirstChild("Part") :: TextLabel?,
	}
end

local function drawHitDots(current: Ui, hitLog: { Network.HitLogEntry }, avatar: Model): ()
	HitDots.prepareAvatar(avatar)
	avatar.Parent = current.world
	table.insert(reportScope, avatar)

	local camCF = HitDots.aimCamera(current.camera, avatar)
	if not camCF then
		return
	end

	local frameWidth = current.dotFrame.Size.X.Offset
	local frameHeight = current.dotFrame.Size.Y.Offset

	for _, entry in hitLog do
		local x, y, visible = HitDots.project(avatar, camCF, entry.bodyPart, Vector3.new(entry.localX, entry.localY, entry.localZ), frameWidth, frameHeight)
		if visible then
			local style = if entry.headshot then NewDeathScreen.Styles.Dot.Headshot else NewDeathScreen.Styles.Dot.Body
			local dot = Profile.run("Vultar::NewDeathScreen::createHitDot", NewDeathScreen.createHitDot, reportScope)
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Size = UDim2.fromOffset(style.Size, style.Size)
			dot.Position = UDim2.fromOffset(x, y)
			dot.BackgroundColor3 = style.Color
			find(dot, "UIStroke").Color = style.Color
			dot.Parent = current.dotFrame
		end
	end
end

local function placeHitDots(current: Ui, hitLog: { Network.HitLogEntry }): ()
	local avatar = loadAvatarModel()
	if avatar then
		Profile.run("Vultar::DeathScreen::placeHitDots", drawHitDots, current, hitLog, avatar)
	end
end

local function fillReport(
	current: Ui,
	hitLog: { Network.HitLogEntry },
	dealtLog: { Network.OutgoingHitEntry },
	accuracyStats: { accuracy: number, matchAccuracy: number }?
): ()
	clearReport()
	reportScope = Fusion.scoped(Fusion)

	local damageTaken = 0
	for index, entry in hitLog do
		damageTaken += entry.damage
		local gunName = GunStats.GUN_INDEX_TO_NAME[entry.gunIndex] or ""
		local row = Profile.run("Vultar::NewDeathScreen::createIncomingRow", NewDeathScreen.createIncomingRow, reportScope)
		row.LayoutOrder = index
		applyRowStyle(row, entry.headshot)
		DeathScreenFill.receivedRow(rowLabels(row), {
			gunName = gunName,
			gunImage = gunImageFor(gunName),
			damage = entry.damage,
			playerName = playerNameFor(entry.attackerId),
			bodyPart = HitDots.bodyPartName(entry.bodyPart),
			headshot = entry.headshot,
		})
		row.Parent = current.receivedList
	end

	local damageDealt = 0
	for _, entry in dealtLog do
		damageDealt += entry.damage
	end

	local firstShown = math.max(1, #dealtLog - MAX_DEALT_ROWS + 1)
	for index = firstShown, #dealtLog do
		local entry = dealtLog[index]
		local gunName = GunStats.GUN_INDEX_TO_NAME[entry.gunIndex] or ""
		local row = Profile.run("Vultar::NewDeathScreen::createOutgoingRow", NewDeathScreen.createOutgoingRow, reportScope)
		row.LayoutOrder = index
		applyRowStyle(row, entry.headshot)
		DeathScreenFill.dealtRow(rowLabels(row), {
			gunName = gunName,
			gunImage = gunImageFor(gunName),
			damage = entry.damage,
			playerName = playerNameFor(entry.targetId),
			bodyPart = if entry.headshot then "Head" else "Body",
			headshot = entry.headshot,
		})
		attach(row, current.dealtList)
	end

	DeathScreenFill.reportTotals(current.totals, {
		hitsTaken = #hitLog,
		damageTaken = damageTaken,
		hitsDealt = #dealtLog,
		damageDealt = damageDealt,
		accuracy = if accuracyStats then accuracyStats.accuracy else nil,
		matchAccuracy = if accuracyStats then accuracyStats.matchAccuracy else nil,
	})
end

local function buildReport(killLog: Network.KillLogData?, accuracyStats: { accuracy: number, matchAccuracy: number }?): ()
	local current = ui
	if not current then
		return
	end

	local hitLog: { Network.HitLogEntry } = if killLog and killLog.hitLog then killLog.hitLog else {}
	local dealtLog: { Network.OutgoingHitEntry } = if killLog and killLog.outgoingLog then killLog.outgoingLog else {}
	Profile.run("Vultar::DeathScreen::buildReport", fillReport, current, hitLog, dealtLog, accuracyStats)
	placeHitDots(current, hitLog)
	current.report.Visible = true
end

local function openReport(): ()
	local current = ui
	if not current or phase ~= "visible" or not currentHasKillLog or reportLoading or current.report.Visible then
		return
	end

	reportLoading = true
	task.spawn(function()
		local accuracyStats: any = nil
		local getAccuracy = ReplicatedStorage:WaitForChild("GetAccuracyStats", 5)
		if getAccuracy and getAccuracy:IsA("RemoteFunction") then
			local ok, result = pcall(function()
				return getAccuracy:InvokeServer()
			end)
			if ok and typeof(result) == "table" then
				accuracyStats = result
			end
		end

		local ok, killLog = pcall(function(): Network.KillLogData?
			return Network.Death.requestKillLog()
		end)
		reportLoading = false
		if phase ~= "visible" then
			return
		end

		local ran, err = pcall(buildReport :: any, if ok then killLog else nil, accuracyStats)
		if not ran then
			warn("[DeathScreenService] Report failed:", err)
			clearReport()
		end
	end)
end

local function toggleReport(): ()
	local current = ui
	if not current or not current.gui.Enabled then
		return
	end
	if current.report.Visible then
		closeReport()
	else
		openReport()
	end
end

local function hideScreen(): ()
	phase = "hidden"
	stopCountdownSound()
	local current = ui
	if not current then
		return
	end
	current.report.Visible = false
	clearReport()
	local group = fade
	if not group then
		current.gui.Enabled = false
		return
	end
	FadeGroup.tweenTo(group, 0, FADE_OUT_INFO, function()
		if phase == "hidden" then
			current.gui.Enabled = false
		end
	end)
end

local function onCharacterAdded(_character: Model): ()
	if isSuspended then
		return
	end
	cleanupCharacterConnection()
	cancelCountdownThread()
	hideScreen()
end

local function updateRespawnDuration(): ()
	currentRespawnDuration = Maps.getRespawnTime()
end

local startDeathSequence: (data: DeathScreenData) -> ()

local function startCountdown(): ()
	cancelCountdownThread()
	playCountdownSound()

	countdownThread = task.spawn(function()
		local startTime = os.clock()

		while true do
			local remaining = math.max(0, currentRespawnDuration - (os.clock() - startTime))
			local current = ui
			if current then
				current.filler.Size = UDim2.fromScale(remaining / currentRespawnDuration, 1)
				DeathScreenFill.respawnTimer(current.time, remaining)
			end
			if remaining <= 0 then
				break
			end
			task.wait()
		end

		countdownThread = nil

		if TEST_MODE then
			hideScreen()
			testCycleThread = task.delay(3, function()
				testCycleThread = nil
				if testData then
					startDeathSequence(testData)
				end
			end)
			return
		end

		local deadCharacter = player.Character
		characterConnection = player.CharacterAdded:Connect(onCharacterAdded)
		Network.Death.requestRespawn()

		if player.Character and player.Character ~= deadCharacter then
			onCharacterAdded(player.Character)
			return
		end

		task.spawn(function()
			while characterConnection and phase == "visible" do
				task.wait(2.5)
				if characterConnection and phase == "visible" then
					if player.Character and player.Character ~= deadCharacter then
						onCharacterAdded(player.Character)
						break
					end
					Network.Death.requestRespawn()
				end
			end
		end)
	end)
end

local function fillKiller(current: Ui, data: DeathScreenData): ()
	local killerPlayer = Players:GetPlayerByUserId(data.killerUserId)
	local team = if killerPlayer then killerPlayer.Team else nil

	DeathScreenFill.killer(current.killer, {
		userId = data.killerUserId,
		name = data.killerName,
		avatarImage = `rbxthumb://type=AvatarHeadShot&id={data.killerUserId}&w=150&h=150`,
		teamName = if team then team.Name else "",
		faction = if team then FactionUtils.getTeamFaction(team.Name) else "",
		teamColor = if team then team.TeamColor.Color else Color3.new(1, 1, 1),
		gunName = data.gunName,
		gunImage = gunImageFor(data.gunName),
		range = data.range,
		health = data.killerHealth,
	})

	DeathScreenFill.card(current.card, data.playerCardImage, data.isAnimatedCard == true)
end

startDeathSequence = function(data: DeathScreenData): ()
	local current = buildUi()
	if not current then
		return
	end

	updateRespawnDuration()
	cancelCountdownThread()
	cancelTestCycleThread()
	cleanupCharacterConnection()
	closeReport()

	currentData = data
	Profile.run("Vultar::DeathScreen::fillKiller", fillKiller, current, data)
	current.reportButtonFrame.Visible = currentHasKillLog
	current.filler.Size = UDim2.fromScale(1, 1)
	DeathScreenFill.respawnTimer(current.time, currentRespawnDuration)

	setSectionsVisible(true)
	phase = "visible"
	local group: FadeGroup.FadeGroup = fade or FadeGroup.new()
	if not fade then
		FadeGroup.capture(group, current.sections)
		fade = group
	end
	if not current.gui.Enabled then
		FadeGroup.set(group, 0)
		current.gui.Enabled = true
	end
	FadeGroup.tweenTo(group, 1, FADE_IN_INFO)
	startCountdown()
end

local function onDeathData(data: Network.DeathData): ()
	if isSuspended then
		return
	end

	local sw = ServiceLocator.ScreenWatch()
	local isWatching = if sw and typeof(sw.IsWatching) == "function" then sw:IsWatching() else false
	if isWatching then
		updateRespawnDuration()
		task.delay(currentRespawnDuration, function()
			Network.Death.requestRespawn()
		end)
		return
	end

	currentHasKillLog = data.hasKillLog
	startDeathSequence({
		killerUserId = data.killerUserId,
		killerName = data.killerName,
		gunName = data.gunName,
		range = data.range,
		killerHealth = data.killerHealth,
		playerCardImage = data.playerCardImage,
		isAnimatedCard = data.isAnimatedCard,
	})
end

local function bindInput(): ()
	local current = buildUi()
	if not current then
		return
	end

	table.insert(connections, current.reportButton.Activated:Connect(openReport))
	table.insert(connections, current.closeButton.Activated:Connect(closeReport))
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if not gameProcessed and input.KeyCode == Enum.KeyCode.V then
				toggleReport()
			end
		end)
	)
end

function DeathScreenService:init(): ()
	isInitialized = true

	if TEST_MODE then
		testCycleThread = task.spawn(function()
			task.wait(0.5)
			testData = {
				killerUserId = player.UserId,
				killerName = player.DisplayName,
				gunName = "H-82",
				range = 47,
				killerHealth = 100,
				playerCardImage = nil,
				isAnimatedCard = false,
			}
			currentHasKillLog = false
			startDeathSequence(testData :: DeathScreenData)
			testCycleThread = nil
		end)
	end
end

function DeathScreenService:Suspend(): ()
	isSuspended = true
end

function DeathScreenService:Resume(): ()
	isSuspended = false
end

function DeathScreenService:start(): ()
	if not isInitialized then
		self:init()
	end

	task.spawn(bindInput)

	if not TEST_MODE then
		deathConnection = Network.Death.onDeathData(onDeathData)
	end
end

function DeathScreenService:Show(data: DeathScreenData): ()
	startDeathSequence(data)
end

function DeathScreenService:Hide(): ()
	cancelCountdownThread()
	cancelTestCycleThread()
	cleanupCharacterConnection()
	closeReport()
	hideScreen()
end

function DeathScreenService:GetPhase(): DeathScreenPhase
	return phase
end

function DeathScreenService:GetCurrentData(): DeathScreenData?
	return currentData
end

function DeathScreenService:Cleanup(): ()
	isSuspended = false

	cancelCountdownThread()
	cancelTestCycleThread()
	cleanupCharacterConnection()
	stopCountdownSound()
	clearReport()
	testData = nil
	currentData = nil
	currentHasKillLog = false
	reportLoading = false
	phase = "hidden"

	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)

	if deathConnection then
		deathConnection.Disconnect()
		deathConnection = nil
	end

	if fade then
		FadeGroup.destroy(fade)
		fade = nil
	end

	if scope then
		scope:doCleanup()
		scope = nil
	end
	ui = nil

	isInitialized = false
end

return DeathScreenService
