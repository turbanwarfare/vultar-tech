--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local FactionUtils = require(MainModule.Shared.Utils.Game.FactionUtils)

local CursorIFFSystem = {}

export type IFFCallbacks = {
	getCursorVariantURL: (variantIndex: number) -> string,
	setCursor: (url: string) -> (),
	isUsingCustomCursor: () -> boolean,
}

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local factionCache: { [Player]: string } = {}
local localPlayerFaction: string = ""

local RunService = game:GetService("RunService")

local iffEnabled = true
local iffConnection: RBXScriptConnection? = nil

local playerRemovingConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local playerTeamConnections: { [Player]: RBXScriptConnection } = {}

local lastIFFTarget: BasePart? = nil
local lastAppliedURL: string = ""

local callbacks: IFFCallbacks? = nil

local VARIANT_NEUTRAL = 1
local VARIANT_FRIENDLY = 3
local VARIANT_ENEMY = 2

function CursorIFFSystem.getPlayerFaction(targetPlayer: Player): string
	local cached = factionCache[targetPlayer]
	if cached then
		return cached
	end

	local faction = FactionUtils.getPlayerFaction(targetPlayer)
	if faction ~= "" then
		factionCache[targetPlayer] = faction
	end
	return faction
end

function CursorIFFSystem.updateLocalPlayerFaction(): ()
	factionCache[player] = nil
	localPlayerFaction = CursorIFFSystem.getPlayerFaction(player)
end

function CursorIFFSystem.clearFactionCache(): ()
	table.clear(factionCache)
	CursorIFFSystem.updateLocalPlayerFaction()
end

local function applyCursor(variantIndex: number): ()
	if not callbacks then
		return
	end

	local url = callbacks.getCursorVariantURL(variantIndex)
	if url ~= "" and url ~= lastAppliedURL then
		lastAppliedURL = url
		callbacks.setCursor(url)
	end
end

local function onMouseMove(): ()
	if not callbacks or callbacks.isUsingCustomCursor() then
		return
	end

	local target = mouse.Target

	if not target then
		if lastIFFTarget ~= nil then
			lastIFFTarget = nil
			applyCursor(VARIANT_NEUTRAL)
		end
		return
	end

	if target == lastIFFTarget then
		return
	end
	lastIFFTarget = target

	if not target.Parent then
		applyCursor(VARIANT_NEUTRAL)
		return
	end

	local parent = target.Parent
	local humanoid = parent:FindFirstChild("Humanoid")
	if not humanoid then
		local grandparent = parent.Parent
		if grandparent then
			humanoid = grandparent:FindFirstChild("Humanoid")
			if humanoid then
				parent = grandparent
			end
		end
	end

	if not humanoid then
		applyCursor(VARIANT_NEUTRAL)
		return
	end

	local targetPlayer = Players:GetPlayerFromCharacter(parent)
	if not targetPlayer then
		applyCursor(VARIANT_NEUTRAL)
		return
	end

	if targetPlayer == player then
		applyCursor(VARIANT_NEUTRAL)
		return
	end

	local targetFaction = CursorIFFSystem.getPlayerFaction(targetPlayer)

	if targetFaction == "" or localPlayerFaction == "" then
		applyCursor(VARIANT_NEUTRAL)
		return
	end

	if localPlayerFaction == "Neutral" then
		applyCursor(VARIANT_FRIENDLY)
		return
	end

	if targetFaction == "Neutral" then
		applyCursor(VARIANT_FRIENDLY)
		return
	end

	if targetFaction == localPlayerFaction then
		applyCursor(VARIANT_FRIENDLY)
	else
		applyCursor(VARIANT_ENEMY)
	end
end

function CursorIFFSystem.startTracking(): ()
	if iffConnection then
		return
	end

	lastIFFTarget = nil
	lastAppliedURL = ""
	iffConnection = RunService.RenderStepped:Connect(onMouseMove)
	applyCursor(VARIANT_NEUTRAL)
end

function CursorIFFSystem.stopTracking(): ()
	if iffConnection then
		iffConnection:Disconnect()
		iffConnection = nil
	end

	lastAppliedURL = ""

	if callbacks and callbacks.isUsingCustomCursor() then
		return
	end

	applyCursor(VARIANT_NEUTRAL)
end

function CursorIFFSystem.updateState(): ()
	if not callbacks then
		return
	end

	if iffEnabled and not callbacks.isUsingCustomCursor() then
		CursorIFFSystem.startTracking()
	else
		CursorIFFSystem.stopTracking()
	end
end

function CursorIFFSystem.setupCharacterTracking(_character: Model): ()
	lastIFFTarget = nil
end

local function setupPlayerTeamListener(targetPlayer: Player): ()
	if playerTeamConnections[targetPlayer] then
		return
	end

	playerTeamConnections[targetPlayer] = targetPlayer:GetPropertyChangedSignal("Team"):Connect(function()
		factionCache[targetPlayer] = nil
		lastIFFTarget = nil
		if targetPlayer == player then
			CursorIFFSystem.updateLocalPlayerFaction()
			CursorIFFSystem.updateState()
		end
	end)
end

function CursorIFFSystem.connect(iffCallbacks: IFFCallbacks): ()
	callbacks = iffCallbacks

	CursorIFFSystem.updateLocalPlayerFaction()

	setupPlayerTeamListener(player)
	for _, targetPlayer in Players:GetPlayers() do
		if targetPlayer ~= player then
			setupPlayerTeamListener(targetPlayer)
		end
	end

	playerAddedConnection = Players.PlayerAdded:Connect(function(newPlayer)
		setupPlayerTeamListener(newPlayer)
	end)

	playerRemovingConnection = Players.PlayerRemoving:Connect(function(leavingPlayer)
		factionCache[leavingPlayer] = nil
		local conn = playerTeamConnections[leavingPlayer]
		if conn then
			conn:Disconnect()
			playerTeamConnections[leavingPlayer] = nil
		end
	end)

	CursorIFFSystem.updateState()
end

function CursorIFFSystem.setEnabled(enabled: boolean): ()
	iffEnabled = enabled
	CursorIFFSystem.updateState()
end

function CursorIFFSystem.isEnabled(): boolean
	return iffEnabled
end

function CursorIFFSystem.forceRefresh(): ()
	lastIFFTarget = nil
	lastAppliedURL = ""
end

function CursorIFFSystem.cleanup(): ()
	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	if playerAddedConnection then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end
	if iffConnection then
		iffConnection:Disconnect()
		iffConnection = nil
	end

	for _, conn in playerTeamConnections do
		conn:Disconnect()
	end
	table.clear(playerTeamConnections)

	table.clear(factionCache)
	callbacks = nil
	lastIFFTarget = nil
	lastAppliedURL = ""
end

return CursorIFFSystem
