--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CratesConfig = require(MainModule.Shared.Config.Cosmetics.Crates)

local CrateModelCache = require(script.Parent.Parent.Cache.CrateModelCache)
local SkinModelCache = require(script.Parent.Parent.Cache.SkinModelCache)
local CosmeticLookup = require(script.Parent.Parent.Cache.CosmeticLookup)
local GunViewportFactory = require(MainModule.Client.Utils.GunViewportFactory)
local CrateViewportFactory = require(MainModule.Client.Utils.CrateViewportFactory)
local UISound = require(script.Parent.Parent.Parent.UISound)
local Shadow = require(MainModule.Client.Components.Shadow)
local CrateInfoModal = require(script.Parent.CrateInfoModal)

local BREATHING_TWEEN_INFO = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local SHIMMER_TWEEN_INFO = TweenInfo.new(4.0, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false)
local AURA_SPIN_TWEEN_INFO = TweenInfo.new(24, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false)
local LEGENDARY_PULSE_TWEEN_INFO = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local ELITE_PULSE_TWEEN_INFO = TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionValue<T> = Types.FusionValue<T>
type CrateConfig = CratesConfig.CrateConfig
type CrateRarity = CratesConfig.CrateRarity
type CrateDrop = CratesConfig.CrateDrop
type ResolvedCosmetic = Types.ResolvedCosmetic

type HoveredDropData = {
	drop: CrateDrop,
	slotIndex: number,
	totalSlots: number,
}

local PANEL_BG = Color3.fromRGB(20, 20, 20)
local PANEL_BG_TRANSPARENCY = 0.2
local PANEL_BORDER = Color3.fromRGB(140, 140, 160)
local PANEL_BORDER_TRANSPARENCY = 0.3

local PANEL_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(178, 178, 178)),
})

local ELITE_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 220)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 150, 90)),
})

local LEGENDARY_COLOR = CratesConfig.getRarityColor("Legendary")
local MYTHIC_COLOR = CratesConfig.getRarityColor("Mythic")

local LEGENDARY_CARD_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, LEGENDARY_COLOR:Lerp(Color3.new(1, 1, 1), 0.85)),
	ColorSequenceKeypoint.new(1, LEGENDARY_COLOR:Lerp(Color3.new(0, 0, 0), 0.55)),
})

local LEGENDARY_BORDER_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, LEGENDARY_COLOR:Lerp(Color3.new(0, 0, 0), 0.6)),
	ColorSequenceKeypoint.new(0.25, LEGENDARY_COLOR),
	ColorSequenceKeypoint.new(0.5, LEGENDARY_COLOR:Lerp(Color3.new(1, 1, 1), 0.5)),
	ColorSequenceKeypoint.new(0.75, LEGENDARY_COLOR),
	ColorSequenceKeypoint.new(1, LEGENDARY_COLOR:Lerp(Color3.new(0, 0, 0), 0.6)),
})

local MYTHIC_CARD_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, MYTHIC_COLOR:Lerp(Color3.new(1, 1, 1), 0.85)),
	ColorSequenceKeypoint.new(1, MYTHIC_COLOR:Lerp(Color3.new(0, 0, 0), 0.6)),
})

local MYTHIC_BORDER_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, MYTHIC_COLOR:Lerp(Color3.new(0, 0, 0), 0.8)),
	ColorSequenceKeypoint.new(0.25, MYTHIC_COLOR),
	ColorSequenceKeypoint.new(0.5, MYTHIC_COLOR:Lerp(Color3.new(1, 1, 1), 0.45)),
	ColorSequenceKeypoint.new(0.75, MYTHIC_COLOR),
	ColorSequenceKeypoint.new(1, MYTHIC_COLOR:Lerp(Color3.new(0, 0, 0), 0.8)),
})

local RARE_COLOR = CratesConfig.getRarityColor("Rare")

local ELITE_BORDER_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, RARE_COLOR:Lerp(Color3.new(0, 0, 0), 0.6)),
	ColorSequenceKeypoint.new(0.25, RARE_COLOR),
	ColorSequenceKeypoint.new(0.5, RARE_COLOR:Lerp(Color3.new(1, 1, 1), 0.5)),
	ColorSequenceKeypoint.new(0.75, RARE_COLOR),
	ColorSequenceKeypoint.new(1, RARE_COLOR:Lerp(Color3.new(0, 0, 0), 0.6)),
})

local STAR_FLARE_ASSET = "rbxassetid://11037779268"

local DROP_SLOT_ZINDEX = {
	BACKGROUND = 1,
	OUTER_GLOW = 2,
	SHIMMER_SWEEP = 3,
	MODEL_VIEWPORT = 5,
	BORDER_OUTLINE = 6,
	HITBOX = 10,
}

local SHIMMER_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
})

local SHIMMER_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0.65),
	NumberSequenceKeypoint.new(1, 1),
})

local function tierTheme(rarity: string, auraTransparency: number, auraSize: number, stripeTransparency: number)
	local base = CratesConfig.getRarityColor(rarity :: any)
	return {
		Accent = base,
		AuraColor = base,
		AuraTransparency = auraTransparency,
		AuraSize = auraSize,
		BorderNormal = base:Lerp(Color3.new(0, 0, 0), 0.15),
		BorderHover = base:Lerp(Color3.new(1, 1, 1), 0.4),
		StripeColor = base,
		StripeTransparency = stripeTransparency,
	}
end

local TIER_THEMES = {
	Common = tierTheme("Common", 0.65, 230, Theme.Section.Stripe.Transparency),
	Uncommon = tierTheme("Uncommon", 0.50, 240, 0.94),
	Rare = tierTheme("Rare", 0.38, 250, 0.92),
	Legendary = tierTheme("Legendary", 0.35, 260, 0.92),
	Mythic = tierTheme("Mythic", 0.30, 270, 0.90),
}
TIER_THEMES.Common.StripeColor = Theme.Section.Stripe.Color

local function formatNumber(amount: number): string
	local formatted = tostring(math.max(0, math.floor(amount)))
	local iterations = 0
	repeat
		formatted, iterations = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until iterations == 0
	return formatted
end

local function createGunSkinThumbnailViewport(skinId: string, gunName: string?): ViewportFrame?
	local targetGun = gunName or "H-82"
	local model = SkinModelCache.getModel(skinId, targetGun) or SkinModelCache.getModel(skinId, "H-82")
	if not model then
		return nil
	end

	local viewport = GunViewportFactory.create(model, {
		fov = 32,
		distanceMultiplier = 0.85,
		rotation = CFrame.Angles(0, -math.pi / 2, 0) * CFrame.Angles(math.rad(14), 0, 0),
		ambient = Color3.fromRGB(160, 160, 170),
		lightDirection = Vector3.new(-0.35, -0.85, -0.4),
	})
	viewport.Name = "SkinViewport"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Position = UDim2.fromScale(0.5, 0.5)
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.BackgroundTransparency = 1
	viewport.ZIndex = DROP_SLOT_ZINDEX.MODEL_VIEWPORT
	return viewport
end

local function createCrateModelViewport(crate: CrateConfig): ViewportFrame?
	local model = CrateModelCache.getModel(crate.modelName)
	if not model then
		return nil
	end

	local viewport = CrateViewportFactory.create(model, {
		fov = 35,
		paddingMultiplier = crate.paddingMultiplier or 0.85,
		yawAngleDeg = crate.yawAngleDeg or 152,
		pitchAngleDeg = crate.cameraElevationDeg or 14,
		ambient = Color3.fromRGB(130, 130, 140),
		lightDirection = Vector3.new(-0.3, -0.8, -0.4),
	})
	viewport.Name = "CrateModelViewport"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Position = UDim2.fromScale(0.5, 0.5)
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.BackgroundTransparency = 1
	viewport.ZIndex = 2
	return viewport
end

export type CrateCardProps = {
	Crate: CrateConfig,
	LayoutOrder: number,
	OnClick: () -> (),
	OnInfoClick: (() -> ())?,
}

local function CrateCard(scope: FusionScope, props: CrateCardProps): Frame
	local crate = props.Crate
	local theme = TIER_THEMES[crate.rarity] or TIER_THEMES.Common
	local rarityColor = CratesConfig.getRarityColor(crate.rarity)
	local isElite = crate.id == "Elite" or crate.rarity == "Rare"
	local isMythicCrate = crate.rarity == "Mythic"
	local isLegendaryCrate = crate.id == "Legendary" or crate.rarity == "Legendary" or isMythicCrate
	local legendaryBorderGradient = if isMythicCrate then MYTHIC_BORDER_GRADIENT else LEGENDARY_BORDER_GRADIENT

	local isHovered = scope:Value(false)
	local isInfoModalOpen = scope:Value(false)
	local isInfoHovered = scope:Value(false)
	local isPriceRowHovered = scope:Value(false)
	local hoveredDropInfo: FusionValue<HoveredDropData?> = scope:Value(nil)

	local breathingScale: UIScale? = nil

	if isLegendaryCrate then
		local uiScale = scope:New("UIScale")({ Scale = 1 })
		local breathingTween = TweenService:Create(uiScale, BREATHING_TWEEN_INFO, { Scale = 1.015 })
		breathingTween:Play()
		breathingScale = uiScale
		table.insert(scope, function()
			breathingTween:Cancel()
			breathingTween:Destroy()
		end)
	end

	local cardScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 1.018 else 1.0
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local borderStrokeColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then theme.BorderHover else theme.BorderNormal
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local borderStrokeThickness = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if isLegendaryCrate then
				return if use(isHovered) then 2.0 else 1.6
			end
			return if use(isHovered) then 1.5 else 1.0
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local borderStrokeTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if isLegendaryCrate then
				return if use(isHovered) then 0.0 else 0.08
			end
			return if use(isHovered) then 0.05 else Theme.Stroke.Strong
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local borderShimmerGradient: UIGradient? = nil
	local borderShimmerTween: Tween? = nil
	if isLegendaryCrate then
		borderShimmerGradient = scope:New("UIGradient")({
			Color = legendaryBorderGradient,
			Rotation = 0,
		})
		borderShimmerTween = TweenService:Create(borderShimmerGradient, SHIMMER_TWEEN_INFO, { Rotation = 360 })
		borderShimmerTween:Play()
	end

	local isPremiumCrate = isLegendaryCrate or isElite
	local priceShimmerGradient: UIGradient? = nil
	local priceShimmerTween: Tween? = nil
	local infoShimmerGradient: UIGradient? = nil
	local infoShimmerTween: Tween? = nil

	if isPremiumCrate then
		local shimmerSeq = if isLegendaryCrate then legendaryBorderGradient else ELITE_BORDER_GRADIENT

		priceShimmerGradient = scope:New("UIGradient")({
			Color = shimmerSeq,
			Rotation = 0,
		})
		priceShimmerTween = TweenService:Create(priceShimmerGradient, SHIMMER_TWEEN_INFO, { Rotation = 360 })
		priceShimmerTween:Play()

		infoShimmerGradient = scope:New("UIGradient")({
			Color = shimmerSeq,
			Rotation = 0,
		})
		infoShimmerTween = TweenService:Create(infoShimmerGradient, SHIMMER_TWEEN_INFO, { Rotation = 360 })
		infoShimmerTween:Play()
	end

	local previewDrops = CratesConfig.getPreviewDrops(crate)

	local auraImage = scope:New("ImageLabel")({
		Name = "RadiantAuraBloom",
		Size = UDim2.fromOffset(theme.AuraSize + 30, theme.AuraSize + 30),
		Position = UDim2.fromScale(0.5, 0.44),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = STAR_FLARE_ASSET,
		ImageColor3 = theme.AuraColor,
		ImageTransparency = theme.AuraTransparency,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 2,
	})

	local rotTween = TweenService:Create(auraImage, AURA_SPIN_TWEEN_INFO, { Rotation = 360 })
	rotTween:Play()

	local pulseTween: Tween? = nil
	if isLegendaryCrate then
		pulseTween = TweenService:Create(auraImage, LEGENDARY_PULSE_TWEEN_INFO, {
			ImageTransparency = 0.08,
			Size = UDim2.fromOffset(theme.AuraSize + 45, theme.AuraSize + 45),
		})
		pulseTween:Play()
	elseif isElite then
		pulseTween = TweenService:Create(auraImage, ELITE_PULSE_TWEEN_INFO, {
			ImageTransparency = 0.20,
			Size = UDim2.fromOffset(theme.AuraSize + 25, theme.AuraSize + 25),
		})
		pulseTween:Play()
	end

	table.insert(scope, function()
		rotTween:Cancel()
		rotTween:Destroy()
		if pulseTween then
			pulseTween:Cancel()
			pulseTween:Destroy()
		end
		if borderShimmerTween then
			borderShimmerTween:Cancel()
			borderShimmerTween:Destroy()
		end
		if priceShimmerTween then
			priceShimmerTween:Cancel()
			priceShimmerTween:Destroy()
		end
		if infoShimmerTween then
			infoShimmerTween:Cancel()
			infoShimmerTween:Destroy()
		end
	end)

	local function onMouseEnter()
		isHovered:set(true)
		UISound.play("Swipe")
	end

	local function onMouseLeave()
		isHovered:set(false)
	end

	local function openInfoModal()
		if props.OnInfoClick then
			props.OnInfoClick()
		else
			isInfoModalOpen:set(true)
		end
		UISound.play("Swipe")
	end

	local function closeInfoModal()
		isInfoModalOpen:set(false)
	end

	local dropStripChildren: { Instance } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for idx, drop in previewDrops do
		if idx > 5 then
			break
		end
		local isFeatured = drop.isFeatured == true
		local itemRarityColor = CratesConfig.getRarityColor(drop.rarity)
		local sepPos = string.find(drop.id, ":", 1, true)
		local baseSkinId = drop.skinId or (sepPos and string.sub(drop.id, 1, sepPos - 1)) or drop.id
		local weaponName = drop.weaponName or (sepPos and string.sub(drop.id, sepPos + 1))
		local resolved = if drop.category == "GunSkin" then CosmeticLookup.getSkinById(baseSkinId) else CosmeticLookup.getCardById(drop.id)
		local itemSize = if isFeatured then 44 else 38

		local iconCard = scope:New("Frame")({
			Name = "DropSlot_" .. drop.id,
			Size = UDim2.fromOffset(itemSize, itemSize),
			BackgroundColor3 = Color3.fromRGB(15, 17, 24),
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			LayoutOrder = idx,
			ZIndex = 6,

			[Fusion.Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),

				scope:New("UIStroke")({
					Color = if isFeatured then Color3.fromRGB(255, 255, 255) else itemRarityColor,
					Thickness = if isFeatured then 1.5 else 1,
					Transparency = if isFeatured then 0.2 else 0.4,
					[Fusion.Children] = if not isFeatured
							and drop.rarity == "Mythic"
							and CratesConfig.RarityGradients
							and CratesConfig.RarityGradients.Mythic
						then {
							scope:New("UIGradient")({
								Color = CratesConfig.RarityGradients.Mythic,
								Rotation = 45,
							}),
						}
						else nil,
				}),

				if isFeatured
					then scope:New("Frame")({
						Name = "FeaturedGlowOutline",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ZIndex = DROP_SLOT_ZINDEX.OUTER_GLOW,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
							scope:New("UIStroke")({
								Color = theme.Accent,
								Thickness = 1,
								Transparency = 0.35,
								BorderStrokePosition = Enum.BorderStrokePosition.Outer,
							}),
						},
					})
					else nil,

				if drop.category == "GunSkin"
					then createGunSkinThumbnailViewport(baseSkinId, weaponName)
					else scope:New("ImageLabel")({
						Name = "CardImage",
						Size = UDim2.new(1, -6, 1, -6),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = if resolved then resolved.imageId else "",
						ScaleType = Enum.ScaleType.Fit,
						ZIndex = DROP_SLOT_ZINDEX.MODEL_VIEWPORT,
					}),

				scope:New("Frame")({
					Name = "Shimmer",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					ZIndex = DROP_SLOT_ZINDEX.SHIMMER_SWEEP,

					[Fusion.Children] = {
						scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
						scope:New("UIGradient")({
							Color = SHIMMER_GRADIENT,
							Rotation = 45,
							Transparency = SHIMMER_TRANSPARENCY,
						}),
					},
				}),

				scope:New("TextButton")({
					Name = "ItemHitbox",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = DROP_SLOT_ZINDEX.HITBOX,

					[Fusion.OnEvent("MouseEnter")] = function()
						hoveredDropInfo:set({
							drop = drop,
							slotIndex = idx,
							totalSlots = #previewDrops,
						})
					end,
					[Fusion.OnEvent("MouseLeave")] = function()
						local current = Fusion.peek(hoveredDropInfo)
						if current and current.drop.id == drop.id then
							hoveredDropInfo:set(nil)
						end
					end,
					[Fusion.OnEvent("Activated")] = props.OnClick,
				}),
			},
		})

		table.insert(dropStripChildren, iconCard)
	end

	local activeTooltip = scope:New("Frame")({
		Name = "ActiveTooltip",
		Size = UDim2.fromOffset(136, 34),
		Position = scope:Computed(function(use: FusionUseFn)
			local info = use(hoveredDropInfo)
			if not info then
				return UDim2.new(0.5, 0, 0, -6)
			end
			local xRatio = (info.slotIndex - 0.5) / math.max(1, info.totalSlots)
			local clampedX = math.clamp(xRatio, 0.24, 0.76)
			return UDim2.new(clampedX, 0, 0, -6)
		end),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = PANEL_BG,
		BackgroundTransparency = PANEL_BG_TRANSPARENCY,
		BorderSizePixel = 0,
		Visible = scope:Computed(function(use: FusionUseFn)
			return use(hoveredDropInfo) ~= nil
		end),
		ZIndex = 30,

		[Fusion.Children] = {
			Shadow(scope, {
				Size = UDim2.new(1, 10, 1, 10),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = 4,
				Transparency = 0.5,
				ZIndex = 0,
			}),

			scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),

			scope:New("UIStroke")({
				Color = PANEL_BORDER,
				Thickness = 1,
				Transparency = PANEL_BORDER_TRANSPARENCY,
			}),

			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			}),

			scope:New("TextLabel")({
				Name = "ItemName",
				Size = UDim2.new(1, 0, 0, 13),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use: FusionUseFn)
					local info = use(hoveredDropInfo)
					if not info then
						return ""
					end
					local sepPos = string.find(info.drop.id, ":", 1, true)
					local baseSkinId = info.drop.skinId or (sepPos and string.sub(info.drop.id, 1, sepPos - 1)) or info.drop.id
					local weaponName = info.drop.weaponName or (sepPos and string.sub(info.drop.id, sepPos + 1))
					local resolved = if info.drop.category == "GunSkin"
						then CosmeticLookup.getSkinById(baseSkinId)
						else CosmeticLookup.getCardById(info.drop.id)
					local baseName = if resolved then resolved.name else baseSkinId
					local formattedName = if info.drop.packName
						then `{baseName} {info.drop.packName}`
						elseif info.drop.rarity == "Mythic" and weaponName then `{baseName} ({weaponName})`
						else baseName
					return string.upper(formattedName)
				end),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 10,
				Font = Theme.Text.Black,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 31,
			}),

			scope:New("TextLabel")({
				Name = "RarityAndRate",
				Size = UDim2.new(1, 0, 0, 13),
				Position = UDim2.fromOffset(0, 13),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use: FusionUseFn)
					local info = use(hoveredDropInfo)
					if not info then
						return ""
					end
					local _, itemChance = CratesConfig.getItemChance(crate, info.drop)
					local rLabel = CratesConfig.RarityLabels[info.drop.rarity] or info.drop.rarity
					return string.format("%s / %s CHANCE", rLabel, CratesConfig.formatChance(itemChance))
				end),
				TextColor3 = scope:Computed(function(use: FusionUseFn)
					local info = use(hoveredDropInfo)
					if not info then
						return Color3.fromRGB(255, 255, 255)
					end
					return CratesConfig.getRarityColor(info.drop.rarity)
				end),
				TextSize = 9,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 31,
			}),
		},
	})

	return scope:New("Frame")({
		Name = crate.id .. "_Card",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,

		[Fusion.Children] = {
			scope:Computed(function(use: FusionUseFn, modalScope: FusionScope)
				if use(isInfoModalOpen) then
					return CrateInfoModal(modalScope, {
						Crate = crate,
						OnClose = closeInfoModal,
						ZIndex = 100,
					})
				end
				return nil
			end),

			Shadow(scope, {
				Size = UDim2.new(1, 16, 1, 16),
				Position = UDim2.new(0.5, 0, 0.5, 4),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Spread = 6,
				Transparency = 0.6,
				ZIndex = 0,
			}),

			scope:New("Frame")({
				Name = "ScaleContainer",
				Size = UDim2.fromScale(1, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIScale")({ Scale = cardScale }),

					scope:New("Frame")({
						Name = "Card",
						Size = UDim2.fromScale(1, 1),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						BackgroundColor3 = PANEL_BG,
						BackgroundTransparency = PANEL_BG_TRANSPARENCY,
						BorderSizePixel = 0,

						[Fusion.Children] = {
							breathingScale,
							scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),

							scope:New("UIStroke")({
								Color = if isLegendaryCrate then Color3.fromRGB(255, 255, 255) else borderStrokeColor,
								Thickness = borderStrokeThickness,
								Transparency = borderStrokeTransparency,
								BorderStrokePosition = Enum.BorderStrokePosition.Inner,
								ZIndex = 10,
								[Fusion.Children] = if isLegendaryCrate and borderShimmerGradient
									then {
										borderShimmerGradient,
									}
									else nil,
							}),

							scope:New("ImageLabel")({
								Name = "Stripes",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Image = Theme.Patterns.DiagonalStripes.Fat,
								ImageColor3 = theme.StripeColor,
								ImageTransparency = theme.StripeTransparency,
								ScaleType = Enum.ScaleType.Tile,
								TileSize = UDim2.fromOffset(Theme.Section.Stripe.TileSize, Theme.Section.Stripe.TileSize),
								ZIndex = 1,
							}),

							scope:New("UIGradient")({
								Color = if isMythicCrate
									then MYTHIC_CARD_GRADIENT
									elseif isLegendaryCrate then LEGENDARY_CARD_GRADIENT
									elseif isElite then ELITE_GRADIENT
									else PANEL_GRADIENT,
								Rotation = 90,
							}),

							auraImage,

							scope:New("Frame")({
								Name = "Content",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								ZIndex = 5,

								[Fusion.Children] = {
									scope:New("UIPadding")({
										PaddingLeft = UDim.new(0, 12),
										PaddingRight = UDim.new(0, 12),
										PaddingTop = UDim.new(0, 10),
										PaddingBottom = UDim.new(0, 8),
									}),

									scope:New("Frame")({
										Name = "Header",
										Size = UDim2.new(1, 0, 0, 48),
										BackgroundTransparency = 1,

										[Fusion.Children] = {
											scope:New("Frame")({
												Name = "RarityPill",
												Size = UDim2.fromOffset(66, 15),
												Position = UDim2.fromOffset(0, 0),
												BackgroundColor3 = rarityColor,
												BackgroundTransparency = 0.82,
												BorderSizePixel = 0,

												[Fusion.Children] = {
													scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
													scope:New("UIStroke")({
														Color = rarityColor,
														Thickness = 1,
														Transparency = 0.35,
													}),
													scope:New("TextLabel")({
														Name = "RarityLabel",
														Size = UDim2.fromScale(1, 1),
														BackgroundTransparency = 1,
														Text = CratesConfig.RarityLabels[crate.rarity] or crate.rarity,
														TextColor3 = rarityColor,
														TextSize = 9.5,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Center,
														TextYAlignment = Enum.TextYAlignment.Center,
													}),
												},
											}),

											scope:New("TextLabel")({
												Name = "Title",
												Size = UDim2.new(1, 0, 0, 18),
												Position = UDim2.fromOffset(0, 16),
												BackgroundTransparency = 1,
												Text = string.upper(crate.name),
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextSize = 14,
												Font = Theme.Text.Black,
												TextXAlignment = Enum.TextXAlignment.Left,
												TextYAlignment = Enum.TextYAlignment.Center,
												TextTruncate = Enum.TextTruncate.AtEnd,

												[Fusion.Children] = {
													scope:New("UIStroke")({
														Color = Color3.fromRGB(0, 0, 0),
														Thickness = 1.2,
														Transparency = 0.5,
													}),
												},
											}),

											scope:New("TextLabel")({
												Name = "Subtitle",
												Size = UDim2.new(1, 0, 0, 13),
												Position = UDim2.fromOffset(0, 33),
												BackgroundTransparency = 1,
												Text = crate.subtitle or "Open to receive rare cosmetics",
												TextColor3 = Color3.fromRGB(160, 165, 180),
												TextSize = 9.5,
												Font = Theme.Text.Semibold,
												TextXAlignment = Enum.TextXAlignment.Left,
												TextYAlignment = Enum.TextYAlignment.Center,
												TextTruncate = Enum.TextTruncate.AtEnd,
											}),
										},
									}),

									scope:New("Frame")({
										Name = "Stage3D",
										Size = UDim2.new(1, 0, 1, -142),
										Position = UDim2.fromOffset(0, 48),
										BackgroundTransparency = 1,

										[Fusion.Children] = {
											scope:New("Frame")({
												Name = "CrateStage",
												Size = UDim2.new(1, 24, 1, 20),
												Position = UDim2.fromScale(0.5, 0.5),
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundTransparency = 1,
												ZIndex = 3,

												[Fusion.Children] = {
													createCrateModelViewport(crate),
												},
											}),
										},
									}),

									scope:New("Frame")({
										Name = "FooterSection",
										Size = UDim2.new(1, 0, 0, 94),
										Position = UDim2.fromScale(0, 1),
										AnchorPoint = Vector2.new(0, 1),
										BackgroundTransparency = 1,

										[Fusion.Children] = {
											activeTooltip,

											scope:New("Frame")({
												Name = "DropPreviewStrip",
												Size = UDim2.new(1, 0, 0, 42),
												Position = UDim2.fromOffset(0, 0),
												BackgroundTransparency = 1,
												ZIndex = 6,

												[Fusion.Children] = dropStripChildren,
											}),

											scope:New("Frame")({
												Name = "DropStats",
												Size = UDim2.new(1, 0, 0, 14),
												Position = UDim2.fromOffset(0, 46),
												BackgroundTransparency = 1,

												[Fusion.Children] = {
													scope:New("TextLabel")({
														Name = "DropCount",
														Size = UDim2.new(0.48, -6, 1, 0),
														Position = UDim2.fromScale(0, 0),
														BackgroundTransparency = 1,
														Text = string.format("%d ITEMS", #crate.drops),
														TextColor3 = Color3.fromRGB(160, 165, 180),
														TextSize = 9,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Left,
														TextYAlignment = Enum.TextYAlignment.Center,
													}),

													scope:New("Frame")({
														Name = "Divider",
														Size = UDim2.fromOffset(1, 10),
														Position = UDim2.fromScale(0.5, 0.5),
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundColor3 = PANEL_BORDER,
														BackgroundTransparency = 0.55,
														BorderSizePixel = 0,
													}),

													scope:New("TextLabel")({
														Name = "JackpotOdds",
														Size = UDim2.new(0.48, -6, 1, 0),
														Position = UDim2.fromScale(1, 0),
														AnchorPoint = Vector2.new(1, 0),
														BackgroundTransparency = 1,
														Text = if isMythicCrate
															then `MYTHIC: {CratesConfig.formatChance(CratesConfig.getChance(crate, "Mythic"))}`
															else `LEGENDARY: {CratesConfig.formatChance(CratesConfig.getChance(crate, "Legendary"))}`,
														TextColor3 = rarityColor,
														TextSize = 9,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Right,
														TextYAlignment = Enum.TextYAlignment.Center,
													}),
												},
											}),

											scope:New("Frame")({
												Name = "PriceRow",
												Size = UDim2.new(1, -34, 0, 30),
												Position = UDim2.fromOffset(0, 64),
												BackgroundColor3 = PANEL_BG,
												BackgroundTransparency = PANEL_BG_TRANSPARENCY,
												BorderSizePixel = 0,

												[Fusion.Children] = {
													scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),

													scope:New("UIStroke")({
														Color = scope:Computed(function(use: FusionUseFn)
															if isPremiumCrate then
																return Color3.fromRGB(255, 255, 255)
															end
															return if use(isPriceRowHovered) then Color3.fromRGB(255, 255, 255) else PANEL_BORDER
														end),
														Thickness = if isPremiumCrate then 1.2 else 1,
														Transparency = scope:Computed(function(use: FusionUseFn)
															if isPremiumCrate then
																return if use(isPriceRowHovered) then 0.05 else 0.20
															end
															return if use(isPriceRowHovered) then 0.1 else PANEL_BORDER_TRANSPARENCY
														end),
														[Fusion.Children] = if isPremiumCrate and priceShimmerGradient
															then {
																priceShimmerGradient,
															}
															else nil,
													}),

													scope:New("UIPadding")({
														PaddingLeft = UDim.new(0, 10),
														PaddingRight = UDim.new(0, 10),
													}),

													scope:New("TextLabel")({
														Name = "PriceLabel",
														Size = UDim2.fromScale(0.35, 1),
														Position = UDim2.fromScale(0, 0),
														BackgroundTransparency = 1,
														Text = "PRICE",
														TextColor3 = scope:Computed(function(use: FusionUseFn)
															return if use(isPriceRowHovered)
																then Color3.fromRGB(255, 255, 255)
																else Color3.fromRGB(160, 165, 180)
														end),
														TextSize = 10,
														Font = Theme.Text.Bold,
														TextXAlignment = Enum.TextXAlignment.Left,
														TextYAlignment = Enum.TextYAlignment.Center,
													}),

													scope:New("TextLabel")({
														Name = "PriceAmount",
														Size = UDim2.fromScale(0.65, 1),
														Position = UDim2.fromScale(1, 0),
														AnchorPoint = Vector2.new(1, 0),
														BackgroundTransparency = 1,
														Text = string.format("%s CR", formatNumber(crate.price)),
														TextColor3 = CratesConfig.getRarityColor("Rare"),
														TextSize = 14,
														Font = Theme.Text.Black,
														TextXAlignment = Enum.TextXAlignment.Right,
														TextYAlignment = Enum.TextYAlignment.Center,
													}),

													scope:New("TextButton")({
														Name = "PriceHitbox",
														Size = UDim2.fromScale(1, 1),
														BackgroundTransparency = 1,
														Text = "",
														AutoButtonColor = false,
														ZIndex = 10,

														[Fusion.OnEvent("MouseEnter")] = function()
															isPriceRowHovered:set(true)
															isHovered:set(true)
														end,
														[Fusion.OnEvent("MouseLeave")] = function()
															isPriceRowHovered:set(false)
														end,
														[Fusion.OnEvent("Activated")] = props.OnClick,
													}),
												},
											}),

											scope:New("Frame")({
												Name = "InfoButtonContainer",
												Size = UDim2.fromOffset(30, 30),
												Position = UDim2.new(1, 0, 0, 64),
												AnchorPoint = Vector2.new(1, 0),
												BackgroundColor3 = PANEL_BG,
												BackgroundTransparency = PANEL_BG_TRANSPARENCY,
												BorderSizePixel = 0,
												ZIndex = 8,

												[Fusion.Children] = {
													scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),

													scope:New("UIStroke")({
														Color = scope:Computed(function(use: FusionUseFn)
															if isPremiumCrate then
																return Color3.fromRGB(255, 255, 255)
															end
															return if use(isInfoHovered) then Color3.fromRGB(200, 200, 220) else PANEL_BORDER
														end),
														Thickness = if isPremiumCrate then 1.2 else 1,
														Transparency = scope:Computed(function(use: FusionUseFn)
															if isPremiumCrate then
																return if use(isInfoHovered) then 0.05 else 0.20
															end
															return if use(isInfoHovered) then 0.1 else PANEL_BORDER_TRANSPARENCY
														end),
														[Fusion.Children] = if isPremiumCrate and infoShimmerGradient
															then {
																infoShimmerGradient,
															}
															else nil,
													}),

													scope:New("TextLabel")({
														Name = "InfoIcon",
														Size = UDim2.fromScale(1, 1),
														BackgroundTransparency = 1,
														Text = "?",
														TextColor3 = scope:Computed(function(use: FusionUseFn)
															return if use(isInfoHovered) then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(160, 165, 180)
														end),
														TextSize = 14,
														Font = Theme.Text.Black,
														TextXAlignment = Enum.TextXAlignment.Center,
														TextYAlignment = Enum.TextYAlignment.Center,
													}),

													scope:New("TextButton")({
														Name = "InfoHitbox",
														Size = UDim2.fromScale(1, 1),
														BackgroundTransparency = 1,
														Text = "",
														AutoButtonColor = false,
														ZIndex = 10,

														[Fusion.OnEvent("MouseEnter")] = function()
															isInfoHovered:set(true)
														end,
														[Fusion.OnEvent("MouseLeave")] = function()
															isInfoHovered:set(false)
														end,
														[Fusion.OnEvent("Activated")] = openInfoModal,
													}),
												},
											}),
										},
									}),
								},
							}),

							scope:New("TextButton")({
								Name = "CardHitbox",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = "",
								AutoButtonColor = false,
								Active = true,
								ZIndex = 4,

								[Fusion.OnEvent("MouseEnter")] = onMouseEnter,
								[Fusion.OnEvent("MouseLeave")] = onMouseLeave,
								[Fusion.OnEvent("Activated")] = props.OnClick,
							}),
						},
					}),
				},
			}),
		},
	})
end

return CrateCard
