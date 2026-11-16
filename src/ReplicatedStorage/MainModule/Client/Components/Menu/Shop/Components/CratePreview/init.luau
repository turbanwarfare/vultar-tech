--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CratesConfig = require(MainModule.Shared.Config.Cosmetics.Crates)

local CrateModelCache = require(script.Parent.Parent.Cache.CrateModelCache)
local CrateViewportFactory = require(MainModule.Client.Utils.CrateViewportFactory)

local Constants = require(script.Constants)
local ChancesPanel = require(script.ChancesPanel)
local DropsPanel = require(script.DropsPanel)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type CrateConfig = CratesConfig.CrateConfig

local function createCrateViewport(scope: FusionScope, crate: CrateConfig, isAssetsLoaded: Types.FusionValue<boolean>): Instance?
	return scope:Computed(function(use: FusionUseFn)
		local loaded = use(isAssetsLoaded)
		if not loaded then
			return nil
		end
		local model = CrateModelCache.getModel(crate.modelName)
		if not model then
			return nil
		end

		local viewport = CrateViewportFactory.create(model, {
			fov = 35,
			paddingMultiplier = crate.paddingMultiplier or 1.15,
			yawAngleDeg = crate.yawAngleDeg or 150,
			pitchAngleDeg = crate.cameraElevationDeg or 14,
			ambient = Color3.fromRGB(120, 120, 130),
			lightDirection = Vector3.new(-0.318, -0.848, -0.424),
		})
		viewport.Name = "CrateViewport"
		viewport.Position = UDim2.fromScale(0.5, 0.42)
		viewport.AnchorPoint = Vector2.new(0.5, 0.5)
		viewport.Size = UDim2.new(1, 0, 1, -44)
		viewport.BackgroundTransparency = 1
		viewport.ZIndex = 1
		return viewport
	end)
end

export type CratePreviewProps = {
	Crate: CrateConfig,
	OnBack: () -> (),
	OnOpen: ((crate: CrateConfig, amount: number) -> ())?,
	OwnedItems: Types.FusionValue<{ [string]: boolean }>?,
}

local function CratePreview(scope: FusionScope, props: CratePreviewProps): Frame
	local crate = props.Crate
	local rarityColor = CratesConfig.getRarityColor(crate.rarity)

	local isAssetsLoaded = scope:Value(CrateModelCache.isLoaded())
	if not Fusion.peek(isAssetsLoaded) then
		local conn = CrateModelCache.onLoaded(function()
			isAssetsLoaded:set(true)
		end)
		table.insert(scope, function()
			conn.Disconnect()
		end)
	end

	local camera = workspace.CurrentCamera
	local viewportWidth = scope:Value(if camera then camera.ViewportSize.X else 1920)
	local viewportHeight = scope:Value(if camera then camera.ViewportSize.Y else 1080)

	if camera then
		local conn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			viewportWidth:set(camera.ViewportSize.X)
			viewportHeight:set(camera.ViewportSize.Y)
		end)
		table.insert(scope, function()
			conn:Disconnect()
		end)
	end

	local leftColumnWidth = scope:Computed(function(use: FusionUseFn)
		local w = use(viewportWidth)
		local calculated = math.floor(w * 0.24)
		return math.clamp(calculated, 330, 440)
	end)

	local columnGap = Constants.COLUMN_GAP

	local quantityIndex = scope:Value(1)
	local isAmountHovered = scope:Value(false)
	local isOpenHovered = scope:Value(false)
	local isBackHovered = scope:Value(false)

	local openAmount = scope:Computed(function(use: FusionUseFn)
		local idx = use(quantityIndex)
		return CratesConfig.QUANTITY_OPTIONS[idx] or 1
	end)

	local function cycleAmount()
		local current = Fusion.peek(quantityIndex)
		local nextIdx = (current % #CratesConfig.QUANTITY_OPTIONS) + 1
		quantityIndex:set(nextIdx)
	end

	local openTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isOpenHovered) then 0 else 0.1
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local openStrokeTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isOpenHovered) then 0.15 else 0.4
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local backTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isBackHovered) then 0.25 else 0.5
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local amountText = scope:Computed(function(use: FusionUseFn)
		return "x" .. tostring(use(openAmount))
	end)

	local totalPriceText = scope:Computed(function(use: FusionUseFn)
		return tostring(crate.price * use(openAmount))
	end)

	local function requestOpen()
		if not Fusion.peek(isAssetsLoaded) then
			return
		end
		if props.OnOpen then
			props.OnOpen(crate, Fusion.peek(openAmount))
		end
	end

	return scope:New("Frame")({
		Name = "CratePreview",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "LeftColumn",
				Size = scope:Computed(function(use: FusionUseFn)
					local lw = use(leftColumnWidth)
					return UDim2.new(0, lw, 1, 0)
				end),
				Position = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "CratePanel",
						Size = UDim2.new(1, 0, 1, -128),
						Position = UDim2.fromOffset(0, 0),
						BackgroundColor3 = Constants.PANEL_BG,
						BackgroundTransparency = Constants.PANEL_BG_TRANSPARENCY,
						BorderSizePixel = 0,
						ClipsDescendants = true,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),

							scope:New("UIGradient")({
								Color = Constants.PANEL_GRADIENT,
								Rotation = 90,
							}),

							scope:New("UIStroke")({
								Color = Constants.PANEL_BORDER,
								Thickness = 1,
								Transparency = Theme.Stroke.Strong,
							}),

							scope:New("ImageLabel")({
								Name = "Stripes",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Image = Theme.Patterns.DiagonalStripes.Fat,
								ImageColor3 = Theme.Section.Stripe.Color,
								ImageTransparency = Theme.Section.Stripe.Transparency,
								ScaleType = Enum.ScaleType.Tile,
								TileSize = UDim2.fromOffset(Theme.Section.Stripe.TileSize, Theme.Section.Stripe.TileSize),
							}),

							createCrateViewport(scope, crate, isAssetsLoaded),

							scope:New("Frame")({
								Name = "BackButton",
								Size = UDim2.fromOffset(78, 26),
								Position = UDim2.fromOffset(12, 12),
								BackgroundColor3 = Constants.PANEL_BG,
								BackgroundTransparency = backTransparency,
								BorderSizePixel = 0,
								ZIndex = 5,

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),

									scope:New("UIStroke")({
										Color = Constants.PANEL_BORDER,
										Thickness = 1,
										Transparency = Theme.Stroke.Strong,
									}),

									scope:New("TextButton")({
										Name = "Hitbox",
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = "< BACK",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextSize = Theme.Text.Medium,
										Font = Theme.Text.Bold,
										ZIndex = 6,

										[Fusion.OnEvent("MouseEnter")] = function()
											isBackHovered:set(true)
										end,
										[Fusion.OnEvent("MouseLeave")] = function()
											isBackHovered:set(false)
										end,
										[Fusion.OnEvent("Activated")] = props.OnBack,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "CrateHeader",
								Size = UDim2.new(1, -24, 0, 56),
								Position = UDim2.new(0.5, 0, 1, -12),
								AnchorPoint = Vector2.new(0.5, 1),
								BackgroundTransparency = 1,
								ZIndex = 3,

								[Fusion.Children] = {
									scope:New("TextLabel")({
										Name = "Title",
										Size = UDim2.new(1, 0, 0, 26),
										Position = UDim2.fromOffset(0, 0),
										BackgroundTransparency = 1,
										Text = string.upper(crate.name),
										TextColor3 = Constants.TITLE_TEXT,
										TextSize = Theme.Text.Title - 4,
										Font = Theme.Text.Black,
										TextXAlignment = Enum.TextXAlignment.Center,
										TextYAlignment = Enum.TextYAlignment.Center,
									}),

									scope:New("Frame")({
										Name = "Rarity",
										Size = UDim2.fromOffset(130, 20),
										Position = UDim2.new(0.5, 0, 0, 32),
										AnchorPoint = Vector2.new(0.5, 0),
										BackgroundColor3 = rarityColor,
										BackgroundTransparency = 0.88,
										BorderSizePixel = 0,
										ClipsDescendants = true,

										[Fusion.Children] = {
											scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),

											scope:New("UIStroke")({
												Color = rarityColor,
												Thickness = 1,
												Transparency = 0.4,
											}),

											scope:New("TextLabel")({
												Name = "Label",
												Size = UDim2.fromScale(1, 1),
												BackgroundTransparency = 1,
												Text = string.format("%s CRATE", CratesConfig.RarityLabels[crate.rarity] or crate.rarity),
												TextColor3 = rarityColor,
												TextSize = Theme.Text.Small,
												Font = Theme.Text.Bold,
												TextXAlignment = Enum.TextXAlignment.Center,
												TextYAlignment = Enum.TextYAlignment.Center,
											}),
										},
									}),
								},
							}),
						},
					}),

					scope:New("Frame")({
						Name = "BottomControls",
						Size = UDim2.new(1, 0, 0, 116),
						Position = UDim2.fromScale(0, 1),
						AnchorPoint = Vector2.new(0, 1),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 6),
							}),

							scope:New("Frame")({
								Name = "PriceRow",
								Size = UDim2.new(1, 0, 0, Constants.PRICE_ROW_HEIGHT),
								BackgroundColor3 = Constants.PANEL_BG,
								BackgroundTransparency = Constants.PANEL_BG_TRANSPARENCY,
								BorderSizePixel = 0,
								LayoutOrder = 1,

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),

									scope:New("UIStroke")({
										Color = Constants.PANEL_BORDER,
										Thickness = 1,
										Transparency = Theme.Stroke.Strong,
									}),

									scope:New("UIPadding")({
										PaddingLeft = UDim.new(0, 14),
										PaddingRight = UDim.new(0, 14),
									}),

									scope:New("TextLabel")({
										Name = "Label",
										Size = UDim2.fromScale(0.4, 1),
										Position = UDim2.fromScale(0, 0.5),
										AnchorPoint = Vector2.new(0, 0.5),
										BackgroundTransparency = 1,
										Text = "PRICE",
										TextColor3 = Color3.fromRGB(188, 188, 188),
										TextSize = Theme.Text.Medium,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),

									scope:New("TextLabel")({
										Name = "Currency",
										Size = UDim2.fromOffset(24, 16),
										Position = UDim2.fromScale(1, 0.5),
										AnchorPoint = Vector2.new(1, 0.5),
										BackgroundTransparency = 1,
										Text = "CR",
										TextColor3 = Constants.MUTED_TEXT,
										TextSize = Theme.Text.Small,
										Font = Theme.Text.Black,
										TextXAlignment = Enum.TextXAlignment.Right,
									}),

									scope:New("TextLabel")({
										Name = "Amount",
										Size = UDim2.new(0.5, -28, 1, 0),
										Position = UDim2.new(1, -26, 0.5, 0),
										AnchorPoint = Vector2.new(1, 0.5),
										BackgroundTransparency = 1,
										Text = totalPriceText,
										TextColor3 = Constants.PRICE_COLOR,
										TextSize = Theme.Text.Title - 4,
										Font = Theme.Text.Black,
										TextXAlignment = Enum.TextXAlignment.Right,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "ActionRow",
								Size = UDim2.new(1, 0, 0, Constants.OPEN_BUTTON_HEIGHT),
								BackgroundTransparency = 1,
								LayoutOrder = 2,

								[Fusion.Children] = {
									scope:New("TextButton")({
										Name = "OpenButton",
										Size = UDim2.new(1, -(Constants.AMOUNT_BOX_WIDTH + 8), 1, 0),
										Position = UDim2.fromScale(0, 0),
										BackgroundColor3 = Color3.new(1, 1, 1),
										BackgroundTransparency = openTransparency,
										Text = "",
										AutoButtonColor = false,

										[Fusion.Children] = {
											scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),

											scope:New("UIStroke")({
												Color = Constants.OPEN_BUTTON_STROKE,
												Thickness = 1.5,
												Transparency = openStrokeTransparency,
											}),

											scope:New("UIGradient")({
												Color = Constants.OPEN_GRADIENT,
												Rotation = 270,
											}),

											scope:New("TextLabel")({
												Name = "Label",
												Size = UDim2.fromScale(1, 1),
												BackgroundTransparency = 1,
												Text = scope:Computed(function(use: FusionUseFn)
													return if use(isAssetsLoaded) then "OPEN CRATE" else "LOADING ASSETS..."
												end),
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextSize = Theme.Text.Large,
												Font = Theme.Text.Black,
											}),
										},

										[Fusion.OnEvent("MouseEnter")] = function()
											isOpenHovered:set(true)
										end,
										[Fusion.OnEvent("MouseLeave")] = function()
											isOpenHovered:set(false)
										end,
										[Fusion.OnEvent("Activated")] = requestOpen,
									}),

									scope:New("Frame")({
										Name = "AmountBox",
										Size = UDim2.fromOffset(Constants.AMOUNT_BOX_WIDTH, Constants.OPEN_BUTTON_HEIGHT),
										Position = UDim2.fromScale(1, 0),
										AnchorPoint = Vector2.new(1, 0),
										BackgroundColor3 = Constants.PANEL_BG,
										BackgroundTransparency = Constants.PANEL_BG_TRANSPARENCY,
										BorderSizePixel = 0,

										[Fusion.Children] = {
											scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),

											scope:New("UIStroke")({
												Color = scope:Computed(function(use: FusionUseFn)
													return if use(isAmountHovered) then Color3.fromRGB(255, 255, 255) else Constants.PANEL_BORDER
												end),
												Thickness = 1,
												Transparency = scope:Computed(function(use: FusionUseFn)
													return if use(isAmountHovered) then 0.1 else Theme.Stroke.Strong
												end),
											}),

											scope:New("TextButton")({
												Name = "CycleButton",
												Size = UDim2.fromScale(1, 1),
												BackgroundTransparency = 1,
												Text = amountText,
												TextColor3 = scope:Computed(function(use: FusionUseFn)
													return if use(isAmountHovered) then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(220, 220, 230)
												end),
												TextSize = Theme.Text.Large,
												Font = Theme.Text.Bold,
												AutoButtonColor = false,

												[Fusion.OnEvent("MouseEnter")] = function()
													isAmountHovered:set(true)
												end,
												[Fusion.OnEvent("MouseLeave")] = function()
													isAmountHovered:set(false)
												end,
												[Fusion.OnEvent("Activated")] = cycleAmount,
											}),
										},
									}),
								},
							}),

							scope:New("TextLabel")({
								Name = "Disclaimer",
								Size = UDim2.new(1, 0, 0, 14),
								BackgroundTransparency = 1,
								Text = "ITEMS ARE ADDED STRAIGHT TO YOUR INVENTORY",
								TextColor3 = Constants.SUBTLE_TEXT,
								TextSize = 10,
								Font = Theme.Text.Semibold,
								TextXAlignment = Enum.TextXAlignment.Center,
								TextYAlignment = Enum.TextYAlignment.Center,
								LayoutOrder = 3,
							}),
						},
					}),
				},
			}),

			scope:New("ScrollingFrame")({
				Name = "RightColumn",
				Size = scope:Computed(function(use: FusionUseFn)
					local lw = use(leftColumnWidth)
					return UDim2.new(1, -(lw + columnGap), 1, 0)
				end),
				Position = scope:Computed(function(use: FusionUseFn)
					local lw = use(leftColumnWidth)
					return UDim2.fromOffset(lw + columnGap, 0)
				end),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = Theme.Scrollbar.Thumb,
				ScrollBarImageTransparency = 0.4,
				ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,

				[Fusion.Children] = {
					scope:New("UIPadding")({
						PaddingRight = UDim.new(0, 8),
						PaddingBottom = UDim.new(0, 24),
						PaddingTop = UDim.new(0, 6),
						PaddingLeft = UDim.new(0, 8),
					}),

					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 16),
					}),

					ChancesPanel(scope, {
						Crate = crate,
						LayoutOrder = 1,
					}),

					DropsPanel(scope, {
						Crate = crate,
						LayoutOrder = 2,
						OwnedItems = props.OwnedItems,
					}),
				},
			}),
		},
	})
end

return CratePreview
