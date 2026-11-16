--!strict

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)
local Types = require(MainModule.Shared.Types)
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
local MenuContent = require(script.Parent.Parent.MenuContent)
local NPCViewport = require(script.Parent.Parent.NPCViewport)
local Buttons = require(script.Parent.Parent.Parent.Buttons)
local Constants = require(script.Parent.Constants)
local SidebarItem = require(script.Parent.SidebarItem)
local RightSidebar = require(script.Parent.RightSidebar)
local SearchEngine = require(script.Parent.Parent.SearchEngine)
local Signal = require(MainModule.Shared.Utils.State.Signal)

type FusionScope = Types.FusionScope
type FusionValue<T> = Types.FusionValue<T>
type FusionUseFn = Types.FusionUseFn

local peek = Fusion.peek

local function formatKeyForSearch(key: string): string
	local result = key:gsub("(%l)(%u)", "%1 %2"):gsub("I D", "ID")
	return result:lower()
end

local function settingMatchesQuery(query: string, settingKey: string, description: string?): boolean
	local label = formatKeyForSearch(settingKey)
	return SearchEngine.matches(query, label, description or "", settingKey)
end

export type Props = {
	Visible: FusionValue<boolean>,
	Settings: SettingsConfig.SettingsTemplate,
	SearchQuery: FusionValue<string>,
	PreviewOnRight: FusionValue<boolean>,
	PreviewForcedToBottom: FusionCanBeState<boolean>,
	RightSidebarWidth: FusionValue<number>,
	SharingModalVisible: FusionValue<boolean>,
	OnSettingChange: (string, any) -> (),
	OnResetSettings: (() -> ())?,
	OnCursorEquip: ((cursorId: number) -> ())?,
	OnCursorToggleRadial: ((cursorId: number) -> ())?,
	SettingChanged: Signal.Signal<string, any>?,
}

local SEARCH_DEBOUNCE_TIME = 0.15

local function SettingsTab(scope: FusionScope, props: Props): Frame
	local cursorCallbacks: MenuContent.CursorHistoryCallbacks = {
		OnEquip = props.OnCursorEquip,
		OnToggleRadial = props.OnCursorToggleRadial,
	}
	local restrictedSettings: { [string]: FusionCanBeState<boolean> } = {
		PreviewPosition = props.PreviewForcedToBottom,
	}
	local settingsSections = MenuContent.createSettingsContent(
		scope,
		props.Settings,
		props.OnSettingChange,
		props.SearchQuery,
		cursorCallbacks,
		restrictedSettings,
		props.SettingChanged
	)

	local activeSectionIndex = scope:Value(1)
	local settingsScrollFrame: ScrollingFrame? = nil
	local sectionPositions = scope:Value({} :: { [number]: number })
	local searchDebounceThread: thread? = nil
	local searchInputBox: TextBox? = nil
	local isDestroyed = false

	table.insert(scope, function()
		isDestroyed = true
		if searchDebounceThread then
			task.cancel(searchDebounceThread)
			searchDebounceThread = nil
		end
	end)

	local hasSearchResults = scope:Computed(function(use: FusionUseFn)
		local query = use(props.SearchQuery)
		if query == "" then
			return true
		end

		for _, category in SettingsConfig.Categories do
			for _, setting in category.settings do
				if settingMatchesQuery(query, setting.key, setting.description) then
					return true
				end

				if setting.children then
					for _, child in setting.children do
						if settingMatchesQuery(query, child.key, child.description) then
							return true
						end
					end
				end
			end
		end

		return false
	end)

	local settingsColumnChildren: { Instance } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for _, section in settingsSections do
		table.insert(settingsColumnChildren, section)
	end

	local function getScrollFrame(): ScrollingFrame?
		return settingsScrollFrame
	end

	local sidebarItems: { Instance } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, Theme.Settings.Sidebar.ItemGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for i, category in SettingsConfig.Categories do
		table.insert(
			sidebarItems,
			SidebarItem(scope, {
				Index = i,
				Name = category.name,
				IsPreview = false,
				ActiveSectionIndex = activeSectionIndex,
				SectionPositions = sectionPositions,
				GetScrollFrame = getScrollFrame,
				CategoryCount = #SettingsConfig.Categories,
			})
		)
	end

	table.insert(
		sidebarItems,
		scope:New("Frame")({
			Name = "Divider",
			Size = UDim2.new(1, -8, 0, 1),
			BackgroundColor3 = Color3.fromRGB(60, 60, 65),
			BorderSizePixel = 0,
			LayoutOrder = #SettingsConfig.Categories + 1,
		})
	)

	table.insert(
		sidebarItems,
		SidebarItem(scope, {
			Index = #SettingsConfig.Categories + 2,
			Name = "Preview",
			IsPreview = true,
			ActiveSectionIndex = activeSectionIndex,
			SectionPositions = sectionPositions,
			GetScrollFrame = getScrollFrame,
			CategoryCount = #SettingsConfig.Categories,
		})
	)

	local settingsContainer = scope:New("Frame")({
		Name = "SettingsContainer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = props.Visible,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 120),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "Title",
						Size = UDim2.new(1, 0, 0, 50),
						Position = UDim2.fromOffset(0, 16),
						BackgroundTransparency = 1,
						Text = "SETTINGS",
						TextColor3 = Theme.Settings.Title.Text,
						TextSize = Theme.Settings.Title.Size,
						Font = Theme.Settings.Title.Font,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),

					scope:New("Frame")({
						Name = "SearchBarWrapper",
						Size = scope:Computed(function(use: FusionUseFn)
							local rsWidth = use(props.RightSidebarWidth)
							return UDim2.fromOffset(
								Theme.Settings.ContentWidth
									+ Constants.SIDEBAR_WIDTH
									+ rsWidth
									+ (Constants.SIDEBAR_GAP * 2),
								Theme.Settings.SearchBar.Height
							)
						end),
						Position = UDim2.new(0.5, 0, 0, 78),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("Frame")({
								Name = "SearchBarContainer",
								Size = UDim2.new(0, Theme.Settings.ContentWidth - 16, 1, 0),
								Position = UDim2.fromOffset(Constants.SIDEBAR_WIDTH + Constants.SIDEBAR_GAP + 8, 0),
								BackgroundColor3 = Theme.Settings.SearchBar.Background,
								BackgroundTransparency = Theme.Settings.SearchBar.BackgroundTransparency,
								BorderSizePixel = 0,

								[Fusion.Children] = {
									scope:New("UICorner")({
										CornerRadius = Theme.Radius.Medium,
									}),

									scope:New("UIStroke")({
										Color = Theme.Settings.SearchBar.Border,
										Thickness = 1,
										Transparency = Theme.Settings.SearchBar.BorderTransparency,
									}),

									scope:New("TextLabel")({
										Name = "SearchIcon",
										Size = UDim2.new(0, 16, 1, 0),
										Position = UDim2.fromOffset(14, 0),
										BackgroundTransparency = 1,
										Text = "?",
										TextColor3 = Theme.Settings.SearchBar.Icon,
										TextSize = Theme.Text.Large,
										Font = Theme.Text.Bold,
									}),

									(function()
										local initialQuery = peek(props.SearchQuery) or ""
										searchInputBox = scope:New("TextBox")({
											Name = "SearchInput",
											Size = UDim2.new(1, -52, 1, 0),
											Position = UDim2.fromOffset(38, 0),
											BackgroundTransparency = 1,
											Text = initialQuery,
											PlaceholderText = "SEARCH SETTINGS...",
											PlaceholderColor3 = Theme.Settings.SearchBar.Placeholder,
											TextColor3 = Theme.Settings.SearchBar.Text,
											TextSize = Theme.Text.Medium,
											Font = Theme.Text.Semibold,
											TextXAlignment = Enum.TextXAlignment.Left,
											ClearTextOnFocus = false,

											[Fusion.OnChange("Text")] = function(text: string)
												if searchDebounceThread then
													task.cancel(searchDebounceThread)
												end
												searchDebounceThread = task.delay(SEARCH_DEBOUNCE_TIME, function()
													props.SearchQuery:set(text:lower())
													searchDebounceThread = nil
												end)
											end,
										})
										return searchInputBox
									end)(),
								},
							}),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "MainContent",
				Size = UDim2.new(1, 0, 1, -128),
				Position = UDim2.fromOffset(0, 128),
				BackgroundTransparency = 1,
				ClipsDescendants = true,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "CenteredContainer",
						Size = scope:Computed(function(use: FusionUseFn)
							local rsWidth = use(props.RightSidebarWidth)
							return UDim2.new(
								0,
								Theme.Settings.ContentWidth
									+ Constants.SIDEBAR_WIDTH
									+ rsWidth
									+ (Constants.SIDEBAR_GAP * 2),
								1,
								0
							)
						end),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("Frame")({
								Name = "Sidebar",
								Size = UDim2.new(0, Constants.SIDEBAR_WIDTH, 1, -12),
								Position = UDim2.fromOffset(0, 0),
								BackgroundTransparency = 1,

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
												PaddingTop = UDim.new(0, 10),
												PaddingRight = UDim.new(0, 8),
												PaddingBottom = UDim.new(0, 8),
											}),
											unpack(sidebarItems),
										},
									}),
								},
							}),

							scope:New("ScrollingFrame")({
								Name = "SettingsScroll",
								Size = UDim2.new(0, Theme.Settings.ContentWidth, 1, 0),
								Position = UDim2.fromOffset(Constants.SIDEBAR_WIDTH + Constants.SIDEBAR_GAP, 0),
								BackgroundTransparency = 1,
								ScrollBarThickness = 3,
								ScrollBarImageColor3 = Theme.Scrollbar.Thumb,
								CanvasSize = UDim2.fromOffset(0, 0),
								AutomaticCanvasSize = Enum.AutomaticSize.Y,
								ScrollingDirection = Enum.ScrollingDirection.Y,
								BorderSizePixel = 0,

								[Fusion.Children] = {
									scope:New("UIPadding")({
										PaddingTop = UDim.new(0, 8),
										PaddingBottom = UDim.new(0, 8),
										PaddingRight = UDim.new(0, 8),
										PaddingLeft = UDim.new(0, 8),
									}),

									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Vertical,
										Padding = UDim.new(0, 16),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),

									scope:New("Frame")({
										Name = "SettingsColumn",
										Size = UDim2.fromScale(1, 0),
										AutomaticSize = Enum.AutomaticSize.Y,
										BackgroundTransparency = 1,
										LayoutOrder = 1,
										Visible = hasSearchResults,

										[Fusion.Children] = settingsColumnChildren,
									}),

									scope:New("Frame")({
										Name = "NoResultsMessage",
										Size = UDim2.new(1, 0, 0, 200),
										BackgroundTransparency = 1,
										LayoutOrder = 1,
										Visible = scope:Computed(function(use: FusionUseFn)
											return not use(hasSearchResults)
										end),

										[Fusion.Children] = {
											scope:New("Frame")({
												Name = "Content",
												Size = UDim2.new(1, 0, 0, 120),
												Position = UDim2.fromScale(0.5, 0.5),
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundTransparency = 1,

												[Fusion.Children] = {
													scope:New("TextLabel")({
														Name = "Message",
														Size = UDim2.new(1, 0, 0, 24),
														Position = UDim2.fromOffset(0, 0),
														BackgroundTransparency = 1,
														Text = scope:Computed(function(use: FusionUseFn)
															return `No settings found for "{use(props.SearchQuery)}"`
														end),
														TextColor3 = Theme.Foreground.Muted,
														TextSize = 16,
														Font = Theme.Text.Semibold,
														TextXAlignment = Enum.TextXAlignment.Center,
													}),

													scope:New("TextLabel")({
														Name = "Hint",
														Size = UDim2.new(1, 0, 0, 18),
														Position = UDim2.fromOffset(0, 32),
														BackgroundTransparency = 1,
														Text = "Try a different search term",
														TextColor3 = Theme.Foreground.Disabled,
														TextSize = 13,
														Font = Theme.Text.Regular,
														TextXAlignment = Enum.TextXAlignment.Center,
													}),

													scope:New("Frame")({
														Name = "ButtonContainer",
														Size = UDim2.new(1, 0, 0, 38),
														Position = UDim2.new(0.5, 0, 0, 70),
														AnchorPoint = Vector2.new(0.5, 0),
														BackgroundTransparency = 1,

														[Fusion.Children] = {
															scope:New("UIListLayout")({
																FillDirection = Enum.FillDirection.Horizontal,
																HorizontalAlignment = Enum.HorizontalAlignment.Center,
															}),

															Buttons.Button(scope, {
																Text = "CLEAR SEARCH",
																Variant = "secondary",
																Size = UDim2.fromOffset(140, 38),
																OnClick = function()
																	props.SearchQuery:set("")
																	if searchInputBox then
																		searchInputBox.Text = ""
																	end
																end,
															}),
														},
													}),
												},
											}),
										},
									}),

									scope:New("Frame")({
										Name = "PreviewDivider",
										Size = UDim2.new(1, 0, 0, 100),
										BackgroundTransparency = 1,
										LayoutOrder = 3,
										Visible = scope:Computed(function(use: FusionUseFn)
											return use(hasSearchResults) and not use(props.PreviewOnRight)
										end),

										[Fusion.Children] = {
											scope:New("TextLabel")({
												Name = "PreviewTitle",
												Size = UDim2.new(1, 0, 0, 50),
												Position = UDim2.fromScale(0, 0.5),
												AnchorPoint = Vector2.new(0, 0.5),
												BackgroundTransparency = 1,
												Text = "PREVIEW",
												TextColor3 = Theme.Colors.White,
												TextSize = 42,
												Font = Enum.Font.GothamBlack,
												TextXAlignment = Enum.TextXAlignment.Left,
												TextYAlignment = Enum.TextYAlignment.Center,
											}),
										},
									}),

									scope:New("Frame")({
										Name = "PreviewSection",
										Size = UDim2.new(1, 0, 0, Theme.Settings.Preview.Height),
										BackgroundTransparency = 1,
										LayoutOrder = 4,
										Visible = scope:Computed(function(use: FusionUseFn)
											return use(hasSearchResults) and not use(props.PreviewOnRight)
										end),

										[Fusion.Children] = {
											NPCViewport(scope, {
												Size = UDim2.fromScale(1, 1),
												Visible = scope:Computed(function(use: FusionUseFn)
													return use(props.Visible) and not use(props.PreviewOnRight)
												end),
											}),
										},
									}),
								},
							}),

							RightSidebar(scope, {
								Visible = props.Visible,
								PreviewOnRight = props.PreviewOnRight,
								PreviewForcedToBottom = props.PreviewForcedToBottom,
								Width = props.RightSidebarWidth,
								OnResetSettings = props.OnResetSettings,
								OnShareClick = function()
									props.SharingModalVisible:set(true)
								end,
							}),
						},
					}),
				},
			}),
		},
	})

	local function recalculateSectionPositions()
		if isDestroyed then
			return
		end
		if not settingsScrollFrame then
			return
		end

		local scrollFrame = settingsScrollFrame
		local settingsColumn = scrollFrame:FindFirstChild("SettingsColumn")
		if not settingsColumn then
			return
		end

		local positions: { [number]: number } = {}
		local yOffset = 8

		for i, category in SettingsConfig.Categories do
			local sectionFrame = settingsColumn:FindFirstChild(category.name)
			if sectionFrame and sectionFrame.AbsoluteSize.Y > 0 then
				positions[i] = yOffset
				yOffset = yOffset + sectionFrame.AbsoluteSize.Y + 8
			end
		end

		local previewDivider = scrollFrame:FindFirstChild("PreviewDivider")
		if previewDivider and previewDivider.AbsoluteSize.Y > 0 then
			positions[#SettingsConfig.Categories + 1] = yOffset + 8
		end

		sectionPositions:set(positions)
	end

	scope:Observer(props.Visible):onChange(function()
		if peek(props.Visible) then
			task.delay(0.3, recalculateSectionPositions)
		end
	end)

	task.defer(function()
		task.wait(0.3)
		if isDestroyed then
			return
		end

		local mainContent = settingsContainer:FindFirstChild("MainContent")
		if not mainContent then
			return
		end

		local centeredContainer = mainContent:FindFirstChild("CenteredContainer")
		if not centeredContainer then
			return
		end

		local scrollFrame = centeredContainer:FindFirstChild("SettingsScroll") :: ScrollingFrame?
		if not scrollFrame then
			return
		end

		settingsScrollFrame = scrollFrame

		recalculateSectionPositions()
		task.delay(0.5, recalculateSectionPositions)

		local scrollConnection = scrollFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			local scrollY = scrollFrame.CanvasPosition.Y
			local pos = peek(sectionPositions)
			local viewportHeight = scrollFrame.AbsoluteSize.Y
			local canvasHeight = scrollFrame.AbsoluteCanvasSize.Y
			local maxScroll = math.max(0, canvasHeight - viewportHeight)

			local lastSectionPos = 0
			local categoryCount = #SettingsConfig.Categories
			for i = categoryCount, 1, -1 do
				if pos[i] then
					lastSectionPos = pos[i]
					break
				end
			end

			local hasUnreachableSections = lastSectionPos > maxScroll and maxScroll > 0
			if hasUnreachableSections then
				local scrollProgress = scrollY / maxScroll
				local scaledPosition = scrollProgress * lastSectionPos

				local currentSection = 1
				for i = categoryCount, 1, -1 do
					local sectionPos = pos[i]
					if sectionPos and scaledPosition >= sectionPos - 50 then
						currentSection = i
						break
					end
				end
				activeSectionIndex:set(currentSection)
				return
			end

			local currentSection = 1
			for i = categoryCount + 1, 1, -1 do
				local sectionPos = pos[i]
				if sectionPos and scrollY >= sectionPos - 50 then
					currentSection = i
					break
				end
			end

			activeSectionIndex:set(currentSection)
		end)

		table.insert(scope, scrollConnection)
	end)

	return settingsContainer
end

return SettingsTab
