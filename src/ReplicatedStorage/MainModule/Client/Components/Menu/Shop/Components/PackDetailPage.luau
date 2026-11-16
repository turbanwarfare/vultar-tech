--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)

local BundleTypes = require(script.Parent.BundleDetailPage.Types)
local BundleConstants = require(script.Parent.BundleDetailPage.Constants)
local BundleItemList = require(script.Parent.BundleDetailPage.BundleItemList)
local PlayerCardPreview = require(script.Parent.BundleDetailPage.PlayerCardPreview)
local GunSkinPreview = require(script.Parent.BundleDetailPage.GunSkinPreview)
local PurchaseRedirectController = require(script.Parent.Parent.PurchaseRedirectController)
local EMPTY = ""
local COLOR_CLR_SEQ_2 = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 140, 220)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 120, 200)), ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 100, 180)), })
local COLOR_CLR_SEQ = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 210, 110)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 190, 90)), ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 160, 70)), })

type FusionScope = BundleTypes.FusionScope
type FusionUseFn = BundleTypes.FusionUseFn
type FusionValue<T> = BundleTypes.FusionValue<T>
type BundleItem = BundleTypes.BundleItem

export type PackDetailPageProps = {
	PackName: string,
	PackId: string,
	SkinId: string,
	ImageId: string,
	GamepassId: number,
	OnBack: () -> (),
}

local function PackDetailPage(scope: FusionScope, props: PackDetailPageProps): Frame
	local packName = props.PackName:gsub(" Pack", EMPTY)
	local isButtonHovered = scope:Value(false)

	local items: { BundleItem } = {
		{
			type = "PlayerCard",
			id = props.PackId .. "_PlayerCard",
			name = packName .. " Card",
			imageId = props.ImageId,
			animated = false,
		},
		{
			type = "GunSkin",
			id = props.PackId .. "_GunSkin",
			name = props.SkinId,
			imageId = props.ImageId,
			skinId = props.SkinId,
			gunName = "H-82",
		},
	}

	local selectedItem: FusionValue<BundleItem?> = scope:Value(items[1])

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
		Name = "PackDetailPage",
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
						Name = "PackName",
						Size = UDim2.new(1, 0, 0, 50),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Text = string.upper(props.PackName),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 42,
						Font = Enum.Font.GothamBlack,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),

					scope:New("TextLabel")({
						Name = "Subtitle",
						Size = UDim2.new(1, 0, 0, 28),
						Position = UDim2.new(0.5, 0, 0, 54),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Text = "COSMETIC PACK",
						TextColor3 = Color3.fromRGB(100, 200, 255),
						TextSize = 18,
						Font = Enum.Font.GothamBold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "CenteredContainer",
				Size = UDim2.new(0, BundleConstants.CONTENT_WIDTH, 1, -210),
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
								Size = UDim2.new(0, BundleConstants.LIST_WIDTH, 1, 0),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									BundleItemList(scope, {
										Items = items,
										SelectedItem = selectedItem,
										HeaderText = "PACK CONTENTS",
									}),
								},
							}),

							scope:New("Frame")({
								Name = "PreviewSection",
								Size = UDim2.new(1, -(BundleConstants.LIST_WIDTH + 16), 1, 0),
								Position = UDim2.fromOffset(BundleConstants.LIST_WIDTH + 16, 0),
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
										Text = "PURCHASE PACK",
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

return PackDetailPage
