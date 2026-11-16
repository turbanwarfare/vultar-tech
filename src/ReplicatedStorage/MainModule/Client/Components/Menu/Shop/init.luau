--!native
--!optimize 2

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Core = require(MainModule.Shared.Network.Core)
local Network = require(MainModule.Shared.Network)

local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Scale = require(MainModule.Client.Utils.Scaling.Scale)
local Packs = require(MainModule.Shared.Config.Cosmetics.Packs)
local GunSkinsConfig = require(MainModule.Shared.Config.Cosmetics.Items.GunSkins)
local PlayerCardsConfig = require(MainModule.Shared.Config.Cosmetics.Items.PlayerCards)
local StoreHubRedirects = require(MainModule.Shared.Config.StoreHubRedirects)
local CratesConfig = require(MainModule.Shared.Config.Cosmetics.Crates)
local EconomyConfig = require(MainModule.Shared.Config.Economy.EconomyConfig)
local MenuNavigation = require(script.Parent.MenuNavigation)
local CosmeticLookup = require(script.Cache.CosmeticLookup)
local PriceCache = require(script.Cache.PriceCache)

local ShopConstants = require(script.ShopConstants)
local BundleDetailPage = require(script.Components.BundleDetailPage)
local HelloKittyBundleShowcase = require(script.Components.HelloKittyBundleShowcase)
local PackCard = require(script.Components.PackCard)
local PackDetailPage = require(script.Components.PackDetailPage)
local PageSidebar = require(script.Components.PageSidebar)
local StoreTabBar = require(script.Components.StoreTabBar)
local SkinPreview = require(script.Components.SkinPreview)
local CardPreview = require(script.Components.CardPreview)
local StoreHubRedirectPrompt = require(script.Components.StoreHubRedirectPrompt)
local CratePreview = require(script.Components.CratePreview)
local CrateOpeningOverlay = require(script.Components.CrateOpening)
local CreditsDisplay = require(script.Components.CreditsDisplay)
local BuyCreditsModal = require(script.Components.BuyCreditsModal)
local CratesPage = require(script.Pages.CratesPage)
local PurchaseRedirectController = require(script.PurchaseRedirectController)
local GunSkinsPage = require(script.Pages.GunSkinsPage)
local BundleSettings = require(script.BundleSettings)

local TeleportToHubEvent: RemoteEvent = Core.getOrCreateRemoteEvent("TeleportToHub")

local TRANSPARENCY_NUM_SEQ = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0.2),
	NumberSequenceKeypoint.new(1, 0.8),
})
local PlayerCardsPage = require(script.Pages.PlayerCardsPage)
local UISound = require(script.Parent.UISound)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionValue<T> = Types.FusionValue<T>
type BundleItem = BundleDetailPage.BundleItem
type PackConfig = Packs.PackConfig

type SkinData = {
	id: string,
	name: string,
	gamepassId: number,
}

type CardData = {
	id: string,
	name: string,
	imageId: string,
	gamepassId: number,
	isAnimated: boolean,
}

export type ShopGridProps = ShopConstants.ShopGridProps & {
	CurrentPage: FusionValue<number>?,
	CurrentTab: FusionValue<string>?,
}

local BUNDLES_ENABLED = true

local TITLE_BASE_SIZE = 48
local PADDING_BASE = 48
local PANEL_GAP = 24
local TITLE_HEIGHT = 60

local PAGE_COUNT = 2
local PAGE_TITLES = {
	"HELLO KITTY WEAPON BUNDLE",
	"COSMETIC PACKS",
}

local STORE_TABS: { StoreTabBar.TabConfig } = {
	{ id = "featured", label = "FEATURED" },
	{ id = "crates", label = "CRATES" },
	{ id = "skins", label = "SKINS" },
	{ id = "cards", label = "PLAYER CARDS" },
}

local TAB_BAR_HEIGHT = 44
local STORE_TITLE_HEIGHT = 50

local camera = workspace.CurrentCamera

local PACK_CARD_BASE_HEIGHT = 320
local PACK_GRID_GAP = 12

local function getPacksPerRow(): number
	if not camera then
		return 5
	end
	local width = camera.ViewportSize.X
	if width < 1400 then
		return 3
	end
	if width < 1800 then
		return 4
	end
	return 5
end

local function getScaledPackHeight(): number
	if not camera then
		return PACK_CARD_BASE_HEIGHT
	end
	local height = camera.ViewportSize.Y
	local scale = math.clamp((height - 600) / 600, 0.7, 1.0)
	return math.floor(PACK_CARD_BASE_HEIGHT * scale)
end

type BundleData = {
	name: string,
	gamepassId: number,
	items: { BundleItem },
	showcaseCards: { { imageId: string, label: string, animated: boolean } },
	showcaseGuns: { { skinId: string, gunName: string } },
}

local LAUNCH_BUNDLE: BundleData = {
	name = "LAUNCH BUNDLE",
	gamepassId = 1663742264,
	items = {
		{
			type = "PlayerCard",
			id = "Beast",
			name = "Beast",
			imageId = "rbxassetid://135895927269596",
			animated = false,
		},
		{
			type = "PlayerCard",
			id = "Cloud",
			name = "Cloud",
			imageId = "rbxassetid://127190345000261",
			animated = true,
		},
		{
			type = "GunSkin",
			id = "Beast_H82",
			name = "Beast",
			skinId = "Beast",
			gunName = "H-82",
			imageId = "rbxassetid://135895927269596",
		},
		{
			type = "GunSkin",
			id = "Volatil_H82",
			name = "Volatil",
			skinId = "Volatil",
			gunName = "H-82",
			imageId = "rbxassetid://122284747350886",
		},
		{
			type = "ChatGradient",
			id = "Inferno",
			name = "Inferno",
			gradientColors = {
				Color3.fromRGB(255, 60, 20),
				Color3.fromRGB(255, 140, 40),
				Color3.fromRGB(255, 200, 80),
				Color3.fromRGB(255, 140, 40),
				Color3.fromRGB(255, 60, 20),
				Color3.fromRGB(180, 30, 10),
				Color3.fromRGB(255, 60, 20),
			},
		},
	},
	showcaseCards = {
		{ imageId = "rbxassetid://135895927269596", label = "BEAST PLAYER CARD", animated = false },
		{ imageId = "rbxassetid://127190345000261", label = "CLOUD PLAYER CARD (ANIMATED)", animated = true },
	},
	showcaseGuns = {
		{ skinId = "Beast", gunName = "H-82" },
		{ skinId = "Volatil", gunName = "H-82" },
	},
}

local BEST_SELLER_BUNDLE: BundleData = {
	name = "BEST SELLER BUNDLE",
	gamepassId = 1661788677,
	items = {
		{
			type = "PlayerCard",
			id = "Digi",
			name = "Digi",
			imageId = "rbxassetid://116131194979543",
			animated = false,
		},
		{
			type = "PlayerCard",
			id = "Volatil",
			name = "Volatil",
			imageId = "rbxassetid://122284747350886",
			animated = false,
		},
		{
			type = "GunSkin",
			id = "Digi_H82",
			name = "Digi",
			skinId = "Digi",
			gunName = "H-82",
			imageId = "rbxassetid://116131194979543",
		},
		{
			type = "GunSkin",
			id = "Volatil_H82",
			name = "Volatil",
			skinId = "Volatil",
			gunName = "H-82",
			imageId = "rbxassetid://122284747350886",
		},
		{
			type = "ChatGradient",
			id = "Blizzard",
			name = "Blizzard",
			gradientColors = {
				Color3.fromRGB(255, 255, 255),
				Color3.fromRGB(200, 230, 255),
				Color3.fromRGB(140, 200, 255),
				Color3.fromRGB(100, 180, 240),
				Color3.fromRGB(140, 200, 255),
				Color3.fromRGB(200, 230, 255),
				Color3.fromRGB(255, 255, 255),
			},
		},
	},
	showcaseCards = {
		{ imageId = "rbxassetid://116131194979543", label = "DIGI PLAYER CARD", animated = false },
		{ imageId = "rbxassetid://122284747350886", label = "VOLATIL PLAYER CARD", animated = false },
	},
	showcaseGuns = {
		{ skinId = "Digi", gunName = "H-82" },
		{ skinId = "Volatil", gunName = "H-82" },
	},
}

local SKIN_BUNDLE_WEAPON_ROSTER = {
	{ gunName = "H-82", className = "Assault" },
	{ gunName = "BR-16", className = "Assault" },
	{ gunName = "H-41", className = "Shocktrooper" },
	{ gunName = "BR-40", className = "Shocktrooper" },
	{ gunName = "H-94", className = "Devastator" },
	{ gunName = "BR-56", className = "Devastator" },
	{ gunName = "H-50", className = "Recon" },
	{ gunName = "BR-50", className = "Recon" },
	{ gunName = "H-22", className = "Flag Bearer" },
	{ gunName = "BR-22", className = "Flag Bearer" },
	{ gunName = "H-12", className = "Pistol" },
	{ gunName = "BR-8", className = "Pistol" },
}

local function buildSkinBundle(bundleKey: string): BundleData
	local settings = BundleSettings[bundleKey]
	local bannerImage = "rbxassetid://" .. tostring(settings.CardImage)

	local items: { BundleItem } = {}
	for _, weapon in SKIN_BUNDLE_WEAPON_ROSTER do
		table.insert(items, {
			type = "GunSkin",
			id = bundleKey .. "_" .. weapon.gunName,
			name = weapon.className,
			skinId = settings.Id,
			gunName = weapon.gunName,
			imageId = bannerImage,
		})
	end
	table.insert(items, {
		type = "PlayerCard",
		id = bundleKey .. "_Card",
		name = settings.Id,
		imageId = bannerImage,
		animated = false,
	})
	if not settings.NoChatGradient then
		table.insert(items, {
			type = "ChatGradient",
			id = bundleKey .. "_Gradient",
			name = settings.Id,
			gradientColors = settings.Gradient,
		})
	end

	return {
		name = settings.DisplayName,
		gamepassId = settings.BundleId,
		items = items,
		showcaseCards = {},
		showcaseGuns = {
			{ skinId = settings.Id, gunName = "H-82" },
			{ skinId = settings.Id, gunName = "BR-16" },
		},
	}
end

local BUNDLES: { [string]: BundleData } = {
	hellokitty = buildSkinBundle("HelloKitty"),
	vex = buildSkinBundle("Vex"),
	toxic = buildSkinBundle("Toxic"),
	freeze = buildSkinBundle("Freeze"),
	pixelgun = buildSkinBundle("PixelGun"),
	launch = LAUNCH_BUNDLE,
	bestseller = BEST_SELLER_BUNDLE,
}

local function buildGamepassLookup(): { [number]: string }
	local lookup: { [number]: string } = {}

	for _, bundle in BUNDLES do
		if bundle.gamepassId > 0 then
			lookup[bundle.gamepassId] = "Bundle"
		end
	end

	for _, pack in Packs.getAllPacks() do
		if pack.gamepassId > 0 then
			lookup[pack.gamepassId] = "Pack"
		end
	end

	for _, skin in GunSkinsConfig do
		if skin.purchaseGamepassId and skin.purchaseGamepassId > 0 then
			lookup[skin.purchaseGamepassId] = "GunSkin"
		end
	end

	for _, card in PlayerCardsConfig do
		if card.purchaseGamepassId and card.purchaseGamepassId > 0 then
			lookup[card.purchaseGamepassId] = "PlayerCard"
		end
	end

	return lookup
end

local GAMEPASS_COSMETIC_TYPE = buildGamepassLookup()

local function createPackGrid(
	scope: FusionScope,
	packs: { PackConfig },
	onPackClick: (pack: PackConfig) -> (),
	canvasPosition: FusionValue<Vector2>,
	scrollingEnabled: FusionValue<boolean>
): ScrollingFrame
	local packsPerRow = scope:Value(getPacksPerRow())
	local packHeight = scope:Value(getScaledPackHeight())

	if camera then
		local viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			packsPerRow:set(getPacksPerRow())
			packHeight:set(getScaledPackHeight())
		end)
		table.insert(scope, function()
			viewportConnection:Disconnect()
		end)
	end

	local cellWidthScale = scope:Computed(function(use: FusionUseFn)
		local perRow = use(packsPerRow)
		return (1 - (perRow - 1) * 0.012) / perRow
	end)

	local gridChildren: { Instance } = {
		scope:New("UIGridLayout")({
			CellSize = scope:Computed(function(use: FusionUseFn)
				return UDim2.new(use(cellWidthScale), 0, 0, use(packHeight))
			end),
			CellPadding = UDim2.new(0.012, 0, 0, PACK_GRID_GAP),
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirectionMaxCells = scope:Computed(function(use: FusionUseFn)
				return use(packsPerRow)
			end),
		}),
	}

	for i, pack in packs do
		local skinId = pack.collection
		for _, item in pack.items do
			if item.category == "GunSkin" then
				skinId = item.id
				break
			end
		end

		local card = PackCard(scope, {
			PackId = pack.id,
			PackName = pack.name,
			SkinId = skinId,
			ImageId = pack.imageId,
			GamepassId = pack.gamepassId,
			LayoutOrder = i,
			OnClick = function()
				onPackClick(pack)
			end,
		})
		table.insert(gridChildren, card)
	end

	local gridFrame = scope:New("Frame")({
		Name = "PackGridInner",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,

		[Fusion.Children] = gridChildren,
	})

	return scope:New("ScrollingFrame")({
		Name = "PackGrid",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90),
		ScrollBarImageTransparency = 0.3,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		CanvasPosition = canvasPosition,
		ScrollingEnabled = scrollingEnabled,

		[Fusion.OnChange("CanvasPosition")] = function(newPos)
			canvasPosition:set(newPos)
		end,

		[Fusion.Children] = {
			scope:New("UIPadding")({
				PaddingRight = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 20),
			}),
			gridFrame,
		},
	})
end

local function buildDetailContainer(scope: FusionScope, name: string, paddingUDim: any, child: Instance): Frame
	return scope:New("Frame")({
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			scope:New("UIPadding")({
				PaddingLeft = paddingUDim,
				PaddingTop = paddingUDim,
				PaddingRight = paddingUDim,
				PaddingBottom = paddingUDim,
			}),
			child,
		},
	})
end

type DetailPageCallbacks = {
	closeBundle: () -> (),
	closePack: () -> (),
	closeSkin: () -> (),
	closeCard: () -> (),
	closeCrate: () -> (),
	openCrateAction: (crate: CratesConfig.CrateConfig, amount: number) -> (),
}

local function resolveDetailPage(
	scope: FusionScope,
	use: FusionUseFn,
	selectedBundle: any,
	selectedPack: any,
	selectedSkin: any,
	selectedCard: any,
	selectedCrate: any,
	paddingUDim: any,
	ownedItems: any,
	callbacks: DetailPageCallbacks
): Frame?
	local crate = use(selectedCrate)
	if crate then
		return buildDetailContainer(
			scope,
			"CratePreviewContainer",
			paddingUDim,
			CratePreview(scope, {
				Crate = crate,
				OnBack = callbacks.closeCrate,
				OnOpen = callbacks.openCrateAction,
				OwnedItems = ownedItems,
			})
		)
	end

	local bundleKey = use(selectedBundle)
	if bundleKey then
		local bundle = BUNDLES[bundleKey]
		if bundle then
			return buildDetailContainer(
				scope,
				"DetailPageContainer",
				paddingUDim,
				BundleDetailPage(scope, {
					BundleName = bundle.name,
					GamepassId = bundle.gamepassId,
					Items = bundle.items,
					OnBack = callbacks.closeBundle,
				})
			)
		end
	end

	local pack = use(selectedPack)
	if pack then
		local skinId = pack.collection
		for _, item in pack.items do
			if item.category == "GunSkin" then
				skinId = item.id
				break
			end
		end
		return buildDetailContainer(
			scope,
			"PackDetailContainer",
			paddingUDim,
			PackDetailPage(scope, {
				PackName = pack.name,
				PackId = pack.id,
				SkinId = skinId,
				ImageId = pack.imageId,
				GamepassId = pack.gamepassId,
				OnBack = callbacks.closePack,
			})
		)
	end

	local skin = use(selectedSkin)
	if skin then
		return buildDetailContainer(
			scope,
			"SkinPreviewContainer",
			paddingUDim,
			SkinPreview(scope, {
				SkinId = skin.id,
				SkinName = skin.name or skin.id,
				GamepassId = skin.purchaseGamepassId or 0,
				OnBack = callbacks.closeSkin,
			})
		)
	end

	local card = use(selectedCard)
	if card then
		return buildDetailContainer(
			scope,
			"CardPreviewContainer",
			paddingUDim,
			CardPreview(scope, {
				CardId = card.id,
				CardName = card.name or card.id,
				ImageId = card.imageId or "",
				GamepassId = card.purchaseGamepassId or 0,
				IsAnimated = card.isAnimated or false,
				OnBack = callbacks.closeCard,
			})
		)
	end

	return nil
end

local function ShopGrid(scope: FusionScope, props: ShopGridProps): Frame
	local currentStoreTab: FusionValue<string> = props.CurrentTab or scope:Value("featured")
	local currentPage: FusionValue<number> = props.CurrentPage or scope:Value(1)
	if not BUNDLES_ENABLED and Fusion.peek(currentPage) == 1 then
		currentPage:set(2)
	end

	local selectedBundleKey: FusionValue<string?> = props.SelectedBundleKey or scope:Value(nil)
	local selectedPackId: FusionValue<string?> = props.SelectedPackId or scope:Value(nil)
	local selectedSkinId: FusionValue<string?> = props.SelectedSkinId or scope:Value(nil)
	local selectedCardId: FusionValue<string?> = props.SelectedCardId or scope:Value(nil)
	local selectedCrateId: FusionValue<string?> = scope:Value(nil)

	local isShopAlive = true
	table.insert(scope, function()
		isShopAlive = false
	end)

	local creditsBalance: FusionValue<number> = scope:Value(Network.Economy.getCachedBalance())
	local balanceConn = Network.Economy.onBalanceUpdated(function(newBalance: number)
		if isShopAlive then
			creditsBalance:set(newBalance)
		end
	end)
	table.insert(scope, function()
		balanceConn:Disconnect()
	end)

	local paidRandomItemsAllowed: FusionValue<boolean> = scope:Value(false)
	task.spawn(function()
		local fetched = Network.Economy.requestBalance()
		if isShopAlive then
			creditsBalance:set(fetched)
		end

		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(Players.LocalPlayer)
		end)
		if isShopAlive and ok and typeof(info) == "table" and info.ArePaidRandomItemsRestricted == false then
			paidRandomItemsAllowed:set(true)
		end
	end)

	local selectedBundle = selectedBundleKey
	local redirectPromptGamepassId: FusionValue<number?> = scope:Value(nil)
	local redirectStatusText: FusionValue<string> = scope:Value("")
	local redirectTeleporting: FusionValue<boolean> = scope:Value(false)
	local redirectPromptVisible = scope:Computed(function(use: FusionUseFn)
		return use(redirectPromptGamepassId) ~= nil
	end)

	local function openPurchaseRedirectPrompt(gamepassId: number)
		redirectPromptGamepassId:set(gamepassId)
		redirectStatusText:set("")
		redirectTeleporting:set(false)
	end

	local function closePurchaseRedirectPrompt()
		if Fusion.peek(redirectTeleporting) then
			return
		end

		redirectPromptGamepassId:set(nil)
		redirectStatusText:set("")
	end

	local function teleportToStoreHub()
		if Fusion.peek(redirectTeleporting) then
			return
		end

		local gamepassId = Fusion.peek(redirectPromptGamepassId)
		if not gamepassId then
			return
		end

		local hub = StoreHubRedirects.getHubForGamepass(gamepassId)
		if not hub then
			redirectStatusText:set("This item is not mapped to a store hub yet.")
			return
		end
		if hub.placeId <= 0 then
			redirectStatusText:set("This store hub needs a place ID in StoreHubRedirects.")
			return
		end

		redirectTeleporting:set(true)
		redirectStatusText:set("")
		TeleportToHubEvent:FireServer(gamepassId)
	end

	PurchaseRedirectController.setPromptHandler(openPurchaseRedirectPrompt)
	table.insert(scope, function()
		PurchaseRedirectController.clearPromptHandler(openPurchaseRedirectPrompt)
	end)

	local selectedPack: FusionValue<PackConfig?> = scope:Computed(function(use: FusionUseFn)
		local packId = use(selectedPackId)
		if not packId then
			return nil
		end
		return CosmeticLookup.getPackById(packId)
	end) :: any

	local selectedSkin: FusionValue<SkinData?> = scope:Computed(function(use: FusionUseFn)
		local skinId = use(selectedSkinId)
		if not skinId then
			return nil
		end
		return CosmeticLookup.getSkinById(skinId)
	end) :: any

	local selectedCard: FusionValue<CardData?> = scope:Computed(function(use: FusionUseFn)
		local cardId = use(selectedCardId)
		if not cardId then
			return nil
		end
		return CosmeticLookup.getCardById(cardId)
	end) :: any

	local selectedCrate: FusionValue<CratesConfig.CrateConfig?> = scope:Computed(function(use: FusionUseFn)
		local crateId = use(selectedCrateId)
		if not crateId then
			return nil
		end
		return CratesConfig.getCrateById(crateId)
	end) :: any

	local isMouseOver = scope:Value(false)
	local page2Loaded = scope:Value(Fusion.peek(currentPage) == 2)

	local packGridCanvasPos = scope:Value(Vector2.zero)
	local packGridScrollingEnabled = scope:Value(true)

	local allPacks = Packs.getAllPacks()

	local titleSize = scope:Computed(function(use: FusionUseFn)
		return math.round(use(Scale.get()) * TITLE_BASE_SIZE)
	end)

	local padding = scope:Computed(function(use: FusionUseFn)
		return math.round(use(Scale.get()) * PADDING_BASE)
	end)

	local paddingUDim = scope:Computed(function(use: FusionUseFn)
		return UDim.new(0, use(padding))
	end)

	local halfPaddingUDim = scope:Computed(function(use: FusionUseFn)
		return UDim.new(0, use(padding) * 0.5)
	end)

	local panelGap = scope:Computed(function(use: FusionUseFn)
		return math.round(use(Scale.get()) * PANEL_GAP)
	end)

	local page1Title = scope:Value(PAGE_TITLES[1])
	local page1BundleKey: FusionValue<string?> = scope:Value(nil)
	local page1AccentColor = scope:Computed(function(use: FusionUseFn)
		local bundleKey = use(page1BundleKey)
		local settings = bundleKey and BundleSettings[bundleKey]
		return (settings and settings.TitleTextColor) or BundleSettings.Freeze.TitleTextColor
	end)
	local currentTitle = scope:Computed(function(use: FusionUseFn)
		local page = use(currentPage)
		if page == 1 then
			return use(page1Title)
		end
		return PAGE_TITLES[page] or ""
	end)

	local isDetailView = scope:Computed(function(use: FusionUseFn)
		return use(selectedBundle) ~= nil or use(selectedPack) ~= nil or use(selectedSkin) ~= nil or use(selectedCard) ~= nil or use(selectedCrate) ~= nil
	end)

	local page1OffsetY = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(currentPage) == 1 then 0 else -20
		end),
		25,
		1
	)

	local page2OffsetY = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(currentPage) == 2 then 0 else 20
		end),
		25,
		1
	)

	local function closeBundle()
		selectedBundleKey:set(nil)
	end

	local function openPack(pack: PackConfig)
		selectedPackId:set(pack.id)
	end

	local function closePack()
		selectedPackId:set(nil)
	end

	local function openSkin(skin: SkinData)
		selectedSkinId:set(skin.id)
	end

	local function closeSkin()
		selectedSkinId:set(nil)
	end

	local function openCard(card: CardData)
		selectedCardId:set(card.id)
	end

	local function closeCard()
		selectedCardId:set(nil)
	end

	local function openCrate(crate: CratesConfig.CrateConfig)
		selectedCrateId:set(crate.id)
	end

	local function closeCrate()
		selectedCrateId:set(nil)
	end

	local activeOpeningCrate = scope:Value(nil :: CratesConfig.CrateConfig?)
	local openingResults = scope:Value(nil :: { CratesConfig.RollResult }?)
	local openingRefund = scope:Value(0)
	local openingError = scope:Value(nil :: string?)
	local isBuyCreditsOpen = scope:Value(false)
	if MenuNavigation.consumeBuyCredits() then
		isBuyCreditsOpen:set(true)
	end
	local navigationConnection = MenuNavigation.Requested:Connect(function(target: MenuNavigation.Target)
		if target == "BuyCredits" then
			MenuNavigation.consumeBuyCredits()
			isBuyCreditsOpen:set(true)
		end
	end)
	table.insert(scope, function()
		navigationConnection:Disconnect()
	end)

	local function startOpenCrate(crateToOpen: CratesConfig.CrateConfig, amount: number)
		activeOpeningCrate:set(crateToOpen)
		openingResults:set(nil)
		openingRefund:set(0)
		openingError:set(nil)

		task.spawn(function()
			local response = Network.Crate.openCrate(crateToOpen.id, amount)
			if not isShopAlive then
				return
			end
			if response.success and response.results then
				openingRefund:set(response.totalRefund or 0)
				openingResults:set(response.results)
			else
				openingError:set(response.error or "Failed to open crate")
			end
		end)
	end

	local purchaseConnection = MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
		if player ~= Players.LocalPlayer then
			return
		end

		if not wasPurchased then
			return
		end

		local cosmeticType = GAMEPASS_COSMETIC_TYPE[gamepassId]
		if not cosmeticType then
			return
		end

		selectedBundleKey:set(nil)
		selectedPackId:set(nil)
		selectedSkinId:set(nil)
		selectedCardId:set(nil)
		selectedCrateId:set(nil)

		if props.OnPurchaseSuccess then
			local typeToSend = if cosmeticType == "Pack" then "GunSkin" else cosmeticType
			props.OnPurchaseSuccess(typeToSend, nil)
		end
	end)

	table.insert(scope, function()
		purchaseConnection:Disconnect()
	end)

	local function changePage(newPage: number)
		local minPage = if BUNDLES_ENABLED then 1 else 2
		if newPage >= minPage and newPage <= PAGE_COUNT and newPage ~= Fusion.peek(currentPage) then
			currentPage:set(newPage)
			UISound.play("Swipe")
			if newPage == 2 then
				if not Fusion.peek(page2Loaded) then
					page2Loaded:set(true)
				end
				packGridScrollingEnabled:set(false)
				task.delay(0.5, function()
					packGridScrollingEnabled:set(true)
				end)
			end
		end
	end

	local function changeStoreTab(tabId: string)
		if tabId ~= Fusion.peek(currentStoreTab) then
			currentStoreTab:set(tabId)
			UISound.play("Swipe")
			if tabId == "featured" then
				currentPage:set(if BUNDLES_ENABLED then 1 else 2)
			end
		end
	end

	local isFeaturedTab = scope:Computed(function(use: FusionUseFn)
		return use(currentStoreTab) == "featured"
	end)

	local lastScrollTime = 0

	local scrollConnection = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseWheel then
			return
		end
		if not Fusion.peek(isMouseOver) then
			return
		end
		if Fusion.peek(isDetailView) then
			return
		end

		local current = Fusion.peek(currentPage)
		if input.Position.Z > 0 then
			if current == 2 then
				local pos = Fusion.peek(packGridCanvasPos)
				if pos.Y > 5 then
					lastScrollTime = os.clock()
					return
				end
				if os.clock() - lastScrollTime < 0.15 then
					return
				end
			end
			changePage(current - 1)
		elseif input.Position.Z < 0 then
			changePage(current + 1)
		end
	end)

	table.insert(scope, function()
		scrollConnection:Disconnect()
	end)

	table.insert(scope, function()
		PriceCache.cancelAllPending()
	end)

	return scope:New("Frame")({
		Name = "ShopContainer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.OnEvent("MouseEnter")] = function()
			isMouseOver:set(true)
		end,
		[Fusion.OnEvent("MouseLeave")] = function()
			isMouseOver:set(false)
		end,

		[Fusion.Children] = {
			scope:New("ScrollingFrame")({
				Name = "ScrollSink",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				CanvasSize = UDim2.fromScale(1, 1),
				ScrollingEnabled = true,
				ScrollBarThickness = 0,
				ZIndex = 0,
			}),

			scope:New("Frame")({
				Name = "StoreHeader",
				Size = UDim2.new(1, 0, 0, STORE_TITLE_HEIGHT + TAB_BAR_HEIGHT + 20),
				Position = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				ZIndex = 10,
				Visible = scope:Computed(function(use: FusionUseFn)
					return not use(isDetailView)
				end),

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "HeaderBackground",
						Size = UDim2.new(1, -32, 1, -8),
						Position = UDim2.fromOffset(16, 4),
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 0.6,
						ZIndex = 0,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 16) }),
							scope:New("UIGradient")({
								Rotation = 90,
								Transparency = TRANSPARENCY_NUM_SEQ,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "HeaderContent",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						ZIndex = 1,

						[Fusion.Children] = {
							scope:New("UIPadding")({
								PaddingLeft = paddingUDim,
								PaddingRight = paddingUDim,
								PaddingTop = halfPaddingUDim,
							}),

							CreditsDisplay(scope, {
								Balance = creditsBalance,
								Position = UDim2.new(1, 0, 0, 5),
								Visible = paidRandomItemsAllowed,
								ShowAddCredits = #EconomyConfig.CREDIT_PRODUCTS > 0,
								OnAddCredits = function()
									isBuyCreditsOpen:set(true)
								end,
								OnClick = function()
									if #EconomyConfig.CREDIT_PRODUCTS > 0 then
										isBuyCreditsOpen:set(true)
									end
								end,
							}),

							scope:New("TextLabel")({
								Name = "StoreTitle",
								Size = UDim2.new(1, 0, 0, STORE_TITLE_HEIGHT),
								BackgroundTransparency = 1,
								Text = "STORE",
								TextColor3 = Theme.Colors.White,
								TextSize = 42,
								Font = Enum.Font.GothamBlack,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Center,
							}),

							scope:New("Frame")({
								Name = "TabBarContainer",
								Size = UDim2.new(1, 0, 0, TAB_BAR_HEIGHT),
								Position = UDim2.fromOffset(170, 14),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									StoreTabBar(scope, {
										Tabs = STORE_TABS,
										CurrentTab = currentStoreTab,
										OnTabChange = changeStoreTab,
									}),
								},
							}),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "TabContent",
				Size = scope:Computed(function(use: FusionUseFn)
					if use(isDetailView) then
						return UDim2.fromScale(1, 1)
					end
					return UDim2.new(1, 0, 1, -(STORE_TITLE_HEIGHT + TAB_BAR_HEIGHT))
				end),
				Position = scope:Computed(function(use: FusionUseFn)
					if use(isDetailView) then
						return UDim2.fromOffset(0, 0)
					end
					return UDim2.fromOffset(0, STORE_TITLE_HEIGHT + TAB_BAR_HEIGHT)
				end),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "FeaturedContent",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Visible = scope:Computed(function(use: FusionUseFn)
							return use(isFeaturedTab) and not use(isDetailView)
						end),

						[Fusion.Children] = {
							scope:New("UIPadding")({
								PaddingLeft = paddingUDim,
								PaddingTop = halfPaddingUDim,
								PaddingRight = paddingUDim,
								PaddingBottom = paddingUDim,
							}),

							scope:New("Frame")({
								Name = "TitleSection",
								Size = UDim2.new(1, 0, 0, TITLE_HEIGHT + 20),
								Position = UDim2.fromOffset(0, 0),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									scope:New("TextLabel")({
										Name = "HeroTitle",
										Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
										BackgroundTransparency = 1,
										Text = currentTitle,
										TextColor3 = Theme.Colors.White,
										TextSize = titleSize,
										Font = Enum.Font.GothamBlack,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Top,
										TextTruncate = Enum.TextTruncate.AtEnd,
									}),

									scope:New("TextLabel")({
										Name = "Subtitle",
										Size = UDim2.new(1, 0, 0, 20),
										Position = UDim2.fromOffset(0, TITLE_HEIGHT - 8),
										BackgroundTransparency = 1,
										Text = "Get matching gun skins and player cards together at a discount",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextSize = 14,
										Font = Enum.Font.GothamMedium,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextTransparency = scope:Spring(
											scope:Computed(function(use: FusionUseFn)
												return if use(currentPage) == 2 then 0 else 1
											end),
											40,
											1
										),
									}),
								},
							}),

							scope:New("Frame")({
								Name = "Page1_Bundles",
								Size = scope:Computed(function(use: FusionUseFn)
									return UDim2.new(1, 0, 1, -TITLE_HEIGHT - use(panelGap))
								end),
								Position = scope:Computed(function(use: FusionUseFn)
									local offsetY = use(page1OffsetY)
									return UDim2.fromOffset(0, TITLE_HEIGHT + use(panelGap) + offsetY)
								end),
								BackgroundTransparency = 1,
								Visible = scope:Computed(function(use: FusionUseFn)
									return BUNDLES_ENABLED and use(currentPage) == 1
								end),

								[Fusion.Children] = {
									HelloKittyBundleShowcase(scope, { TitleOut = page1Title, BundleKeyOut = page1BundleKey }),

									scope:New("Frame")({
										Name = "BottomBar",
										Size = UDim2.new(1, 0, 0, 48),
										Position = UDim2.new(0.5, 0, 1, -52),
										AnchorPoint = Vector2.new(0.5, 0),
										BackgroundTransparency = 1,

										[Fusion.Children] = {
											scope:New("UIListLayout")({
												FillDirection = Enum.FillDirection.Horizontal,
												HorizontalAlignment = Enum.HorizontalAlignment.Center,
												VerticalAlignment = Enum.VerticalAlignment.Center,
												Padding = UDim.new(0, 12),
												SortOrder = Enum.SortOrder.LayoutOrder,
											}),

											scope:New("TextButton")({
												Name = "ViewBundle",
												Size = UDim2.fromOffset(220, 44),
												BackgroundColor3 = page1AccentColor,
												BackgroundTransparency = 0.1,
												Text = "VIEW BUNDLE CONTENTS",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextSize = 15,
												Font = Enum.Font.GothamBlack,
												AutoButtonColor = true,
												LayoutOrder = 1,

												[Fusion.Children] = {
													scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
													scope:New("UIStroke")({
														Color = scope:Computed(function(use: FusionUseFn)
															return use(page1AccentColor):Lerp(Color3.new(1, 1, 1), 0.35)
														end),
														Thickness = 1.5,
														Transparency = 0.4,
													}),
												},

												[Fusion.OnEvent("Activated")] = function()
													local bundleKey = Fusion.peek(page1BundleKey)
													selectedBundleKey:set(bundleKey and string.lower(bundleKey) or "hellokitty")
												end,
											}),

											scope:New("TextButton")({
												Name = "PurchaseBundle",
												Size = UDim2.fromOffset(180, 44),
												BackgroundColor3 = scope:Computed(function(use: FusionUseFn)
													return use(page1AccentColor):Lerp(Color3.new(0, 0, 0), 0.3)
												end),
												BackgroundTransparency = 0.05,
												LayoutOrder = 2,
												Text = "PURCHASE",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextSize = 15,
												Font = Enum.Font.GothamBlack,
												AutoButtonColor = true,

												[Fusion.Children] = {
													scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
												},

												[Fusion.OnEvent("Activated")] = function()
													local bundleKey = Fusion.peek(page1BundleKey)
													local settings = bundleKey and BundleSettings[bundleKey]
													PurchaseRedirectController.promptPurchase(settings and settings.BundleId)
												end,
											}),
										},
									}),
								},
							}),

							scope:New("Frame")({
								Name = "Page2_CosmeticPacks",
								Size = scope:Computed(function(use: FusionUseFn)
									return UDim2.new(1, 0, 1, -TITLE_HEIGHT - use(panelGap) - 20)
								end),
								Position = scope:Computed(function(use: FusionUseFn)
									if not BUNDLES_ENABLED then
										return UDim2.fromOffset(0, TITLE_HEIGHT + use(panelGap) + 40)
									end
									local offsetY = use(page2OffsetY)
									return UDim2.fromOffset(0, TITLE_HEIGHT + use(panelGap) + 40 + offsetY)
								end),
								BackgroundTransparency = 1,
								Visible = scope:Computed(function(use: FusionUseFn)
									return not BUNDLES_ENABLED or use(currentPage) == 2
								end),

								[Fusion.Children] = {
									scope:Computed(function(use: FusionUseFn)
										if use(page2Loaded) then
											return createPackGrid(scope, allPacks, openPack, packGridCanvasPos, packGridScrollingEnabled)
										end
										return nil
									end),
								},
							}),

							if BUNDLES_ENABLED
								then PageSidebar(scope, {
									PageCount = PAGE_COUNT,
									CurrentPage = currentPage,
									OnPageChange = changePage,
								})
								else nil,
						},
					}),

					scope:New("Frame")({
						Name = "CratesContent",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Visible = scope:Computed(function(use: FusionUseFn)
							return use(currentStoreTab) == "crates" and not use(isDetailView)
						end),

						[Fusion.Children] = {
							scope:Computed(function(use: FusionUseFn)
								if use(paidRandomItemsAllowed) then
									return CratesPage.create(scope, {
										Padding = padding,
										OnCrateClick = openCrate,
									})
								end
								return scope:New("TextLabel")({
									Name = "CratesUnavailable",
									Size = UDim2.fromScale(1, 1),
									BackgroundTransparency = 1,
									Text = "Crates are not available for your account.",
									TextColor3 = Theme.Colors.White,
									TextTransparency = 0.4,
									TextSize = 18,
									Font = Enum.Font.GothamMedium,
								})
							end),
						},
					}),

					scope:New("Frame")({
						Name = "SkinsContent",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Visible = scope:Computed(function(use: FusionUseFn)
							return use(currentStoreTab) == "skins" and not use(isDetailView)
						end),

						[Fusion.Children] = {
							GunSkinsPage.create(scope, {
								Padding = padding,
								OnSkinClick = openSkin,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "CardsContent",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Visible = scope:Computed(function(use: FusionUseFn)
							return use(currentStoreTab) == "cards" and not use(isDetailView)
						end),

						[Fusion.Children] = {
							PlayerCardsPage.create(scope, {
								Padding = padding,
								OnCardClick = openCard,
							}),
						},
					}),
				},
			}),

			scope:Computed(function(use: FusionUseFn, pageScope: FusionScope)
				return resolveDetailPage(pageScope, use, selectedBundle, selectedPack, selectedSkin, selectedCard, selectedCrate, paddingUDim, props.OwnedItems, {
					closeBundle = closeBundle,
					closePack = closePack,
					closeSkin = closeSkin,
					closeCard = closeCard,
					closeCrate = closeCrate,
					openCrateAction = startOpenCrate,
				})
			end),

			scope:Computed(function(use: FusionUseFn, overlayScope: FusionScope)
				local crateToOpen = use(activeOpeningCrate)
				if crateToOpen then
					return CrateOpeningOverlay(overlayScope, {
						Crate = crateToOpen,
						Results = openingResults,
						TotalRefund = openingRefund,
						ErrorMessage = openingError,
						OnClose = function()
							activeOpeningCrate:set(nil)
							openingResults:set(nil)
							openingRefund:set(0)
							openingError:set(nil)
						end,
					})
				end
				return nil
			end),

			scope:Computed(function(use: FusionUseFn, modalScope: FusionScope)
				if use(isBuyCreditsOpen) and use(paidRandomItemsAllowed) then
					return BuyCreditsModal(modalScope, {
						OnClose = function()
							isBuyCreditsOpen:set(false)
						end,
						ZIndex = 40,
					})
				end
				return nil
			end),

			StoreHubRedirectPrompt(scope, {
				Visible = redirectPromptVisible,
				GamepassId = redirectPromptGamepassId,
				Teleporting = redirectTeleporting,
				StatusText = redirectStatusText,
				OnTakeMeThere = teleportToStoreHub,
				OnStayHere = closePurchaseRedirectPrompt,
			}),
		},
	})
end

return ShopGrid
