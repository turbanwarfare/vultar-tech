--!strict
--!native
--!optimize 2

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local Root = script.Parent
local MainModule = require(Root.Shared.Game).get()
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Network = { ScreenWatch = require(Root.Shared.Network) }
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)

local ScreenWatchTarget = require(script.ScreenWatchTarget)
local AimStream = require(script.AimStream)
local ScreenWatchWatcher = require(script.ScreenWatchWatcher)
local ScreenWatchPanel = require(script.Panel)
local ScreenWatchSelectModal = require(script.Panel.ScreenWatchSelectModal)

local ScreenWatchService = {}
ScreenWatchService.Name = "ScreenWatchService"

local scope = Fusion:scoped()
local uiInstance: ScreenGui? = nil
local selectModalInstance: ScreenGui? = nil
local playerGui: PlayerGui? = nil
local selectMenuVisible = scope:Value(false)
local PLAYBACK_ACTION = "VultarScreenWatchPlayback"

local function watchNextSuspect(): ()
	local list = ScreenWatchWatcher.getSuspects()
	if #list == 0 then
		return
	end
	local current = ScreenWatchService:GetTargetUserId()
	local index = 0
	for i, suspect in list do
		if suspect.userId == current then
			index = i
			break
		end
	end
	for offset = 1, #list do
		local candidate = list[(index + offset - 1) % #list + 1]
		if candidate.userId ~= current and Players:GetPlayerByUserId(candidate.userId) then
			ScreenWatchService:StartWatch(candidate.userId)
			return
		end
	end
end

local function watchLastVictim(): ()
	local victimId = ScreenWatchWatcher.getLastVictimId()
	if victimId and Players:GetPlayerByUserId(victimId) then
		ScreenWatchService:StartWatch(victimId)
	end
end

local KEY_ACTIONS: { [Enum.KeyCode]: () -> () } = {
	[Enum.KeyCode.P] = ScreenWatchWatcher.togglePause,
	[Enum.KeyCode.O] = ScreenWatchWatcher.cycleSpeed,
	[Enum.KeyCode.Comma] = function()
		ScreenWatchWatcher.step(-1)
	end,
	[Enum.KeyCode.Period] = function()
		ScreenWatchWatcher.step(1)
	end,
	[Enum.KeyCode.LeftBracket] = function()
		ScreenWatchWatcher.seek(-5)
	end,
	[Enum.KeyCode.RightBracket] = function()
		ScreenWatchWatcher.seek(5)
	end,
	[Enum.KeyCode.H] = ScreenWatchWatcher.goLive,
	[Enum.KeyCode.N] = watchNextSuspect,
	[Enum.KeyCode.B] = watchLastVictim,
}

local function reservedKeys(): { [Enum.KeyCode]: boolean }
	local reserved: { [Enum.KeyCode]: boolean } = {}
	local settings = ServiceLocator.Settings()
	local defaults = SettingsConfig.DefaultSettings and SettingsConfig.DefaultSettings.Keybinds
	if not settings or typeof(settings.GetKeybind) ~= "function" or not defaults then
		return reserved
	end
	for action in defaults do
		local keyName = settings:GetKeybind(action)
		if keyName then
			local ok, keyCode = pcall(function()
				return (Enum.KeyCode :: any)[keyName]
			end)
			if ok and keyCode then
				reserved[keyCode] = true
			end
		end
	end
	return reserved
end

local function onPlaybackInput(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local action = KEY_ACTIONS[input.KeyCode]
	if not action then
		return Enum.ContextActionResult.Pass
	end
	action()
	return Enum.ContextActionResult.Sink
end

local function bindPlaybackKeys(): ()
	local reserved = reservedKeys()
	local keys: { Enum.KeyCode } = {}
	for key in KEY_ACTIONS do
		if not reserved[key] then
			table.insert(keys, key)
		end
	end
	if #keys > 0 then
		ContextActionService:BindAction(PLAYBACK_ACTION, onPlaybackInput, false, table.unpack(keys))
	end
end

local function unbindPlaybackKeys(): ()
	ContextActionService:UnbindAction(PLAYBACK_ACTION)
end

function ScreenWatchService:StartWatch(targetUserId: number): ()
	Network.ScreenWatch.sendSubscribeWatch(targetUserId)
end

function ScreenWatchService:StopWatch(): ()
	local state = ScreenWatchWatcher.getState()
	local targetId = Fusion.peek(state.targetUserId)
	if targetId and targetId ~= 0 then
		Network.ScreenWatch.sendUnsubscribeWatch(targetId)
	end
	ScreenWatchWatcher.stopWatching()
end

function ScreenWatchService:IsWatching(): boolean
	local state = ScreenWatchWatcher.getState()
	return Fusion.peek(state.isWatching) == true
end

function ScreenWatchService:GetTargetUserId(): number
	local state = ScreenWatchWatcher.getState()
	if Fusion.peek(state.isWatching) then
		return Fusion.peek(state.targetUserId) or 0
	end
	return 0
end

function ScreenWatchService:GetTargetPlayer(): Player?
	local targetId = self:GetTargetUserId()
	return if targetId ~= 0 then Players:GetPlayerByUserId(targetId) else nil
end

function ScreenWatchService:GetESPMode(): string
	return ScreenWatchWatcher.getESPMode()
end

function ScreenWatchService:CycleESPMode(): ()
	ScreenWatchWatcher.cycleESPMode()
end

function ScreenWatchService:OpenSelectMenu(): ()
	selectMenuVisible:set(true)
end

function ScreenWatchService:CloseSelectMenu(): ()
	selectMenuVisible:set(false)
end

function ScreenWatchService:ExportLogs(): ()
	ScreenWatchWatcher.exportLogs()
end

function ScreenWatchService:init(): ()
	ScreenWatchTarget.init()
	ScreenWatchWatcher.init()
	AimStream.start()

	Network.ScreenWatch.onOpenSelectMenu(function()
		selectMenuVisible:set(true)
	end)

	Network.ScreenWatch.sendClientReady()
end

local function ensureUI(): ()
	local gui = playerGui
	if uiInstance or not gui then
		return
	end

	local state = ScreenWatchWatcher.getState()

	uiInstance = ScreenWatchPanel(scope, {
		IsWatching = state.isWatching,
		TargetUserId = state.targetUserId,
		TargetName = state.targetName,
		CursorPosition = state.cursorPosition,
		CursorIcon = state.cursorIcon,
		CursorSize = state.cursorSize,
		PlaybackStatus = state.playbackStatus,
		PlaybackPaused = state.playbackPaused,
		PlaybackSpeed = state.playbackSpeed,
		MarkersEnabled = state.markersEnabled,
		TimelineSpan = state.timelineSpan,
		TimelineRewind = state.timelineRewind,
		TimelineTicks = state.timelineTicks,
		LagStatus = state.lagStatus,
		AcReport = state.acReport,
		FlickBars = state.flickBars,
		FlickPeak = state.flickPeak,
		IsCursorFree = state.isCursorFree,
		IsSprinting = state.isSprinting,
		IsCrouching = state.isCrouching,
		TrailEnabled = state.trailEnabled,
		GhostsEnabled = state.ghostsEnabled,
		ESPMode = state.espMode,
		TrailNodes = state.trailNodes,
		KeyStates = state.keyStates,
		MouseStates = state.mouseStates,
		KeyHistory = state.keyHistory,
		HitHistory = state.hitHistory,
		InputsVisible = state.inputsVisible,
		HitsVisible = state.hitsVisible,
		TargetPing = state.targetPing,
		TargetAvgPing = state.targetAvgPing,
		TargetPingSpikes = state.targetPingSpikes,
		TargetMatchAccuracy = state.targetMatchAccuracy,
		TargetFOV = state.targetFOV,
		TargetResolution = state.targetResolution,
		OnStopWatching = function()
			ScreenWatchService:StopWatch()
			ScreenWatchService:OpenSelectMenu()
		end,
		OnToggleTrail = function()
			ScreenWatchWatcher.toggleTrail()
		end,
		OnToggleGhosts = function()
			ScreenWatchWatcher.toggleGhosts()
		end,
		OnCycleESP = function()
			ScreenWatchWatcher.cycleESPMode()
		end,
		OnToggleInputs = function()
			ScreenWatchWatcher.toggleInputs()
		end,
		OnToggleHits = function()
			ScreenWatchWatcher.toggleHits()
		end,
		OnExportLogs = function()
			ScreenWatchService:ExportLogs()
		end,
		OnTogglePause = ScreenWatchWatcher.togglePause,
		OnCycleSpeed = ScreenWatchWatcher.cycleSpeed,
		OnStepBack = function()
			ScreenWatchWatcher.step(-1)
		end,
		OnStepForward = function()
			ScreenWatchWatcher.step(1)
		end,
		OnSeekBack = function()
			ScreenWatchWatcher.seek(-5)
		end,
		OnSeekForward = function()
			ScreenWatchWatcher.seek(5)
		end,
		OnGoLive = ScreenWatchWatcher.goLive,
		OnNextSuspect = watchNextSuspect,
		OnWatchVictim = watchLastVictim,
		OnSeekFraction = ScreenWatchWatcher.seekToFraction,
		OnToggleMarkers = ScreenWatchWatcher.toggleMarkers,
	})

	selectModalInstance = ScreenWatchSelectModal(scope, {
		Visible = selectMenuVisible,
		OnSelectTarget = function(targetPlayer: Player)
			selectMenuVisible:set(false)
			ScreenWatchService:StartWatch(targetPlayer.UserId)
		end,
		OnClose = function()
			selectMenuVisible:set(false)
		end,
	})

	if uiInstance then
		uiInstance.Parent = gui
	end

	if selectModalInstance then
		selectModalInstance.Parent = gui
	end
end

function ScreenWatchService:start(): ()
	local localPlayer = Players.LocalPlayer
	playerGui = localPlayer:WaitForChild("PlayerGui", 10) :: PlayerGui?
	if not playerGui then
		return
	end

	local state = ScreenWatchWatcher.getState()

	scope:Observer(selectMenuVisible):onBind(function()
		if Fusion.peek(selectMenuVisible) then
			ensureUI()
		end
	end)

	scope:Observer(state.isWatching):onBind(function()
		if Fusion.peek(state.isWatching) then
			ensureUI()
			bindPlaybackKeys()
		else
			unbindPlaybackKeys()
		end
	end)
end

function ScreenWatchService:Cleanup(): ()
	ScreenWatchService:StopWatch()
	ScreenWatchTarget.stopCapture()
	AimStream.stop()

	unbindPlaybackKeys()

	if uiInstance then
		uiInstance:Destroy()
		uiInstance = nil
	end

	if selectModalInstance then
		selectModalInstance:Destroy()
		selectModalInstance = nil
	end

	scope:doCleanup()
end

return ScreenWatchService
