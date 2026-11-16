--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5)) :: any
local scoped = Fusion.scoped
local peek = Fusion.peek

local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
local Network = require(MainModule.Shared.Network)
local LoadingState = require(MainModule.Client.Utils.UI.LoadingState)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)

local CursorAssetManager = require(script.CursorAssetManager)
local CursorIFFSystem = require(script.CursorIFFSystem)
local RadialUI = require(script.RadialUI)
local InputHandler = require(script.InputHandler)

local currentCursorURL: string = ""
local iconWatchConnection: RBXScriptConnection? = nil
local enabledWatchConnection: RBXScriptConnection? = nil

local function setCursor(url: string): ()
	if url == currentCursorURL then
		return
	end
	currentCursorURL = url
	UserInputService.MouseIcon = url
end

local function startCursorWatchers(): ()
	if iconWatchConnection then
		return
	end

	iconWatchConnection = UserInputService:GetPropertyChangedSignal("MouseIcon"):Connect(function()
		if currentCursorURL ~= "" and UserInputService.MouseIcon ~= currentCursorURL then
			UserInputService.MouseIcon = currentCursorURL
		end
	end)

	enabledWatchConnection = UserInputService:GetPropertyChangedSignal("MouseIconEnabled"):Connect(function()
		if currentCursorURL ~= "" and not UserInputService.MouseIconEnabled then
			UserInputService.MouseIconEnabled = true
		end
	end)
end

local function stopCursorWatchers(): ()
	if iconWatchConnection then
		iconWatchConnection:Disconnect()
		iconWatchConnection = nil
	end
	if enabledWatchConnection then
		enabledWatchConnection:Disconnect()
		enabledWatchConnection = nil
	end
end

local CursorService = {}
CursorService.Name = "CursorService"

local player = Players.LocalPlayer
local playerGui: PlayerGui? = nil

local scope: any = scoped(Fusion)

local currentCursorStyle: any = nil
local storedCustomCursorId: number = 0
local customCursorIdValue: any = nil
local isUsingCustomCursor: any = nil
local switchHistory: { number } = {}

local MAX_SWITCH_HISTORY = SettingsConfig.MAX_CURSOR_SWITCH_HISTORY

local cursorHistoryValue: any = scope:Value({})
local radialCursorsValue: any = scope:Value({})
local radialGui: ScreenGui? = nil
local hoveredIndex: any = nil
local wheelVisible: any = nil
local wheelPosition: any = nil
local radialCleanup: (() -> ())? = nil
local getRadialSelection: (() -> RadialUI.RadialResult?)? = nil

local INNER_RADIUS = 50
local OUTER_RADIUS = 120

local presetCount = #SettingsConfig.Cursors

local function getCursorVariantURL(variantIndex: number): string
	local styleIndex = 1
	if currentCursorStyle then
		styleIndex = peek(currentCursorStyle)
	end

	return CursorAssetManager.getVariantURL(styleIndex, variantIndex)
end

local overrideCursorURL: string? = nil

local function applyNeutralCursor(): ()
	local usingCustom = isUsingCustomCursor and peek(isUsingCustomCursor) or false
	local url: string

	if usingCustom and storedCustomCursorId > 0 then
		url = CursorAssetManager.getCachedURL(storedCustomCursorId) or "rbxassetid://" .. tostring(storedCustomCursorId)
	else
		url = getCursorVariantURL(1)
	end

	if overrideCursorURL and not usingCustom then
		local styleIndex = currentCursorStyle and peek(currentCursorStyle) or 1
		if styleIndex == 1 then
			url = overrideCursorURL
		end
	end

	if url ~= "" then
		setCursor(url)
		UserInputService.MouseIconEnabled = true
	end
end

local presetIdToIndex: { [number]: number } = {}
for i, cursor in SettingsConfig.Cursors do
	presetIdToIndex[cursor.id] = i
end

local function getActiveCursorAssetId(): number
	local usingCustom = isUsingCustomCursor and peek(isUsingCustomCursor) or false
	if usingCustom and storedCustomCursorId > 0 then
		return storedCustomCursorId
	end
	local styleIndex = currentCursorStyle and peek(currentCursorStyle) or 1
	local cursorData = SettingsConfig.Cursors[styleIndex]
	return if cursorData then cursorData.id else SettingsConfig.Cursors[1].id
end

local function applyCursorByAssetId(assetId: number): ()
	local presetIndex = presetIdToIndex[assetId]
	if presetIndex then
		isUsingCustomCursor:set(false)
		currentCursorStyle:set(presetIndex)
		Network.Settings.changeSetting("CursorStyle", presetIndex)
		Network.Settings.changeSetting("UsingCustomCursor", false)
	else
		CursorAssetManager.addToCache(assetId)
		storedCustomCursorId = assetId
		if customCursorIdValue then
			customCursorIdValue:set(assetId)
		end
		isUsingCustomCursor:set(true)
		Network.Settings.changeSetting("CustomCursorId", assetId)
		Network.Settings.changeSetting("UsingCustomCursor", true)
	end
	CursorIFFSystem.forceRefresh()
	CursorIFFSystem.updateState()
	applyNeutralCursor()
end

local function pushToSwitchHistory(assetId: number): ()
	local newHistory = { assetId }
	for _, id in switchHistory do
		if id ~= assetId then
			if #newHistory >= MAX_SWITCH_HISTORY then
				break
			end
			table.insert(newHistory, id)
		end
	end
	switchHistory = newHistory
	Network.Settings.changeSetting("CursorSwitchHistory", newHistory)
end

local function quickSwitch(): ()
	if #switchHistory < 2 then
		return
	end

	if not currentCursorStyle then
		return
	end

	local previous = switchHistory[2]
	if not previous or previous <= 0 then
		return
	end

	switchHistory[2] = switchHistory[1]
	switchHistory[1] = previous

	applyCursorByAssetId(previous)

	local historySnapshot = table.clone(switchHistory)
	Network.Settings.changeSetting("CursorSwitchHistory", historySnapshot)
end

local createRadialUI: () -> ()

local function ensureRadialCreated(): ()
	if radialGui then
		return
	end
	createRadialUI()
end

local function openRadial(): ()
	if LoadingState.isLoadingActive(ServiceLocator.Loading(), playerGui) then
		return
	end

	ensureRadialCreated()

	if not radialGui or not wheelVisible then
		return
	end

	local gun = ServiceLocator.Gun()
	if gun then
		gun:SetFireBlocked(true)
	end

	local mousePos = InputHandler.getMouseLocation()
	wheelPosition:set(UDim2.fromOffset(mousePos.X, mousePos.Y))
	wheelVisible:set(true)
end

local function closeRadial(): ()
	if not radialGui then
		return
	end

	if not wheelVisible then
		return
	end

	local gun = ServiceLocator.Gun()
	if gun then
		gun:SetFireBlocked(false)
	end

	wheelVisible:set(false)

	if not getRadialSelection then
		return
	end

	local result = getRadialSelection()
	if not result then
		return
	end

	if result.segmentType == "custom" and result.customCursorId then
		local cursorId = result.customCursorId
		if cursorId > 0 then
			pushToSwitchHistory(cursorId)
			storedCustomCursorId = cursorId
			if customCursorIdValue then
				customCursorIdValue:set(cursorId)
			end
			isUsingCustomCursor:set(true)
			Network.Settings.changeSetting("CustomCursorId", cursorId)
			Network.Settings.changeSetting("UsingCustomCursor", true)
			CursorIFFSystem.updateState()
			applyNeutralCursor()
		end
		return
	end

	if result.segmentType == "preset" and result.presetIndex then
		local selected = result.presetIndex
		local currentStyle = peek(currentCursorStyle)
		local usingCustom = peek(isUsingCustomCursor)

		if selected ~= currentStyle or usingCustom then
			local presetData = SettingsConfig.Cursors[selected]
			if presetData then
				pushToSwitchHistory(presetData.id)
			end
			isUsingCustomCursor:set(false)
			currentCursorStyle:set(selected)
			Network.Settings.changeSetting("CursorStyle", selected)
			Network.Settings.changeSetting("UsingCustomCursor", false)
			CursorIFFSystem.updateState()
			applyNeutralCursor()
		end
	end
end

createRadialUI = function()
	if radialCleanup then
		radialCleanup()
		radialCleanup = nil
	end

	if radialGui then
		radialGui:Destroy()
		radialGui = nil
	end

	getRadialSelection = nil

	local gui, visible, position, cleanup, getSelection = RadialUI.createRadialSelector(
		scope,
		hoveredIndex,
		currentCursorStyle,
		INNER_RADIUS,
		OUTER_RADIUS,
		customCursorIdValue,
		isUsingCustomCursor,
		radialCursorsValue
	)

	radialGui = gui
	wheelVisible = visible
	wheelPosition = position
	radialCleanup = cleanup
	getRadialSelection = getSelection

	if playerGui then
		radialGui.Parent = playerGui
	end
end

function CursorService:init(): ()
	playerGui = player:WaitForChild("PlayerGui", 15) :: PlayerGui?

	CursorAssetManager.buildCache()
end

function CursorService:start(): ()
	hoveredIndex = scope:Value(0)
	currentCursorStyle = scope:Value(1)
	customCursorIdValue = scope:Value(0)
	isUsingCustomCursor = scope:Value(false)

	InputHandler.connect({
		OnOpen = openRadial,
		OnClose = closeRadial,
		OnQuickSwitch = quickSwitch,
	})

	CursorAssetManager.preloadAll()

	CursorIFFSystem.connect({
		getCursorVariantURL = getCursorVariantURL,
		setCursor = setCursor,
		isUsingCustomCursor = function()
			return isUsingCustomCursor and peek(isUsingCustomCursor) or false
		end,
	})

	task.spawn(function()
		local serverSettings = Network.Settings.getSettings()
		if serverSettings and serverSettings.Settings then
			local settingStyle = serverSettings.Settings.CursorStyle
			local settingCustomId = serverSettings.Settings.CustomCursorId
			local settingUsingCustom = serverSettings.Settings.UsingCustomCursor
			local settingIFF = serverSettings.Settings.IFF
			local settingHistory = serverSettings.Settings.CustomCursorHistory
			local settingRadial = serverSettings.Settings.RadialCursors
			local settingSwitchHistory = serverSettings.Settings.CursorSwitchHistory

			if settingStyle then
				currentCursorStyle:set(settingStyle)
			end

			if type(settingHistory) == "table" then
				cursorHistoryValue:set(settingHistory)
				for _, cursorId in settingHistory do
					if cursorId > 0 then
						CursorAssetManager.addToCache(cursorId)
					end
				end
			end

			if type(settingRadial) == "table" then
				radialCursorsValue:set(settingRadial)
			end

			if settingCustomId and settingCustomId > 0 then
				local resolvedId = Network.Settings.checkCursor(settingCustomId)
				if resolvedId > 0 then
					storedCustomCursorId = resolvedId
					customCursorIdValue:set(resolvedId)
					CursorAssetManager.addToCache(resolvedId)
					if radialGui then
						createRadialUI()
					end
				end
			end

			if settingUsingCustom == true and storedCustomCursorId > 0 then
				isUsingCustomCursor:set(true)
			else
				isUsingCustomCursor:set(false)
			end

			if settingIFF ~= nil then
				CursorIFFSystem.setEnabled(settingIFF == true)
			end

			applyNeutralCursor()

			local knownIds: { [number]: boolean } = {}
			for _, cursor in SettingsConfig.Cursors do
				knownIds[cursor.id] = true
			end
			if type(settingHistory) == "table" then
				for _, id in settingHistory :: { number } do
					if id > 0 then
						knownIds[id] = true
					end
				end
			end
			if storedCustomCursorId > 0 then
				knownIds[storedCustomCursorId] = true
			end

			if type(settingSwitchHistory) == "table" then
				local cleaned = {}
				for _, id in settingSwitchHistory :: { number } do
					if knownIds[id] then
						table.insert(cleaned, id)
					end
				end
				switchHistory = cleaned
			end

			local currentId = getActiveCursorAssetId()
			if #switchHistory == 0 or switchHistory[1] ~= currentId then
				pushToSwitchHistory(currentId)
			end
		end

		CursorIFFSystem.updateLocalPlayerFaction()
		CursorIFFSystem.updateState()
	end)

	applyNeutralCursor()
	startCursorWatchers()
end

function CursorService:SetCursorStyle(styleIndex: number): ()
	if currentCursorStyle then
		local clamped = math.clamp(styleIndex, 1, presetCount)
		local presetData = SettingsConfig.Cursors[clamped]
		if presetData then
			pushToSwitchHistory(presetData.id)
		end
		isUsingCustomCursor:set(false)
		currentCursorStyle:set(math.clamp(styleIndex, 1, presetCount))
		Network.Settings.changeSetting("CursorStyle", styleIndex)
		Network.Settings.changeSetting("UsingCustomCursor", false)
		CursorIFFSystem.updateState()
		applyNeutralCursor()
	end
end

function CursorService:SetCustomCursorId(id: number): ()
	local hadCustom = storedCustomCursorId > 0

	if id > 0 then
		local resolvedId = Network.Settings.checkCursor(id)
		if resolvedId > 0 then
			id = resolvedId
		end
		pushToSwitchHistory(id)
		CursorAssetManager.addToCache(id)
		self:AddToHistory(id)
	end

	local hasCustom = id > 0
	local idChanged = storedCustomCursorId ~= id

	storedCustomCursorId = id
	if customCursorIdValue then
		customCursorIdValue:set(id)
	end

	if hadCustom ~= hasCustom or (hasCustom and idChanged) then
		if radialGui then
			createRadialUI()
		end
	end

	if id > 0 then
		isUsingCustomCursor:set(true)
		Network.Settings.changeSetting("CustomCursorId", id)
		Network.Settings.changeSetting("UsingCustomCursor", true)
	end

	CursorIFFSystem.updateState()
	applyNeutralCursor()
end

local function isInArray(arr: { number }, value: number): boolean
	return table.find(arr, value) ~= nil
end

local function removeFromArray(arr: { number }, value: number): { number }
	local result = {}
	for _, v in arr do
		if v ~= value then
			table.insert(result, v)
		end
	end
	return result
end

function CursorService:AddToHistory(cursorId: number): ()
	if cursorId <= 0 then
		return
	end

	if not cursorHistoryValue then
		return
	end

	local history = peek(cursorHistoryValue)
	if isInArray(history, cursorId) then
		return
	end

	local newHistory = { cursorId }
	for _, id in history do
		if #newHistory >= SettingsConfig.MAX_CURSOR_HISTORY then
			break
		end
		table.insert(newHistory, id)
	end

	cursorHistoryValue:set(newHistory)
	Network.Settings.changeSetting("CustomCursorHistory", newHistory)

	local radial = peek(radialCursorsValue)
	if #radial == 0 then
		self:AddToRadial(cursorId)
	end
end

function CursorService:RemoveFromHistory(cursorId: number): ()
	if not cursorHistoryValue then
		return
	end

	local history = peek(cursorHistoryValue)
	local newHistory = removeFromArray(history, cursorId)
	cursorHistoryValue:set(newHistory)
	Network.Settings.changeSetting("CustomCursorHistory", newHistory)

	self:RemoveFromRadial(cursorId)
end

function CursorService:GetHistory(): { number }
	if cursorHistoryValue then
		return peek(cursorHistoryValue)
	end
	return {}
end

function CursorService:AddToRadial(cursorId: number): ()
	if cursorId <= 0 then
		return
	end

	if not radialCursorsValue then
		return
	end

	local radial = peek(radialCursorsValue)
	if isInArray(radial, cursorId) then
		return
	end

	if #radial >= SettingsConfig.MAX_RADIAL_CURSORS then
		return
	end

	local newRadial = table.clone(radial)
	table.insert(newRadial, cursorId)
	radialCursorsValue:set(newRadial)
	Network.Settings.changeSetting("RadialCursors", newRadial)
	if radialGui then
		createRadialUI()
	end
end

function CursorService:RemoveFromRadial(cursorId: number): ()
	if not radialCursorsValue then
		return
	end

	local radial = peek(radialCursorsValue)
	local newRadial = removeFromArray(radial, cursorId)
	radialCursorsValue:set(newRadial)
	Network.Settings.changeSetting("RadialCursors", newRadial)
	if radialGui then
		createRadialUI()
	end
end

function CursorService:GetRadialCursors(): { number }
	if radialCursorsValue then
		return peek(radialCursorsValue)
	end
	return {}
end

function CursorService:IsInRadial(cursorId: number): boolean
	local radial = self:GetRadialCursors()
	return isInArray(radial, cursorId)
end

function CursorService:ToggleRadial(cursorId: number): ()
	if self:IsInRadial(cursorId) then
		self:RemoveFromRadial(cursorId)
	else
		self:AddToRadial(cursorId)
	end
end

function CursorService:EquipCursor(cursorId: number): ()
	if cursorId <= 0 then
		return
	end

	pushToSwitchHistory(cursorId)
	CursorAssetManager.addToCache(cursorId)

	storedCustomCursorId = cursorId
	if customCursorIdValue then
		customCursorIdValue:set(cursorId)
	end

	isUsingCustomCursor:set(true)
	Network.Settings.changeSetting("CustomCursorId", cursorId)
	Network.Settings.changeSetting("UsingCustomCursor", true)

	CursorIFFSystem.updateState()
	applyNeutralCursor()
end

function CursorService:GetHistoryValue(): any
	return cursorHistoryValue
end

function CursorService:GetRadialCursorsValue(): any
	return radialCursorsValue
end

function CursorService:SetIFFEnabled(enabled: boolean): ()
	CursorIFFSystem.setEnabled(enabled)
end

function CursorService:GetCurrentStyle(): number
	if currentCursorStyle then
		return peek(currentCursorStyle)
	end
	return 1
end

function CursorService:IsIFFEnabled(): boolean
	return CursorIFFSystem.isEnabled()
end

function CursorService:SetOverrideCursor(url: string?)
	overrideCursorURL = url
	applyNeutralCursor()
end

function CursorService:Cleanup(): ()
	stopCursorWatchers()
	currentCursorURL = ""
	CursorIFFSystem.cleanup()
	CursorAssetManager.clearCache()

	if radialCleanup then
		radialCleanup()
		radialCleanup = nil
	end
	if radialGui then
		radialGui:Destroy()
		radialGui = nil
	end
	if scope then
		scope:doCleanup()
		scope = nil
	end
end

return CursorService
