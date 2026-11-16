--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local CosmeticConfig = require(MainModule.Shared.Config.Cosmetics)
local Packs = require(MainModule.Shared.Config.Cosmetics.Packs)

type ResolvedCosmetic = CosmeticConfig.ResolvedCosmetic
type PackConfig = Packs.PackConfig

local CosmeticLookup = {}

local skinsById: { [string]: ResolvedCosmetic } = {}
local cardsById: { [string]: ResolvedCosmetic } = {}
local skinCount = 0
local cardCount = 0

local initialized = false

local function buildLookupTables()
	if initialized then return end
	initialized = true

	local skinItems = CosmeticConfig.getItemsByCategory("GunSkin")
	for _, item in skinItems do
		local resolved = CosmeticConfig.resolveItem(item)
		skinsById[item.id] = resolved
	end
	skinCount = #skinItems

	local cardItems = CosmeticConfig.getItemsByCategory("PlayerCard")
	for _, item in cardItems do
		local resolved = CosmeticConfig.resolveItem(item)
		cardsById[item.id] = resolved
	end
	cardCount = #cardItems
end

function CosmeticLookup.getSkinById(id: string): ResolvedCosmetic?
	buildLookupTables()
	return skinsById[id]
end

function CosmeticLookup.getCardById(id: string): ResolvedCosmetic?
	buildLookupTables()
	return cardsById[id]
end

function CosmeticLookup.getPackById(id: string): PackConfig?
	return Packs.getPackById(id)
end

function CosmeticLookup.getSkinCount(): number
	buildLookupTables()
	return skinCount
end

function CosmeticLookup.getCardCount(): number
	buildLookupTables()
	return cardCount
end

function CosmeticLookup.getPackCount(): number
	return #Packs.getAllPacks()
end

return CosmeticLookup
