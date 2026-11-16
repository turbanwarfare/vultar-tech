--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

local PriceCache = require(script.Parent.Parent.Cache.PriceCache)
local PurchaseRedirectController = require(script.Parent.Parent.PurchaseRedirectController)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionCanBeState<T> = Types.FusionCanBeState<T>

local TRANSPARENCY_NUM_SEQ_3 = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 1) })
local TRANSPARENCY_NUM_SEQ_2 = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 0) })
local TRANSPARENCY_NUM_SEQ = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 0.15) })

local GLOW_ASSET = "rbxassetid://1316045217"
local GLOW_SLICE = Rect.new(32, 32, 96, 96)

local GLOW_BLUE = Color3.fromRGB(60, 140, 180)
local GLOW_ORANGE = Color3.fromRGB(220, 140, 60)

export type ContentPanelProps = {
	Size: FusionCanBeState<UDim2>,
	Position: FusionCanBeState<UDim2>,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Title: string,
	GamepassId: number,
	Children: { Instance }?,
	OnClick: (() -> ())?,
	Disabled: boolean?,
}

local function ContentPanel(scope: FusionScope, props: ContentPanelProps): Frame
	local isHovered = scope:Value(false)
	local price: Types.FusionValue<number?> = scope:Value(nil)

	PriceCache.getPriceAsync(props.GamepassId, price :: any)

	local glowOpacity = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0.65 else 0.82
		end),
		30,
		1
	)

	local borderOpacity = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0.25 else 0.45
		end),
		30,
		1
	)

	local function handleClick()
		if props.Disabled then
			return
		end
		if props.OnClick then
			props.OnClick()
		else
			PurchaseRedirectController.promptPurchase(props.GamepassId)
		end
	end

	return scope:New("Frame")({
		Name = "ContentPanelWrapper",
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "ContentPanel",
				Size = UDim2.fromScale(1, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("ImageLabel")({
						Name = "GlowBlue",
						Size = UDim2.new(1, 20, 1, 20),
						Position = UDim2.fromOffset(-10, -10),
						BackgroundTransparency = 1,
						Image = GLOW_ASSET,
						ImageColor3 = GLOW_BLUE,
						ImageTransparency = glowOpacity,
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = GLOW_SLICE,
						ZIndex = 0,

						[Fusion.Children] = {
							scope:New("UIGradient")({
								Rotation = 135,
								Transparency = TRANSPARENCY_NUM_SEQ_3,
							}),
						},
					}),

					scope:New("ImageLabel")({
						Name = "GlowOrange",
						Size = UDim2.new(1, 20, 1, 20),
						Position = UDim2.fromOffset(-10, -10),
						BackgroundTransparency = 1,
						Image = GLOW_ASSET,
						ImageColor3 = GLOW_ORANGE,
						ImageTransparency = glowOpacity,
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = GLOW_SLICE,
						ZIndex = 0,

						[Fusion.Children] = {
							scope:New("UIGradient")({
								Rotation = 135,
								Transparency = TRANSPARENCY_NUM_SEQ_2,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "PanelBody",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Color3.fromRGB(15, 18, 25),
						BackgroundTransparency = 0.92,
						ClipsDescendants = true,
						ZIndex = 1,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),

							scope:New("UIStroke")({
								Color = Theme.Border.Silver,
								Thickness = 1,
								Transparency = borderOpacity,
							}),

							scope:New("Frame")({
								Name = "Content",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								ZIndex = 1,

								[Fusion.Children] = props.Children,
							}),

							scope:New("Frame")({
								Name = "BottomGradient",
								Size = UDim2.new(1, 0, 0, 140),
								Position = UDim2.fromScale(0, 1),
								AnchorPoint = Vector2.new(0, 1),
								BackgroundColor3 = Color3.new(0, 0, 0),
								BackgroundTransparency = 0.3,
								ZIndex = 2,

								[Fusion.Children] = {
									scope:New("UIGradient")({
										Rotation = 90,
										Transparency = TRANSPARENCY_NUM_SEQ,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "TextContainer",
								Size = UDim2.new(1, 0, 0, 120),
								Position = UDim2.fromScale(0, 1),
								AnchorPoint = Vector2.new(0, 1),
								BackgroundTransparency = 1,
								ZIndex = 3,

								[Fusion.Children] = {
									scope:New("UIPadding")({
										PaddingLeft = UDim.new(0, 24),
										PaddingRight = UDim.new(0, 24),
										PaddingBottom = UDim.new(0, 20),
									}),

									scope:New("TextLabel")({
										Name = "Title",
										Size = UDim2.new(1, 0, 0, 44),
										Position = UDim2.new(0, 0, 1, -42),
										AnchorPoint = Vector2.new(0, 1),
										BackgroundTransparency = 1,
										Text = props.Title,
										TextColor3 = Theme.Colors.White,
										TextSize = 36,
										Font = Enum.Font.GothamBlack,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Center,
									}),

									scope:New("TextLabel")({
										Name = "PriceText",
										Size = UDim2.new(1, 0, 0, 36),
										Position = UDim2.fromScale(0, 1),
										AnchorPoint = Vector2.new(0, 1),
										BackgroundTransparency = 1,
										Text = scope:Computed(function(use: FusionUseFn)
											local p = use(price)
											return if p then tostring(p) .. "R$" else "..."
										end),
										TextColor3 = Color3.fromRGB(200, 255, 200),
										TextSize = 28,
										Font = Enum.Font.GothamBlack,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Center,
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
								[Fusion.OnEvent("Activated")] = handleClick,
							}),

							if props.Disabled
								then scope:New("Frame")({
									Name = "DisabledOverlay",
									Size = UDim2.fromScale(1, 1),
									BackgroundColor3 = Color3.fromRGB(30, 30, 35),
									BackgroundTransparency = 0.3,
									ZIndex = 15,

									[Fusion.Children] = {
										scope:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),

										scope:New("TextLabel")({
											Name = "DisabledText",
											Size = UDim2.fromScale(1, 1),
											BackgroundTransparency = 1,
											Text = "Disabled during testing",
											TextColor3 = Color3.fromRGB(180, 180, 185),
											TextSize = 20,
											Font = Enum.Font.GothamBold,
											TextXAlignment = Enum.TextXAlignment.Center,
											TextYAlignment = Enum.TextYAlignment.Center,
										}),
									},
								})
								else nil,
						},
					}),
				},
			}),
		},
	})
end

return ContentPanel
