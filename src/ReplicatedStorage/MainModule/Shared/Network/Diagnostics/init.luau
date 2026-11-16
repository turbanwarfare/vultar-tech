--!strict
--!native
--!optimize 2

local Types = require(script.Types)

export type DiagnosticDump = Types.DiagnosticDump
export type DumpMetadata = Types.DumpMetadata

local DiagnosticsNetwork = {}

local NOOP_CONNECTION = { Disconnect = function() end }

function DiagnosticsNetwork.requestDump(targetPlayer: Player): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Diagnostics.RequestDump.Fire(targetPlayer)
end

function DiagnosticsNetwork.onDumpRequested(callback: () -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Diagnostics.RequestDump.On(callback)
	return NOOP_CONNECTION
end

function DiagnosticsNetwork.submitDump(dump: DiagnosticDump): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Diagnostics.SubmitDump.Fire(dump)
end

function DiagnosticsNetwork.onDumpSubmitted(callback: (player: Player, dump: DiagnosticDump) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Diagnostics.SubmitDump.On(callback)
	return NOOP_CONNECTION
end

function DiagnosticsNetwork.init(): ()
end

return DiagnosticsNetwork
