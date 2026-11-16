--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Maps = require(MainModule.Shared.Config.Maps)

local ArenaClient: any = nil
local ArenaTitleClient: any = nil
local ArenaLookupClient: any = nil
local ArenaHistoryClient: any = nil
local ArenaLobbyClient: any = nil
local ArenaLeaderboardClient: any = nil
local ArenaViacomClient: any = nil
local ArenaAdminClient: any = nil

local SparringService = {}
SparringService.Name = "SparringService"

function SparringService:init()
	if not Maps.isSparMode() then
		return
	end

	local Network = require(MainModule.Shared.Network)
	Network.Spar.init()

	ArenaClient = require(script.ArenaClient)
	ArenaTitleClient = require(script.ArenaTitleClient)

	Network.Spar.onSuppressDeathScreen(function(suppressed: boolean)
		local DeathScreenService = require(MainModule.Client.Services.DeathScreenService)
		if suppressed then
			DeathScreenService:Suspend()
			DeathScreenService:Hide()
		else
			DeathScreenService:Resume()
		end
	end)

	ArenaClient.init()

	local lookupSuccess, lookupErr = pcall(function()
		ArenaLookupClient = require(script.ArenaLookupClient)
	end)
	if lookupSuccess and ArenaLookupClient then
		local ok, initErr = pcall(ArenaLookupClient.init)
		if not ok then
			warn("[SparringService] Failed to initialize ArenaLookupClient:", initErr)
		end
	else
		warn("[SparringService] Failed to load ArenaLookupClient:", lookupErr)
	end

	local historySuccess, historyErr = pcall(function()
		ArenaHistoryClient = require(script.ArenaHistoryClient)
	end)
	if historySuccess and ArenaHistoryClient then
		local ok, initErr = pcall(ArenaHistoryClient.init)
		if not ok then
			warn("[SparringService] Failed to initialize ArenaHistoryClient:", initErr)
		end
	else
		warn("[SparringService] Failed to load ArenaHistoryClient:", historyErr)
	end

	local lobbySuccess, lobbyErr = pcall(function()
		ArenaLobbyClient = require(script.ArenaLobbyClient)
	end)
	if lobbySuccess and ArenaLobbyClient then
		local ok, initErr = pcall(ArenaLobbyClient.init)
		if not ok then
			warn("[SparringService] Failed to initialize ArenaLobbyClient:", initErr)
		end
	else
		warn("[SparringService] Failed to load ArenaLobbyClient:", lobbyErr)
	end

	local lbSuccess, lbErr = pcall(function()
		ArenaLeaderboardClient = require(script.ArenaLeaderboardClient)
	end)
	if lbSuccess and ArenaLeaderboardClient then
		local ok, initErr = pcall(ArenaLeaderboardClient.init)
		if not ok then
			warn("[SparringService] Failed to initialize ArenaLeaderboardClient:", initErr)
		end
	else
		warn("[SparringService] Failed to load ArenaLeaderboardClient:", lbErr)
	end

	local viacomSuccess, viacomErr = pcall(function()
		ArenaViacomClient = require(script.ArenaViacomClient)
	end)
	if viacomSuccess and ArenaViacomClient then
		local ok, initErr = pcall(ArenaViacomClient.init)
		if not ok then
			warn("[SparringService] Failed to initialize ArenaViacomClient:", initErr)
		end
	else
		warn("[SparringService] Failed to load ArenaViacomClient:", viacomErr)
	end

	local adminSuccess, adminErr = pcall(function()
		ArenaAdminClient = require(script.ArenaAdminClient)
	end)
	if adminSuccess and ArenaAdminClient then
		local ok, initErr = pcall(ArenaAdminClient.init)
		if not ok then
			warn("[SparringService] Failed to initialize ArenaAdminClient:", initErr)
		end
	else
		warn("[SparringService] Failed to load ArenaAdminClient:", adminErr)
	end
end

function SparringService:start()
	if not Maps.isSparMode() then
		return
	end
	--ArenaClient.enableSoloMode()
	local ok1, err1 = pcall(ArenaClient.start)
	if not ok1 then
		warn("[SparringService] Failed to start ArenaClient:", err1)
	end
	
	local ok2, err2 = pcall(ArenaTitleClient.start)
	if not ok2 then
		warn("[SparringService] Failed to start ArenaTitleClient:", err2)
	end

	if ArenaLookupClient then
		local ok, startErr = pcall(ArenaLookupClient.start)
		if not ok then
			warn("[SparringService] Failed to start ArenaLookupClient:", startErr)
		end
	end

	if ArenaHistoryClient then
		local ok, startErr = pcall(ArenaHistoryClient.start)
		if not ok then
			warn("[SparringService] Failed to start ArenaHistoryClient:", startErr)
		end
	end

	if ArenaLobbyClient then
		local ok, startErr = pcall(ArenaLobbyClient.start)
		if not ok then
			warn("[SparringService] Failed to start ArenaLobbyClient:", startErr)
		end
	end

	if ArenaLeaderboardClient then
		local ok, startErr = pcall(ArenaLeaderboardClient.start)
		if not ok then
			warn("[SparringService] Failed to start ArenaLeaderboardClient:", startErr)
		end
	end

	if ArenaViacomClient then
		local ok, startErr = pcall(ArenaViacomClient.start)
		if not ok then
			warn("[SparringService] Failed to start ArenaViacomClient:", startErr)
		end
	end

	if ArenaAdminClient then
		local ok, startErr = pcall(ArenaAdminClient.start)
		if not ok then
			warn("[SparringService] Failed to start ArenaAdminClient:", startErr)
		end
	end
end

function SparringService:Cleanup()
	if not ArenaClient then
		return
	end
	ArenaClient.cleanup()
	ArenaTitleClient.cleanup()

	if ArenaLookupClient then
		pcall(ArenaLookupClient.cleanup)
	end

	if ArenaHistoryClient then
		pcall(ArenaHistoryClient.cleanup)
	end

	if ArenaLobbyClient then
		pcall(ArenaLobbyClient.cleanup)
	end

	if ArenaLeaderboardClient then
		pcall(ArenaLeaderboardClient.cleanup)
	end

	if ArenaViacomClient then
		pcall(ArenaViacomClient.cleanup)
	end
	if ArenaAdminClient and type(ArenaAdminClient.cleanup) == "function" then
		pcall(ArenaAdminClient.cleanup)
	end
end

return SparringService
