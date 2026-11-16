--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Icon = require(Packages:WaitForChild("TopbarPlus", 5))
local DominationControls = require(MainModule.Client.Components.DominationControls)
local Maps = require(MainModule.Shared.Config.Maps)
local DominationConfig = require(MainModule.Shared.Config.DominationConfig)
local Network = require(MainModule.Shared.Network)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)

local DominationControlsService = {}
DominationControlsService.Name = "DominationControlsService"

local scope: any = nil
local controlsGui: ScreenGui? = nil
local playerGui: PlayerGui? = nil
local topbarIcon: any = nil

local hasAccess: any = nil
local isOfficial: any = nil
local paused: any = nil
local defenderScore: any = nil
local hostileScore: any = nil
local maxScore: any = nil
local modalVisible: any = nil

local captureTimeSeconds: any = nil
local speedBonusPerPlayer: any = nil
local speedBonusMaxPlayers: any = nil

local isActive: boolean = false
local isUpdatingFromIcon: boolean = false
local isUpdatingFromModal: boolean = false
local hasAccessCached: boolean = false

local updateConnection: { Disconnect: () -> () }? = nil

local TERMINAL_ICON = "rbxassetid://119015428034090"

local function sendControl(payload: Network.DominationControlPayload): ()
	Network.Domination.sendControl(payload)
end

local function onDominationUpdate(state: Network.DominationState): ()
	if isOfficial then
		isOfficial:set(state.Official)
	end
	if paused then
		paused:set(state.Paused)
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
end

local function updateIconVisibility(): ()
	if not topbarIcon then return end

	if hasAccessCached then
		topbarIcon:setEnabled(true)
	else
		topbarIcon:setEnabled(false)
	end
end

local createControls: () -> ()
local fetchInitialState: () -> ()

local function onIconSelected(): ()
	if isUpdatingFromModal then return end
	if not controlsGui then
		createControls()
		fetchInitialState()
	end
	if modalVisible then
		isUpdatingFromIcon = true
		modalVisible:set(true)
		isUpdatingFromIcon = false
	end
end

local function onIconDeselected(): ()
	if isUpdatingFromModal then return end
	if modalVisible then
		isUpdatingFromIcon = true
		modalVisible:set(false)
		isUpdatingFromIcon = false
	end
end

local function createTopbarIcon(): ()
	if topbarIcon then return end

	topbarIcon = Icon.new()
		:setImage(TERMINAL_ICON)
		:setLabel("")
		:setOrder(5)
		:setEnabled(false)
		:setCaption("Domination Controls")
		:bindEvent("selected", onIconSelected)
		:bindEvent("deselected", onIconDeselected)
end

createControls = function(): ()
	if controlsGui then return end

	scope = Fusion.scoped(Fusion)

	hasAccess = scope:Value(hasAccessCached)
	isOfficial = scope:Value(false)
	paused = scope:Value(true)
	defenderScore = scope:Value(0)
	hostileScore = scope:Value(0)
	maxScore = scope:Value(1000)
	modalVisible = scope:Value(false)

	captureTimeSeconds = scope:Value(DominationConfig.DEFAULT.CaptureTimeSeconds)
	speedBonusPerPlayer = scope:Value(DominationConfig.DEFAULT.SpeedBonusPerPlayer)
	speedBonusMaxPlayers = scope:Value(DominationConfig.DEFAULT.SpeedBonusMaxPlayers)

	scope:Observer(modalVisible):onChange(function()
		if isUpdatingFromIcon then return end
		local visible = Fusion.peek(modalVisible)
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

	controlsGui = DominationControls(scope, {
		Visible = modalVisible,
		IsOfficial = isOfficial,
		Paused = paused,
		DefenderScore = defenderScore,
		HostileScore = hostileScore,
		MaxScore = maxScore,
		OnClose = function()
			modalVisible:set(false)
		end,
		OnStart = function()
			sendControl({ action = "start" })
		end,
		OnEnd = function()
			sendControl({ action = "reset" })
		end,
		OnPause = function()
			sendControl({ action = "pause" })
		end,
		OnUnpause = function()
			sendControl({ action = "unpause" })
		end,
		OnDefenderScoreChange = function(value: number)
			sendControl({ action = "setScores", defenderScore = value })
		end,
		OnHostileScoreChange = function(value: number)
			sendControl({ action = "setScores", hostileScore = value })
		end,
		OnMaxScoreChange = function(value: number)
			sendControl({ action = "setMaxScore", maxScore = value })
		end,
		CaptureTimeSeconds = captureTimeSeconds,
		SpeedBonusPerPlayer = speedBonusPerPlayer,
		SpeedBonusMaxPlayers = speedBonusMaxPlayers,
		OnCaptureTimeSecondsChange = function(value: number)
			local remote = game.ReplicatedStorage:FindFirstChild("DominationConfigRemote") :: RemoteEvent?
			if remote then
				remote:FireServer({ CaptureTimeSeconds = value })
			end
		end,
		OnSpeedBonusPerPlayerChange = function(value: number)
			local remote = game.ReplicatedStorage:FindFirstChild("DominationConfigRemote") :: RemoteEvent?
			if remote then
				remote:FireServer({ SpeedBonusPerPlayer = value })
			end
		end,
		OnSpeedBonusMaxPlayersChange = function(value: number)
			local remote = game.ReplicatedStorage:FindFirstChild("DominationConfigRemote") :: RemoteEvent?
			if remote then
				remote:FireServer({ SpeedBonusMaxPlayers = value })
			end
		end,
	})

	if playerGui then
		controlsGui.Parent = playerGui
	end
end

local function destroyControls(): ()
	if topbarIcon then
		topbarIcon:destroy()
		topbarIcon = nil
	end

	if scope then
		scope:doCleanup()
		scope = nil
	end
	controlsGui = nil
	hasAccess = nil
	isOfficial = nil
	paused = nil
	defenderScore = nil
	hostileScore = nil
	maxScore = nil
	modalVisible = nil
	captureTimeSeconds = nil
	speedBonusPerPlayer = nil
	speedBonusMaxPlayers = nil
end

local function fetchPermissions(): ()
	task.spawn(function()
		for _ = 1, 5 do
			local permissions = Network.Domination.getPermissions()
			if permissions then
				hasAccessCached = permissions.HasAccess
				if hasAccess then
					hasAccess:set(permissions.HasAccess)
				end
				updateIconVisibility()
				return
			end
			task.wait(1)
		end
	end)
end

fetchInitialState = function(): ()
	task.spawn(function()
		local state = Network.Domination.getState()
		if state then
			onDominationUpdate(state)
		end
	end)
end

function DominationControlsService:init(): ()
	isActive = Maps.isDominationMap()
	playerGui = PlayerGuiHelper.waitForPlayerGui()
end

function DominationControlsService:start(): ()
	if not isActive then return end

	createTopbarIcon()
	fetchPermissions()
	fetchInitialState()

	updateConnection = Network.Domination.onUpdate(onDominationUpdate)
end

function DominationControlsService:Cleanup(): ()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	destroyControls()
	isActive = false
end

return DominationControlsService

