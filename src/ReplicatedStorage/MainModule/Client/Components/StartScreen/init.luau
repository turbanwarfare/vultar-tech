--!native
--!optimize 2

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Constants = require(MainModule.Shared.Config.Constants)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Maps = require(MainModule.Shared.Config.Maps)
local WinCamera = require(MainModule.Client.Components.WinScreen.WinCamera)
local LoadingCameras = require(MainModule.Shared.Config.LoadingCameras)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type StartScreenProps = {
	Countdown: Types.FusionValue<number>,
	MaxPoints: Types.FusionValue<number>,
	GameId: string,
	OnDismissed: () -> (),
	Mode: string?,
}

local VULTAR_ICON = "rbxassetid://98751546690059"
local HOSTILES_ICON = "rbxassetid://0"

local DEFENDER_COLOR = Color3.fromRGB(180, 50, 50)
local HOSTILE_COLOR = Color3.fromRGB(50, 110, 200)
local STARTING_COLOR = Color3.fromRGB(220, 50, 50)
local DEFENDER_GLOW_COLOR = Color3.fromRGB(200, 55, 60)
local HOSTILE_GLOW_COLOR = Color3.fromRGB(60, 115, 210)
local TOPO_COLOR = Color3.fromRGB(163, 162, 165)
local TOPO_PATTERN = "rbxassetid://0"

local GHOST_LOGO_SIZE = 240
local SOLID_LOGO_SIZE = 200
local GHOST_TRANSPARENCY = 0.85

local LOGO_X_DEFENDER = 0.25
local LOGO_X_HOSTILE = 0.75
local LOGO_Y_OFFSET = -20

local BADGE_WIDTH = 200
local BADGE_HEIGHT = 60
local BADGE_CORNER = 4
local BADGE_ACCENT_HEIGHT = 3
local BADGE_ABOVE_LOGO = 30

local INFO_TEXT_COLOR = Color3.fromRGB(120, 120, 125)
local VERY_MUTED_COLOR = Color3.fromRGB(65, 65, 70)
local DIVIDER_COLOR = Color3.fromRGB(60, 60, 65)

local SPRING_SPEED = 12
local SPRING_DAMPING = 1
local POP_SPRING_SPEED = 20
local POP_SPRING_DAMPING = 0.9
local REVEAL_STAGGER = 0.25
local TOP_BADGE_Y = 24
local TOP_CENTER_Y = 100

local FADE_OUT_TIME = 0.5
local INTRO_TIME = 3
local FLYOVER_TIME = 7
local FLYOVER_MOVES = {
	{ CFrame.new(-1.5, 0, 0), CFrame.new(1.5, 0.4, -1.5) },
	{ CFrame.new(1.5, 0, 0), CFrame.new(-1.5, 0, 0) },
	{ CFrame.new(0, 0.5, 1), CFrame.new(0, -0.3, -1.5) },
}

local BG_ALPHA = 0.3

local DEFENDER_TEAMS = Constants.FACTIONS.DEFENDER_TEAMS
local HOSTILE_TEAMS = Constants.FACTIONS.RAIDER_TEAMS

local function getTeamCounts(): (number, number, number)
	local defenderCount = 0
	local hostileCount = 0

	for _, team in Teams:GetTeams() do
		local players = team:GetPlayers()
		local count = #players
		if DEFENDER_TEAMS[team.Name] then
			defenderCount += count
		elseif HOSTILE_TEAMS[team.Name] then
			hostileCount += count
		end
	end

	return defenderCount, hostileCount, defenderCount + hostileCount
end

local function getServerRegion(): string
	local region = ReplicatedStorage:GetAttribute("ServerRegion")
	if region and type(region) == "string" and #region > 0 then
		return string.upper(region)
	end
	return "UNKNOWN"
end

local function createBlur(): BlurEffect
	local existingBlur = Lighting:FindFirstChild("StartScreenBlur")
	if existingBlur and existingBlur:IsA("BlurEffect") then
		existingBlur:Destroy()
	end

	local blur = Instance.new("BlurEffect")
	blur.Name = "StartScreenBlur"
	blur.Size = 0
	blur.Parent = Lighting

	task.delay(30, function()
		if blur and blur.Parent then
			blur:Destroy()
		end
	end)

	return blur
end

local function TeamBadge(scope: FusionScope, teamName: string, playerCount: number, accentColor: Color3, alpha: any): Frame
	return scope:New("Frame")({
		Name = teamName .. "Badge",
		Size = UDim2.fromOffset(BADGE_WIDTH, BADGE_HEIGHT),
		BackgroundColor3 = Theme.Chat.Window.Background,
		BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
			return 0.25 + (1 - use(alpha)) * 0.75
		end),

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, BADGE_CORNER) }),
			scope:New("UIStroke")({
				Color = Theme.Chat.Window.Border,
				Thickness = 1,
				Transparency = scope:Computed(function(use: FusionUseFn)
					return 0.3 + (1 - use(alpha)) * 0.7
				end),
			}),

			scope:New("Frame")({
				Name = "TopAccent",
				Size = UDim2.new(0.4, 0, 0, BADGE_ACCENT_HEIGHT),
				Position = UDim2.new(0.5, 0, 0, -2),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = accentColor,
				BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
					return 1 - use(alpha)
				end),
				ZIndex = 2,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
				},
			}),

			scope:New("Frame")({
				Name = "TextContainer",
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.new(0.5, 0, 0.5, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 1),
					}),

					scope:New("TextLabel")({
						Name = "TeamName",
						Size = UDim2.new(1, 0, 0, 18),
						BackgroundTransparency = 1,
						Text = string.upper(teamName),
						TextColor3 = Theme.Colors.White,
						TextTransparency = scope:Computed(function(use: FusionUseFn)
							return 1 - use(alpha)
						end),
						TextSize = 14,
						Font = Theme.Text.Black,
						LayoutOrder = 1,
					}),

					scope:New("TextLabel")({
						Name = "PlayerCount",
						Size = UDim2.new(1, 0, 0, 13),
						BackgroundTransparency = 1,
						Text = playerCount .. " PLAYERS",
						TextColor3 = INFO_TEXT_COLOR,
						TextTransparency = scope:Computed(function(use: FusionUseFn)
							return 0.2 + (1 - use(alpha)) * 0.8
						end),
						TextSize = 10,
						Font = Theme.Text.Bold,
						LayoutOrder = 2,
					}),
				},
			}),
		},
	})
end

local function StartScreen(scope: FusionScope, props: StartScreenProps): (ScreenGui, () -> ())
	local countdown = props.Countdown
	local maxPoints = props.MaxPoints
	local onDismissed = props.OnDismissed

	local mode = props.Mode or "Hardpoint"
	local isPhaseMode = mode == "Phase"

	local defenderCount, hostileCount, totalCount = getTeamCounts()
	local mapName = Maps.getMapName() or "UNKNOWN"
	local mapConfig = Maps.getConfig()
	local gameTypeTag = "[" .. string.upper(mapConfig.GameType) .. "]"
	local dateStr = os.date("%m / %d / %y")
	local region = getServerRegion()
	local gameId = props.GameId

	local backgroundVisible = scope:Value(false)
	local badgesVisible = scope:Value(false)
	local ghostLogosVisible = scope:Value(false)
	local solidLogosVisible = scope:Value(false)
	local centerTextVisible = scope:Value(false)
	local isDismissing = scope:Value(false)
	local flyingOver = scope:Value(false)

	local countdownScaleGoal = scope:Value(1)

	local blur = createBlur()

	local backgroundAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDismissing) or use(flyingOver) then
				return 0
			end
			return if use(backgroundVisible) then BG_ALPHA else 0
		end),
		8,
		1
	)

	local backgroundLayerFade = scope:Computed(function(use: FusionUseFn)
		return math.clamp(1 - use(backgroundAlpha) / BG_ALPHA, 0, 1)
	end)

	local blurSize = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDismissing) or use(flyingOver) then
				return 0
			end
			return if use(backgroundVisible) then 24 else 0
		end),
		8,
		1
	)

	scope:Observer(blurSize):onChange(function()
		blur.Size = Fusion.peek(blurSize)
	end)

	local badgeAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDismissing) then
				return 0
			end
			return if use(badgesVisible) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local defenderBadgeX = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDismissing) then
				return -200
			end
			return if use(badgesVisible) then 0 else -200
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local hostileBadgeX = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDismissing) then
				return 200
			end
			return if use(badgesVisible) then 0 else 200
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local ghostAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDismissing) or use(flyingOver) then
				return 0
			end
			return if use(ghostLogosVisible) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local solidAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDismissing) or use(flyingOver) then
				return 0
			end
			return if use(solidLogosVisible) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local centerAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isDismissing) then
				return 0
			end
			return if use(centerTextVisible) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local countdownScale = scope:Spring(countdownScaleGoal, POP_SPRING_SPEED, POP_SPRING_DAMPING)

	local lift = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(flyingOver) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local prevCountdown = Fusion.peek(countdown)
	scope:Observer(countdown):onChange(function()
		local current = Fusion.peek(countdown)
		if current ~= prevCountdown then
			prevCountdown = current
			countdownScaleGoal:set(1.15)
			task.defer(function()
				countdownScaleGoal:set(1)
			end)
		end
	end)

	local hiddenGuis: { ScreenGui } = {}
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		for _, gui in playerGui:GetChildren() do
			if gui:IsA("ScreenGui") and gui.Enabled then
				gui.Enabled = false
				table.insert(hiddenGuis, gui)
			end
		end
	end
	table.insert(scope, function()
		for _, gui in hiddenGuis do
			if gui.Parent then
				gui.Enabled = true
			end
		end
	end)

	local shots = LoadingCameras.getShots()
	local openedAt = os.clock()

	local cutTo: WinCamera.CutTo, fadeOut: WinCamera.FadeOut
	cutTo, fadeOut = WinCamera.start(scope, function()
		backgroundVisible:set(true)
		task.wait(REVEAL_STAGGER)
		badgesVisible:set(true)
		task.wait(REVEAL_STAGGER)
		ghostLogosVisible:set(true)
		task.wait(REVEAL_STAGGER)
		solidLogosVisible:set(true)
		task.wait(REVEAL_STAGGER)
		centerTextVisible:set(true)

		if #shots == 0 then
			return
		end
		Random.new():Shuffle(shots)
		local shotTime = FLYOVER_TIME / #FLYOVER_MOVES
		task.wait(math.max(0, INTRO_TIME - (os.clock() - openedAt)))
		for index, move in FLYOVER_MOVES do
			local shotStarted = os.clock()
			local shot = shots[(index - 1) % #shots + 1]
			cutTo(shot * move[1], shot * move[2], shotTime, function()
				flyingOver:set(true)
			end)
			task.wait(math.max(0, shotTime - (os.clock() - shotStarted)))
		end
	end)

	local function dismiss()
		if Fusion.peek(isDismissing) then
			return
		end
		isDismissing:set(true)
		fadeOut()
		task.delay(FADE_OUT_TIME, function()
			blur:Destroy()
			onDismissed()
		end)
	end

	table.insert(scope, function()
		if blur and blur.Parent then
			blur:Destroy()
		end
	end)

	local totalPlayersText = "TOTAL PLAYERS // " .. tostring(totalCount)
	local infoRowText = gameTypeTag .. " " .. string.upper(mapName) .. "  ·  " .. dateStr .. "  ·  " .. region

	return scope:New("ScreenGui")({
		Name = "StartScreen",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 95,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Background",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
					return 1 - use(backgroundAlpha)
				end),
				BorderSizePixel = 0,
				ZIndex = 1,

				[Fusion.Children] = {
					scope:New("ImageLabel")({
						Name = "Topo",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = TOPO_PATTERN,
						ImageColor3 = TOPO_COLOR,
						ImageTransparency = scope:Computed(function(use: FusionUseFn)
							return 0.85 + use(backgroundLayerFade) * 0.35
						end),
						ScaleType = Enum.ScaleType.Tile,
						TileSize = UDim2.fromOffset(1024, 1024),
					}),

					scope:New("Frame")({
						Name = "Vignette",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Color3.fromRGB(8, 8, 10),
						BackgroundTransparency = backgroundLayerFade,
						BorderSizePixel = 0,

						[Fusion.Children] = {
							scope:New("UIGradient")({
								Rotation = 90,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0.7),
									NumberSequenceKeypoint.new(0.45, 0.55),
									NumberSequenceKeypoint.new(1, 0.08),
								}),
							}),
						},
					}),

					scope:New("Frame")({
						Name = "DefenderGlow",
						Size = UDim2.fromScale(0.5, 1),
						BackgroundColor3 = DEFENDER_GLOW_COLOR,
						BackgroundTransparency = backgroundLayerFade,
						BorderSizePixel = 0,

						[Fusion.Children] = {
							scope:New("UIGradient")({
								Rotation = 0,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0.78),
									NumberSequenceKeypoint.new(1, 1),
								}),
							}),
						},
					}),

					scope:New("Frame")({
						Name = "HostileGlow",
						Size = UDim2.fromScale(0.5, 1),
						Position = UDim2.fromScale(0.5, 0),
						BackgroundColor3 = HOSTILE_GLOW_COLOR,
						BackgroundTransparency = backgroundLayerFade,
						BorderSizePixel = 0,

						[Fusion.Children] = {
							scope:New("UIGradient")({
								Rotation = 180,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0.78),
									NumberSequenceKeypoint.new(1, 1),
								}),
							}),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "Content",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 2,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "TotalPlayers",
						Size = UDim2.new(1, 0, 0, 24),
						Position = UDim2.new(0.5, 0, 0, 40),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Text = totalPlayersText,
						TextColor3 = Theme.Colors.White,
						TextTransparency = scope:Computed(function(use: FusionUseFn)
							return 0.15 + (1 - use(centerAlpha)) * 0.85
						end),
						TextSize = 13,
						Font = Theme.Text.Bold,
					}),

					scope:New("Frame")({
						Name = "HostileBadgeWrapper",
						Size = UDim2.fromOffset(BADGE_WIDTH, BADGE_HEIGHT),
						Position = scope:Computed(function(use: FusionUseFn)
							local lifted = use(lift)
							return UDim2.new(
								LOGO_X_HOSTILE,
								-BADGE_WIDTH / 2 + use(hostileBadgeX),
								0.5 * (1 - lifted),
								(LOGO_Y_OFFSET - SOLID_LOGO_SIZE / 2 - BADGE_ABOVE_LOGO - BADGE_HEIGHT) * (1 - lifted) + TOP_BADGE_Y * lifted
							)
						end),
						BackgroundTransparency = 1,
						ZIndex = 4,

						[Fusion.Children] = {
							TeamBadge(scope, "Hostiles", hostileCount, HOSTILE_COLOR, badgeAlpha),
						},
					}),

					scope:New("Frame")({
						Name = "DefenderBadgeWrapper",
						Size = UDim2.fromOffset(BADGE_WIDTH, BADGE_HEIGHT),
						Position = scope:Computed(function(use: FusionUseFn)
							local lifted = use(lift)
							return UDim2.new(
								LOGO_X_DEFENDER,
								-BADGE_WIDTH / 2 + use(defenderBadgeX),
								0.5 * (1 - lifted),
								(LOGO_Y_OFFSET - SOLID_LOGO_SIZE / 2 - BADGE_ABOVE_LOGO - BADGE_HEIGHT) * (1 - lifted) + TOP_BADGE_Y * lifted
							)
						end),
						BackgroundTransparency = 1,
						ZIndex = 4,

						[Fusion.Children] = {
							TeamBadge(scope, "Vultarians", defenderCount, DEFENDER_COLOR, badgeAlpha),
						},
					}),

					scope:New("ImageLabel")({
						Name = "HostileGhostLogo",
						Size = UDim2.fromOffset(GHOST_LOGO_SIZE, GHOST_LOGO_SIZE),
						Position = UDim2.new(LOGO_X_HOSTILE, 0, 0.5, LOGO_Y_OFFSET),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = HOSTILES_ICON,
						ImageColor3 = HOSTILE_COLOR,
						ImageTransparency = scope:Computed(function(use: FusionUseFn)
							return GHOST_TRANSPARENCY + (1 - use(ghostAlpha)) * (1 - GHOST_TRANSPARENCY)
						end),
						ScaleType = Enum.ScaleType.Fit,
						ZIndex = 2,
					}),

					scope:New("ImageLabel")({
						Name = "HostileSolidLogo",
						Size = UDim2.fromOffset(SOLID_LOGO_SIZE, SOLID_LOGO_SIZE),
						Position = UDim2.new(LOGO_X_HOSTILE, 0, 0.5, LOGO_Y_OFFSET),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = HOSTILES_ICON,
						ImageColor3 = HOSTILE_COLOR,
						ImageTransparency = scope:Computed(function(use: FusionUseFn)
							return 1 - use(solidAlpha)
						end),
						ScaleType = Enum.ScaleType.Fit,
						ZIndex = 3,
					}),

					scope:New("ImageLabel")({
						Name = "DefenderGhostLogo",
						Size = UDim2.fromOffset(GHOST_LOGO_SIZE, GHOST_LOGO_SIZE),
						Position = UDim2.new(LOGO_X_DEFENDER, 0, 0.5, LOGO_Y_OFFSET),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = VULTAR_ICON,
						ImageColor3 = DEFENDER_COLOR,
						ImageTransparency = scope:Computed(function(use: FusionUseFn)
							return GHOST_TRANSPARENCY + (1 - use(ghostAlpha)) * (1 - GHOST_TRANSPARENCY)
						end),
						ScaleType = Enum.ScaleType.Fit,
						ZIndex = 2,
					}),

					scope:New("ImageLabel")({
						Name = "DefenderSolidLogo",
						Size = UDim2.fromOffset(SOLID_LOGO_SIZE, SOLID_LOGO_SIZE),
						Position = UDim2.new(LOGO_X_DEFENDER, 0, 0.5, LOGO_Y_OFFSET),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = VULTAR_ICON,
						ImageColor3 = DEFENDER_COLOR,
						ImageTransparency = scope:Computed(function(use: FusionUseFn)
							return 1 - use(solidAlpha)
						end),
						ScaleType = Enum.ScaleType.Fit,
						ZIndex = 3,
					}),

					scope:New("Frame")({
						Name = "CenterContent",
						Size = UDim2.fromOffset(500, 280),
						Position = scope:Computed(function(use: FusionUseFn)
							local lifted = use(lift)
							return UDim2.new(0.5, 0, 0.5 * (1 - lifted), -10 * (1 - lifted) + TOP_CENTER_Y * lifted)
						end),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						ZIndex = 5,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 4),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							scope:New("Frame")({
								Name = "InfoRowWrapper",
								Size = UDim2.new(1, 0, 0, 18),
								BackgroundTransparency = 1,
								LayoutOrder = 1,

								[Fusion.Children] = {
									scope:New("Frame")({
										Name = "LeftLine",
										Size = UDim2.fromOffset(40, 1),
										Position = UDim2.new(0.5, -200, 0.5, 0),
										AnchorPoint = Vector2.new(1, 0.5),
										BackgroundColor3 = DIVIDER_COLOR,
										BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
											return 0.3 + (1 - use(centerAlpha)) * 0.7
										end),
										BorderSizePixel = 0,
									}),

									scope:New("TextLabel")({
										Name = "InfoText",
										Size = UDim2.new(0, 380, 1, 0),
										Position = UDim2.fromScale(0.5, 0.5),
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Text = infoRowText,
										TextColor3 = Theme.Colors.White,
										TextTransparency = scope:Computed(function(use: FusionUseFn)
											return 0.2 + (1 - use(centerAlpha)) * 0.8
										end),
										TextSize = 12,
										Font = Theme.Text.Bold,
									}),

									scope:New("Frame")({
										Name = "RightLine",
										Size = UDim2.fromOffset(40, 1),
										Position = UDim2.new(0.5, 200, 0.5, 0),
										AnchorPoint = Vector2.new(0, 0.5),
										BackgroundColor3 = DIVIDER_COLOR,
										BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
											return 0.3 + (1 - use(centerAlpha)) * 0.7
										end),
										BorderSizePixel = 0,
									}),
								},
							}),

							scope:New("TextLabel")({
								Name = "MatchStarting",
								Size = scope:Computed(function(use: FusionUseFn)
									return UDim2.new(1, 0, 0, 56 * (1 - use(lift)))
								end),
								BackgroundTransparency = 1,
								Text = "MATCH STARTING",
								TextColor3 = Theme.Colors.White,
								TextTransparency = scope:Computed(function(use: FusionUseFn)
									return 1 - use(centerAlpha) * (1 - use(lift))
								end),
								TextSize = 52,
								Font = Theme.Text.Black,
								LayoutOrder = 2,
							}),

							scope:New("Frame")({
								Name = "CountdownWrapper",
								Size = UDim2.fromOffset(120, 50),
								BackgroundTransparency = 1,
								LayoutOrder = 3,

								[Fusion.Children] = {
									scope:New("UIScale")({
										Scale = scope:Computed(function(use: FusionUseFn)
											return use(countdownScale) * (1 - 0.4 * use(lift))
										end),
									}),

									scope:New("TextLabel")({
										Name = "CountdownNumber",
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = scope:Computed(function(use: FusionUseFn)
											local num = use(countdown)
											if num <= 0 then
												return "STARTING"
											end
											return "IN " .. tostring(num)
										end),
										TextColor3 = scope:Computed(function(use: FusionUseFn)
											if use(countdown) <= 0 then
												return STARTING_COLOR
											end
											return Theme.Colors.White
										end),
										TextTransparency = scope:Computed(function(use: FusionUseFn)
											return 1 - use(centerAlpha)
										end),
										TextSize = 42,
										Font = Theme.Text.Black,
									}),
								},
							}),

							scope:New("TextLabel")({
								Name = "PointsTarget",
								Size = UDim2.new(1, 0, 0, 18),
								BackgroundTransparency = 1,
								Text = scope:Computed(function(use: FusionUseFn)
									return "TO " .. tostring(use(maxPoints))
								end),
								TextColor3 = Theme.Colors.White,
								TextTransparency = scope:Computed(function(use: FusionUseFn)
									return 0.1 + (1 - use(centerAlpha)) * 0.9
								end),
								TextSize = 13,
								Font = Theme.Text.Bold,
								LayoutOrder = 4,
								Visible = not isPhaseMode,
							}),
						},
					}),

					scope:New("TextLabel")({
						Name = "GameId",
						Size = UDim2.fromOffset(300, 20),
						Position = UDim2.new(0.5, 0, 1, -30),
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						Text = "[ " .. string.upper(mode) .. " // " .. gameId .. " ]",
						TextColor3 = VERY_MUTED_COLOR,
						TextTransparency = scope:Computed(function(use: FusionUseFn)
							return 0.3 + (1 - use(centerAlpha)) * 0.7
						end),
						TextSize = 11,
						Font = Theme.Text.Semibold,
						ZIndex = 3,
					}),
				},
			}),
		},
	}),
		dismiss
end

return StartScreen
