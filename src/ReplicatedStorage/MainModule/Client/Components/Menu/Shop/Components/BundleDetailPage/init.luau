--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)

local BundleTypes = require(script.Types)
local Constants = require(script.Constants)
local BundleItemList = require(script.BundleItemList)
local PlayerCardPreview = require(script.PlayerCardPreview)
local GunSkinPreview = require(script.GunSkinPreview)
local ChatGradientPreview = require(script.ChatGradientPreview)
local PurchaseRedirectController = require(script.Parent.Parent.PurchaseRedirectController)

type FusionScope = BundleTypes.FusionScope
type FusionUseFn = BundleTypes.FusionUseFn
type FusionValue<T> = BundleTypes.FusionValue<T>

export type BundleItem = BundleTypes.BundleItem
export type BundleDetailPageProps = BundleTypes.BundleDetailPageProps

local CLASS_HEADER_HEIGHT = 16
local CLASS_SECTION_GAP = 3

local function getClassBoxHeight(): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 34
	end
	local height = camera.ViewportSize.Y
	if height >= 1400 then
		return 42
	end
	if height >= 1200 then
		return 38
	end
	return 32
end
local CLASS_BOX_GAP = 6
local CLASS_BOX_BG = Color3.fromRGB(255, 255, 255)
local CLASS_BOX_BG_TRANSPARENCY = 0.92
local CLASS_BOX_HOVER_TRANSPARENCY = 0.84
local CLASS_BOX_SELECTED_BORDER = Color3.fromRGB(0, 220, 70)

local function isGunSkinBundle(items: { BundleItem }): boolean
	local hasGunSkin = false
	for _, item in items do
		if item.type == "GunSkin" then
			hasGunSkin = true
		end
	end
	return hasGunSkin
end

local function groupItemsByClass(items: { BundleItem }): { { className: string, guns: { BundleItem } } }
	local order: { string } = {}
	local groups: { [string]: { BundleItem } } = {}

	for _, item in items do
		local className = item.name or "Other"
		if not groups[className] then
			groups[className] = {}
			table.insert(order, className)
		end
		table.insert(groups[className], item)
	end

	local result: { { className: string, guns: { BundleItem } } } = {}
	for _, className in order do
		table.insert(result, { className = className, guns = groups[className] })
	end
	return result
end

local function getFactionLabel(gunName: string?): string
	if not gunName then
		return ""
	end
	return if gunName:sub(1, 1) == "H" then "DEFENDER" else "HOSTILE"
end

local function createClassGunGrid(scope: FusionScope, items: { BundleItem }, selectedItem: FusionValue<BundleItem?>): Frame
	local classBoxHeight = getClassBoxHeight()
	local gunSkinItems: { BundleItem } = {}
	for _, item in items do
		if item.type == "GunSkin" then
			table.insert(gunSkinItems, item)
		end
	end

	local classGroups = groupItemsByClass(gunSkinItems)
	local sectionChildren: { Instance } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, CLASS_SECTION_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		scope:New("TextLabel")({
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = "BUNDLE CONTENTS",
			TextColor3 = Color3.fromRGB(165, 165, 175),
			TextSize = 10,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
		}),
	}

	for groupIdx, group in classGroups do
		local sectionFrame = scope:New("Frame")({
			Name = "Class_" .. group.className,
			Size = UDim2.new(1, 0, 0, CLASS_HEADER_HEIGHT + classBoxHeight),
			BackgroundTransparency = 1,
			LayoutOrder = groupIdx,

			[Fusion.Children] = (function()
				local children: { Instance } = {
					scope:New("TextLabel")({
						Name = "ClassName",
						Size = UDim2.new(1, 0, 0, CLASS_HEADER_HEIGHT),
						BackgroundTransparency = 1,
						Text = string.upper(group.className),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 10,
						Font = Enum.Font.GothamBlack,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Bottom,
					}),
				}

				for gunIdx, item in group.guns do
					local isHovered = scope:Value(false)
					local isSelected = scope:Computed(function(use: FusionUseFn)
						local sel = use(selectedItem)
						return sel ~= nil and sel.id == item.id
					end)

					local boxWidth = (1 / #group.guns)
					local xPos = (gunIdx - 1) * boxWidth
					local factionText = getFactionLabel(item.gunName)

					table.insert(
						children,
						scope:New("TextButton")({
							Name = "Gun_" .. (item.gunName or item.id),
							Size = UDim2.new(boxWidth, -CLASS_BOX_GAP, 0, classBoxHeight),
							Position = UDim2.new(xPos, if gunIdx == 1 then 0 else CLASS_BOX_GAP / 2, 0, CLASS_HEADER_HEIGHT),
							BackgroundColor3 = CLASS_BOX_BG,
							BackgroundTransparency = scope:Spring(
								scope:Computed(function(use: FusionUseFn)
									return if use(isHovered) or use(isSelected) then CLASS_BOX_HOVER_TRANSPARENCY else CLASS_BOX_BG_TRANSPARENCY
								end),
								40,
								1
							),
							Text = "",
							AutoButtonColor = false,

							[Fusion.Children] = {
								scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
								scope:New("UIStroke")({
									Color = scope:Computed(function(use: FusionUseFn)
										if use(isSelected) then
											return CLASS_BOX_SELECTED_BORDER
										end
										return if use(isHovered) then Color3.fromRGB(120, 125, 135) else Color3.fromRGB(80, 85, 95)
									end),
									Thickness = scope:Computed(function(use: FusionUseFn)
										return if use(isSelected) then 1.5 else 1
									end),
									Transparency = scope:Computed(function(use: FusionUseFn)
										return if use(isSelected) or use(isHovered) then 0.2 else 0.55
									end),
								}),

								scope:New("TextLabel")({
									Name = "GunName",
									Size = UDim2.new(1, 0, 0, 16),
									Position = UDim2.new(0, 0, 0.5, -3),
									AnchorPoint = Vector2.new(0, 0.5),
									BackgroundTransparency = 1,
									Text = item.gunName or item.id,
									TextColor3 = Color3.fromRGB(255, 255, 255),
									TextSize = 12,
									Font = Enum.Font.GothamBold,
								}),

								scope:New("TextLabel")({
									Name = "FactionLabel",
									Size = UDim2.new(1, 0, 0, 10),
									Position = UDim2.new(0, 0, 0.5, 9),
									AnchorPoint = Vector2.new(0, 0.5),
									BackgroundTransparency = 1,
									Text = factionText,
									TextColor3 = if factionText == "DEFENDER" then Color3.fromRGB(255, 100, 100) else Color3.fromRGB(100, 170, 255),
									TextSize = 8,
									Font = Enum.Font.GothamBold,
									TextTransparency = 0.3,
								}),
							},

							[Fusion.OnEvent("MouseEnter")] = function()
								isHovered:set(true)
								selectedItem:set(item)
							end,
							[Fusion.OnEvent("MouseLeave")] = function()
								isHovered:set(false)
							end,
						})
					)
				end

				return children
			end)(),
		})
		table.insert(sectionChildren, sectionFrame)
	end

	local playerCardItem: BundleItem? = nil
	for _, item in items do
		if item.type == "PlayerCard" then
			playerCardItem = item
			break
		end
	end

	if playerCardItem then
		local pcItem = playerCardItem :: BundleItem
		local isHovered = scope:Value(false)
		local isSelected = scope:Computed(function(use: FusionUseFn)
			local sel = use(selectedItem)
			return sel ~= nil and sel.id == pcItem.id
		end)

		table.insert(
			sectionChildren,
			scope:New("Frame")({
				Name = "PlayerCardSection",
				Size = UDim2.new(1, 0, 0, CLASS_HEADER_HEIGHT + classBoxHeight),
				BackgroundTransparency = 1,
				LayoutOrder = #classGroups + 1,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "SectionName",
						Size = UDim2.new(1, 0, 0, CLASS_HEADER_HEIGHT),
						BackgroundTransparency = 1,
						Text = "PLAYER CARD",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 10,
						Font = Enum.Font.GothamBlack,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Bottom,
					}),

					scope:New("TextButton")({
						Name = "CardButton",
						Size = UDim2.new(1, 0, 0, classBoxHeight),
						Position = UDim2.fromOffset(0, CLASS_HEADER_HEIGHT),
						BackgroundColor3 = CLASS_BOX_BG,
						BackgroundTransparency = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								return if use(isHovered) or use(isSelected) then CLASS_BOX_HOVER_TRANSPARENCY else CLASS_BOX_BG_TRANSPARENCY
							end),
							40,
							1
						),
						Text = "",
						AutoButtonColor = false,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
							scope:New("UIStroke")({
								Color = scope:Computed(function(use: FusionUseFn)
									if use(isSelected) then
										return CLASS_BOX_SELECTED_BORDER
									end
									return if use(isHovered) then Color3.fromRGB(120, 125, 135) else Color3.fromRGB(80, 85, 95)
								end),
								Thickness = scope:Computed(function(use: FusionUseFn)
									return if use(isSelected) then 1.5 else 1
								end),
								Transparency = scope:Computed(function(use: FusionUseFn)
									return if use(isSelected) or use(isHovered) then 0.2 else 0.55
								end),
							}),

							scope:New("TextLabel")({
								Name = "CardName",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = string.upper(pcItem.name or "ITEM") .. " PLAYER CARD",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 12,
								Font = Enum.Font.GothamBold,
							}),
						},

						[Fusion.OnEvent("MouseEnter")] = function()
							isHovered:set(true)
							selectedItem:set(pcItem)
						end,
						[Fusion.OnEvent("MouseLeave")] = function()
							isHovered:set(false)
						end,
					}),
				},
			})
		)
	end

	local chatGradientItem: BundleItem? = nil
	for _, item in items do
		if item.type == "ChatGradient" then
			chatGradientItem = item
			break
		end
	end

	if chatGradientItem then
		local cgItem = chatGradientItem :: BundleItem
		local isHovered = scope:Value(false)
		local isSelected = scope:Computed(function(use: FusionUseFn)
			local sel = use(selectedItem)
			return sel ~= nil and sel.id == cgItem.id
		end)

		table.insert(
			sectionChildren,
			scope:New("Frame")({
				Name = "ChatGradientSection",
				Size = UDim2.new(1, 0, 0, CLASS_HEADER_HEIGHT + classBoxHeight),
				BackgroundTransparency = 1,
				LayoutOrder = #classGroups + 3,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "SectionName",
						Size = UDim2.new(1, 0, 0, CLASS_HEADER_HEIGHT),
						BackgroundTransparency = 1,
						Text = "CHAT GRADIENT",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 10,
						Font = Enum.Font.GothamBlack,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Bottom,
					}),

					scope:New("TextButton")({
						Name = "GradientButton",
						Size = UDim2.new(1, 0, 0, classBoxHeight),
						Position = UDim2.fromOffset(0, CLASS_HEADER_HEIGHT),
						BackgroundColor3 = CLASS_BOX_BG,
						BackgroundTransparency = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								return if use(isHovered) or use(isSelected) then CLASS_BOX_HOVER_TRANSPARENCY else CLASS_BOX_BG_TRANSPARENCY
							end),
							40,
							1
						),
						Text = "",
						AutoButtonColor = false,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
							scope:New("UIStroke")({
								Color = scope:Computed(function(use: FusionUseFn)
									if use(isSelected) then
										return CLASS_BOX_SELECTED_BORDER
									end
									return if use(isHovered) then Color3.fromRGB(120, 125, 135) else Color3.fromRGB(80, 85, 95)
								end),
								Thickness = scope:Computed(function(use: FusionUseFn)
									return if use(isSelected) then 1.5 else 1
								end),
								Transparency = scope:Computed(function(use: FusionUseFn)
									return if use(isSelected) or use(isHovered) then 0.2 else 0.55
								end),
							}),

							scope:New("TextLabel")({
								Name = "GradientName",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = string.upper(cgItem.name or "ITEM") .. " CHAT GRADIENT",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 12,
								Font = Enum.Font.GothamBold,
							}),
						},

						[Fusion.OnEvent("MouseEnter")] = function()
							isHovered:set(true)
							selectedItem:set(cgItem)
						end,
						[Fusion.OnEvent("MouseLeave")] = function()
							isHovered:set(false)
						end,
					}),
				},
			})
		)
	end

	return scope:New("ScrollingFrame")({
		Name = "ClassGunGrid",
		Size = UDim2.new(0, Constants.LIST_WIDTH, 1, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65),
		ScrollBarImageTransparency = 0.4,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,
		ClipsDescendants = true,

		[Fusion.Children] = sectionChildren,
	})
end

local COLOR_CLR_SEQ_2 = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 140, 220)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 120, 200)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 100, 180)),
})
local COLOR_CLR_SEQ = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 210, 110)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 190, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 160, 70)),
})

local function BundleDetailPage(scope: FusionScope, props: BundleDetailPageProps): Frame
	local selectedItem: FusionValue<BundleItem?> = scope:Value(props.Items[1] or nil)
	local isButtonHovered = scope:Value(false)

	local buttonScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isButtonHovered) then 1.02 else 1
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local function promptPurchase()
		PurchaseRedirectController.promptPurchase(props.GamepassId)
	end

	local previewImageId = scope:Computed(function(use: FusionUseFn)
		local item = use(selectedItem)
		return if item then (item.imageId or "") else ""
	end)

	local previewIsAnimated = scope:Computed(function(use: FusionUseFn)
		local item = use(selectedItem)
		return if item then (item.animated or false) else false
	end)

	local previewName = scope:Computed(function(use: FusionUseFn)
		local item = use(selectedItem)
		return if item then string.upper(item.name) else ""
	end)

	return scope:New("Frame")({
		Name = "BundleDetailPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 100),
				Position = UDim2.new(0.5, 0, 0, 20),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "BundleName",
						Size = UDim2.new(1, 0, 0, 50),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Text = string.upper(props.BundleName),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 42,
						Font = Enum.Font.GothamBlack,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "CenteredContainer",
				Size = UDim2.new(0, Constants.CONTENT_WIDTH, 1, -210),
				Position = UDim2.new(0.5, 0, 0, 130),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "ContentArea",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("Frame")({
								Name = "LeftColumn",
								Size = UDim2.new(0, Constants.LIST_WIDTH, 1, 0),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									if isGunSkinBundle(props.Items)
										then createClassGunGrid(scope, props.Items, selectedItem)
										else BundleItemList(scope, {
											Items = props.Items,
											SelectedItem = selectedItem,
										}),
								},
							}),

							scope:New("Frame")({
								Name = "PreviewSection",
								Size = UDim2.new(1, -(Constants.LIST_WIDTH + 16), 1, 0),
								Position = UDim2.fromOffset(Constants.LIST_WIDTH + 16, 0),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									scope:New("Frame")({
										Name = "PreviewHeader",
										Size = UDim2.new(1, 0, 0, 28),
										BackgroundTransparency = 1,

										[Fusion.Children] = {
											scope:New("TextLabel")({
												Name = "PreviewTitle",
												Size = UDim2.new(1, 0, 0, 10),
												BackgroundTransparency = 1,
												Text = "PREVIEW",
												TextColor3 = Color3.fromRGB(145, 145, 155),
												TextSize = 9,
												Font = Theme.Text.Bold,
												TextXAlignment = Enum.TextXAlignment.Left,
											}),

											scope:New("TextLabel")({
												Name = "ItemName",
												Size = UDim2.new(1, 0, 0, 16),
												Position = UDim2.fromOffset(0, 12),
												BackgroundTransparency = 1,
												Text = previewName,
												TextColor3 = Color3.fromRGB(240, 240, 245),
												TextSize = 14,
												Font = Theme.Text.Bold,
												TextXAlignment = Enum.TextXAlignment.Left,
											}),
										},
									}),

									scope:New("ScrollingFrame")({
										Name = "PreviewContainer",
										Size = UDim2.new(1, 0, 1, -32),
										Position = UDim2.fromOffset(0, 30),
										BackgroundTransparency = 1,
										ScrollBarThickness = 2,
										ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65),
										CanvasSize = UDim2.fromOffset(0, 0),
										AutomaticCanvasSize = Enum.AutomaticSize.Y,
										ScrollingDirection = Enum.ScrollingDirection.Y,
										BorderSizePixel = 0,

										[Fusion.Children] = {
											scope:New("UIListLayout")({
												FillDirection = Enum.FillDirection.Vertical,
												Padding = UDim.new(0, 16),
												SortOrder = Enum.SortOrder.LayoutOrder,
											}),

											PlayerCardPreview(scope, {
												SelectedItem = selectedItem,
												PreviewImageId = previewImageId,
												PreviewIsAnimated = previewIsAnimated,
											}),

											GunSkinPreview(scope, {
												SelectedItem = selectedItem,
											}),

											ChatGradientPreview(scope, {
												SelectedItem = selectedItem,
											}),
										},
									}),
								},
							}),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "Footer",
				Size = UDim2.fromOffset(480, 70),
				Position = UDim2.new(0.5, 0, 1, -70),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("TextButton")({
						Name = "BackButton",
						Size = UDim2.fromOffset(140, 50),
						Position = UDim2.fromScale(0, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundColor3 = Color3.fromRGB(50, 120, 200),
						Text = "",

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
							scope:New("UIStroke")({
								Color = Color3.fromRGB(80, 150, 230),
								Thickness = 2,
								Transparency = 0.2,
							}),

							scope:New("UIGradient")({
								Color = COLOR_CLR_SEQ_2,
								Rotation = 90,
							}),

							scope:New("TextLabel")({
								Name = "Label",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = "< BACK",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 18,
								Font = Enum.Font.GothamBold,
							}),
						},

						[Fusion.OnEvent("Activated")] = props.OnBack,
					}),

					scope:New("Frame")({
						Name = "ButtonContainer",
						Size = UDim2.fromOffset(320, 50),
						Position = UDim2.fromScale(1, 0.5),
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIScale")({ Scale = buttonScale }),

							scope:New("TextButton")({
								Name = "PurchaseButton",
								Size = UDim2.fromScale(1, 1),
								BackgroundColor3 = Color3.fromRGB(45, 180, 80),
								Text = "",

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
									scope:New("UIStroke")({
										Color = Color3.fromRGB(80, 220, 120),
										Thickness = 2,
										Transparency = 0.2,
									}),

									scope:New("UIGradient")({
										Color = COLOR_CLR_SEQ,
										Rotation = 90,
									}),

									scope:New("TextLabel")({
										Name = "ButtonText",
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = "PURCHASE BUNDLE",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextSize = 18,
										Font = Enum.Font.GothamBlack,
									}),
								},

								[Fusion.OnEvent("MouseEnter")] = function()
									isButtonHovered:set(true)
								end,
								[Fusion.OnEvent("MouseLeave")] = function()
									isButtonHovered:set(false)
								end,
								[Fusion.OnEvent("Activated")] = promptPurchase,
							}),
						},
					}),
				},
			}),
		},
	})
end

return BundleDetailPage
