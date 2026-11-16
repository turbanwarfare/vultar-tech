--!strict

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Network = require(MainModule.Shared.Network)
local UniformsConfig = require(MainModule.Shared.Config.Uniforms)
local Section = require(script.Parent.Parent.Parent.Section)
local Row = require(script.Parent.Parent.Parent.Row)
local AvatarUniformDetailPage = require(script.Parent.AvatarUniformDetailPage)

type FusionScope = Types.FusionScope
type FusionValue<T> = Types.FusionValue<T>
type FusionUseFn = Types.FusionUseFn

export type Props = {
	Visible: FusionValue<boolean>,
}

local CONTENT_WIDTH = 960
local EQUIPPED_ACCENT = Color3.fromRGB(255, 140, 0)
local THUMBNAIL_BASE = "rbxthumb://type=GroupIcon&id="
local THUMBNAIL_SUFFIX = "&w=420&h=420"
local CARD_CELL_HEIGHT = 140

local CARD_GRADIENT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.35, 0.7),
	NumberSequenceKeypoint.new(1, 0),
})

local function buildUniformCard(
	scope: FusionScope,
	uniformKey: string,
	equippedUniform: FusionValue<string?>,
	onSelectUniform: (key: string) -> ()
): Frame
	local uniformConfig = UniformsConfig.byKey[uniformKey]
	if not uniformConfig then
		return scope:New("Frame")({
			Name = uniformKey,
			Visible = false,
			Size = UDim2.fromOffset(0, 0),
		}) :: Frame
	end

	local isEquipped = scope:Computed(function(use: FusionUseFn)
		return use(equippedUniform) == uniformKey
	end)

	local isHovered = scope:Value(false)

	local strokeColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isEquipped) then return EQUIPPED_ACCENT end
			if use(isHovered) then return uniformConfig.accentColor end
			return Theme.Border.Default
		end),
		Theme.Spring.Snappy.Speed
	)

	local strokeTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isEquipped) then return 0 end
			if use(isHovered) then return 0.15 end
			return 0.7
		end),
		Theme.Spring.Snappy.Speed
	)

	local bgOverlayTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0.45 else 0.55
		end),
		Theme.Spring.Snappy.Speed
	)

	local thumbnailUrl = THUMBNAIL_BASE .. uniformConfig.groupId .. THUMBNAIL_SUFFIX

	return scope:New("Frame")({
		Name = uniformKey,
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),

			scope:New("UIStroke")({
				Color = strokeColor,
				Thickness = 1.5,
				Transparency = strokeTransparency,
			}),

			scope:New("ImageLabel")({
				Name = "ThumbnailBg",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Background.Tertiary,
				BackgroundTransparency = 0,
				Image = thumbnailUrl,
				ScaleType = Enum.ScaleType.Crop,
				ZIndex = 1,
				ClipsDescendants = true,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
				},
			}),

			scope:New("Frame")({
				Name = "GradientOverlay",
				Size = UDim2.fromScale(1, 0.75),
				Position = UDim2.fromScale(0, 1),
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = bgOverlayTransparency,
				BorderSizePixel = 0,
				ZIndex = 2,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Radius.Large }),
					scope:New("UIGradient")({
						Transparency = CARD_GRADIENT,
						Rotation = 90,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "TextContent",
				Size = UDim2.new(1, 0, 0, 56),
				Position = UDim2.fromScale(0, 1),
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				ZIndex = 3,

				[Fusion.Children] = {
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 10),
						PaddingRight = UDim.new(0, 10),
						PaddingBottom = UDim.new(0, 8),
					}),
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						VerticalAlignment = Enum.VerticalAlignment.Bottom,
						Padding = UDim.new(0, 2),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					scope:New("TextLabel")({
						Name = "EquippedBadge",
						Size = UDim2.new(1, 0, 0, 11),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use: FusionUseFn)
							return if use(isEquipped) then "● EQUIPPED" else ""
						end),
						TextColor3 = EQUIPPED_ACCENT,
						TextSize = 10,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 2,
					}),

					scope:New("TextLabel")({
						Name = "DivisionName",
						Size = UDim2.new(1, 0, 0, 16),
						BackgroundTransparency = 1,
						Text = string.upper(uniformConfig.divisionName),
						TextColor3 = Theme.Foreground.Primary,
						TextSize = 13,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
						TextStrokeTransparency = 0.2,
						LayoutOrder = 1,
					}),
				},
			}),

			scope:New("TextButton")({
				Name = "Hitbox",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 10,
				AutoButtonColor = false,

				[Fusion.OnEvent("MouseEnter")] = function()
					isHovered:set(true)
				end,

				[Fusion.OnEvent("MouseLeave")] = function()
					isHovered:set(false)
				end,

				[Fusion.OnEvent("Activated")] = function()
					onSelectUniform(uniformKey)
				end,
			}),
		},
	}) :: Frame
end

local function AvatarTab(scope: FusionScope, props: Props): Frame
	local isLoading = scope:Value(true)
	local showHats: FusionValue<boolean> = scope:Value(true)
	local equippedUniform: FusionValue<string?> = scope:Value(nil)
	local equippedVariantKey: FusionValue<string?> = scope:Value(nil)
	local availableUniforms: FusionValue<{ string }> = scope:Value({})
	local selectedUniformKey: FusionValue<string?> = scope:Value(nil)
	local noobicSkinColor: FusionValue<boolean> = scope:Value(false)
	local torsoColor: FusionValue<number> = scope:Value(1)

	local scopeAlive = true
	table.insert(scope, function()
		scopeAlive = false
	end)

	local fetchThread = task.spawn(function()
		local state = Network.Avatar.getState()
		if not scopeAlive then return end
		if state then
			showHats:set(state.showHats == true)
			equippedUniform:set(state.equippedUniform)
			equippedVariantKey:set(if type(state.equippedVariantKey) == "string" then state.equippedVariantKey else nil)
			availableUniforms:set(state.availableUniforms or {})
			noobicSkinColor:set(state.noobicSkinColor == true)
			torsoColor:set(if type(state.torsoColor) == "number" then state.torsoColor else 1)
		end
		isLoading:set(false)
	end)
	table.insert(scope, function()
		task.cancel(fetchThread)
	end)

	local stateConn = Network.Avatar.onStateUpdated(function(state: Network.AvatarState)
		if not scopeAlive then return end
		showHats:set(state.showHats == true)
		equippedUniform:set(state.equippedUniform)
		equippedVariantKey:set(if type(state.equippedVariantKey) == "string" then state.equippedVariantKey else nil)
		availableUniforms:set(state.availableUniforms or {})
		noobicSkinColor:set(state.noobicSkinColor == true)
		torsoColor:set(if type(state.torsoColor) == "number" then state.torsoColor else 1)
	end)
	table.insert(scope, stateConn)

	local showGrid = scope:Computed(function(use: FusionUseFn)
		return use(selectedUniformKey) == nil
	end)

	local showDetail = scope:Computed(function(use: FusionUseFn)
		return use(selectedUniformKey) ~= nil
	end)

	local hasUniforms = scope:Computed(function(use: FusionUseFn)
		return not use(isLoading) and #use(availableUniforms) > 0
	end)

	local showStatus = scope:Computed(function(use: FusionUseFn)
		return use(isLoading) or #use(availableUniforms) == 0
	end)

	local function onSelectUniform(key: string)
		selectedUniformKey:set(key)
	end

	local uniformCards = scope:ForValues(
		availableUniforms,
		function(_use: FusionUseFn, cardScope: FusionScope, uniformKey: string)
			return buildUniformCard(cardScope, uniformKey, equippedUniform, onSelectUniform)
		end
	)

	local hatToggleRow = Row(scope, {
		Label = "Show Hats & Accessories",
		ControlType = "Boolean",
		Value = showHats,
		OnChange = function(value: boolean)
			showHats:set(value)
			Network.Avatar.toggleHats(value)
		end,
		LayoutOrder = 1,
	})

	local avatarSettingsSection = Section(scope, {
		Title = "My Avatar Settings",
		LayoutOrder = 2,
		Children = { hatToggleRow },
	})

	local uniformsGridContainer = scope:New("Frame")({
		Name = "UniformsContainer",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			scope:New("Frame")({
				Name = "StatusRow",
				Size = scope:Computed(function(use: FusionUseFn)
					return if use(showStatus) then UDim2.new(1, 0, 0, 80) else UDim2.fromOffset(0, 0)
				end),
				BackgroundTransparency = 1,
				LayoutOrder = 1,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use: FusionUseFn)
							if use(isLoading) then
								return "CHECKING DIVISION MEMBERSHIP..."
							end
							return "YOU ARE NOT A MEMBER OF ANY SUPPORTED DIVISION"
						end),
						TextColor3 = Theme.Foreground.Disabled,
						TextSize = Theme.Text.Medium,
						Font = Theme.Text.Semibold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "Grid",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = scope:Computed(function(use: FusionUseFn)
					return if use(hasUniforms) then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
				end),
				BackgroundTransparency = 1,
				LayoutOrder = 2,

				[Fusion.Children] = {
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 2),
						PaddingRight = UDim.new(0, 2),
					}),
					scope:New("UIGridLayout")({
						CellSize = UDim2.new(0.25, -6, 0, CARD_CELL_HEIGHT),
						CellPadding = UDim2.fromOffset(8, 8),
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					uniformCards,
				},
			}),
		},
	})

	local uniformsSection = Section(scope, {
		Title = "Division Uniforms",
		LayoutOrder = 3,
		Children = { uniformsGridContainer },
	})

	local gridPage = scope:New("ScrollingFrame")({
		Name = "GridPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Scrollbar.Thumb,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,
		Visible = showGrid,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "CenteredContent",
				Size = UDim2.fromOffset(CONTENT_WIDTH, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = UDim2.fromScale(0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 16),
						PaddingRight = UDim.new(0, 16),
						PaddingTop = UDim.new(0, 24),
						PaddingBottom = UDim.new(0, 32),
					}),

					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 12),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					scope:New("TextLabel")({
						Name = "PageTitle",
						Size = UDim2.new(1, 0, 0, 60),
						BackgroundTransparency = 1,
						Text = "AVATAR",
						TextColor3 = Theme.Colors.White,
						TextSize = Theme.Text.Hero,
						Font = Theme.Text.Black,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						LayoutOrder = 1,
					}),

					avatarSettingsSection,
					uniformsSection,
				},
			}),
		},
	})

	local detailPage = AvatarUniformDetailPage(scope, {
		Visible = showDetail,
		SelectedUniformKey = selectedUniformKey,
		EquippedUniform = equippedUniform,
		EquippedVariantKey = equippedVariantKey,
		NoobicSkinColor = noobicSkinColor,
		TorsoColor = torsoColor,
		OnBack = function()
			selectedUniformKey:set(nil)
		end,
	})

	return scope:New("Frame")({
		Name = "AvatarContent",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = props.Visible,

		[Fusion.Children] = {
			gridPage,
			detailPage,
		},
	}) :: Frame
end

return AvatarTab
