--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local PolicyService = game:GetService("PolicyService")

local MainModule = script.Parent.Parent.Parent
local Core = require(MainModule.Shared.Network.Core)
local CratesConfig = require(MainModule.Shared.Config.Cosmetics.Crates)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

type RollResult = CratesConfig.RollResult
type CrateOpenResponse = CratesConfig.CrateOpenResponse

local CratesService = {}
CratesService.Name = "CratesService"

local REMOTE_FUNCTION_OPEN_CRATE = "Crate_Open"
local OPEN_COOLDOWN = 1
local SUSPICIOUS_WINDOW = 60
local SPAM_THRESHOLD = 5

local getEconomyService = LazyService.create(MainModule, "EconomyService")
local getCosmeticService = LazyService.create(MainModule, "CosmeticService")
local getJoinLogService = LazyService.create(MainModule, "JoinLogService")

local playerOpeningLocks: { [number]: boolean } = {}
local lastOpenTimes: { [number]: number } = {}
local paidRandomItemsRestricted: { [number]: boolean } = {}
type SuspiciousEntry = { count: number, windowStart: number, logged: boolean }

local suspiciousCounts: { [string]: SuspiciousEntry } = {}
local connections: { RBXScriptConnection } = {}
local isInitialized = false

local function flagSuspicious(player: Player, reason: string, threshold: number): ()
	local key = `{player.UserId}:{reason}`
	local now = os.clock()
	local existing = suspiciousCounts[key]
	local entry: SuspiciousEntry = if existing and now - existing.windowStart < SUSPICIOUS_WINDOW
		then existing
		else { count = 0, windowStart = now, logged = false }
	suspiciousCounts[key] = entry

	entry.count += 1
	if entry.logged or entry.count < threshold then
		return
	end
	entry.logged = true

	local joinLogService = getJoinLogService()
	if joinLogService then
		local countText = if threshold > 1 then ` ({entry.count}x in {SUSPICIOUS_WINDOW}s)` else ""
		joinLogService.LogEconomyAlert("SUSPICIOUS CRATE REQUEST", player.UserId, reason .. countText)
	end
end

local function arePaidRandomItemsRestricted(player: Player): (boolean, boolean)
	local cached = paidRandomItemsRestricted[player.UserId]
	if cached ~= nil then
		return cached, true
	end

	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if not ok or typeof(info) ~= "table" or typeof(info.ArePaidRandomItemsRestricted) ~= "boolean" then
		return true, false
	end

	paidRandomItemsRestricted[player.UserId] = info.ArePaidRandomItemsRestricted
	return info.ArePaidRandomItemsRestricted, true
end

local function handleOpenCrate(player: Player, crateId: any, requestedAmount: any): CrateOpenResponse
	if typeof(crateId) ~= "string" or typeof(requestedAmount) ~= "number" then
		flagSuspicious(player, "sent malformed crate request", 1)
		return {
			success = false,
			error = "Invalid request arguments",
		}
	end

	local amount = math.floor(requestedAmount)
	if not table.find(CratesConfig.QUANTITY_OPTIONS, amount) then
		flagSuspicious(player, `asked to open {requestedAmount} crates at once`, 1)
		return {
			success = false,
			error = "Invalid crate opening quantity",
		}
	end

	local crate = CratesConfig.getCrateById(crateId)
	if not crate or crate.visible == false then
		flagSuspicious(player, `asked for unknown or hidden crate "{string.sub(crateId, 1, 40)}"`, 1)
		return {
			success = false,
			error = "Crate is currently unavailable",
		}
	end

	if #crate.drops == 0 or #crate.odds == 0 then
		return {
			success = false,
			error = "Crate contains no drops",
		}
	end

	local userId = player.UserId
	if playerOpeningLocks[userId] then
		flagSuspicious(player, "spamming crate opens", SPAM_THRESHOLD)
		return {
			success = false,
			error = "Another crate opening is already in progress",
		}
	end

	local now = os.clock()
	local lastOpen = lastOpenTimes[userId]
	if lastOpen and now - lastOpen < OPEN_COOLDOWN then
		flagSuspicious(player, "spamming crate opens", SPAM_THRESHOLD)
		return {
			success = false,
			error = "Please wait a moment before opening another crate",
		}
	end

	playerOpeningLocks[userId] = true
	lastOpenTimes[userId] = now

	local success, response = pcall(function(): CrateOpenResponse
		local restricted, verified = arePaidRandomItemsRestricted(player)
		if restricted then
			if verified then
				flagSuspicious(player, "tried to open crates while blocked in their region", 1)
			end
			return {
				success = false,
				error = "Crates are not available in your region",
			}
		end

		local economyService = getEconomyService()
		local cosmeticService = getCosmeticService()
		if not economyService or not cosmeticService then
			return {
				success = false,
				error = "Crates are temporarily unavailable",
			}
		end

		local totalCost = crate.price * amount
		if economyService:GetBalance(player) < totalCost then
			return {
				success = false,
				error = "Insufficient credits to open crates",
			}
		end

		local ownedLookup: { [string]: boolean } = {}
		for _, items in cosmeticService:GetPlayerState(player).owned do
			for _, itemId in items do
				ownedLookup[itemId] = true
			end
		end

		local results: { RollResult } = {}
		local totalRefund = 0
		local newItemsToUnlock: { string } = {}
		local rng = Random.new()

		for _ = 1, amount do
			local rollPercent = rng:NextNumber(0, 100)
			local chosenRarity: CratesConfig.CrateRarity = crate.odds[1].rarity
			local cumulative = 0

			for _, oddEntry in crate.odds do
				cumulative += oddEntry.chance
				if rollPercent <= cumulative then
					chosenRarity = oddEntry.rarity
					break
				end
			end

			local dropsInRarity = CratesConfig.getDropsByRarity(crate, chosenRarity)
			local chosenDrop: CratesConfig.CrateDrop = if #dropsInRarity > 0
				then dropsInRarity[rng:NextInteger(1, #dropsInRarity)]
				else crate.drops[rng:NextInteger(1, #crate.drops)]

			local baseSkinId = if chosenDrop.category == "GunSkin" then chosenDrop.skinId or string.match(chosenDrop.id, "^[^:]+") else nil
			local unlockIds: { string } = chosenDrop.unlocks or { chosenDrop.id }
			local missingUnlocks: { string } = {}
			if not (baseSkinId and ownedLookup[baseSkinId]) then
				for _, itemId in unlockIds do
					if not ownedLookup[itemId] then
						table.insert(missingUnlocks, itemId)
					end
				end
			end
			local isDuplicate = #missingUnlocks == 0

			local refundAmount = 0
			if isDuplicate then
				refundAmount = math.floor(crate.price * (1 - CratesConfig.DUPLICATE_REFUND_PENALTY))
				totalRefund += refundAmount
			else
				for _, itemId in missingUnlocks do
					ownedLookup[itemId] = true
					table.insert(newItemsToUnlock, itemId)
				end
			end

			table.insert(results, {
				category = chosenDrop.category,
				id = chosenDrop.id,
				skinId = chosenDrop.skinId,
				weaponName = chosenDrop.weaponName,
				packName = chosenDrop.packName,
				rarity = chosenDrop.rarity,
				isDuplicate = isDuplicate,
				refundAmount = if isDuplicate then refundAmount else nil,
			})
		end

		local committed, commitError = economyService:CommitCrateOpen(player, {
			txId = HttpService:GenerateGUID(false),
			crateId = crate.id,
			amount = amount,
			cost = totalCost,
			refund = totalRefund,
			unlocks = newItemsToUnlock,
		})
		if not committed then
			return {
				success = false,
				error = if commitError == "insufficient" then "Insufficient credits to open crates" else "Crates are temporarily unavailable",
			}
		end

		if #newItemsToUnlock > 0 then
			cosmeticService:ApplyUnlocks(player, newItemsToUnlock)
		end

		local logged, logError = pcall(function()
			local joinLogService = getJoinLogService()
			if joinLogService then
				joinLogService.LogCrateOpen(player, crate.name, totalCost, totalRefund, results)
				for _, result in results do
					if result.rarity == "Mythic" then
						joinLogService.LogJackpot(player, crate.name, result)
					end
				end
			end
		end)
		if not logged then
			warn(`[CratesService] Crate log failed for {player.Name}: {logError}`)
		end

		return {
			success = true,
			results = results,
			totalCost = totalCost,
			totalRefund = totalRefund,
			newBalance = economyService:GetBalance(player),
		}
	end)

	playerOpeningLocks[userId] = nil

	if not success then
		warn(`[CratesService] Error handling crate opening for player {player.Name}: {response}`)
		return {
			success = false,
			error = "An error occurred while opening crate. Please try again.",
		}
	end

	return response
end

function CratesService:init(): ()
	if isInitialized then
		return
	end
	isInitialized = true

	local openRemote = Core.getOrCreateRemoteFunction(REMOTE_FUNCTION_OPEN_CRATE)
	openRemote.OnServerInvoke = handleOpenCrate
end

function CratesService:start(): ()
	if not isInitialized then
		self:init()
	end

	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			playerOpeningLocks[player.UserId] = nil
			lastOpenTimes[player.UserId] = nil
			paidRandomItemsRestricted[player.UserId] = nil
			local prefix = `{player.UserId}:`
			for key in suspiciousCounts do
				if string.sub(key, 1, #prefix) == prefix then
					suspiciousCounts[key] = nil
				end
			end
		end)
	)
end

function CratesService:Cleanup(): ()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	table.clear(playerOpeningLocks)
	table.clear(lastOpenTimes)
	table.clear(paidRandomItemsRestricted)
	isInitialized = false
end

return CratesService
