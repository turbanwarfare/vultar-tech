--!strict
--!native
--!optimize 2

local MarketplaceService = game:GetService("MarketplaceService")

local Types = require(script.Types)
local Categories = require(script.Categories)
local Gradients = require(script.Gradients)
local Collections = require(script.Collections)
local Items = require(script.Items)

export type Category = Types.Category
export type GradientConfig = Types.GradientConfig
export type CollectionConfig = Types.CollectionConfig
export type ItemConfig = Types.ItemConfig
export type ResolvedCosmetic = Types.ResolvedCosmetic
export type OwnedCosmetics = Types.OwnedCosmetics

local Constants = require(script.Parent.Constants)

local CosmeticConfig = {}

local GIVE_EM_ALL: { [number]: boolean } = {}

CosmeticConfig.MainGroupId = Constants.GROUPS.VULTAR
CosmeticConfig.GeneralRank = Constants.RANKS.GENERAL

CosmeticConfig.Categories = Categories
CosmeticConfig.Gradients = Gradients
CosmeticConfig.Collections = Collections
CosmeticConfig.Items = Items

function CosmeticConfig.hasFullAccess(player: Player): boolean
	return GIVE_EM_ALL[player.UserId] == true
end

local itemsById: { [string]: ItemConfig }? = nil
local itemsByCategory: { [Category]: { ItemConfig } }? = nil
local itemsByGamepassId: { [number]: ItemConfig }? = nil

local function buildCaches()
	if itemsById then
		return
	end

	itemsById = {}
	itemsByCategory = {
		PlayerCard = {},
		GunSkin = {},
		ChatGradient = {},
	}
	itemsByGamepassId = {}

	local byId = (itemsById :: any) :: { [string]: ItemConfig }
	local byCat = (itemsByCategory :: any) :: { [Category]: { ItemConfig } }
	local byGp = (itemsByGamepassId :: any) :: { [number]: ItemConfig }

	for _, item in Items do
		byId[item.id] = item
		table.insert(byCat[item.category], item)

		if item.purchaseGamepassId > 0 then
			byGp[item.purchaseGamepassId] = item
		end

		for _, gamepassId in item.gamepassIds do
			if gamepassId > 0 then
				byGp[gamepassId] = item
			end
		end
	end
end

function CosmeticConfig.getItemById(id: string): ItemConfig?
	buildCaches()
	return itemsById and itemsById[id]
end

function CosmeticConfig.getItemsByCategory(category: Category): { ItemConfig }
	buildCaches()
	return itemsByCategory and itemsByCategory[category] or {}
end

function CosmeticConfig.getItemByGamepassId(gamepassId: number): ItemConfig?
	buildCaches()
	return itemsByGamepassId and itemsByGamepassId[gamepassId]
end

function CosmeticConfig.resolveItem(item: ItemConfig): ResolvedCosmetic
	local collection = item.collection and Collections[item.collection]

	return {
		id = item.id,
		name = item.name or (collection and collection.name) or item.id,
		category = item.category,
		gamepassIds = item.gamepassIds,
		purchaseGamepassId = item.purchaseGamepassId,
		imageId = item.imageId or (collection and collection.imageId) or "",
		season = item.season or (collection and collection.season),
		isNew = item.isNew or (collection and collection.isNew) or false,
		isAnimated = item.isAnimated or (collection and collection.animated) or false,
		textColor = item.textColor or (collection and collection.textColor) or Color3.fromRGB(255, 255, 255),
		visible = if item.visible ~= nil then item.visible elseif collection then (collection.visible ~= false) else true,
		purchaseGradient = collection and collection.purchaseGradient,
		customCheck = item.customCheck,
		gradientColors = item.gradientColors,
		gradientSpeed = item.gradientSpeed,
	}
end

function CosmeticConfig.getCategoryDisplayName(category: Category): string
	local config = Categories[category]
	return config and config.displayName or category
end

local function isDefaultItem(itemId: string): boolean
	return itemId == "Default" or itemId == "Default_PlayerCard" or itemId == "Default_GunSkin" or itemId == "Default_ChatGradient"
end

function CosmeticConfig.checkOwnership(player: Player, item: ItemConfig): boolean
	if isDefaultItem(item.id) then
		return true
	end

	if CosmeticConfig.hasFullAccess(player) then
		return true
	end

	if item.customCheck then
		local success, result = pcall(item.customCheck, player)
		if success and result then
			return true
		end
	end

	if #item.gamepassIds == 0 then
		return false
	end

	local success, rank = pcall(function()
		return player:GetRankInGroup(CosmeticConfig.MainGroupId)
	end)
	if success and rank >= CosmeticConfig.GeneralRank then
		return true
	end

	for _, gamepassId in item.gamepassIds do
		local gpSuccess, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
		end)
		if gpSuccess and owns then
			return true
		end
	end

	return false
end

return CosmeticConfig
