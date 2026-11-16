--!strict
--!native
--!optimize 2

local Types = require(script.Types)

export type LogSubmitData = Types.LogSubmitData
export type LogSubmitResult = Types.LogSubmitResult
export type LogPlayer = Types.LogPlayer

local NOOP_CONNECTION = { Disconnect = function() end }

local LoggingNetwork = {}

function LoggingNetwork.submitLog(playerUsernames: { string }): LogSubmitResult
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Logging.SubmitLog.Invoke, playerUsernames)
	if success and result then
		return result
	end
	return { success = false, error = "Network error" }
end

function LoggingNetwork.onSubmitLog(callback: (player: Player, playerUsernames: { string }) -> LogSubmitResult): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Logging.SubmitLog.On(callback)
	return NOOP_CONNECTION
end

function LoggingNetwork.getLogPlayers(): { LogPlayer }
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Logging.GetPlayers.Invoke)
	if success and result then
		return result
	end
	return {}
end

function LoggingNetwork.onGetLogPlayers(callback: (player: Player) -> { LogPlayer }): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Logging.GetPlayers.On(callback)
	return NOOP_CONNECTION
end

function LoggingNetwork.init(): ()
end

return LoggingNetwork
