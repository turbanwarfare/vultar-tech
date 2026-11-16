--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")

local MainModule = script.Parent.Parent.Parent
local Core = require(MainModule.Shared.Network.Core)
local StoreHubRedirects = require(MainModule.Shared.Config.StoreHubRedirects)

local Network = require(MainModule.Shared.Network)
local CosmeticConfig = require(MainModule.Shared.Config.Cosmetics)
local Bundles = require(MainModule.Shared.Config.Cosmetics.Bundles)
local Packs = require(MainModule.Shared.Config.Cosmetics.Packs)
local Signal = require(MainModule.Shared.Utils.State.Signal)
local RankCache = require(MainModule.Server.Cache.RankCache)
local PlayerDataStore = require(script.Parent.SettingsService.PlayerDataStore)
local EventCosmeticsAPI = require(script.EventCosmeticsAPI)

type Category = CosmeticConfig.Category
type ItemConfig = CosmeticConfig.ItemConfig
type ResolvedCosmetic = CosmeticConfig.ResolvedCosmetic
type OwnedCosmetics = CosmeticConfig.OwnedCosmetics
type CosmeticState = Network.CosmeticState
type EquippedCosmetics = Network.EquippedCosmetics

local CosmeticService = {}
CosmeticService.Name = "CosmeticService"

local playerStates: { [number]: CosmeticState } = {}
local playerOwnershipCache: { [number]: { [number]: boolean } } = {}
local playerBundleCache: { [number]: { [string]: boolean } } = {}
local playerPackCache: { [number]: { [string]: boolean } } = {}
local playerOwnedLookup: { [number]: { [Category]: { [string]: boolean } } } = {}
local externalUnlocks: { [number]: { [string]: Category } } = {}
local playerOwnershipReady: { [number]: boolean } = {}
local isInitialized = false
local connections: { RBXScriptConnection } = {}

local cosmeticChanged = Signal.new()

local OWNERSHIP_CHECK_TIMEOUT = 5
local BATCH_SIZE = 10
local BATCH_DELAY = 0.1
local MAX_CONCURRENT_CHECKS = 30
local activeCheckCount = 0

local function checkGamepassOwnershipDirect(userId: number, gamepassId: number): boolean
	if gamepassId <= 0 then
		return false
	end

	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(userId, gamepassId)
	end)

	return success == true and owns == true
end

local function getOrCreateUserCache(userId: number): { [number]: boolean }
	local userCache = playerOwnershipCache[userId]
	if not userCache then
		userCache = {}
		playerOwnershipCache[userId] = userCache
	end
	return userCache
end

local function checkGamepassOwnership(player: Player, gamepassId: number): boolean
	if gamepassId <= 0 then
		return false
	end

	if CosmeticConfig.hasFullAccess(player) then
		return true
	end

	local userId = player.UserId
	local userCache = getOrCreateUserCache(userId)

	local cached = userCache[gamepassId]
	if cached ~= nil then
		return cached
	end

	local owns = checkGamepassOwnershipDirect(userId, gamepassId)
	userCache[gamepassId] = owns
	return owns
end

local function prefetchAllGamepasses(player: Player): ()
	local userId = player.UserId
	if CosmeticConfig.hasFullAccess(player) then
		playerOwnershipReady[userId] = true
		return
	end

	local userCache = getOrCreateUserCache(userId)

	local gamepassIds: { number } = {}
	local seen: { [number]: boolean } = {}

	for _, item in CosmeticConfig.Items do
		for _, gpId in item.gamepassIds do
			if gpId > 0 and not seen[gpId] then
				seen[gpId] = true
				table.insert(gamepassIds, gpId)
			end
		end
		if item.purchaseGamepassId and item.purchaseGamepassId > 0 and not seen[item.purchaseGamepassId] then
			seen[item.purchaseGamepassId] = true
			table.insert(gamepassIds, item.purchaseGamepassId)
		end
	end

	for _, bundle in Bundles.getAllBundles() do
		if bundle.gamepassId > 0 and not seen[bundle.gamepassId] then
			seen[bundle.gamepassId] = true
			table.insert(gamepassIds, bundle.gamepassId)
		end
	end

	for _, pack in Packs.getAllPacks() do
		if pack.gamepassId > 0 and not seen[pack.gamepassId] then
			seen[pack.gamepassId] = true
			table.insert(gamepassIds, pack.gamepassId)
		end
	end

	for i = 1, #gamepassIds, BATCH_SIZE do
		if not Players:FindFirstChild(player.Name) then
			return
		end

		local batchEnd = math.min(i + BATCH_SIZE - 1, #gamepassIds)
		local pendingCount = 0
		local completedCount = 0

		for j = i, batchEnd do
			local gpId = gamepassIds[j]
			if userCache[gpId] == nil then
				while activeCheckCount >= MAX_CONCURRENT_CHECKS do
					task.wait()
				end
				pendingCount += 1
				activeCheckCount += 1
				task.spawn(function()
					local owns = checkGamepassOwnershipDirect(userId, gpId)
					userCache[gpId] = owns
					completedCount += 1
					activeCheckCount -= 1
				end)
			end
		end

		if pendingCount > 0 then
			local startTime = os.clock()
			while completedCount < pendingCount and (os.clock() - startTime) < OWNERSHIP_CHECK_TIMEOUT do
				task.wait()
			end
		end

		if i + BATCH_SIZE <= #gamepassIds then
			task.wait(BATCH_DELAY)
		end
	end

	playerOwnershipReady[userId] = true
end

local function isDefaultItem(itemId: string): boolean
	return itemId == "Default" or itemId == "Default_PlayerCard" or itemId == "Default_GunSkin" or itemId == "Default_ChatGradient"
end

local function checkOwnershipForItem(player: Player, item: ItemConfig): boolean
	if isDefaultItem(item.id) then
		return true
	end

	if CosmeticConfig.hasFullAccess(player) then
		return true
	end

	if item.customCheck then
		local success, result = pcall(item.customCheck, player)
		if success and result == true then
			return true
		end
	end

	if #item.gamepassIds == 0 then
		return false
	end

	if RankCache.isInGroup(player, CosmeticConfig.MainGroupId, CosmeticConfig.GeneralRank) then
		return true
	end

	for _, gamepassId in item.gamepassIds do
		if checkGamepassOwnership(player, gamepassId) then
			return true
		end
	end

	return false
end

local function checkBundleOwnership(player: Player, bundle: Bundles.BundleConfig): boolean
	if bundle.gamepassId <= 0 then
		return false
	end

	local userId = player.UserId
	local bundleCache = playerBundleCache[userId]
	if bundleCache and bundleCache[bundle.id] ~= nil then
		return bundleCache[bundle.id]
	end

	if not bundleCache then
		bundleCache = {}
		playerBundleCache[userId] = bundleCache
	end

	local owns = checkGamepassOwnership(player, bundle.gamepassId)
	bundleCache[bundle.id] = owns
	return owns
end

local function getOwnedBundleItems(player: Player): { [Category]: { string } }
	local bundleItems: { [Category]: { string } } = {
		PlayerCard = {},
		GunSkin = {},
		ChatGradient = {},
	}

	for _, bundle in Bundles.getAllBundles() do
		if checkBundleOwnership(player, bundle) then
			for _, item in bundle.items do
				table.insert(bundleItems[item.category], item.id)
			end
		end
	end

	return bundleItems
end

local function checkPackOwnership(player: Player, pack: Packs.PackConfig): boolean
	if pack.gamepassId <= 0 then
		return false
	end

	local userId = player.UserId
	local packCache = playerPackCache[userId]
	if packCache and packCache[pack.id] ~= nil then
		return packCache[pack.id]
	end

	if not packCache then
		packCache = {}
		playerPackCache[userId] = packCache
	end

	local owns = checkGamepassOwnership(player, pack.gamepassId)
	packCache[pack.id] = owns
	return owns
end

local function getOwnedPackItems(player: Player): { [Category]: { string } }
	local packItems: { [Category]: { string } } = {
		PlayerCard = {},
		GunSkin = {},
		ChatGradient = {},
	}

	for _, pack in Packs.getAllPacks() do
		if checkPackOwnership(player, pack) then
			for _, item in pack.items do
				table.insert(packItems[item.category], item.id)
			end
		end
	end

	return packItems
end

local function getEventCosmetics(player: Player): { [Category]: { string } }
	local eventItems: { [Category]: { string } } = {
		PlayerCard = {},
		GunSkin = {},
		ChatGradient = {},
	}

	local eventData = EventCosmeticsAPI.getEventCosmetics(player.UserId)
	if not eventData or not eventData.halloween then
		return eventItems
	end

	local halloween = eventData.halloween

	if halloween.leaderboardCard == true then
		table.insert(eventItems["PlayerCard"], "Halloween_PlayerCard")
	end

	if halloween.gunSkin == true then
		table.insert(eventItems["GunSkin"], "Halloween")
	end

	return eventItems
end

local function buildOwnedLookup(userId: number, owned: OwnedCosmetics): ()
	local lookup: { [Category]: { [string]: boolean } } = {
		PlayerCard = {},
		GunSkin = {},
		ChatGradient = {},
	}

	for category, items in owned do
		for _, itemId in items do
			lookup[category :: Category][itemId] = true
		end
	end

	playerOwnedLookup[userId] = lookup
end

local function isItemOwned(userId: number, category: Category, itemId: string): boolean
	local lookup = playerOwnedLookup[userId]
	if not lookup then
		return false
	end
	local categoryLookup = lookup[category]
	if not categoryLookup then
		return false
	end
	return categoryLookup[itemId] == true
end

local CATEGORY_TO_KEY: { [Category]: string } = {
	PlayerCard = "PlayerCard",
	ChatGradient = "ChatGradient",
}

local GUN_SKIN_SEPARATOR = ":"

local function parseGunSkinId(itemId: string): (string, string?)
	local sepPos = string.find(itemId, GUN_SKIN_SEPARATOR, 1, true)
	if sepPos then
		return string.sub(itemId, 1, sepPos - 1), string.sub(itemId, sepPos + 1)
	end
	return itemId, nil
end

local function getPersistedUnlocks(player: Player): { string }
	local data = PlayerDataStore.get(player)
	local cosmetics = data and data.Cosmetics
	local unlocked = cosmetics and (cosmetics :: any).Unlocked
	if type(unlocked) == "table" then
		return unlocked
	end
	return {}
end

local function getOwnedCosmetics(player: Player): OwnedCosmetics
	local userId = player.UserId

	prefetchAllGamepasses(player)

	local owned: OwnedCosmetics = {
		PlayerCard = {},
		GunSkin = {},
		ChatGradient = {},
	}
	local seen: { [Category]: { [string]: boolean } } = {
		PlayerCard = {},
		GunSkin = {},
		ChatGradient = {},
	}

	for _, item in CosmeticConfig.Items do
		if checkOwnershipForItem(player, item) then
			table.insert(owned[item.category], item.id)
			seen[item.category][item.id] = true
		end
	end

	local bundleItems = getOwnedBundleItems(player)
	for category, items in bundleItems do
		for _, itemId in items do
			if not seen[category :: Category][itemId] then
				table.insert(owned[category :: Category], itemId)
				seen[category :: Category][itemId] = true
			end
		end
	end

	local packItems = getOwnedPackItems(player)
	for category, items in packItems do
		for _, itemId in items do
			if not seen[category :: Category][itemId] then
				table.insert(owned[category :: Category], itemId)
				seen[category :: Category][itemId] = true
			end
		end
	end

	local eventItems = getEventCosmetics(player)
	for category, items in eventItems do
		for _, itemId in items do
			if not seen[category :: Category][itemId] then
				table.insert(owned[category :: Category], itemId)
				seen[category :: Category][itemId] = true
			end
		end
	end

	for _, itemId in getPersistedUnlocks(player) do
		local cfg = CosmeticConfig.getItemById((parseGunSkinId(itemId)))
		if cfg and not seen[cfg.category][itemId] then
			table.insert(owned[cfg.category], itemId)
			seen[cfg.category][itemId] = true
		end
	end

	local unlocked = externalUnlocks[userId]
	if unlocked then
		for itemId, category in unlocked do
			if not seen[category :: Category][itemId] then
				table.insert(owned[category :: Category], itemId)
				seen[category :: Category][itemId] = true
			end
		end
	end

	buildOwnedLookup(userId, owned)
	return owned
end

local function getDefaultEquipped(): EquippedCosmetics
	return {
		PlayerCard = "Default_PlayerCard",
		GunSkins = {},
		ChatGradient = "",
	}
end

local function loadEquippedFromLyra(player: Player): EquippedCosmetics
	local data = PlayerDataStore.get(player)
	local equipped = getDefaultEquipped()

	if data and data.Cosmetics then
		for category, key in CATEGORY_TO_KEY do
			local storedValue = data.Cosmetics[key]
			if storedValue and storedValue ~= "" then
				(equipped :: any)[category] = storedValue
			end
		end

		local gunSkins = data.Cosmetics.GunSkins
		if type(gunSkins) == "table" then
			equipped.GunSkins = table.clone(gunSkins :: any)
		elseif type(data.Cosmetics.Skin) == "string" and data.Cosmetics.Skin ~= "" then
			equipped.GunSkins = {}
		end
	end

	return equipped
end

local function validateEquippedCosmetics(userId: number, equipped: EquippedCosmetics): EquippedCosmetics
	local validated = getDefaultEquipped()

	if equipped.PlayerCard and equipped.PlayerCard ~= "" then
		if isDefaultItem(equipped.PlayerCard) or isItemOwned(userId, "PlayerCard", equipped.PlayerCard) then
			validated.PlayerCard = equipped.PlayerCard
		end
	end

	if equipped.ChatGradient and equipped.ChatGradient ~= "" then
		if isDefaultItem(equipped.ChatGradient) or isItemOwned(userId, "ChatGradient", equipped.ChatGradient) then
			validated.ChatGradient = equipped.ChatGradient
		end
	end

	if equipped.GunSkins then
		for gunName, skinId in equipped.GunSkins do
			if skinId and skinId ~= "" and skinId ~= "Default" then
				if isItemOwned(userId, "GunSkin", skinId) or isItemOwned(userId, "GunSkin", `{skinId}:{gunName}`) then
					validated.GunSkins[gunName] = skinId
				end
			end
		end
	end

	return validated
end

local function saveEquippedToLyra(player: Player, category: Category, itemId: string): ()
	local key = CATEGORY_TO_KEY[category]
	if not key then
		return
	end

	PlayerDataStore.update(player, function(state)
		if state.Cosmetics then
			state.Cosmetics[key] = itemId
		end
		return true
	end)
end

local function saveGunSkinsToLyra(player: Player, gunSkins: { [string]: string }): ()
	local copy = table.clone(gunSkins)
	PlayerDataStore.update(player, function(state)
		if state.Cosmetics then
			state.Cosmetics.GunSkins = copy
			state.Cosmetics.Skin = nil
		end
		return true
	end)
end

local function getPlayerState(player: Player): CosmeticState
	local userId = player.UserId
	if not playerStates[userId] then
		local owned = getOwnedCosmetics(player)
		local rawEquipped = loadEquippedFromLyra(player)
		local validatedEquipped = validateEquippedCosmetics(userId, rawEquipped)

		playerStates[userId] = {
			owned = owned,
			equipped = validatedEquipped,
		}

		if rawEquipped.PlayerCard ~= validatedEquipped.PlayerCard and rawEquipped.PlayerCard ~= "" then
			saveEquippedToLyra(player, "PlayerCard", validatedEquipped.PlayerCard or "Default_PlayerCard")
		end
		if rawEquipped.ChatGradient ~= validatedEquipped.ChatGradient and rawEquipped.ChatGradient ~= "" then
			saveEquippedToLyra(player, "ChatGradient", validatedEquipped.ChatGradient or "")
		end
	end
	return playerStates[userId]
end

local function canEquipItem(player: Player, category: Category, itemId: string, gunName: string?): boolean
	local userId = player.UserId

	if isDefaultItem(itemId) then
		return true
	end

	local lookup = playerOwnedLookup[userId]
	if not lookup then
		getPlayerState(player)
		lookup = playerOwnedLookup[userId]
	end

	if not lookup or not lookup[category] then
		return false
	end

	if lookup[category][itemId] == true then
		return true
	end

	return category == "GunSkin" and gunName ~= nil and lookup[category][`{itemId}:{gunName}`] == true
end

local function equipItem(player: Player, category: Category, itemId: string): boolean
	if category == "GunSkin" then
		local skinId, gunName = parseGunSkinId(itemId)
		if not canEquipItem(player, "GunSkin", skinId, gunName) then
			return false
		end

		if gunName and #gunName > 50 then
			return false
		end

		local state = getPlayerState(player)
		if not state.equipped.GunSkins then
			state.equipped.GunSkins = {}
		end

		if gunName then
			if isDefaultItem(skinId) or skinId == "Default" then
				state.equipped.GunSkins[gunName] = nil
			else
				state.equipped.GunSkins[gunName] = skinId
			end
		end

		saveGunSkinsToLyra(player, state.equipped.GunSkins)
		cosmeticChanged:Fire(player, category, itemId)
		Network.Cosmetic.sendStateUpdate(player, state)
		return true
	end

	if not canEquipItem(player, category, itemId) then
		return false
	end

	local state = getPlayerState(player);
	(state.equipped :: any)[category] = itemId

	saveEquippedToLyra(player, category, itemId)
	cosmeticChanged:Fire(player, category, itemId)
	Network.Cosmetic.sendStateUpdate(player, state)

	return true
end

local function unequipItem(player: Player, category: Category): boolean
	local state = getPlayerState(player)

	if category == "GunSkin" then
		state.equipped.GunSkins = {}
		saveGunSkinsToLyra(player, {})
		cosmeticChanged:Fire(player, category, "Default")
		Network.Cosmetic.sendStateUpdate(player, state)
		return true
	end

	local defaultId = "Default_" .. category;
	(state.equipped :: any)[category] = defaultId

	saveEquippedToLyra(player, category, defaultId)
	cosmeticChanged:Fire(player, category, defaultId)
	Network.Cosmetic.sendStateUpdate(player, state)

	return true
end

local function invalidatePlayerCache(userId: number): ()
	playerOwnershipCache[userId] = nil
	playerBundleCache[userId] = nil
	playerPackCache[userId] = nil
	playerOwnershipReady[userId] = nil
end

local function addItemToOwned(player: Player, category: Category, itemId: string): boolean
	local userId = player.UserId
	local state = playerStates[userId]
	if not state then
		return false
	end

	local lookup = playerOwnedLookup[userId]
	if lookup and lookup[category] and lookup[category][itemId] then
		return false
	end

	local owned = state.owned[category]
	if owned then
		table.insert(owned, itemId)
	end

	if lookup and lookup[category] then
		lookup[category][itemId] = true
	end

	return true
end

local function onGamepassPurchase(player: Player, gamepassId: number, wasPurchased: boolean): ()
	if not wasPurchased then
		return
	end

	local userId = player.UserId
	local userCache = playerOwnershipCache[userId]
	if userCache then
		userCache[gamepassId] = true
	end

	local bundle = Bundles.getBundleByGamepassId(gamepassId)
	if bundle then
		local bundleCache = playerBundleCache[userId]
		if bundleCache then
			bundleCache[bundle.id] = true
		end

		local addedAny = false
		for _, bundleItem in bundle.items do
			if addItemToOwned(player, bundleItem.category, bundleItem.id) then
				addedAny = true
			end
		end

		if addedAny then
			local state = playerStates[userId]
			if state then
				Network.Cosmetic.sendStateUpdate(player, state)
			end
		end
		return
	end

	local pack = Packs.getPackByGamepassId(gamepassId)
	if pack then
		local packCache = playerPackCache[userId]
		if packCache then
			packCache[pack.id] = true
		end

		local addedAny = false
		for _, packItem in pack.items do
			if addItemToOwned(player, packItem.category, packItem.id) then
				addedAny = true
			end
		end

		if addedAny then
			local state = playerStates[userId]
			if state then
				Network.Cosmetic.sendStateUpdate(player, state)
			end
		end
		return
	end

	local item = CosmeticConfig.getItemByGamepassId(gamepassId)
	if item then
		if addItemToOwned(player, item.category, item.id) then
			local state = playerStates[userId]
			if state then
				Network.Cosmetic.sendStateUpdate(player, state)
			end
		end
	end
end

local function onGetState(player: Player): CosmeticState?
	return getPlayerState(player)
end

local function onEquip(player: Player, category: Category, itemId: string): boolean
	if typeof(category) ~= "string" or typeof(itemId) ~= "string" then
		return false
	end

	if not CosmeticConfig.Categories[category] then
		return false
	end

	return equipItem(player, category, itemId)
end

local function onUnequip(player: Player, category: Category): boolean
	if typeof(category) ~= "string" then
		return false
	end

	if not CosmeticConfig.Categories[category] then
		return false
	end

	return unequipItem(player, category)
end

local function mergeOwnedCosmetics(existing: OwnedCosmetics, fresh: OwnedCosmetics): OwnedCosmetics
	local freshLookup: { [string]: { [string]: boolean } } = {}
	for category, items in fresh do
		freshLookup[category] = {}
		for _, itemId in items do
			freshLookup[category][itemId] = true
		end
	end

	for category, items in existing do
		local catLookup = freshLookup[category]
		if catLookup then
			for _, itemId in items do
				if not catLookup[itemId] then
					table.insert(fresh[category], itemId)
				end
			end
		end
	end

	return fresh
end

local function onRefreshOwnership(player: Player): CosmeticState?
	local userId = player.UserId

	local state = getPlayerState(player)
	local existingOwned = state.owned

	invalidatePlayerCache(userId)

	local freshOwned = getOwnedCosmetics(player)
	state.owned = mergeOwnedCosmetics(existingOwned, freshOwned)

	local validatedEquipped = validateEquippedCosmetics(userId, state.equipped)

	if state.equipped.PlayerCard ~= validatedEquipped.PlayerCard then
		state.equipped.PlayerCard = validatedEquipped.PlayerCard
		saveEquippedToLyra(player, "PlayerCard", validatedEquipped.PlayerCard or "Default_PlayerCard")
	end

	if state.equipped.ChatGradient ~= validatedEquipped.ChatGradient then
		state.equipped.ChatGradient = validatedEquipped.ChatGradient
		saveEquippedToLyra(player, "ChatGradient", validatedEquipped.ChatGradient or "")
	end

	state.equipped.GunSkins = validatedEquipped.GunSkins or {}
	saveGunSkinsToLyra(player, state.equipped.GunSkins)

	Network.Cosmetic.sendStateUpdate(player, state)
	return state
end

local function onPlayerAdded(player: Player): ()
	task.spawn(getPlayerState, player)
end

local function onPlayerRemoving(player: Player): ()
	local userId = player.UserId
	playerStates[userId] = nil
	playerOwnershipCache[userId] = nil
	playerBundleCache[userId] = nil
	playerPackCache[userId] = nil
	playerOwnedLookup[userId] = nil
	playerOwnershipReady[userId] = nil
	externalUnlocks[userId] = nil
	EventCosmeticsAPI.clearCache(userId)
end

function CosmeticService:GetPlayerState(player: Player): CosmeticState
	return getPlayerState(player)
end

function CosmeticService:GetEquippedItem(player: Player, category: Category): ResolvedCosmetic?
	local state = getPlayerState(player)
	local itemId = (state.equipped :: any)[category]
	if not itemId or type(itemId) ~= "string" then
		return nil
	end

	local item = CosmeticConfig.getItemById(itemId)
	if not item then
		return nil
	end

	return CosmeticConfig.resolveItem(item)
end

function CosmeticService:GetEquippedGunSkins(player: Player): { [string]: string }
	local state = getPlayerState(player)
	return state.equipped.GunSkins or {}
end

function CosmeticService:GetEquippedGunSkin(player: Player, gunName: string): string
	local state = getPlayerState(player)
	if state.equipped.GunSkins and state.equipped.GunSkins[gunName] then
		return state.equipped.GunSkins[gunName]
	end
	return "Default"
end

function CosmeticService:GetOwnedItems(player: Player, category: Category): { ResolvedCosmetic }
	local state = getPlayerState(player)
	local owned = state.owned[category]
	if not owned then
		return {}
	end

	local resolved: { ResolvedCosmetic } = {}
	for _, itemId in owned do
		local item = CosmeticConfig.getItemById(itemId)
		if item then
			table.insert(resolved, CosmeticConfig.resolveItem(item))
		end
	end

	return resolved
end

function CosmeticService:EquipItem(player: Player, category: Category, itemId: string): boolean
	return equipItem(player, category, itemId)
end

function CosmeticService:UnequipItem(player: Player, category: Category): boolean
	return unequipItem(player, category)
end

function CosmeticService:RefreshOwnership(player: Player): CosmeticState
	return onRefreshOwnership(player) :: CosmeticState
end

function CosmeticService:OwnsItem(player: Player, itemId: string): boolean
	local item = CosmeticConfig.getItemById(itemId)
	if not item then
		return false
	end
	return checkOwnershipForItem(player, item)
end

function CosmeticService:OnCosmeticChanged(callback: (player: Player, category: Category, itemId: string) -> ()): Signal.Connection
	return cosmeticChanged:Connect(callback)
end

function CosmeticService:init(): ()
	isInitialized = true
end

function CosmeticService:start(): ()
	if not isInitialized then
		self:init()
	end

	Network.Cosmetic.onGetState(onGetState)
	Network.Cosmetic.onEquip(onEquip)
	Network.Cosmetic.onUnequip(onUnequip)
	Network.Cosmetic.onRefreshOwnership(onRefreshOwnership)

	local TeleportToHubEvent: RemoteEvent = Core.getOrCreateRemoteEvent("TeleportToHub")

	table.insert(
		connections,
		TeleportToHubEvent.OnServerEvent:Connect(function(player: Player, gamepassId: any)
			if type(gamepassId) ~= "number" then
				return
			end

			local hub = StoreHubRedirects.getHubForGamepass(gamepassId)
			if not hub or hub.placeId <= 0 then
				return
			end

			local teleportOptions = Instance.new("TeleportOptions")
			teleportOptions:SetTeleportData({
				source = "VultarShop",
				gamepassId = gamepassId,
				storeHubKey = hub.key,
			})

			local success, err = pcall(function()
				TeleportService:TeleportAsync(hub.placeId, { player }, teleportOptions)
			end)
			if not success then
				warn(`FAILED TO TELEPORT {player.Name} TO STORE HUB FOR GAMEPASS {gamepassId}: {err}`)
			end
		end)
	)

	table.insert(connections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(connections, Players.PlayerRemoving:Connect(onPlayerRemoving))

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	table.insert(connections, MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamepassPurchase))
end

function CosmeticService:ApplyUnlocks(player: Player, itemIds: { string }): ()
	local userId = player.UserId
	local unlocks = externalUnlocks[userId] or {}
	externalUnlocks[userId] = unlocks

	local added: { { id: string, category: Category } } = {}
	for _, id in itemIds do
		local cfg = CosmeticConfig.getItemById((parseGunSkinId(id)))
		if cfg and not unlocks[id] then
			unlocks[id] = cfg.category
			table.insert(added, { id = id, category = cfg.category })
		end
	end

	local userState = playerStates[userId]
	if not userState or #added == 0 then
		return
	end

	for _, entry in added do
		if not table.find(userState.owned[entry.category], entry.id) then
			table.insert(userState.owned[entry.category], entry.id)
		end
	end
	buildOwnedLookup(userId, userState.owned)
	Network.Cosmetic.sendStateUpdate(player, userState)
end

function CosmeticService:GrantUnlocks(player: Player, itemIds: { string }): ()
	local valid: { string } = {}
	for _, id in itemIds do
		if CosmeticConfig.getItemById((parseGunSkinId(id))) then
			table.insert(valid, id)
		else
			warn(`GrantUnlocks: unknown item {id}`)
		end
	end
	if #valid == 0 then
		return
	end

	PlayerDataStore.update(player, function(state)
		if not state.Cosmetics then
			return false
		end
		local cosmetics = state.Cosmetics :: any
		local unlocked: { string } = cosmetics.Unlocked or {}
		for _, id in valid do
			if not table.find(unlocked, id) then
				table.insert(unlocked, id)
			end
		end
		cosmetics.Unlocked = unlocked
		return true
	end)

	self:ApplyUnlocks(player, valid)
end

function CosmeticService:Cleanup(): ()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	table.clear(playerStates)
	table.clear(playerOwnershipCache)
	table.clear(playerBundleCache)
	table.clear(playerPackCache)
	table.clear(playerOwnedLookup)
	table.clear(playerOwnershipReady)
	table.clear(externalUnlocks)
	cosmeticChanged:Destroy()
	isInitialized = false
end

return CosmeticService
