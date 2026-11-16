--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local AnimatedCardService = require(MainModule.Client.Services.AnimatedCardService)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionCanBeState<T> = Types.FusionCanBeState<T>

export type HitLogEntry = {
	attackerId: number,
	bodyPart: number,
	localX: number,
	localY: number,
	localZ: number,
	damage: number,
	gunIndex: number,
	headshot: boolean,
}

export type OutgoingHitEntry = {
	targetId: number,
	damage: number,
	gunIndex: number,
	headshot: boolean,
}

export type DeathScreenData = {
	killerUserId: number,
	killerName: string,
	gunName: string,
	range: number,
	killerHealth: number,
	playerCardImage: string?,
	isAnimatedCard: boolean?,
}

export type DeathScreenPhase = "hidden" | "visible" | "fadeout"

export type DeathScreenProps = {
	Phase: FusionCanBeState<DeathScreenPhase>,
	Data: FusionCanBeState<DeathScreenData?>,
	OverlayDarkness: FusionCanBeState<number>?,
	RespawnProgress: FusionCanBeState<number>?,
	RespawnTimeLeft: FusionCanBeState<number>?,
	VDIButtonVisible: FusionCanBeState<boolean>?,
	OnVDIToggle: (() -> ())?,
}

local SKULL_ASSET = "rbxassetid://113780006558360"
local SKULL_SIZE = 110

local CARD_WIDTH = 520
local CARD_HEIGHT = 120
local AVATAR_SIZE = CARD_HEIGHT

local PROGRESS_WIDTH = 300
local PROGRESS_HEIGHT = 7

local DEATH_RED = Color3.fromRGB(200, 35, 35)
local PROGRESS_TRACK_COLOR = Color3.fromRGB(50, 50, 50)
local CARD_BACKGROUND = Color3.fromRGB(18, 18, 18)
local CARD_BORDER = Color3.fromRGB(100, 100, 110)
local BANNER_TRANSPARENCY = 0.35

local FONT_TITLE = Enum.Font.BuilderSansExtraBold
local FONT_BOLD = Enum.Font.BuilderSansBold
local FONT_MEDIUM = Enum.Font.BuilderSansMedium

local SKULL_GAP = 12
local TITLE_HEIGHT = 42
local TITLE_GAP = 16
local STROKE_PADDING = 4
local CONTENT_HEIGHT = SKULL_SIZE + SKULL_GAP + TITLE_HEIGHT + TITLE_GAP + CARD_HEIGHT + STROKE_PADDING

local BTN_W = CARD_WIDTH
local BTN_H = 36
local BTN_GAP = 12
local BTN_BG = Color3.fromRGB(22, 22, 25)
local BTN_BG_HOVER = Color3.fromRGB(32, 32, 36)
local BTN_BORDER = Color3.fromRGB(140, 140, 150)
local BTN_TEXT = Color3.fromRGB(180, 180, 190)
local BTN_TEXT_HOVER = Color3.fromRGB(220, 220, 230)

local RESPAWN_GAP = 30

local CARD_GRADIENT_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.6, 0),
	NumberSequenceKeypoint.new(1, 0.7),
})

local SPRING_SPEED = 22
local SPRING_DAMPING = 1
local CONTENT_Y_SHIFT = 30

local function resolve(scope: FusionScope, prop: any, default: any): any
	return scope:Computed(function(use: FusionUseFn)
		if prop == nil then
			return default
		end
		if typeof(prop) == "table" then
			return use(prop)
		end
		return prop
	end)
end

local function DeathScreen(scope: FusionScope, props: DeathScreenProps): ScreenGui
	local phase = resolve(scope, props.Phase, "hidden")
	local data = resolve(scope, props.Data, nil)
	local respawnProgress = resolve(scope, props.RespawnProgress, 1)
	local respawnTimeLeft = resolve(scope, props.RespawnTimeLeft, 0)
	local vdiButtonVisible = resolve(scope, props.VDIButtonVisible, false)
	local overlayDarkness = resolve(scope, props.OverlayDarkness, 0)

	local btnHovered = scope:Value(false)

	local isVisible = scope:Computed(function(use: FusionUseFn)
		return use(phase) ~= "hidden"
	end)

	local isActive = scope:Computed(function(use: FusionUseFn)
		return use(phase) == "visible"
	end)

	local contentY = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isActive) then 0 else -CONTENT_Y_SHIFT
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local contentAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isActive) then 0 else 1
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)


	local killerName = scope:Computed(function(use: FusionUseFn)
		local d = use(data)
		return if d then string.upper(d.killerName) else "UNKNOWN"
	end)

	local gunName = scope:Computed(function(use: FusionUseFn)
		local d = use(data)
		return if d then d.gunName else "Unknown"
	end)

	local killerRange = scope:Computed(function(use: FusionUseFn)
		local d = use(data)
		return if d then d.range else 0
	end)

	local killerHealth = scope:Computed(function(use: FusionUseFn)
		local d = use(data)
		return if d then d.killerHealth else 0
	end)

	local avatarUrl = scope:Computed(function(use: FusionUseFn)
		local d = use(data)
		if d and d.killerUserId > 0 then
			return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", d.killerUserId)
		end
		return ""
	end)

	local playerCardImage = scope:Computed(function(use: FusionUseFn)
		local d = use(data)
		return if d and d.playerCardImage then d.playerCardImage else ""
	end)

	local isAnimatedCard = scope:Computed(function(use: FusionUseFn)
		local d = use(data)
		return if d then d.isAnimatedCard == true else false
	end)

	local hasCard = scope:Computed(function(use: FusionUseFn)
		return use(playerCardImage) ~= ""
	end)

	local progressFillScale = scope:Computed(function(use: FusionUseFn)
		return math.clamp(use(respawnProgress), 0, 1)
	end)

	local countdownText = scope:Computed(function(use: FusionUseFn)
		return tostring(math.ceil(math.max(use(respawnTimeLeft), 0)))
	end)

	local function createBannerContent(): any
		local bannerChildren: { any } = {}

		table.insert(
			bannerChildren,
			scope:New("ImageLabel")({
				Name = "StaticCardBackground",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = playerCardImage,
				ImageTransparency = BANNER_TRANSPARENCY,
				ScaleType = Enum.ScaleType.Crop,
				ZIndex = 1,
				Visible = scope:Computed(function(use: FusionUseFn)
					return use(hasCard) and not use(isAnimatedCard)
				end),
				[Fusion.Children] = {
					scope:New("UIGradient")({
						Transparency = CARD_GRADIENT_TRANSPARENCY,
					}),
				},
			})
		)

		local animatedContainer = scope:New("CanvasGroup")({
			Name = "AnimatedCardContainer",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			GroupTransparency = 0,
			ZIndex = 1,
			Visible = scope:Computed(function(use: FusionUseFn)
				return use(hasCard) and use(isAnimatedCard)
			end),
			[Fusion.Children] = {
				scope:New("UIGradient")({
					Transparency = CARD_GRADIENT_TRANSPARENCY,
				}),
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
							Image = playerCardImage,
							ImageTransparency = BANNER_TRANSPARENCY,
							ScaleType = Enum.ScaleType.Crop,
						}),
						scope:New("ImageLabel")({
							Name = "CardImage2",
							Position = UDim2.fromScale(0.5, 0),
							Size = UDim2.fromScale(0.5, 1),
							BackgroundTransparency = 1,
							Image = playerCardImage,
							ImageTransparency = BANNER_TRANSPARENCY,
							ScaleType = Enum.ScaleType.Crop,
						}),
					},
				}),
			},
		})

		table.insert(bannerChildren, animatedContainer)

		local registeredContainer: any = nil
		local waitThread: thread? = nil
		scope:Observer(data):onBind(function()
			local currentData = Fusion.peek(data)
			local shouldAnimate = currentData
				and currentData.isAnimatedCard == true
				and currentData.playerCardImage
				and currentData.playerCardImage ~= ""
			local cardUserId = currentData and currentData.killerUserId or nil
			local container = animatedContainer

			if waitThread then
				task.cancel(waitThread)
				waitThread = nil
			end

			if shouldAnimate then
				waitThread = task.spawn(function()
					local waitCount = 0
					while container and not container.Parent and waitCount < 10 do
						task.wait()
						waitCount += 1
					end
					waitThread = nil
					if container and container.Parent then
						if registeredContainer and registeredContainer ~= container then
							AnimatedCardService:UnregisterContainer(registeredContainer)
						end
						AnimatedCardService:RegisterContainer(container, cardUserId)
						registeredContainer = container
					end
				end)
			elseif registeredContainer then
				AnimatedCardService:UnregisterContainer(registeredContainer)
				registeredContainer = nil
			end
		end)

		table.insert(scope, function()
			if waitThread then
				task.cancel(waitThread)
				waitThread = nil
			end
			if registeredContainer then
				AnimatedCardService:UnregisterContainer(registeredContainer)
				registeredContainer = nil
			end
		end)

		return bannerChildren
	end

	return scope:New("ScreenGui")({
		Name = "DeathScreen",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = isVisible,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Overlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
					local d = use(overlayDarkness)
					if type(d) ~= "number" then
						d = 0
					end
					return math.clamp(1 - d, 0, 1)
				end),
				BorderSizePixel = 0,
				Visible = scope:Computed(function(use: FusionUseFn)
					local d = use(overlayDarkness)
					return use(isVisible) and type(d) == "number" and d > 0.001
				end),
				ZIndex = 1,
			}),

			scope:New("CanvasGroup")({
				Name = "Content",
				Size = UDim2.new(1, 0, 0, CONTENT_HEIGHT),
				Position = scope:Computed(function(use: FusionUseFn)
					return UDim2.new(0.5, 0, 0.38, use(contentY))
				end),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				GroupTransparency = contentAlpha,
				ZIndex = 10,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					scope:New("ImageLabel")({
						Name = "Skull",
						Size = UDim2.fromOffset(SKULL_SIZE, SKULL_SIZE),
						BackgroundTransparency = 1,
						Image = SKULL_ASSET,
						LayoutOrder = 1,
					}),

					scope:New("Frame")({
						Name = "SkullGap",
						Size = UDim2.fromOffset(1, SKULL_GAP),
						BackgroundTransparency = 1,
						LayoutOrder = 2,
					}),

					scope:New("TextLabel")({
						Name = "Title",
						Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
						BackgroundTransparency = 1,
						Text = "YOU WERE KILLED BY",
						TextColor3 = Theme.Colors.White,
						TextSize = 34,
						Font = FONT_TITLE,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						LayoutOrder = 3,
					}),

					scope:New("Frame")({
						Name = "TitleGap",
						Size = UDim2.fromOffset(1, TITLE_GAP),
						BackgroundTransparency = 1,
						LayoutOrder = 4,
					}),

					scope:New("CanvasGroup")({
						Name = "Card",
						Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
						BackgroundColor3 = CARD_BACKGROUND,
						BackgroundTransparency = 0.15,
						LayoutOrder = 5,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0, 4),
							}),

							scope:New("UIStroke")({
								Color = CARD_BORDER,
								Thickness = 1,
								Transparency = 0.5,
							}),

							scope:New("Frame")({
								Name = "BannerContainer",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								ClipsDescendants = true,
								ZIndex = 1,
								[Fusion.Children] = {
									scope:New("UICorner")({
										CornerRadius = UDim.new(0, 4),
									}),
									createBannerContent(),
								},
							}),

							scope:New("ImageLabel")({
								Name = "Avatar",
								Size = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE),
								Position = UDim2.fromOffset(0, 0),
								BackgroundTransparency = 1,
								Image = avatarUrl,
								ZIndex = 5,
								[Fusion.Children] = {
									scope:New("UICorner")({
										CornerRadius = UDim.new(0, 4),
									}),
								},
							}),

							scope:New("Frame")({
								Name = "LeftInfo",
								Size = UDim2.fromOffset(250, 52),
								Position = UDim2.fromOffset(AVATAR_SIZE + 16, 12),
								BackgroundTransparency = 1,
								ZIndex = 5,
								[Fusion.Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Vertical,
										VerticalAlignment = Enum.VerticalAlignment.Top,
										Padding = UDim.new(0, -2),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),
									scope:New("TextLabel")({
										Name = "KillerName",
										Size = UDim2.new(1, 0, 0, 36),
										BackgroundTransparency = 1,
										Text = killerName,
										TextColor3 = Theme.Colors.White,
										TextScaled = true,
										Font = FONT_BOLD,
										TextXAlignment = Enum.TextXAlignment.Left,
										LayoutOrder = 1,
										[Fusion.Children] = {
											scope:New("UITextSizeConstraint")({
												MaxTextSize = 32,
												MinTextSize = 16,
											}),
										},
									}),
									scope:New("TextLabel")({
										Name = "HP",
										Size = UDim2.new(1, 0, 0, 20),
										BackgroundTransparency = 1,
										Text = scope:Computed(function(use: FusionUseFn)
											return tostring(math.floor(use(killerHealth))) .. " HP"
										end),
										TextColor3 = Theme.Colors.Black[200],
										TextSize = 16,
										Font = FONT_MEDIUM,
										TextXAlignment = Enum.TextXAlignment.Left,
										LayoutOrder = 2,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "RightInfo",
								Size = UDim2.fromOffset(120, 48),
								Position = UDim2.new(1, -16, 1, -12),
								AnchorPoint = Vector2.one,
								BackgroundTransparency = 1,
								ZIndex = 5,
								[Fusion.Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Vertical,
										VerticalAlignment = Enum.VerticalAlignment.Bottom,
										HorizontalAlignment = Enum.HorizontalAlignment.Right,
										Padding = UDim.new(0, 0),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),
									scope:New("TextLabel")({
										Name = "GunName",
										Size = UDim2.new(1, 0, 0, 26),
										BackgroundTransparency = 1,
										Text = gunName,
										TextColor3 = Theme.Colors.White,
										TextSize = 22,
										Font = FONT_BOLD,
										TextXAlignment = Enum.TextXAlignment.Right,
										LayoutOrder = 1,
									}),
									scope:New("TextLabel")({
										Name = "Range",
										Size = UDim2.new(1, 0, 0, 18),
										BackgroundTransparency = 1,
										Text = scope:Computed(function(use: FusionUseFn)
											return tostring(math.floor(use(killerRange))) .. " STUDS"
										end),
										TextColor3 = Theme.Colors.Black[300],
										TextSize = 14,
										Font = FONT_MEDIUM,
										TextXAlignment = Enum.TextXAlignment.Right,
										LayoutOrder = 2,
									}),
								},
							}),
						},
					}),
				},
			}),

			scope:New("TextButton")({
				Name = "DeathReportBtn",
				Size = UDim2.fromOffset(BTN_W, BTN_H),
				Position = scope:Computed(function(use: FusionUseFn)
					return UDim2.new(0.5, 0, 0.38, use(contentY) + CONTENT_HEIGHT / 2 + BTN_GAP)
				end),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = scope:Spring(
					scope:Computed(function(use: FusionUseFn)
						return if use(btnHovered) then BTN_BG_HOVER else BTN_BG
					end),
					Theme.Spring.Snappy.Speed
				),
				BackgroundTransparency = 0.25,
				BorderSizePixel = 0,
				Text = "VDI DEATH REPORT",
				TextColor3 = scope:Spring(
					scope:Computed(function(use: FusionUseFn)
						return if use(btnHovered) then BTN_TEXT_HOVER else BTN_TEXT
					end),
					Theme.Spring.Snappy.Speed
				),
				TextSize = 12,
				Font = FONT_BOLD,
				AutoButtonColor = false,
				ZIndex = 10,
				Visible = scope:Computed(function(use: FusionUseFn)
					return use(vdiButtonVisible) and use(isActive)
				end),

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
					scope:New("UIStroke")({
						Color = BTN_BORDER,
						Thickness = 1,
						Transparency = 0.3,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
				},

				[Fusion.OnEvent("MouseEnter")] = function()
					btnHovered:set(true)
				end,
				[Fusion.OnEvent("MouseLeave")] = function()
					btnHovered:set(false)
				end,
				[Fusion.OnEvent("Activated")] = function()
					if props.OnVDIToggle then
						props.OnVDIToggle()
					end
				end,
			}),

			scope:New("CanvasGroup")({
				Name = "RespawnSection",
				Size = UDim2.fromOffset(PROGRESS_WIDTH, 90),
				Position = scope:Computed(function(use: FusionUseFn)
					local extraOffset = if use(vdiButtonVisible) then BTN_H + BTN_GAP else 0
					return UDim2.new(0.5, 0, 0.38, use(contentY) + CONTENT_HEIGHT / 2 + RESPAWN_GAP + extraOffset)
				end),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				GroupTransparency = contentAlpha,
				ZIndex = 10,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					scope:New("TextLabel")({
						Name = "RespawnLabel",
						Size = UDim2.new(1, 0, 0, 18),
						BackgroundTransparency = 1,
						Text = "You will respawn in",
						TextColor3 = Theme.Colors.White,
						TextSize = 14,
						Font = FONT_MEDIUM,
						TextXAlignment = Enum.TextXAlignment.Center,
						LayoutOrder = 1,
					}),

					scope:New("Frame")({
						Name = "ProgressTrack",
						Size = UDim2.new(1, 0, 0, PROGRESS_HEIGHT),
						BackgroundColor3 = PROGRESS_TRACK_COLOR,
						LayoutOrder = 2,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0.5, 0),
							}),

							scope:New("Frame")({
								Name = "Fill",
								Size = scope:Computed(function(use: FusionUseFn)
									return UDim2.fromScale(use(progressFillScale), 1)
								end),
								BackgroundColor3 = DEATH_RED,

								[Fusion.Children] = {
									scope:New("UICorner")({
										CornerRadius = UDim.new(0.5, 0),
									}),
								},
							}),
						},
					}),

					scope:New("Frame")({
						Name = "BarGap",
						Size = UDim2.fromOffset(1, 4),
						BackgroundTransparency = 1,
						LayoutOrder = 3,
					}),

					scope:New("TextLabel")({
						Name = "Countdown",
						Size = UDim2.new(1, 0, 0, 32),
						BackgroundTransparency = 1,
						Text = countdownText,
						TextColor3 = Theme.Colors.White,
						TextSize = 28,
						Font = FONT_BOLD,
						TextXAlignment = Enum.TextXAlignment.Center,
						LayoutOrder = 4,
					}),
				},
			}),
		},
	})
end

return DeathScreen
