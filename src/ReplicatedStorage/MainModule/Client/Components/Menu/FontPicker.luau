--!native
--!optimize 2

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)
local Profile = require(MainModule.Shared.Utils.Debug.Profile)

type FusionScope = Types.FusionScope
type FusionValue<T> = Types.FusionValue<T>
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

local peek: <T>(state: FusionCanBeState<T>) -> T = Fusion.peek

export type FontPickerProps = {
	Value: FusionCanBeState<string>,
	OnChange: ((string) -> ())?,
}

export type FontItem = {
	name: string,
	font: Enum.Font,
	displayName: string,
}

local function formatFontName(rawName: string): string
	local formatted = rawName:gsub("(%l)(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2")
	return formatted
end

local function getPlayerGui(): PlayerGui?
	local localPlayer = Players.LocalPlayer
	if localPlayer then
		return localPlayer:FindFirstChildOfClass("PlayerGui")
	end
	return nil
end

local EXCLUDED_FONTS: { [string]: boolean } = {
	AmaticSC = true,
	Antique = true,
	Arcade = true,
	Bangers = true,
	Bodoni = true,
	Cartoon = true,
	ComicNeue = true,
	Creepster = true,
	DenkOne = true,
	Fondamento = true,
	FredokaOne = true,
	Garamond = true,
	GrenzeGotisch = true,
	IndieFlower = true,
	Kalam = true,
	LuckiestGuy = true,
	PatrickHand = true,
	PermanentMarker = true,
	PressStart2P = true,
}

local DEFAULT_FONT_NAME = "GothamBold"
local DEFAULT_FONT_ITEM: FontItem = {
	name = "GothamBold",
	font = Enum.Font.GothamBold,
	displayName = "Gotham Bold",
}

local CUSTOM_FONTS: { FontItem } = {}
local ALL_FONTS: { FontItem } = {}
local FONT_INDEX_BY_NAME: { [string]: number } = {}

do
	local rawItems = Enum.Font:GetEnumItems()
	local tempCustom: { FontItem } = {}

	for _, item in rawItems do
		local name = item.Name
		if not EXCLUDED_FONTS[name] and name ~= DEFAULT_FONT_NAME then
			local displayName = formatFontName(name)
			table.insert(tempCustom, {
				name = name,
				font = item,
				displayName = displayName,
			})
		elseif name == DEFAULT_FONT_NAME then
			DEFAULT_FONT_ITEM = {
				name = name,
				font = item,
				displayName = formatFontName(name),
			}
		end
	end

	table.sort(tempCustom, function(a, b)
		return a.displayName:lower() < b.displayName:lower()
	end)

	CUSTOM_FONTS = tempCustom

	table.insert(ALL_FONTS, DEFAULT_FONT_ITEM)
	for _, item in CUSTOM_FONTS do
		table.insert(ALL_FONTS, item)
	end

	for i, fontItem in ALL_FONTS do
		FONT_INDEX_BY_NAME[fontItem.name] = i
	end
end

local function getFontItemByName(name: string?): FontItem
	if name and FONT_INDEX_BY_NAME[name] then
		return ALL_FONTS[FONT_INDEX_BY_NAME[name]]
	end
	return DEFAULT_FONT_ITEM
end

local BUTTON_HEIGHT = 22
local GAP = 2
local MODAL_WIDTH = 420
local MODAL_HEIGHT = 440
local ROW_HEIGHT = 38
local MODAL_FREE_DELAY = 0.6

local function createModal(
	scope: FusionScope,
	props: FontPickerProps,
	isModalOpen: FusionValue<boolean>,
	searchQuery: FusionValue<string>,
	closeModal: () -> ()
): TextBox
	local searchBoxRef: TextBox? = nil

	local inputConnection = UserInputService.InputBegan:Connect(function(input, _gameProcessed)
		if input.KeyCode == Enum.KeyCode.Escape and peek(isModalOpen) then
			closeModal()
		end
	end)
	table.insert(scope, function()
		inputConnection:Disconnect()
	end)

	local modalScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isModalOpen) then 1 else 0.95
		end),
		Theme.Spring.Snappy.Speed
	)

	local modalTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isModalOpen) then 0 else 1
		end),
		Theme.Spring.Snappy.Speed
	)

	local isDefaultMatching = scope:Computed(function(use: FusionUseFn)
		local query = use(searchQuery):lower():gsub("%s+", "")
		if query == "" then
			return true
		end
		local cleanName = DEFAULT_FONT_ITEM.name:lower()
		local cleanDisplay = DEFAULT_FONT_ITEM.displayName:lower():gsub("%s+", "")
		return cleanName:find(query, 1, true) ~= nil or cleanDisplay:find(query, 1, true) ~= nil
	end)

	local filteredCustomFonts = scope:Computed(function(use: FusionUseFn)
		local query = use(searchQuery):lower():gsub("%s+", "")
		if query == "" then
			return CUSTOM_FONTS
		end
		local results = {}
		for _, fontItem in CUSTOM_FONTS do
			local cleanName = fontItem.name:lower()
			local cleanDisplay = fontItem.displayName:lower():gsub("%s+", "")
			if cleanName:find(query, 1, true) or cleanDisplay:find(query, 1, true) then
				table.insert(results, fontItem)
			end
		end
		return results
	end)

	local hasCustomMatching = scope:Computed(function(use: FusionUseFn)
		local list = use(filteredCustomFonts)
		return #list > 0
	end)

	local totalMatchingCount = scope:Computed(function(use: FusionUseFn)
		local count = #use(filteredCustomFonts)
		if use(isDefaultMatching) then
			count += 1
		end
		return count
	end)

	local fontCountText = scope:Computed(function(use: FusionUseFn)
		return string.format("%d FONTS", use(totalMatchingCount))
	end)

	local function createFontRow(subScope: FusionScope, fontItem: FontItem, isVisible: FusionCanBeState<boolean>?): Frame
		local rowHovered = subScope:Value(false)

		local isSelected = subScope:Computed(function(use: FusionUseFn)
			return use(props.Value) == fontItem.name
		end)

		local rowBgColor = subScope:Computed(function(use: FusionUseFn)
			if use(isSelected) then
				return Theme.Background.Accent
			elseif use(rowHovered) then
				return Theme.Background.Overlay
			end
			return Theme.Background.Elevated
		end)

		local rowBorderColor = subScope:Computed(function(use: FusionUseFn)
			if use(isSelected) then
				return Theme.Colors.Success
			elseif use(rowHovered) then
				return Theme.Border.Active
			end
			return Theme.Border.Default
		end)

		local rowBorderTransparency = subScope:Computed(function(use: FusionUseFn)
			return if use(isSelected) or use(rowHovered) then 0 else 0.8
		end)

		local previewFont = subScope:Computed(function(use: FusionUseFn)
			return if use(isSelected) or use(rowHovered) then fontItem.font else Theme.Text.Regular
		end)

		return subScope:New("Frame")({
			Name = fontItem.name,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundColor3 = rowBgColor,
			BorderSizePixel = 0,
			Visible = isVisible,

			[Fusion.Children] = {
				subScope:New("UICorner")({
					CornerRadius = Theme.Radius.Medium,
				}),
				subScope:New("UIStroke")({
					Color = rowBorderColor,
					Thickness = 1,
					Transparency = rowBorderTransparency,
				}),
				subScope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				}),

				subScope:New("TextLabel")({
					Name = "FontName",
					Size = UDim2.fromScale(0.44, 1),
					BackgroundTransparency = 1,
					Text = fontItem.displayName,
					TextColor3 = subScope:Computed(function(use: FusionUseFn)
						return if use(isSelected) then Theme.Foreground.Primary else Theme.Foreground.Secondary
					end),
					TextSize = Theme.Text.Medium,
					Font = Theme.Text.Regular,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),

				subScope:New("Frame")({
					Name = "PreviewBadge",
					Size = UDim2.new(0.28, 0, 0, 24),
					Position = UDim2.fromScale(0.46, 0.5),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Theme.Background.Tertiary,
					BorderSizePixel = 0,

					[Fusion.Children] = {
						subScope:New("UICorner")({
							CornerRadius = Theme.Radius.Small,
						}),
						subScope:New("TextLabel")({
							Name = "SampleText",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = "123 DMG",
							TextColor3 = Color3.fromRGB(255, 75, 75),
							TextSize = 13,
							Font = previewFont,
							TextXAlignment = Enum.TextXAlignment.Center,

							[Fusion.Children] = {
								subScope:New("UIStroke")({
									Color = Color3.fromRGB(15, 15, 15),
									Thickness = 1.2,
								}),
							},
						}),
					},
				}),

				subScope:New("TextLabel")({
					Name = "EquippedLabel",
					Size = UDim2.fromOffset(68, ROW_HEIGHT),
					Position = UDim2.new(1, -68, 0, 0),
					BackgroundTransparency = 1,
					Text = "EQUIPPED",
					TextColor3 = Theme.Colors.Success,
					TextSize = 11,
					Font = Theme.Text.Bold,
					TextXAlignment = Enum.TextXAlignment.Right,
					Visible = isSelected,
				}),

				subScope:New("TextButton")({
					Name = "Hitbox",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "",
					AutoButtonColor = false,
					ZIndex = 5,

					[Fusion.OnEvent("MouseEnter")] = function()
						rowHovered:set(true)
					end,
					[Fusion.OnEvent("MouseLeave")] = function()
						rowHovered:set(false)
					end,
					[Fusion.OnEvent("Activated")] = function()
						if props.OnChange then
							props.OnChange(fontItem.name)
						end
					end,
				}),
			},
		})
	end

	local function createSectionHeader(headerScope: FusionScope, title: string, isVisible: FusionCanBeState<boolean>?): Frame
		return headerScope:New("Frame")({
			Name = "SectionHeader_" .. title:gsub("%s+", ""),
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			Visible = isVisible,

			[Fusion.Children] = {
				headerScope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, 4),
					PaddingTop = UDim.new(0, 4),
				}),
				headerScope:New("TextLabel")({
					Name = "Label",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = title,
					TextColor3 = Theme.Foreground.Muted,
					TextSize = 11,
					Font = Theme.Text.Bold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			},
		})
	end

	local fontRowsContainer = scope:New("ScrollingFrame")({
		Name = "FontListScroll",
		Size = UDim2.new(1, 0, 1, -100),
		Position = UDim2.fromOffset(0, 92),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Foreground.Muted,
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 8),
			}),

			createSectionHeader(scope, "DEFAULT", isDefaultMatching),
			createFontRow(scope, DEFAULT_FONT_ITEM, isDefaultMatching),
			createSectionHeader(scope, "CUSTOM FONTS", hasCustomMatching),
			scope:ForValues(filteredCustomFonts, function(_use: FusionUseFn, subScope: FusionScope, fontItem: FontItem)
				return createFontRow(subScope, fontItem)
			end),

			scope:New("TextLabel")({
				Name = "NoResults",
				Size = UDim2.new(1, 0, 0, 60),
				BackgroundTransparency = 1,
				Text = "No matching fonts found",
				TextColor3 = Theme.Foreground.Muted,
				TextSize = Theme.Text.Medium,
				Font = Theme.Text.Regular,
				TextXAlignment = Enum.TextXAlignment.Center,
				Visible = scope:Computed(function(use: FusionUseFn)
					return use(totalMatchingCount) == 0
				end),
			}),
		},
	})

	local searchBox = scope:New("TextBox")({
		Name = "SearchBox",
		Size = UDim2.new(1, -64, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		BackgroundTransparency = 1,
		PlaceholderText = "Search for font name",
		PlaceholderColor3 = Theme.Foreground.Muted,
		Text = searchQuery,
		TextColor3 = Theme.Foreground.Primary,
		TextSize = Theme.Text.Medium,
		Font = Theme.Text.Semibold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,

		[Fusion.OnEvent("FocusLost")] = function() end,
	})
	searchBoxRef = searchBox

	local searchConn = searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		searchQuery:set(searchBox.Text)
	end)
	table.insert(scope, function()
		searchConn:Disconnect()
	end)

	local _modalScreen = scope:New("ScreenGui")({
		Name = "DamageIndicatorFontPickerModal",
		AutoLocalize = false,
		DisplayOrder = 100005,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = isModalOpen,
		Parent = getPlayerGui(),

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Backdrop",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Modal.Overlay,
				BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
					return if use(isModalOpen) then Theme.Modal.OverlayTransparency else 1
				end),
				BorderSizePixel = 0,
				Active = true,
				ZIndex = 1,
			}),

			scope:New("Frame")({
				Name = "ModalCardContainer",
				Size = UDim2.fromOffset(MODAL_WIDTH, MODAL_HEIGHT),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 2,

				[Fusion.Children] = {
					scope:New("UIScale")({
						Scale = modalScale,
					}),

					Shadow(scope, {
						Size = UDim2.new(1, 16, 1, 16),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Spread = 0,
						Transparency = 0.65,
						ZIndex = 0,
					}),

					scope:New("CanvasGroup")({
						Name = "ModalCard",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Theme.Modal.Background,
						BackgroundTransparency = Theme.Modal.BackgroundTransparency,
						BorderSizePixel = 0,
						GroupTransparency = modalTransparency,
						ZIndex = 1,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = Theme.Radius.Large,
							}),
							scope:New("UIStroke")({
								Color = Theme.Modal.Border,
								Thickness = 1,
								Transparency = 0,
							}),

							scope:New("Frame")({
								Name = "Header",
								Size = UDim2.new(1, 0, 0, 44),
								BackgroundColor3 = Theme.Modal.Header,
								BackgroundTransparency = Theme.Modal.HeaderTransparency,
								BorderSizePixel = 0,

								[Fusion.Children] = {
									scope:New("UIPadding")({
										PaddingLeft = UDim.new(0, 16),
										PaddingRight = UDim.new(0, 12),
									}),
									scope:New("TextLabel")({
										Name = "Title",
										Size = UDim2.fromScale(0.65, 1),
										BackgroundTransparency = 1,
										Text = "DAMAGE INDICATOR FONTS",
										TextColor3 = Theme.Foreground.Primary,
										TextSize = Theme.Text.Medium,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
									scope:New("TextLabel")({
										Name = "CountBadge",
										Size = UDim2.fromScale(0.2, 1),
										Position = UDim2.fromScale(0.65, 0),
										BackgroundTransparency = 1,
										Text = fontCountText,
										TextColor3 = Theme.Foreground.Muted,
										TextSize = Theme.Text.Small,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Right,
									}),
									scope:New("TextButton")({
										Name = "CloseButton",
										Size = UDim2.fromOffset(26, 26),
										Position = UDim2.new(1, -26, 0.5, 0),
										AnchorPoint = Vector2.new(0, 0.5),
										BackgroundColor3 = Theme.Background.Overlay,
										BorderSizePixel = 0,
										Text = "X",
										TextColor3 = Theme.Foreground.Secondary,
										TextSize = 12,
										Font = Theme.Text.Bold,
										AutoButtonColor = false,

										[Fusion.Children] = {
											scope:New("UICorner")({
												CornerRadius = Theme.Radius.Small,
											}),
										},

										[Fusion.OnEvent("Activated")] = closeModal,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "SearchBar",
								Size = UDim2.new(1, -24, 0, 34),
								Position = UDim2.fromOffset(12, 50),
								BackgroundColor3 = Theme.Background.Secondary,
								BorderSizePixel = 0,

								[Fusion.Children] = {
									scope:New("UICorner")({
										CornerRadius = Theme.Radius.Medium,
									}),
									scope:New("UIStroke")({
										Color = Theme.Border.Default,
										Thickness = 1,
										Transparency = 0.4,
									}),
									searchBox,
									scope:New("TextButton")({
										Name = "ClearSearch",
										Size = UDim2.fromOffset(20, 20),
										Position = UDim2.new(1, -24, 0.5, 0),
										AnchorPoint = Vector2.new(0, 0.5),
										BackgroundTransparency = 1,
										Text = "X",
										TextColor3 = Theme.Foreground.Muted,
										TextSize = 10,
										Font = Theme.Text.Bold,
										Visible = scope:Computed(function(use: FusionUseFn)
											return use(searchQuery) ~= ""
										end),

										[Fusion.OnEvent("Activated")] = function()
											searchQuery:set("")
											if searchBoxRef then
												searchBoxRef.Text = ""
											end
										end,
									}),
								},
							}),

							fontRowsContainer,
						},
					}),
				},
			}),
		},
	})

	return searchBox
end

local function FontPicker(scope: FusionScope, props: FontPickerProps): Frame
	local isModalOpen = scope:Value(false)
	local searchQuery = scope:Value("")
	local searchBoxRef: TextBox? = nil
	local modalScope: FusionScope? = nil

	local isHovered = scope:Value(false)

	local currentFontItem = scope:Computed(function(use: FusionUseFn)
		local val = use(props.Value)
		return getFontItemByName(val)
	end)

	local currentFontEnum = scope:Computed(function(use: FusionUseFn)
		local item = use(currentFontItem)
		return item.font
	end)

	local currentDisplayNameUpper = scope:Computed(function(use: FusionUseFn)
		local item = use(currentFontItem)
		return string.upper(item.displayName)
	end)

	local function closeModal()
		isModalOpen:set(false)
		searchQuery:set("")
		local closingScope = modalScope
		task.delay(MODAL_FREE_DELAY, function()
			if closingScope and closingScope == modalScope and not peek(isModalOpen) then
				modalScope = nil
				searchBoxRef = nil
				Fusion.doCleanup(closingScope)
			end
		end)
	end

	local function openModal()
		if not modalScope then
			local newScope: FusionScope = Fusion.innerScope(scope)
			modalScope = newScope
			searchBoxRef = Profile.run("Vultar::Menu::FontPicker::modal", createModal, newScope, props, isModalOpen, searchQuery, closeModal)
		end
		searchQuery:set("")
		if peek(isModalOpen) then
			isModalOpen:set(false)
		end
		isModalOpen:set(true)
		task.defer(function()
			if searchBoxRef then
				searchBoxRef:CaptureFocus()
			end
		end)
	end

	local buttonBgColor = scope:Computed(function(use: FusionUseFn)
		return if use(isHovered) then Theme.Background.Accent else Theme.Background.Tertiary
	end)

	local innerButton = scope:New("TextButton")({
		Name = "FontPickerButton",
		Size = UDim2.fromOffset(140, BUTTON_HEIGHT),
		BackgroundColor3 = buttonBgColor,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Small,
			}),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 8),
			}),

			scope:New("TextLabel")({
				Name = "FontLabel",
				Size = UDim2.new(1, -18, 1, 0),
				BackgroundTransparency = 1,
				Text = currentDisplayNameUpper,
				TextColor3 = Theme.Foreground.Primary,
				TextSize = Theme.Text.Small,
				Font = currentFontEnum,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),

			scope:New("TextLabel")({
				Name = "Chevron",
				Size = UDim2.fromOffset(14, 14),
				Position = UDim2.new(1, -6, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Text = "^",
				Rotation = 180,
				TextColor3 = Theme.Foreground.Muted,
				TextSize = Theme.Text.Large,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		},

		[Fusion.OnEvent("MouseEnter")] = function()
			isHovered:set(true)
		end,
		[Fusion.OnEvent("MouseLeave")] = function()
			isHovered:set(false)
		end,
		[Fusion.OnEvent("Activated")] = openModal,
	})

	return scope:New("Frame")({
		Name = "SettingsPicker",
		Size = UDim2.fromOffset(0, BUTTON_HEIGHT + (GAP * 2)),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Background.Secondary,
		BorderSizePixel = 0,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Medium,
			}),

			scope:New("UIStroke")({
				Color = Theme.Border.Default,
				Thickness = 1,
				Transparency = 0,
			}),

			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, GAP),
				PaddingRight = UDim.new(0, GAP),
				PaddingTop = UDim.new(0, GAP),
				PaddingBottom = UDim.new(0, GAP),
			}),

			innerButton,
		},
	})
end

return FontPicker
