--!strict
--!native
--!optimize 2

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local EconomyConfig = require(MainModule.Shared.Config.Economy.EconomyConfig)
local PriceCache = require(script.Parent.Parent.Cache.PriceCache)
local Shadow = require(MainModule.Client.Components.Shadow)
local FormatUtils = require(MainModule.Shared.Utils.Text.FormatUtils)
local Network = require(MainModule.Shared.Network)

local SHIMMER_TWEEN_INFO = TweenInfo.new(4.0, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionValue<T> = Types.FusionValue<T>
type CreditProduct = EconomyConfig.CreditProduct

local PANEL_BG = Color3.fromRGB(18, 18, 20)
local PANEL_BG_TRANSPARENCY = 0.12
local PANEL_BORDER = Color3.fromRGB(90, 95, 110)
local PANEL_BORDER_TRANSPARENCY = 0.45

local BEST_VALUE_BG = Color3.fromRGB(30, 27, 20)
local BEST_VALUE_BORDER = Color3.fromRGB(225, 180, 50)

local CREDITS_ICON = "rbxassetid://0"
local ROBUX_ICON = "rbxassetid://11560341132"

local GOLD_SHIMMER_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 135, 25)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 210, 55)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 230)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 210, 55)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 135, 25)),
})

local function getPlayerGui(): PlayerGui?
	local localPlayer = Players.LocalPlayer
	if localPlayer then
		local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			return playerGui
		end
		return localPlayer:WaitForChild("PlayerGui", 5) :: PlayerGui?
	end
	return nil
end

export type BuyCreditsModalProps = {
	OnClose: () -> (),
	ZIndex: number?,
	Parent: Instance?,
}

local function BuyCreditsModal(scope: FusionScope, props: BuyCreditsModalProps): ScreenGui
	local isCloseHovered = scope:Value(false)
	local productPrices: { [number]: FusionValue<number> } = {}
	local productHovers: { [number]: FusionValue<boolean> } = {}

	for _, product in EconomyConfig.CREDIT_PRODUCTS do
		local priceVal = scope:Value(0)
		productPrices[product.ProductId] = priceVal
		productHovers[product.ProductId] = scope:Value(false)
		PriceCache.getProductPriceAsync(product.ProductId, priceVal)
	end

	local bestValueProductId = scope:Computed(function(use: FusionUseFn)
		local bestRatio = 0
		local worstRatio = math.huge
		local bestId: number? = nil
		local validCount = 0

		for _, product in EconomyConfig.CREDIT_PRODUCTS do
			local price = use(productPrices[product.ProductId])
			if price and price > 0 then
				local ratio = product.Credits / price
				validCount += 1
				if ratio >= bestRatio then
					bestRatio = ratio
					bestId = product.ProductId
				end
				if ratio < worstRatio then
					worstRatio = ratio
				end
			end
		end

		if validCount >= 2 and bestRatio > (worstRatio * 1.02) then
			return bestId
		end
		return nil
	end)

	local isModalAlive = true
	local pendingTimeoutThreads: { [number]: thread } = {}
	local revertThreads: { [number]: thread } = {}
	local isPromptOpen: { [number]: boolean } = {}
	local isServerConfirmed: { [number]: boolean } = {}

	table.insert(scope, function()
		isModalAlive = false
		for _, thread in pendingTimeoutThreads do
			task.cancel(thread)
		end
		table.clear(pendingTimeoutThreads)
		for _, thread in revertThreads do
			task.cancel(thread)
		end
		table.clear(revertThreads)
	end)

	local rowStates: { [number]: FusionValue<string> } = {}
	for _, product in EconomyConfig.CREDIT_PRODUCTS do
		rowStates[product.ProductId] = scope:Value("idle")
	end

	local function handlePurchase(productId: number)
		local localPlayer = Players.LocalPlayer
		if not localPlayer then
			warn("[BuyCreditsModal] Cannot prompt purchase: Players.LocalPlayer is nil")
			return
		end

		local statusVal = rowStates[productId]
		if statusVal and Fusion.peek(statusVal) ~= "idle" then
			return
		end

		if statusVal then
			statusVal:set("processing")
		end

		isPromptOpen[productId] = true
		isServerConfirmed[productId] = false
		if revertThreads[productId] then
			task.cancel(revertThreads[productId])
			revertThreads[productId] = nil
		end
		if pendingTimeoutThreads[productId] then
			task.cancel(pendingTimeoutThreads[productId])
			pendingTimeoutThreads[productId] = nil
		end

		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(localPlayer, productId)
		end)
		if not ok then
			warn(`[BuyCreditsModal] PromptProductPurchase failed for product {productId}: {err}`)
			isPromptOpen[productId] = false
			if statusVal and isModalAlive then
				statusVal:set("idle")
			end
		end
	end

	local promptFinishedConn = MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, isPurchased: boolean)
		local localPlayer = Players.LocalPlayer
		if not localPlayer or userId ~= localPlayer.UserId then
			return
		end

		isPromptOpen[productId] = false

		local existingTimeout = pendingTimeoutThreads[productId]
		if existingTimeout then
			task.cancel(existingTimeout)
			pendingTimeoutThreads[productId] = nil
		end

		if not isPurchased then
			isServerConfirmed[productId] = false
			local existingRevert = revertThreads[productId]
			if existingRevert then
				task.cancel(existingRevert)
				revertThreads[productId] = nil
			end

			local statusVal = rowStates[productId]
			if statusVal and isModalAlive then
				statusVal:set("idle")
			end
		else
			local statusVal = rowStates[productId]
			if isServerConfirmed[productId] then
				if revertThreads[productId] then
					task.cancel(revertThreads[productId])
				end
				revertThreads[productId] = task.delay(3.5, function()
					revertThreads[productId] = nil
					if isModalAlive and statusVal and Fusion.peek(statusVal) == "success" then
						statusVal:set("idle")
					end
				end)
			else
				local timeoutThread = task.delay(12, function()
					pendingTimeoutThreads[productId] = nil
					if not isModalAlive then
						return
					end
					if statusVal and Fusion.peek(statusVal) == "processing" then
						statusVal:set("pending")
						task.delay(3.5, function()
							if isModalAlive and Fusion.peek(statusVal) == "pending" then
								statusVal:set("idle")
							end
						end)
					end
				end)
				pendingTimeoutThreads[productId] = timeoutThread
			end
		end
	end)
	table.insert(scope, function()
		promptFinishedConn:Disconnect()
	end)

	local confirmationConn = Network.Economy.onPurchaseConfirmation(function(data)
		local productId = data.productId
		isServerConfirmed[productId] = true

		local existingTimeout = pendingTimeoutThreads[productId]
		if existingTimeout then
			task.cancel(existingTimeout)
			pendingTimeoutThreads[productId] = nil
		end

		if not isModalAlive then
			return
		end

		local statusVal = rowStates[productId]
		if statusVal then
			statusVal:set("success")

			if revertThreads[productId] then
				task.cancel(revertThreads[productId])
				revertThreads[productId] = nil
			end

			if isPromptOpen[productId] then
				revertThreads[productId] = task.delay(25, function()
					revertThreads[productId] = nil
					if isModalAlive and Fusion.peek(statusVal) == "success" then
						statusVal:set("idle")
					end
				end)
			else
				revertThreads[productId] = task.delay(3.5, function()
					revertThreads[productId] = nil
					if isModalAlive and Fusion.peek(statusVal) == "success" then
						statusVal:set("idle")
					end
				end)
			end
		end
	end)
	table.insert(scope, function()
		confirmationConn:Disconnect()
	end)

	local productCount = #EconomyConfig.CREDIT_PRODUCTS
	local productListFullHeight = math.max(236, productCount * 52 + math.max(productCount - 1, 0) * 8)
	local productListHeight = math.min(productListFullHeight, 420)
	local modalHeight = 114 + productListHeight

	local productRows: { Instance } = {
		scope:New("UIListLayout")({
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	}

	for idx, product in EconomyConfig.CREDIT_PRODUCTS do
		local priceVal = productPrices[product.ProductId]
		local isRowHovered = productHovers[product.ProductId]

		local isBestValue = scope:Computed(function(use: FusionUseFn)
			return use(bestValueProductId) == product.ProductId
		end)

		local shimmerGradient = scope:New("UIGradient")({
			Color = GOLD_SHIMMER_GRADIENT,
			Rotation = 0,
			Enabled = isBestValue,
		})

		local shimmerTween = TweenService:Create(shimmerGradient, SHIMMER_TWEEN_INFO, { Rotation = 360 })
		shimmerTween:Play()

		table.insert(scope, function()
			shimmerTween:Cancel()
			shimmerTween:Destroy()
		end)

		local priceText = scope:Computed(function(use: FusionUseFn)
			local price = use(priceVal)
			if price and price > 0 then
				return FormatUtils.formatNumberWithCommas(price)
			elseif price == -1 then
				return "—"
			else
				return "..."
			end
		end)

		local isBuyHovered = scope:Value(false)
		local buyButtonScale = scope:Spring(
			scope:Computed(function(use: FusionUseFn)
				return if use(isBuyHovered) then 1.03 else 1.0
			end),
			Theme.Spring.Responsive.Speed,
			Theme.Spring.Responsive.Damping
		)

		local rowBgTransparency = scope:Spring(
			scope:Computed(function(use: FusionUseFn)
				if use(isBestValue) then
					return if use(isRowHovered) then 0.22 else 0.32
				end
				return if use(isRowHovered) then 0.94 else 1.0
			end),
			Theme.Spring.Snappy.Speed,
			Theme.Spring.Snappy.Damping
		)

		local rowStrokeTransparency = scope:Spring(
			scope:Computed(function(use: FusionUseFn)
				if use(isBestValue) then
					return if use(isRowHovered) then 0.15 else 0.35
				end
				return 1.0
			end),
			Theme.Spring.Snappy.Speed,
			Theme.Spring.Snappy.Damping
		)

		local statusVal = rowStates[product.ProductId]

		local buttonBgColor = scope:Spring(
			scope:Computed(function(use: FusionUseFn)
				local st = use(statusVal)
				if st == "processing" then
					return Color3.fromRGB(45, 50, 65)
				elseif st == "pending" then
					return Color3.fromRGB(55, 50, 35)
				elseif st == "success" then
					return Color3.fromRGB(16, 185, 129)
				else
					return Color3.fromRGB(0, 185, 95)
				end
			end),
			Theme.Spring.Responsive.Speed,
			Theme.Spring.Responsive.Damping
		)

		local buttonStrokeColor = scope:Computed(function(use: FusionUseFn)
			local st = use(statusVal)
			if st == "processing" then
				return Color3.fromRGB(90, 100, 125)
			elseif st == "pending" then
				return Color3.fromRGB(170, 135, 55)
			elseif st == "success" then
				return Color3.fromRGB(110, 245, 180)
			else
				return Color3.fromRGB(140, 245, 170)
			end
		end)

		local isRobuxIconVisible = scope:Computed(function(use: FusionUseFn)
			return use(statusVal) == "idle"
		end)

		local buttonLabelText = scope:Computed(function(use: FusionUseFn)
			local st = use(statusVal)
			if st == "processing" then
				return "PROCESSING"
			elseif st == "pending" then
				return "PENDING"
			elseif st == "success" then
				return "SUCCESS"
			else
				return use(priceText)
			end
		end)

		local buttonLabelSize = scope:Computed(function(use: FusionUseFn)
			local st = use(statusVal)
			if st == "processing" then
				return 11
			elseif st == "pending" then
				return 12
			elseif st == "success" then
				return 13
			else
				return 15
			end
		end)

		local rowContainer = scope:New("Frame")({
			Name = "ProductRow_" .. tostring(product.ProductId),
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = scope:Computed(function(use: FusionUseFn)
				return if use(isBestValue) then BEST_VALUE_BG else Color3.fromRGB(255, 255, 255)
			end),
			BackgroundTransparency = rowBgTransparency,
			BorderSizePixel = 0,
			LayoutOrder = idx,

			[Fusion.Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),

				scope:New("UIStroke")({
					Color = BEST_VALUE_BORDER,
					Thickness = 1,
					Transparency = rowStrokeTransparency,
					[Fusion.Children] = {
						shimmerGradient,
					},
				}),

				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 14),
					PaddingRight = UDim.new(0, 12),
				}),

				scope:New("Frame")({
					Name = "Divider",
					Size = UDim2.new(1, 0, 0, 1),
					Position = UDim2.fromScale(0, 1),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 0.93,
					BorderSizePixel = 0,
					Visible = scope:Computed(function(use: FusionUseFn)
						return not use(isBestValue) and idx < #EconomyConfig.CREDIT_PRODUCTS
					end),
				}),

				scope:New("Frame")({
					Name = "LeftSection",
					Size = UDim2.new(1, -112, 1, 0),
					BackgroundTransparency = 1,

					[Fusion.Children] = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
							Padding = UDim.new(0, 10),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),

						scope:New("ImageLabel")({
							Name = "CoinIcon",
							Size = UDim2.fromOffset(24, 22),
							BackgroundTransparency = 1,
							Image = CREDITS_ICON,
							ScaleType = Enum.ScaleType.Fit,
							LayoutOrder = 1,
						}),

						scope:New("TextLabel")({
							Name = "AmountLabel",
							Size = UDim2.fromOffset(0, 24),
							AutomaticSize = Enum.AutomaticSize.X,
							BackgroundTransparency = 1,
							RichText = true,
							Text = string.format(
								'%s <font color="rgb(145, 150, 165)" size="17">CR</font>',
								FormatUtils.formatNumberWithCommas(product.Credits)
							),
							TextColor3 = Theme.Colors.White,
							TextSize = 21,
							Font = Theme.Text.Black,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Center,
							LayoutOrder = 2,
						}),
					},
				}),

				scope:New("Frame")({
					Name = "ButtonWrapper",
					Size = UDim2.fromOffset(100, 34),
					Position = UDim2.fromScale(1, 0.5),
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,

					[Fusion.Children] = {
						scope:New("UIScale")({ Scale = buyButtonScale }),

						scope:New("TextButton")({
							Name = "PurchaseButton",
							Size = UDim2.fromScale(1, 1),
							BackgroundColor3 = buttonBgColor,
							BackgroundTransparency = 0.05,
							BorderSizePixel = 0,
							AutoButtonColor = false,
							Text = "",

							[Fusion.Children] = {
								scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
								scope:New("UIStroke")({
									Color = buttonStrokeColor,
									Thickness = 1,
									Transparency = scope:Computed(function(use: FusionUseFn)
										return if use(isBuyHovered) then 0.15 else 0.45
									end),
								}),

								scope:New("Frame")({
									Name = "ButtonContent",
									Size = UDim2.fromScale(1, 1),
									BackgroundTransparency = 1,

									[Fusion.Children] = {
										scope:New("UIListLayout")({
											FillDirection = Enum.FillDirection.Horizontal,
											VerticalAlignment = Enum.VerticalAlignment.Center,
											HorizontalAlignment = Enum.HorizontalAlignment.Center,
											Padding = UDim.new(0, 5),
										}),

										scope:New("ImageLabel")({
											Name = "RobuxIcon",
											Size = UDim2.fromOffset(16, 16),
											BackgroundTransparency = 1,
											Image = ROBUX_ICON,
											ScaleType = Enum.ScaleType.Fit,
											Visible = isRobuxIconVisible,
										}),

										scope:New("TextLabel")({
											Name = "PriceLabel",
											Size = UDim2.fromOffset(0, 20),
											AutomaticSize = Enum.AutomaticSize.X,
											BackgroundTransparency = 1,
											Text = buttonLabelText,
											TextColor3 = Color3.fromRGB(255, 255, 255),
											TextSize = buttonLabelSize,
											Font = Theme.Text.Black,
											TextXAlignment = Enum.TextXAlignment.Center,
											TextYAlignment = Enum.TextYAlignment.Center,
										}),
									},
								}),
							},

							[Fusion.OnEvent("MouseEnter")] = function()
								isBuyHovered:set(true)
								isRowHovered:set(true)
							end,
							[Fusion.OnEvent("MouseLeave")] = function()
								isBuyHovered:set(false)
								isRowHovered:set(false)
							end,
							[Fusion.OnEvent("Activated")] = function()
								if Fusion.peek(statusVal) == "idle" then
									handlePurchase(product.ProductId)
								end
							end,
						}),
					},
				}),

				scope:New("TextButton")({
					Name = "RowHitbox",
					Size = UDim2.new(1, -108, 1, 0),
					Position = UDim2.fromScale(0, 0),
					BackgroundTransparency = 1,
					Text = "",

					[Fusion.OnEvent("MouseEnter")] = function()
						isRowHovered:set(true)
					end,
					[Fusion.OnEvent("MouseLeave")] = function()
						isRowHovered:set(false)
					end,
					[Fusion.OnEvent("Activated")] = function()
						handlePurchase(product.ProductId)
					end,
				}),
			},
		})

		table.insert(productRows, rowContainer)
	end

	local targetParent = props.Parent or getPlayerGui()

	return scope:New("ScreenGui")({
		Name = "BuyCreditsModalGui",
		AutoLocalize = false,
		DisplayOrder = 100020,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = targetParent,

		[Fusion.Children] = {
			scope:New("TextButton")({
				Name = "BackdropHitbox",
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0, 0),
				BackgroundColor3 = Theme.Modal.Overlay,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 1,
				[Fusion.OnEvent("Activated")] = props.OnClose,
			}),

			scope:New("Frame")({
				Name = "ModalContainer",
				Size = UDim2.fromOffset(400, math.max(350, modalHeight)),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = PANEL_BG,
				BackgroundTransparency = PANEL_BG_TRANSPARENCY,
				BorderSizePixel = 0,
				Active = true,
				ZIndex = 2,

				[Fusion.Children] = {
					Shadow(scope, {
						Size = UDim2.new(1, 28, 1, 28),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Spread = 14,
						Transparency = 0.55,
						ZIndex = 0,
					}),

					scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),

					scope:New("UIStroke")({
						Color = PANEL_BORDER,
						Thickness = 1,
						Transparency = PANEL_BORDER_TRANSPARENCY,
						BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					}),

					scope:New("ImageLabel")({
						Name = "Stripes",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = Theme.Patterns.DiagonalStripes.Fat,
						ImageColor3 = Theme.Section.Stripe.Color,
						ImageTransparency = 0.95,
						ScaleType = Enum.ScaleType.Tile,
						TileSize = UDim2.fromOffset(48, 48),
						ZIndex = 1,
					}),

					scope:New("TextButton")({
						Name = "CloseButton",
						Size = UDim2.fromOffset(36, 36),
						Position = UDim2.new(1, -6, 0, 6),
						AnchorPoint = Vector2.new(1, 0),
						BackgroundTransparency = 1,
						Text = "",
						AutoButtonColor = false,
						ZIndex = 5,

						[Fusion.Children] = {
							scope:New("TextLabel")({
								Name = "CloseIcon",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = "X",
								TextColor3 = scope:Computed(function(use: FusionUseFn)
									return if use(isCloseHovered) then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(140, 145, 160)
								end),
								TextSize = 15,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Center,
								TextYAlignment = Enum.TextYAlignment.Center,
							}),
						},

						[Fusion.OnEvent("MouseEnter")] = function()
							isCloseHovered:set(true)
						end,
						[Fusion.OnEvent("MouseLeave")] = function()
							isCloseHovered:set(false)
						end,
						[Fusion.OnEvent("Activated")] = props.OnClose,
					}),

					scope:New("Frame")({
						Name = "Content",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						ZIndex = 3,

						[Fusion.Children] = {
							scope:New("UIPadding")({
								PaddingLeft = UDim.new(0, 22),
								PaddingRight = UDim.new(0, 22),
								PaddingTop = UDim.new(0, 20),
								PaddingBottom = UDim.new(0, 20),
							}),

							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 16),
							}),

							scope:New("Frame")({
								Name = "Header",
								Size = UDim2.new(1, 0, 0, 42),
								BackgroundTransparency = 1,
								LayoutOrder = 1,

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										SortOrder = Enum.SortOrder.LayoutOrder,
										Padding = UDim.new(0, 3),
									}),

									scope:New("TextLabel")({
										Name = "Title",
										Size = UDim2.new(1, -36, 0, 22),
										BackgroundTransparency = 1,
										Text = "BUY CREDITS",
										TextColor3 = Theme.Colors.White,
										TextSize = 20,
										Font = Theme.Text.Black,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Center,
										LayoutOrder = 1,
									}),

									scope:New("TextLabel")({
										Name = "Subtitle",
										Size = UDim2.new(1, -36, 0, 16),
										BackgroundTransparency = 1,
										Text = "Top up your balance to unlock crates and cosmetics.",
										TextColor3 = Color3.fromRGB(185, 190, 205),
										TextSize = 12,
										Font = Theme.Text.Regular,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Center,
										LayoutOrder = 2,
									}),
								},
							}),

							scope:New("ScrollingFrame")({
								Name = "ProductList",
								Size = UDim2.new(1, 0, 0, productListHeight),
								CanvasSize = UDim2.fromOffset(0, productListFullHeight),
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
								ScrollBarThickness = if productListFullHeight > productListHeight then 4 else 0,
								ScrollingDirection = Enum.ScrollingDirection.Y,
								LayoutOrder = 2,

								[Fusion.Children] = productRows,
							}),
						},
					}),
				},
			}),
		},
	})
end

return BuyCreditsModal
