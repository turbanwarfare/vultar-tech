--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Tabs = require(script.Parent.Tabs)
local GunSkinsContent = require(script.Parent.GunSkinsContent)
local PlayerCardsContent = require(script.Parent.PlayerCardsContent)
local ChatGradientsContent = require(script.Parent.ChatGradientsContent)
local UISound = require(script.Parent.UISound)
local GunSkinUtils = require(script.Parent.GunSkinUtils)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionValue<T> = Types.FusionValue<T>

export type InventoryProps = {
	OwnedItems: FusionValue<{ [string]: boolean }>?,
	EquippedItems: FusionValue<{ [string]: any }>?,
	CurrentTab: FusionValue<number>?,
}

local INVENTORY_TABS = { "Gun Skins", "Player Cards", "Chat Gradients" }

local SIDEBAR_WIDTH = 150
local CARD_GAP = 8
local CARDS_PER_ROW = 4
local CONTENT_WIDTH = 880
local GRID_PADDING = 8
local AVAILABLE_GRID_WIDTH = CONTENT_WIDTH - (GRID_PADDING * 2)
local CARD_WIDTH = (AVAILABLE_GRID_WIDTH - (CARD_GAP * (CARDS_PER_ROW - 1))) // CARDS_PER_ROW
local CARD_HEIGHT = 110

local VULTAR_ICON = "rbxassetid://98751546690059"
local HOSTILES_ICON = "rbxassetid://0"

local SIDEBAR_GRADIENT_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.new(0.5, 0.5, 0.5)),
})

local GUN_CLASSES = {
	{ name = "Assault", vultarian = "H-82", hostile = "BR-16" },
	{ name = "Shocktrooper", vultarian = "H-41", hostile = "BR-40" },
	{ name = "Devastator", vultarian = "H-94", hostile = "BR-56" },
	{ name = "Recon", vultarian = "H-50", hostile = "BR-50" },
	{ name = "Flag Bearer", vultarian = "H-22", hostile = "BR-22" },
	{ name = "Pistol", vultarian = "H-12", hostile = "BR-8" },
}

local function createSidebarButton(
	scope: FusionScope,
	classInfo: { name: string, vultarian: string, hostile: string },
	index: number,
	currentGunIndex: FusionValue<number>,
	currentFaction: FusionValue<string>,
	faction: string
): Frame
	local isSelected = scope:Computed(function(use: FusionUseFn)
		return use(currentFaction) == faction and use(currentGunIndex) == index
	end)

	local isHovered = scope:Value(false)

	local accentColor = if faction == "Vultarian"
		then Theme.Inventory.Faction.Vultarian
		else Theme.Inventory.Faction.Hostile

	local gunName = if faction == "Vultarian" then classInfo.vultarian else classInfo.hostile

	local textColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isSelected) then
				return Color3.fromRGB(255, 255, 255)
			elseif use(isHovered) then
				return Color3.fromRGB(220, 220, 225)
			end
			return Color3.fromRGB(160, 160, 170)
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local xOffset = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isSelected) or use(isHovered) then 4 else 0
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	return scope:New("Frame")({
		Name = classInfo.name,
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		LayoutOrder = index,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Background",
				Size = UDim2.fromScale(1, 1),
				Position = scope:Computed(function(use: FusionUseFn)
					return UDim2.fromOffset(use(xOffset), 0)
				end),
				BackgroundColor3 = accentColor,
				BackgroundTransparency = scope:Spring(
					scope:Computed(function(use: FusionUseFn)
						if use(isSelected) then
							return 0.85
						elseif use(isHovered) then
							return 0.92
						end
						return 1
					end),
					Theme.Spring.Snappy.Speed,
					Theme.Spring.Snappy.Damping
				),
				BorderSizePixel = 0,
				ClipsDescendants = true,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, 4),
					}),

					scope:New("UIGradient")({
						Color = SIDEBAR_GRADIENT_SEQUENCE,
						Rotation = 90,
					}),

					scope:New("ImageLabel")({
						Name = "Stripes",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = Theme.Patterns.DiagonalStripes.Fat,
						ImageColor3 = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								if use(isSelected) then
									return accentColor
								elseif use(isHovered) then
									return Color3.fromRGB(70, 70, 75)
								end
								return Color3.fromRGB(50, 50, 55)
							end),
							Theme.Spring.Snappy.Speed,
							Theme.Spring.Snappy.Damping
						),
						ImageTransparency = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								if use(isSelected) then
									return 0
								elseif use(isHovered) then
									return 0.5
								end
								return 1
							end),
							Theme.Spring.Snappy.Speed,
							Theme.Spring.Snappy.Damping
						),
						ScaleType = Enum.ScaleType.Tile,
						TileSize = UDim2.fromOffset(64, 64),
						ZIndex = 2,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "Content",
				Size = UDim2.new(1, -16, 1, 0),
				Position = scope:Computed(function(use: FusionUseFn)
					return UDim2.fromOffset(8 + use(xOffset), 0)
				end),
				BackgroundTransparency = 1,
				ZIndex = 3,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "ClassName",
						Size = UDim2.new(1, 0, 0, 14),
						Position = UDim2.fromOffset(0, 7),
						BackgroundTransparency = 1,
						Text = string.upper(classInfo.name),
						TextColor3 = textColor,
						TextSize = 14,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),

					scope:New("TextLabel")({
						Name = "GunName",
						Size = UDim2.new(1, 0, 0, 11),
						Position = UDim2.fromOffset(0, 21),
						BackgroundTransparency = 1,
						Text = gunName,
						TextColor3 = scope:Computed(function(use: FusionUseFn)
							local base = use(textColor)
							return Color3.new(base.R * 0.6, base.G * 0.6, base.B * 0.6)
						end),
						TextSize = 11,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				},
			}),

			scope:New("TextButton")({
				Name = "Hitbox",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 10,

				[Fusion.OnEvent("MouseEnter")] = function()
					isHovered:set(true)
				end,

				[Fusion.OnEvent("MouseLeave")] = function()
					isHovered:set(false)
				end,

				[Fusion.OnEvent("Activated")] = function()
					currentFaction:set(faction)
					currentGunIndex:set(index)
				end,
			}),
		},
	})
end

local function createEquipAllButton(
	scope: FusionScope,
	faction: string,
	flashedFaction: FusionValue<string>,
	onActivated: () -> ()
): TextButton
	local accentColor = if faction == "Vultarian"
		then Theme.Inventory.Faction.Vultarian
		else Theme.Inventory.Faction.Hostile
	local isHovered = scope:Value(false)

	return scope:New("TextButton")({
		Name = "EquipAll",
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = accentColor,
		BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0.6 else 0.82
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		LayoutOrder = 2,
		Text = scope:Computed(function(use: FusionUseFn)
			return if use(flashedFaction) == faction then "EQUIPPED" else "EQUIP ALL"
		end),
		TextColor3 = Color3.fromRGB(235, 235, 240),
		TextSize = 11,
		Font = Theme.Text.Bold,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
			scope:New("UIStroke")({
				Color = accentColor,
				Thickness = 1,
				Transparency = 0.4,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		},

		[Fusion.OnEvent("MouseEnter")] = function()
			isHovered:set(true)
		end,
		[Fusion.OnEvent("MouseLeave")] = function()
			isHovered:set(false)
		end,
		[Fusion.OnEvent("Activated")] = onActivated,
	})
end

local function Inventory(scope: FusionScope, props: InventoryProps): Frame
	local currentTab = props.CurrentTab or scope:Value(1)
	local currentGunIndex = scope:Value(1)
	local currentFaction = scope:Value("Vultarian")

	local isGunSkinsSelected = scope:Computed(function(use: FusionUseFn)
		return use(currentTab) == 1
	end)

	local sidebarWidth = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isGunSkinsSelected) then SIDEBAR_WIDTH else 0
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local sidebarOpacity = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isGunSkinsSelected) then 1 else 0
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local tabButtons: { Instance } = {}

	for i, tabName in INVENTORY_TABS do
		local isSelected = scope:Computed(function(use: FusionUseFn)
			return use(currentTab) == i
		end)

		local tab = Tabs.Tab(scope, {
			Text = tabName,
			IsSelected = isSelected,
			LayoutOrder = i,
			Style = Tabs.Styles.Category,
			OnClick = function()
				if Fusion.peek(currentTab) ~= i then
					currentTab:set(i)
					UISound.play("Swipe")
				end
			end,
		})

		table.insert(tabButtons, tab)
	end

	local vultarianButtons: { Instance } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for i, classInfo in GUN_CLASSES do
		local button = createSidebarButton(scope, classInfo, i, currentGunIndex, currentFaction, "Vultarian")
		table.insert(vultarianButtons, button)
	end

	local hostileButtons: { Instance } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for i, classInfo in GUN_CLASSES do
		local button = createSidebarButton(scope, classInfo, i, currentGunIndex, currentFaction, "Hostile")
		table.insert(hostileButtons, button)
	end

	local currentGunName = scope:Computed(function(use: FusionUseFn)
		local faction = use(currentFaction)
		local index = use(currentGunIndex)
		local classInfo = GUN_CLASSES[index]
		if not classInfo then
			return "H-82"
		end
		if faction == "Vultarian" then
			return classInfo.vultarian
		else
			return classInfo.hostile
		end
	end)

	local currentClassName = scope:Computed(function(use: FusionUseFn)
		local index = use(currentGunIndex)
		local classInfo = GUN_CLASSES[index]
		return if classInfo then classInfo.name else "Assault"
	end)

	local flashedFaction = scope:Value("")
	local flashThread: thread? = nil

	table.insert(scope, function()
		if flashThread then
			task.cancel(flashThread)
			flashThread = nil
		end
	end)

	local function equipAll(faction: string): ()
		local gunNames: { string } = {}
		for _, classInfo in GUN_CLASSES do
			table.insert(gunNames, if faction == "Vultarian" then classInfo.vultarian else classInfo.hostile)
		end

		local equipped = if props.EquippedItems then Fusion.peek(props.EquippedItems) else nil
		local equippedSkins = if equipped and type(equipped.GunSkins) == "table" then equipped.GunSkins else nil
		local skinForCurrentGun = if equippedSkins then equippedSkins[Fusion.peek(currentGunName)] else nil
		local skinId = if skinForCurrentGun and skinForCurrentGun ~= "" then skinForCurrentGun else "Default"
		local ownedItems = if props.OwnedItems then Fusion.peek(props.OwnedItems) else nil

		GunSkinUtils.equipOnGuns(skinId, gunNames, ownedItems)
		UISound.play("Swipe")

		flashedFaction:set(faction)
		if flashThread then
			task.cancel(flashThread)
		end
		flashThread = task.delay(1.2, function()
			flashThread = nil
			flashedFaction:set("")
		end)
	end

	return scope:New("Frame")({
		Name = "Inventory",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 100),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "Title",
						Size = UDim2.new(1, 0, 0, 50),
						Position = UDim2.fromOffset(0, 12),
						BackgroundTransparency = 1,
						Text = "INVENTORY",
						TextColor3 = Theme.Inventory.Title.Text,
						TextSize = Theme.Inventory.Title.Size,
						Font = Theme.Inventory.Title.Font,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),

					scope:New("Frame")({
						Name = "TabsContainer",
						Size = UDim2.new(1, 0, 0, 32),
						Position = UDim2.fromOffset(0, 64),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								Padding = UDim.new(0, 0),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							tabButtons,
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "MainContent",
				Size = UDim2.new(1, 0, 1, -108),
				Position = UDim2.fromOffset(0, 108),
				BackgroundTransparency = 1,
				ClipsDescendants = true,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "CenteredContainer",
						Size = scope:Computed(function(use: FusionUseFn)
							local sw = use(sidebarWidth)
							return UDim2.new(0, sw + 16 + CONTENT_WIDTH, 1, 0)
						end),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("CanvasGroup")({
								Name = "Sidebar",
								Size = scope:Computed(function(use: FusionUseFn)
									return UDim2.new(0, use(sidebarWidth), 1, -12)
								end),
								Position = UDim2.fromOffset(0, 0),
								BackgroundTransparency = 1,
								GroupTransparency = scope:Computed(function(use: FusionUseFn)
									return 1 - use(sidebarOpacity)
								end),

								[Fusion.Children] = {
									scope:New("ScrollingFrame")({
										Name = "SidebarScroll",
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										ScrollBarThickness = 2,
										ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65),
										CanvasSize = UDim2.fromOffset(0, 0),
										AutomaticCanvasSize = Enum.AutomaticSize.Y,
										ScrollingDirection = Enum.ScrollingDirection.Y,
										BorderSizePixel = 0,

										[Fusion.Children] = {
											scope:New("UIPadding")({
												PaddingTop = UDim.new(0, 0),
												PaddingLeft = UDim.new(0, 0),
												PaddingRight = UDim.new(0, 8),
												PaddingBottom = UDim.new(0, 8),
											}),

											scope:New("UIListLayout")({
												FillDirection = Enum.FillDirection.Vertical,
												Padding = UDim.new(0, 16),
												SortOrder = Enum.SortOrder.LayoutOrder,
											}),

											scope:New("Frame")({
												Name = "VultarianSection",
												Size = UDim2.fromScale(1, 0),
												AutomaticSize = Enum.AutomaticSize.Y,
												BackgroundTransparency = 1,
												LayoutOrder = 1,

												[Fusion.Children] = {
													scope:New("UIListLayout")({
														FillDirection = Enum.FillDirection.Vertical,
														Padding = UDim.new(0, 8),
														SortOrder = Enum.SortOrder.LayoutOrder,
													}),

													scope:New("Frame")({
														Name = "Header",
														Size = UDim2.new(1, 0, 0, 24),
														BackgroundTransparency = 1,
														LayoutOrder = 0,

														[Fusion.Children] = {
															scope:New("ImageLabel")({
																Name = "Icon",
																Size = UDim2.fromOffset(22, 22),
																Position = UDim2.fromScale(0, 0.5),
																AnchorPoint = Vector2.new(0, 0.5),
																BackgroundTransparency = 1,
																Image = VULTAR_ICON,
																ImageColor3 = Theme.Inventory.Faction.Vultarian,
																ScaleType = Enum.ScaleType.Fit,
															}),

															scope:New("TextLabel")({
																Name = "Label",
																Size = UDim2.new(1, -28, 1, 0),
																Position = UDim2.fromOffset(28, 0),
																BackgroundTransparency = 1,
																Text = "VULTARIAN",
																TextColor3 = Theme.Inventory.Faction.Vultarian,
																TextSize = 13,
																Font = Theme.Text.Bold,
																TextXAlignment = Enum.TextXAlignment.Left,
																TextYAlignment = Enum.TextYAlignment.Center,
															}),
														},
													}),

													scope:New("Frame")({
														Name = "Buttons",
														Size = UDim2.fromScale(1, 0),
														AutomaticSize = Enum.AutomaticSize.Y,
														BackgroundTransparency = 1,
														LayoutOrder = 1,

														[Fusion.Children] = vultarianButtons,
													}),

													createEquipAllButton(scope, "Vultarian", flashedFaction, function()
														equipAll("Vultarian")
													end),
												},
											}),

											scope:New("Frame")({
												Name = "Divider",
												Size = UDim2.new(1, -8, 0, 1),
												Position = UDim2.fromOffset(0, 0),
												BackgroundColor3 = Color3.fromRGB(50, 50, 55),
												BorderSizePixel = 0,
												LayoutOrder = 2,
											}),

											scope:New("Frame")({
												Name = "HostileSection",
												Size = UDim2.fromScale(1, 0),
												AutomaticSize = Enum.AutomaticSize.Y,
												BackgroundTransparency = 1,
												LayoutOrder = 3,

												[Fusion.Children] = {
													scope:New("UIListLayout")({
														FillDirection = Enum.FillDirection.Vertical,
														Padding = UDim.new(0, 8),
														SortOrder = Enum.SortOrder.LayoutOrder,
													}),

													scope:New("Frame")({
														Name = "Header",
														Size = UDim2.new(1, 0, 0, 20),
														BackgroundTransparency = 1,
														LayoutOrder = 0,

														[Fusion.Children] = {
															scope:New("ImageLabel")({
																Name = "Icon",
																Size = UDim2.fromOffset(18, 18),
																Position = UDim2.fromScale(0, 0.5),
																AnchorPoint = Vector2.new(0, 0.5),
																BackgroundTransparency = 1,
																Image = HOSTILES_ICON,
																ImageColor3 = Theme.Inventory.Faction.Hostile,
																ScaleType = Enum.ScaleType.Fit,
															}),

															scope:New("TextLabel")({
																Name = "Label",
																Size = UDim2.new(1, -24, 1, 0),
																Position = UDim2.fromOffset(24, 0),
																BackgroundTransparency = 1,
																Text = "HOSTILE",
																TextColor3 = Theme.Inventory.Faction.Hostile,
																TextSize = 13,
																Font = Theme.Text.Bold,
																TextXAlignment = Enum.TextXAlignment.Left,
																TextYAlignment = Enum.TextYAlignment.Center,
															}),
														},
													}),

													scope:New("Frame")({
														Name = "Buttons",
														Size = UDim2.fromScale(1, 0),
														AutomaticSize = Enum.AutomaticSize.Y,
														BackgroundTransparency = 1,
														LayoutOrder = 1,

														[Fusion.Children] = hostileButtons,
													}),

													createEquipAllButton(scope, "Hostile", flashedFaction, function()
														equipAll("Hostile")
													end),
												},
											}),
										},
									}),
								},
							}),

							scope:New("Frame")({
								Name = "ContentArea",
								Size = UDim2.new(0, CONTENT_WIDTH, 1, 0),
								Position = scope:Computed(function(use: FusionUseFn)
									return UDim2.fromOffset(use(sidebarWidth) + 16, 0)
								end),
								BackgroundTransparency = 1,
								ClipsDescendants = true,

								[Fusion.Children] = {
									scope:New("Frame")({
										Name = "GunSkinsWrapper",
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Visible = scope:Computed(function(use: FusionUseFn)
											return use(currentTab) == 1
										end),

										[Fusion.Children] = {
											GunSkinsContent(scope, {
												CurrentGunName = currentGunName,
												CurrentClassName = currentClassName,
												OwnedItems = props.OwnedItems,
												EquippedItems = props.EquippedItems,
												CardWidth = CARD_WIDTH,
												CardHeight = CARD_HEIGHT,
												CardGap = CARD_GAP,
											}),
										},
									}),

									scope:New("Frame")({
										Name = "PlayerCardsWrapper",
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Visible = scope:Computed(function(use: FusionUseFn)
											return use(currentTab) == 2
										end),

										[Fusion.Children] = {
											PlayerCardsContent(scope, {
												OwnedItems = props.OwnedItems,
												EquippedItems = props.EquippedItems,
											}),
										},
									}),

									scope:New("Frame")({
										Name = "ChatGradientsWrapper",
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Visible = scope:Computed(function(use: FusionUseFn)
											return use(currentTab) == 3
										end),

										[Fusion.Children] = {
											ChatGradientsContent(scope, {
												OwnedItems = props.OwnedItems,
												EquippedItems = props.EquippedItems,
											}),
										},
									}),
								},
							}),
						},
					}),
				},
			}),
		},
	})
end

return Inventory
