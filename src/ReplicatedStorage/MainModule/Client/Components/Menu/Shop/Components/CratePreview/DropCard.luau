--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CratesConfig = require(MainModule.Shared.Config.Cosmetics.Crates)

local CosmeticLookup = require(script.Parent.Parent.Parent.Cache.CosmeticLookup)
local SkinModelCache = require(script.Parent.Parent.Parent.Cache.SkinModelCache)
local GunViewportFactory = require(MainModule.Client.Utils.GunViewportFactory)
local Constants = require(script.Parent.Constants)

local AURA_PULSE_TWEEN_INFO = TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local SHIMMER_TWEEN_INFO = TweenInfo.new(3.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 1.4)

local MYTHIC = CratesConfig.getRarityColor("Mythic")
local MYTHIC_DARK = MYTHIC:Lerp(Color3.new(0, 0, 0), 0.75)
local MYTHIC_LIGHT = MYTHIC:Lerp(Color3.new(1, 1, 1), 0.45)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type CrateDrop = CratesConfig.CrateDrop

local PREVIEW_GUN = "H-82"

local function resolveDrop(drop: CrateDrop): (string, string)
	if drop.category == "GunSkin" then
		local sepPos = string.find(drop.id, ":", 1, true)
		local baseSkinId = drop.skinId or (sepPos and string.sub(drop.id, 1, sepPos - 1)) or drop.id
		local weaponName = drop.weaponName or (sepPos and string.sub(drop.id, sepPos + 1))
		local skin = CosmeticLookup.getSkinById(baseSkinId)
		local skinName = (skin and skin.name) or baseSkinId
		local displayName = if drop.packName
			then `{skinName} {drop.packName}`
			elseif drop.rarity == "Mythic" and weaponName then `{skinName} ({weaponName})`
			else skinName
		return displayName, (skin and skin.imageId) or ""
	end

	local card = CosmeticLookup.getCardById(drop.id)
	return (card and card.name) or drop.id, (card and card.imageId) or ""
end

local function createArt(scope: FusionScope, drop: CrateDrop, imageId: string): Instance?
	if drop.category == "GunSkin" then
		local sepPos = string.find(drop.id, ":", 1, true)
		local baseSkinId = drop.skinId or (sepPos and string.sub(drop.id, 1, sepPos - 1)) or drop.id
		local weaponName = drop.weaponName or (sepPos and string.sub(drop.id, sepPos + 1)) or PREVIEW_GUN
		local model = SkinModelCache.getModel(baseSkinId, weaponName) or SkinModelCache.getModel(baseSkinId, PREVIEW_GUN)
		if model then
			local viewport = GunViewportFactory.create(model, {
				fov = 40,
				distanceMultiplier = 0.9,
				rotation = CFrame.Angles(0, -math.pi / 2, 0) * CFrame.Angles(math.rad(16), 0, 0),
				ambient = Color3.fromRGB(130, 130, 140),
				lightDirection = Vector3.new(-0.3, -0.8, -0.4),
			})
			viewport.Name = "SkinViewport"
			viewport.Size = UDim2.fromScale(1, 1)
			viewport.ZIndex = 2
			return viewport
		end
	end

	if imageId == "" then
		return nil
	end

	return scope:New("ImageLabel")({
		Name = "CardBackground",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = imageId,
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 2,
	})
end

export type DropCardProps = {
	Drop: CrateDrop,
	Size: UDim2?,
	LayoutOrder: number,
	IsOwned: Types.FusionValue<boolean>?,
}

local function DropCard(scope: FusionScope, props: DropCardProps): Frame
	local drop = props.Drop
	local isMythic = drop.rarity == "Mythic"
	local rarityColor = CratesConfig.getRarityColor(drop.rarity)
	local displayName, imageId = resolveDrop(drop)

	local isHovered = scope:Value(false)

	local isOwnedComputed = scope:Computed(function(use: FusionUseFn)
		return props.IsOwned and use(props.IsOwned) == true or false
	end)

	local cardScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 1.03 else 1
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local borderTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if isMythic then
				return if use(isHovered) then 0.0 else 0.08
			end
			return if use(isHovered) then 0.1 else Theme.Stroke.Strong
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local bgTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0.15 else Constants.PANEL_BG_TRANSPARENCY
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	return scope:New("Frame")({
		Name = drop.id,
		Size = props.Size or UDim2.fromOffset(Constants.DROP_CARD_WIDTH, Constants.DROP_CARD_HEIGHT),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,

		[Fusion.Children] = {
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
						BackgroundColor3 = Constants.PANEL_BG,
						BackgroundTransparency = bgTransparency,
						BorderSizePixel = 0,
						ClipsDescendants = true,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),

							scope:New("UIStroke")({
								Color = if isMythic then MYTHIC_LIGHT else rarityColor,
								Thickness = if isMythic then 2 else 1,
								Transparency = borderTransparency,
								BorderStrokePosition = Enum.BorderStrokePosition.Outer,
								ZIndex = 2,
								[Fusion.Children] = if isMythic
									then {
										scope:New("UIGradient")({
											Color = ColorSequence.new({
												ColorSequenceKeypoint.new(0, MYTHIC_DARK),
												ColorSequenceKeypoint.new(0.25, MYTHIC),
												ColorSequenceKeypoint.new(0.5, MYTHIC_LIGHT),
												ColorSequenceKeypoint.new(0.75, MYTHIC),
												ColorSequenceKeypoint.new(1, MYTHIC_DARK),
											}),
											Rotation = 45,
										}),
									}
									else nil,
							}),

							scope:New("Frame")({
								Name = "ArtHolder",
								Size = UDim2.new(1, 0, 1, -Constants.DROP_FOOTER_HEIGHT),
								BackgroundColor3 = Color3.new(1, 1, 1),
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
								ClipsDescendants = true,

								[Fusion.Children] = {
									if isMythic
										then scope:New("Frame")({
											Name = "MythicSpotlightBackdrop",
											Size = UDim2.fromScale(1, 1),
											BackgroundColor3 = MYTHIC,
											BackgroundTransparency = 0.88,
											BorderSizePixel = 0,
											ZIndex = 1,

											[Fusion.Children] = {
												scope:New("UIGradient")({
													Rotation = 90,
													Color = ColorSequence.new({
														ColorSequenceKeypoint.new(0, MYTHIC_DARK),
														ColorSequenceKeypoint.new(0.45, MYTHIC_LIGHT),
														ColorSequenceKeypoint.new(1, MYTHIC_DARK),
													}),
													Transparency = NumberSequence.new({
														NumberSequenceKeypoint.new(0, 0.95),
														NumberSequenceKeypoint.new(0.45, 0.40),
														NumberSequenceKeypoint.new(1, 0.95),
													}),
												}),
											},
										})
										else nil,

									if isMythic
										then (function()
											local auraImage = scope:New("ImageLabel")({
												Name = "MythicAuraBloom",
												Size = UDim2.fromOffset(68, 68),
												Position = UDim2.fromScale(0.5, 0.46),
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundTransparency = 1,
												Image = "rbxassetid://11037779268",
												ImageColor3 = MYTHIC_LIGHT,
												ImageTransparency = 0.54,
												ScaleType = Enum.ScaleType.Fit,
												ZIndex = 1,
											})

											local auraPulseTween = TweenService:Create(auraImage, AURA_PULSE_TWEEN_INFO, { ImageTransparency = 0.72 })
											auraPulseTween:Play()

											table.insert(scope, function()
												auraPulseTween:Cancel()
												auraPulseTween:Destroy()
											end)

											return auraImage
										end)()
										else nil,

									createArt(scope, drop, imageId),

									scope:Computed(function(use: FusionUseFn)
										if not use(isOwnedComputed) then
											return nil
										end
										return scope:New("Frame")({
											Name = "OwnedBadge",
											Size = UDim2.fromOffset(48, 16),
											Position = UDim2.new(1, -6, 0, 6),
											AnchorPoint = Vector2.new(1, 0),
											BackgroundColor3 = Color3.fromRGB(30, 120, 200),
											BackgroundTransparency = 0.15,
											BorderSizePixel = 0,
											ZIndex = 6,

											[Fusion.Children] = {
												scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
												scope:New("UIStroke")({
													Color = Color3.fromRGB(100, 200, 255),
													Thickness = 1,
													Transparency = 0.3,
												}),
												scope:New("TextLabel")({
													Name = "Label",
													Size = UDim2.fromScale(1, 1),
													BackgroundTransparency = 1,
													Text = "OWNED",
													TextColor3 = Color3.fromRGB(220, 245, 255),
													TextSize = 9,
													Font = Theme.Text.Black,
													TextXAlignment = Enum.TextXAlignment.Center,
													TextYAlignment = Enum.TextYAlignment.Center,
												}),
											},
										})
									end),

									if not isMythic
										then scope:New("Frame")({
											Name = "ArtGradient",
											Size = UDim2.fromScale(1, 1),
											BackgroundColor3 = rarityColor,
											BorderSizePixel = 0,
											ZIndex = 1,

											[Fusion.Children] = {
												scope:New("UIGradient")({
													Rotation = 270,
													Transparency = Constants.ART_FADE_TRANSPARENCY,
												}),
											},
										})
										else nil,
								},
							}),

							if isMythic
								then (function()
									local shimmerGrad = scope:New("UIGradient")({
										Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
										Transparency = NumberSequence.new({
											NumberSequenceKeypoint.new(0, 1),
											NumberSequenceKeypoint.new(0.42, 1),
											NumberSequenceKeypoint.new(0.50, 0.72),
											NumberSequenceKeypoint.new(0.58, 1),
											NumberSequenceKeypoint.new(1, 1),
										}),
										Rotation = 65,
										Offset = Vector2.new(-1.2, 0),
									})

									local shimmerFrame = scope:New("Frame")({
										Name = "MythicHoloShimmer",
										Size = UDim2.fromScale(1, 1),
										BackgroundColor3 = Color3.fromRGB(255, 255, 255),
										BackgroundTransparency = 0,
										BorderSizePixel = 0,
										ZIndex = 8,

										[Fusion.Children] = {
											scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
											shimmerGrad,
										},
									})

									local shimmerTween = TweenService:Create(shimmerGrad, SHIMMER_TWEEN_INFO, { Offset = Vector2.new(1.2, 0) })
									shimmerTween:Play()

									table.insert(scope, function()
										shimmerTween:Cancel()
										shimmerTween:Destroy()
									end)

									return shimmerFrame
								end)()
								else nil,

							scope:New("Frame")({
								Name = "Separator",
								Size = UDim2.new(1, 0, 0, 1),
								Position = UDim2.new(0.5, 0, 1, -Constants.DROP_FOOTER_HEIGHT),
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = if isMythic then MYTHIC else rarityColor,
								BackgroundTransparency = if isMythic then 0.35 else 0.5,
								BorderSizePixel = 0,
								ZIndex = 3,
								[Fusion.Children] = if isMythic
									then {
										scope:New("UIGradient")({
											Color = ColorSequence.new({
												ColorSequenceKeypoint.new(0, MYTHIC_DARK),
												ColorSequenceKeypoint.new(0.5, MYTHIC_LIGHT),
												ColorSequenceKeypoint.new(1, MYTHIC_DARK),
											}),
										}),
									}
									else nil,
							}),

							scope:New("Frame")({
								Name = "Info",
								Size = UDim2.new(1, 0, 0, Constants.DROP_FOOTER_HEIGHT),
								Position = UDim2.new(0, 0, 1, -Constants.DROP_FOOTER_HEIGHT),
								BackgroundTransparency = 1,
								ZIndex = 4,

								[Fusion.Children] = {
									scope:New("TextLabel")({
										Name = "Title",
										Size = UDim2.new(1, -16, 0, 18),
										Position = UDim2.fromOffset(8, 4),
										BackgroundTransparency = 1,
										Text = string.upper(displayName),
										TextColor3 = Constants.TITLE_TEXT,
										TextSize = Theme.Text.Small,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Center,
										TextTruncate = Enum.TextTruncate.AtEnd,
									}),

									scope:New("TextLabel")({
										Name = "Type",
										Size = UDim2.new(1, -78, 0, 16),
										Position = UDim2.fromOffset(8, 24),
										BackgroundTransparency = 1,
										Text = if drop.category == "GunSkin"
												and drop.rarity == "Mythic"
												and (drop.weaponName or string.find(drop.id, ":", 1, true))
											then `{drop.weaponName or string.sub(drop.id, (string.find(drop.id, ":", 1, true) :: number) + 1)} SKIN`
											else (CratesConfig.CategoryLabels[drop.category] or drop.category),
										TextColor3 = Constants.TYPE_TEXT,
										TextSize = Theme.Text.XSmall,
										Font = Theme.Text.Semibold,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Center,
										TextTruncate = Enum.TextTruncate.AtEnd,
									}),

									scope:New("Frame")({
										Name = "Rarity",
										AutomaticSize = Enum.AutomaticSize.X,
										Size = if isMythic then UDim2.fromOffset(0, 18) else UDim2.fromOffset(0, 16),
										Position = if isMythic then UDim2.new(1, -8, 0, 23) else UDim2.new(1, -8, 0, 24),
										AnchorPoint = Vector2.new(1, 0),
										BackgroundColor3 = if isMythic then MYTHIC else rarityColor,
										BackgroundTransparency = if isMythic then 0.15 else 0.88,
										BorderSizePixel = 0,

										[Fusion.Children] = {
											scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),

											if isMythic
												then scope:New("UIGradient")({
													Color = ColorSequence.new({
														ColorSequenceKeypoint.new(0, MYTHIC_DARK),
														ColorSequenceKeypoint.new(0.5, MYTHIC),
														ColorSequenceKeypoint.new(1, MYTHIC_DARK),
													}),
												})
												else nil,

											scope:New("UIStroke")({
												Color = Color3.fromRGB(255, 255, 255),
												Thickness = if isMythic then 1.5 else 1,
												Transparency = if isMythic then 0.05 else 0.4,
												[Fusion.Children] = if isMythic
													then {
														scope:New("UIGradient")({
															Color = ColorSequence.new({
																ColorSequenceKeypoint.new(0, MYTHIC),
																ColorSequenceKeypoint.new(0.5, MYTHIC_LIGHT),
																ColorSequenceKeypoint.new(1, MYTHIC),
															}),
														}),
													}
													else nil,
											}),

											scope:New("UIPadding")({
												PaddingLeft = if isMythic then UDim.new(0, 8) else UDim.new(0, 6),
												PaddingRight = if isMythic then UDim.new(0, 8) else UDim.new(0, 6),
											}),

											scope:New("TextLabel")({
												Name = "Label",
												AutomaticSize = Enum.AutomaticSize.X,
												Size = UDim2.fromScale(0, 1),
												BackgroundTransparency = 1,
												Text = CratesConfig.RarityLabels[drop.rarity] or drop.rarity,
												TextColor3 = if isMythic then Color3.fromRGB(255, 255, 255) else rarityColor,
												TextSize = if isMythic then 10 else 9,
												Font = if isMythic then Theme.Text.Black else Theme.Text.Bold,
												TextXAlignment = Enum.TextXAlignment.Center,
												TextYAlignment = Enum.TextYAlignment.Center,
											}),
										},
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
							}),
						},
					}),
				},
			}),
		},
	})
end

return DropCard
