--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)

local SkinModelCache = require(script.Parent.Parent.Cache.SkinModelCache)
local GunViewportFactory = require(MainModule.Client.Utils.GunViewportFactory)
local BundleSettings = require(script.Parent.Parent.BundleSettings)
local GradientBackground = require(script.Parent.GradientBackground)

type FusionScope = Types.FusionScope

local SKIN_ID: string = nil
local BUNDLE_DISPLAY_NAME: string = "HELLO KITTY WEAPON BUNDLE"
local BUNDLE_TEXT_COLOR: Color3 = Color3.fromRGB(255, 255, 255)
local SHOWCASE_GUNS = { "H-82", "BR-16", "H-50", "H-94", "H-41", "BR-22", "BR-50" }
local PLAYER_CARD_IMAGE: string?

local HEADER_HEIGHT = 20
local BOTTOM_SECTION_HEIGHT = 90
local VIEWPORT_OVERSIZE = 2.5

local GUN_TILT_Y = -math.pi / 2
local GUN_TILT_UP = math.rad(25)
local GUN_LEAN_RIGHT = math.rad(10)
local CAMERA_DIST = 1.0

local HELLO_KITTY_GRADIENT_COLORS: { Color3 } = {}
local HAS_CHAT_GRADIENT = true

local GRADIENT_TWEEN_INFO = TweenInfo.new(2 / 0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 0)

local GUN_TILT_Y_OVERRIDES = {
	["BR-22"] = math.pi / 2,
	["BR-50"] = math.pi / 2,
	["H-41"] = math.pi / 2,
	["H-94"] = math.pi / 2,
}

local function bundleSetup()
	local selectedSkin = BundleSettings.selectSkin() or "Freeze"
	local bundle = BundleSettings[selectedSkin]

	SKIN_ID = bundle.Id
	BUNDLE_DISPLAY_NAME = bundle.DisplayName
	BUNDLE_TEXT_COLOR = bundle.TitleTextColor
	HELLO_KITTY_GRADIENT_COLORS = bundle.Gradient
	HAS_CHAT_GRADIENT = not bundle.NoChatGradient
	PLAYER_CARD_IMAGE = "rbxassetid://" .. tostring(bundle.CardImage)

	GradientBackground.setThemeColor(BUNDLE_TEXT_COLOR)
end

local function createGunViewport(gunName: string): ViewportFrame?
	local model = SkinModelCache.getModel(SKIN_ID, gunName)
	if not model then
		return nil
	end

	local tiltY = GUN_TILT_Y_OVERRIDES[gunName] or GUN_TILT_Y
	local tiltUp = GUN_TILT_UP
	local leanRight = GUN_LEAN_RIGHT
	if GUN_TILT_Y_OVERRIDES[gunName] then
		tiltUp = -GUN_TILT_UP
		leanRight = -GUN_LEAN_RIGHT
	end
	local rotation = CFrame.Angles(0, tiltY, 0) * CFrame.Angles(tiltUp, 0, leanRight)

	local viewport = GunViewportFactory.create(model, {
		fov = 50,
		distanceMultiplier = CAMERA_DIST,
		rotation = rotation,
		ambient = Color3.fromRGB(135, 130, 130),
		lightColor = Color3.fromRGB(255, 245, 245),
		lightDirection = Vector3.new(-0.5, -0.8, -0.3),
	})
	viewport.Name = "GunViewport_" .. gunName
	viewport.Size = UDim2.fromScale(VIEWPORT_OVERSIZE, 1)
	viewport.Position = UDim2.fromScale(0.5, 0.5)
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	return viewport
end

local function buildColorSequence(colors: { Color3 }): ColorSequence
	local keypoints: { ColorSequenceKeypoint } = {}
	for i, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keypoints)
end

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

export type HelloKittyBundleShowcaseProps = {
	TitleOut: Types.FusionValue<string>?,
	BundleKeyOut: Types.FusionValue<string>?,
}

local function HelloKittyBundleShowcase(scope: FusionScope, props: HelloKittyBundleShowcaseProps?): Frame
	bundleSetup()

	if props and props.TitleOut then
		props.TitleOut:set(BUNDLE_DISPLAY_NAME)
	end

	if props and props.BundleKeyOut then
		props.BundleKeyOut:set(SKIN_ID)
	end

	local gunFrames: { Instance } = {}
	local gunWidth = 1 / #SHOWCASE_GUNS

	for i, gunName in SHOWCASE_GUNS do
		table.insert(
			gunFrames,
			scope:New("Frame")({
				Name = "Slot_" .. gunName,
				Size = UDim2.fromScale(gunWidth, 1),
				Position = UDim2.fromScale((i - 1) * gunWidth, 0),
				BackgroundTransparency = 1,
				ClipsDescendants = false,

				[Fusion.Children] = {
					createGunViewport(gunName),
				},
			})
		)
	end

	local tweens: { Tween } = {}
	local gradientSequence = buildColorSequence(HELLO_KITTY_GRADIENT_COLORS)
	local barGradient = createAnimatedGradient(scope, gradientSequence, tweens)

	table.insert(scope, function()
		for _, tween in tweens do
			tween:Cancel()
		end
		table.clear(tweens)
	end)

	return scope:New("Frame")({
		Name = "HelloKittyBundleShowcase",
		Size = UDim2.new(1, 0, 1, -60),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("TextLabel")({
				Name = "SkinsHeader",
				Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
				Position = UDim2.fromOffset(4, 0),
				BackgroundTransparency = 1,
				Text = "ORIGINAL GUN SKINS FOR EVERY GUN",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			scope:New("Frame")({
				Name = "GunsRow",
				Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + BOTTOM_SECTION_HEIGHT + 68)),
				Position = UDim2.fromOffset(0, HEADER_HEIGHT),
				BackgroundTransparency = 1,
				ClipsDescendants = false,

				[Fusion.Children] = gunFrames,
			}),

			scope:New("Frame")({
				Name = "BottomShowcase",
				Size = UDim2.new(1, 0, 0, BOTTOM_SECTION_HEIGHT),
				Position = UDim2.new(0, 0, 1, -(BOTTOM_SECTION_HEIGHT + 64)),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "GradientSection",
						Size = UDim2.new(0.5, -8, 1, 0),
						BackgroundTransparency = 1,
						Visible = HAS_CHAT_GRADIENT,

						[Fusion.Children] = {
							scope:New("TextLabel")({
								Name = "GradientLabel",
								Size = UDim2.new(1, 0, 0, 16),
								BackgroundTransparency = 1,
								Text = "INCLUDED CHAT GRADIENT",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 11,
								Font = Enum.Font.GothamBlack,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),

							scope:New("Frame")({
								Name = "GradientPreview",
								Size = UDim2.new(1, 0, 1, -20),
								Position = UDim2.fromOffset(0, 20),
								BackgroundColor3 = Color3.fromRGB(8, 10, 14),
								BackgroundTransparency = 0.25,

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
									scope:New("UIStroke")({
										Color = Color3.fromRGB(50, 55, 60),
										Thickness = 1,
										Transparency = 0.5,
									}),

									scope:New("TextLabel")({
										Name = "GradientTitle",
										Size = UDim2.new(1, -16, 0, 16),
										Position = UDim2.fromOffset(8, 6),
										BackgroundTransparency = 1,
										Text = BUNDLE_DISPLAY_NAME .. " CHAT GRADIENT",
										TextColor3 = BUNDLE_TEXT_COLOR,
										TextSize = 11,
										Font = Enum.Font.GothamBlack,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),

									scope:New("Frame")({
										Name = "GradientBar",
										Size = UDim2.new(1, -16, 0, 22),
										Position = UDim2.new(0, 8, 1, -30),
										BackgroundColor3 = Color3.new(1, 1, 1),

										[Fusion.Children] = {
											scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
											barGradient,
										},
									}),
								},
							}),
						},
					}),

					scope:New("Frame")({
						Name = "CardSection",
						Size = UDim2.new(0.5, -8, 1, 0),
						Position = UDim2.new(0.5, 8, 0, 0),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("TextLabel")({
								Name = "CardLabel",
								Size = UDim2.new(1, 0, 0, 16),
								BackgroundTransparency = 1,
								Text = "INCLUDED PLAYER CARD",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 11,
								Font = Enum.Font.GothamBlack,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),

							scope:New("Frame")({
								Name = "CardContainer",
								Size = UDim2.new(1, 0, 1, -20),
								Position = UDim2.fromOffset(0, 20),
								BackgroundColor3 = Color3.fromRGB(8, 10, 14),
								BackgroundTransparency = 0.2,

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
									scope:New("UIStroke")({
										Color = Color3.fromRGB(50, 55, 60),
										Thickness = 1,
										Transparency = 0.5,
									}),

									scope:New("ImageLabel")({
										Name = "Banner",
										Size = UDim2.new(1, -8, 1, -8),
										Position = UDim2.fromOffset(4, 4),
										BackgroundTransparency = 1,
										Image = PLAYER_CARD_IMAGE,
										ScaleType = Enum.ScaleType.Crop,

										[Fusion.Children] = {
											scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
										},
									}),
								},
							}),
						},
					}),
				},
			}),
		},
	})
end

return HelloKittyBundleShowcase
