--!strict
--!native
--!optimize 2

local Types = require(script.Types)

export type TeamChoice = Types.TeamChoice
export type TeamChangeResult = Types.TeamChangeResult

local NOOP_CONNECTION = { Disconnect = function() end }

local TeamsNetwork = {}

function TeamsNetwork.changeTeam(choice: TeamChoice): TeamChangeResult
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Teams.ChangeTeam.Invoke, choice)
	if success and result then
		return result
	end
	return { success = false, error = "Network error" }
end

function TeamsNetwork.onChangeTeam(callback: (player: Player, choice: TeamChoice) -> TeamChangeResult): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Teams.ChangeTeam.On(callback)
	return NOOP_CONNECTION
end

function TeamsNetwork.getCurrentTeam(): string?
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Teams.GetCurrentTeam.Invoke)
	if success then
		return result
	end
	return nil
end

function TeamsNetwork.onGetCurrentTeam(callback: (player: Player) -> string?): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Teams.GetCurrentTeam.On(callback)
	return NOOP_CONNECTION
end

function TeamsNetwork.init(): ()
end

return TeamsNetwork
