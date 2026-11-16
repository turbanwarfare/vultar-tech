--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

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

local spawnHighlightAddedConn: RBXScriptConnection? = nil
local spawnHighlightRemovedConn: RBXScriptConnection? = nil

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local Maps = require(MainModule.Shared.Config.Maps)
local AimChamberConfig = require(MainModule.Shared.Config.AimChamberConfig)
local Theme = require(MainModule.Shared.UI.Theme)

local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))

local AimChamberConfigUI: any = nil
local AimChamberTimerHUD: any = nil
local AimChamberAssessmentUI: any = nil
local AimChamberLeaderboardClient: any = nil
local AimChamberRecorder: any = nil
local AimChamberRecorderUI: any = nil
local MatchHistory: any = nil
local Icon: any = nil
local Iris: any = nil

type AimChamberSettings = AimChamberConfig.AimChamberSettings
type AimChamberValidationPayload = AimChamberConfig.AimChamberValidationPayload

local AimChamberService = {}
AimChamberService.Name = "AimChamberService"

local scope = Fusion.scoped(Fusion)

local configVisible = scope:Value(false)
local configSettings = scope:Value(AimChamberConfig.getDefaultSettings())
local configPresetId = scope:Value(AimChamberConfig.DEFAULT_PRESET)
local configLocked = scope:Value(false)
local configFeedbackMessage = scope:Value("")
local configFeedbackIsError = scope:Value(false)

local historyVisible = scope:Value(false)
local historyData = scope:Value({})
local isLoadingHistory = scope:Value(false)
local historyWindow: ScreenGui? = nil

local topbarIcon: any = nil
local isUpdatingFromIcon = false
local isUpdatingFromModal = false

local recorderVisibleState = nil
local recorderIsRecording = false
local recorderChunks = {}
local recorderFrameCount = 0
local recorderIcon: any = nil
local isUpdatingRecorderFromIcon = false
local isUpdatingRecorderFromModal = false

local aimReportLoopActive = false

local playerKills = scope:Value(0)
local botKills = scope:Value(0)
local playerShotsFired = scope:Value(0)
local playerShotsHit = scope:Value(0)
local botShotsFired = scope:Value(0)
local botShotsHit = scope:Value(0)

local botScoreboardGui: BillboardGui? = nil
local scoreboardScope: any = nil

local FAST_IN_ALT = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
local BACK_OUT_ALT = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local EXPO_OUT_ALT = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local SLOW_OUT_ALT = TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local resultOverlayGui: ScreenGui? = nil

local function playResultSequence(didWin: boolean)
	local playerGui = LocalPlayer:WaitForChild("PlayerGui", 5)
	if not playerGui then
		return
	end

	if resultOverlayGui then
		resultOverlayGui:Destroy()
		resultOverlayGui = nil
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AimChamberResult"
	screenGui.AutoLocalize = false
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 260
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui
	resultOverlayGui = screenGui

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
	subtitleLabel.Text = if didWin then "Well played" else "Better luck next time"
	subtitleLabel.TextColor3 = Theme.Foreground.Muted
	subtitleLabel.TextTransparency = 1
	subtitleLabel.Font = Theme.Text.Bold
	subtitleLabel.TextScaled = true
	subtitleLabel.ZIndex = 10
	subtitleLabel.Parent = pillFrame

	uiScale.Scale = 0.2
	local intro1 = TweenService:Create(uiScale, BACK_OUT_ALT, { Scale = 1 })
	local intro2 = TweenService:Create(resultLabel, EXPO_OUT_ALT, { TextTransparency = 0 })
	local intro3 = TweenService:Create(pillStroke, EXPO_OUT_ALT, { Transparency = 0 })
	local intro4 = TweenService:Create(subtitleLabel, SLOW_OUT_ALT, { TextTransparency = 0.3 })

	intro1:Play()
	intro2:Play()
	intro3:Play()
	intro4:Play()

	task.wait(2.8)

	local t1 = TweenService:Create(uiScale, FAST_IN_ALT, { Scale = 1.15 })
	local t2 = TweenService:Create(resultLabel, FAST_IN_ALT, { TextTransparency = 1 })
	local t3 = TweenService:Create(subtitleLabel, FAST_IN_ALT, { TextTransparency = 1 })
	local t4 = TweenService:Create(pillStroke, FAST_IN_ALT, { Transparency = 1 })
	local t5 = TweenService:Create(pillFrame, FAST_IN_ALT, { BackgroundTransparency = 1 })

	t1:Play()
	t2:Play()
	t3:Play()
	t4:Play()
	t5:Play()

	t1.Completed:Wait()

	t1:Destroy()
	t2:Destroy()
	t3:Destroy()
	t4:Destroy()
	t5:Destroy()

	intro1:Destroy()
	intro2:Destroy()
	intro3:Destroy()
	intro4:Destroy()

	screenGui:Destroy()
	if resultOverlayGui == screenGui then
		resultOverlayGui = nil
	end
end

local function showMatchHistory()
	isLoadingHistory:set(true)
	historyVisible:set(true)
	task.spawn(function()
		local data = Network.AimChamber.requestMatchHistory()
		historyData:set(data or {})
		isLoadingHistory:set(false)
	end)
end

local function onIconSelected(): ()
	if isUpdatingFromModal then
		return
	end
	showMatchHistory()
end

local function onIconDeselected(): ()
	if isUpdatingFromModal then
		return
	end
	if Fusion.peek(historyVisible) then
		isUpdatingFromIcon = true
		historyVisible:set(false)
		isUpdatingFromIcon = false
	end
end

local function createBotScoreboardHUD(adorneePart: BasePart)
	if botScoreboardGui then
		botScoreboardGui:Destroy()
		botScoreboardGui = nil
	end
	if scoreboardScope then
		Fusion.doCleanup(scoreboardScope)
	end
	scoreboardScope = Fusion.scoped(Fusion)

	local playerAccuracy = scoreboardScope:Computed(function(use)
		local fired = use(playerShotsFired)
		local hit = use(playerShotsHit)
		if fired <= 0 then
			return "0%"
		end
		return string.format("%.2f%%", (hit / fired) * 100)
	end)

	local botAccuracy = scoreboardScope:Computed(function(use)
		local fired = use(botShotsFired)
		local hit = use(botShotsHit)
		if fired <= 0 then
			return "0%"
		end
		return string.format("%.2f%%", (hit / fired) * 100)
	end)

	local uiCorner = scoreboardScope:New("UICorner")({ CornerRadius = Theme.Radius.Medium })
	local uiStroke = scoreboardScope:New("UIStroke")({
		Color = Color3.fromRGB(75, 73, 75),
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	local billboard = scoreboardScope:New("BillboardGui")({
		Name = "BotScoreboardHUD",
		Size = UDim2.fromOffset(350, 100),
		Adornee = adorneePart,
		Active = true,
		AlwaysOnTop = true,
		MaxDistance = 250,
		LightInfluence = 0,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = adorneePart,
		[Fusion.Children] = {
			scoreboardScope:New("Frame")({
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Colors.Black[850],
				BackgroundTransparency = 0.15,
				[Fusion.Children] = {
					uiCorner,
					uiStroke,
					scoreboardScope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 16),
						PaddingRight = UDim.new(0, 16),
						PaddingTop = UDim.new(0, 12),
						PaddingBottom = UDim.new(0, 12),
					}),
					scoreboardScope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),

					scoreboardScope:New("Frame")({
						Size = UDim2.new(1, 0, 0, 16),
						BackgroundTransparency = 1,
						LayoutOrder = 1,
						[Fusion.Children] = {
							scoreboardScope:New("TextLabel")({
								Size = UDim2.fromScale(0.4, 1),
								BackgroundTransparency = 1,
								Text = "NAME",
								Font = Theme.Text.Bold,
								TextSize = 11,
								TextColor3 = Theme.Foreground.Secondary,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							scoreboardScope:New("TextLabel")({
								Size = UDim2.fromScale(0.3, 1),
								Position = UDim2.fromScale(0.4, 0),
								BackgroundTransparency = 1,
								Text = "HIT ACCURACY",
								Font = Theme.Text.Bold,
								TextSize = 11,
								TextColor3 = Theme.Foreground.Secondary,
								TextXAlignment = Enum.TextXAlignment.Center,
							}),
							scoreboardScope:New("TextLabel")({
								Size = UDim2.fromScale(0.3, 1),
								Position = UDim2.fromScale(0.7, 0),
								BackgroundTransparency = 1,
								Text = "KILLS",
								Font = Theme.Text.Bold,
								TextSize = 11,
								TextColor3 = Theme.Foreground.Secondary,
								TextXAlignment = Enum.TextXAlignment.Right,
							}),
						},
					}),

					scoreboardScope:New("Frame")({
						Size = UDim2.new(1, 0, 0, 20),
						BackgroundTransparency = 1,
						LayoutOrder = 2,
						[Fusion.Children] = {
							scoreboardScope:New("TextLabel")({
								Size = UDim2.fromScale(0.4, 1),
								BackgroundTransparency = 1,
								Text = "Training Bot",
								Font = Theme.Text.Bold,
								TextSize = 13,
								TextColor3 = Color3.fromRGB(220, 100, 100),
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							scoreboardScope:New("TextLabel")({
								Size = UDim2.fromScale(0.3, 1),
								Position = UDim2.fromScale(0.4, 0),
								BackgroundTransparency = 1,
								Text = botAccuracy,
								Font = Theme.Text.Bold,
								TextSize = 13,
								TextColor3 = Color3.fromRGB(220, 100, 100),
								TextXAlignment = Enum.TextXAlignment.Center,
							}),
							scoreboardScope:New("TextLabel")({
								Size = UDim2.fromScale(0.3, 1),
								Position = UDim2.fromScale(0.7, 0),
								BackgroundTransparency = 1,
								Text = scoreboardScope:Computed(function(use)
									return tostring(use(botKills))
								end),
								Font = Theme.Text.Bold,
								TextSize = 13,
								TextColor3 = Color3.fromRGB(220, 100, 100),
								TextXAlignment = Enum.TextXAlignment.Right,
							}),
						},
					}),

					scoreboardScope:New("Frame")({
						Size = UDim2.new(1, 0, 0, 20),
						BackgroundTransparency = 1,
						LayoutOrder = 3,
						[Fusion.Children] = {
							scoreboardScope:New("TextLabel")({
								Size = UDim2.fromScale(0.4, 1),
								BackgroundTransparency = 1,
								Text = LocalPlayer.Name,
								Font = Theme.Text.Bold,
								TextSize = 13,
								TextColor3 = Color3.fromRGB(100, 200, 220),
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							scoreboardScope:New("TextLabel")({
								Size = UDim2.fromScale(0.3, 1),
								Position = UDim2.fromScale(0.4, 0),
								BackgroundTransparency = 1,
								Text = playerAccuracy,
								Font = Theme.Text.Bold,
								TextSize = 13,
								TextColor3 = Color3.fromRGB(100, 200, 220),
								TextXAlignment = Enum.TextXAlignment.Center,
							}),
							scoreboardScope:New("TextLabel")({
								Size = UDim2.fromScale(0.3, 1),
								Position = UDim2.fromScale(0.7, 0),
								BackgroundTransparency = 1,
								Text = scoreboardScope:Computed(function(use)
									return tostring(use(playerKills))
								end),
								Font = Theme.Text.Bold,
								TextSize = 13,
								TextColor3 = Color3.fromRGB(100, 200, 220),
								TextXAlignment = Enum.TextXAlignment.Right,
							}),
						},
					}),
				},
			}),
		},
	})

	botScoreboardGui = billboard
end

local isAiModeComputed = scope:Computed(function(use)
	local pid = use(configPresetId)
	if pid == "AI" then
		return true
	elseif pid == "CUSTOM" then
		local set = use(configSettings)
		return set and set.IsAiMode == true
	end
	return false
end)

local timerVisible = scope:Value(true)
local timerElapsedTime = scope:Value(0)
local timerSpawnRate = scope:Value(0)
local matchSettings: AimChamberSettings? = nil

local assessmentVisible = scope:Value(false)
local assessmentPayload = scope:Value(nil :: AimChamberValidationPayload?)

local configWindow: ScreenGui? = nil
local timerHUD: ScreenGui? = nil
local assessmentWindow: ScreenGui? = nil

function AimChamberService:init()
	if not Maps.isAimMode() then
		return
	end

	AimChamberConfigUI = require(script.AimChamberConfigUI)
	AimChamberTimerHUD = require(script.AimChamberTimerHUD)
	AimChamberAssessmentUI = require(script.AimChamberAssessmentUI)
	AimChamberLeaderboardClient = require(script.AimChamberLeaderboardClient)
	AimChamberRecorder = require(script.AimChamberRecorder)
	AimChamberRecorderUI = require(script.AimChamberRecorderUI)
	MatchHistory = require(MainModule.Client.Components.MatchHistory)
	Icon = require(Packages:WaitForChild("TopbarPlus", 5))
	Iris = require(Packages:WaitForChild("iris", 5))

	local DeathScreenService = require(MainModule.Client.Services.DeathScreenService)
	DeathScreenService:Suspend()
	DeathScreenService:Hide()

	Network.AimChamber.onConfigStateSync(function(state: any)
		pcall(function()
			print("[AimChamber Client] onConfigStateSync received settings:", HttpService:JSONEncode(state.Settings), "preset:", state.ActivePreset)
		end)
		configPresetId:set(state.ActivePreset)
		configSettings:set(state.Settings)
		configLocked:set(state.Locked)
		if not Fusion.peek(configVisible) then
			configFeedbackMessage:set("")
			configFeedbackIsError:set(false)
		end
		configVisible:set(true)
	end)

	Network.AimChamber.onApplyConfigResult(function(result: any)
		pcall(function()
			print("[AimChamber Client] onApplyConfigResult received:", HttpService:JSONEncode(result))
		end)
		configFeedbackMessage:set(result.Success and "Settings Applied Successfully!" or result.Error)
		configFeedbackIsError:set(not result.Success)
		if result.Success then
			task.delay(4, function()
				if Fusion.peek(configFeedbackMessage) == "Settings Applied Successfully!" then
					configFeedbackMessage:set("")
				end
			end)
		end
	end)

	Network.AimChamber.onMatchStarted(function(payload: any)
		configVisible:set(false)
		assessmentVisible:set(false)
		historyVisible:set(false)

		if payload.PresetId then
			configPresetId:set(payload.PresetId)
		end
		if payload.Settings then
			configSettings:set(payload.Settings)
		end

		matchSettings = payload.Settings
		timerElapsedTime:set(0)

		playerKills:set(0)
		botKills:set(0)
		playerShotsFired:set(0)
		playerShotsHit:set(0)
		botShotsFired:set(0)
		botShotsHit:set(0)

		local isAiMode = (payload.PresetId == "AI") or (payload.Settings and payload.Settings.IsAiMode == true)
		if isAiMode then
			aimReportLoopActive = true
			task.spawn(function()
				local player = game.Players.LocalPlayer
				local mouse = player:GetMouse()
				while aimReportLoopActive do
					local ray = mouse.UnitRay
					Network.AimChamber.sendAimReport(ray.Origin, ray.Direction)
					task.wait(0.1)
				end
			end)

			local interactableParts = workspace:FindFirstChild("InteractableParts")
			local botScreenPart = interactableParts and interactableParts:FindFirstChild("BotScreenPart")
			if botScreenPart then
				createBotScoreboardHUD(botScreenPart)
			else
				task.spawn(function()
					local folder = workspace:WaitForChild("InteractableParts", 30)
					local part = folder and folder:WaitForChild("BotScreenPart", 30)
					if part then
						createBotScoreboardHUD(part)
					end
				end)
			end
		end

		local initRate = payload.Settings.ZombieSpawnRate
		if payload.Settings.SpawnRateRampEnabled then
			initRate = math.max(payload.Settings.SpawnRateRampStartRate, 0.1)
		end
		timerSpawnRate:set(initRate)
		timerVisible:set(true)

		local InventoryService = require(MainModule.Client.Services.InventoryService)
		InventoryService:SetHasDeployed(true)
	end)

	Network.AimChamber.onMatchTick(function(tick: any)
		local elapsed = tick.ElapsedTime
		timerElapsedTime:set(elapsed)

		if tick.PlayerKills then
			playerKills:set(tick.PlayerKills)
		end
		if tick.BotKills then
			botKills:set(tick.BotKills)
		end
		if tick.PlayerShotsFired then
			playerShotsFired:set(tick.PlayerShotsFired)
		end
		if tick.PlayerShotsHit then
			playerShotsHit:set(tick.PlayerShotsHit)
		end
		if tick.BotShotsFired then
			botShotsFired:set(tick.BotShotsFired)
		end
		if tick.BotShotsHit then
			botShotsHit:set(tick.BotShotsHit)
		end

		local ms = matchSettings
		if ms then
			local currentRate: number
			if ms.SpawnRateRampEnabled then
				local t = math.clamp(elapsed / math.max(ms.SpawnRateRampDuration, 0.1), 0, 1)
				local startRate = math.max(ms.SpawnRateRampStartRate, 0.1)
				local endRate = math.max(ms.ZombieSpawnRate, 0.1)
				currentRate = startRate + (endRate - startRate) * t
			else
				currentRate = ms.ZombieSpawnRate
			end
			timerSpawnRate:set(currentRate)
		end
	end)

	Network.AimChamber.onMatchEnded(function(payload: any)
		aimReportLoopActive = false

		if payload.IsAiMode and payload.DidWin ~= nil then
			task.spawn(playResultSequence, payload.DidWin)
		end

		if botScoreboardGui then
			botScoreboardGui:Destroy()
			botScoreboardGui = nil
		end
		if scoreboardScope then
			Fusion.doCleanup(scoreboardScope)
			scoreboardScope = nil
		end

		if payload.ShowAssessmentUI and payload.Validation then
			assessmentPayload:set(payload.Validation)
			assessmentVisible:set(true)
		else
			assessmentPayload:set(nil)
			assessmentVisible:set(false)
		end
	end)

	spawnHighlightAddedConn = CollectionService:GetInstanceAddedSignal("SpawnHighlight"):Connect(function(instance)
		if instance:IsA("Highlight") then
			startHighlightTween(instance)
		end
	end)

	spawnHighlightRemovedConn = CollectionService:GetInstanceRemovedSignal("SpawnHighlight"):Connect(function(instance)
		if instance:IsA("Highlight") then
			stopHighlightTween(instance)
		end
	end)
end

function AimChamberService:start()
	if not Maps.isAimMode() then
		return
	end

	Network.AimChamber.init()

	configWindow = AimChamberConfigUI.createWindow({
		Visible = configVisible,
		Settings = configSettings,
		PresetId = configPresetId,
		Locked = configLocked,
		FeedbackMessage = configFeedbackMessage,
		FeedbackIsError = configFeedbackIsError,
		OnApply = function(settings: AimChamberSettings)
			pcall(function()
				print("[AimChamber Client] sendApplyConfig settings:", HttpService:JSONEncode(settings))
			end)
			configFeedbackMessage:set("Applying...")
			configFeedbackIsError:set(false)
			Network.AimChamber.sendApplyConfig(settings)
		end,
		OnClose = function()
			configVisible:set(false)
		end,
	})
	configWindow.Parent = LocalPlayer:WaitForChild("PlayerGui", 5)

	historyWindow = MatchHistory(scope, {
		Visible = historyVisible,
		OnClose = function()
			historyVisible:set(false)
		end,
		HistoryData = historyData,
		Loading = isLoadingHistory,
	})
	historyWindow.Parent = LocalPlayer:WaitForChild("PlayerGui", 5)

	topbarIcon = Icon.new()
		:setImage("rbxassetid://126942755236234")
		:setLabel("")
		:setOrder(8)
		:setEnabled(true)
		:setCaption("Match History")
		:bindEvent("selected", onIconSelected)
		:bindEvent("deselected", onIconDeselected)

	scope:Observer(historyVisible):onChange(function()
		if isUpdatingFromIcon then
			return
		end
		local visible = Fusion.peek(historyVisible)
		if topbarIcon then
			isUpdatingFromModal = true
			if visible then
				topbarIcon:select()
			else
				topbarIcon:deselect()
			end
			isUpdatingFromModal = false
		end
	end)

	local function onRecorderIconSelected()
		if isUpdatingRecorderFromModal then
			return
		end
		if recorderVisibleState then
			recorderVisibleState:set(true)
		end
	end

	local function onRecorderIconDeselected()
		if isUpdatingRecorderFromModal then
			return
		end
		if recorderVisibleState and recorderVisibleState:get() then
			isUpdatingRecorderFromIcon = true
			recorderVisibleState:set(false)
			isUpdatingRecorderFromIcon = false
		end
	end

	local hasRecorderAccess = false
	if LocalPlayer then
		for _, id in AimChamberConfig.RecorderAccessUserIds do
			if LocalPlayer.UserId == id then
				hasRecorderAccess = true
				break
			end
		end
	end

	if hasRecorderAccess then
		recorderIcon = Icon.new()
			:setLabel("VDI MVR")
			:setOrder(9)
			:setEnabled(true)
			:setCaption("Movement Recorder")
			:bindEvent("selected", onRecorderIconSelected)
			:bindEvent("deselected", onRecorderIconDeselected)

		Iris.Init()
		recorderVisibleState = Iris.State(false)
		local recorderConfirmExportState = Iris.State(false)

		recorderVisibleState:onChange(function(visible)
			if isUpdatingRecorderFromIcon then
				return
			end
			if recorderIcon then
				isUpdatingRecorderFromModal = true
				if visible then
					recorderIcon:select()
				else
					recorderIcon:deselect()
				end
				isUpdatingRecorderFromModal = false
			end
		end)

		Iris:Connect(function()
			AimChamberRecorderUI({
				VisibleState = recorderVisibleState,
				ConfirmExportState = recorderConfirmExportState,
				IsRecording = recorderIsRecording,
				RecordedChunks = recorderChunks,
				FrameCount = recorderFrameCount,
				ElapsedTime = AimChamberRecorder.getElapsedTime(),
				OnStartRecording = function()
					AimChamberRecorder.startRecording()
					recorderIsRecording = true
					recorderChunks = {}
					recorderFrameCount = 0
					recorderConfirmExportState:set(false)

					task.spawn(function()
						while recorderIsRecording do
							recorderFrameCount = AimChamberRecorder.getFrameCount()
							task.wait(0.2)
						end
					end)
				end,
				OnStopRecording = function()
					local chunks = AimChamberRecorder.stopRecording()
					recorderIsRecording = false
					recorderChunks = chunks or {}
					recorderFrameCount = AimChamberRecorder.getFrameCount()
				end,
				OnExportDiscord = function()
					if recorderChunks and #recorderChunks > 0 then
						print("[AimChamber] Sending ExportMovement to server with", #recorderChunks, "chunks.")
						Network.AimChamber.sendExportMovement(recorderChunks)
					else
						warn("[AimChamber] Cannot export: no recorded chunks available.")
					end
				end,
			})
		end)
	end

	timerHUD = AimChamberTimerHUD.createHUD({
		Visible = timerVisible,
		ElapsedTime = timerElapsedTime,
		SpawnRate = timerSpawnRate,
		PresetId = configPresetId,
		IsAiMode = isAiModeComputed,
		Settings = configSettings,
	})
	timerHUD.Parent = LocalPlayer:WaitForChild("PlayerGui", 5)

	assessmentWindow = AimChamberAssessmentUI.createWindow({
		Visible = assessmentVisible,
		Payload = assessmentPayload,
		OnClose = function()
			assessmentVisible:set(false)
		end,
	})
	assessmentWindow.Parent = LocalPlayer:WaitForChild("PlayerGui", 5)

	AimChamberLeaderboardClient.start()
	AimChamberRecorder.start()
end

function AimChamberService:Cleanup()
	if configWindow then
		configWindow:Destroy()
		configWindow = nil
	end
	if timerHUD then
		timerHUD:Destroy()
		timerHUD = nil
	end
	if assessmentWindow then
		assessmentWindow:Destroy()
		assessmentWindow = nil
	end
	if historyWindow then
		historyWindow:Destroy()
		historyWindow = nil
	end
	if topbarIcon then
		topbarIcon:destroy()
		topbarIcon = nil
	end
	if botScoreboardGui then
		botScoreboardGui:Destroy()
		botScoreboardGui = nil
	end
	if scoreboardScope then
		Fusion.doCleanup(scoreboardScope)
		scoreboardScope = nil
	end
	if AimChamberLeaderboardClient then
		AimChamberLeaderboardClient.cleanup()
	end
	if spawnHighlightAddedConn then
		spawnHighlightAddedConn:Disconnect()
		spawnHighlightAddedConn = nil
	end
	if spawnHighlightRemovedConn then
		spawnHighlightRemovedConn:Disconnect()
		spawnHighlightRemovedConn = nil
	end
	if resultOverlayGui then
		resultOverlayGui:Destroy()
		resultOverlayGui = nil
	end
	for _, tween in highlightTweens do
		tween:Cancel()
		tween:Destroy()
	end
	table.clear(highlightTweens)
	scope:doCleanup()
end

return AimChamberService
