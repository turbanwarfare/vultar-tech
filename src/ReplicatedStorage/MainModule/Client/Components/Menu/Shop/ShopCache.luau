--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local CosmeticConfig = require(MainModule.Shared.Config.Cosmetics)
local PurchaseRedirectController = require(script.Parent.PurchaseRedirectController)

local ShopCache = {}

local resolvedItemCache: { [string]: CosmeticConfig.ResolvedCosmetic } = {}
local categoryItemsCache: { [string]: { CosmeticConfig.ItemConfig } } = {}

function ShopCache.getCachedResolvedItem(itemId: string): CosmeticConfig.ResolvedCosmetic?
	local cached = resolvedItemCache[itemId]
	if cached then
		return cached
	end

	local item = CosmeticConfig.getItemById(itemId)
	if not item then
		return nil
	end

	local resolved = CosmeticConfig.resolveItem(item)
	resolvedItemCache[itemId] = resolved
	return resolved
end

function ShopCache.getCachedCategoryItems(category: CosmeticConfig.Category): { CosmeticConfig.ItemConfig }
	local cached = categoryItemsCache[category]
	if cached then
		return cached
	end

	local items = CosmeticConfig.getItemsByCategory(category)
	categoryItemsCache[category] = items

	task.spawn(function()
		for _, item in items do
			if not resolvedItemCache[item.id] then
				resolvedItemCache[item.id] = CosmeticConfig.resolveItem(item)
			end
		end
	end)

	return items
end

function ShopCache.promptPurchase(gamepassId: number): ()
	if gamepassId == 0 then
		return
	end
	PurchaseRedirectController.promptPurchase(gamepassId)
end

function ShopCache.clearCache(): ()
	table.clear(resolvedItemCache)
	table.clear(categoryItemsCache)
end

return ShopCache
