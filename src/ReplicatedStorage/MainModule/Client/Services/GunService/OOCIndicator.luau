--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local SettingsEnums = require(MainModule.Shared.Config.Settings.SettingsEnums)
local Cache = require(script.Parent.Cache)

local OOCIndicator = {}

OOCIndicator.DISPLAY_DURATION = 3
OOCIndicator.COOLDOWN = 1

local localPlayer = Players.LocalPlayer

local OOC_IMAGE = "rbxassetid://0"
local OOC_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local COLOR_TEXT = Color3.fromRGB(240, 0, 4)
local COLOR_STROKE = Color3.fromRGB(60, 60, 60)
local COLOR_BLACK = Color3.new()
local HEAD_STUDS_OFFSET = Vector3.new(0, 2.5, 0)

local POSITION_TORSO = SettingsEnums.OOCIndicatorPosition.Torso
local MODE_CONDENSED = SettingsEnums.TeamESPOverhead.Condensed

local DETAILED_CHARGE_OFFSET_Y = 5
local CONDENSED_CHARGE_OFFSET_Y = 14

type ActiveEntry = {
	gui: BillboardGui?,
	expireThread: thread?,
	blockedUntil: number,
}

local active: { [number]: ActiveEntry } = {}
local playerRemovingConn: RBXScriptConnection? = nil

local function createBillboard(adornee: BasePart, studsOffset: Vector3?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Charge"
	gui.Active = true
	gui.AlwaysOnTop = true
	gui.MaxDistance = 30
	gui.ResetOnSpawn = false
	gui.Size = UDim2.fromOffset(100, 40)
	if studsOffset then
		gui.StudsOffset = studsOffset
	end
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Adornee = adornee
	return gui
end

local function createIconPair(parent: Frame, size: UDim2): ()
	local white = Instance.new("ImageLabel")
	white.Name = "White"
	white.AnchorPoint = Vector2.new(1, 0.5)
	white.BackgroundTransparency = 1
	white.Image = OOC_IMAGE
	white.Position = UDim2.fromScale(1, 0.5)
	white.Size = size
	white.ZIndex = 2
	white.Parent = parent

	local black = Instance.new("ImageLabel")
	black.Name = "Black"
	black.AnchorPoint = Vector2.new(1, 0.5)
	black.BackgroundTransparency = 1
	black.Image = OOC_IMAGE
	black.ImageColor3 = COLOR_BLACK
	black.Position = UDim2.new(1, 1, 0.5, 1)
	black.Size = size
	black.Parent = parent
end

local function createLabel(parent: Frame, textSize: number, leftAlign: boolean): ()
	local label = Instance.new("TextLabel")
	label.Name = "Num"
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.BackgroundTransparency = 1
	label.FontFace = OOC_FONT
	label.Position = UDim2.fromScale(0, 0.5)
	label.Size = UDim2.new(1, 0, 0, 11)
	label.Text = "OOC"
	label.TextColor3 = COLOR_TEXT
	label.TextSize = textSize
	label.TextStrokeColor3 = COLOR_STROKE
	label.TextStrokeTransparency = 0.5
	if leftAlign then
		label.TextXAlignment = Enum.TextXAlignment.Left
	end
	label.Parent = parent
end

local function buildHeadBadge(adornee: BasePart, chargeOffsetY: number): BillboardGui
	local gui = createBillboard(adornee, HEAD_STUDS_OFFSET)

	local container = Instance.new("Frame")
	container.Name = "DetailedContainer"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.Parent = gui

	local chargeFrame = Instance.new("Frame")
	chargeFrame.Name = "Charge"
	chargeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	chargeFrame.BackgroundTransparency = 1
	chargeFrame.Position = UDim2.new(0.5, 0, 0.5, chargeOffsetY)
	chargeFrame.Size = UDim2.fromOffset(45, 15)
	chargeFrame.Parent = container

	createIconPair(chargeFrame, UDim2.fromOffset(14, 11))
	createLabel(chargeFrame, 14, true)

	return gui
end

local function buildDetailedBadge(adornee: BasePart): BillboardGui
	return buildHeadBadge(adornee, DETAILED_CHARGE_OFFSET_Y)
end

local function buildCondensedBadge(adornee: BasePart): BillboardGui
	return buildHeadBadge(adornee, CONDENSED_CHARGE_OFFSET_Y)
end

local function buildTorsoBadge(adornee: BasePart): BillboardGui
	local gui = createBillboard(adornee, nil)

	local chargeFrame = Instance.new("Frame")
	chargeFrame.Name = "Charge"
	chargeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	chargeFrame.BackgroundTransparency = 1
	chargeFrame.Position = UDim2.fromScale(0.5, 0.5)
	chargeFrame.Size = UDim2.fromScale(1, 1)
	chargeFrame.Parent = gui

	createIconPair(chargeFrame, UDim2.fromOffset(20, 18))
	createLabel(chargeFrame, 26, false)

	return gui
end

local function getTorsoPart(character: Model): BasePart?
	local part = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

local function clearEntry(healerId: number): ()
	local entry = active[healerId]
	if not entry then
		return
	end
	if entry.expireThread then
		task.cancel(entry.expireThread)
		entry.expireThread = nil
	end
	if entry.gui then
		entry.gui:Destroy()
		entry.gui = nil
	end
	active[healerId] = nil
end

function OOCIndicator.show(healerId: number): ()
	if healerId == localPlayer.UserId then
		return
	end

	local now = os.clock()
	local entry = active[healerId]
	if entry and now < entry.blockedUntil then
		return
	end

	local healer = Players:GetPlayerByUserId(healerId)
	if not healer then
		return
	end
	local character = healer.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	local useTorso = Cache.getOOCIndicatorPosition() == POSITION_TORSO
	local adornee: BasePart? = nil
	if useTorso then
		adornee = getTorsoPart(character)
	else
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			adornee = head
		else
			adornee = getTorsoPart(character)
		end
	end
	if not adornee then
		return
	end

	clearEntry(healerId)

	local gui: BillboardGui
	if useTorso then
		gui = buildTorsoBadge(adornee)
	elseif Cache.getTeamESPOverheadMode() == MODE_CONDENSED then
		gui = buildCondensedBadge(adornee)
	else
		gui = buildDetailedBadge(adornee)
	end
	gui.Parent = playerGui

	local newEntry: ActiveEntry = {
		gui = gui,
		expireThread = nil,
		blockedUntil = now + OOCIndicator.DISPLAY_DURATION + OOCIndicator.COOLDOWN,
	}
	newEntry.expireThread = task.delay(OOCIndicator.DISPLAY_DURATION, function()
		newEntry.expireThread = nil
		if newEntry.gui then
			newEntry.gui:Destroy()
			newEntry.gui = nil
		end
	end)
	active[healerId] = newEntry
end

function OOCIndicator.init(): ()
	playerRemovingConn = Players.PlayerRemoving:Connect(function(player: Player)
		clearEntry(player.UserId)
	end)
end

function OOCIndicator.cleanup(): ()
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	for healerId in active do
		clearEntry(healerId)
	end
	table.clear(active)
end

return OOCIndicator
