--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Icon = require(Packages:WaitForChild("TopbarPlus", 5))
local PlayerLookup = require(MainModule.Client.Components.PlayerLookup)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)

local ArenaLookupClient = {}

local scope: any = nil
local lookupGui: ScreenGui? = nil
local playerGui: PlayerGui? = nil
local topbarIcon: any = nil
local modalVisible: any = nil

local isUpdatingFromIcon = false
local isUpdatingFromModal = false

local STATS_ICON = "rbxassetid://95734475402045"

local function onIconSelected(): ()
	if isUpdatingFromModal then
		return
	end
	if not lookupGui then
		ArenaLookupClient.createUI()
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

function ArenaLookupClient.createTopbarIcon(): ()
	if topbarIcon then
		return
	end

	topbarIcon = Icon.new()
		:setImage(STATS_ICON)
		:setLabel("")
		:setOrder(6)
		:setEnabled(true)
		:setCaption("Player Lookup")
		:bindEvent("selected", onIconSelected)
		:bindEvent("deselected", onIconDeselected)
end

function ArenaLookupClient.createUI(): ()
	if lookupGui then
		return
	end

	scope = Fusion.scoped(Fusion)
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

	lookupGui = PlayerLookup(scope, {
		Visible = modalVisible,
		OnClose = function()
			modalVisible:set(false)
		end,
	})

	if playerGui then
		lookupGui.Parent = playerGui
	end
end

function ArenaLookupClient.init(): ()
	playerGui = PlayerGuiHelper.waitForPlayerGui()
end

function ArenaLookupClient.start(): ()
	ArenaLookupClient.createTopbarIcon()
end

function ArenaLookupClient.cleanup(): ()
	if topbarIcon then
		topbarIcon:destroy()
		topbarIcon = nil
	end

	if scope then
		scope:doCleanup()
		scope = nil
	end
	lookupGui = nil
	modalVisible = nil
end

return ArenaLookupClient
