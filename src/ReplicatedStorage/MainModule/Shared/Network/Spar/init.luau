--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Core = require(MainModule.Shared.Network.Core)
local Signal = require(MainModule.Shared.Utils.State.Signal)

local RunService = game:GetService("RunService")

local SparNetwork = {}

local selectOptionFired = Signal.new()
local toggleSettingFired = Signal.new()
local startMatchFired = Signal.new()

local simulateRoundWinFired = Signal.new()
local roundTransitionFired = Signal.new()
local suppressDeathScreenFired = Signal.new()
local lobbyJoinFired = Signal.new()
local lobbyStateFired = Signal.new()
local revealArenaFired = Signal.new()
local exitMatchFired = Signal.new()

local onMatchStartClientFired = Signal.new()

local initialized = false

local getPlayerStatsCallback: ((player: Player, username: string) -> any)? = nil
local getMatchHistoryCallback: ((player: Player) -> any)? = nil
local getLeaderboardCallback: ((player: Player, stat: string, scope: string) -> any)? = nil
local viacomCheckAccessCallback: ((player: Player) -> boolean)? = nil
local viacomSearchCallback: ((player: Player, username: string) -> any)? = nil
local viacomGetMatchCallback: ((player: Player, matchId: string) -> any)? = nil
local viacomGetAuditLogCallback: ((player: Player) -> any)? = nil
local viacomExportMatchCallback: ((player: Player, matchId: string) -> any)? = nil

local adminEditStatsCallback: ((player: Player, targetUsername: string, statsData: any) -> boolean)? = nil
local adminInjectMatchCallback: ((player: Player, targetUsername: string, matchData: any) -> boolean)? = nil
local adminCheckAccessCallback: ((player: Player) -> boolean)? = nil

local function registerGetPlayerStats(callback: (player: Player, username: string) -> any): ()
	getPlayerStatsCallback = callback
end

local function registerGetMatchHistory(callback: (player: Player) -> any): ()
	getMatchHistoryCallback = callback
end

local function registerGetLeaderboard(callback: (player: Player, stat: string, scope: string) -> any): ()
	getLeaderboardCallback = callback
end

local function registerViacomCheckAccess(callback: (player: Player) -> boolean): ()
	viacomCheckAccessCallback = callback
end

local function registerViacomSearch(callback: (player: Player, username: string) -> any): ()
	viacomSearchCallback = callback
end

local function registerViacomGetMatch(callback: (player: Player, matchId: string) -> any): ()
	viacomGetMatchCallback = callback
end

local function registerViacomGetAuditLog(callback: (player: Player) -> any): ()
	viacomGetAuditLogCallback = callback
end

local function registerViacomExportMatch(callback: (player: Player, matchId: string) -> any): ()
	viacomExportMatchCallback = callback
end

local function registerAdminEditStats(callback: (player: Player, targetUsername: string, statsData: any) -> boolean): ()
	adminEditStatsCallback = callback
end

local function registerAdminInjectMatch(callback: (player: Player, targetUsername: string, matchData: any) -> boolean): ()
	adminInjectMatchCallback = callback
end

local function registerAdminCheckAccess(callback: (player: Player) -> boolean): ()
	adminCheckAccessCallback = callback
end

local function requestPlayerStats(username: string): any
	local remote = Core.getOrCreateRemoteFunction("Spar_GetPlayerStats")
	local success, result = pcall(remote.InvokeServer, remote, username)
	if success then
		return result
	end
	return nil
end

local function requestMatchHistory(): any
	local remote = Core.getOrCreateRemoteFunction("Spar_GetMatchHistory")
	local success, result = pcall(remote.InvokeServer, remote)
	if success then
		return result
	end
	return {}
end

local function requestLeaderboard(stat: string, scope: string): any
	local remote = Core.getOrCreateRemoteFunction("Spar_GetLeaderboard")
	local success, result = pcall(remote.InvokeServer, remote, stat, scope)
	if success then
		return result
	end
	return {}
end

local function requestViacomCheckAccess(): boolean
	local remote = Core.getOrCreateRemoteFunction("Spar_ViacomCheckAccess")
	local success, result = pcall(remote.InvokeServer, remote)
	if success then
		return result == true
	end
	return false
end

local function requestViacomSearch(username: string): any
	local remote = Core.getOrCreateRemoteFunction("Spar_ViacomSearch")
	local success, result = pcall(remote.InvokeServer, remote, username)
	if success then
		return result
	end
	return nil
end

local function requestViacomGetMatch(matchId: string): any
	local remote = Core.getOrCreateRemoteFunction("Spar_ViacomGetMatch")
	local success, result = pcall(remote.InvokeServer, remote, matchId)
	if success then
		return result
	end
	return nil
end

local function requestViacomGetAuditLog(): any
	local remote = Core.getOrCreateRemoteFunction("Spar_ViacomGetAuditLog")
	local success, result = pcall(remote.InvokeServer, remote)
	if success then
		return result
	end
	return nil
end

local function requestViacomExportMatch(matchId: string): any
	local remote = Core.getOrCreateRemoteFunction("Spar_ViacomExportMatch")
	local success, result = pcall(remote.InvokeServer, remote, matchId)
	if success then
		return result
	end
	return { success = false, error = "Request failed" }
end

local function requestAdminEditStats(targetUsername: string, statsData: any): boolean
	local remote = Core.getOrCreateRemoteFunction("Spar_AdminEditStats")
	local success, result = pcall(remote.InvokeServer, remote, targetUsername, statsData)
	if success then
		return result == true
	end
	return false
end

local function requestAdminInjectMatch(targetUsername: string, matchData: any): boolean
	local remote = Core.getOrCreateRemoteFunction("Spar_AdminInjectMatch")
	local success, result = pcall(remote.InvokeServer, remote, targetUsername, matchData)
	if success then
		return result == true
	end
	return false
end

local function requestAdminCheckAccess(): boolean
	local remote = Core.getOrCreateRemoteFunction("Spar_AdminCheckAccess")
	local success, result = pcall(remote.InvokeServer, remote)
	if success then
		return result == true
	end
	return false
end

local function firePadStatus(player: Player, arenaNumber: number, isOnPad: boolean): ()
	local remote = Core.getOrCreateRemoteEvent("Spar_PadStatus")
	remote:FireClient(player, arenaNumber, isOnPad)
end

local function onPadStatus(callback: (arenaNumber: number, isOnPad: boolean) -> ()): Signal.Connection
	local remote = Core.getOrCreateRemoteEvent("Spar_PadStatus")
	return remote.OnClientEvent:Connect(function(arenaNumber: number, isOnPad: boolean)
		callback(arenaNumber, isOnPad)
	end)
end

local function sendSelectOption(arenaNumber: number, optionType: string, value: string): ()
	local remote = Core.getOrCreateRemoteEvent("Spar_SelectOption")
	remote:FireServer(arenaNumber, optionType, value)
end

local function onSelectOption(callback: (player: Player, arenaNumber: number, optionType: string, value: string) -> ()): Signal.Connection
	return selectOptionFired:Connect(callback)
end

local function sendToggleSetting(arenaNumber: number, settingName: string): ()
	local remote = Core.getOrCreateRemoteEvent("Spar_ToggleSetting")
	remote:FireServer(arenaNumber, settingName)
end

local function onToggleSetting(callback: (player: Player, arenaNumber: number, settingName: string) -> ()): Signal.Connection
	return toggleSettingFired:Connect(callback)
end

local function sendStartMatch(arenaNumber: number, map: string, gun: string, health: string, rounds: string, showVersusGUI: boolean, instantRespawn: boolean, isSoloMode: boolean?, forcefieldDuration: string?): ()
	local remote = Core.getOrCreateRemoteEvent("Spar_StartMatch")
	remote:FireServer(arenaNumber, map, gun, health, rounds, showVersusGUI, instantRespawn, isSoloMode, forcefieldDuration)
end

local function onStartMatch(callback: (
	player: Player,
	arenaNumber: number,
	map: string,
	gun: string,
	health: string,
	rounds: string,
	showVersusGUI: boolean,
	instantRespawn: boolean,
	isSoloMode: boolean?,
	forcefieldDuration: string?
) -> ()): Signal.Connection
	return startMatchFired:Connect(callback)
end

local function sendSimulateRoundWin(arenaNumber: number): ()
	local remote = Core.getOrCreateRemoteEvent("Spar_SimulateRoundWin")
	remote:FireServer(arenaNumber)
end

local function onSimulateRoundWin(callback: (player: Player, arenaNumber: number) -> ()): Signal.Connection
	return simulateRoundWinFired:Connect(callback)
end

local function fireExitMatch(arenaNumber: number): ()
	local remote = Core.getOrCreateRemoteEvent("Spar_ExitMatch")
	remote:FireServer(arenaNumber)
end

local function onExitMatch(callback: (player: Player, arenaNumber: number) -> ()): Signal.Connection
	return exitMatchFired:Connect(callback)
end

local function fireMatchStarted(
	player: Player,
	arenaNumber: number,
	mapName: string,
	gunName: string,
	healthName: string,
	rounds: number,
	showVersusGUI: boolean,
	player1Id: number,
	player2Id: number,
	revealAt: number,
	forcefieldDuration: number
): ()
	local remote = Core.getOrCreateRemoteEvent("Spar_MatchStarted")
	remote:FireClient(player, arenaNumber, mapName, gunName, healthName, rounds, showVersusGUI, player1Id, player2Id, revealAt, forcefieldDuration)
end

local function onMatchStarted(callback: (
	arenaNumber: number,
	mapName: string,
	gunName: string,
	healthName: string,
	rounds: number,
	showVersusGUI: boolean,
	player1Id: number,
	player2Id: number,
	revealAt: number,
	forcefieldDuration: number
) -> ()): Signal.Connection
	return onMatchStartClientFired:Connect(callback)
end

local function fireRoundTransition(
	player: Player,
	arenaNumber: number,
	currentRound: number,
	totalRounds: number,
	roundWinnerUserId: number?,
	isMatchPoint: boolean?,
	isSuddenDeath: boolean?,
	revealAt: number,
	forcefieldDuration: number
): ()
	local remote = Core.getOrCreateRemoteEvent("Spar_RoundTransition")
	remote:FireClient(player, arenaNumber, currentRound, totalRounds, roundWinnerUserId, isMatchPoint, isSuddenDeath, revealAt, forcefieldDuration)
end

local function onRoundTransition(callback: (
	arenaNumber: number,
	currentRound: number,
	totalRounds: number,
	roundWinnerUserId: number?,
	isMatchPoint: boolean?,
	isSuddenDeath: boolean?,
	revealAt: number,
	forcefieldDuration: number
) -> ()): Signal.Connection
	return roundTransitionFired:Connect(callback)
end

local function fireArenaStatus(player: Player, arenaNumber: number, statusType: string, data: string): ()
	local remote = Core.getOrCreateRemoteEvent("Spar_ArenaStatus")
	remote:FireClient(player, arenaNumber, statusType, data)
end

local function broadcastArenaStatus(arenaNumber: number, statusType: string, data: string): ()
	local remote = Core.getOrCreateRemoteEvent("Spar_ArenaStatus")
	remote:FireAllClients(arenaNumber, statusType, data)
end

local function onArenaStatus(callback: (arenaNumber: number, statusType: string, data: string) -> ()): Signal.Connection
	local remote = Core.getOrCreateRemoteEvent("Spar_ArenaStatus")
	return remote.OnClientEvent:Connect(callback)
end

local function fireSuppressDeathScreen(player: Player, suppressed: boolean): ()
	local remote = Core.getOrCreateRemoteEvent("Spar_SuppressDeathScreen")
	remote:FireClient(player, suppressed)
end

local function onSuppressDeathScreen(callback: (suppressed: boolean) -> ()): Signal.Connection
	return suppressDeathScreenFired:Connect(callback)
end

local function broadcastLobbyState(data: any): ()
	local remote = Core.getOrCreateRemoteEvent("Spar_LobbyState")
	remote:FireAllClients(data)
end

local function onLobbyState(callback: (data: any) -> ()): Signal.Connection
	return lobbyStateFired:Connect(callback)
end

local function sendLobbyJoin(arenaNumber: number): ()
	local remote = Core.getOrCreateRemoteEvent("Spar_LobbyJoin")
	remote:FireServer(arenaNumber)
end

local function onLobbyJoin(callback: (player: Player, arenaNumber: number) -> ()): Signal.Connection
	return lobbyJoinFired:Connect(callback)
end

local function sendRevealArena(arenaNumber: number, roundNumber: number): ()
	local remote = Core.getOrCreateRemoteEvent("Spar_RevealArena")
	remote:FireServer(arenaNumber, roundNumber)
end

local function onRevealArena(callback: (player: Player, arenaNumber: number, roundNumber: number) -> ()): Signal.Connection
	return revealArenaFired:Connect(callback)
end

function SparNetwork.init(): ()
	if initialized then
		return
	end
	initialized = true

	if RunService:IsServer() then
		Core.getOrCreateRemoteEvent("Spar_RoundTransition")
		Core.getOrCreateRemoteEvent("Spar_SuppressDeathScreen")

		local selectRemote = Core.getOrCreateRemoteEvent("Spar_SelectOption")
		selectRemote.OnServerEvent:Connect(function(player: Player, arenaNumber: number, optionType: string, value: string)
			selectOptionFired:Fire(player, arenaNumber, optionType, value)
		end)

		local toggleRemote = Core.getOrCreateRemoteEvent("Spar_ToggleSetting")
		toggleRemote.OnServerEvent:Connect(function(player: Player, arenaNumber: number, settingName: string)
			toggleSettingFired:Fire(player, arenaNumber, settingName)
		end)

		local startRemote = Core.getOrCreateRemoteEvent("Spar_StartMatch")
		startRemote.OnServerEvent:Connect(
			function(player: Player, arenaNumber: any, map: any, gun: any, health: any, rounds: any, showVersusGUI: any, instantRespawn: any, isSoloMode: any, forcefieldDuration: any)
				if
					type(arenaNumber) ~= "number"
					or type(map) ~= "string"
					or type(gun) ~= "string"
					or type(health) ~= "string"
					or type(rounds) ~= "string"
					or type(showVersusGUI) ~= "boolean"
					or type(instantRespawn) ~= "boolean"
					or (isSoloMode ~= nil and type(isSoloMode) ~= "boolean")
					or (forcefieldDuration ~= nil and type(forcefieldDuration) ~= "string")
				then
					warn("[SparNetwork] Spar_StartMatch: rejected invalid payload from", player.Name)
					return
				end
				startMatchFired:Fire(player, arenaNumber, map, gun, health, rounds, showVersusGUI, instantRespawn, isSoloMode, forcefieldDuration)
			end
		)

		local simRemote = Core.getOrCreateRemoteEvent("Spar_SimulateRoundWin")
		simRemote.OnServerEvent:Connect(function(player: Player, arenaNumber: number)
			simulateRoundWinFired:Fire(player, arenaNumber)
		end)

		local getStatsRemote = Core.getOrCreateRemoteFunction("Spar_GetPlayerStats")
		getStatsRemote.OnServerInvoke = function(player: Player, username: string)
			if getPlayerStatsCallback then
				return getPlayerStatsCallback(player, username)
			end
			return nil
		end

		local getMatchHistoryRemote = Core.getOrCreateRemoteFunction("Spar_GetMatchHistory")
		getMatchHistoryRemote.OnServerInvoke = function(player: Player)
			if getMatchHistoryCallback then
				return getMatchHistoryCallback(player)
			end
			return {}
		end

		local getLeaderboardRemote = Core.getOrCreateRemoteFunction("Spar_GetLeaderboard")
		getLeaderboardRemote.OnServerInvoke = function(player: Player, stat: string, scope: string)
			if getLeaderboardCallback then
				return getLeaderboardCallback(player, stat, scope)
			end
			return {}
		end

		Core.getOrCreateRemoteEvent("Spar_MatchStarted")
		Core.getOrCreateRemoteEvent("Spar_ArenaStatus")

		Core.getOrCreateRemoteEvent("Spar_LobbyState")
		local lobbyJoinRemote = Core.getOrCreateRemoteEvent("Spar_LobbyJoin")
		lobbyJoinRemote.OnServerEvent:Connect(function(player: Player, arenaNumber: number)
			lobbyJoinFired:Fire(player, arenaNumber)
		end)

		local revealRemote = Core.getOrCreateRemoteEvent("Spar_RevealArena")
		revealRemote.OnServerEvent:Connect(function(player: Player, arenaNumber: number, roundNumber: number)
			revealArenaFired:Fire(player, arenaNumber, roundNumber)
		end)

		local exitMatchRemote = Core.getOrCreateRemoteEvent("Spar_ExitMatch")
		exitMatchRemote.OnServerEvent:Connect(function(player: Player, arenaNumber: number)
			exitMatchFired:Fire(player, arenaNumber)
		end)

		local viacomCheckAccessRemote = Core.getOrCreateRemoteFunction("Spar_ViacomCheckAccess")
		viacomCheckAccessRemote.OnServerInvoke = function(player: Player)
			if viacomCheckAccessCallback then
				return viacomCheckAccessCallback(player)
			end
			return false
		end

		local viacomSearchRemote = Core.getOrCreateRemoteFunction("Spar_ViacomSearch")
		viacomSearchRemote.OnServerInvoke = function(player: Player, username: string)
			if viacomSearchCallback then
				return viacomSearchCallback(player, username)
			end
			return nil
		end

		local viacomGetMatchRemote = Core.getOrCreateRemoteFunction("Spar_ViacomGetMatch")
		viacomGetMatchRemote.OnServerInvoke = function(player: Player, matchId: string)
			if viacomGetMatchCallback then
				return viacomGetMatchCallback(player, matchId)
			end
			return nil
		end

		local viacomGetAuditLogRemote = Core.getOrCreateRemoteFunction("Spar_ViacomGetAuditLog")
		viacomGetAuditLogRemote.OnServerInvoke = function(player: Player)
			if viacomGetAuditLogCallback then
				return viacomGetAuditLogCallback(player)
			end
			return nil
		end

		local viacomExportMatchRemote = Core.getOrCreateRemoteFunction("Spar_ViacomExportMatch")
		viacomExportMatchRemote.OnServerInvoke = function(player: Player, matchId: string)
			if viacomExportMatchCallback then
				return viacomExportMatchCallback(player, matchId)
			end
			return { success = false, error = "Export handler not available" }
		end

		local adminEditStatsRemote = Core.getOrCreateRemoteFunction("Spar_AdminEditStats")
		adminEditStatsRemote.OnServerInvoke = function(player: Player, targetUsername: string, statsData: any)
			if adminEditStatsCallback then
				return adminEditStatsCallback(player, targetUsername, statsData)
			end
			return false
		end

		local adminInjectMatchRemote = Core.getOrCreateRemoteFunction("Spar_AdminInjectMatch")
		adminInjectMatchRemote.OnServerInvoke = function(player: Player, targetUsername: string, matchData: any)
			if adminInjectMatchCallback then
				return adminInjectMatchCallback(player, targetUsername, matchData)
			end
			return false
		end

		local adminCheckAccessRemote = Core.getOrCreateRemoteFunction("Spar_AdminCheckAccess")
		adminCheckAccessRemote.OnServerInvoke = function(player: Player)
			if adminCheckAccessCallback then
				return adminCheckAccessCallback(player)
			end
			return false
		end
	else
		local matchStartedRemote = Core.getOrCreateRemoteEvent("Spar_MatchStarted")
		matchStartedRemote.OnClientEvent:Connect(
			function(
				arenaNumber: number,
				mapName: string,
				gunName: string,
				healthName: string,
				rounds: number,
				showVersusGUI: boolean,
				player1Id: number,
				player2Id: number,
				revealAt: number,
				forcefieldDuration: number
			)
				onMatchStartClientFired:Fire(arenaNumber, mapName, gunName, healthName, rounds, showVersusGUI, player1Id, player2Id, revealAt, forcefieldDuration)
			end
		)

		local roundTransitionRemote = Core.getOrCreateRemoteEvent("Spar_RoundTransition")
		roundTransitionRemote.OnClientEvent:Connect(
			function(
				arenaNumber: number,
				currentRound: number,
				totalRounds: number,
				roundWinnerUserId: number?,
				isMatchPoint: boolean?,
				isSuddenDeath: boolean?,
				revealAt: number,
				forcefieldDuration: number
			)
				roundTransitionFired:Fire(arenaNumber, currentRound, totalRounds, roundWinnerUserId, isMatchPoint, isSuddenDeath, revealAt, forcefieldDuration)
			end
		)

		local suppressDeathScreenRemote = Core.getOrCreateRemoteEvent("Spar_SuppressDeathScreen")
		suppressDeathScreenRemote.OnClientEvent:Connect(function(suppressed: boolean)
			suppressDeathScreenFired:Fire(suppressed)
		end)

		Core.getOrCreateRemoteEvent("Spar_SimulateRoundWin")

		Core.getOrCreateRemoteFunction("Spar_GetPlayerStats")
		Core.getOrCreateRemoteFunction("Spar_GetMatchHistory")
		Core.getOrCreateRemoteFunction("Spar_GetLeaderboard")

		Core.getOrCreateRemoteFunction("Spar_ViacomCheckAccess")
		Core.getOrCreateRemoteFunction("Spar_ViacomSearch")
		Core.getOrCreateRemoteFunction("Spar_ViacomGetMatch")
		Core.getOrCreateRemoteFunction("Spar_ViacomGetAuditLog")
		Core.getOrCreateRemoteFunction("Spar_ViacomExportMatch")

		local lobbyStateRemote = Core.getOrCreateRemoteEvent("Spar_LobbyState")
		lobbyStateRemote.OnClientEvent:Connect(function(data: any)
			lobbyStateFired:Fire(data)
		end)
		Core.getOrCreateRemoteEvent("Spar_LobbyJoin")
		Core.getOrCreateRemoteEvent("Spar_RevealArena")
		Core.getOrCreateRemoteEvent("Spar_ExitMatch")
	end
end

SparNetwork.firePadStatus = firePadStatus
SparNetwork.onPadStatus = onPadStatus
SparNetwork.sendSelectOption = sendSelectOption
SparNetwork.onSelectOption = onSelectOption
SparNetwork.sendToggleSetting = sendToggleSetting
SparNetwork.onToggleSetting = onToggleSetting
SparNetwork.sendStartMatch = sendStartMatch
SparNetwork.onStartMatch = onStartMatch
SparNetwork.sendSimulateRoundWin = sendSimulateRoundWin
SparNetwork.onSimulateRoundWin = onSimulateRoundWin
SparNetwork.fireExitMatch = fireExitMatch
SparNetwork.onExitMatch = onExitMatch
SparNetwork.fireMatchStarted = fireMatchStarted
SparNetwork.onMatchStarted = onMatchStarted
SparNetwork.fireArenaStatus = fireArenaStatus
SparNetwork.broadcastArenaStatus = broadcastArenaStatus
SparNetwork.onArenaStatus = onArenaStatus
SparNetwork.fireRoundTransition = fireRoundTransition
SparNetwork.onRoundTransition = onRoundTransition
SparNetwork.fireSuppressDeathScreen = fireSuppressDeathScreen
SparNetwork.onSuppressDeathScreen = onSuppressDeathScreen
SparNetwork.registerGetPlayerStats = registerGetPlayerStats
SparNetwork.requestPlayerStats = requestPlayerStats
SparNetwork.registerGetMatchHistory = registerGetMatchHistory
SparNetwork.requestMatchHistory = requestMatchHistory
SparNetwork.registerGetLeaderboard = registerGetLeaderboard
SparNetwork.requestLeaderboard = requestLeaderboard
SparNetwork.broadcastLobbyState = broadcastLobbyState
SparNetwork.onLobbyState = onLobbyState
SparNetwork.sendLobbyJoin = sendLobbyJoin
SparNetwork.onLobbyJoin = onLobbyJoin
SparNetwork.sendRevealArena = sendRevealArena
SparNetwork.onRevealArena = onRevealArena

SparNetwork.registerViacomCheckAccess = registerViacomCheckAccess
SparNetwork.requestViacomCheckAccess = requestViacomCheckAccess
SparNetwork.registerViacomSearch = registerViacomSearch
SparNetwork.requestViacomSearch = requestViacomSearch
SparNetwork.registerViacomGetMatch = registerViacomGetMatch
SparNetwork.requestViacomGetMatch = requestViacomGetMatch
SparNetwork.registerViacomGetAuditLog = registerViacomGetAuditLog
SparNetwork.requestViacomGetAuditLog = requestViacomGetAuditLog
SparNetwork.registerViacomExportMatch = registerViacomExportMatch
SparNetwork.requestViacomExportMatch = requestViacomExportMatch

SparNetwork.registerAdminEditStats = registerAdminEditStats
SparNetwork.requestAdminEditStats = requestAdminEditStats
SparNetwork.registerAdminInjectMatch = registerAdminInjectMatch
SparNetwork.requestAdminInjectMatch = requestAdminInjectMatch
SparNetwork.registerAdminCheckAccess = registerAdminCheckAccess
SparNetwork.requestAdminCheckAccess = requestAdminCheckAccess

return SparNetwork
