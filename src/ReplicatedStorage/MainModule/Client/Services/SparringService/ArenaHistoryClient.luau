--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Icon = require(Packages:WaitForChild("TopbarPlus", 5))
local MatchHistory = require(MainModule.Client.Components.MatchHistory)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)
local Network = require(MainModule.Shared.Network)

local ArenaHistoryClient = {}

local scope: any = nil
local historyGui: ScreenGui? = nil
local playerGui: PlayerGui? = nil
local topbarIcon: any = nil
local modalVisible: any = nil
local historyData: any = nil
local isLoading: any = nil

local isUpdatingFromIcon = false
local isUpdatingFromModal = false

local HISTORY_ICON = "rbxassetid://126942755236234"

local function onIconSelected(): ()
	if isUpdatingFromModal then
		return
	end
	if not historyGui then
		ArenaHistoryClient.createUI()
	end
	if modalVisible and historyData and isLoading then
		isUpdatingFromIcon = true
		isLoading:set(true)
		modalVisible:set(true)
		isUpdatingFromIcon = false

		task.spawn(function()
			local data = Network.Spar.requestMatchHistory()
			if historyData then
				historyData:set(data or {})
			end
			if isLoading then
				isLoading:set(false)
			end
		end)
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

function ArenaHistoryClient.createTopbarIcon(): ()
	if topbarIcon then
		return
	end

	topbarIcon = Icon.new()
		:setImage(HISTORY_ICON)
		:setLabel("")
		:setOrder(7)
		:setEnabled(true)
		:setCaption("Match History")
		:bindEvent("selected", onIconSelected)
		:bindEvent("deselected", onIconDeselected)
end

function ArenaHistoryClient.createUI(): ()
	if historyGui then
		return
	end

	scope = Fusion.scoped(Fusion)
	modalVisible = scope:Value(false)
	historyData = scope:Value({})
	isLoading = scope:Value(false)

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

	historyGui = MatchHistory(scope, {
		Visible = modalVisible,
		OnClose = function()
			modalVisible:set(false)
		end,
		HistoryData = historyData,
		Loading = isLoading,
	})

	if playerGui then
		historyGui.Parent = playerGui
	end
end

function ArenaHistoryClient.init(): ()
	playerGui = PlayerGuiHelper.waitForPlayerGui()
end

function ArenaHistoryClient.start(): ()
	ArenaHistoryClient.createTopbarIcon()
end

function ArenaHistoryClient.cleanup(): ()
	if topbarIcon then
		topbarIcon:destroy()
		topbarIcon = nil
	end

	if scope then
		scope:doCleanup()
		scope = nil
	end
	historyGui = nil
	modalVisible = nil
	historyData = nil
	isLoading = nil
end

return ArenaHistoryClient
