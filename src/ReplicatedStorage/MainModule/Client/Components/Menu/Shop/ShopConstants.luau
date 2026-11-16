--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Types = require(MainModule.Shared.Types)
local Network = require(MainModule.Shared.Network)

export type CardTheme = {
	label: string,
	displayName: string,
	accent: Color3,
	backgroundImageId: string,
}

export type ShopCardData = {
	id: string,
	label: string,
	accent: Color3,
	backgroundImageId: string,
}

export type ShopGridProps = {
	OnCardClick: ((cardId: string) -> ())?,
	OwnedItems: Types.FusionValue<{ [string]: boolean }>?,
	EquippedItems: Types.FusionValue<{ [string]: any }>?,
	ResetTrigger: Types.FusionValue<number>?,
	CurrentPage: Types.FusionValue<number>?,
	CurrentTab: Types.FusionValue<string>?,
	SelectedBundleKey: Types.FusionValue<string?>?,
	SelectedPackId: Types.FusionValue<string?>?,
	SelectedSkinId: Types.FusionValue<string?>?,
	SelectedCardId: Types.FusionValue<string?>?,
	OnPurchaseSuccess: ((cosmeticType: string, newState: Network.CosmeticState?) -> ())?,
}

export type PageConfig = {
	id: string,
	label: string,
	subtitle: string,
}

local ShopConstants = {}

ShopConstants.PAGES = {
	{
		id = "Featured",
		label = "FEATURED",
		subtitle = "A curated collection of packs and bundles",
	},
	{
		id = "GunSkins",
		label = "GUN SKINS",
		subtitle = "Skins for your weapons",
	},
	{
		id = "PlayerCards",
		label = "PLAYER CARDS",
		subtitle = "Customize your player card",
	},
	{
		id = "ChatGradients",
		label = "GRADIENTS",
		subtitle = "Gradient effects for your chat messages",
	},
} :: { PageConfig }

ShopConstants.PAGE_LOOKUP = {} :: { [string]: number }
for i, page in ShopConstants.PAGES do
	ShopConstants.PAGE_LOOKUP[page.id] = i
end

ShopConstants.Header = {
	Height = 100,
}

ShopConstants.Layout = {
	SectionGap = 24,
	ContentPadding = 40,
}

ShopConstants.Section = {
	TitleSize = 24,
	SubtitleSize = 13,
	TitleColor = Color3.fromRGB(255, 255, 255),
	SubtitleColor = Color3.fromRGB(140, 140, 145),
}

ShopConstants.Card = {
	Width = 200,
	Height = 240,
	Gap = 16,
	CornerRadius = 8,
	ImageHeight = 160,
	PriceAccent = Color3.fromRGB(230, 60, 150),
	BorderAccent = Color3.fromRGB(255, 140, 0),
}

ShopConstants.INVENTORY_CARDS = {
	Shop = {
		label = "SHOP",
		displayName = "Shop",
		accent = Color3.fromRGB(255, 185, 50),
		backgroundImageId = "85308516327766",
	},
	GunSkin = {
		label = "GUN SKINS",
		displayName = "Gun Skins",
		accent = Color3.fromRGB(220, 75, 75),
		backgroundImageId = "136225460745188",
	},
	PlayerCard = {
		label = "PLAYER CARDS",
		displayName = "Player Cards",
		accent = Color3.fromRGB(65, 145, 255),
		backgroundImageId = "114901680198720",
	},
	ChatGradient = {
		label = "CHAT GRADIENTS",
		displayName = "Chat Gradients",
		accent = Color3.fromRGB(180, 100, 220),
		backgroundImageId = "86108890273439",
	},
}

ShopConstants.SHOP_CARDS = {
	{ id = "GunSkin", label = "GUN SKINS", accent = Color3.fromRGB(220, 75, 75), backgroundImageId = "139076761632435" },
	{ id = "PlayerCard", label = "PLAYER CARDS", accent = Color3.fromRGB(65, 145, 255), backgroundImageId = "97389410625853" },
	{ id = "ChatGradient", label = "CHAT GRADIENTS", accent = Color3.fromRGB(180, 100, 220), backgroundImageId = "115310168098188" },
}

return ShopConstants
