--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Network = require(MainModule.Shared.Network)
local Shadow = require(MainModule.Client.Components.Shadow)
local StoreHubRedirects = require(MainModule.Shared.Config.StoreHubRedirects)

local SkinModelCache = require(MainModule.Client.Components.Menu.Shop.Cache.SkinModelCache)
local GunViewportFactory = require(MainModule.Client.Utils.GunViewportFactory)
local StoreHubRedirectPrompt = require(MainModule.Client.Components.Menu.Shop.Components.StoreHubRedirectPrompt)
local PurchaseRedirectController = require(MainModule.Client.Components.Menu.Shop.PurchaseRedirectController)
local BundleSettings = require(MainModule.Client.Components.Menu.Shop.BundleSettings)
local Core = require(MainModule.Shared.Network.Core)

type FusionScope = Types.FusionScope

local BundlePopupService = {}
BundlePopupService.Name = "BundlePopupService"

local SHOWCASE_GUNS = { "H-82", "BR-16", "H-50", "H-94" }

local POPUP_WIDTH = 500
local POPUP_HEIGHT = 420
local CLOSE_BUTTON_HEIGHT = 42
local CLOSE_GAP = 10
local CORNER_RADIUS = 8
local VIEWPORT_OVERSIZE = 2.2

local BG_COLOR = Color3.fromRGB(8, 8, 8)
local BG_TRANSPARENCY = 0.3
local BORDER_COLOR = Color3.fromRGB(50, 55, 65)
local SUBTLE_TEXT = Color3.fromRGB(150, 155, 165)
local WHITE = Color3.fromRGB(255, 255, 255)

local HEADER_Y = 16
local SUBTITLE_Y = 46
local GUNS_Y = 66
local GUNS_HEIGHT = 200
local CARD_Y = GUNS_Y + GUNS_HEIGHT + 10
local CARD_HEIGHT = 65

local GUN_TILT_Y = -math.pi / 2
local GUN_TILT_UP = math.rad(25)
local GUN_LEAN = math.rad(10)
local CAMERA_DIST = 1.0

local GUN_TILT_Y_OVERRIDES = {
	["BR-22"] = math.pi / 2,
	["BR-50"] = math.pi / 2,
	["H-41"] = math.pi / 2,
	["H-94"] = math.pi / 2,
}

local scope: FusionScope? = nil
local connections: { any } = {}
local isInitialized = false

local TeleportToHubEvent: RemoteEvent = Core.getOrCreateRemoteEvent("TeleportToHub")

local function createGunViewport(s: FusionScope, skinId: string, gunName: string): ViewportFrame
	local model = SkinModelCache.getModel(skinId, gunName)
	if not model then
		return s:New("ViewportFrame")({
			Name = "Gun_" .. gunName,
			Size = UDim2.fromScale(VIEWPORT_OVERSIZE, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end

	local tiltY = GUN_TILT_Y
	local tiltUp = GUN_TILT_UP
	local leanRight = GUN_LEAN

	if (skinId == "HelloKitty" or skinId == "Vex" or skinId == "Freeze") and GUN_TILT_Y_OVERRIDES[gunName] then
		tiltY = GUN_TILT_Y_OVERRIDES[gunName]
		tiltUp = -GUN_TILT_UP
		leanRight = -GUN_LEAN
	end

	local viewport = GunViewportFactory.create(model, {
		fov = 50,
		distanceMultiplier = CAMERA_DIST,
		rotation = CFrame.Angles(0, tiltY, 0) * CFrame.Angles(tiltUp, 0, leanRight),
		ambient = Color3.fromRGB(135, 130, 130),
		lightColor = Color3.fromRGB(255, 245, 245),
		lightDirection = Vector3.new(-0.5, -0.8, -0.3),
	})
	viewport.Name = "Gun_" .. gunName
	viewport.Size = UDim2.fromScale(VIEWPORT_OVERSIZE, 1)
	viewport.Position = UDim2.fromScale(0.5, 0.5)
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	return viewport
end

local function createPopup(s: FusionScope, bundle, onClose: () -> ()): ScreenGui
	local isVisible = s:Value(false)
	local cardImage = "rbxassetid://" .. tostring(bundle.CardImage)
	local accentColor: Color3 = bundle.TitleTextColor

	local redirectPromptGamepassId = s:Value(nil)
	local redirectStatusText = s:Value("")
	local redirectTeleporting = s:Value(false)
	local redirectPromptVisible = s:Computed(function(use)
		return use(redirectPromptGamepassId) ~= nil
	end)

	local function openRedirectPrompt(gamepassId: number)
		redirectPromptGamepassId:set(gamepassId)
		redirectStatusText:set("")
		redirectTeleporting:set(false)
	end

	local function closeRedirectPrompt()
		if Fusion.peek(redirectTeleporting) then
			return
		end
		redirectPromptGamepassId:set(nil)
		redirectStatusText:set("")
	end

	local function teleportToStoreHub()
		if Fusion.peek(redirectTeleporting) then
			return
		end

		local gamepassId = Fusion.peek(redirectPromptGamepassId)
		if not gamepassId then
			return
		end

		local hub = StoreHubRedirects.getHubForGamepass(gamepassId)
		if not hub then
			redirectStatusText:set("This item is not mapped to a store hub yet.")
			return
		end
		if hub.placeId <= 0 then
			redirectStatusText:set("This store hub needs a place ID in StoreHubRedirects.")
			return
		end

		redirectTeleporting:set(true)
		redirectStatusText:set("")
		TeleportToHubEvent:FireServer(gamepassId)
	end

	PurchaseRedirectController.setPromptHandler(openRedirectPrompt)
	table.insert(s, function()
		PurchaseRedirectController.clearPromptHandler(openRedirectPrompt)
	end)

	local popupScale = s:Spring(
		s:Computed(function(use)
			return if use(isVisible) then 1 else 0.9
		end),
		30,
		0.85
	)

	local popupTransparency = s:Spring(
		s:Computed(function(use)
			return if use(isVisible) then 0 else 1
		end),
		25,
		1
	)

	local overlayTransparency = s:Spring(
		s:Computed(function(use)
			return if use(isVisible) then 0.35 else 1
		end),
		25,
		1
	)

	task.defer(function()
		isVisible:set(true)
	end)

	local gunSlots: { Instance } = {}
	local gunWidth = 1 / #SHOWCASE_GUNS

	for i, gunName in SHOWCASE_GUNS do
		table.insert(
			gunSlots,
			s:New("Frame")({
				Name = "Slot_" .. gunName,
				Size = UDim2.fromScale(gunWidth, 1),
				Position = UDim2.fromScale((i - 1) * gunWidth, 0),
				BackgroundTransparency = 1,
				ClipsDescendants = false,

				[Fusion.Children] = {
					createGunViewport(s, bundle.Id, gunName),
				},
			})
		)
	end

	local function handleClose()
		isVisible:set(false)
		task.delay(0.5, onClose)
	end

	local function handlePurchase()
		PurchaseRedirectController.promptPurchase(bundle.BundleId)
	end

	local padX = 20

	return s:New("ScreenGui")({
		Name = "BundlePopup",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			s:New("Frame")({
				Name = "Overlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = overlayTransparency,
				BorderSizePixel = 0,
				ZIndex = 1,
			}),

			s:New("Frame")({
				Name = "ShadowWrapper",
				Size = UDim2.fromOffset(POPUP_WIDTH, POPUP_HEIGHT),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 2,

				[Fusion.Children] = {
					s:New("UIScale")({ Scale = popupScale }),
					Shadow(s, {
						Size = UDim2.new(1, 16, 1, 14),
						Position = UDim2.new(0.5, 0, 0.5, -1),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Spread = 0,
						Transparency = s:Computed(function(use)
							return 0.55 + use(popupTransparency) * 0.45
						end),
						Color = accentColor:Lerp(Color3.new(0, 0, 0), 0.55),
					}),
				},
			}),

			s:New("CanvasGroup")({
				Name = "Popup",
				Size = UDim2.fromOffset(POPUP_WIDTH, POPUP_HEIGHT),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = BG_COLOR,
				BackgroundTransparency = BG_TRANSPARENCY,
				GroupTransparency = popupTransparency,
				ZIndex = 3,

				[Fusion.Children] = {
					s:New("UIScale")({ Scale = popupScale }),
					s:New("UICorner")({ CornerRadius = UDim.new(0, CORNER_RADIUS) }),
					s:New("UIStroke")({
						Color = BORDER_COLOR,
						Thickness = 1,
						Transparency = s:Computed(function(use)
							return 0.4 + use(popupTransparency) * 0.6
						end),
					}),

					s:New("TextLabel")({
						Name = "Title",
						Size = UDim2.new(1, 0, 0, 28),
						Position = UDim2.fromOffset(0, HEADER_Y),
						BackgroundTransparency = 1,
						Text = bundle.DisplayName,
						TextColor3 = WHITE,
						TextSize = 22,
						Font = Enum.Font.GothamBlack,
					}),

					s:New("TextLabel")({
						Name = "Subtitle",
						Size = UDim2.new(1, 0, 0, 16),
						Position = UDim2.fromOffset(0, SUBTITLE_Y),
						BackgroundTransparency = 1,
						Text = "ORIGINAL GUN SKINS FOR EVERY WEAPON",
						TextColor3 = SUBTLE_TEXT,
						TextSize = 10,
						Font = Enum.Font.GothamBold,
					}),

					s:New("CanvasGroup")({
						Name = "GunsArea",
						Size = UDim2.fromOffset(POPUP_WIDTH - padX * 2, GUNS_HEIGHT),
						Position = UDim2.fromOffset(padX, GUNS_Y),
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 0.6,
						ClipsDescendants = true,

						[Fusion.Children] = {
							s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),

							s:New("ImageLabel")({
								Name = "CardBg",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Image = cardImage,
								ImageTransparency = 0.75,
								ScaleType = Enum.ScaleType.Crop,
								ZIndex = 0,

								[Fusion.Children] = {
									s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
								},
							}),

							gunSlots,
						},
					}),

					s:New("Frame")({
						Name = "CardRow",
						Size = UDim2.fromOffset(POPUP_WIDTH - padX * 2, CARD_HEIGHT),
						Position = UDim2.fromOffset(padX, CARD_Y),
						BackgroundColor3 = Color3.fromRGB(10, 12, 16),
						BackgroundTransparency = 0.35,

						[Fusion.Children] = {
							s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
							s:New("UIStroke")({
								Color = Color3.fromRGB(40, 45, 52),
								Thickness = 1,
								Transparency = 0.5,
							}),

							s:New("ImageLabel")({
								Name = "CardImage",
								Size = UDim2.new(0.5, 0, 1, -8),
								Position = UDim2.fromOffset(4, 4),
								BackgroundTransparency = 1,
								Image = cardImage,
								ScaleType = Enum.ScaleType.Crop,

								[Fusion.Children] = {
									s:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
								},
							}),

							s:New("Frame")({
								Name = "CardInfo",
								Size = UDim2.fromScale(0.46, 1),
								Position = UDim2.fromScale(0.54, 0),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									s:New("TextLabel")({
										Size = UDim2.new(1, 0, 0, 10),
										Position = UDim2.fromOffset(0, 10),
										BackgroundTransparency = 1,
										Text = "INCLUDED",
										TextColor3 = SUBTLE_TEXT,
										TextSize = 8,
										Font = Enum.Font.GothamBold,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
									s:New("TextLabel")({
										Size = UDim2.new(1, 0, 0, 16),
										Position = UDim2.fromOffset(0, 20),
										BackgroundTransparency = 1,
										Text = if bundle.NoChatGradient then "PLAYER CARD" else "PLAYER CARD + CHAT GRADIENT",
										TextColor3 = WHITE,
										TextSize = 12,
										Font = Enum.Font.GothamBlack,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
									s:New("TextLabel")({
										Size = UDim2.new(1, 0, 0, 10),
										Position = UDim2.fromOffset(0, 38),
										BackgroundTransparency = 1,
										Text = "Exclusive cosmetics with the bundle",
										TextColor3 = SUBTLE_TEXT,
										TextSize = 9,
										Font = Enum.Font.GothamMedium,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
								},
							}),
						},
					}),

					s:New("TextLabel")({
						Name = "Description",
						Size = UDim2.new(1, -padX * 2, 0, 30),
						Position = UDim2.fromOffset(20, 340),
						BackgroundTransparency = 1,
						Text = if bundle.NoChatGradient
							then "Includes original skins for every weapon and a player card. Visit the store for full previews."
							else "Includes original skins for every weapon, a player card, and a chat gradient. Visit the store for full previews.",
						TextColor3 = SUBTLE_TEXT,
						TextSize = 11,
						Font = Enum.Font.GothamMedium,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),

					s:New("TextButton")({
						Name = "PurchaseButton",
						Size = UDim2.fromOffset(460, 42),
						Position = UDim2.fromOffset(20, 369),
						BackgroundColor3 = accentColor:Lerp(Color3.new(0, 0, 0), 0.15),
						Text = "PURCHASE BUNDLE",
						TextColor3 = WHITE,
						TextSize = 16,
						Font = Enum.Font.GothamBlack,
						AutoButtonColor = true,

						[Fusion.Children] = {
							s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
							s:New("UIStroke")({
								Color = accentColor:Lerp(Color3.new(1, 1, 1), 0.35),
								Thickness = 1.5,
								Transparency = 0.3,
							}),
						},

						[Fusion.OnEvent("Activated")] = handlePurchase,
					}),
				},
			}),

			(function()
				local isCloseHovered = s:Value(false)
				local isClosePressed = s:Value(false)

				local closeBgTransparency = s:Spring(
					s:Computed(function(use)
						if use(isClosePressed) then
							return 0.15
						end
						if use(isCloseHovered) then
							return 0.25
						end
						return 0.35
					end),
					40
				)

				local closeBorderTransparency = s:Spring(
					s:Computed(function(use)
						if use(isClosePressed) then
							return 0.2
						end
						if use(isCloseHovered) then
							return 0.3
						end
						return 0.45
					end),
					40
				)

				local totalCenter = POPUP_HEIGHT / 2 + CLOSE_GAP / 2 + CLOSE_BUTTON_HEIGHT / 2

				return s:New("Frame")({
					Name = "CloseWrapper",
					Size = UDim2.fromOffset(POPUP_WIDTH, CLOSE_BUTTON_HEIGHT + 12),
					Position = UDim2.new(0.5, 0, 0.5, totalCenter),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					ZIndex = 4,

					[Fusion.Children] = {
						s:New("UIScale")({ Scale = popupScale }),

						Shadow(s, {
							Size = UDim2.fromScale(1, 1),
							Position = UDim2.new(0.5, 0, 0.5, 2),
							AnchorPoint = Vector2.new(0.5, 0.5),
							Spread = 0,
							Transparency = s:Computed(function(use)
								return 0.65 + use(popupTransparency) * 0.35
							end),
						}),

						s:New("CanvasGroup")({
							Name = "CloseButton",
							Size = UDim2.fromOffset(POPUP_WIDTH, CLOSE_BUTTON_HEIGHT),
							Position = UDim2.fromOffset(0, 6),
							BackgroundColor3 = BG_COLOR,
							BackgroundTransparency = closeBgTransparency,
							GroupTransparency = popupTransparency,

							[Fusion.Children] = {
								s:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
								s:New("UIStroke")({
									Color = BORDER_COLOR,
									Thickness = 1,
									Transparency = s:Computed(function(use)
										return math.max(use(closeBorderTransparency), use(popupTransparency))
									end),
								}),

								s:New("TextLabel")({
									Name = "Text",
									Size = UDim2.fromScale(1, 1),
									BackgroundTransparency = 1,
									Text = "CLOSE",
									TextColor3 = SUBTLE_TEXT,
									TextSize = 14,
									Font = Enum.Font.GothamBold,
								}),

								s:New("TextButton")({
									Name = "Hitbox",
									Size = UDim2.fromScale(1, 1),
									BackgroundTransparency = 1,
									Text = "",
									ZIndex = 10,

									[Fusion.OnEvent("MouseEnter")] = function()
										isCloseHovered:set(true)
									end,
									[Fusion.OnEvent("MouseLeave")] = function()
										isCloseHovered:set(false)
										isClosePressed:set(false)
									end,
									[Fusion.OnEvent("MouseButton1Down")] = function()
										isClosePressed:set(true)
									end,
									[Fusion.OnEvent("MouseButton1Up")] = function()
										isClosePressed:set(false)
									end,
									[Fusion.OnEvent("Activated")] = handleClose,
								}),
							},
						}),
					},
				})
			end)(),

			StoreHubRedirectPrompt(s, {
				Visible = redirectPromptVisible,
				GamepassId = redirectPromptGamepassId,
				Teleporting = redirectTeleporting,
				StatusText = redirectStatusText,
				OnTakeMeThere = teleportToStoreHub,
				OnStayHere = closeRedirectPrompt,
			}),
		},
	})
end

function BundlePopupService:init(): ()
	isInitialized = true
end

function BundlePopupService:start(): ()
	if not isInitialized then
		self:init()
	end

	local popupProcessing = false

	table.insert(
		connections,
		Network.Deploy.onDeployComplete(function()
			if scope or popupProcessing then
				return
			end
			popupProcessing = true

			local player = Players.LocalPlayer
			if not player then
				popupProcessing = false
				return
			end

			local playerGui = player:FindFirstChildOfClass("PlayerGui")
			if not playerGui then
				popupProcessing = false
				return
			end

			local selectedSkin = BundleSettings.selectSkin()
			local bundle = selectedSkin and BundleSettings[selectedSkin]
			if not bundle then
				popupProcessing = false
				return
			end

			scope = Fusion.scoped(Fusion)

			local gui = createPopup(scope, bundle, function()
				if scope then
					scope:doCleanup()
					scope = nil
				end
			end)

			gui.Parent = playerGui
			popupProcessing = false
		end)
	)
end

function BundlePopupService:Cleanup(): ()
	for _, conn in connections do
		if typeof(conn) == "table" and conn.Disconnect then
			conn:Disconnect()
		end
	end
	table.clear(connections)

	if scope then
		scope:doCleanup()
		scope = nil
	end

	isInitialized = false
end

return BundlePopupService
