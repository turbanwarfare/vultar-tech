--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

local PriceCache = require(script.Parent.Parent.Cache.PriceCache)
local SkinModelCache = require(script.Parent.Parent.Cache.SkinModelCache)
local GunViewportFactory = require(MainModule.Client.Utils.GunViewportFactory)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionValue<T> = Types.FusionValue<T>

local TRANSPARENCY_NUM_SEQ = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.95), NumberSequenceKeypoint.new(0.75, 0.75), NumberSequenceKeypoint.new(1, 0.55), })

local CORNER_RADIUS = 8

local function createGunViewport(skinId: string): ViewportFrame?
	local model = SkinModelCache.getModel(skinId, "H-82")
	if not model then
		return nil
	end
	local viewport = GunViewportFactory.create(model, {
		fov = 40,
		distanceMultiplier = 0.88,
		rotation = CFrame.Angles(0, -math.pi / 2, 0)
			* CFrame.Angles(math.rad(18), 0, 0)
			* CFrame.Angles(0, 0, math.rad(-3)),
		ambient = Color3.fromRGB(120, 120, 130),
		lightDirection = Vector3.new(-0.3, -0.8, -0.4),
	})
	viewport.Name = "GunViewport"
	viewport.ZIndex = 1
	return viewport
end

export type SkinCardProps = {
	SkinId: string,
	SkinName: string,
	GamepassId: number,
	LayoutOrder: number,
	IsOwned: FusionValue<boolean>?,
	OnClick: () -> (),
}

local function SkinCard(scope: FusionScope, props: SkinCardProps): Frame
	local isHovered = scope:Value(false)
	local price = scope:Value(0)

	PriceCache.getPriceAsync(props.GamepassId, price)

	local cardScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 1.03 else 1
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local bgTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0.88 else 0.92
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local borderTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0.3 else 0.5
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local priceText = scope:Computed(function(use: FusionUseFn)
		local p = use(price)
		if p == -1 then
			return "OWNED"
		elseif p > 0 then
			return tostring(p) .. " R$"
		else
			return "..."
		end
	end)

	local priceColor = scope:Computed(function(use: FusionUseFn)
		local p = use(price)
		if p == -1 then
			return Color3.fromRGB(100, 200, 255)
		else
			return Color3.fromRGB(0, 200, 100)
		end
	end)

	return scope:New("Frame")({
		Name = props.SkinId,
		Size = UDim2.fromScale(1, 1),
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

					scope:New("CanvasGroup")({
						Name = "Card",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Color3.fromRGB(30, 32, 40),
						BackgroundTransparency = bgTransparency,
						BorderSizePixel = 0,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER_RADIUS) }),

							scope:New("UIStroke")({
								Color = Color3.fromRGB(100, 105, 120),
								Thickness = 1,
								Transparency = borderTransparency,
							}),

							createGunViewport(props.SkinId),

							scope:New("Frame")({
								Name = "BottomFade",
								Size = UDim2.new(1, 0, 0, 60),
								Position = UDim2.fromScale(0, 1),
								AnchorPoint = Vector2.new(0, 1),
								BackgroundColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								ZIndex = 4,

								[Fusion.Children] = {
									scope:New("UIGradient")({
										Rotation = 90,
										Transparency = TRANSPARENCY_NUM_SEQ,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "TextContainer",
								Size = UDim2.new(1, 0, 0, 48),
								Position = UDim2.fromScale(0, 1),
								AnchorPoint = Vector2.new(0, 1),
								BackgroundTransparency = 1,
								ZIndex = 5,

								[Fusion.Children] = {
									scope:New("TextLabel")({
										Name = "SkinName",
										Size = UDim2.new(1, -20, 0, 20),
										Position = UDim2.fromOffset(10, 6),
										BackgroundTransparency = 1,
										Text = string.upper(props.SkinName),
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextSize = 14,
										Font = Enum.Font.GothamBold,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Center,
										TextTruncate = Enum.TextTruncate.AtEnd,

										[Fusion.Children] = {
											scope:New("UIStroke")({
												Color = Color3.fromRGB(0, 0, 0),
												Thickness = 1.2,
												Transparency = 0.4,
											}),
										},
									}),

									scope:New("TextLabel")({
										Name = "Price",
										Size = UDim2.new(1, -20, 0, 18),
										Position = UDim2.fromOffset(10, 26),
										BackgroundTransparency = 1,
										Text = priceText,
										TextColor3 = priceColor,
										TextSize = 13,
										Font = Enum.Font.GothamBold,
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
								[Fusion.OnEvent("Activated")] = props.OnClick,
							}),
						},
					}),
				},
			}),
		},
	})
end

return SkinCard
