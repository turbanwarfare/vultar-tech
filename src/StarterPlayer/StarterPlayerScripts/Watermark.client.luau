--!native
--!optimize 2

local Players = game:GetService("Players")
local script_ref = script
local player = Players.LocalPlayer

if not player then
	script_ref:Destroy()
	return
end

local TEST_PLACE_ID = 134407518396463
if game.PlaceId ~= TEST_PLACE_ID then
	script_ref:Destroy()
	return
end

local EXCLUDED_USERS = {} :: { number }
if table.find(EXCLUDED_USERS, player.UserId) then
	script_ref:Destroy()
	return
end

local playerGui = player:WaitForChild("PlayerGui", 30)
if not playerGui then
	script_ref:Destroy()
	return
end

local USERNAME = player.Name
local USERID = tostring(player.UserId)
local WATERMARK_TEXT = USERNAME .. "\n" .. USERID

local TRANSPARENCY = 0.82
local TEXT_COLOR = Color3.fromRGB(140, 140, 140)
local TEXT_SIZE = 36
local ROTATION = -30
local SPACING_X = 480
local SPACING_Y = 220

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Watermark"
screenGui.DisplayOrder = 2147483647
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.fromScale(3, 3)
container.Position = UDim2.fromScale(-1, -1)
container.BackgroundTransparency = 1
container.BorderSizePixel = 0
container.ClipsDescendants = false
container.Rotation = ROTATION
container.Parent = screenGui

local viewportX = 1920 * 3
local viewportY = 1080 * 3

local cols = math.ceil(viewportX / SPACING_X) + 2
local rows = math.ceil(viewportY / SPACING_Y) + 2

for row = 0, rows do
	for col = 0, cols do
		local offsetX = (row % 2) * (SPACING_X / 2)

		local label = Instance.new("TextLabel")
		label.Name = `WM_{row}_{col}`
		label.Size = UDim2.fromOffset(SPACING_X, SPACING_Y)
		label.Position = UDim2.fromOffset(col * SPACING_X + offsetX, row * SPACING_Y)
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Text = WATERMARK_TEXT
		label.TextColor3 = TEXT_COLOR
		label.TextTransparency = TRANSPARENCY
		label.TextSize = TEXT_SIZE
		label.Font = Enum.Font.GothamBold
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Parent = container
	end
end

screenGui.Parent = playerGui
