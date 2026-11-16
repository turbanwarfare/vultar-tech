--!native
--!optimize 2

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local AnimatedCardService = require(MainModule.Client.Services.AnimatedCardService)

local SkinModelCache = require(script.Parent.Parent.Cache.SkinModelCache)
local GunViewportFactory = require(MainModule.Client.Utils.GunViewportFactory)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

local INFERNO_GRADIENT = {
	Color3.fromRGB(255, 60, 20),
	Color3.fromRGB(255, 140, 40),
	Color3.fromRGB(255, 200, 80),
	Color3.fromRGB(255, 140, 40),
	Color3.fromRGB(255, 60, 20),
	Color3.fromRGB(180, 30, 10),
	Color3.fromRGB(255, 60, 20),
}

local FALLBACK_COLOR_SEQUENCE = ColorSequence.new(Color3.new(1, 1, 1))

local function convertGradientColors(colors: { Color3 }): ColorSequence
	local colorCount = #colors
	if colorCount < 2 then
		return FALLBACK_COLOR_SEQUENCE
	end

	local keypoints: { ColorSequenceKeypoint } = {}
	if colorCount == 7 then
		keypoints = {
			ColorSequenceKeypoint.new(0, colors[1]),
			ColorSequenceKeypoint.new(0.18, colors[2]),
			ColorSequenceKeypoint.new(0.35, colors[3]),
			ColorSequenceKeypoint.new(0.50, colors[4]),
			ColorSequenceKeypoint.new(0.65, colors[5]),
			ColorSequenceKeypoint.new(0.82, colors[6]),
			ColorSequenceKeypoint.new(1, colors[7]),
		}
	else
		for i, color in ipairs(colors) do
			local position = (i - 1) / (colorCount - 1)
			table.insert(keypoints, ColorSequenceKeypoint.new(position, color))
		end
	end

	return ColorSequence.new(keypoints)
end

local function createAnimatedBanner(scope: FusionScope, imageId: string): CanvasGroup
	local container = scope:New("CanvasGroup")({
		Name = "AnimatedCardContainer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 0.15,
		ClipsDescendants = true,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),

			scope:New("Frame")({
				Name = "ScrollingFrame",
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(2, 1),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("ImageLabel")({
						Name = "CardImage1",
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(0.5, 1),
						BackgroundTransparency = 1,
						Image = imageId,
						ScaleType = Enum.ScaleType.Crop,
						ZIndex = 1,
					}),
					scope:New("ImageLabel")({
						Name = "CardImage2",
						Position = UDim2.fromScale(0.5, 0),
						Size = UDim2.fromScale(0.5, 1),
						BackgroundTransparency = 1,
						Image = imageId,
						ScaleType = Enum.ScaleType.Crop,
						ZIndex = 1,
					}),
				},
			}),
		},
	})

	task.defer(function()
		local animContainer = container :: Frame
		if animContainer and animContainer.Parent then
			AnimatedCardService:RegisterContainer(animContainer)
		end
	end)

	table.insert(scope, function()
		AnimatedCardService:UnregisterContainer(container :: Frame)
	end)

	return container
end

local function createStaticBanner(scope: FusionScope, imageId: string): CanvasGroup
	return scope:New("CanvasGroup")({
		Name = "StaticCardContainer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 0.15,
		ClipsDescendants = true,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			scope:New("ImageLabel")({
				Name = "CardImage",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = imageId,
				ScaleType = Enum.ScaleType.Crop,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
				},
			}),
		},
	})
end

local function createGunViewport(skinId: string, gunName: string): ViewportFrame?
	local model = SkinModelCache.getModel(skinId, gunName)
	if not model then
		return nil
	end
	local viewport = GunViewportFactory.create(model, {
		fov = 50,
		distanceMultiplier = 0.90,
		rotation = CFrame.Angles(0, -math.pi / 2, 0) * CFrame.Angles(math.rad(20), 0, 0),
		ambient = Color3.fromRGB(150, 150, 155),
		lightDirection = Vector3.new(-0.4, -0.7, -0.5),
	})
	viewport.Name = "GunViewport_" .. skinId
	return viewport
end

type CardConfig = { imageId: string, label: string, animated: boolean }
type GunConfig = { skinId: string, gunName: string }
type GradientConfig = { name: string, colors: { Color3 } }

local SEQUENCE_CLR_SEQ = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 100)), ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 220, 140)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 220)), ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 220, 140)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 180, 100)), })

export type BundleShowcaseProps = {
	Cards: { CardConfig },
	Guns: { GunConfig },
	ChatGradient: GradientConfig?,
}

local GRADIENT_TWEEN_INFO = TweenInfo.new(
	2 / 0.35,
	Enum.EasingStyle.Linear,
	Enum.EasingDirection.In,
	-1,
	false,
	0
)

local function createAnimatedGradient(scope: FusionScope, colorSequence: ColorSequence, tweens: { Tween }): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = colorSequence
	gradient.Offset = Vector2.new(-1, 0)

	local tween = TweenService:Create(gradient, GRADIENT_TWEEN_INFO, { Offset = Vector2.new(1, 0) })
	tween:Play()
	table.insert(tweens, tween)

	table.insert(scope, function()
		gradient:Destroy()
	end)

	return gradient
end

local function BundleShowcase(scope: FusionScope, props: BundleShowcaseProps): Frame
	local gradientColors = if props.ChatGradient then props.ChatGradient.colors else INFERNO_GRADIENT
	local gradientName = if props.ChatGradient then props.ChatGradient.name else "INFERNO"
	local gradientSequence = convertGradientColors(gradientColors)
	local chatMessage = if gradientName == "Blizzard" then "Winter is coming" else "It's getting hot in here"

	local tweens: { Tween } = {}

	local badgeGradient = createAnimatedGradient(scope, SEQUENCE_CLR_SEQ, tweens)

	local usernameGradient = createAnimatedGradient(scope, gradientSequence, tweens)
	local barGradient = createAnimatedGradient(scope, gradientSequence, tweens)

	table.insert(scope, function()
		for _, tween in tweens do
			tween:Cancel()
		end
		table.clear(tweens)
	end)

	local localPlayer = Players.LocalPlayer
	local playerName = localPlayer and localPlayer.DisplayName or "Player"

	return scope:New("Frame")({
		Name = "BundleShowcase",
		Size = UDim2.new(1, 0, 1, -140),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "TopSection",
				Size = UDim2.new(1, -24, 0, 100),
				Position = UDim2.fromOffset(12, 8),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "BannerLeft",
						Size = UDim2.new(0.5, -8, 0, 72),
						Position = UDim2.fromOffset(0, 0),
						BackgroundColor3 = Color3.fromRGB(10, 10, 14),
						BackgroundTransparency = 0.4,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
							scope:New("UIStroke")({
								Color = Color3.fromRGB(80, 80, 90),
								Thickness = 1,
								Transparency = 0.6,
							}),
							if props.Cards[1].animated
								then createAnimatedBanner(scope, props.Cards[1].imageId)
								else createStaticBanner(scope, props.Cards[1].imageId),
						},
					}),

					scope:New("TextLabel")({
						Name = "LabelLeft",
						Size = UDim2.new(0.5, -8, 0, 20),
						Position = UDim2.fromOffset(0, 76),
						BackgroundTransparency = 1,
						Text = props.Cards[1].label,
						TextColor3 = Color3.fromRGB(200, 200, 210),
						TextSize = 12,
						Font = Enum.Font.GothamBold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),

					scope:New("Frame")({
						Name = "BannerRight",
						Size = UDim2.new(0.5, -8, 0, 72),
						Position = UDim2.new(0.5, 8, 0, 0),
						BackgroundColor3 = Color3.fromRGB(10, 10, 14),
						BackgroundTransparency = 0.4,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
							scope:New("UIStroke")({
								Color = Color3.fromRGB(80, 80, 90),
								Thickness = 1,
								Transparency = 0.6,
							}),
							if props.Cards[2].animated
								then createAnimatedBanner(scope, props.Cards[2].imageId)
								else createStaticBanner(scope, props.Cards[2].imageId),
						},
					}),

					scope:New("TextLabel")({
						Name = "LabelRight",
						Size = UDim2.new(0.5, -8, 0, 20),
						Position = UDim2.new(0.5, 8, 0, 76),
						BackgroundTransparency = 1,
						Text = props.Cards[2].label,
						TextColor3 = Color3.fromRGB(200, 200, 210),
						TextSize = 12,
						Font = Enum.Font.GothamBold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "GunsSection",
				Size = UDim2.new(1, 0, 1, -210),
				Position = UDim2.fromOffset(0, 108),
				BackgroundTransparency = 1,
				ClipsDescendants = true,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "GunLeft",
						Size = UDim2.fromScale(0.5, 1),
						Position = UDim2.fromOffset(0, 0),
						BackgroundTransparency = 1,
						ClipsDescendants = true,

						[Fusion.Children] = {
							createGunViewport(props.Guns[1].skinId, props.Guns[1].gunName),
						},
					}),

					scope:New("Frame")({
						Name = "GunRight",
						Size = UDim2.fromScale(0.5, 1),
						Position = UDim2.fromScale(0.5, 0),
						BackgroundTransparency = 1,
						ClipsDescendants = true,

						[Fusion.Children] = {
							createGunViewport(props.Guns[2].skinId, props.Guns[2].gunName),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "GradientSection",
				Size = UDim2.new(1, -24, 0, 100),
				Position = UDim2.new(0, 12, 1, -104),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "BadgeContainer",
						Size = UDim2.fromOffset(150, 24),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.fromRGB(18, 18, 24),
						BackgroundTransparency = 0.1,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
							scope:New("UIStroke")({
								Color = Color3.new(1, 1, 1),
								Thickness = 1.5,
								Transparency = 0.15,

								[Fusion.Children] = { badgeGradient },
							}),

							scope:New("TextLabel")({
								Name = "BadgeText",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = "NEW COSMETIC TYPE",
								TextColor3 = Color3.fromRGB(255, 230, 180),
								TextSize = 10,
								Font = Enum.Font.GothamBlack,
							}),
						},
					}),

					scope:New("TextLabel")({
						Name = "GradientTitle",
						Size = UDim2.new(1, 0, 0, 20),
						Position = UDim2.fromOffset(0, 28),
						BackgroundTransparency = 1,
						Text = string.upper(gradientName) .. " CHAT GRADIENT",
						TextColor3 = Color3.fromRGB(235, 235, 245),
						TextSize = 15,
						Font = Enum.Font.GothamBlack,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),

					scope:New("Frame")({
						Name = "GradientPreview",
						Size = UDim2.new(1, 0, 0, 44),
						Position = UDim2.fromOffset(0, 52),
						BackgroundColor3 = Color3.fromRGB(8, 8, 12),
						BackgroundTransparency = 0.3,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
							scope:New("UIStroke")({
								Color = Color3.fromRGB(70, 70, 80),
								Thickness = 1,
								Transparency = 0.7,
							}),

							scope:New("Frame")({
								Name = "ChatLine",
								Size = UDim2.new(1, -24, 0, 18),
								Position = UDim2.fromOffset(12, 6),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										VerticalAlignment = Enum.VerticalAlignment.Center,
										Padding = UDim.new(0, 5),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),

									scope:New("TextLabel")({
										Name = "Username",
										Size = UDim2.fromScale(0, 1),
										AutomaticSize = Enum.AutomaticSize.X,
										BackgroundTransparency = 1,
										Text = playerName .. ":",
										TextColor3 = Color3.new(1, 1, 1),
										TextSize = 13,
										Font = Enum.Font.GothamBold,
										LayoutOrder = 1,

										[Fusion.Children] = { usernameGradient },
									}),

									scope:New("TextLabel")({
										Name = "Message",
										Size = UDim2.fromScale(0, 1),
										AutomaticSize = Enum.AutomaticSize.X,
										BackgroundTransparency = 1,
										Text = chatMessage,
										TextColor3 = Color3.fromRGB(200, 200, 205),
										TextSize = 13,
										Font = Enum.Font.GothamMedium,
										LayoutOrder = 2,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "GradientBar",
								Size = UDim2.new(1, -24, 0, 6),
								Position = UDim2.new(0, 12, 1, -12),
								BackgroundColor3 = Color3.new(1, 1, 1),

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
									barGradient,
								},
							}),
						},
					}),
				},
			}),
		},
	})
end

return BundleShowcase
