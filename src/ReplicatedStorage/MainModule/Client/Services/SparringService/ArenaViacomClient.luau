--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Icon = require(Packages:WaitForChild("TopbarPlus", 5))
local ViacomPanel = require(MainModule.Client.Components.ViacomPanel)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)
local Network = require(MainModule.Shared.Network)

local ArenaViacomClient = {}

local scope: any = nil
local viacomGui: ScreenGui? = nil
local playerGui: PlayerGui? = nil
local topbarIcon: any = nil
local modalVisible: any = nil
local hasAccess: any = nil

local isUpdatingFromIcon = false
local isUpdatingFromModal = false

local VIACOM_ICON = "rbxassetid://134880308929198"

local function updateIconVisibility(): ()
	if not topbarIcon then
		return
	end
	if hasAccess and Fusion.peek(hasAccess) == true then
		topbarIcon:setEnabled(true)
	else
		topbarIcon:setEnabled(false)
	end
end

local function onIconSelected(): ()
	if isUpdatingFromModal then
		return
	end
	if not viacomGui then
		ArenaViacomClient.createUI()
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

function ArenaViacomClient.createTopbarIcon(): ()
	if topbarIcon then
		return
	end

	topbarIcon = Icon.new()
		:setImage(VIACOM_ICON)
		:setLabel("")
		:setOrder(8)
		:setEnabled(false)
		:setCaption("VIACOM Panel")
		:bindEvent("selected", onIconSelected)
		:bindEvent("deselected", onIconDeselected)
end

function ArenaViacomClient.createState(): ()
	if scope then
		return
	end

	scope = Fusion.scoped(Fusion)
	modalVisible = scope:Value(false)
	hasAccess = scope:Value(false)

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
end

function ArenaViacomClient.createUI(): ()
	if viacomGui then
		return
	end

	ArenaViacomClient.createState()

	viacomGui = ViacomPanel(scope, {
		Visible = modalVisible,
		OnClose = function()
			modalVisible:set(false)
		end,
	})

	if playerGui then
		viacomGui.Parent = playerGui
	end
end

function ArenaViacomClient.fetchAccess(): ()
	task.spawn(function()
		local access = Network.Spar.requestViacomCheckAccess()
		if hasAccess then
			hasAccess:set(access)
		end
		updateIconVisibility()
	end)
end

function ArenaViacomClient.init(): ()
	playerGui = PlayerGuiHelper.waitForPlayerGui()
end

function ArenaViacomClient.start(): ()
	ArenaViacomClient.createTopbarIcon()
	ArenaViacomClient.createState()
	ArenaViacomClient.fetchAccess()
end

function ArenaViacomClient.cleanup(): ()
	if topbarIcon then
		topbarIcon:destroy()
		topbarIcon = nil
	end

	if scope then
		scope:doCleanup()
		scope = nil
	end
	viacomGui = nil
	modalVisible = nil
	hasAccess = nil
end

return ArenaViacomClient
