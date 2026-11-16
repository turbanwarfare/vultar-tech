--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Core = require(MainModule.Shared.Network.Core)
local Signal = require(MainModule.Shared.Utils.State.Signal)

local RunService = game:GetService("RunService")

local AimChamberNetwork = {}

local requestOpenConfigFired = Signal.new()
local applyConfigFired = Signal.new()
local requestStartMatchFired = Signal.new()
local requestEndMatchFired = Signal.new()

local configStateSyncClientFired = Signal.new()
local applyConfigResultClientFired = Signal.new()
local matchStartedClientFired = Signal.new()
local matchTickClientFired = Signal.new()
local matchEndedClientFired = Signal.new()
local npcShotClientFired = Signal.new()
local reportAimFired = Signal.new()

local initialized = false

local REMOTE_NAMES = {
	REQUEST_OPEN_CONFIG = "AimChamber_RequestOpenConfig",
	CONFIG_STATE_SYNC = "AimChamber_ConfigStateSync",
	APPLY_CONFIG = "AimChamber_ApplyConfig",
	APPLY_CONFIG_RESULT = "AimChamber_ApplyConfigResult",
	REQUEST_START_MATCH = "AimChamber_RequestStartMatch",
	REQUEST_END_MATCH = "AimChamber_RequestEndMatch",
	MATCH_STARTED = "AimChamber_MatchStarted",
	MATCH_TICK = "AimChamber_MatchTick",
	MATCH_ENDED = "AimChamber_MatchEnded",
	GET_LEADERBOARD = "AimChamber_GetLeaderboard",
	NPC_SHOT = "AimChamber_NpcShot",
	GET_MATCH_HISTORY = "AimChamber_GetMatchHistory",
	EXPORT_MOVEMENT = "AimChamber_ExportMovement",
	REPORT_AIM = "AimChamber_ReportAim",
}

function AimChamberNetwork.init(): ()
	if initialized then
		return
	end
	initialized = true

	if RunService:IsServer() then
		for key, remoteName in REMOTE_NAMES do
			if key ~= "GET_LEADERBOARD" and key ~= "GET_MATCH_HISTORY" then
				Core.getOrCreateRemoteEvent(remoteName)
			end
		end
		Core.getOrCreateRemoteFunction(REMOTE_NAMES.GET_LEADERBOARD)
		Core.getOrCreateRemoteFunction(REMOTE_NAMES.GET_MATCH_HISTORY)

		local openConfigRemote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.REQUEST_OPEN_CONFIG)
		openConfigRemote.OnServerEvent:Connect(function(player: Player)
			requestOpenConfigFired:Fire(player)
		end)

		local applyRemote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.APPLY_CONFIG)
		applyRemote.OnServerEvent:Connect(function(player: Player, settings: any)
			applyConfigFired:Fire(player, settings)
		end)

		local startRemote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.REQUEST_START_MATCH)
		startRemote.OnServerEvent:Connect(function(player: Player)
			requestStartMatchFired:Fire(player)
		end)

		local endRemote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.REQUEST_END_MATCH)
		endRemote.OnServerEvent:Connect(function(player: Player)
			requestEndMatchFired:Fire(player)
		end)

		Core.getOrCreateRemoteEvent(REMOTE_NAMES.EXPORT_MOVEMENT)

		local reportAimRemote = Core.getOrCreateUnreliableRemoteEvent(REMOTE_NAMES.REPORT_AIM)
		reportAimRemote.OnServerEvent:Connect(function(player: Player, origin: Vector3, direction: Vector3)
			reportAimFired:Fire(player, origin, direction)
		end)
	else
		for key, remoteName in REMOTE_NAMES do
			if key ~= "GET_LEADERBOARD" and key ~= "GET_MATCH_HISTORY" and key ~= "REPORT_AIM" then
				Core.getOrCreateRemoteEvent(remoteName)
			end
		end
		Core.getOrCreateRemoteFunction(REMOTE_NAMES.GET_LEADERBOARD)
		Core.getOrCreateRemoteFunction(REMOTE_NAMES.GET_MATCH_HISTORY)

		local configSyncRemote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.CONFIG_STATE_SYNC)
		configSyncRemote.OnClientEvent:Connect(function(state: any)
			configStateSyncClientFired:Fire(state)
		end)

		local applyResultRemote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.APPLY_CONFIG_RESULT)
		applyResultRemote.OnClientEvent:Connect(function(result: any)
			applyConfigResultClientFired:Fire(result)
		end)

		local matchStartedRemote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.MATCH_STARTED)
		matchStartedRemote.OnClientEvent:Connect(function(payload: any)
			matchStartedClientFired:Fire(payload)
		end)

		local matchTickRemote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.MATCH_TICK)
		matchTickRemote.OnClientEvent:Connect(function(tick: any)
			matchTickClientFired:Fire(tick)
		end)

		local matchEndedRemote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.MATCH_ENDED)
		matchEndedRemote.OnClientEvent:Connect(function(payload: any)
			matchEndedClientFired:Fire(payload)
		end)

		local npcShotRemote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.NPC_SHOT)
		npcShotRemote.OnClientEvent:Connect(function(hitResult: any)
			npcShotClientFired:Fire(hitResult)
		end)

		Core.getOrCreateUnreliableRemoteEvent(REMOTE_NAMES.REPORT_AIM)
	end
end

function AimChamberNetwork.sendRequestOpenConfig(): ()
	local remote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.REQUEST_OPEN_CONFIG)
	remote:FireServer()
end

function AimChamberNetwork.onRequestOpenConfig(callback: (player: Player) -> ()): Signal.Connection
	return requestOpenConfigFired:Connect(callback)
end

function AimChamberNetwork.fireConfigStateSync(player: Player, state: any): ()
	local remote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.CONFIG_STATE_SYNC)
	remote:FireClient(player, state)
end

function AimChamberNetwork.onConfigStateSync(callback: (state: any) -> ()): Signal.Connection
	return configStateSyncClientFired:Connect(callback)
end

function AimChamberNetwork.sendApplyConfig(settings: any): ()
	local remote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.APPLY_CONFIG)
	remote:FireServer(settings)
end

function AimChamberNetwork.onApplyConfig(callback: (player: Player, settings: any) -> ()): Signal.Connection
	return applyConfigFired:Connect(callback)
end

function AimChamberNetwork.fireApplyConfigResult(player: Player, result: any): ()
	local remote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.APPLY_CONFIG_RESULT)
	remote:FireClient(player, result)
end

function AimChamberNetwork.onApplyConfigResult(callback: (result: any) -> ()): Signal.Connection
	return applyConfigResultClientFired:Connect(callback)
end

function AimChamberNetwork.sendRequestStartMatch(): ()
	local remote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.REQUEST_START_MATCH)
	remote:FireServer()
end

function AimChamberNetwork.onRequestStartMatch(callback: (player: Player) -> ()): Signal.Connection
	return requestStartMatchFired:Connect(callback)
end

function AimChamberNetwork.sendEndMatch(): ()
	local remote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.REQUEST_END_MATCH)
	remote:FireServer()
end

function AimChamberNetwork.onRequestEndMatch(callback: (player: Player) -> ()): Signal.Connection
	return requestEndMatchFired:Connect(callback)
end

function AimChamberNetwork.fireMatchStarted(player: Player, payload: any): ()
	local remote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.MATCH_STARTED)
	remote:FireClient(player, payload)
end

function AimChamberNetwork.onMatchStarted(callback: (payload: any) -> ()): Signal.Connection
	return matchStartedClientFired:Connect(callback)
end

function AimChamberNetwork.fireMatchTick(player: Player, tick: any): ()
	local remote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.MATCH_TICK)
	remote:FireClient(player, tick)
end

function AimChamberNetwork.onMatchTick(callback: (tick: any) -> ()): Signal.Connection
	return matchTickClientFired:Connect(callback)
end

function AimChamberNetwork.fireMatchEnded(player: Player, payload: any): ()
	local remote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.MATCH_ENDED)
	remote:FireClient(player, payload)
end

function AimChamberNetwork.onMatchEnded(callback: (payload: any) -> ()): Signal.Connection
	return matchEndedClientFired:Connect(callback)
end

function AimChamberNetwork.fireNpcShot(player: Player, payload: { origin: Vector3, target: Vector3, gunName: string? }): ()
	local remote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.NPC_SHOT)
	remote:FireClient(player, payload)
end

function AimChamberNetwork.onNpcShotReceived(callback: (payload: { origin: Vector3, target: Vector3, gunName: string? }) -> ()): Signal.Connection
	return npcShotClientFired:Connect(callback)
end

function AimChamberNetwork.registerGetLeaderboard(handler: (player: Player, scope: string?) -> any): ()
	local remote = Core.getOrCreateRemoteFunction(REMOTE_NAMES.GET_LEADERBOARD)
	remote.OnServerInvoke = handler
end

function AimChamberNetwork.requestLeaderboard(scope: string?): any
	local remote = Core.getOrCreateRemoteFunction(REMOTE_NAMES.GET_LEADERBOARD)
	local success, result = pcall(remote.InvokeServer, remote, scope)
	if success then
		return result
	end
	return {}
end

function AimChamberNetwork.registerGetMatchHistory(handler: (player: Player) -> any): ()
	local remote = Core.getOrCreateRemoteFunction(REMOTE_NAMES.GET_MATCH_HISTORY)
	remote.OnServerInvoke = handler
end

function AimChamberNetwork.requestMatchHistory(): any
	local remote = Core.getOrCreateRemoteFunction(REMOTE_NAMES.GET_MATCH_HISTORY)
	local success, result = pcall(remote.InvokeServer, remote)
	if success then
		return result
	end
	return {}
end

function AimChamberNetwork.sendExportMovement(chunks: { string }): ()
	local remote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.EXPORT_MOVEMENT)
	remote:FireServer(chunks)
end

function AimChamberNetwork.onExportMovement(callback: (player: Player, chunks: { string }) -> ()): Signal.Connection
	local remote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.EXPORT_MOVEMENT)
	return remote.OnServerEvent:Connect(callback)
end

function AimChamberNetwork.sendAimReport(origin: Vector3, direction: Vector3)
	if Core.isClient() then
		local remote = Core.getOrCreateUnreliableRemoteEvent(REMOTE_NAMES.REPORT_AIM)
		remote:FireServer(origin, direction)
	end
end

function AimChamberNetwork.onAimReport(callback: (Player, Vector3, Vector3) -> ())
	return reportAimFired:Connect(callback)
end

return AimChamberNetwork
