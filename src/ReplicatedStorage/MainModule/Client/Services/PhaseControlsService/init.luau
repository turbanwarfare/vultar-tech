--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Icon = require(Packages:WaitForChild("TopbarPlus", 5))
local PhaseControls = require(MainModule.Client.Components.PhaseControls)
local Maps = require(MainModule.Shared.Config.Maps)
local Network = require(MainModule.Shared.Network)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)

local PhaseControlsService = {}
PhaseControlsService.Name = "PhaseControlsService"

local scope: any = nil
local controlsGui: ScreenGui? = nil
local playerGui: PlayerGui? = nil
local topbarIcon: any = nil

local hasAccess: any = nil
local isOfficial: any = nil
local currentPhase: any = nil
local raidTime: any = nil
local termTime: any = nil
local modalVisible: any = nil

local isActive: boolean = false
local isUpdatingFromIcon: boolean = false
local isUpdatingFromModal: boolean = false
local hasAccessCached: boolean = false

local phaseUpdateConnection: { Disconnect: () -> () }? = nil

local TERMINAL_ICON = "rbxassetid://119015428034090"

local function sendControl(payload: Network.PhaseControlPayload): ()
	Network.Phase.sendControl(payload)
end

local function onPhaseUpdate(state: Network.PhaseState): ()
	if isOfficial then
		isOfficial:set(state.Official)
	end
	if currentPhase then
		currentPhase:set(state.Phase)
	end
	if raidTime then
		raidTime:set(state.RaidTime)
	end
	if termTime then
		termTime:set(state.TermTime)
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
		:setCaption("Phase Controls")
		:bindEvent("selected", onIconSelected)
		:bindEvent("deselected", onIconDeselected)
end

createControls = function(): ()
	if controlsGui then return end

	scope = Fusion.scoped(Fusion)

	hasAccess = scope:Value(hasAccessCached)
	isOfficial = scope:Value(false)
	currentPhase = scope:Value(0)
	raidTime = scope:Value(0)
	termTime = scope:Value(0)
	modalVisible = scope:Value(false)

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

	controlsGui = PhaseControls(scope, {
		Visible = modalVisible,
		IsOfficial = isOfficial,
		CurrentPhase = currentPhase,
		RaidTime = raidTime,
		TermTime = termTime,
		OnClose = function()
			modalVisible:set(false)
		end,
		OnStart = function()
			sendControl({ action = "start" })
		end,
		OnSkipPhase = function()
			sendControl({ action = "skipPhase" })
		end,
		OnEnd = function()
			sendControl({ action = "end" })
		end,
		OnRaidTimeChange = function(value: number)
			sendControl({ action = "setRaidTime", raidTime = value })
		end,
		OnTermTimeChange = function(value: number)
			sendControl({ action = "setTermTime", termTime = value })
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
	currentPhase = nil
	raidTime = nil
	termTime = nil
	modalVisible = nil
end

local function fetchPermissions(): ()
	task.spawn(function()		for _ = 1, 5 do
			local permissions = Network.Phase.getPermissions()
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
	task.spawn(function()		local state = Network.Phase.getState()
		if state then
			onPhaseUpdate(state)
		end
	end)
end

function PhaseControlsService:init(): ()
	local mapConfig = Maps.getConfig()
	isActive = mapConfig.RaidType == "Phase"
	playerGui = PlayerGuiHelper.waitForPlayerGui()
end

function PhaseControlsService:start(): ()
	if not isActive then return end

	createTopbarIcon()
	fetchPermissions()
	fetchInitialState()

	phaseUpdateConnection = Network.Phase.onUpdate(onPhaseUpdate)
end

function PhaseControlsService:Cleanup(): ()
	if phaseUpdateConnection then
		phaseUpdateConnection:Disconnect()
		phaseUpdateConnection = nil
	end

	destroyControls()
	isActive = false
end

return PhaseControlsService
