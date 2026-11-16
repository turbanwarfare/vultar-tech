--!strict
--!native
--!optimize 2

local CosmeticLookup = require(script.CosmeticLookup)
local PriceCache = require(script.PriceCache)
local SkinModelCache = require(script.SkinModelCache)

local ShopCacheModule = {}

ShopCacheModule.CosmeticLookup = CosmeticLookup
ShopCacheModule.PriceCache = PriceCache
ShopCacheModule.SkinModelCache = SkinModelCache

function ShopCacheModule.clearAllCaches()
	PriceCache.clearCache()
	SkinModelCache.clearCache()
end

return ShopCacheModule
