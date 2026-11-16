--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Network = require(MainModule.Shared.Network)
local UniformsConfig = require(MainModule.Shared.Config.Uniforms)
local Row = require(script.Parent.Parent.Parent.Row)
local AvatarViewport = require(script.Parent.Parent.Parent.AvatarViewport)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionValue<T> = Types.FusionValue<T>
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type UniformVariantOption = UniformsConfig.UniformVariantOption

export type DetailPageProps = {
	Visible: FusionCanBeState<boolean>,
	SelectedUniformKey: FusionValue<string?>,
	EquippedUniform: FusionValue<string?>,
	EquippedVariantKey: FusionValue<string?>,
	NoobicSkinColor: FusionValue<boolean>,
	TorsoColor: FusionValue<number>,
	OnBack: () -> (),
}

local EQUIPPED_ACCENT = Color3.fromRGB(255, 140, 0)
local EQUIP_BTN_BG = Color3.fromRGB(0, 112, 78)
local EQUIP_BTN_HOVER = Color3.fromRGB(0, 135, 94)
local UNEQUIP_BTN_BG = Color3.fromRGB(50, 50, 50)
local UNEQUIP_BTN_HOVER = Color3.fromRGB(65, 65, 65)
local CHIP_SELECTED_BG = Color3.fromRGB(24, 36, 58)
local CHIP_DEFAULT_BG = Color3.fromRGB(20, 20, 25)
local CHIP_HOVER_BG = Color3.fromRGB(28, 28, 36)
local THUMBNAIL_BASE = "rbxthumb://type=GroupIcon&id="
local THUMBNAIL_SUFFIX = "&w=420&h=420"
local HEADER_HEIGHT = 90
local LEFT_PANEL_RATIO = 0.36

local function buildVariantChip(
	btnScope: FusionScope,
	variant: UniformVariantOption,
	selectedVariantKey: FusionValue<string?>,
	accentColor: Color3
): TextButton
	local vKey = variant.key

	local isSelected = btnScope:Computed(function(use: FusionUseFn)
		return use(selectedVariantKey) == vKey
	end)

	local isHovered = btnScope:Value(false)

	local bgColor = btnScope:Spring(
		btnScope:Computed(function(use: FusionUseFn)
			if use(isSelected) then return CHIP_SELECTED_BG end
			if use(isHovered) then return CHIP_HOVER_BG end
			return CHIP_DEFAULT_BG
		end),
		Theme.Spring.Snappy.Speed
	)

	local strokeColor = btnScope:Spring(
		btnScope:Computed(function(use: FusionUseFn)
			return if use(isSelected) then accentColor else Theme.Border.Subtle
		end),
		Theme.Spring.Snappy.Speed
	)

	local strokeTransparency = btnScope:Spring(
		btnScope:Computed(function(use: FusionUseFn)
			if use(isSelected) then return 0.1 end
			if use(isHovered) then return 0.5 end
			return 0.75
		end),
		Theme.Spring.Snappy.Speed
	)

	local textColor = btnScope:Spring(
		btnScope:Computed(function(use: FusionUseFn)
			return if use(isSelected) then Theme.Foreground.Primary else Theme.Foreground.Muted
		end),
		Theme.Spring.Snappy.Speed
	)

	return btnScope:New("TextButton")({
		Name = vKey,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = bgColor,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,

		[Fusion.Children] = {
			btnScope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			btnScope:New("UIStroke")({
				Color = strokeColor,
				Thickness = 1.5,
				Transparency = strokeTransparency,
			}),
			btnScope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
			}),
			btnScope:New("TextLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = string.upper(variant.variantName),
				TextColor3 = textColor,
				TextSize = 11,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		},

		[Fusion.OnEvent("MouseEnter")] = function() isHovered:set(true) end,
		[Fusion.OnEvent("MouseLeave")] = function() isHovered:set(false) end,
		[Fusion.OnEvent("Activated")] = function() selectedVariantKey:set(vKey) end,
	}) :: TextButton
end

local function AvatarUniformDetailPage(scope: FusionScope, props: DetailPageProps): Frame
	local uniformConfig = scope:Computed(function(use: FusionUseFn)
		local key = use(props.SelectedUniformKey)
		if not key then return nil end
		return UniformsConfig.byKey[key]
	end)

	local selectedVariantKey: FusionValue<string?> = scope:Value(nil)

	local uniformKeyObserver = scope:Observer(props.SelectedUniformKey)
	uniformKeyObserver:onChange(function()
		local key = Fusion.peek(props.SelectedUniformKey)
		if not key then
			selectedVariantKey:set(nil)
			return
		end
		local uniform = UniformsConfig.byKey[key]
		if not uniform or not uniform.variants then
			selectedVariantKey:set(nil)
			return
		end
		local equippedUniform = Fusion.peek(props.EquippedUniform)
		local equippedVariant = Fusion.peek(props.EquippedVariantKey)
		if equippedUniform == key and equippedVariant then
			selectedVariantKey:set(equippedVariant)
		else
			selectedVariantKey:set(uniform.variants[1].key)
		end
	end)

	local isEquipped = scope:Computed(function(use: FusionUseFn)
		local key = use(props.SelectedUniformKey)
		if key == nil then return false end
		if use(props.EquippedUniform) ~= key then return false end
		local uniform = UniformsConfig.byKey[key]
		if uniform and uniform.variants then
			local selVariant = use(selectedVariantKey)
			return selVariant ~= nil and use(props.EquippedVariantKey) == selVariant
		end
		return true
	end)

	local isEquipHovered = scope:Value(false)

	local show3NDSettings = scope:Computed(function(use: FusionUseFn)
		local cfg = use(uniformConfig)
		return cfg ~= nil and cfg.settings ~= nil
	end)

	local showTorsoSetting = scope:Computed(function(use: FusionUseFn)
		return use(show3NDSettings) and use(props.NoobicSkinColor)
	end)

	local hasVariants = scope:Computed(function(use: FusionUseFn)
		local cfg = use(uniformConfig)
		return cfg ~= nil and cfg.variants ~= nil
	end)

	local equipBgColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isEquipped) then
				return if use(isEquipHovered) then UNEQUIP_BTN_HOVER else UNEQUIP_BTN_BG
			end
			return if use(isEquipHovered) then EQUIP_BTN_HOVER else EQUIP_BTN_BG
		end),
		Theme.Spring.Snappy.Speed
	)

	local function onEquipClick()
		local key = Fusion.peek(props.SelectedUniformKey)
		if not key then return end
		local uniform = UniformsConfig.byKey[key]
		local variantKey: string? = nil
		if uniform and uniform.variants then
			variantKey = Fusion.peek(selectedVariantKey)
			if not variantKey then return end
		end
		if Fusion.peek(isEquipped) then
			props.EquippedUniform:set(nil)
			props.EquippedVariantKey:set(nil)
			Network.Avatar.unequipUniform()
		else
			props.EquippedUniform:set(key)
			props.EquippedVariantKey:set(variantKey)
			Network.Avatar.equipUniform(key, variantKey)
		end
	end

	local variantSource = scope:Computed(function(use: FusionUseFn)
		local cfg = use(uniformConfig)
		if not cfg or not cfg.variants then
			return {} :: { UniformVariantOption }
		end
		return cfg.variants
	end)

	local variantChips = scope:ForValues(
		variantSource,
		function(_use: FusionUseFn, chipScope: FusionScope, variant: UniformVariantOption)
			local cfg = Fusion.peek(uniformConfig)
			local accentColor = if cfg then cfg.accentColor else Theme.Border.Default
			return buildVariantChip(chipScope, variant, selectedVariantKey, accentColor)
		end
	)

	local noobicRow = Row(scope, {
		Label = "Noobic Skin Color",
		ControlType = "Boolean",
		Value = props.NoobicSkinColor,
		OnChange = function(value: boolean)
			props.NoobicSkinColor:set(value)
			Network.Avatar.setNoobicSkinColor(value)
		end,
		LayoutOrder = 1,
	})

	local torsoRow = Row(scope, {
		Label = "Torso Color",
		ControlType = "Pick",
		Options = { "Blue", "Red", "Green" },
		Value = props.TorsoColor,
		OnChange = function(value: number)
			props.TorsoColor:set(value)
			Network.Avatar.setTorsoColor(value)
		end,
		LayoutOrder = 2,
	})

	local avatarViewport = AvatarViewport(scope, {
		UniformKey = props.SelectedUniformKey,
		VariantKey = selectedVariantKey,
		NoobicSkinColor = props.NoobicSkinColor,
		TorsoColor = props.TorsoColor,
		Size = UDim2.fromScale(1, 1),
	})

	return scope:New("Frame")({
		Name = "UniformDetailPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = props.Visible,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("TextButton")({
						Name = "BackButton",
						Size = UDim2.fromOffset(0, 30),
						AutomaticSize = Enum.AutomaticSize.X,
						Position = UDim2.fromOffset(20, 20),
						BackgroundColor3 = Theme.Background.Tertiary,
						BackgroundTransparency = 0.3,
						BorderSizePixel = 0,
						Text = "",
						AutoButtonColor = false,
						ZIndex = 2,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
							scope:New("UIStroke")({
								Color = Theme.Border.Default,
								Thickness = 1,
								Transparency = 0.5,
							}),
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 5),
							}),
							scope:New("UIPadding")({
								PaddingLeft = UDim.new(0, 10),
								PaddingRight = UDim.new(0, 10),
							}),
							scope:New("TextLabel")({
								Size = UDim2.fromOffset(0, 30),
								AutomaticSize = Enum.AutomaticSize.X,
								BackgroundTransparency = 1,
								Text = "←",
								TextColor3 = Theme.Foreground.Secondary,
								TextSize = 13,
								Font = Theme.Text.Bold,
								LayoutOrder = 1,
							}),
							scope:New("TextLabel")({
								Size = UDim2.fromOffset(0, 30),
								AutomaticSize = Enum.AutomaticSize.X,
								BackgroundTransparency = 1,
								Text = "UNIFORMS",
								TextColor3 = Theme.Foreground.Secondary,
								TextSize = 12,
								Font = Theme.Text.Bold,
								LayoutOrder = 2,
							}),
						},

						[Fusion.OnEvent("Activated")] = props.OnBack,
					}),

					scope:New("Frame")({
						Name = "TitleBlock",
						Size = UDim2.new(1, -240, 1, 0),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								Padding = UDim.new(0, 2),
							}),

							scope:New("TextLabel")({
								Name = "DivisionName",
								Size = UDim2.new(1, 0, 0, 30),
								BackgroundTransparency = 1,
								Text = scope:Computed(function(use: FusionUseFn)
									local cfg = use(uniformConfig)
									return if cfg then string.upper(cfg.divisionName) else ""
								end),
								TextColor3 = Theme.Foreground.Primary,
								TextSize = 24,
								Font = Theme.Text.Black,
								TextXAlignment = Enum.TextXAlignment.Center,
								TextTruncate = Enum.TextTruncate.AtEnd,
								LayoutOrder = 1,
							}),

							scope:New("TextLabel")({
								Name = "SubLabel",
								Size = UDim2.new(1, 0, 0, 15),
								BackgroundTransparency = 1,
								Text = scope:Computed(function(use: FusionUseFn)
									local cfg = use(uniformConfig)
									return if cfg then string.upper(cfg.variantName) else ""
								end),
								TextColor3 = Theme.Foreground.Muted,
								TextSize = 11,
								Font = Theme.Text.Semibold,
								TextXAlignment = Enum.TextXAlignment.Center,
								LayoutOrder = 2,
							}),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "Body",
				Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT),
				Position = UDim2.fromOffset(0, HEADER_HEIGHT),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("ScrollingFrame")({
						Name = "LeftColumn",
						Size = UDim2.fromScale(LEFT_PANEL_RATIO, 1),
						BackgroundTransparency = 1,
						ScrollBarThickness = 3,
						ScrollBarImageColor3 = Theme.Scrollbar.Thumb,
						CanvasSize = UDim2.fromOffset(0, 0),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						ScrollingDirection = Enum.ScrollingDirection.Y,
						BorderSizePixel = 0,

						[Fusion.Children] = {
							scope:New("UIPadding")({
								PaddingLeft = UDim.new(0, 20),
								PaddingRight = UDim.new(0, 16),
								PaddingTop = UDim.new(0, 4),
								PaddingBottom = UDim.new(0, 20),
							}),
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, 14),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							scope:New("Frame")({
								Name = "Identity",
								Size = UDim2.fromScale(1, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								LayoutOrder = 1,

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										VerticalAlignment = Enum.VerticalAlignment.Center,
										Padding = UDim.new(0, 12),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),

									scope:New("ImageLabel")({
										Name = "GroupIcon",
										Size = UDim2.fromOffset(52, 52),
										BackgroundColor3 = Theme.Background.Tertiary,
										BackgroundTransparency = 0.25,
										Image = scope:Computed(function(use: FusionUseFn)
											local cfg = use(uniformConfig)
											if not cfg then return "" end
											return THUMBNAIL_BASE .. cfg.groupId .. THUMBNAIL_SUFFIX
										end),
										ScaleType = Enum.ScaleType.Crop,
										LayoutOrder = 1,

										[Fusion.Children] = {
											scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
											scope:New("UIStroke")({
												Color = scope:Computed(function(use: FusionUseFn)
													local cfg = use(uniformConfig)
													return if cfg then cfg.accentColor else Theme.Border.Default
												end),
												Thickness = 1.5,
												Transparency = 0.4,
											}),
										},
									}),

									scope:New("Frame")({
										Name = "Labels",
										Size = UDim2.fromOffset(0, 0),
										AutomaticSize = Enum.AutomaticSize.XY,
										BackgroundTransparency = 1,
										LayoutOrder = 2,

										[Fusion.Children] = {
											scope:New("UIListLayout")({
												FillDirection = Enum.FillDirection.Vertical,
												Padding = UDim.new(0, 3),
												SortOrder = Enum.SortOrder.LayoutOrder,
											}),
											scope:New("TextLabel")({
												Size = UDim2.fromOffset(0, 15),
												AutomaticSize = Enum.AutomaticSize.X,
												BackgroundTransparency = 1,
												Text = scope:Computed(function(use: FusionUseFn)
													local cfg = use(uniformConfig)
													return if cfg then string.upper(cfg.divisionName) else ""
												end),
												TextColor3 = Theme.Foreground.Primary,
												TextSize = 12,
												Font = Theme.Text.Black,
												TextXAlignment = Enum.TextXAlignment.Left,
												LayoutOrder = 1,
											}),
											scope:New("TextLabel")({
												Size = UDim2.fromOffset(0, 12),
												AutomaticSize = Enum.AutomaticSize.X,
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
										},
									}),
								},
							}),

							scope:New("Frame")({
								Name = "VariantPicker",
								Size = UDim2.fromScale(1, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								Visible = hasVariants,
								LayoutOrder = 2,

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Vertical,
										Padding = UDim.new(0, 8),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),

									scope:New("TextLabel")({
										Size = UDim2.new(1, 0, 0, 14),
										BackgroundTransparency = 1,
										Text = "VARIANT",
										TextColor3 = Theme.Foreground.Disabled,
										TextSize = 10,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
										LayoutOrder = 1,
									}),

									scope:New("Frame")({
										Name = "ChipRow",
										Size = UDim2.fromScale(1, 0),
										AutomaticSize = Enum.AutomaticSize.Y,
										BackgroundTransparency = 1,
										LayoutOrder = 2,

										[Fusion.Children] = {
											scope:New("UIListLayout")({
												FillDirection = Enum.FillDirection.Horizontal,
												VerticalAlignment = Enum.VerticalAlignment.Center,
												Padding = UDim.new(0, 6),
												Wraps = true,
											}),
											variantChips,
										},
									}),
								},
							}),

							scope:New("TextButton")({
								Name = "EquipButton",
								Size = UDim2.new(1, 0, 0, 40),
								BackgroundColor3 = equipBgColor,
								BorderSizePixel = 0,
								Text = "",
								AutoButtonColor = false,
								LayoutOrder = 3,

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
									scope:New("TextLabel")({
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = scope:Computed(function(use: FusionUseFn)
											return if use(isEquipped) then "UNEQUIP" else "EQUIP UNIFORM"
										end),
										TextColor3 = Theme.Colors.White,
										TextSize = Theme.Text.Medium,
										Font = Theme.Text.Black,
									}),
								},

								[Fusion.OnEvent("MouseEnter")] = function() isEquipHovered:set(true) end,
								[Fusion.OnEvent("MouseLeave")] = function() isEquipHovered:set(false) end,
								[Fusion.OnEvent("Activated")] = onEquipClick,
							}),

							scope:New("Frame")({
								Name = "Settings",
								Size = UDim2.fromScale(1, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								Visible = show3NDSettings,
								LayoutOrder = 4,

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Vertical,
										Padding = UDim.new(0, 4),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),
									scope:New("Frame")({
										Size = UDim2.new(1, 0, 0, 1),
										BackgroundColor3 = Theme.Border.Default,
										BackgroundTransparency = 0.6,
										BorderSizePixel = 0,
										LayoutOrder = 0,
									}),
									scope:New("TextLabel")({
										Size = UDim2.new(1, 0, 0, 22),
										BackgroundTransparency = 1,
										Text = "SETTINGS",
										TextColor3 = Theme.Foreground.Disabled,
										TextSize = 10,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
										LayoutOrder = 1,
									}),
									scope:New("Frame")({
										Size = UDim2.new(1, 0, 0, 34),
										BackgroundTransparency = 1,
										LayoutOrder = 2,
										[Fusion.Children] = { noobicRow },
									}),
									scope:New("Frame")({
										Size = UDim2.new(1, 0, 0, 34),
										BackgroundTransparency = 1,
										Visible = showTorsoSetting,
										LayoutOrder = 3,
										[Fusion.Children] = { torsoRow },
									}),
								},
							}),
						},
					}),

					scope:New("Frame")({
						Name = "RightPanel",
						Size = UDim2.fromScale(1 - LEFT_PANEL_RATIO, 1),
						Position = UDim2.fromScale(LEFT_PANEL_RATIO, 0),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIPadding")({
								PaddingTop = UDim.new(0, 8),
								PaddingBottom = UDim.new(0, 20),
								PaddingRight = UDim.new(0, 20),
								PaddingLeft = UDim.new(0, 8),
							}),
							avatarViewport,
						},
					}),
				},
			}),
		},
	}) :: Frame
end

return AvatarUniformDetailPage
