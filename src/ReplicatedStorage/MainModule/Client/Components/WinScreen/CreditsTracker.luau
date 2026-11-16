--!native
--!optimize 2

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")

local MainModule = script.Parent.Parent.Parent.Parent
local Types = require(MainModule.Shared.Types)
local Network = require(MainModule.Shared.Network)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

local RECENT_REWARD_SECONDS = 120

local localPlayer = Players.LocalPlayer

export type CreditsTracker = {
	Balance: any,
	Earned: any,
	Reward: any,
	Purchasable: any,
}

local function CreditsTracker(scope: FusionScope): CreditsTracker
	local balance = scope:Value(Network.Economy.getCachedBalance())
	local reward = scope:Value(Network.Economy.getRecentMatchReward(RECENT_REWARD_SECONDS))
	local purchasable = scope:Value(false)
	local alive = true

	local balanceConnection = Network.Economy.onBalanceUpdated(function(newBalance: number)
		balance:set(newBalance)
	end)
	local rewardConnection = Network.Economy.onMatchReward(function(data: Network.MatchRewardData)
		reward:set(data)
	end)
	table.insert(scope, function()
		alive = false
		balanceConnection:Disconnect()
		rewardConnection:Disconnect()
	end)

	task.spawn(function()
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(localPlayer)
		end)
		if alive and ok and typeof(info) == "table" and info.ArePaidRandomItemsRestricted == false then
			purchasable:set(true)
		end
	end)

	local earned = scope:Computed(function(use: FusionUseFn)
		local data = use(reward)
		return if data then data.credits else 0
	end)

	return { Balance = balance, Earned = earned, Reward = reward, Purchasable = purchasable }
end

return CreditsTracker
