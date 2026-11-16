--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent
local Core = require(MainModule.Shared.Network.Core)
local CratesConfig = require(MainModule.Shared.Config.Cosmetics.Crates)

export type RollResult = CratesConfig.RollResult
export type CrateOpenResponse = CratesConfig.CrateOpenResponse

local CrateNetwork = {}

local REMOTE_FUNCTION_OPEN_CRATE = "Crate_Open"

function CrateNetwork.openCrate(crateId: string, amount: number): CrateOpenResponse
	if RunService:IsServer() then
		return {
			success = false,
			error = "Cannot open crate from server directly via CrateNetwork",
		}
	end

	local remote = Core.getOrCreateRemoteFunction(REMOTE_FUNCTION_OPEN_CRATE)
	local success, result = pcall(function()
		return remote:InvokeServer(crateId, amount)
	end)

	if success and type(result) == "table" then
		return result :: CrateOpenResponse
	end

	return {
		success = false,
		error = if not success then tostring(result) else "Invalid response from server",
	}
end

return CrateNetwork
