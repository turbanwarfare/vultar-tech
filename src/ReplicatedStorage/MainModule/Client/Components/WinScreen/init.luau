--!native
--!optimize 2

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)
local Network = require(MainModule.Shared.Network)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local BlurEffect = require(MainModule.Client.Utils.UI.BlurEffect)
local TeamPanel = require(script.TeamPanel)
local PostGameLeaderboard = require(script.PostGameLeaderboard)
local BackgroundMotes = require(script.BackgroundMotes)
local Maps = require(MainModule.Shared.Config.Maps)
local CreditsTracker = require(script.CreditsTracker)
local CreditsModal = require(script.CreditsModal)
local WinCamera = require(script.WinCamera)

local SOUND_VICTORY = "rbxassetid://112637915387187"
local SOUND_LOSS = "rbxassetid://102764785026253"
local MUSIC_VOLUME = 0.5
local MUSIC_FADE_DURATION = 1.0
local MUSIC_FADE_TWEEN_INFO = TweenInfo.new(MUSIC_FADE_DURATION)
local LEADING_ZERO_COLOR = Color3.fromRGB(80, 80, 80)

local CLOSE_STROKE_COLOR = Color3.fromRGB(180, 50, 50)
local CLOSE_TEXT_COLOR = Color3.fromRGB(255, 140, 140)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type WinScreenProps = {
	VictoryData: Network.VictoryData,
	PlayerFaction: "Defenders" | "Raiders" | "Neutral",
	GameId: string,
	DefendersData: PostGameLeaderboard.FactionData,
	RaidersData: PostGameLeaderboard.FactionData,
	OnComplete: () -> (),
}

local VULTAR_ICON = "rbxassetid://98751546690059"
local HOSTILES_ICON = "rbxassetid://0"
local TOPO_PATTERN = "rbxassetid://0"

local BACKGROUND_ALPHA = 0.25
local DEFENDER_GLOW_COLOR = Color3.fromRGB(200, 55, 60)
local HOSTILE_GLOW_COLOR = Color3.fromRGB(60, 115, 210)
local META_TEXT_COLOR = Color3.fromRGB(180, 180, 190)
local META_SEPARATOR_COLOR = Color3.fromRGB(149, 149, 149)

local DEFENDER_COLOR_BRIGHT = Color3.fromRGB(220, 80, 80)
local HOSTILE_COLOR_BRIGHT = Color3.fromRGB(80, 145, 235)

local CORNER_RADIUS = 6
local SMALL_CORNER = 4
local SHADOW_SPREAD = 4
local SHADOW_OFFSET_Y = 2
local SHADOW_TRANSPARENCY = 0.7

local AVATAR_WIDTH = 260
local AVATAR_HEIGHT = 320
local AVATAR_WIDTH_CENTER = 300
local AVATAR_HEIGHT_CENTER = 370
local LABEL_CARD_HEIGHT = 38
local STAT_CARD_HEIGHT = 48
local LABEL_CARD_HEIGHT_CENTER = 44
local STAT_CARD_HEIGHT_CENTER = 54
local CARD_SPACING = 12
local MVP_COLUMN_GAP = 40

local PANEL_SPACING = 280

local INTRO_DELAY = 0.15
local PANELS_SLIDE_DELAY = 0.4
local SCORE_START_DELAY = 0.5
local WINNER_REVEAL_DELAY = 1.5
local SCORE_HOLD_TIME = 3.0

local HEADER_APPEAR_DELAY = 0.5
local MVP_POP_DELAY = 0.6

local LEADERBOARD_APPEAR_DELAY = 0.6
local FINAL_FADE_TIME = 1.2

local FORCE_CLOSE_TIMEOUT = 60

local SPRING_SPEED = 20
local SPRING_DAMPING = 1

local NEVER_RESTORE_GUIS: { [string]: boolean } = {
	["DeathScreen"] = true,
	["VDIKillReport"] = true,
	["HurtScreen"] = true,
	["LoadingScreen"] = true,
	["StartScreen"] = true,
	["WinScreen"] = true,
	["MataroWinScreen"] = true,
}

local function createBlur(): BlurEffect
	return BlurEffect.getOrCreate("WinScreenBlur", 0)
end

local function disableBackgroundGuis(): { ScreenGui }
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return {}
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return {}
	end

	local disabled: { ScreenGui } = {}
	for _, child in playerGui:GetChildren() do
		if child:IsA("ScreenGui") and child.Name ~= "WinScreen" and child.Enabled then
			child.Enabled = false
			if not NEVER_RESTORE_GUIS[child.Name] then
				table.insert(disabled, child)
			end
		end
	end
	return disabled
end

local function restoreBackgroundGuis(disabled: { ScreenGui }): ()
	for _, gui in disabled do
		if gui and gui.Parent and not NEVER_RESTORE_GUIS[gui.Name] then
			gui.Enabled = true
		end
	end
end

local function ScoreDisplay(
	scope: FusionScope,
	score: number,
	accentColor: Color3,
	isWinner: boolean,
	alpha: any,
	size: UDim2,
	alignment: Enum.TextXAlignment
): Frame
	local scoreStr = string.format("%04d", math.clamp(score, 0, 9999))
	local firstNonZero = 5
	for i = 1, 4 do
		if string.sub(scoreStr, i, i) ~= "0" then
			firstNonZero = i
			break
		end
	end

	local digits = {}

	for i = 1, 4 do
		local digit = string.sub(scoreStr, i, i)
		local isLeadingZero = i < firstNonZero
		local digitColor = if isLeadingZero then LEADING_ZERO_COLOR else (if isWinner then accentColor else Theme.Colors.White)

		table.insert(
			digits,
			scope:New("TextLabel")({
				Name = "Digit" .. i,
				Size = UDim2.fromScale(0.25, 1),
				BackgroundTransparency = 1,
				Text = digit,
				TextColor3 = digitColor,
				TextTransparency = scope:Computed(function(use: FusionUseFn)
					return 1 - use(alpha)
				end),
				TextScaled = true,
				Font = Theme.Text.Black,
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = i,
			})
		)
	end

	local horizontalAlign = Enum.HorizontalAlignment.Left
	if alignment == Enum.TextXAlignment.Right then
		horizontalAlign = Enum.HorizontalAlignment.Right
	elseif alignment == Enum.TextXAlignment.Center then
		horizontalAlign = Enum.HorizontalAlignment.Center
	end

	return scope:New("Frame")({
		Name = "ScoreDisplay",
		Size = size,
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("UIAspectRatioConstraint")({
				AspectRatio = 2.4,
			}),

			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = horizontalAlign,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 0),
			}),

			digits,
		},
	})
end

local function loadAvatarModel(userId: number): Model?
	if userId <= 0 then
		return nil
	end

	local success, model = pcall(function()
		local description = Players:GetHumanoidDescriptionFromUserId(userId)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)

	if success and model then
		model.Name = "AvatarPreview"

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end

		local scriptToRemove = model:FindFirstChildWhichIsA("BaseScript", true)
		while scriptToRemove do
			scriptToRemove:Destroy()
			scriptToRemove = model:FindFirstChildWhichIsA("BaseScript", true)
		end

		return model
	end

	return nil
end

local function MVPColumn(scope: FusionScope, labelText: string, statSuffix: string, player: Network.TopPlayer?, visible: any, isCenter: boolean): Frame
	local avatarW = if isCenter then AVATAR_WIDTH_CENTER else AVATAR_WIDTH
	local avatarH = if isCenter then AVATAR_HEIGHT_CENTER else AVATAR_HEIGHT
	local labelH = if isCenter then LABEL_CARD_HEIGHT_CENTER else LABEL_CARD_HEIGHT
	local statH = if isCenter then STAT_CARD_HEIGHT_CENTER else STAT_CARD_HEIGHT
	local usernameSize = if isCenter then 30 else 24
	local labelSize = if isCenter then 16 else 13
	local statSize = if isCenter then 24 else 18

	local columnAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(visible) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local columnScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(visible) then 1 else 0.88
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local userId = player and player.UserId or 0
	local displayName = player and player.DisplayName or "---"
	local value = player and player.Value or 0

	local viewportFrame: ViewportFrame? = nil
	local worldModel: WorldModel? = nil
	local avatarModel: Model? = nil
	local camera: Camera? = nil

	local function setupViewport()
		if not viewportFrame then
			return
		end

		viewportFrame.Ambient = Color3.fromRGB(140, 145, 155)
		viewportFrame.LightColor = Color3.fromRGB(255, 255, 255)
		viewportFrame.LightDirection = Vector3.new(-0.4, -0.7, -0.4).Unit

		worldModel = Instance.new("WorldModel")

		camera = Instance.new("Camera")
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 45
		viewportFrame.CurrentCamera = camera
		camera.Parent = viewportFrame
		worldModel.Parent = viewportFrame

		if userId > 0 then
			task.spawn(function()
				local model = loadAvatarModel(userId)
				if model and worldModel then
					avatarModel = model
					model.Parent = worldModel

					local rootPart = model:FindFirstChild("Torso") :: BasePart?
					if not rootPart then
						rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?
					end
					if rootPart then
						local currentPivot = model:GetPivot()
						model:PivotTo(currentPivot * CFrame.Angles(0, math.rad(180), 0))

						local npcPosition = rootPart.Position
						local cameraDistance = if isCenter then 6.0 else 6.5
						local cameraHeight = if isCenter then 0.6 else 0.8
						local angleRad = math.rad(200)

						local cameraOffset = Vector3.new(math.sin(angleRad) * cameraDistance, cameraHeight, math.cos(angleRad) * cameraDistance)
						local cameraPosition = npcPosition + cameraOffset
						local lookAt = npcPosition + Vector3.new(0, 0.2, 0)

						if camera then
							camera.CFrame = CFrame.new(cameraPosition, lookAt)
						end
					end
				end
			end)
		end
	end

	local function cleanup()
		if avatarModel then
			avatarModel:Destroy()
			avatarModel = nil
		end
		if worldModel then
			worldModel:Destroy()
			worldModel = nil
		end
		camera = nil
		viewportFrame = nil
	end

	table.insert(scope, cleanup)

	local totalHeight = labelH + CARD_SPACING + avatarH + CARD_SPACING + statH + 54

	local container = scope:New("Frame")({
		Name = labelText,
		Size = UDim2.fromOffset(avatarW, totalHeight),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("UIScale")({
				Scale = columnScale,
			}),

			scope:New("TextLabel")({
				Name = "Username",
				Size = UDim2.new(1, 0, 0, 44),
				Position = UDim2.fromScale(0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Text = string.upper(displayName),
				TextColor3 = Theme.Colors.White,
				TextTransparency = scope:Computed(function(use: FusionUseFn)
					return 1 - use(columnAlpha)
				end),
				TextSize = usernameSize,
				Font = Theme.Text.Black,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 10,
			}),

			scope:New("Frame")({
				Name = "LabelCardWrapper",
				Size = UDim2.fromOffset(avatarW, labelH),
				Position = UDim2.new(0.5, 0, 0, 52),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					Shadow(scope, {
						Size = UDim2.new(1, SHADOW_SPREAD * 2, 1, SHADOW_SPREAD * 2),
						Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Spread = SHADOW_SPREAD,
						Transparency = scope:Computed(function(use: FusionUseFn)
							return SHADOW_TRANSPARENCY + (1 - use(columnAlpha)) * (1 - SHADOW_TRANSPARENCY)
						end),
						ZIndex = 0,
					}),

					scope:New("Frame")({
						Name = "LabelCard",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Theme.Chat.Window.Background,
						BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
							return 0.4 + (1 - use(columnAlpha)) * 0.6
						end),
						ZIndex = 1,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, SMALL_CORNER) }),
							scope:New("UIStroke")({
								Color = Theme.Chat.Window.Border,
								Thickness = 1,
								Transparency = scope:Computed(function(use: FusionUseFn)
									return 0.3 + (1 - use(columnAlpha)) * 0.7
								end),
							}),

							scope:New("TextLabel")({
								Name = "Label",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = labelText,
								TextColor3 = Theme.Colors.White,
								TextTransparency = scope:Computed(function(use: FusionUseFn)
									return 0.1 + (1 - use(columnAlpha)) * 0.9
								end),
								TextSize = labelSize,
								Font = Theme.Text.Bold,
								ZIndex = 2,
							}),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "AvatarCardWrapper",
				Size = UDim2.fromOffset(avatarW, avatarH),
				Position = UDim2.new(0.5, 0, 0, 52 + labelH + CARD_SPACING),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					Shadow(scope, {
						Size = UDim2.new(1, SHADOW_SPREAD * 2 + 6, 1, SHADOW_SPREAD * 2 + 6),
						Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y + 3),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Spread = SHADOW_SPREAD + 3,
						Transparency = scope:Computed(function(use: FusionUseFn)
							return (SHADOW_TRANSPARENCY - 0.15) + (1 - use(columnAlpha)) * (1 - SHADOW_TRANSPARENCY + 0.15)
						end),
						ZIndex = 0,
					}),

					scope:New("Frame")({
						Name = "AvatarCard",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Theme.Chat.Window.Background,
						BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
							return 0.35 + (1 - use(columnAlpha)) * 0.65
						end),
						ClipsDescendants = true,
						ZIndex = 1,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER_RADIUS) }),
							scope:New("UIStroke")({
								Color = Theme.Chat.Window.Border,
								Thickness = 1,
								Transparency = scope:Computed(function(use: FusionUseFn)
									return 0.25 + (1 - use(columnAlpha)) * 0.75
								end),
							}),

							scope:New("Frame")({
								Name = "ViewportContainer",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								ZIndex = 2,
								Visible = scope:Computed(function(use: FusionUseFn)
									return use(columnAlpha) > 0.05
								end),
							}),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "StatCardWrapper",
				Size = UDim2.fromOffset(avatarW, statH),
				Position = UDim2.new(0.5, 0, 0, 52 + labelH + CARD_SPACING + avatarH + CARD_SPACING),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					Shadow(scope, {
						Size = UDim2.new(1, SHADOW_SPREAD * 2, 1, SHADOW_SPREAD * 2),
						Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Spread = SHADOW_SPREAD,
						Transparency = scope:Computed(function(use: FusionUseFn)
							return SHADOW_TRANSPARENCY + (1 - use(columnAlpha)) * (1 - SHADOW_TRANSPARENCY)
						end),
						ZIndex = 0,
					}),

					scope:New("Frame")({
						Name = "StatCard",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Theme.Chat.Window.Background,
						BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
							return 0.4 + (1 - use(columnAlpha)) * 0.6
						end),
						ZIndex = 1,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, SMALL_CORNER) }),
							scope:New("UIStroke")({
								Color = Theme.Chat.Window.Border,
								Thickness = 1,
								Transparency = scope:Computed(function(use: FusionUseFn)
									return 0.3 + (1 - use(columnAlpha)) * 0.7
								end),
							}),

							scope:New("TextLabel")({
								Name = "StatValue",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = `{value} {statSuffix}`,
								TextColor3 = Theme.Colors.White,
								TextTransparency = scope:Computed(function(use: FusionUseFn)
									return 1 - use(columnAlpha)
								end),
								TextSize = statSize,
								Font = Theme.Text.Black,
								ZIndex = 2,
							}),
						},
					}),
				},
			}),
		},
	})

	task.defer(function()
		local avatarCardWrapper = container:FindFirstChild("AvatarCardWrapper")
		if avatarCardWrapper then
			local avatarCard = avatarCardWrapper:FindFirstChild("AvatarCard")
			if avatarCard then
				local viewportContainer = avatarCard:FindFirstChild("ViewportContainer")
				if viewportContainer then
					viewportFrame = Instance.new("ViewportFrame")
					viewportFrame.Name = "AvatarViewport"
					viewportFrame.Size = UDim2.fromScale(1, 1)
					viewportFrame.BackgroundTransparency = 1
					viewportFrame.ZIndex = 3
					viewportFrame.Parent = viewportContainer
					setupViewport()
				end
			end
		end
	end)

	return container
end

local function MVPScreen(
	scope: FusionScope,
	myTeamTopPlayers: any,
	visible: any,
	killsVisible: any,
	damageVisible: any,
	healsVisible: any,
	onBack: () -> ()
): Frame
	local columnHeightSide = LABEL_CARD_HEIGHT + CARD_SPACING + AVATAR_HEIGHT + CARD_SPACING + STAT_CARD_HEIGHT + 54
	local columnHeightCenter = LABEL_CARD_HEIGHT_CENTER + CARD_SPACING + AVATAR_HEIGHT_CENTER + CARD_SPACING + STAT_CARD_HEIGHT_CENTER + 54
	local maxColumnHeight = math.max(columnHeightSide, columnHeightCenter)
	local totalWidth = AVATAR_WIDTH + MVP_COLUMN_GAP + AVATAR_WIDTH_CENTER + MVP_COLUMN_GAP + AVATAR_WIDTH

	local mvpContainerAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(visible) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local backAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			local a = use(mvpContainerAlpha)
			local isVis = use(visible)
			return if isVis and a > 0.85 then 1 else 0
		end),
		12,
		1
	)

	return scope:New("Frame")({
		Name = "MVPScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Visible = scope:Computed(function(use: FusionUseFn)
			return use(mvpContainerAlpha) > 0.01
		end),

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "MVPContainer",
				Size = UDim2.fromScale(1, 0.85),
				Position = UDim2.fromScale(0.5, 0.09),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				ZIndex = 3,

				[Fusion.Children] = {
					scope:New("UIScale")({
						Scale = scope:Computed(function(use: FusionUseFn)
							return 0.97 + use(mvpContainerAlpha) * 0.03
						end),
					}),

					scope:New("Frame")({
						Name = "ContentStack",
						Size = UDim2.fromOffset(totalWidth, maxColumnHeight + 44 + 32),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 32),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							scope:New("Frame")({
								Name = "MVPRow",
								Size = UDim2.fromOffset(totalWidth, maxColumnHeight),
								BackgroundTransparency = 1,
								LayoutOrder = 1,

								[Fusion.Children] = {
									scope:New("Frame")({
										Name = "DamageWrapper",
										Size = UDim2.fromOffset(AVATAR_WIDTH, columnHeightSide),
										Position = UDim2.fromScale(0, 0.5),
										AnchorPoint = Vector2.new(0, 0.5),
										BackgroundTransparency = 1,
										[Fusion.Children] = {
											MVPColumn(scope, "TOP DAMAGE", "DAMAGE", myTeamTopPlayers and myTeamTopPlayers.Damage, damageVisible, false),
										},
									}),

									scope:New("Frame")({
										Name = "KillsWrapper",
										Size = UDim2.fromOffset(AVATAR_WIDTH_CENTER, columnHeightCenter),
										Position = UDim2.fromScale(0.5, 0.5),
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										[Fusion.Children] = {
											MVPColumn(scope, "TOP KILLS", "KILLS", myTeamTopPlayers and myTeamTopPlayers.Kills, killsVisible, true),
										},
									}),

									scope:New("Frame")({
										Name = "HealsWrapper",
										Size = UDim2.fromOffset(AVATAR_WIDTH, columnHeightSide),
										Position = UDim2.fromScale(1, 0.5),
										AnchorPoint = Vector2.new(1, 0.5),
										BackgroundTransparency = 1,
										[Fusion.Children] = {
											MVPColumn(scope, "TOP HEALS", "HEALS", myTeamTopPlayers and myTeamTopPlayers.Heals, healsVisible, false),
										},
									}),
								},
							}),

							scope:New("Frame")({
								Name = "ButtonsRow",
								Size = UDim2.fromOffset(totalWidth, 44),
								BackgroundTransparency = 1,
								LayoutOrder = 2,

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Center,
										VerticalAlignment = Enum.VerticalAlignment.Center,
										Padding = UDim.new(0, 16),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),

									scope:New("TextButton")({
										Name = "ReturnButton",
										Size = UDim2.fromOffset(180, 44),
										BackgroundColor3 = Theme.Chat.Window.Background,
										BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
											return Theme.Chat.Window.BackgroundTransparency
												+ (1 - use(backAlpha)) * (1 - Theme.Chat.Window.BackgroundTransparency)
										end),
										Text = "RETURN",
										TextColor3 = CLOSE_TEXT_COLOR,
										TextTransparency = scope:Computed(function(use: FusionUseFn)
											return 1 - use(backAlpha)
										end),
										TextSize = 14,
										Font = Theme.Text.Bold,
										AutoButtonColor = false,
										LayoutOrder = 1,
										ZIndex = 10,

										[Fusion.OnEvent("Activated")] = function()
											if Fusion.peek(backAlpha) > 0.5 then
												onBack()
											end
										end,

										[Fusion.Children] = {
											scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
											scope:New("UIStroke")({
												Color = CLOSE_STROKE_COLOR,
												Thickness = 1.5,
												ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
												Transparency = scope:Computed(function(use: FusionUseFn)
													local a = use(backAlpha)
													if a < 0.05 then
														return 1
													end
													return 0.2 + (1 - a) * 0.8
												end),
											}),
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

local function WinScreen(scope: FusionScope, props: WinScreenProps): ScreenGui
	local victoryData = props.VictoryData
	local playerFaction = props.PlayerFaction
	local onComplete = props.OnComplete
	local defendersData = props.DefendersData
	local raidersData = props.RaidersData

	local isPlayerDefender = playerFaction == "Defenders"
	local isPlayerRaider = playerFaction == "Raiders"
	local isSpectator = playerFaction == "Neutral"
	local didPlayerWin = (isPlayerDefender and victoryData.WinningTeam == "Defenders") or (isPlayerRaider and victoryData.WinningTeam == "Hostiles")

	local defendersWon = victoryData.WinningTeam == "Defenders"
	local soundId = if defendersWon then SOUND_VICTORY else SOUND_LOSS

	local music = Instance.new("Sound")
	music.Name = "WinScreenMusic"
	music.SoundId = soundId
	music.Volume = MUSIC_VOLUME
	music.Parent = SoundService
	music:Play()

	table.insert(scope, function()
		if music then
			local fadeOut = TweenService:Create(music, MUSIC_FADE_TWEEN_INFO, { Volume = 0 })
			fadeOut:Play()
			fadeOut.Completed:Once(function()
				music:Destroy()
			end)
		end
	end)

	WinCamera.start(scope)

	local teamVictoryText = if defendersWon then "VULTARIAN VICTORY" else "HOSTILE VICTORY"
	local resultText = if didPlayerWin or isSpectator then "VICTORY" else "DEFEAT"
	local gameId = props.GameId

	local myTeamTopPlayers = if isPlayerDefender then victoryData.DefenderTopPlayers else victoryData.HostileTopPlayers

	local defenderScore = victoryData.DefenderScore or 0
	local hostileScore = victoryData.HostileScore or 0

	local backgroundVisible = scope:Value(false)
	local panelsVisible = scope:Value(false)
	local startScoreCounting = scope:Value(false)
	local winnerRevealed = scope:Value(false)
	local victoryTextVisible = scope:Value(false)
	local headerVisible = scope:Value(false)

	local killsVisible = scope:Value(false)
	local damageVisible = scope:Value(false)
	local healsVisible = scope:Value(false)

	local transitionToLeaderboard = scope:Value(false)
	local leaderboardVisible = scope:Value(false)

	local mvpScreenVisible = scope:Value(false)

	local isClosing = scope:Value(false)
	local tabToggledDuringScorePhase = scope:Value(false)

	local currentPhase = scope:Value("loading")

	local compactScoresVisible = scope:Computed(function(use: FusionUseFn)
		return use(tabToggledDuringScorePhase) or use(headerVisible)
	end)

	local blur = createBlur()
	table.insert(scope, function()
		if blur and blur.Parent then
			blur.Size = 0
			blur:Destroy()
		end
		BlurEffect.forceRemove("WinScreenBlur")
	end)

	local disabledBackgroundGuis = disableBackgroundGuis()
	local backgroundGuisRestored = false

	local function restoreBackgroundUIOnce(): ()
		if backgroundGuisRestored then
			return
		end
		backgroundGuisRestored = true
		restoreBackgroundGuis(disabledBackgroundGuis)
	end

	table.insert(scope, restoreBackgroundUIOnce)

	local backgroundAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isClosing) then
				return 0
			end
			return if use(backgroundVisible) then BACKGROUND_ALPHA else 0
		end),
		12,
		1
	)

	local blurSize = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isClosing) then
				return 0
			end
			return if use(backgroundVisible) then 24 else 0
		end),
		12,
		1
	)

	scope:Observer(blurSize):onChange(function()
		blur.Size = Fusion.peek(blurSize)
	end)

	local scorePhaseAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isClosing) or use(transitionToLeaderboard) then
				return 0
			end
			return if use(panelsVisible) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local tabScorePhaseAlpha = scope:Computed(function(use: FusionUseFn)
		return use(scorePhaseAlpha)
	end)

	local victoryTextAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isClosing) then
				return 0
			end
			return if use(victoryTextVisible) or use(tabToggledDuringScorePhase) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local victoryTextY = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(transitionToLeaderboard) then
				return 0.03
			end
			if use(tabToggledDuringScorePhase) then
				return 0.03
			end
			return 0.78
		end),
		14,
		1
	)

	local victoryTextScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(transitionToLeaderboard) then
				return 0.55
			end
			if use(tabToggledDuringScorePhase) then
				return 0.7
			end
			if not use(victoryTextVisible) then
				return 0.9
			end
			return 1
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local victoryTextFinalAlpha = scope:Computed(function(use: FusionUseFn)
		local base = use(victoryTextAlpha)
		if use(transitionToLeaderboard) then
			return base * 0.55
		end
		return base
	end)

	local victoryIcon = if defendersWon then VULTAR_ICON else HOSTILES_ICON

	local headerTransparency = scope:Computed(function(use: FusionUseFn)
		return 1 - use(victoryTextFinalAlpha)
	end)

	local backgroundLayerFade = scope:Computed(function(use: FusionUseFn)
		return math.clamp(1 - use(backgroundAlpha) / BACKGROUND_ALPHA, 0, 1)
	end)

	local matchInfoParts: { string } = {}
	local mapName = Maps.getMapName()
	if mapName then
		table.insert(matchInfoParts, string.upper(mapName))
	end
	table.insert(matchInfoParts, "MATCH " .. gameId)
	table.insert(matchInfoParts, #Players:GetPlayers() .. " PLAYERS")

	local matchInfoChildren: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.018, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i, part in matchInfoParts do
		if i > 1 then
			table.insert(
				matchInfoChildren,
				scope:New("Frame")({
					Name = "Separator" .. (i - 1),
					Size = UDim2.fromScale(0.0022, 0.83),
					BackgroundColor3 = META_SEPARATOR_COLOR,
					BackgroundTransparency = headerTransparency,
					BorderSizePixel = 0,
					LayoutOrder = i * 2 - 1,
				})
			)
		end
		table.insert(
			matchInfoChildren,
			scope:New("TextLabel")({
				Name = "MetaText" .. i,
				Size = UDim2.fromScale(#part * 0.0135, 0.83),
				BackgroundTransparency = 1,
				Text = part,
				TextColor3 = META_TEXT_COLOR,
				TextTransparency = headerTransparency,
				TextScaled = true,
				Font = Theme.Text.Bold,
				LayoutOrder = i * 2,
			})
		)
	end

	local credits = CreditsTracker(scope)
	local creditsModalOpen = scope:Value(false)

	local compactHeaderAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isClosing) then
				return 0
			end
			if use(tabToggledDuringScorePhase) then
				return 1
			end
			return if use(headerVisible) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local gameIdAlpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isClosing) or use(transitionToLeaderboard) or use(tabToggledDuringScorePhase) then
				return 0
			end
			return if use(panelsVisible) then 0.4 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local tabInputConnection: RBXScriptConnection?
	local lastTabPressTime = 0
	local TAB_TOGGLE_COOLDOWN = 0.3

	local function setupTabDetection()
		if tabInputConnection then
			tabInputConnection:Disconnect()
			tabInputConnection = nil
		end

		tabInputConnection = UserInputService.InputBegan:Connect(function(input: InputObject, _: boolean)
			if input.KeyCode ~= Enum.KeyCode.Tab then
				return
			end
			local phase = Fusion.peek(currentPhase)
			if phase ~= "scorePhase" then
				return
			end
			if Fusion.peek(transitionToLeaderboard) then
				return
			end

			local currentTime = os.clock()
			if currentTime - lastTabPressTime < TAB_TOGGLE_COOLDOWN then
				return
			end
			lastTabPressTime = currentTime

			local leaderboardService = ServiceLocator.Leaderboard()
			if leaderboardService and leaderboardService.IsVisible then
				tabToggledDuringScorePhase:set(not leaderboardService:IsVisible())
			end
		end)
	end

	table.insert(scope, function()
		if tabInputConnection then
			tabInputConnection:Disconnect()
			tabInputConnection = nil
		end

		local leaderboardService = ServiceLocator.Leaderboard()
		if leaderboardService and leaderboardService.SetBlocked then
			leaderboardService:SetBlocked(false)
		end
	end)

	local mvpStaggerStarted = false

	local function openMVPScreen()
		if Fusion.peek(mvpScreenVisible) then
			return
		end
		mvpScreenVisible:set(true)
		currentPhase:set("mvpPhase")

		if not mvpStaggerStarted then
			mvpStaggerStarted = true
			task.spawn(function()
				task.wait(HEADER_APPEAR_DELAY)
				killsVisible:set(true)
				task.wait(MVP_POP_DELAY)
				damageVisible:set(true)
				task.wait(MVP_POP_DELAY)
				healsVisible:set(true)
			end)
		end
	end

	local function closeMVPScreen()
		killsVisible:set(false)
		damageVisible:set(false)
		healsVisible:set(false)
		mvpStaggerStarted = false
		mvpScreenVisible:set(false)
		currentPhase:set("leaderboardPhase")
	end

	task.spawn(function()
		task.wait(INTRO_DELAY)
		backgroundVisible:set(true)
		task.wait(PANELS_SLIDE_DELAY)
		panelsVisible:set(true)
		currentPhase:set("scorePhase")

		setupTabDetection()

		task.wait(SCORE_START_DELAY - PANELS_SLIDE_DELAY)
		startScoreCounting:set(true)
		task.wait(WINNER_REVEAL_DELAY - SCORE_START_DELAY)
		winnerRevealed:set(true)
		task.wait(0.3)

		if not Fusion.peek(tabToggledDuringScorePhase) then
			victoryTextVisible:set(true)
		end

		task.wait(SCORE_HOLD_TIME - WINNER_REVEAL_DELAY - 0.3)

		if tabInputConnection then
			tabInputConnection:Disconnect()
			tabInputConnection = nil
		end

		local leaderboardService = ServiceLocator.Leaderboard()
		if leaderboardService and leaderboardService.SetBlocked then
			leaderboardService:SetBlocked(true)
		end

		victoryTextVisible:set(true)
		transitionToLeaderboard:set(true)
		currentPhase:set("leaderboardPhase")
		task.wait(LEADERBOARD_APPEAR_DELAY)
		headerVisible:set(true)
		leaderboardVisible:set(true)
	end)

	local function closeScreen()
		if Fusion.peek(isClosing) then
			return
		end
		isClosing:set(true)
		currentPhase:set("closing")

		blur.Size = 0
		BlurEffect.forceRemove("WinScreenBlur")

		if tabInputConnection then
			tabInputConnection:Disconnect()
			tabInputConnection = nil
		end

		leaderboardVisible:set(false)
		mvpScreenVisible:set(false)

		local leaderboardService = ServiceLocator.Leaderboard()
		if leaderboardService and leaderboardService.SetBlocked then
			leaderboardService:SetBlocked(false)
		end

		restoreBackgroundUIOnce()

		task.delay(FINAL_FADE_TIME, function()
			BlurEffect.forceRemove("WinScreenBlur")
			if onComplete then
				onComplete()
			end
		end)
	end

	local forceCloseTimer = task.delay(FORCE_CLOSE_TIMEOUT, closeScreen)
	table.insert(scope, function()
		task.cancel(forceCloseTimer)
	end)

	local leaderboardBodyVisible = scope:Computed(function(use: FusionUseFn)
		return use(leaderboardVisible) and not use(mvpScreenVisible)
	end)

	local compactScoresActuallyVisible = scope:Computed(function(use: FusionUseFn)
		return use(compactScoresVisible)
	end)

	return scope:New("ScreenGui")({
		Name = "WinScreen",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Background",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(8, 8, 10),
				BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
					return 1 - use(backgroundAlpha)
				end),
				Visible = scope:Computed(function(use: FusionUseFn)
					return use(backgroundAlpha) > 0.001
				end),
				BorderSizePixel = 0,
				ZIndex = 1,

				[Fusion.Children] = {
					scope:New("ImageLabel")({
						Name = "Topo",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = TOPO_PATTERN,
						ImageColor3 = if defendersWon then DEFENDER_GLOW_COLOR else HOSTILE_GLOW_COLOR,
						ImageTransparency = scope:Computed(function(use: FusionUseFn)
							return 0.65 + use(backgroundLayerFade) * 0.15
						end),
						ScaleType = Enum.ScaleType.Tile,
						TileSize = UDim2.fromOffset(1024, 1024),
						Visible = if defendersWon then false else true,
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
						Name = "TeamGlow",
						Size = UDim2.new(1, 0, 0, 560),
						BackgroundColor3 = if defendersWon then DEFENDER_GLOW_COLOR else HOSTILE_GLOW_COLOR,
						BackgroundTransparency = backgroundLayerFade,
						BorderSizePixel = 0,

						[Fusion.Children] = {
							scope:New("UIGradient")({
								Rotation = 90,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0.78),
									NumberSequenceKeypoint.new(1, 1),
								}),
							}),
						},
					}),
					if defendersWon then BackgroundMotes(scope, { Fade = backgroundLayerFade }) else nil,
				},
			}),

			scope:New("Frame")({
				Name = "ScorePhaseContent",
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 2,
				Visible = scope:Computed(function(use: FusionUseFn)
					return use(tabScorePhaseAlpha) > 0.01
				end),

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "TeamsContainer",
						Size = UDim2.fromOffset(720, 480),
						Position = UDim2.fromScale(0.5, 0.45),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("Frame")({
								Name = "DefenderPanelWrapper",
								Size = UDim2.new(0.5, -PANEL_SPACING / 2, 1, 0),
								Position = UDim2.fromScale(0, 0.5),
								AnchorPoint = Vector2.new(0, 0.5),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									TeamPanel(scope, {
										TeamName = "Vultarians",
										TeamIcon = VULTAR_ICON,
										TeamColorBright = DEFENDER_COLOR_BRIGHT,
										Score = defenderScore,
										IsWinner = defendersWon,
										Visible = panelsVisible,
										StartScoreCounting = startScoreCounting,
										WinnerRevealed = winnerRevealed,
										SlideDirection = -1,
										FadeOut = scope:Computed(function(use: FusionUseFn)
											return use(transitionToLeaderboard) or use(tabToggledDuringScorePhase)
										end),
									}),
								},
							}),

							scope:New("Frame")({
								Name = "HostilePanelWrapper",
								Size = UDim2.new(0.5, -PANEL_SPACING / 2, 1, 0),
								Position = UDim2.fromScale(1, 0.5),
								AnchorPoint = Vector2.new(1, 0.5),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									TeamPanel(scope, {
										TeamName = "Hostiles",
										TeamIcon = HOSTILES_ICON,
										TeamColorBright = HOSTILE_COLOR_BRIGHT,
										Score = hostileScore,
										IsWinner = not defendersWon,
										Visible = panelsVisible,
										StartScoreCounting = startScoreCounting,
										WinnerRevealed = winnerRevealed,
										SlideDirection = 1,
										FadeOut = scope:Computed(function(use: FusionUseFn)
											return use(transitionToLeaderboard) or use(tabToggledDuringScorePhase)
										end),
									}),
								},
							}),
						},
					}),

					scope:New("TextLabel")({
						Name = "GameId",
						Size = UDim2.fromOffset(300, 24),
						Position = UDim2.fromScale(0.5, 0.96),
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						Text = "MATCH " .. gameId,
						TextColor3 = Theme.Colors.White,
						TextTransparency = scope:Computed(function(use: FusionUseFn)
							return 1 - use(gameIdAlpha)
						end),
						TextSize = 12,
						Font = Theme.Text.Medium,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "VictoryTextContainer",
				Size = UDim2.fromScale(1, 0.122),
				Position = scope:Computed(function(use: FusionUseFn)
					return UDim2.fromScale(0.5, use(victoryTextY))
				end),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				ZIndex = 6,

				[Fusion.Children] = {
					scope:New("UIScale")({
						Scale = victoryTextScale,
					}),

					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0.045, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					scope:New("TextLabel")({
						Name = "ResultText",
						Size = UDim2.fromScale(0.2, 0.515),
						BackgroundTransparency = 1,
						Text = resultText,
						TextColor3 = Theme.Colors.White,
						TextTransparency = 0,
						TextScaled = true,
						Font = Theme.Text.Black,
						LayoutOrder = 1,

						[Fusion.Children] = {
							scope:New("ImageLabel")({
								Name = "Crest",
								Size = UDim2.fromScale(1, 0.94),
								Position = UDim2.fromScale(-0.02, 0.5),
								AnchorPoint = Vector2.new(1, 0.5),
								BackgroundTransparency = 1,
								Image = victoryIcon,
								ImageTransparency = headerTransparency,
								ScaleType = Enum.ScaleType.Fit,

								[Fusion.Children] = {
									scope:New("UIAspectRatioConstraint")({
										AspectRatio = 1,
										DominantAxis = Enum.DominantAxis.Height,
									}),
								},
							}),
						},
					}),

					scope:New("TextLabel")({
						Name = "TeamVictoryText",
						Size = UDim2.fromScale(0.3125, 0.167),
						BackgroundTransparency = 1,
						Text = teamVictoryText,
						TextColor3 = if defendersWon then DEFENDER_COLOR_BRIGHT else HOSTILE_COLOR_BRIGHT,
						TextTransparency = scope:Computed(function(use: FusionUseFn)
							return 0.15 + (1 - use(victoryTextFinalAlpha)) * 0.85
						end),
						TextScaled = true,
						Font = Theme.Text.Bold,
						LayoutOrder = 2,
					}),

					scope:New("Frame")({
						Name = "MatchInfo",
						Size = UDim2.fromScale(0.469, 0.182),
						BackgroundTransparency = 1,
						LayoutOrder = 3,

						[Fusion.Children] = matchInfoChildren,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "MVPHeaderScores",
				Size = UDim2.fromScale(1, 0.074),
				Position = UDim2.fromScale(0.5, 0.03),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				ZIndex = 5,
				Visible = scope:Computed(function(use: FusionUseFn)
					return use(compactScoresActuallyVisible)
				end),

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "DefenderSide",
						Size = UDim2.fromScale(0.073, 1),
						Position = UDim2.fromScale(0.354, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0.05, 0),
							}),

							scope:New("TextLabel")({
								Name = "TeamName",
								Size = UDim2.fromScale(1, 0.175),
								BackgroundTransparency = 1,
								Text = "VULTARIANS",
								TextColor3 = if defendersWon then DEFENDER_COLOR_BRIGHT else Theme.Colors.White,
								TextTransparency = scope:Computed(function(use: FusionUseFn)
									return 1 - use(compactHeaderAlpha)
								end),
								TextScaled = true,
								Font = Theme.Text.Bold,
								LayoutOrder = 1,
							}),

							ScoreDisplay(scope, defenderScore, DEFENDER_COLOR_BRIGHT, defendersWon, compactHeaderAlpha, UDim2.fromScale(0.651, 0.475), Enum.TextXAlignment.Center),
						},
					}),

					scope:New("Frame")({
						Name = "HostileSide",
						Size = UDim2.fromScale(0.073, 1),
						Position = UDim2.fromScale(0.646, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0.05, 0),
							}),

							scope:New("TextLabel")({
								Name = "TeamName",
								Size = UDim2.fromScale(1, 0.175),
								BackgroundTransparency = 1,
								Text = "HOSTILES",
								TextColor3 = if not defendersWon then HOSTILE_COLOR_BRIGHT else Theme.Colors.White,
								TextTransparency = scope:Computed(function(use: FusionUseFn)
									return 1 - use(compactHeaderAlpha)
								end),
								TextScaled = true,
								Font = Theme.Text.Bold,
								LayoutOrder = 1,
							}),

							ScoreDisplay(scope, hostileScore, HOSTILE_COLOR_BRIGHT, not defendersWon, compactHeaderAlpha, UDim2.fromScale(0.651, 0.475), Enum.TextXAlignment.Center),
						},
					}),
				},
			}),

			scope:Computed(function(use: FusionUseFn)
				if not use(transitionToLeaderboard) then
					return nil
				end
				return PostGameLeaderboard(scope, {
					DefendersData = defendersData,
					RaidersData = raidersData,
					DefendersWon = defendersWon,
					TopPlayers = myTeamTopPlayers,
					Visible = leaderboardBodyVisible,
					OnClose = closeScreen,
					OnOpenMVP = openMVPScreen,
					CreditsBalance = credits.Balance,
					CreditsEarned = credits.Earned,
					CreditsReward = credits.Reward,
					CreditsPurchasable = credits.Purchasable,
					OnBalanceClick = function()
						creditsModalOpen:set(true)
					end,
				})
			end),

			scope:Computed(function(use: FusionUseFn)
				if not use(transitionToLeaderboard) then
					return nil
				end
				return MVPScreen(scope, myTeamTopPlayers, mvpScreenVisible, killsVisible, damageVisible, healsVisible, closeMVPScreen)
			end),

			CreditsModal(scope, { Visible = creditsModalOpen }),
		},
	})
end

return WinScreen
