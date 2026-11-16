--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local GunStats = require(MainModule.Shared.Config.GunStats)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

type HitLogEntry = {
	attackerId: number,
	bodyPart: number,
	localX: number,
	localY: number,
	localZ: number,
	damage: number,
	gunIndex: number,
	headshot: boolean,
}

type OutgoingHitEntry = {
	targetId: number,
	damage: number,
	gunIndex: number,
	headshot: boolean,
}

export type VDIKillReportProps = {
	HitLog: { HitLogEntry },
	OutgoingLog: { OutgoingHitEntry }?,
	CharacterModel: Model,
	KillerName: string?,
	GunName: string?,
	Range: number?,
	AccuracyStats: { accuracy: number, matchAccuracy: number }?,
	OnClose: () -> (),
}

local BODY_PART_NAMES: { string } = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local GUN_INDEX_TO_NAME = GunStats.GUN_INDEX_TO_NAME

local VP_W = 260
local VP_H = 380
local LIST_W = 306
local ROW_H = 30
local GAP = 16
local CLOSE_H = 34

local CAM_DIST = 7.5
local CAM_UP = 1.0
local CAM_LOOK = 0.1
local CAM_FOV = 50

local DOT_PX = 8
local DOT_PX_HS = 10
local DOT_FILL_TRANS = 0.75
local DOT_BORDER = 2.5

local DOT_BODY_C = Color3.fromRGB(130, 145, 200)
local DOT_HS_C = Color3.fromRGB(220, 55, 55)

local BG = Color3.fromRGB(16, 16, 20)
local VP_BG = Color3.fromRGB(10, 10, 14)
local STROKE_COL = Color3.fromRGB(45, 45, 55)
local ROW_BG = Color3.fromRGB(22, 22, 28)
local ROW_BG_HS = Color3.fromRGB(35, 18, 22)
local CLOSE_BG = Color3.fromRGB(160, 35, 35)
local CLOSE_HOVER = Color3.fromRGB(195, 45, 45)
local ACCENT = Color3.fromRGB(200, 50, 50)

local T_WHITE = Color3.fromRGB(230, 230, 240)
local T_SILVER = Color3.fromRGB(160, 160, 175)
local T_MUTED = Color3.fromRGB(100, 100, 115)
local T_DIM = Color3.fromRGB(60, 60, 72)

local FB = Enum.Font.GothamBlack
local FD = Enum.Font.GothamBold
local FM = Enum.Font.GothamMedium

local function getGunImageId(gunIndex: number): string
	local name = GUN_INDEX_TO_NAME[gunIndex]
	if not name then return "" end
	local stats = GunStats.get(name)
	if not stats then return "" end
	return "rbxassetid://" .. tostring(stats.GunImageId)
end

local function getPlayerName(userId: number): string
	local p = Players:GetPlayerByUserId(userId)
	return if p then p.Name else "Unknown"
end

local R6_OFFSETS: { [string]: CFrame } = {
	Head = CFrame.new(0, 1.5, 0),
	["Left Arm"] = CFrame.new(-1.5, 0, 0),
	["Right Arm"] = CFrame.new(1.5, 0, 0),
	["Left Leg"] = CFrame.new(-0.5, -2, 0),
	["Right Leg"] = CFrame.new(0.5, -2, 0),
}

local function prepareAvatarModel(model: Model): ()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	for _, desc in model:GetDescendants() do
		if desc:IsA("BaseScript") or desc:IsA("Sound") or desc:IsA("Tool") or desc:IsA("BallSocketConstraint") then
			desc:Destroy()
		end
	end

	local torso = model:FindFirstChild("Torso") :: BasePart?
	if torso then
		local torsoCF = torso.CFrame
		for partName, offset in R6_OFFSETS do
			local part = model:FindFirstChild(partName) :: BasePart?
			if part then
				part.CFrame = torsoCF * offset
			end
		end
	end

	local pivot = model:GetPivot()
	model:PivotTo(pivot * CFrame.Angles(0, math.pi, 0))
end

local function projectToViewport(camCF: CFrame, fov: number, worldPos: Vector3, vpW: number, vpH: number): (number, number, boolean)
	local localPos = camCF:PointToObjectSpace(worldPos)
	if localPos.Z >= 0 then
		return 0, 0, false
	end

	local aspect = vpW / vpH
	local halfTan = math.tan(math.rad(fov) / 2)
	local depth = -localPos.Z

	local sx = (-localPos.X / (depth * halfTan * aspect)) * 0.5 + 0.5
	local sy = (-localPos.Y / (depth * halfTan)) * 0.5 + 0.5

	local visible = sx >= -0.1 and sx <= 1.1 and sy >= -0.1 and sy <= 1.1
	return sx * vpW, sy * vpH, visible
end

local function mirrorToFront(hitWorldPos: Vector3, bpCenter: Vector3, camPos: Vector3): Vector3
	local toC = (camPos - bpCenter).Unit
	local off = hitWorldPos - bpCenter
	if off:Dot(toC) < 0 then
		return bpCenter + off - 2 * off:Dot(toC) * toC
	end
	return hitWorldPos
end


local function createDonut(scope: FusionScope, x: number, y: number, isHS: boolean): Frame
	local col = if isHS then DOT_HS_C else DOT_BODY_C
	local sz = if isHS then DOT_PX_HS else DOT_PX

	return scope:New("Frame")({
		Name = "Dot",
		Size = UDim2.fromOffset(sz, sz),
		Position = UDim2.fromOffset(x - sz // 2, y - sz // 2),
		BackgroundColor3 = col,
		BackgroundTransparency = DOT_FILL_TRANS,
		BorderSizePixel = 0,
		ZIndex = 5,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			scope:New("UIStroke")({ Color = col, Thickness = DOT_BORDER }),
		},
	})
end

local function createHitRow(scope: FusionScope, entry: HitLogEntry, order: number): Frame
	local img = getGunImageId(entry.gunIndex)
	local dmg = tostring(math.floor(entry.damage))
	local name = getPlayerName(entry.attackerId)
	local isHS = entry.headshot
	local bg = if isHS then ROW_BG_HS else ROW_BG

	return scope:New("Frame")({
		Name = "H" .. tostring(order),
		Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundColor3 = bg,
		LayoutOrder = order,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
			scope:New("ImageLabel")({
				Name = "Gun",
				Size = UDim2.fromOffset(44, 18),
				Position = UDim2.fromOffset(10, 6),
				BackgroundTransparency = 1,
				Image = img,
				ScaleType = Enum.ScaleType.Fit,
				ImageColor3 = if isHS then Color3.fromRGB(220, 160, 160) else T_SILVER,
			}),
			scope:New("TextLabel")({
				Name = "Dmg",
				Size = UDim2.fromOffset(50, ROW_H),
				Position = UDim2.fromOffset(60, 0),
				BackgroundTransparency = 1,
				Text = dmg,
				TextColor3 = if isHS then ACCENT else T_WHITE,
				TextSize = 18,
				Font = FB,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
			scope:New("TextLabel")({
				Name = "Name",
				Size = UDim2.new(1, -122, 0, ROW_H),
				Position = UDim2.fromOffset(114, 0),
				BackgroundTransparency = 1,
				Text = name,
				TextColor3 = T_MUTED,
				TextSize = 12,
				Font = FM,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		},
	})
end

local function VDIKillReport(scope: FusionScope, props: VDIKillReportProps): ScreenGui
	
	local accStr = ""
	local matchAccStr = ""
	if props.AccuracyStats then
		accStr = string.format("ACCURACY: %.1f%%", props.AccuracyStats.accuracy * 100)
		matchAccStr = string.format("MATCH ACCURACY: %.1f%%", props.AccuracyStats.matchAccuracy * 100)
	end
	local hitLog = props.HitLog

	local wm: WorldModel = Instance.new("WorldModel")

	local avatar = props.CharacterModel
	prepareAvatarModel(avatar)
	avatar.Parent = wm

	local cam = Instance.new("Camera")
	cam.FieldOfView = CAM_FOV
	cam.CameraType = Enum.CameraType.Scriptable

	local root = avatar:FindFirstChild("Torso") :: BasePart?
		or avatar:FindFirstChild("HumanoidRootPart") :: BasePart?

	local camCF = CFrame.identity
	local camPos = Vector3.zero

	if root then
		local c = root.Position
		camPos = c + Vector3.new(0, CAM_UP, -CAM_DIST)
		camCF = CFrame.new(camPos, c + Vector3.new(0, CAM_LOOK, 0))
		cam.CFrame = camCF
	end

	local dotFrames: { any } = {}
	for _, entry in hitLog do
		local bpName = BODY_PART_NAMES[entry.bodyPart] or "Torso"
		local bp = avatar:FindFirstChild(bpName) :: BasePart?
		if not bp then
			bp = root
		end
		if not bp then continue end

		local hitWorld = bp.CFrame * CFrame.new(entry.localX, entry.localY, entry.localZ)
		local mirrored = mirrorToFront(hitWorld.Position, bp.Position, camPos)
		local px, py, vis = projectToViewport(camCF, CAM_FOV, mirrored, VP_W, VP_H)

		if vis then
			table.insert(dotFrames, createDonut(scope, px, py, entry.headshot))
		end
	end

	table.insert(scope, function()
		wm:Destroy()
	end)

	local rows: { any } = {}
	for i, entry in hitLog do
		table.insert(rows, createHitRow(scope, entry, i))
	end

	local closeHovered = scope:Value(false)

	local alphaVal = scope:Value(1)
	local fadeAlpha = scope:Spring(alphaVal, 30, 0.9)

	task.defer(function()
		alphaVal:set(0)
	end)

	local totalW = VP_W + GAP + LIST_W
	local totalH = VP_H

	return scope:New("ScreenGui")({
		Name = "VDIKillReport",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 51,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			scope:New("CanvasGroup")({
				Name = "Root",
				Size = UDim2.fromOffset(totalW, totalH),
				Position = UDim2.fromScale(0.5, 0.46),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = BG,
				BackgroundTransparency = 0.25,
				GroupTransparency = fadeAlpha,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
					scope:New("UIStroke")({ Color = STROKE_COL, Thickness = 1 }),

					scope:New("Frame")({
						Name = "VP",
						Size = UDim2.fromOffset(VP_W, VP_H),
						BackgroundColor3 = VP_BG,
						BackgroundTransparency = 0.3,
						BorderSizePixel = 0,
						ClipsDescendants = true,
						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
							scope:New("ViewportFrame")({
								Name = "View",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								CurrentCamera = cam,
								Ambient = Color3.fromRGB(180, 185, 195),
								LightColor = Color3.fromRGB(255, 255, 255),
								LightDirection = Vector3.new(-0.3, -0.6, -0.5).Unit,
								ZIndex = 1,
								[Fusion.Children] = { wm, cam },
							}),
							dotFrames,
						},
					}),

					scope:New("Frame")({
						Name = "Right",
						Size = UDim2.new(0, LIST_W, 1, 0),
						Position = UDim2.fromOffset(VP_W + GAP, 0),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								Padding = UDim.new(0, 0),
								SortOrder = Enum.SortOrder.LayoutOrder,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
							}),

							scope:New("Frame")({
								Name = "Header",
								Size = UDim2.new(1, 0, 0, 28),
								BackgroundTransparency = 1,
								LayoutOrder = 1,
								[Fusion.Children] = {
									scope:New("TextLabel")({
										Name = "Title",
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = "VDI DEATH REPORT",
										TextColor3 = T_SILVER,
										TextSize = 13,
										Font = FD,
										TextXAlignment = Enum.TextXAlignment.Center,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "AccuracyStatsFrame",
								Size = UDim2.new(1, 0, 0, 20),
								BackgroundTransparency = 1,
								LayoutOrder = 2,
								Visible = props.AccuracyStats ~= nil,
								[Fusion.Children] = {
									scope:New("TextLabel")({
										Name = "Accuracy",
										Size = UDim2.fromScale(0.5, 1),
										Position = UDim2.fromScale(0, 0),
										BackgroundTransparency = 1,
										Text = accStr,
										TextColor3 = T_SILVER,
										TextSize = 11,
										Font = FM,
										TextXAlignment = Enum.TextXAlignment.Center,
									}),
									scope:New("TextLabel")({
										Name = "MatchAccuracy",
										Size = UDim2.fromScale(0.5, 1),
										Position = UDim2.fromScale(0.5, 0),
										BackgroundTransparency = 1,
										Text = matchAccStr,
										TextColor3 = T_SILVER,
										TextSize = 11,
										Font = FM,
										TextXAlignment = Enum.TextXAlignment.Center,
									}),
								},
							}),

							scope:New("ScrollingFrame")({
								Name = "List",
								Size = UDim2.new(1, 0, 1, -48 - CLOSE_H - 6),
								BackgroundTransparency = 1,
								ScrollBarThickness = 3,
								ScrollBarImageColor3 = T_DIM,
								CanvasSize = UDim2.fromOffset(0, 0),
								AutomaticCanvasSize = Enum.AutomaticSize.Y,
								BorderSizePixel = 0,
								ScrollingDirection = Enum.ScrollingDirection.Y,
								LayoutOrder = 3,

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										Padding = UDim.new(0, 4),
										SortOrder = Enum.SortOrder.LayoutOrder,
										HorizontalAlignment = Enum.HorizontalAlignment.Center,
									}),
									scope:New("UIPadding")({
										PaddingTop = UDim.new(0, 6),
										PaddingBottom = UDim.new(0, 6),
										PaddingLeft = UDim.new(0, 0),
										PaddingRight = UDim.new(0, 16),
									}),
									rows,
								},
							}),

							scope:New("Frame")({
								Name = "ClosePad",
								Size = UDim2.new(1, 0, 0, 4),
								BackgroundTransparency = 1,
								LayoutOrder = 4,
							}),

							scope:New("TextButton")({
								Name = "Close",
								AnchorPoint = Vector2.new(0.5, 0),
								Position = UDim2.fromScale(0.5, 0),
								Size = UDim2.new(0.75, 0, 0, CLOSE_H),
								BackgroundColor3 = scope:Spring(
									scope:Computed(function(use: FusionUseFn)
										return if use(closeHovered) then CLOSE_HOVER else CLOSE_BG
									end),
									30
								),
								Text = "CLOSE",
								TextColor3 = T_WHITE,
								TextSize = 12,
								Font = FD,
								AutoButtonColor = false,
								LayoutOrder = 5,

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
								},

								[Fusion.OnEvent("Activated")] = function()
									props.OnClose()
								end,
								[Fusion.OnEvent("MouseEnter")] = function()
									closeHovered:set(true)
								end,
								[Fusion.OnEvent("MouseLeave")] = function()
									closeHovered:set(false)
								end,
							}),
						},
					}),
				},
			}),
		},
	})
end

local Module = {
	create = VDIKillReport,
}

return Module
