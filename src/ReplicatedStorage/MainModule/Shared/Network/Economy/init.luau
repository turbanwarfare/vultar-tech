--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent
local Core = require(MainModule.Shared.Network.Core)

local EconomyNetwork = {}

local REMOTE_EVENT_BALANCE_UPDATE = "Economy_BalanceUpdate"
local REMOTE_EVENT_PURCHASE_CONFIRMATION = "Economy_PurchaseConfirmation"
local REMOTE_EVENT_MATCH_REWARD = "Economy_MatchReward"
local REMOTE_FUNCTION_GET_BALANCE = "Economy_GetBalance"

export type PurchaseConfirmationData = {
	creditsGranted: number,
	productId: number,
	newBalance: number,
}

export type MatchRewardData = {
	credits: number,
	mapName: string,
	mapReward: number,
	isWinner: boolean,
	attendance: number,
	score: number,
	isPrivate: boolean,
}

local cachedBalance = 0
local lastMatchReward: MatchRewardData? = nil
local lastMatchRewardAt = 0
local matchRewardCallbacks: { (data: MatchRewardData) -> () } = {}
local balanceUpdatedCallbacks: { (balance: number) -> () } = {}
local purchaseConfirmationCallbacks: { (data: PurchaseConfirmationData) -> () } = {}
local clientInitialized = false

function EconomyNetwork.sendBalance(player: Player, balance: number): ()
	if not RunService:IsServer() then
		return
	end
	local remote = Core.getOrCreateRemoteEvent(REMOTE_EVENT_BALANCE_UPDATE)
	remote:FireClient(player, balance)
end

function EconomyNetwork.sendPurchaseConfirmation(player: Player, data: PurchaseConfirmationData): ()
	if not RunService:IsServer() then
		return
	end
	local remote = Core.getOrCreateRemoteEvent(REMOTE_EVENT_PURCHASE_CONFIRMATION)
	remote:FireClient(player, data)
end

function EconomyNetwork.sendMatchReward(player: Player, data: MatchRewardData): ()
	if not RunService:IsServer() then
		return
	end
	local remote = Core.getOrCreateRemoteEvent(REMOTE_EVENT_MATCH_REWARD)
	remote:FireClient(player, data)
end

function EconomyNetwork.onMatchReward(callback: (data: MatchRewardData) -> ()): { Disconnect: () -> () }
	if RunService:IsClient() and not clientInitialized then
		EconomyNetwork.init()
	end

	table.insert(matchRewardCallbacks, callback)
	local isDisconnected = false
	return {
		Disconnect = function()
			if isDisconnected then
				return
			end
			isDisconnected = true
			local index = table.find(matchRewardCallbacks, callback)
			if index then
				table.remove(matchRewardCallbacks, index)
			end
		end,
	}
end

function EconomyNetwork.getRecentMatchReward(maxAgeSeconds: number): MatchRewardData?
	if lastMatchReward and os.clock() - lastMatchRewardAt <= maxAgeSeconds then
		return lastMatchReward
	end
	return nil
end

function EconomyNetwork.onPurchaseConfirmation(
	callback: (data: PurchaseConfirmationData) -> ()
): { Disconnect: () -> () }
	if RunService:IsClient() and not clientInitialized then
		EconomyNetwork.init()
	end

	table.insert(purchaseConfirmationCallbacks, callback)
	local isDisconnected = false
	return {
		Disconnect = function()
			if isDisconnected then
				return
			end
			isDisconnected = true
			local index = table.find(purchaseConfirmationCallbacks, callback)
			if index then
				table.remove(purchaseConfirmationCallbacks, index)
			end
		end,
	}
end

function EconomyNetwork.onBalanceUpdated(callback: (balance: number) -> ()): { Disconnect: () -> () }
	if RunService:IsClient() and not clientInitialized then
		EconomyNetwork.init()
	end

	table.insert(balanceUpdatedCallbacks, callback)
	local isDisconnected = false
	return {
		Disconnect = function()
			if isDisconnected then
				return
			end
			isDisconnected = true
			local index = table.find(balanceUpdatedCallbacks, callback)
			if index then
				table.remove(balanceUpdatedCallbacks, index)
			end
		end,
	}
end

function EconomyNetwork.getCachedBalance(): number
	return cachedBalance
end

function EconomyNetwork.requestBalance(): number
	if RunService:IsServer() then
		return cachedBalance
	end
	local remote = Core.getOrCreateRemoteFunction(REMOTE_FUNCTION_GET_BALANCE)
	local success, result = pcall(function()
		return remote:InvokeServer()
	end)
	if success and typeof(result) == "number" then
		cachedBalance = result
		return result
	end
	return cachedBalance
end

function EconomyNetwork.onGetBalance(callback: (player: Player) -> number): ()
	if not RunService:IsServer() then
		return
	end
	local remote = Core.getOrCreateRemoteFunction(REMOTE_FUNCTION_GET_BALANCE)
	remote.OnServerInvoke = function(player: Player)
		return callback(player)
	end
end

local function ensureServerRemotes(): ()
	if RunService:IsServer() then
		Core.getOrCreateRemoteEvent(REMOTE_EVENT_BALANCE_UPDATE)
		Core.getOrCreateRemoteEvent(REMOTE_EVENT_PURCHASE_CONFIRMATION)
		Core.getOrCreateRemoteEvent(REMOTE_EVENT_MATCH_REWARD)
		Core.getOrCreateRemoteFunction(REMOTE_FUNCTION_GET_BALANCE)
	end
end

ensureServerRemotes()

function EconomyNetwork.init(): ()
	if RunService:IsServer() then
		ensureServerRemotes()
		return
	end

	if RunService:IsClient() and not clientInitialized then
		clientInitialized = true
		local remote = Core.getOrCreateRemoteEvent(REMOTE_EVENT_BALANCE_UPDATE)
		remote.OnClientEvent:Connect(function(newBalance: any)
			if typeof(newBalance) == "number" then
				cachedBalance = newBalance
				for _, cb in balanceUpdatedCallbacks do
					task.spawn(cb, newBalance)
				end
			end
		end)

		local rewardRemote = Core.getOrCreateRemoteEvent(REMOTE_EVENT_MATCH_REWARD)
		rewardRemote.OnClientEvent:Connect(function(data: any)
			if typeof(data) == "table" and typeof(data.credits) == "number" and typeof(data.score) == "number" then
				lastMatchReward = data :: MatchRewardData
				lastMatchRewardAt = os.clock()
				for _, cb in matchRewardCallbacks do
					task.spawn(cb, data :: MatchRewardData)
				end
			end
		end)

		local purchaseRemote = Core.getOrCreateRemoteEvent(REMOTE_EVENT_PURCHASE_CONFIRMATION)
		purchaseRemote.OnClientEvent:Connect(function(data: any)
			if typeof(data) == "table" and typeof(data.creditsGranted) == "number" then
				for _, cb in purchaseConfirmationCallbacks do
					task.spawn(cb, data :: PurchaseConfirmationData)
				end
			end
		end)
	end
end

return EconomyNetwork
