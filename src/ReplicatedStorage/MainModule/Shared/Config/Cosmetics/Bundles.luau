--!nonstrict
--!native
--!optimize 2

export type BundleItem = {
	category: "PlayerCard" | "GunSkin" | "ChatGradient",
	id: string,
}

export type BundleConfig = {
	id: string,
	name: string,
	description: string,
	gamepassId: number,
	price: number,
	items: { BundleItem },
	visible: boolean?,
	isNew: boolean?,
	season: string?,
}

local Bundles: { BundleConfig } = {
	{
		id = "LaunchBundle",
		name = "Launch Bundle",
		description = "Kickstart your arsenal with the Beast & Volatil gun skins, Beast & Cloud (Animated) banners, and the exclusive Inferno chat gradient.",
		gamepassId = 1663742264,
		price = 1499,
		isNew = true,
		season = "Launch",
		items = {
			{ category = "GunSkin", id = "Beast" },
			{ category = "GunSkin", id = "Volatil" },
			{ category = "PlayerCard", id = "Beast_PlayerCard" },
			{ category = "PlayerCard", id = "Cloud_Animated_PlayerCard" },
			{ category = "ChatGradient", id = "Inferno_ChatGradient" },
		},
	},

	{
		id = "ToxicBundle",
		name = "Toxic Weapon Bundle",
		description = "The full Toxic arsenal. Every rifle, every sidearm - dripping in radioactive green. Includes our first-ever pistol skins for the H-12 and BR-8.",
		gamepassId = 1763970361,
		price = 0,
		isNew = true,
		season = "3",
		items = {
			{ category = "GunSkin", id = "Toxic" },
			{ category = "PlayerCard", id = "Toxic_PlayerCard" },
			{ category = "ChatGradient", id = "Toxic_ChatGradient" },
		},
	},

	{
		id = "HelloKittyBundle",
		name = "Hello Kitty Bundle",
		description = "",
		gamepassId = 1902972726,
		price = 1500,
		isNew = true,
		season = "3",
		items = {
			{ category = "GunSkin", id = "HelloKitty" },
			{ category = "PlayerCard", id = "HelloKitty_PlayerCard" },
			{ category = "ChatGradient", id = "HelloKitty_ChatGradient" },
		},
	},

	{
		id = "PixelGunBundle",
		name = "Pixel Gun Bundle",
		description = "",
		gamepassId = 2061442665,
		price = 1200,
		isNew = true,
		season = "4",
		items = {
			{ category = "GunSkin", id = "PixelGun" },
			{ category = "PlayerCard", id = "PixelGun_PlayerCard" },
		},
	},

	{
		id = "FreezeBundle",
		name = "Freeze Bundle",
		description = "",
		gamepassId = 1931220905,
		price = 1100,
		isNew = true,
		season = "3",
		items = {
			{ category = "GunSkin", id = "Freeze" },
			{ category = "PlayerCard", id = "Freeze_PlayerCard" },
			{ category = "ChatGradient", id = "Freeze_ChatGradient" },
		},
	},

	{
		id = "VexBundle",
		name = "Vex Weapon Bundle",
		description = "The full Vex arsenal. Every rifle, every sidearm - drenched in crimson. Includes the exclusive Vex player card and chat gradient.",
		gamepassId = 1870445094,
		price = 0,
		isNew = true,
		season = "3",
		items = {
			{ category = "GunSkin", id = "Vex" },
			{ category = "PlayerCard", id = "Vex_PlayerCard" },
			{ category = "ChatGradient", id = "Vex_ChatGradient" },
		},
	},

	{
		id = "BestSellerBundle",
		name = "Best Seller Bundle",
		description = "Fan favorites in one package: Digi & Volatil gun skins, Digi & Volatil banners, and the icy Blizzard chat gradient.",
		gamepassId = 1661788677,
		price = 1299,
		isNew = true,
		season = "Launch",
		items = {
			{ category = "GunSkin", id = "Digi" },
			{ category = "GunSkin", id = "Volatil" },
			{ category = "PlayerCard", id = "Digi_PlayerCard" },
			{ category = "PlayerCard", id = "Volatil_PlayerCard" },
			{ category = "ChatGradient", id = "Blizzard_ChatGradient" },
		},
	},
}

local bundlesById: { [string]: BundleConfig }? = nil
local bundlesByGamepassId: { [number]: BundleConfig }? = nil

local function buildCaches()
	if bundlesById then
		return
	end

	bundlesById = {}
	bundlesByGamepassId = {}

	local byId = (bundlesById :: any) :: { [string]: BundleConfig }
	local byGp = (bundlesByGamepassId :: any) :: { [number]: BundleConfig }

	for _, bundle in Bundles do
		byId[bundle.id] = bundle
		if bundle.gamepassId > 0 then
			byGp[bundle.gamepassId] = bundle
		end
	end
end

local BundlesModule = {}

BundlesModule.Bundles = Bundles

function BundlesModule.getBundleById(id: string): BundleConfig?
	buildCaches()
	return bundlesById and bundlesById[id]
end

function BundlesModule.getBundleByGamepassId(gamepassId: number): BundleConfig?
	buildCaches()
	return bundlesByGamepassId and bundlesByGamepassId[gamepassId]
end

function BundlesModule.getAllBundles(): { BundleConfig }
	return Bundles
end

function BundlesModule.getVisibleBundles(): { BundleConfig }
	local visible: { BundleConfig } = {}
	for _, bundle in Bundles do
		if bundle.visible ~= false then
			table.insert(visible, bundle)
		end
	end
	return visible
end

return BundlesModule
