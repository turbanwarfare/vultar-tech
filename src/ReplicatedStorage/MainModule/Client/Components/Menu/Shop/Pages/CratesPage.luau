--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

local CratesConfig = require(MainModule.Shared.Config.Cosmetics.Crates)
local CrateModelCache = require(script.Parent.Parent.Cache.CrateModelCache)
local CrateCard = require(script.Parent.Parent.Components.CrateCard)
local CrateInfoModal = require(script.Parent.Parent.Components.CrateInfoModal)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type CrateConfig = CratesConfig.CrateConfig
type CrateRarity = CratesConfig.CrateRarity

local CARD_GAP = 20
local TITLE_SECTION_HEIGHT = 50

export type CratesPageProps = {
	Padding: Types.FusionValue<number>,
	OnCrateClick: ((crate: CrateConfig) -> ())?,
}

local CratesPage = {}

function CratesPage.create(scope: FusionScope, props: CratesPageProps): Frame
	local allCrates = CratesConfig.getAllCrates()
	local activeModalCrate = scope:Value(nil :: CrateConfig?)

	local isAssetsLoaded = scope:Value(CrateModelCache.isLoaded())
	local hasTimedOut = scope:Value(false)

	if not Fusion.peek(isAssetsLoaded) then
		local loadConn = CrateModelCache.onLoaded(function()
			isAssetsLoaded:set(true)
		end)
		table.insert(scope, function()
			loadConn.Disconnect()
		end)

		task.delay(10, function()
			if not Fusion.peek(isAssetsLoaded) then
				hasTimedOut:set(true)
			end
		end)
	end

	local orderedCrates: { CrateConfig } = {}
	local targetOrder: { CrateRarity } = { "Common", "Uncommon", "Rare", "Legendary", "Mythic" }

	for _, rarity in targetOrder do
		for _, crate in allCrates do
			if crate.rarity == rarity then
				table.insert(orderedCrates, crate)
			end
		end
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

	local cardWidth = scope:Computed(function(use: FusionUseFn)
		local w = use(viewportWidth)
		local pad = use(props.Padding) * 2
		local availableW = math.max(600, w - pad - 60)
		local numCards = math.max(1, #orderedCrates)
		local totalGaps = (numCards - 1) * CARD_GAP
		local calculated = (availableW - totalGaps) // numCards
		return math.clamp(calculated, 260, 420)
	end)

	local cardListChildren: { Instance } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, CARD_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, crate in orderedCrates do
		local card = scope:New("Frame")({
			Name = "CardSlot_" .. crate.id,
			Size = scope:Computed(function(use: FusionUseFn)
				local cw = use(cardWidth)
				return UDim2.new(0, cw, 1, 0)
			end),
			BackgroundTransparency = 1,
			LayoutOrder = index,

			[Fusion.Children] = {
				CrateCard(scope, {
					Crate = crate,
					LayoutOrder = index,
					OnClick = function()
						if props.OnCrateClick then
							props.OnCrateClick(crate)
						end
					end,
					OnInfoClick = function()
						activeModalCrate:set(crate)
					end,
				}),
			},
		})

		table.insert(cardListChildren, card)
	end

	return scope:New("Frame")({
		Name = "CratesPageRoot",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:Computed(function(use: FusionUseFn, modalScope: FusionScope)
				local activeCrate = use(activeModalCrate)
				if activeCrate then
					return CrateInfoModal(modalScope, {
						Crate = activeCrate,
						OnClose = function()
							activeModalCrate:set(nil)
						end,
					})
				end
				return nil
			end),

			scope:New("ScrollingFrame")({
				Name = "CratesScrollingFrame",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Theme.Scrollbar.Thumb,
				ScrollBarImageTransparency = 0.5,
				CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.X,
				ScrollingDirection = Enum.ScrollingDirection.X,
				BorderSizePixel = 0,
				ZIndex = 1,

				[Fusion.Children] = {
					scope:New("UIPadding")({
						PaddingLeft = scope:Computed(function(use: FusionUseFn)
							return UDim.new(0, use(props.Padding))
						end),
						PaddingRight = scope:Computed(function(use: FusionUseFn)
							return UDim.new(0, use(props.Padding))
						end),
						PaddingTop = UDim.new(0, 8),
						PaddingBottom = UDim.new(0, 16),
					}),

					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 10),
						FillDirection = Enum.FillDirection.Vertical,
					}),

					scope:New("Frame")({
						Name = "TitleHeader",
						Size = UDim2.new(1, 0, 0, TITLE_SECTION_HEIGHT),
						BackgroundTransparency = 1,
						LayoutOrder = 0,

						[Fusion.Children] = {
							scope:New("TextLabel")({
								Name = "Title",
								Size = UDim2.new(1, 0, 0, 26),
								Position = UDim2.fromOffset(0, 2),
								BackgroundTransparency = 1,
								Text = "COSMETIC CRATES",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 24,
								Font = Theme.Text.Black,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Center,

								[Fusion.Children] = {
									scope:New("UIStroke")({
										Color = Color3.fromRGB(0, 0, 0),
										Thickness = 1.2,
										Transparency = 0.4,
									}),
								},
							}),

							scope:New("TextLabel")({
								Name = "Subtitle",
								Size = UDim2.new(1, 0, 0, 18),
								Position = UDim2.fromOffset(0, 28),
								BackgroundTransparency = 1,
								Text = "",
								TextColor3 = Color3.fromRGB(160, 165, 180),
								TextSize = 12,
								Font = Theme.Text.Semibold,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Center,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "CardsStage",
						Size = scope:Computed(function(use: FusionUseFn)
							local vh = use(viewportHeight)
							local availableHeight = math.clamp(vh - 315, 260, 500)
							return UDim2.fromOffset(0, availableHeight)
						end),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						LayoutOrder = 1,

						[Fusion.Children] = {
							scope:Computed(function(use: FusionUseFn)
								local loaded = use(isAssetsLoaded)
								local timedOut = use(hasTimedOut)

								if not loaded and not timedOut then
									return scope:New("Frame")({
										Name = "LoadingState",
										Size = UDim2.fromOffset(400, 180),
										BackgroundTransparency = 1,

										[Fusion.Children] = {
											scope:New("UIListLayout")({
												FillDirection = Enum.FillDirection.Vertical,
												HorizontalAlignment = Enum.HorizontalAlignment.Left,
												VerticalAlignment = Enum.VerticalAlignment.Center,
												Padding = UDim.new(0, 8),
											}),

											scope:New("TextLabel")({
												Name = "LoadingTitle",
												Size = UDim2.new(1, 0, 0, 22),
												BackgroundTransparency = 1,
												Text = "LOADING CRATE ASSETS...",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextSize = 16,
												Font = Theme.Text.Black,
												TextXAlignment = Enum.TextXAlignment.Left,
												TextYAlignment = Enum.TextYAlignment.Center,
											}),

											scope:New("TextLabel")({
												Name = "LoadingSubtitle",
												Size = UDim2.new(1, 0, 0, 16),
												BackgroundTransparency = 1,
												Text = "Synchronizing 3D armory models with server...",
												TextColor3 = Color3.fromRGB(150, 155, 170),
												TextSize = 12,
												Font = Theme.Text.Semibold,
												TextXAlignment = Enum.TextXAlignment.Left,
												TextYAlignment = Enum.TextYAlignment.Center,
											}),
										},
									})
								elseif not loaded and timedOut then
									return scope:New("Frame")({
										Name = "ErrorState",
										Size = UDim2.fromOffset(400, 180),
										BackgroundTransparency = 1,

										[Fusion.Children] = {
											scope:New("UIListLayout")({
												FillDirection = Enum.FillDirection.Vertical,
												HorizontalAlignment = Enum.HorizontalAlignment.Left,
												VerticalAlignment = Enum.VerticalAlignment.Center,
												Padding = UDim.new(0, 8),
											}),

											scope:New("TextLabel")({
												Name = "ErrorTitle",
												Size = UDim2.new(1, 0, 0, 22),
												BackgroundTransparency = 1,
												Text = "CRATE ASSETS UNAVAILABLE",
												TextColor3 = Color3.fromRGB(255, 90, 90),
												TextSize = 16,
												Font = Theme.Text.Black,
												TextXAlignment = Enum.TextXAlignment.Left,
												TextYAlignment = Enum.TextYAlignment.Center,
											}),

											scope:New("TextLabel")({
												Name = "ErrorSubtitle",
												Size = UDim2.new(1, 0, 0, 16),
												BackgroundTransparency = 1,
												Text = "ModelsService failed to replicate 3D models. Please rejoin.",
												TextColor3 = Color3.fromRGB(170, 170, 180),
												TextSize = 12,
												Font = Theme.Text.Semibold,
												TextXAlignment = Enum.TextXAlignment.Left,
												TextYAlignment = Enum.TextYAlignment.Center,
											}),
										},
									})
								else
									return scope:New("Frame")({
										Name = "CardsListContainer",
										Size = UDim2.fromScale(1, 1),
										AutomaticSize = Enum.AutomaticSize.X,
										BackgroundTransparency = 1,

										[Fusion.Children] = cardListChildren,
									})
								end
							end),
						},
					}),
				},
			}),
		},
	})
end

return CratesPage
