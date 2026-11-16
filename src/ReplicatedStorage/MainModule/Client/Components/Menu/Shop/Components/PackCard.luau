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

local TRANSPARENCY_NUM_SEQ = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 0.85), })

local CORNER_RADIUS = 12

local function createGunViewport(scope: FusionScope, skinId: string): ViewportFrame
	local model = SkinModelCache.getModel(skinId, "H-82")
	if not model then
		return scope:New("ViewportFrame")({
			Name = "GunViewport",
			Size = UDim2.fromScale(1, 0.42),
			Position = UDim2.fromScale(0, 0.32),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 3,
		})
	end

	local viewport = GunViewportFactory.create(model, {
		fov = 40,
		distanceMultiplier = 0.85,
		rotation = CFrame.Angles(0, -math.pi / 2, 0) * CFrame.Angles(math.rad(25), 0, math.rad(-8)),
		ambient = Color3.fromRGB(140, 140, 150),
		lightDirection = Vector3.new(-0.3, -0.8, -0.4),
	})
	viewport.Size = UDim2.fromScale(1, 0.42)
	viewport.Position = UDim2.fromScale(0, 0.32)
	viewport.ZIndex = 3
	return viewport
end

export type PackCardProps = {
	PackId: string,
	PackName: string,
	SkinId: string,
	ImageId: string,
	GamepassId: number,
	LayoutOrder: number,
	OnClick: () -> (),
}

local function PackCard(scope: FusionScope, props: PackCardProps): Frame
	local isHovered = scope:Value(false)
	local price = scope:Value(0)

	PriceCache.getPriceAsync(props.GamepassId, price)

	local cardScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 1.02 else 1
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local bgTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0.88 else 0.95
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local borderTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0.3 else 0.6
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	return scope:New("Frame")({
		Name = props.PackId,
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

					scope:New("Frame")({
						Name = "CardBody",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Color3.fromRGB(25, 28, 35),
						BackgroundTransparency = bgTransparency,
						ClipsDescendants = true,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER_RADIUS) }),

							scope:New("UIStroke")({
								Color = Color3.fromRGB(100, 105, 120),
								Thickness = 1,
								Transparency = borderTransparency,
							}),

							scope:New("ImageLabel")({
								Name = "PlayerCardBanner",
								Size = UDim2.fromScale(1, 0.5),
								Position = UDim2.fromOffset(0, 0),
								BackgroundTransparency = 1,
								Image = props.ImageId,
								ScaleType = Enum.ScaleType.Crop,
								ZIndex = 1,

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER_RADIUS) }),
									scope:New("UIGradient")({
										Rotation = 90,
										Transparency = TRANSPARENCY_NUM_SEQ,
									}),
								},
							}),

							createGunViewport(scope, props.SkinId),

							scope:New("Frame")({
								Name = "TextContainer",
								Size = UDim2.new(1, 0, 0, 85),
								Position = UDim2.fromScale(0, 1),
								AnchorPoint = Vector2.new(0, 1),
								BackgroundTransparency = 1,
								ZIndex = 5,

								[Fusion.Children] = {
									scope:New("TextLabel")({
										Name = "PackName",
										Size = UDim2.new(1, -28, 0, 32),
										Position = UDim2.fromOffset(14, 10),
										BackgroundTransparency = 1,
										Text = string.upper(props.PackName),
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextSize = 22,
										Font = Enum.Font.GothamBlack,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextTruncate = Enum.TextTruncate.AtEnd,

										[Fusion.Children] = {
											scope:New("UIStroke")({
												Color = Color3.fromRGB(25, 25, 30),
												Thickness = 1.5,
											}),
										},
									}),

									scope:New("TextLabel")({
										Name = "Price",
										Size = UDim2.new(1, -28, 0, 26),
										Position = UDim2.fromOffset(14, 46),
										BackgroundTransparency = 1,
										Text = scope:Computed(function(use: FusionUseFn)
											local p = use(price)
											return if p > 0 then tostring(p) .. "R$" else "..."
										end),
										TextColor3 = Color3.fromRGB(0, 200, 100),
										TextSize = 19,
										Font = Enum.Font.GothamBlack,
										TextXAlignment = Enum.TextXAlignment.Left,

										[Fusion.Children] = {
											scope:New("UIStroke")({
												Color = Color3.fromRGB(25, 25, 30),
												Thickness = 1.5,
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

return PackCard
