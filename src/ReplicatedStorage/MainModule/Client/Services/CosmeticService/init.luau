--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local CosmeticConfig = require(MainModule.Shared.Config.Cosmetics)
local Signal = require(MainModule.Shared.Utils.State.Signal)

type Category = CosmeticConfig.Category
type ItemConfig = CosmeticConfig.ItemConfig
type ResolvedCosmetic = CosmeticConfig.ResolvedCosmetic
type CosmeticState = Network.CosmeticState
type EquippedCosmetics = Network.EquippedCosmetics

local CosmeticService = {}
CosmeticService.Name = "CosmeticService"

local cachedState: CosmeticState? = nil
local resolvedCache: { [string]: ResolvedCosmetic } = {}
local ownedLookup: { [string]: boolean } = {}
local isLoaded = false
local isLoading = false
local isInitialized = false

local stateChanged = Signal.new()
local loadedSignal = Signal.new()

local connections: { RBXScriptConnection } = {}

local function getCachedResolved(itemId: string): ResolvedCosmetic?
	local cached = resolvedCache[itemId]
	if cached then
		return cached
	end

	local item = CosmeticConfig.getItemById(itemId)
	if not item then
		return nil
	end

	local resolved = CosmeticConfig.resolveItem(item)
	resolvedCache[itemId] = resolved
	return resolved
end

local function rebuildOwnedLookup(state: CosmeticState): ()
	table.clear(ownedLookup)
	for _, categoryOwned in state.owned do
		for _, itemId in categoryOwned do
			ownedLookup[itemId] = true
		end
	end
end

local function updateState(newState: CosmeticState): ()
	local oldState = cachedState
	cachedState = newState
	isLoaded = true
	rebuildOwnedLookup(newState)
	stateChanged:Fire(newState, oldState)
end

local function fetchState(): CosmeticState?
	if isLoading then
		return cachedState
	end

	isLoading = true
	local ok, state = pcall(Network.Cosmetic.getState)
	isLoading = false

	if ok and state then
		updateState(state)
		loadedSignal:Fire(state)
	end

	return if ok then state else cachedState
end

function CosmeticService:GetState(): CosmeticState?
	if cachedState then
		return cachedState
	end
	if isLoading then
		loadedSignal:Wait()
		return cachedState
	end
	return fetchState()
end

function CosmeticService:GetCachedState(): CosmeticState?
	return cachedState
end

function CosmeticService:IsLoaded(): boolean
	return isLoaded
end

function CosmeticService:WaitForLoaded(): CosmeticState
	if isLoaded and cachedState then
		return cachedState
	end

	if not isLoading then
		task.spawn(fetchState)
	end

	while not isLoaded do
		loadedSignal:Wait()
	end

	return cachedState :: CosmeticState
end

function CosmeticService:GetEquipped(category: Category): string?
	local state = self:GetCachedState()
	if not state then
		return nil
	end
	return (state.equipped :: any)[category]
end

function CosmeticService:GetEquippedGunSkins(): { [string]: string }
	local state = self:GetCachedState()
	if not state or not state.equipped.GunSkins then
		return {}
	end
	return state.equipped.GunSkins
end

function CosmeticService:GetEquippedGunSkin(gunName: string): string
	local state = self:GetCachedState()
	if state and state.equipped.GunSkins and state.equipped.GunSkins[gunName] then
		return state.equipped.GunSkins[gunName]
	end
	return "Default"
end

function CosmeticService:GetEquippedResolved(category: Category): ResolvedCosmetic?
	local itemId = self:GetEquipped(category)
	if not itemId then
		return nil
	end
	return getCachedResolved(itemId)
end

function CosmeticService:GetAllEquipped(): EquippedCosmetics?
	local state = self:GetCachedState()
	if not state then
		return nil
	end
	return state.equipped
end

function CosmeticService:IsOwned(itemId: string): boolean
	return ownedLookup[itemId] == true
end

function CosmeticService:GetOwned(category: Category): { string }
	local state = self:GetCachedState()
	if not state then
		return {}
	end
	return state.owned[category] or {}
end

function CosmeticService:GetOwnedResolved(category: Category): { ResolvedCosmetic }
	local owned = self:GetOwned(category)
	local resolved: { ResolvedCosmetic } = {}

	for _, itemId in owned do
		local item = getCachedResolved(itemId)
		if item then
			table.insert(resolved, item)
		end
	end

	return resolved
end

function CosmeticService:GetAllOwned(): { [Category]: { string } }?
	local state = self:GetCachedState()
	if not state then
		return nil
	end
	return state.owned
end

function CosmeticService:GetItemById(itemId: string): ResolvedCosmetic?
	return getCachedResolved(itemId)
end

function CosmeticService:GetItemsByCategory(category: Category): { ResolvedCosmetic }
	local items = CosmeticConfig.getItemsByCategory(category)
	local resolved: { ResolvedCosmetic } = {}

	for _, item in items do
		local resolvedItem = CosmeticConfig.resolveItem(item)
		if resolvedItem.visible then
			table.insert(resolved, resolvedItem)
		end
	end

	return resolved
end

function CosmeticService:GetVisibleItemsByCategory(category: Category): { ResolvedCosmetic }
	local items = CosmeticConfig.getItemsByCategory(category)
	local resolved: { ResolvedCosmetic } = {}

	for _, item in items do
		local resolvedItem = CosmeticConfig.resolveItem(item)
		local isOwned = ownedLookup[item.id] == true
		if resolvedItem.visible or isOwned then
			table.insert(resolved, resolvedItem)
		end
	end

	return resolved
end

function CosmeticService:GetCategories(): { { id: Category, displayName: string, order: number } }
	local categories: { { id: Category, displayName: string, order: number } } = {}

	for id, config in CosmeticConfig.Categories do
		table.insert(categories, {
			id = id,
			displayName = config.displayName,
			order = config.order,
		})
	end

	table.sort(categories, function(a, b)
		return a.order < b.order
	end)

	return categories
end

function CosmeticService:Equip(category: Category, itemId: string): boolean
	local success = Network.Cosmetic.equip(category, itemId)
	if success and cachedState then
		if category == "GunSkin" then
			local sepPos = string.find(itemId, ":", 1, true)
			if sepPos then
				local skinId = string.sub(itemId, 1, sepPos - 1)
				local gunName = string.sub(itemId, sepPos + 1)
				if not cachedState.equipped.GunSkins then
					cachedState.equipped.GunSkins = {}
				end
				if skinId == "Default" then
					cachedState.equipped.GunSkins[gunName] = nil
				else
					cachedState.equipped.GunSkins[gunName] = skinId
				end
			end
		else
			local equippedAny = cachedState.equipped :: any
			equippedAny[category] = itemId
		end
		stateChanged:Fire(cachedState, nil)
	end
	return success
end

function CosmeticService:Unequip(category: Category): boolean
	local success = Network.Cosmetic.unequip(category)
	if success and cachedState then
		if category == "GunSkin" then
			cachedState.equipped.GunSkins = {}
		else
			local equippedAny = cachedState.equipped :: any
			equippedAny[category] = "Default_" .. category
		end
		stateChanged:Fire(cachedState, nil)
	end
	return success
end

function CosmeticService:RefreshOwnership(): CosmeticState?
	local state = Network.Cosmetic.refreshOwnership()
	if state then
		updateState(state)
	end
	return state
end

function CosmeticService:OnStateChanged(callback: (newState: CosmeticState, oldState: CosmeticState?) -> ()): Signal.Connection
	return stateChanged:Connect(callback)
end

function CosmeticService:OnLoaded(callback: (state: CosmeticState) -> ()): Signal.Connection
	if isLoaded and cachedState then
		task.spawn(callback, cachedState)
	end
	return loadedSignal:Connect(callback)
end

function CosmeticService:init(): ()
	isInitialized = true
end

function CosmeticService:start(): ()
	if not isInitialized then
		self:init()
	end

	table.insert(connections, Network.Cosmetic.onStateUpdated(function(state)
		if state then
			updateState(state)
		end
	end))

	task.spawn(fetchState)
end

function CosmeticService:Cleanup(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	connections = {}

	stateChanged:DisconnectAll()
	loadedSignal:DisconnectAll()

	cachedState = nil
	table.clear(resolvedCache)
	table.clear(ownedLookup)
	isLoaded = false
	isLoading = false
end

return CosmeticService
