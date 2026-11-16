--!strict
--!native
--!optimize 2

local ProgressNetwork = {}
local NOOP_CONNECTION = { Disconnect = function() end }

function ProgressNetwork.sendProgress(player: Player, data: number | string): ()
	local Blink = require(script.Parent.Generated.Server)
	local progressData
	if type(data) == "number" then
		progressData = { Type = "Number", value = data }
	else
		progressData = { Type = "Text", value = data }
	end
	Blink.Progress.Update.Fire(player, progressData)
end

function ProgressNetwork.onProgressReceived(callback: (data: number | string) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Progress.Update.On(function(progressData: any)
		callback(progressData.value)
	end)
	return NOOP_CONNECTION
end

function ProgressNetwork.init(): ()
end

return ProgressNetwork
