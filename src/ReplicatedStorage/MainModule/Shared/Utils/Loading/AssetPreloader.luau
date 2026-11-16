--!strict
--!native
--!optimize 2

local ContentProvider = game:GetService("ContentProvider")

local AssetPreloader = {}

local preloadQueue: { string } = {}
local preloadQueueSet: { [string]: boolean } = {}
local isPreloading = false
local preloadComplete = false

local function preloadBatch(assets: { any }, batchSize: number): ()
	local total = #assets
	local batches = math.ceil(total / batchSize)

	for i = 1, batches do
		local startIdx = (i - 1) * batchSize + 1
		local endIdx = math.min(i * batchSize, total)
		local batchCount = endIdx - startIdx + 1
		local batch = table.create(batchCount)
		table.move(assets, startIdx, endIdx, 1, batch)

		if batchCount > 0 then
			pcall(function()
				ContentProvider:PreloadAsync(batch)
			end)
		end
	end
end

function AssetPreloader.queueAsset(assetId: string | number): ()
	local id = if typeof(assetId) == "number" then "rbxassetid://" .. tostring(assetId) else assetId
	if not preloadQueueSet[id] then
		preloadQueueSet[id] = true
		table.insert(preloadQueue, id)
	end
end

function AssetPreloader.queueAssets(assetIds: { string | number }): ()
	for _, id in assetIds do
		AssetPreloader.queueAsset(id)
	end
end

function AssetPreloader.preloadQueued(): ()
	if isPreloading or #preloadQueue == 0 then
		return
	end

	isPreloading = true

	task.spawn(function()
		local assets = {}
		for _, id in preloadQueue do
			table.insert(assets, id)
		end
		table.clear(preloadQueue)
		table.clear(preloadQueueSet)

		preloadBatch(assets, 10)

		isPreloading = false
		preloadComplete = true
	end)
end

function AssetPreloader.preloadImmediate(assetIds: { string | number }): ()
	local assets = {}
	for _, id in assetIds do
		local assetId = if typeof(id) == "number" then "rbxassetid://" .. tostring(id) else id
		table.insert(assets, assetId)
	end

	if #assets > 0 then
		task.spawn(preloadBatch, assets, 10)
	end
end

function AssetPreloader.isComplete(): boolean
	return preloadComplete and not isPreloading
end

local UI_PATTERN_ASSETS = {
	"rbxassetid://0",
	"rbxassetid://140384357197755",
	"rbxassetid://76930192397001",
}

function AssetPreloader.preloadUIPatterns(): ()
	if #UI_PATTERN_ASSETS > 0 then
		task.spawn(pcall, ContentProvider.PreloadAsync, ContentProvider, UI_PATTERN_ASSETS)
	end
end

function AssetPreloader.preloadCriticalAssets(): ()
	local MainModule = script.Parent.Parent.Parent.Parent
	local criticalAssets: { string | number } = {}

	for _, pattern in UI_PATTERN_ASSETS do
		table.insert(criticalAssets, pattern)
	end

	local chatConfigSuccess, ChatConfig = pcall(require, MainModule.Shared.Config.Chat.ChatConfig)

	if chatConfigSuccess and ChatConfig and ChatConfig.Tags then
		for _, tag in ChatConfig.Tags do
			if tag.icon then
				table.insert(criticalAssets, tag.icon)
			end
		end
	end

	local success, SettingsConfig = pcall(require, MainModule.Shared.Config.Settings.SettingsConfig)

	if success and SettingsConfig then
		if SettingsConfig.Cursors then
			for _, cursor in SettingsConfig.Cursors do
				if cursor.id and cursor.id > 0 then
					table.insert(criticalAssets, cursor.id)
				end
			end
		end

		if SettingsConfig.HitmarkerAssets then
			for _, asset in SettingsConfig.HitmarkerAssets do
				if asset.id then
					table.insert(criticalAssets, asset.id)
				end
			end
		end
	end

	local constantsSuccess, Constants = pcall(require, MainModule.Shared.Config.Constants)

	if constantsSuccess and Constants then
		if Constants.LOADING_SCREEN_IMAGE and Constants.LOADING_SCREEN_IMAGE ~= "rbxassetid://0" then
			table.insert(criticalAssets, Constants.LOADING_SCREEN_IMAGE)
		end
	end

	if #criticalAssets > 0 then
		AssetPreloader.preloadImmediate(criticalAssets)
	end
end

function AssetPreloader.preloadCosmeticAssets(): ()
	local MainModule = script.Parent.Parent.Parent.Parent
	local cosmeticAssets: { string } = {}

	local success, Cosmetics = pcall(require, MainModule.Shared.Config.Cosmetics)

	if success and Cosmetics then
		local items = Cosmetics.Items
		if items then
			for _, item in items do
				local resolved = Cosmetics.resolveItem(item)
				if resolved and resolved.imageId and resolved.imageId ~= "" then
					table.insert(cosmeticAssets, resolved.imageId)
				end
			end
		end
	end

	if #cosmeticAssets > 0 then
		task.spawn(preloadBatch, cosmeticAssets, 5)
	end
end

function AssetPreloader.preloadCategoryAssets(category: string): ()
	local MainModule = script.Parent.Parent.Parent.Parent
	local categoryAssets: { string } = {}

	local success, Cosmetics = pcall(require, MainModule.Shared.Config.Cosmetics)

	if success and Cosmetics and Cosmetics.getItemsByCategory then
		local items = Cosmetics.getItemsByCategory(category)
		if items then
			for _, item in items do
				local resolved = Cosmetics.resolveItem(item)
				if resolved and resolved.imageId and resolved.imageId ~= "" then
					table.insert(categoryAssets, resolved.imageId)
				end
			end
		end
	end

	if #categoryAssets > 0 then
		task.spawn(preloadBatch, categoryAssets, 5)
	end
end

local SHOP_CARD_BACKGROUNDS = {
	"85308516327766",
	"136225460745188",
	"114901680198720",
	"86108890273439",
	"139076761632435",
	"97389410625853",
	"115310168098188",
}

local SHOP_GRADIENT_TILES = {
	"129248309234235",
	"104515626190317",
	"104815116303085",
	"109886623828201",
	"80260337907798",
	"106934817114589",
}

function AssetPreloader.preloadShopAssets(): ()
	local shopAssets: { string } = {}

	for _, id in SHOP_CARD_BACKGROUNDS do
		table.insert(shopAssets, "rbxassetid://" .. id)
	end

	for _, id in SHOP_GRADIENT_TILES do
		table.insert(shopAssets, "rbxassetid://" .. id)
	end

	if #shopAssets > 0 then
		preloadBatch(shopAssets, 10)
	end
end

function AssetPreloader.preloadOwnedItems(ownedItemIds: { string }): ()
	local MainModule = script.Parent.Parent.Parent.Parent
	local ownedAssets: { string } = {}

	local success, Cosmetics = pcall(require, MainModule.Shared.Config.Cosmetics)

	if success and Cosmetics then
		for _, itemId in ownedItemIds do
			local item = Cosmetics.getItemById(itemId)
			if item then
				local resolved = Cosmetics.resolveItem(item)
				if resolved and resolved.imageId and resolved.imageId ~= "" then
					table.insert(ownedAssets, resolved.imageId)
				end
			end
		end
	end

	if #ownedAssets > 0 then
		task.spawn(preloadBatch, ownedAssets, 10)
	end
end

function AssetPreloader.preloadUniformAssets(): ()
	local MainModule = script.Parent.Parent.Parent.Parent
	local uniformAssets: { string } = {}

	local success, Uniforms = pcall(require, MainModule.Shared.Config.Uniforms)
	if not success or not Uniforms then return end

	local seenGroups: { [number]: boolean } = {}

	for _, uniform in Uniforms.All do
		if not seenGroups[uniform.groupId] then
			seenGroups[uniform.groupId] = true
			table.insert(uniformAssets, "rbxthumb://type=GroupIcon&id=" .. uniform.groupId .. "&w=420&h=420")
		end

		if uniform.variants then
			for _, variant in uniform.variants do
				if variant.shirtId then
					table.insert(uniformAssets, "rbxassetid://" .. variant.shirtId)
				end
				if variant.pantId then
					table.insert(uniformAssets, "rbxassetid://" .. variant.pantId)
				end
			end
		else
			if uniform.shirtId then
				table.insert(uniformAssets, "rbxassetid://" .. uniform.shirtId)
			end
			if uniform.pantId then
				table.insert(uniformAssets, "rbxassetid://" .. uniform.pantId)
			end
		end
	end

	if #uniformAssets > 0 then
		task.spawn(preloadBatch, uniformAssets, 5)
	end
end

function AssetPreloader.preloadFromCosmeticState(state: any): ()
	if not state or not state.owned then return end

	local ownedIds: { string } = {}
	for _, itemIds in state.owned do
		if type(itemIds) == "table" then
			for _, itemId in itemIds do
				table.insert(ownedIds, itemId)
			end
		end
	end

	if #ownedIds > 0 then
		AssetPreloader.preloadOwnedItems(ownedIds)
	end
end

return AssetPreloader
