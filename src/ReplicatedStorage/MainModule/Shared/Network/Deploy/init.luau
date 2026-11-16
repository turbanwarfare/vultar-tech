--!strict
--!native
--!optimize 2

local DeployNetwork = {}

local NOOP_CONNECTION = { Disconnect = function() end }
local deployCompleteCallbacks: { () -> () } = {}
local deployCompleteRegistered = false
local deployAlreadyFired = false

function DeployNetwork.requestDeploy(): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Deploy.Request.Fire()
end

function DeployNetwork.onDeployRequested(callback: (player: Player) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Deploy.Request.On(callback)
	return NOOP_CONNECTION
end

function DeployNetwork.sendDeployComplete(player: Player): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Deploy.Complete.Fire(player)
end

function DeployNetwork.onDeployComplete(callback: () -> ()): { Disconnect: () -> () }
	if deployAlreadyFired then
		task.spawn(callback)
		return NOOP_CONNECTION
	end

	table.insert(deployCompleteCallbacks, callback)

	if not deployCompleteRegistered then
		deployCompleteRegistered = true
		local Blink = require(script.Parent.Generated.Client)
		Blink.Deploy.Complete.On(function()
			deployAlreadyFired = true
			for _, cb in deployCompleteCallbacks do
				task.spawn(cb)
			end
		end)
	end

	return {
		Disconnect = function()
			local index = table.find(deployCompleteCallbacks, callback)
			if not index then
				return
			end
			local lastIndex = #deployCompleteCallbacks
			if index < lastIndex then
				deployCompleteCallbacks[index] = deployCompleteCallbacks[lastIndex]
			end
			deployCompleteCallbacks[lastIndex] = nil
		end,
	}
end

function DeployNetwork.init(): () end

return DeployNetwork
