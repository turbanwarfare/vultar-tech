--!strict
--!native
--!optimize 2

local Collections = require(script.Parent.Collections)

export type PackItem = {
	id: string,
	category: "GunSkin" | "PlayerCard",
}

export type PackConfig = {
	id: string,
	name: string,
	collection: string,
	items: { PackItem },
	imageId: string,
	gamepassId: number,
	isFeatured: boolean?,
}

local Packs: { PackConfig } = {
	{
		id = "HelloKitty_Pack",
		name = "Hello Kitty",
		collection = "HelloKitty",
		items = {
			{ id = "HelloKitty", category = "GunSkin" },
			{ id = "HelloKitty_PlayerCard", category = "PlayerCard" },
		},
		imageId = Collections.HelloKitty.imageId,
		gamepassId = 1902972726,
		isFeatured = true,
	},
	{
		id = "Freeze_Pack",
		name = "Freeze",
		collection = "Freeze",
		items = {
			{ id = "Freeze", category = "GunSkin" },
			{ id = "Freeze_PlayerCard", category = "PlayerCard" },
		},
		imageId = Collections.Freeze.imageId,
		gamepassId = 1931220905,
		isFeatured = true,
	},
	{
		id = "Vex_Pack",
		name = "Vex Pack",
		collection = "Vex",
		items = {
			{ id = "Vex", category = "GunSkin" },
			{ id = "Vex_PlayerCard", category = "PlayerCard" },
		},
		imageId = Collections.Vex.imageId,
		gamepassId = 1870445094,
		isFeatured = true,
	},
	{
		id = "Toxic_Pack",
		name = "Toxic Pack",
		collection = "Toxic",
		items = {
			{ id = "Toxic", category = "GunSkin" },
			{ id = "Toxic_PlayerCard", category = "PlayerCard" },
		},
		imageId = Collections.Toxic.imageId,
		gamepassId = 1763970361,
		isFeatured = true,
	},
	{
		id = "Beast_Pack",
		name = "Beast Pack",
		collection = "Beast",
		items = {
			{ id = "Beast", category = "GunSkin" },
			{ id = "Beast_PlayerCard", category = "PlayerCard" },
		},
		imageId = Collections.Beast.imageId,
		gamepassId = 1668585575,
		isFeatured = true,
	},
	{
		id = "Waves_Pack",
		name = "Waves Pack",
		collection = "Waves",
		items = {
			{ id = "Waves", category = "GunSkin" },
			{ id = "Waves_PlayerCard", category = "PlayerCard" },
		},
		imageId = Collections.Waves.imageId,
		gamepassId = 1668318105,
	},
	{
		id = "FarAway_Pack",
		name = "Far Away Pack",
		collection = "FarAway",
		items = {
			{ id = "Far Away", category = "GunSkin" },
			{ id = "FarAway_PlayerCard", category = "PlayerCard" },
		},
		imageId = Collections.FarAway.imageId,
		gamepassId = 1669004259,
	},
	{
		id = "Commando_Pack",
		name = "Commando Pack",
		collection = "Commando",
		items = {
			{ id = "Commando", category = "GunSkin" },
			{ id = "Commando_PlayerCard", category = "PlayerCard" },
		},
		imageId = Collections.Commando.imageId,
		gamepassId = 1668678595,
	},
	{
		id = "Volatil_Pack",
		name = "Volatil Pack",
		collection = "Volatil",
		items = {
			{ id = "Volatil", category = "GunSkin" },
			{ id = "Volatil_PlayerCard", category = "PlayerCard" },
		},
		imageId = Collections.Volatil.imageId,
		gamepassId = 1668754369,
		isFeatured = true,
	},
	{
		id = "Digi_Pack",
		name = "Digi Pack",
		collection = "Digi",
		items = {
			{ id = "Digi", category = "GunSkin" },
			{ id = "Digi_PlayerCard", category = "PlayerCard" },
		},
		imageId = Collections.Digi.imageId,
		gamepassId = 1668136122,
	},
	{
		id = "Punished_Pack",
		name = "Punished Pack",
		collection = "Punished",
		items = {
			{ id = "Punished", category = "GunSkin" },
			{ id = "Punished_PlayerCard", category = "PlayerCard" },
		},
		imageId = Collections.Punished.imageId,
		gamepassId = 1668409910,
	},
	{
		id = "Cat_Pack",
		name = "Cat Pack",
		collection = "Meow",
		items = {
			{ id = "Maxwell", category = "GunSkin" },
			{ id = "Meow_PlayerCard", category = "PlayerCard" },
		},
		imageId = Collections.Meow.imageId,
		gamepassId = 1669552042,
		isFeatured = true,
	},
	{
		id = "Night_Pack",
		name = "Night Pack",
		collection = "Night",
		items = {
			{ id = "Night", category = "GunSkin" },
			{ id = "Night_PlayerCard", category = "PlayerCard" },
		},
		imageId = Collections.Night.imageId,
		gamepassId = 1668505672,
	},
}

local packsById: { [string]: PackConfig } = {}
local packsByCollection: { [string]: PackConfig } = {}
local packsByGamepassId: { [number]: PackConfig } = {}
local featuredPacks: { PackConfig } = {}

for _, pack in Packs do
	packsById[pack.id] = pack
	packsByCollection[pack.collection] = pack
	if pack.gamepassId > 0 then
		packsByGamepassId[pack.gamepassId] = pack
	end
	if pack.isFeatured then
		table.insert(featuredPacks, pack)
	end
end

local PacksModule = {}

function PacksModule.getAllPacks(): { PackConfig }
	return Packs
end

function PacksModule.getPackById(id: string): PackConfig?
	return packsById[id]
end

function PacksModule.getPackByCollection(collection: string): PackConfig?
	return packsByCollection[collection]
end

function PacksModule.getFeaturedPacks(): { PackConfig }
	return featuredPacks
end

function PacksModule.getPackByGamepassId(gamepassId: number): PackConfig?
	return packsByGamepassId[gamepassId]
end

return PacksModule
