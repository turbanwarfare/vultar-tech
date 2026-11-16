--!native
--!optimize 2

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService")
local GroupService = game:GetService("GroupService")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")

local VULT_GROUP = 35685173

local player = Players.LocalPlayer
if not player then
	return
end

local function showEmergencyUI(message: string, showRejoin: boolean?)
	local playerGui = player:WaitForChild("PlayerGui", 5)
	if not playerGui then
		return
	end

	local existing = playerGui:FindFirstChild("EmergencyUI")
	if existing then
		existing:Destroy()
	end

	local emergencyGui = Instance.new("ScreenGui")
	emergencyGui.Name = "EmergencyUI"
	emergencyGui.AutoLocalize = false
	emergencyGui.DisplayOrder = 1000
	emergencyGui.IgnoreGuiInset = true
	emergencyGui.ResetOnSpawn = false

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(1, 0, 0, 80)
	container.Position = UDim2.new(0, 0, 1, -100)
	container.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	container.BackgroundTransparency = 0.3
	container.BorderSizePixel = 0
	container.Parent = emergencyGui

	local messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "Message"
	messageLabel.Size = UDim2.new(1, -220, 1, 0)
	messageLabel.Position = UDim2.fromOffset(20, 0)
	messageLabel.BackgroundTransparency = 1
	messageLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	messageLabel.TextSize = 16
	messageLabel.Font = Enum.Font.GothamBold
	messageLabel.Text = message
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextWrapped = true
	messageLabel.Parent = container

	if showRejoin then
		local rejoinBtn = Instance.new("TextButton")
		rejoinBtn.Name = "RejoinButton"
		rejoinBtn.Size = UDim2.fromOffset(100, 40)
		rejoinBtn.Position = UDim2.new(1, -120, 0.5, -20)
		rejoinBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 60)
		rejoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		rejoinBtn.TextSize = 14
		rejoinBtn.Font = Enum.Font.GothamBold
		rejoinBtn.Text = "REJOIN"
		rejoinBtn.Parent = container

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = rejoinBtn

		local _rejoinConn = rejoinBtn.Activated:Connect(function()
			pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { player })
		end)
	end

	emergencyGui.Parent = playerGui
end

local MainModule = ReplicatedStorage:WaitForChild("MainModule", 30)
if not MainModule then
	showEmergencyUI("Failed to load game. MainModule not found.", true)
	return
end

local loadError = MainModule:GetAttribute("LoadError")
if loadError then
	showEmergencyUI(`Server error: {loadError}`, true)
	return
end

local Shared = MainModule:WaitForChild("Shared", 10)
if not Shared then
	showEmergencyUI("Failed to load game. Shared module not found.", true)
	return
end

local NetworkModule = Shared:WaitForChild("Network", 10)
if not NetworkModule or not NetworkModule:IsA("ModuleScript") then
	showEmergencyUI("Failed to load game. Network module not found.", true)
	return
end

local Network = require(NetworkModule :: ModuleScript)
if not Network then
	showEmergencyUI("Failed to load game. Network failed to initialize.", true)
	return
end

local pendingProgress: { number | string } = {}
local progressHandler: ((number | string) -> ())? = nil

Network.Progress.onProgressReceived(function(data)
	if progressHandler then
		progressHandler(data)
	else
		table.insert(pendingProgress, data)
	end
end)

Network.Loading.notifyReady()

local playerGui = player:WaitForChild("PlayerGui", 30) :: PlayerGui?
if not playerGui then
	return
end

local loadingScreen = playerGui:WaitForChild("VultarLoadingScreen", 30)
if not loadingScreen then
	return
end

local ConfigFolder = Shared:WaitForChild("Config", 5)
local CreditsModule = ConfigFolder and ConfigFolder:WaitForChild("Credits", 5)
local Credits = CreditsModule and require(CreditsModule)

local canvas = loadingScreen:WaitForChild("Canvas", 5) :: Frame?
if not canvas then
	return
end

local CHILD_TIMEOUT = 5

local uiScale = canvas:WaitForChild("UIScale", CHILD_TIMEOUT) :: UIScale
local shotsFrame = canvas:WaitForChild("Shots", CHILD_TIMEOUT) :: Frame
local shotFade = canvas:WaitForChild("ShotFade", CHILD_TIMEOUT) :: Frame
local shafts = canvas:WaitForChild("Shafts", CHILD_TIMEOUT) :: CanvasGroup
local haze = canvas:WaitForChild("Haze", CHILD_TIMEOUT) :: CanvasGroup
local hazeStrip = haze:WaitForChild("Strip", CHILD_TIMEOUT) :: Frame
local motesLayer = canvas:WaitForChild("Motes", CHILD_TIMEOUT) :: Frame
local brand = canvas:WaitForChild("Brand", CHILD_TIMEOUT) :: Frame
local infoSection = canvas:WaitForChild("Info", CHILD_TIMEOUT) :: Frame
local regionText = infoSection:WaitForChild("Region", CHILD_TIMEOUT) :: TextLabel
local infoDivider = infoSection:WaitForChild("Divider", CHILD_TIMEOUT) :: Frame
local playerCountText = infoSection:WaitForChild("Players", CHILD_TIMEOUT) :: TextLabel
local nameBlock = canvas:WaitForChild("NameBlock", CHILD_TIMEOUT) :: Frame
local baseNameText = nameBlock:WaitForChild("BaseName", CHILD_TIMEOUT) :: TextLabel
local quoteText = nameBlock:WaitForChild("Quote", CHILD_TIMEOUT) :: TextLabel
local playerRow = nameBlock:WaitForChild("PlayerRow", CHILD_TIMEOUT) :: Frame
local playerNameText = playerRow:WaitForChild("PlayerName", CHILD_TIMEOUT) :: TextLabel
local playerRankText = playerRow:WaitForChild("Rank", CHILD_TIMEOUT) :: TextLabel
local loadingBar = canvas:WaitForChild("LoadingBar", CHILD_TIMEOUT) :: Frame
local percentText = loadingBar:WaitForChild("Percent", CHILD_TIMEOUT) :: TextLabel
local progressTrack = loadingBar:WaitForChild("Track", CHILD_TIMEOUT) :: Frame
local progressBar = progressTrack:WaitForChild("Fill", CHILD_TIMEOUT) :: Frame
local buttonContainer = canvas:WaitForChild("Buttons", CHILD_TIMEOUT) :: Frame
local creditsButton = buttonContainer:WaitForChild("CreditsButton", CHILD_TIMEOUT) :: TextButton
local deployButton = buttonContainer:WaitForChild("DeployButton", CHILD_TIMEOUT) :: TextButton
local creditsOverlay = canvas:WaitForChild("CreditsOverlay", CHILD_TIMEOUT) :: Frame
local creditsTitle = creditsOverlay:WaitForChild("Title", CHILD_TIMEOUT) :: TextLabel
local roster = creditsOverlay:WaitForChild("Roster", CHILD_TIMEOUT) :: Frame
local rosterScale = roster:WaitForChild("RosterScale", CHILD_TIMEOUT) :: UIScale
local blackout = canvas:WaitForChild("Blackout", CHILD_TIMEOUT) :: Frame

type MoteDot = {
	frame: Frame,
	opacity: number,
}

type Mote = {
	holder: Frame,
	x: number,
	duration: number,
	offset: number,
	sway: number,
	twinkle: number,
	dots: { MoteDot },
}

local AMBIENT_SOUND_ID = "rbxassetid://134415181415399"
local AMBIENT_VOLUME = 0.3
local AMBIENT_FADE_TIME = 1.5
local GRADE_ATTRIBUTE = "LoadingGrade"
local HANDLER_ATTRIBUTE = "LoadingHandlerId"

local SERVER_PROGRESS_MAX = 0.9
local DESIGN_WIDTH = 1920
local DESIGN_HEIGHT = 1080
local MIN_SCALE = 0.6
local EDGE_MARGIN = 64
local TOPBAR_GAP = 16
local BASE_NAME_GAP = 32
local MIN_BASE_NAME_SIZE = 24
local QUOTE_INTERVAL = 4
local IMAGE_SHOT_TIME = 10
local IMAGE_SHOT_FADE = 2
local CAMERA_SHOT_TIME = 5
local CAMERA_FADE_TIME = 0.8
local STREAM_TIMEOUT = 3
local CARD_LIFT = 6
local ROSTER_SLIDE = 12
local SHAFT_BRIGHT_TRANSPARENCY = 0.25
local MOTE_START = 20
local MOTE_RISE = 760
local MOTE_DRIFT = 80
local MOTE_SWAY = 18
local MOTE_FADE_IN = 0.12
local MOTE_FADE_OUT = 0.85

local HOVER_COLOR = Color3.fromRGB(40, 40, 40)
local PRESSED_COLOR = Color3.fromRGB(46, 46, 46)
local PRESSED_TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local PRESSED_STROKE_COLOR = Color3.fromRGB(140, 140, 145)
local HOVER_STROKE_COLOR = Color3.fromRGB(240, 240, 240)

local IMAGE_MOVES = {
	{ Vector3.new(0, 0, 1.03), Vector3.new(-24, -10, 1.07) },
	{ Vector3.new(26, 0, 1.05), Vector3.new(-26, 0, 1.05) },
	{ Vector3.new(-12, 6, 1.04), Vector3.new(14, -6, 1.08) },
	{ Vector3.new(30, 0, 1.06), Vector3.new(-30, -6, 1.06) },
}

local CAMERA_MOVES = {
	{ CFrame.new(-1.5, 0, 0), CFrame.new(1.5, 0.4, -1.5) },
	{ CFrame.new(1.5, 0, 0), CFrame.new(-1.5, 0, 0) },
	{ CFrame.new(0, 0.5, 1), CFrame.new(0, -0.3, -1.5) },
	{ CFrame.new(2, 0, 0), CFrame.new(-2, -0.4, 0) },
}

local COLOR_GRADE = {
	Brightness = 0.02,
	Contrast = 0.15,
	Saturation = 0.08,
	TintColor = Color3.fromRGB(236, 241, 255),
}

local BLOOM_GRADE = {
	Intensity = 0.8,
	Size = 32,
	Threshold = 1.2,
}

local FOCUS_GRADE = {
	FarIntensity = 0.3,
	FocusDistance = 40,
	InFocusRadius = 35,
	NearIntensity = 0.4,
}

local ATMOSPHERE_GRADE = {
	Density = 0.28,
	Offset = 0.1,
	Color = Color3.fromRGB(185, 192, 205),
	Decay = Color3.fromRGB(60, 66, 80),
	Glare = 0,
	Haze = 1,
}

local FADE_PROPERTIES: { [string]: { string } } = {
	TextLabel = { "TextTransparency", "BackgroundTransparency" },
	TextButton = { "TextTransparency", "BackgroundTransparency" },
	Frame = { "BackgroundTransparency" },
	ImageLabel = { "ImageTransparency", "BackgroundTransparency" },
	UIStroke = { "Transparency" },
}

local AMBIENT_FADE_TWEEN_INFO = TweenInfo.new(AMBIENT_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PROGRESS_BAR_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local FADE_TO_BLACK_TWEEN_INFO = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BUTTON_HOVER_TWEEN_INFO = TweenInfo.new(0.15)
local QUOTE_FADE_TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PHASE_OUT_TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PHASE_IN_TWEEN_INFO = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CREDITS_IN_TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CREDITS_OUT_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ROSTER_SLIDE_TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local IMAGE_FADE_TWEEN_INFO = TweenInfo.new(IMAGE_SHOT_FADE, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local IMAGE_MOVE_TWEEN_INFO = TweenInfo.new(IMAGE_SHOT_TIME + IMAGE_SHOT_FADE, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local CAMERA_FADE_TWEEN_INFO = TweenInfo.new(CAMERA_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CAMERA_MOVE_TWEEN_INFO = TweenInfo.new(CAMERA_SHOT_TIME + CAMERA_FADE_TIME * 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local SHAFT_TWEEN_INFO = TweenInfo.new(7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local HAZE_TWEEN_INFO = TweenInfo.new(80, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)

local brandTop = brand.Position.Y.Offset
local infoOffset = infoSection.Position.Y.Offset - brandTop
local baseNameSize = baseNameText.TextSize
local barWidth = loadingBar.Size.X.Offset
local rosterWidth = roster.Size.X.Offset
local rosterHeight = roster.Size.Y.Offset
local rosterRestPosition = roster.Position
local rosterBottom = -rosterRestPosition.Y.Offset
local creditsTitleGap = -creditsTitle.Position.Y.Offset - rosterBottom - rosterHeight

local ambientSound: Sound? = nil
local quoteCycleRunning = false
local imageShotsRunning = false
local cameraShotsRunning = false
local cameraTween: Tween? = nil
local cameraTypeConnection: RBXScriptConnection? = nil
local restoreAtmosphere: (() -> ())? = nil
local creditsVisible = false
local hasDeployed = false
local retired = false
local handlerId = HttpService:GenerateGUID(false)
local displayedProgress = 0
local gradeEffects: { Instance } = {}
local quoteOrder: { number } = {}
local buttonRestColors: { [TextButton]: Color3 } = {}
local connections: { RBXScriptConnection } = {}
local motes: { Mote } = {}
local motionStart = os.clock()

local creditsRestColor = creditsButton.BackgroundColor3
local creditsTextColor = creditsButton.TextColor3
local creditsStroke = creditsButton:FindFirstChildOfClass("UIStroke")
local creditsStrokeColor = if creditsStroke then creditsStroke.Color else PRESSED_STROKE_COLOR

local function getCamera(): Camera?
	return workspace.CurrentCamera
end

local function tween(instance: Instance, tweenInfo: TweenInfo, goals: { [string]: any }): Tween
	local created = TweenService:Create(instance, tweenInfo, goals)
	created:Play()
	return created
end

local function fadeGroup(root: Instance, visible: boolean, tweenInfo: TweenInfo?): ()
	local instances = root:GetDescendants()
	table.insert(instances, root)

	for _, instance in instances do
		local properties = FADE_PROPERTIES[instance.ClassName]
		if not properties then
			continue
		end

		local target: any = instance
		local goals = {}
		for _, property in properties do
			local base = instance:GetAttribute(property)
			if base == nil then
				base = target[property]
				instance:SetAttribute(property, base)
			end
			goals[property] = if visible then base else 1
		end

		if tweenInfo then
			tween(instance, tweenInfo, goals)
		else
			for property, value in goals do
				target[property] = value
			end
		end
	end
end

local function startAmbientSound(): ()
	if ambientSound then
		return
	end

	local existing = SoundService:FindFirstChild("LoadingAmbient")
	if existing and existing:IsA("Sound") then
		existing.Volume = AMBIENT_VOLUME
		if not existing.IsPlaying then
			existing:Play()
		end
		ambientSound = existing
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "LoadingAmbient"
	sound.SoundId = AMBIENT_SOUND_ID
	sound.Volume = AMBIENT_VOLUME
	sound.Looped = true
	sound.Parent = SoundService
	sound:Play()
	ambientSound = sound
end

local function fadeOutAmbientSound(): ()
	local sound = ambientSound
	ambientSound = nil

	if not sound then
		local orphaned = SoundService:FindFirstChild("LoadingAmbient") :: Sound?
		if orphaned then
			orphaned:Stop()
			orphaned:Destroy()
		end
		return
	end

	local fade = TweenService:Create(sound, AMBIENT_FADE_TWEEN_INFO, { Volume = 0 })
	fade.Completed:Once(function()
		sound:Stop()
		sound:Destroy()
	end)
	fade:Play()
end

local function getPlrRank(): string
	local success, plrRanks = pcall(function()
		return GroupService:GetRolesInGroupAsync(player.UserId, VULT_GROUP)
	end)

	if not success then
		warn("Failed to retrieve player roles:", plrRanks)
		return "OUTSIDER"
	end

	if not plrRanks.IsMember or #plrRanks.Roles == 0 then
		return "OUTSIDER"
	end

	local highestRole = plrRanks.Roles[1]

	for _, role in ipairs(plrRanks.Roles) do
		if role.Rank > highestRole.Rank then
			highestRole = role
		end
	end

	return string.upper(highestRole.Name)
end

local function resolveBaseName(): ()
	if baseNameText.Text ~= "" then
		return
	end

	local success, productInfo = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, game.PlaceId)
	if success and productInfo and productInfo.Name then
		baseNameText.Text = string.upper(productInfo.Name)
	end
end

local function rescale(): ()
	local screenSize = loadingScreen.AbsoluteSize
	if screenSize.X <= 0 or screenSize.Y <= 0 then
		return
	end

	local scale = math.max(MIN_SCALE, math.min(screenSize.X / DESIGN_WIDTH, screenSize.Y / DESIGN_HEIGHT))
	local canvasWidth = screenSize.X / scale
	uiScale.Scale = scale
	canvas.Size = UDim2.fromScale(1 / scale, 1 / scale)

	local top = math.max(brandTop, GuiService:GetGuiInset().Y / scale + TOPBAR_GAP)
	brand.Position = UDim2.fromOffset(brand.Position.X.Offset, top)
	infoSection.Position = UDim2.new(1, infoSection.Position.X.Offset, 0, top + infoOffset)

	local nameWidth = TextService:GetTextSize(baseNameText.Text, baseNameSize, baseNameText.Font, Vector2.new(10000, 1000)).X
	if nameWidth > 0 then
		local nameRoom = canvasWidth - EDGE_MARGIN * 2 - barWidth - BASE_NAME_GAP
		baseNameText.TextSize = math.clamp((baseNameSize * nameRoom) // nameWidth, MIN_BASE_NAME_SIZE, baseNameSize)
	end

	local rosterFit = math.min(1, (canvasWidth - EDGE_MARGIN * 2) / rosterWidth)
	rosterScale.Scale = rosterFit
	creditsTitle.Position = UDim2.new(0, creditsTitle.Position.X.Offset, 1, -(rosterBottom + rosterHeight * rosterFit + creditsTitleGap))
end

local function updateRegion(): ()
	local region = ReplicatedStorage:GetAttribute("ServerRegion")
	local hasRegion = typeof(region) == "string" and region ~= ""
	regionText.Text = if hasRegion then string.upper(region) else ""
	regionText.Visible = hasRegion
	infoDivider.Visible = hasRegion
end

local function updatePlayerCount(leaving: number): ()
	local count = #Players:GetPlayers() - leaving
	playerCountText.Text = if count == 1 then "1 PLAYER" else `{count} PLAYERS`
end

local function shuffleQuotes(): ()
	if not Credits then
		return
	end

	for index = 1, #Credits.Quotes do
		table.insert(quoteOrder, index)
	end

	local random = Random.new()
	for index = #quoteOrder, 2, -1 do
		local swapIndex = random:NextInteger(1, index)
		quoteOrder[index], quoteOrder[swapIndex] = quoteOrder[swapIndex], quoteOrder[index]
	end
end

local function formatQuote(position: number): string
	local quote = Credits.Quotes[quoteOrder[(position - 1) % #quoteOrder + 1]]
	return `“{quote.text}”  <font color="#787878">- {quote.author}</font>`
end

local function startQuoteCycle(): ()
	if quoteCycleRunning or #quoteOrder == 0 then
		return
	end
	quoteCycleRunning = true
	quoteText.Text = formatQuote(1)
	quoteText.TextTransparency = 0

	task.spawn(function()
		local position = 1
		while quoteCycleRunning do
			task.wait(QUOTE_INTERVAL)
			if not quoteCycleRunning then
				break
			end

			tween(quoteText, QUOTE_FADE_TWEEN_INFO, { TextTransparency = 1 }).Completed:Wait()
			if not quoteCycleRunning then
				break
			end

			position += 1
			quoteText.Text = formatQuote(position)
			tween(quoteText, QUOTE_FADE_TWEEN_INFO, { TextTransparency = 0 })
		end
	end)
end

local function stopQuoteCycle(): ()
	quoteCycleRunning = false
end

local function collectMotes(): ()
	for _, holder in motesLayer:GetChildren() do
		if not holder:IsA("Frame") then
			continue
		end

		local dots: { MoteDot } = {}
		for _, dot in holder:GetChildren() do
			if dot:IsA("Frame") then
				table.insert(dots, { frame = dot, opacity = 1 - (dot:GetAttribute("BaseTransparency") or 1) })
			end
		end

		table.insert(motes, {
			holder = holder,
			x = holder:GetAttribute("X") or 0,
			duration = holder:GetAttribute("Duration") or 1,
			offset = holder:GetAttribute("Offset") or 0,
			sway = holder:GetAttribute("Sway") or 1,
			twinkle = holder:GetAttribute("Twinkle") or 1,
			dots = dots,
		})
	end
end

local function getTwinkle(phase: number): number
	if phase < 0.45 then
		return 1 - 0.65 * (phase / 0.45)
	elseif phase < 0.55 then
		return 0.35 + 0.65 * ((phase - 0.45) / 0.1)
	elseif phase < 0.75 then
		return 1 - 0.4 * ((phase - 0.55) / 0.2)
	end
	return 0.6 + 0.4 * ((phase - 0.75) / 0.25)
end

local function updateMotes(): ()
	local now = os.clock() - motionStart
	for _, mote in motes do
		local elapsed = now + mote.offset
		local rise = (elapsed % mote.duration) / mote.duration
		local envelope = if rise < MOTE_FADE_IN then rise / MOTE_FADE_IN elseif rise > MOTE_FADE_OUT then (1 - rise) / (1 - MOTE_FADE_OUT) else 1
		local opacity = envelope * getTwinkle((elapsed % mote.twinkle) / mote.twinkle)
		local sway = -MOTE_SWAY * math.cos(2 * math.pi * now / mote.sway)

		mote.holder.Position = UDim2.new(mote.x, sway - MOTE_DRIFT * rise, 1, -MOTE_START - MOTE_RISE * rise)
		for _, dot in mote.dots do
			dot.frame.BackgroundTransparency = 1 - dot.opacity * opacity
		end
	end
end

local function startBackgroundMotion(): ()
	collectMotes()
	tween(shafts, SHAFT_TWEEN_INFO, {
		GroupTransparency = SHAFT_BRIGHT_TRANSPARENCY,
		Position = UDim2.fromOffset(-shafts.Position.X.Offset, 0),
	})
	tween(hazeStrip, HAZE_TWEEN_INFO, { Position = UDim2.fromScale(-1, 0) })
	table.insert(connections, RunService.Heartbeat:Connect(updateMotes))
end

local function getShotImages(): { ImageLabel }
	local images: { ImageLabel } = {}
	for _, child in shotsFrame:GetChildren() do
		if child:IsA("ImageLabel") then
			table.insert(images, child)
		end
	end
	table.sort(images, function(a, b)
		return a.Name < b.Name
	end)
	return images
end

local function runImageShots(): ()
	local images = getShotImages()
	if #images == 0 then
		return
	end

	imageShotsRunning = true
	local index = 0
	local previous: ImageLabel? = nil

	while imageShotsRunning do
		index += 1
		local image = images[(index - 1) % #images + 1]
		local move = IMAGE_MOVES[(index - 1) % #IMAGE_MOVES + 1]

		image.ZIndex = index
		image.Position = UDim2.new(0.5, move[1].X, 0.5, move[1].Y)
		image.Size = UDim2.fromScale(move[1].Z, move[1].Z)

		local last = previous
		if last then
			image.ImageTransparency = 1
			tween(image, IMAGE_FADE_TWEEN_INFO, { ImageTransparency = 0 })
			task.delay(IMAGE_SHOT_FADE, function()
				if last ~= image then
					last.ImageTransparency = 1
				end
			end)
		else
			image.ImageTransparency = 0
		end

		tween(image, IMAGE_MOVE_TWEEN_INFO, {
			Position = UDim2.new(0.5, move[2].X, 0.5, move[2].Y),
			Size = UDim2.fromScale(move[2].Z, move[2].Z),
		})

		previous = image
		task.wait(IMAGE_SHOT_TIME)
	end
end

local function readCameraShots(): { CFrame }
	local shots: { CFrame } = {}
	local count = loadingScreen:GetAttribute("ShotCount")
	if typeof(count) ~= "number" then
		return shots
	end

	for index = 1, count do
		local cframe = loadingScreen:GetAttribute(`Shot{index}`)
		if typeof(cframe) == "CFrame" then
			table.insert(shots, cframe)
		end
	end
	return shots
end

local function streamAround(position: Vector3): ()
	pcall(player.RequestStreamAroundAsync, player, position, STREAM_TIMEOUT)
end

local function createEffect(className: string, properties: { [string]: any }, parent: Instance): Instance
	local effect: any = Instance.new(className)
	for property, value in properties do
		effect[property] = value
	end
	effect.Name = `Loading{className}`
	effect:SetAttribute(GRADE_ATTRIBUTE, true)
	effect.Parent = parent
	return effect
end

local function applyAtmosphereGrade(): ()
	local existing = Lighting:FindFirstChildOfClass("Atmosphere")
	if not existing or existing:GetAttribute(GRADE_ATTRIBUTE) then
		local atmosphere = existing or createEffect("Atmosphere", ATMOSPHERE_GRADE, Lighting)
		restoreAtmosphere = function()
			atmosphere:Destroy()
		end
		return
	end

	local atmosphere: any = existing
	for property, value in ATMOSPHERE_GRADE do
		local originalKey = `Original{property}`
		if atmosphere:GetAttribute(originalKey) == nil then
			atmosphere:SetAttribute(originalKey, atmosphere[property])
		end
		atmosphere[property] = value
	end

	restoreAtmosphere = function()
		for property in ATMOSPHERE_GRADE do
			local originalKey = `Original{property}`
			local original = atmosphere:GetAttribute(originalKey)
			if original ~= nil then
				atmosphere[property] = original
				atmosphere:SetAttribute(originalKey, nil)
			end
		end
	end
end

local function applyGrade(camera: Camera): ()
	for _, child in camera:GetChildren() do
		if child:GetAttribute(GRADE_ATTRIBUTE) then
			child:Destroy()
		end
	end

	table.insert(gradeEffects, createEffect("ColorCorrectionEffect", COLOR_GRADE, camera))
	table.insert(gradeEffects, createEffect("BloomEffect", BLOOM_GRADE, camera))
	table.insert(gradeEffects, createEffect("DepthOfFieldEffect", FOCUS_GRADE, camera))
	applyAtmosphereGrade()
end

local function removeGrade(): ()
	for _, effect in gradeEffects do
		effect:Destroy()
	end
	table.clear(gradeEffects)

	if restoreAtmosphere then
		restoreAtmosphere()
		restoreAtmosphere = nil
	end
end

local function runCameraShots(shots: { CFrame }): ()
	local index = 0
	while cameraShotsRunning do
		local camera = getCamera()
		if not camera then
			task.wait()
			continue
		end

		index += 1
		local shot = shots[(index - 1) % #shots + 1]
		local move = CAMERA_MOVES[(index - 1) % #CAMERA_MOVES + 1]
		task.spawn(streamAround, shots[index % #shots + 1].Position)

		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = shot * move[1]
		cameraTween = tween(camera, CAMERA_MOVE_TWEEN_INFO, { CFrame = shot * move[2] })
		tween(shotFade, CAMERA_FADE_TWEEN_INFO, { BackgroundTransparency = 1 })

		task.wait(CAMERA_SHOT_TIME)
		if not cameraShotsRunning then
			break
		end

		tween(shotFade, CAMERA_FADE_TWEEN_INFO, { BackgroundTransparency = 0 })
		task.wait(CAMERA_FADE_TIME)
	end
end

local function startCameraShots(shots: { CFrame }): ()
	local camera = getCamera()
	while not camera do
		task.wait()
		camera = getCamera()
	end

	shotFade.BackgroundTransparency = 0
	canvas.BackgroundTransparency = 1
	streamAround(shots[1].Position)
	if hasDeployed or retired or not loadingScreen.Parent then
		return
	end

	applyGrade(camera)
	cameraShotsRunning = true
	cameraTypeConnection = camera:GetPropertyChangedSignal("CameraType"):Connect(function()
		if cameraShotsRunning and camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
	end)
	runCameraShots(shots)
end

local function startShots(): ()
	local shots = readCameraShots()
	if #shots > 0 then
		startCameraShots(shots)
	else
		runImageShots()
	end
end

local function stopShots(): ()
	imageShotsRunning = false
	cameraShotsRunning = false

	if cameraTypeConnection then
		cameraTypeConnection:Disconnect()
		cameraTypeConnection = nil
	end

	if cameraTween then
		cameraTween:Cancel()
		cameraTween = nil
	end

	removeGrade()
end

local function updateProgress(progress: number): ()
	local displayed = progress * SERVER_PROGRESS_MAX
	if displayed <= displayedProgress then
		return
	end
	displayedProgress = displayed
	tween(progressBar, PROGRESS_BAR_TWEEN_INFO, { Size = UDim2.fromScale(displayed, 1) })
	percentText.Text = `{math.round(displayed * 100)}%`
end

local function bindButtonHover(button: TextButton): ()
	buttonRestColors[button] = button.BackgroundColor3

	table.insert(
		connections,
		button.MouseEnter:Connect(function()
			tween(button, BUTTON_HOVER_TWEEN_INFO, { BackgroundColor3 = HOVER_COLOR })
		end)
	)

	table.insert(
		connections,
		button.MouseLeave:Connect(function()
			tween(button, BUTTON_HOVER_TWEEN_INFO, { BackgroundColor3 = buttonRestColors[button] })
		end)
	)
end

local function bindCardHover(holder: Frame, card: Frame): ()
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if not stroke then
		return
	end
	local restColor = stroke.Color

	table.insert(
		connections,
		holder.MouseEnter:Connect(function()
			tween(card, BUTTON_HOVER_TWEEN_INFO, { Position = UDim2.fromOffset(0, -CARD_LIFT) })
			tween(stroke, BUTTON_HOVER_TWEEN_INFO, { Color = HOVER_STROKE_COLOR })
		end)
	)

	table.insert(
		connections,
		holder.MouseLeave:Connect(function()
			tween(card, BUTTON_HOVER_TWEEN_INFO, { Position = UDim2.new() })
			tween(stroke, BUTTON_HOVER_TWEEN_INFO, { Color = restColor })
		end)
	)
end

local function bindRosterHovers(): ()
	for _, descendant in roster:GetDescendants() do
		local holder = descendant.Parent
		if descendant.Name == "Card" and descendant:IsA("Frame") and holder and holder:IsA("Frame") then
			bindCardHover(holder, descendant)
		end
	end
end

local function toggleCreditsPanel(show: boolean): ()
	if show == creditsVisible then
		return
	end
	creditsVisible = show

	buttonRestColors[creditsButton] = if show then PRESSED_COLOR else creditsRestColor
	tween(creditsButton, BUTTON_HOVER_TWEEN_INFO, {
		BackgroundColor3 = buttonRestColors[creditsButton],
		TextColor3 = if show then PRESSED_TEXT_COLOR else creditsTextColor,
	})
	if creditsStroke then
		tween(creditsStroke, BUTTON_HOVER_TWEEN_INFO, { Color = if show then PRESSED_STROKE_COLOR else creditsStrokeColor })
	end

	if show then
		creditsOverlay.Visible = true
		roster.Position = rosterRestPosition + UDim2.fromOffset(0, ROSTER_SLIDE)
		tween(roster, ROSTER_SLIDE_TWEEN_INFO, { Position = rosterRestPosition })
		fadeGroup(creditsOverlay, true, CREDITS_IN_TWEEN_INFO)
	else
		fadeGroup(creditsOverlay, false, CREDITS_OUT_TWEEN_INFO)
		task.delay(CREDITS_OUT_TWEEN_INFO.Time, function()
			if not creditsVisible then
				creditsOverlay.Visible = false
			end
		end)
	end
end

local function transitionToDeployPhase(): ()
	if retired or not loadingScreen.Parent then
		return
	end

	stopQuoteCycle()
	fadeGroup(loadingBar, false, PHASE_OUT_TWEEN_INFO)
	fadeGroup(quoteText, false, PHASE_OUT_TWEEN_INFO)
	task.wait(PHASE_OUT_TWEEN_INFO.Time)

	loadingBar.Visible = false
	buttonContainer.Visible = true
	playerRow.Visible = true
	fadeGroup(buttonContainer, true, PHASE_IN_TWEEN_INFO)
	fadeGroup(playerRow, true, PHASE_IN_TWEEN_INFO)
end

local function fadeToBlack(): ()
	tween(blackout, FADE_TO_BLACK_TWEEN_INFO, { BackgroundTransparency = 0 }).Completed:Wait()
end

local function resetCamera(): ()
	local camera = getCamera()
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

local function deploy(): ()
	if hasDeployed then
		return
	end
	hasDeployed = true
	deployButton.Active = false
	toggleCreditsPanel(false)
	fadeOutAmbientSound()
	fadeToBlack()
	stopShots()
	resetCamera()
	Network.Deploy.requestDeploy()
end

loadingBar.Visible = true
fadeGroup(loadingBar, true)
buttonContainer.Visible = false
playerRow.Visible = false
creditsOverlay.Visible = false
fadeGroup(buttonContainer, false)
fadeGroup(playerRow, false)
fadeGroup(creditsOverlay, false)
displayedProgress = progressBar.Size.X.Scale

playerNameText.Text = string.upper(player.Name)
bindButtonHover(creditsButton)
bindButtonHover(deployButton)
bindRosterHovers()

table.insert(
	connections,
	creditsButton.Activated:Connect(function()
		toggleCreditsPanel(not creditsVisible)
	end)
)
table.insert(connections, deployButton.Activated:Connect(deploy))

updateRegion()
updatePlayerCount(0)
table.insert(connections, ReplicatedStorage:GetAttributeChangedSignal("ServerRegion"):Connect(updateRegion))
table.insert(
	connections,
	Players.PlayerAdded:Connect(function()
		updatePlayerCount(0)
	end)
)
table.insert(
	connections,
	Players.PlayerRemoving:Connect(function()
		updatePlayerCount(1)
	end)
)

rescale()
table.insert(connections, loadingScreen:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale))
pcall(function()
	table.insert(connections, GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(rescale))
end)

task.spawn(function()
	resolveBaseName()
	rescale()
end)

task.spawn(function()
	playerRankText.Text = getPlrRank()
end)

local function disconnectAll(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function retire(): ()
	if retired then
		return
	end
	retired = true
	stopQuoteCycle()
	imageShotsRunning = false
	cameraShotsRunning = false

	if cameraTypeConnection then
		cameraTypeConnection:Disconnect()
		cameraTypeConnection = nil
	end

	if cameraTween then
		cameraTween:Cancel()
		cameraTween = nil
	end

	disconnectAll()
end

table.insert(
	connections,
	loadingScreen.Destroying:Once(function()
		stopQuoteCycle()
		stopShots()
		disconnectAll()
		fadeOutAmbientSound()
		local camera = getCamera()
		if camera then
			camera.CameraType = Enum.CameraType.Custom
		end
	end)
)

loadingScreen:SetAttribute(HANDLER_ATTRIBUTE, handlerId)
table.insert(
	connections,
	loadingScreen:GetAttributeChangedSignal(HANDLER_ATTRIBUTE):Connect(function()
		if loadingScreen:GetAttribute(HANDLER_ATTRIBUTE) ~= handlerId then
			retire()
		end
	end)
)

Network.Credits.onToggleCredits(function(show)
	toggleCreditsPanel(show)
end)

local function handleProgress(data: number | string): ()
	if typeof(data) == "number" then
		updateProgress(data)
	elseif data == "complete" then
		task.spawn(function()
			local deadline = os.clock() + 15
			while not MainModule:GetAttribute("ClientReady") do
				if os.clock() > deadline then
					break
				end
				task.wait(0.1)
			end

			tween(progressBar, PROGRESS_BAR_TWEEN_INFO, { Size = UDim2.fromScale(1, 1) })
			percentText.Text = "100%"
			task.wait(PHASE_OUT_TWEEN_INFO.Time)
			transitionToDeployPhase()
		end)
	end
end

progressHandler = handleProgress
for _, data in pendingProgress do
	handleProgress(data)
end
pendingProgress = {}

shuffleQuotes()
startQuoteCycle()
startAmbientSound()
startBackgroundMotion()
task.spawn(startShots)
