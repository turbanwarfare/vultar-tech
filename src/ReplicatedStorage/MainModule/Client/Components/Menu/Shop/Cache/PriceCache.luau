--!strict
--!native
--!optimize 2

local MarketplaceService = game:GetService("MarketplaceService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Types = require(MainModule.Shared.Types)

type FusionValue<T> = Types.FusionValue<T>

local PriceCache = {}

local cache: { [number]: number } = {}
local cacheSize = 0
local pendingRequests: { [number]: thread } = {}
local pendingCallbacks: { [number]: { FusionValue<number> } } = {}

local productCache: { [number]: number } = {}
local pendingProductRequests: { [number]: thread } = {}
local pendingProductCallbacks: { [number]: { FusionValue<number> } } = {}

function PriceCache.getPrice(gamepassId: number): number?
	return cache[gamepassId]
end

function PriceCache.getPriceAsync(gamepassId: number, priceValue: FusionValue<number>)
	if not gamepassId or gamepassId == 0 then
		priceValue:set(-1)
		return
	end

	local cached = cache[gamepassId]
	if cached then
		priceValue:set(cached)
		return
	end

	if pendingCallbacks[gamepassId] then
		table.insert(pendingCallbacks[gamepassId], priceValue)
		return
	end

	pendingCallbacks[gamepassId] = { priceValue }

	pendingRequests[gamepassId] = task.spawn(function()
		local success, productInfo = pcall(function()
			return MarketplaceService:GetProductInfo(gamepassId, Enum.InfoType.GamePass)
		end)

		pendingRequests[gamepassId] = nil

		if success and productInfo and productInfo.PriceInRobux then
			local price = productInfo.PriceInRobux
			if not cache[gamepassId] then
				cacheSize += 1
			end
			cache[gamepassId] = price

			local callbacks = pendingCallbacks[gamepassId]
			pendingCallbacks[gamepassId] = nil

			if callbacks then
				for _, callback in callbacks do
					callback:set(price)
				end
			end
		else
			local callbacks = pendingCallbacks[gamepassId]
			pendingCallbacks[gamepassId] = nil

			if callbacks then
				for _, callback in callbacks do
					callback:set(-1)
				end
			end
		end
	end)
end

function PriceCache.getProductPrice(productId: number): number?
	return productCache[productId]
end

function PriceCache.getProductPriceAsync(productId: number, priceValue: FusionValue<number>)
	if not productId or productId == 0 then
		priceValue:set(-1)
		return
	end

	local cached = productCache[productId]
	if cached then
		priceValue:set(cached)
		return
	end

	if pendingProductCallbacks[productId] then
		table.insert(pendingProductCallbacks[productId], priceValue)
		return
	end

	pendingProductCallbacks[productId] = { priceValue }

	pendingProductRequests[productId] = task.spawn(function()
		local success, productInfo = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)

		pendingProductRequests[productId] = nil

		if success and productInfo and productInfo.PriceInRobux then
			local price = productInfo.PriceInRobux
			productCache[productId] = price

			local callbacks = pendingProductCallbacks[productId]
			pendingProductCallbacks[productId] = nil

			if callbacks then
				for _, callback in callbacks do
					callback:set(price)
				end
			end
		else
			local callbacks = pendingProductCallbacks[productId]
			pendingProductCallbacks[productId] = nil

			if callbacks then
				for _, callback in callbacks do
					callback:set(-1)
				end
			end
		end
	end)
end

function PriceCache.cancelPending(gamepassId: number)
	local thread = pendingRequests[gamepassId]
	if thread then
		task.cancel(thread)
		pendingRequests[gamepassId] = nil
		pendingCallbacks[gamepassId] = nil
	end
end

function PriceCache.cancelAllPending()
	for _, thread in pendingRequests do
		task.cancel(thread)
	end
	table.clear(pendingRequests)
	table.clear(pendingCallbacks)
end

function PriceCache.clearCache()
	table.clear(cache)
	cacheSize = 0
end

function PriceCache.getCacheSize(): number
	return cacheSize
end

return PriceCache
