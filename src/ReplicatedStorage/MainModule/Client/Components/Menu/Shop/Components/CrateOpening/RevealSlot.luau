--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CratesConfig = require(MainModule.Shared.Config.Cosmetics.Crates)
local FormatUtils = require(MainModule.Shared.Utils.Text.FormatUtils)

local CosmeticLookup = require(script.Parent.Parent.Parent.Cache.CosmeticLookup)
local SkinModelCache = require(script.Parent.Parent.Parent.Cache.SkinModelCache)
local GunViewportFactory = require(MainModule.Client.Utils.GunViewportFactory)

local AURA_SPIN_TWEEN_INFO = TweenInfo.new(20, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type RollResult = CratesConfig.RollResult

local PREVIEW_GUN = "H-82"
local PANEL_BG = Color3.fromRGB(20, 20, 20)
local GOLD_COLOR = CratesConfig.getRarityColor("Rare")
local STAR_FLARE_ASSET = "rbxassetid://11037779268"

local function resolveItemDetails(roll: RollResult): (string, string)
	if roll.category == "GunSkin" then
		local sepPos = string.find(roll.id, ":", 1, true)
		local baseSkinId = roll.skinId or (sepPos and string.sub(roll.id, 1, sepPos - 1)) or roll.id
		local weaponName = roll.weaponName or (sepPos and string.sub(roll.id, sepPos + 1))

		local skin = CosmeticLookup.getSkinById(baseSkinId)
		local skinName = (skin and skin.name) or baseSkinId

		local displayName = if roll.packName
			then `{skinName} {roll.packName}`
			elseif roll.rarity == "Mythic" and weaponName and weaponName ~= "" then string.format("%s %s", weaponName, skinName)
			else skinName

		return displayName, (skin and skin.imageId) or ""
	end

	local card = CosmeticLookup.getCardById(roll.id)
	return (card and card.name) or roll.id, (card and card.imageId) or ""
end

local function createArtPreview(scope: FusionScope, roll: RollResult, imageId: string, useStaticArt: Types.FusionCanBeState<boolean>?): Instance?
	local isStatic = if typeof(useStaticArt) == "table" and (useStaticArt :: any).type == "State"
		then Fusion.peek(useStaticArt :: any)
		else (useStaticArt == true)

	if isStatic then
		if imageId ~= "" then
			return scope:New("ImageLabel")({
				Name = "CardBackground",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = imageId,
				ScaleType = Enum.ScaleType.Crop,
				ZIndex = 5,
			})
		end

		local rarityColor = CratesConfig.getRarityColor(roll.rarity)
		return scope:New("Frame")({
			Name = "FallbackPlaceholder",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 5,

			[Fusion.Children] = {
				scope:New("TextLabel")({
					Name = "IconGlyph",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = if roll.category == "GunSkin" then "WEAPON SKIN" else "PLAYER CARD",
					TextColor3 = rarityColor,
					TextSize = 12,
					Font = Theme.Text.Black,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),
			},
		})
	end

	if roll.category == "GunSkin" then
		local sepPos = string.find(roll.id, ":", 1, true)
		local baseSkinId = roll.skinId or (sepPos and string.sub(roll.id, 1, sepPos - 1)) or roll.id
		local weaponName = roll.weaponName or (sepPos and string.sub(roll.id, sepPos + 1)) or PREVIEW_GUN

		local model = SkinModelCache.getModel(baseSkinId, weaponName)
		if model then
			local viewport = GunViewportFactory.create(model, {
				fov = 40,
				distanceMultiplier = 0.9,
				rotation = CFrame.Angles(0, -math.pi / 2, 0) * CFrame.Angles(math.rad(14), 0, 0),
				ambient = Color3.fromRGB(140, 140, 150),
				lightDirection = Vector3.new(-0.3, -0.8, -0.4),
			})
			viewport.Name = "SkinViewport"
			viewport.Size = UDim2.fromScale(1, 1)
			viewport.ZIndex = 5
			return viewport
		end
	end

	if imageId ~= "" then
		return scope:New("ImageLabel")({
			Name = "CardBackground",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = imageId,
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 5,
		})
	end

	local rarityColor = CratesConfig.getRarityColor(roll.rarity)
	return scope:New("Frame")({
		Name = "FallbackPlaceholder",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,

		[Fusion.Children] = {
			scope:New("TextLabel")({
				Name = "IconGlyph",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = if roll.category == "GunSkin" then "WEAPON SKIN" else "PLAYER CARD",
				TextColor3 = rarityColor,
				TextSize = 12,
				Font = Theme.Text.Black,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		},
	})
end

export type RevealSlotProps = {
	Roll: RollResult,
	IsVisible: Types.FusionValue<boolean>,
	LayoutOrder: number?,
	SlotIndex: number?,
	Size: UDim2?,
	UseStaticArt: Types.FusionCanBeState<boolean>?,
	IsHoverable: boolean?,
}

local function RevealSlot(scope: FusionScope, props: RevealSlotProps): Frame
	local roll = props.Roll
	local rarityColor = CratesConfig.getRarityColor(roll.rarity)
	local displayName, imageId = resolveItemDetails(roll)

	local isHovered = scope:Value(false)

	local hoverScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if props.IsHoverable and use(isHovered) then
				return 1.035
			end
			return 1.0
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local slotScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(props.IsVisible) then 1 else 0.75
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local combinedScale = scope:Computed(function(use: FusionUseFn)
		return use(slotScale) * use(hoverScale)
	end)

	local slotTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(props.IsVisible) then 0 else 1
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local auraImage = scope:New("ImageLabel")({
		Name = "RadiantAuraBloom",
		Size = UDim2.fromScale(1.05, 1.05),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = STAR_FLARE_ASSET,
		ImageColor3 = rarityColor,
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 2,
		[Fusion.Children] = if roll.rarity == "Mythic"
				and CratesConfig.RarityGradients
				and CratesConfig.RarityGradients.Mythic
			then {
				scope:New("UIGradient")({
					Color = CratesConfig.RarityGradients.Mythic,
					Rotation = 45,
				}),
			}
			else nil,
	})

	local rotTween = TweenService:Create(auraImage, AURA_SPIN_TWEEN_INFO, { Rotation = 360 })
	rotTween:Play()

	table.insert(scope, function()
		rotTween:Cancel()
		rotTween:Destroy()
	end)

	local frameName = if props.SlotIndex then ("BatchSlot_" .. tostring(props.SlotIndex)) else ("RevealSlot_" .. roll.id)

	return scope:New("Frame")({
		Name = frameName,
		Size = props.Size or UDim2.fromOffset(260, 360),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 1,
		ZIndex = scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 10 else 1
		end),

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "ScaleContainer",
				Size = UDim2.fromScale(1, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIScale")({ Scale = combinedScale }),

					scope:New("CanvasGroup")({
						Name = "Card",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = PANEL_BG,
						BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
							local t = use(slotTransparency)
							return math.clamp(0.15 + (t * 0.85), 0, 1)
						end),
						GroupTransparency = slotTransparency,
						BorderSizePixel = 0,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),

							scope:New("UIStroke")({
								Color = rarityColor,
								Thickness = 1.5,
								Transparency = scope:Computed(function(use: FusionUseFn)
									local t = use(slotTransparency)
									return math.clamp(0.1 + (t * 0.9), 0, 1)
								end),
								BorderStrokePosition = Enum.BorderStrokePosition.Inner,
								ZIndex = 10,
								[Fusion.Children] = if roll.rarity == "Mythic"
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

							scope:New("ImageLabel")({
								Name = "Stripes",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Image = Theme.Patterns.DiagonalStripes.Fat,
								ImageColor3 = rarityColor,
								ImageTransparency = scope:Computed(function(use: FusionUseFn)
									local t = use(slotTransparency)
									return math.clamp(0.92 + (t * 0.08), 0, 1)
								end),
								ScaleType = Enum.ScaleType.Tile,
								TileSize = UDim2.fromOffset(48, 48),
								ZIndex = 1,
							}),

							auraImage,

							scope:New("Frame")({
								Name = "ArtContainer",
								Size = UDim2.new(1, -24, 1, -110),
								Position = UDim2.fromOffset(12, 16),
								BackgroundTransparency = 1,
								ZIndex = 5,

								[Fusion.Children] = {
									(function()
										local activeVisual: Instance? = nil
										local function destroyActiveVisual()
											if activeVisual then
												activeVisual:Destroy()
												activeVisual = nil
											end
										end
										table.insert(scope, destroyActiveVisual)

										return scope:Computed(function(use: FusionUseFn)
											local staticVal = if typeof(props.UseStaticArt) == "table" and (props.UseStaticArt :: any).type == "State"
												then use(props.UseStaticArt :: any)
												else props.UseStaticArt

											destroyActiveVisual()
											activeVisual = createArtPreview(scope, roll, imageId, staticVal)
											return activeVisual
										end)
									end)(),
								},
							}),

							scope:New("Frame")({
								Name = "FooterInfo",
								Size = UDim2.new(1, -24, 0, 80),
								Position = UDim2.new(0, 12, 1, -12),
								AnchorPoint = Vector2.new(0, 1),
								BackgroundTransparency = 1,
								ZIndex = 6,

								[Fusion.Children] = {
									scope:New("TextLabel")({
										Name = "ItemName",
										Size = UDim2.new(1, 0, 0, 26),
										Position = UDim2.fromOffset(0, 0),
										BackgroundTransparency = 1,
										Text = string.upper(displayName),
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextSize = 20,
										Font = Theme.Text.Black,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Center,
										TextTruncate = Enum.TextTruncate.AtEnd,
									}),

									scope:New("Frame")({
										Name = "RarityPill",
										Size = UDim2.fromOffset(74, 18),
										Position = UDim2.fromOffset(0, 28),
										BackgroundColor3 = if roll.rarity == "Mythic" then Color3.fromRGB(255, 255, 255) else rarityColor,
										BackgroundTransparency = if roll.rarity == "Mythic" then 0.75 else 0.82,
										BorderSizePixel = 0,

										[Fusion.Children] = {
											scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
											if roll.rarity == "Mythic"
													and CratesConfig.RarityGradients
													and CratesConfig.RarityGradients.Mythic
												then scope:New("UIGradient")({
													Color = CratesConfig.RarityGradients.Mythic,
												})
												else nil,
											scope:New("UIStroke")({
												Color = rarityColor,
												Thickness = 1,
												Transparency = 0.35,
												[Fusion.Children] = if roll.rarity == "Mythic"
														and CratesConfig.RarityGradients
														and CratesConfig.RarityGradients.Mythic
													then {
														scope:New("UIGradient")({
															Color = CratesConfig.RarityGradients.Mythic,
														}),
													}
													else nil,
											}),
											scope:New("TextLabel")({
												Name = "Label",
												Size = UDim2.fromScale(1, 1),
												BackgroundTransparency = 1,
												Text = CratesConfig.RarityLabels[roll.rarity] or roll.rarity,
												TextColor3 = rarityColor,
												TextSize = 10,
												Font = Theme.Text.Bold,
												TextXAlignment = Enum.TextXAlignment.Center,
												TextYAlignment = Enum.TextYAlignment.Center,
											}),
										},
									}),

									if roll.isDuplicate
										then scope:New("Frame")({
											Name = "DuplicateNotice",
											Size = UDim2.new(1, 0, 0, 20),
											Position = UDim2.fromOffset(0, 50),
											BackgroundTransparency = 1,

											[Fusion.Children] = {
												scope:New("Frame")({
													Name = "DuplicateTag",
													Size = UDim2.fromOffset(74, 18),
													BackgroundColor3 = Color3.fromRGB(220, 50, 50),
													BackgroundTransparency = 0.75,
													BorderSizePixel = 0,

													[Fusion.Children] = {
														scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
														scope:New("UIStroke")({
															Color = Color3.fromRGB(255, 80, 80),
															Thickness = 1,
															Transparency = 0.4,
														}),
														scope:New("TextLabel")({
															Name = "TagLabel",
															Size = UDim2.fromScale(1, 1),
															BackgroundTransparency = 1,
															Text = "DUPLICATE",
															TextColor3 = Color3.fromRGB(255, 100, 100),
															TextSize = 9,
															Font = Theme.Text.Bold,
															TextXAlignment = Enum.TextXAlignment.Center,
															TextYAlignment = Enum.TextYAlignment.Center,
														}),
													},
												}),

												scope:New("TextLabel")({
													Name = "RefundText",
													Size = UDim2.new(1, -82, 1, 0),
													Position = UDim2.fromOffset(82, 0),
													BackgroundTransparency = 1,
													Text = string.format("+%s CR", FormatUtils.formatNumberWithCommas(roll.refundAmount or 0)),
													TextColor3 = GOLD_COLOR,
													TextSize = 12,
													Font = Theme.Text.Black,
													TextXAlignment = Enum.TextXAlignment.Left,
													TextYAlignment = Enum.TextYAlignment.Center,
												}),
											},
										})
										else scope:New("TextLabel")({
											Name = "CategoryLabel",
											Size = UDim2.new(1, 0, 0, 18),
											Position = UDim2.fromOffset(0, 48),
											BackgroundTransparency = 1,
											Text = CratesConfig.CategoryLabels[roll.category] or roll.category,
											TextColor3 = Color3.fromRGB(150, 155, 170),
											TextSize = 11,
											Font = Theme.Text.Semibold,
											TextXAlignment = Enum.TextXAlignment.Left,
											TextYAlignment = Enum.TextYAlignment.Center,
										}),
								},
							}),

							scope:New("TextButton")({
								Name = "HoverHitbox",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = "",
								ZIndex = 12,

								[Fusion.OnEvent("MouseEnter")] = function()
									if props.IsHoverable then
										isHovered:set(true)
									end
								end,
								[Fusion.OnEvent("MouseLeave")] = function()
									if props.IsHoverable then
										isHovered:set(false)
									end
								end,
							}),
						},
					}),
				},
			}),
		},
	})
end

return RevealSlot
