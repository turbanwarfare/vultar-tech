--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Icon = require(Packages:WaitForChild("TopbarPlus", 5))
local TerminalControls = require(MainModule.Client.Components.TerminalControls)
local Maps = require(MainModule.Shared.Config.Maps)
local Network = require(MainModule.Shared.Network)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)

local TerminalControlsService = {}
TerminalControlsService.Name = "TerminalControlsService"

local scope: any = nil
local controlsGui: ScreenGui? = nil
local playerGui: PlayerGui? = nil
local topbarIcon: any = nil

local hasAccess: any = nil
local isOfficial: any = nil
local isPaused: any = nil
local isCountingDown: any = nil
local maxPoints: any = nil
local rotationMin: any = nil
local rotationMax: any = nil
local defenderScore: any = nil
local hostileScore: any = nil
local modalVisible: any = nil

local defaultMaxPoints: number = 1000
local defaultRotationMin: number = 100
local defaultRotationMax: number = 120

local isActive: boolean = false
local isUpdatingFromIcon: boolean = false
local isUpdatingFromModal: boolean = false
local hasAccessCached: boolean = false

local hardpointUpdateConnection: RBXScriptConnection? = nil

local TERMINAL_ICON = "rbxassetid://119015428034090"

local function sendControl(action: Network.ControlAction, payload: Network.ControlPayload?): ()
	local controlPayload: Network.ControlPayload = payload or { action = action }
	controlPayload.action = action
	Network.Hardpoint.sendControl(controlPayload)
end

local function onHardpointUpdate(state: Network.HardpointState): ()
	if isOfficial then
		isOfficial:set(state.Official)
	end
	if isPaused then
		isPaused:set(state.Paused)
	end
	if isCountingDown then
		isCountingDown:set(state.CountingDown)
	end
	if maxPoints then
		maxPoints:set(state.MaxPoints)
	end
	if rotationMin then
		rotationMin:set(state.RotationTimeMin)
	end
	if rotationMax then
		rotationMax:set(state.RotationTimeMax)
	end
	if defenderScore then
		defenderScore:set(state.DefenderScore)
	end
	if hostileScore then
		hostileScore:set(state.HostileScore)
	end
end

local function updateIconVisibility(): ()
	if not topbarIcon then
		return
	end

	if hasAccessCached then
		topbarIcon:setEnabled(true)
	else
		topbarIcon:setEnabled(false)
	end
end

local createControls: () -> ()
local fetchInitialState: () -> ()

local function onIconSelected(): ()
	if isUpdatingFromModal then
		return
	end
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
	if isUpdatingFromModal then
		return
	end
	if modalVisible then
		isUpdatingFromIcon = true
		modalVisible:set(false)
		isUpdatingFromIcon = false
	end
end

local function createTopbarIcon(): ()
	if topbarIcon then
		return
	end

	topbarIcon = Icon.new()
		:setImage(TERMINAL_ICON)
		:setLabel("")
		:setOrder(5)
		:setEnabled(false)
		:setCaption("Terminal Controls")
		:bindEvent("selected", onIconSelected)
		:bindEvent("deselected", onIconDeselected)
end

createControls = function(): ()
	if controlsGui then
		return
	end

	scope = Fusion.scoped(Fusion)

	hasAccess = scope:Value(hasAccessCached)
	isOfficial = scope:Value(false)
	isPaused = scope:Value(true)
	isCountingDown = scope:Value(false)
	maxPoints = scope:Value(defaultMaxPoints)
	rotationMin = scope:Value(defaultRotationMin)
	rotationMax = scope:Value(defaultRotationMax)
	defenderScore = scope:Value(0)
	hostileScore = scope:Value(0)
	modalVisible = scope:Value(false)

	scope:Observer(modalVisible):onChange(function()
		if isUpdatingFromIcon then
			return
		end
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

	controlsGui = TerminalControls(scope, {
		Visible = modalVisible,
		IsOfficial = isOfficial,
		IsPaused = isPaused,
		IsCountingDown = isCountingDown,
		MaxPoints = maxPoints,
		RotationMin = rotationMin,
		RotationMax = rotationMax,
		DefenderScore = defenderScore,
		HostileScore = hostileScore,
		DefaultMaxPoints = defaultMaxPoints,
		DefaultRotationMin = defaultRotationMin,
		DefaultRotationMax = defaultRotationMax,
		OnClose = function()
			modalVisible:set(false)
		end,
		OnStart = function()
			sendControl("start")
		end,
		OnPause = function()
			sendControl("pause")
		end,
		OnUnpause = function()
			sendControl("unpause")
		end,
		OnReset = function()
			sendControl("reset")
		end,
		OnMaxPointsChange = function(value: number)
			sendControl("setMaxPoints", { action = "setMaxPoints", maxPoints = value })
		end,
		OnRotationRangeChange = function(min: number, max: number)
			sendControl("setRotationRange", {
				action = "setRotationRange",
				rotationMin = min,
				rotationMax = max,
			})
		end,
		OnScoresChange = function(defender: number, hostile: number)
			sendControl("setScores", {
				action = "setScores",
				defenderScore = defender,
				hostileScore = hostile,
			})
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
	isPaused = nil
	isCountingDown = nil
	maxPoints = nil
	rotationMin = nil
	rotationMax = nil
	defenderScore = nil
	hostileScore = nil
	modalVisible = nil
end

local function fetchPermissions(): ()
	task.spawn(function()		local permissions = Network.Hardpoint.getPermissions()
		if permissions then
			hasAccessCached = permissions.HasAccess
			if hasAccess then
				hasAccess:set(permissions.HasAccess)
			end
			updateIconVisibility()
		end
	end)
end

fetchInitialState = function(): ()
	task.spawn(function()		local state = Network.Hardpoint.getState()
		if state then
			onHardpointUpdate(state)
		end
	end)
end

function TerminalControlsService:init(): ()
	local mapConfig = Maps.getConfig()
	isActive = mapConfig.Hardpoint
	defaultMaxPoints = mapConfig.DefaultPoints
	playerGui = PlayerGuiHelper.waitForPlayerGui()
end

function TerminalControlsService:start(): ()
	if not isActive then
		return
	end

	createTopbarIcon()
	fetchPermissions()
	fetchInitialState()

	hardpointUpdateConnection = Network.Hardpoint.onUpdate(onHardpointUpdate)
end

function TerminalControlsService:HasAccess(): boolean
	if hasAccess then
		return Fusion.peek(hasAccess)
	end
	return false
end

function TerminalControlsService:IsActive(): boolean
	return isActive
end

function TerminalControlsService:ShowModal(): ()
	if not controlsGui then
		createControls()
		fetchInitialState()
	end
	if modalVisible then
		modalVisible:set(true)
	end
end

function TerminalControlsService:HideModal(): ()
	if modalVisible then
		modalVisible:set(false)
	end
end

function TerminalControlsService:Cleanup(): ()
	if hardpointUpdateConnection then
		hardpointUpdateConnection:Disconnect()
		hardpointUpdateConnection = nil
	end

	destroyControls()
	isActive = false
end

return TerminalControlsService
