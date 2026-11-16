--!strict

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Network = require(MainModule.Shared.Network)
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
local Tab = require(script.Parent.Tab)
local Modals = require(script.Parent.Parent.Modals)
local AssetPreloader = require(MainModule.Shared.Utils.Loading.AssetPreloader)
local Constants = require(script.Constants)
local Tabs = require(script.Tabs)
local GradientBackground = require(script.Parent.Shop.Components.GradientBackground)
local UISound = require(script.Parent.UISound)
local MenuNavigation = require(script.Parent.MenuNavigation)
local Profile = require(MainModule.Shared.Utils.Debug.Profile)
local Signal = require(MainModule.Shared.Utils.State.Signal)

type FusionScope = Types.FusionScope
type FusionValue<T> = Types.FusionValue<T>
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

local peek = Fusion.peek

export type PersistedMenuState = {
	currentTab: number,
	shopCurrentPage: number,
	shopCurrentTab: string,
	inventoryCurrentTab: number,
	selectedBundleKey: string?,
	selectedPackId: string?,
	selectedSkinId: string?,
	selectedCardId: string?,
	settingsSearchQuery: string?,
}

export type MenuProps = {
	Visible: FusionCanBeState<boolean>,
	Settings: SettingsConfig.SettingsTemplate?,
	OnSettingChange: ((string, any) -> ())?,
	OnKeybindChange: ((string, string) -> ())?,
	OnKeybindEditStart: (() -> ())?,
	OnKeybindEditEnd: (() -> ())?,
	OnResetSettings: (() -> ())?,
	OnImportSettings: ((any) -> ())?,
	OnClose: (() -> ())?,
	InitialState: PersistedMenuState?,
	OnStateChange: ((PersistedMenuState) -> ())?,
	OnCursorEquip: ((cursorId: number) -> ())?,
	OnCursorToggleRadial: ((cursorId: number) -> ())?,
	SettingChanged: Signal.Signal<string, any>?,
}

local PERSISTENT_TABS: { [number]: true } = { [1] = true, [5] = true, [6] = true }

local function Menu(scope: FusionScope, props: MenuProps): ScreenGui
	UISound.init()
	table.insert(scope, UISound.cleanup)

	local initialState = props.InitialState or {
		currentTab = 1,
		shopCurrentPage = 1,
		shopCurrentTab = "featured",
		inventoryCurrentTab = 1,
		selectedBundleKey = nil,
		selectedPackId = nil,
		selectedSkinId = nil,
		selectedCardId = nil,
		settingsSearchQuery = "",
	}

	local startTarget = MenuNavigation.takeTarget()
	if startTarget then
		initialState = table.clone(initialState)
		initialState.currentTab = 2
		initialState.shopCurrentPage = 2
		if startTarget == "Crates" then
			initialState.shopCurrentTab = "crates"
		end
	end

	local currentTab = scope:Value(initialState.currentTab)
	local modalVisible = scope:Value(false)
	local modalKeybindName = scope:Value("")
	local modalKeybindKey = scope:Value("")
	local activeKeybindState: FusionValue<string>? = nil
	local keybindUpdateTrigger = scope:Value(0)
	local shopResetTrigger = scope:Value(0)
	local shopCurrentPage: FusionValue<number> = scope:Value(initialState.shopCurrentPage)
	local shopCurrentTab: FusionValue<string> = scope:Value(initialState.shopCurrentTab)
	local inventoryCurrentTab: FusionValue<number> = scope:Value(initialState.inventoryCurrentTab)
	local selectedBundleKey: FusionValue<string?> = scope:Value(initialState.selectedBundleKey)
	local selectedPackId: FusionValue<string?> = scope:Value(initialState.selectedPackId)
	local selectedSkinId: FusionValue<string?> = scope:Value(initialState.selectedSkinId)
	local selectedCardId: FusionValue<string?> = scope:Value(initialState.selectedCardId)

	local searchQuery = scope:Value(initialState.settingsSearchQuery or "")

	local function saveState()
		if props.OnStateChange then
			props.OnStateChange({
				currentTab = peek(currentTab),
				shopCurrentPage = peek(shopCurrentPage),
				shopCurrentTab = peek(shopCurrentTab),
				inventoryCurrentTab = peek(inventoryCurrentTab),
				selectedBundleKey = peek(selectedBundleKey),
				selectedPackId = peek(selectedPackId),
				selectedSkinId = peek(selectedSkinId),
				selectedCardId = peek(selectedCardId),
				settingsSearchQuery = peek(searchQuery),
			})
		end
	end

	local ownedItems: FusionValue<{ [string]: boolean }> = scope:Value({})
	local equippedItems: FusionValue<{ [string]: any }> = scope:Value({})

	local function parseOwnedState(state: any): { [string]: boolean }
		local owned: { [string]: boolean } = {}
		if state and state.owned then
			for _, itemIds in state.owned do
				if type(itemIds) == "table" then
					for _, itemId in itemIds do
						owned[itemId] = true
					end
				end
			end
		end
		return owned
	end

	local function parseEquippedState(state: any): { [string]: any }
		local equipped: { [string]: any } = {}
		if state and state.equipped then
			for category, value in state.equipped do
				equipped[category] = value
			end
		end
		return equipped
	end

	local scopeAlive = true

	local cosmeticFetchThread = task.spawn(function()
		local state = Network.Cosmetic.getState()
		if state and scopeAlive then
			ownedItems:set(parseOwnedState(state))
			equippedItems:set(parseEquippedState(state))
			AssetPreloader.preloadFromCosmeticState(state)
		end
	end)

	local cosmeticConnection = Network.Cosmetic.onStateUpdated(function(state)
		if not scopeAlive then return end
		if state then
			ownedItems:set(parseOwnedState(state))
			equippedItems:set(parseEquippedState(state))
			AssetPreloader.preloadFromCosmeticState(state)
		end
	end)
	table.insert(scope, function()
		if cosmeticConnection then
			cosmeticConnection:Disconnect()
		end
	end)

	local function handlePurchaseSuccess(cosmeticType: string, newState: Network.CosmeticState?)
		if not scopeAlive then return end
		if newState then
			ownedItems:set(parseOwnedState(newState))
			equippedItems:set(parseEquippedState(newState))
		end

		local inventoryTabIndex = 1
		if cosmeticType == "GunSkin" or cosmeticType == "Bundle" then
			inventoryTabIndex = 1
		elseif cosmeticType == "PlayerCard" then
			inventoryTabIndex = 2
		elseif cosmeticType == "ChatGradient" then
			inventoryTabIndex = 3
		end

		inventoryCurrentTab:set(inventoryTabIndex)
		currentTab:set(3)
	end

	local TAB_IDLE_DESTROY_SECONDS = 30
	local isRenderVisible = scope:Value(peek(props.Visible) == true)
	local closeAnimationThread: thread? = nil

	table.insert(scope, function()
		scopeAlive = false
		if closeAnimationThread then
			task.cancel(closeAnimationThread)
			closeAnimationThread = nil
		end
		if cosmeticFetchThread then
			task.cancel(cosmeticFetchThread)
			cosmeticFetchThread = nil
		end
	end)

	local settings = props.Settings or SettingsConfig.DefaultSettings
	local sharingModalVisible = scope:Value(false)

	local camera = workspace.CurrentCamera
	local screenWidth = scope:Value(camera.ViewportSize.X)
	local viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		screenWidth:set(camera.ViewportSize.X)
	end)
	table.insert(scope, function()
		viewportConn:Disconnect()
	end)

	local previewForcedToBottom = scope:Computed(function(use: FusionUseFn)
		return use(screenWidth) < Constants.MIN_PREVIEW_RIGHT_VIEWPORT_WIDTH
	end)

	local previewOnRightUserChoice = scope:Value((settings.Settings.PreviewPosition or 1) == 2)
	local previewOnRight = scope:Computed(function(use: FusionUseFn)
		if use(previewForcedToBottom) then return false end
		return use(previewOnRightUserChoice)
	end)

	local menuTransparencyValue = scope:Value(settings.Settings.MenuTransparency or 0)

	local originalOnSettingChange = props.OnSettingChange
	local function handleSettingChange(key: string, value: any)
		if key == "PreviewPosition" then
			previewOnRightUserChoice:set(value == 2)
		elseif key == "MenuTransparency" then
			menuTransparencyValue:set(value)
		end
		if originalOnSettingChange then
			originalOnSettingChange(key, value)
		end
	end

	local rightSidebarWidth = scope:Computed(function(use: FusionUseFn)
		return if use(previewOnRight) then Constants.RIGHT_SIDEBAR_WIDTH_RIGHT else Constants.RIGHT_SIDEBAR_WIDTH_BOTTOM
	end)

	local keybindStates: { [string]: FusionValue<string> } = {}

	local function openKeybindModal(name: string, keybindState: FusionValue<string>)
		modalKeybindName:set(name)
		modalKeybindKey:set(peek(keybindState))
		activeKeybindState = keybindState
		modalVisible:set(true)
		if props.OnKeybindEditStart then
			props.OnKeybindEditStart()
		end
	end

	local function closeKeybindModal()
		modalVisible:set(false)
		activeKeybindState = nil
		if props.OnKeybindEditEnd then
			props.OnKeybindEditEnd()
		end
	end

	local function saveKeybind(newKey: string)
		local name = peek(modalKeybindName)
		if props.OnKeybindChange and name ~= "" then
			props.OnKeybindChange(name, newKey)
		end
		if activeKeybindState then
			activeKeybindState:set(newKey)
		end
		keybindUpdateTrigger:set(peek(keybindUpdateTrigger) + 1)
		closeKeybindModal()
	end

	local currentKeybinds = scope:Computed(function(use: FusionUseFn)
		use(keybindUpdateTrigger)
		local result: { [string]: string } = {}
		for name, state in keybindStates do
			result[name] = peek(state)
		end
		return result
	end)

	local tabButtons: { Instance } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for i, tabName in Constants.TABS do
		local isSelected = scope:Computed(function(use: FusionUseFn)
			return use(currentTab) == i
		end)

		local tab = Tab(scope, {
			Text = tabName,
			IsSelected = isSelected,
			LayoutOrder = i,
			IsFirst = i == 1,
			IsLast = i == #Constants.TABS,
			OnClick = function()
				if i == 2 and peek(currentTab) == 2 then
					shopResetTrigger:set(peek(shopResetTrigger) + 1)
				elseif peek(currentTab) ~= i then
					currentTab:set(i)
					UISound.play("Swipe")
				end
			end,
		})

		table.insert(tabButtons, tab)
	end

	local tabScopes: { [number]: any } = {}
	local tabInstances: { [number]: Instance } = {}

	local function createTabContent(tabScope: any, tabIndex: number): Instance?
		if tabIndex == 1 then
			return Profile.run("Vultar::Menu::Settings::build", Tabs.Settings, tabScope, {
				Visible = tabScope:Computed(function(use: FusionUseFn)
					return use(currentTab) == 1 and use(isRenderVisible)
				end),
				Settings = settings,
				SearchQuery = searchQuery,
				PreviewOnRight = previewOnRight,
				PreviewForcedToBottom = previewForcedToBottom,
				RightSidebarWidth = rightSidebarWidth,
				SharingModalVisible = sharingModalVisible,
				OnSettingChange = handleSettingChange,
				OnResetSettings = props.OnResetSettings,
				OnCursorEquip = props.OnCursorEquip,
				OnCursorToggleRadial = props.OnCursorToggleRadial,
				SettingChanged = props.SettingChanged,
			})
		elseif tabIndex == 2 then
			return Tabs.Shop(tabScope, {
				Visible = tabScope:Computed(function(use: FusionUseFn)
					return use(currentTab) == 2 and use(isRenderVisible)
				end),
				OwnedItems = ownedItems,
				EquippedItems = equippedItems,
				ResetTrigger = shopResetTrigger,
				CurrentPage = shopCurrentPage,
				CurrentTab = shopCurrentTab,
				SelectedBundleKey = selectedBundleKey,
				SelectedPackId = selectedPackId,
				SelectedSkinId = selectedSkinId,
				SelectedCardId = selectedCardId,
				OnPurchaseSuccess = handlePurchaseSuccess,
			})
		elseif tabIndex == 3 then
			return Tabs.Inventory(tabScope, {
				Visible = tabScope:Computed(function(use: FusionUseFn)
					return use(currentTab) == 3 and use(isRenderVisible)
				end),
				OwnedItems = ownedItems,
				EquippedItems = equippedItems,
				CurrentTab = inventoryCurrentTab,
			})
		elseif tabIndex == 4 then
			return Tabs.Avatar(tabScope, {
				Visible = tabScope:Computed(function(use: FusionUseFn)
					return use(currentTab) == 4 and use(isRenderVisible)
				end),
			})
		elseif tabIndex == 5 then
			return Profile.run("Vultar::Menu::Keybinds::build", Tabs.Keybinds, tabScope, {
				Visible = tabScope:Computed(function(use: FusionUseFn)
					return use(currentTab) == 5 and use(isRenderVisible)
				end),
				Settings = settings,
				KeybindStates = keybindStates,
				OnKeybindClick = openKeybindModal,
			})
		elseif tabIndex == 6 then
			return Profile.run("Vultar::Menu::Rules::build", Tabs.Rules, tabScope, {
				Visible = tabScope:Computed(function(use: FusionUseFn)
					return use(currentTab) == 6 and use(isRenderVisible)
				end),
			})
		end
		return nil
	end

	local tabContentContainer = scope:Value({} :: { Instance })

	local function syncTabChildren(): ()
		local children: { Instance } = {}
		for _, instance in tabInstances do
			table.insert(children, instance)
		end
		tabContentContainer:set(children)
	end

	local function destroyIdleTabs(): ()
		if not scopeAlive then return end
		local scopesToClean: { any } = {}
		for tabIndex, tabScope in tabScopes do
			if not PERSISTENT_TABS[tabIndex] then
				table.insert(scopesToClean, tabScope)
				tabScopes[tabIndex] = nil
				tabInstances[tabIndex] = nil
			end
		end
		if #scopesToClean == 0 then return end
		syncTabChildren()
		for _, s in scopesToClean do
			s:doCleanup()
		end
	end

	local function ensureTabCreated(tabIndex: number): ()
		if not scopeAlive then return end
		if tabInstances[tabIndex] then
			return
		end

		local ok, tabScope = pcall(scope.innerScope, scope)
		if not ok then return end

		local contentOk, content = pcall(createTabContent, tabScope, tabIndex)
		if not contentOk or not content then
			pcall(function()
				tabScope:doCleanup()
			end)
			return
		end

		tabScopes[tabIndex] = tabScope
		tabInstances[tabIndex] = content
		syncTabChildren()
	end

	scope:Observer(currentTab):onChange(function()
		local tab = peek(currentTab)
		ensureTabCreated(tab)
		saveState()
	end)

	local navigationConnection = MenuNavigation.Requested:Connect(function(target: MenuNavigation.Target)
		MenuNavigation.takeTarget()
		currentTab:set(2)
		shopCurrentPage:set(2)
		if target == "Crates" then
			shopCurrentTab:set("crates")
		end
	end)
	table.insert(scope, function()
		navigationConnection:Disconnect()
	end)

	scope:Observer(shopCurrentPage):onChange(saveState)
	scope:Observer(shopCurrentTab):onChange(saveState)
	scope:Observer(inventoryCurrentTab):onChange(saveState)
	scope:Observer(selectedBundleKey):onChange(saveState)
	scope:Observer(selectedPackId):onChange(saveState)
	scope:Observer(selectedSkinId):onChange(saveState)
	scope:Observer(selectedCardId):onChange(saveState)
	scope:Observer(searchQuery):onChange(saveState)

	local menuVisible = scope:Computed(function(use: FusionUseFn)
		return use(props.Visible)
	end)

	local isCrateTabOpen = scope:Computed(function(use: FusionUseFn)
		return use(menuVisible) and use(currentTab) == 2 and use(shopCurrentTab) == "crates"
	end)

	scope:Observer(isCrateTabOpen):onBind(function()
		if not scopeAlive then return end
		UISound.setCrateTabActive(peek(isCrateTabOpen))
	end)

	scope:Observer(menuVisible):onBind(function()
		if not scopeAlive then return end
		local visible = peek(menuVisible)

		if closeAnimationThread then
			task.cancel(closeAnimationThread)
			closeAnimationThread = nil
		end

		if visible then
			isRenderVisible:set(true)
			ensureTabCreated(peek(currentTab))
			UISound.fadeInBackground()
		else
			sharingModalVisible:set(false)
			modalVisible:set(false)
			UISound.fadeOutBackground()
			closeAnimationThread = task.delay(0.4, function()
				if not scopeAlive then return end
				isRenderVisible:set(false)
				task.wait(TAB_IDLE_DESTROY_SECONDS)
				if not scopeAlive then return end
				destroyIdleTabs()
				closeAnimationThread = nil
			end)
		end
	end)

	local menuPositionTarget = scope:Computed(function(use: FusionUseFn)
		local vis = use(menuVisible)
		return vis and UDim2.new(0.5, 0, 0.5, Theme.TopBar.Height / 2 + 4) or UDim2.fromScale(0.5, 1.5)
	end)

	local menuPosition = scope:Spring(menuPositionTarget, Theme.Spring.Gentle.Speed, Theme.Spring.Gentle.Damping)

	local keybindModal = Modals.Keybind(scope, {
		Visible = modalVisible,
		KeybindName = modalKeybindName,
		CurrentKey = modalKeybindKey,
		CurrentKeybinds = currentKeybinds,
		OnSave = saveKeybind,
		OnCancel = closeKeybindModal,
	})

	local settingsSharingModal = Modals.SettingsSharing(scope, {
		Visible = sharingModalVisible,
		OnClose = function()
			sharingModalVisible:set(false)
		end,
		OnImportSuccess = function(newSettings: any)
			if props.OnImportSettings then
				props.OnImportSettings(newSettings)
			end
		end,
	})

	local topBarPositionTarget = scope:Computed(function(use: FusionUseFn)
		return if use(menuVisible) then UDim2.fromOffset(0, 0) else UDim2.fromOffset(0, -Theme.TopBar.Height)
	end)
	local topBarPosition = scope:Spring(topBarPositionTarget, Theme.Spring.Snappy.Speed, Theme.Spring.Snappy.Damping)

	local backgroundTransparency = scope:Value(1)
	local backgroundTweenProxy = Instance.new("NumberValue")
	backgroundTweenProxy.Value = 1
	local backgroundTween: Tween? = nil
	local backgroundTweenConn: RBXScriptConnection? = nil

	local function updateBackgroundTransparency()
		local targetValue = if peek(menuVisible) then peek(menuTransparencyValue) else 1
		if backgroundTween then
			backgroundTween:Cancel()
		end
		if backgroundTweenConn then
			backgroundTweenConn:Disconnect()
		end
		backgroundTweenProxy.Value = peek(backgroundTransparency)
		backgroundTween = TweenService:Create(backgroundTweenProxy, Theme.Tween.Default, { Value = targetValue })
		backgroundTweenConn = backgroundTweenProxy:GetPropertyChangedSignal("Value"):Connect(function()
			backgroundTransparency:set(backgroundTweenProxy.Value)
		end)
		backgroundTween:Play()
	end

	scope:Observer(menuVisible):onChange(updateBackgroundTransparency)
	scope:Observer(menuTransparencyValue):onChange(function()
		if peek(menuVisible) then
			backgroundTransparency:set(peek(menuTransparencyValue))
		end
	end)

	table.insert(scope, function()
		if backgroundTween then
			backgroundTween:Cancel()
		end
		if backgroundTweenConn then
			backgroundTweenConn:Disconnect()
		end
		backgroundTweenProxy:Destroy()
	end)

	local isStoreTab = scope:Computed(function(use: FusionUseFn)
		return use(currentTab) == 2
	end)

	local STORE_TAB_BACKGROUNDS: { [string]: Color3 } = {
		featured = Color3.fromRGB(1, 34, 69),
		skins = Color3.fromRGB(28, 28, 32),
		cards = Color3.fromRGB(1, 34, 69),
		gradients = Color3.fromRGB(45, 35, 65),
	}

	local backgroundColorTarget = scope:Computed(function(use: FusionUseFn)
		if use(isStoreTab) then
			local tab = use(shopCurrentTab)
			local page = use(shopCurrentPage)
			if tab == "featured" and page == 1 then
				return Color3.fromRGB(0, 0, 0)
			end
			return STORE_TAB_BACKGROUNDS[tab] or STORE_TAB_BACKGROUNDS.featured
		end
		return Theme.MenuBackground.Background
	end)
	local backgroundColor = scope:Spring(backgroundColorTarget, 25, 1.2)

	local patternTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isStoreTab) then 1 else Theme.MenuBackground.PatternTransparency
		end),
		30, 1.2
	)

	return scope:New("ScreenGui")({
		Name = "VultarSettingsMenu",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 100000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			scope:New("CanvasGroup")({
				Name = "BackgroundLayer",
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0, 0),
				BackgroundColor3 = backgroundColor,
				BorderSizePixel = 0,
				Visible = isRenderVisible,
				ZIndex = 0,
				GroupTransparency = backgroundTransparency,

				[Fusion.Children] = {
					scope:New("ImageLabel")({
						Name = "PatternImage",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Image = Theme.MenuBackground.Pattern,
						ImageColor3 = Theme.MenuBackground.PatternColor,
						ImageTransparency = patternTransparency,
						ScaleType = Enum.ScaleType.Tile,
						TileSize = UDim2.fromOffset(Theme.MenuBackground.PatternTileSize, Theme.MenuBackground.PatternTileSize),
						ZIndex = 0,
					}),

					scope:New("CanvasGroup")({
						Name = "StoreGradientContainer",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Visible = isStoreTab,
						GroupTransparency = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								local tab = use(shopCurrentTab)
								local page = use(shopCurrentPage)
								if tab == "featured" then
									return if page == 1 then 0.25 else 0.4
								elseif tab == "cards" then
									return 0.55
								else
									return 0.4
								end
							end),
							25, 1.2
						),
						ZIndex = 1,

						[Fusion.Children] = {
							GradientBackground(scope, {
								Visible = true,
								CurrentTab = shopCurrentTab,
								CurrentPage = shopCurrentPage,
							}),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "TopBar",
				Size = UDim2.new(1, 0, 0, Theme.TopBar.Height),
				Position = topBarPosition,
				BackgroundColor3 = Theme.TopBar.Background,
				BackgroundTransparency = Theme.TopBar.BackgroundTransparency,
				BorderSizePixel = 0,
				ZIndex = 2,
				Visible = isRenderVisible,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "TabsContainer",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("Frame")({
								Name = "Tabs",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,

								[Fusion.Children] = tabButtons,
							}),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "MenuContainer",
				Size = UDim2.new(0.98, 0, 0.88, -Theme.TopBar.Height),
				Position = menuPosition,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Visible = isRenderVisible,
				ZIndex = 1,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "Content",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						ClipsDescendants = true,

						[Fusion.Children] = tabContentContainer,
					}),
				},
			}),

			keybindModal,
			settingsSharingModal,
		},
	})
end

return Menu
