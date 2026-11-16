--!strict
--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkinModelCache = {}

local modelCache: { [string]: Model } = {}
local cacheSize: number = 0

local function buildCacheKey(skinId: string, gunName: string): string
	return skinId .. "_" .. gunName
end

function SkinModelCache.getModel(skinId: string, gunName: string): Model?
	local cacheKey = buildCacheKey(skinId, gunName)
	local cached = modelCache[cacheKey]
	if cached then
		return cached
	end

	local templates = ReplicatedStorage:FindFirstChild("SkinTemplates")
	if not templates then
		return nil
	end

	local skinFolder = templates:FindFirstChild(skinId)
	if not skinFolder then
		return nil
	end

	local model = skinFolder:FindFirstChild(gunName) :: Model?
	if not model then
		local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
		local GunStats = require(MainModule.Shared.Config.GunStats)
		local refGun = GunStats.get(gunName) and GunStats.get(gunName).SkinReferenceGun
		if refGun then
			model = skinFolder:FindFirstChild(refGun) :: Model?
		end
	end
	if model then
		modelCache[cacheKey] = model
		cacheSize += 1
	end
	return model
end

function SkinModelCache.cloneModel(skinId: string, gunName: string): Model?
	local model = SkinModelCache.getModel(skinId, gunName)
	if model then
		return model:Clone()
	end
	return nil
end

function SkinModelCache.clearCache()
	table.clear(modelCache)
	cacheSize = 0
end

function SkinModelCache.getCacheSize(): number
	return cacheSize
end

return SkinModelCache
