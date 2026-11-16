--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Trove = require(Packages:WaitForChild("Trove", 5))
local Network = require(MainModule.Shared.Network)
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
local Theme = require(MainModule.Shared.UI.Theme)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)

local PingService = {}
PingService.Name = "PingService"

local LocalPlayer = Players.LocalPlayer

local HIGHLIGHT_DURATION = 5
local FADE_OUT_START = 4.2
local MARKER_DURATION = 1.5
local MARKER_FADE_START = 1.0

local PING_MARKER_IMAGE = "rbxassetid://70911598639762"
local NORMAL_MARKER_COLOR = Color3.fromRGB(255, 140, 0)
local SPECIAL_MARKER_COLOR = Color3.fromRGB(255, 80, 80)

local MARKER_SHRINK_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local HIGHLIGHT_FADE_OUT_TWEEN_INFO = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local MARKER_SCALE_TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local MARKER_FADE_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HIGHLIGHT_FLASH_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HIGHLIGHT_FILL_TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)


local activeHighlights: { [Model]: { highlight: Highlight, startTime: number } } = {}
local activeMarkers: { [Attachment]: { startTime: number, gui: BillboardGui, fadingOut: boolean } } = {}
local markerCleanupThreads: { [Attachment]: thread } = {}
local SettingsService: any = nil

local pingRaycastParams = RaycastParams.new()
pingRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
pingRaycastParams.IgnoreWater = true

local trove: typeof(Trove.new()) = nil
local heartbeatConnection: RBXScriptConnection? = nil

local function destroyPingMarkerAttachment(attachment: Attachment): ()
	markerCleanupThreads[attachment] = nil
	attachment:Destroy()
end

local function getSettings(): SettingsConfig.SettingsTemplate
	local svc = SettingsService
	if svc and svc.GetSettings then
		local currentSettings = svc:GetSettings()
		if currentSettings then
			return currentSettings
		end
	end

	return SettingsConfig.DefaultSettings
end

local function getHighlightColor(): Color3
	local settings = getSettings()
	local colorIndex = settings.Settings.PingHighlightColor
	if typeof(colorIndex) == "number" and colorIndex >= 1 and colorIndex <= #Theme.HighlightColors then
		return Theme.HighlightColors[colorIndex]
	end
	return Theme.HighlightColors[5]
end

local function isAnimated(): boolean
	local settings = getSettings()
	local animated = settings.Settings.AnimatedPingHighlight
	return animated == true
end

local function isFillEnabled(): boolean
	local settings = getSettings()
	local fill = settings.Settings.PingHighlightFill
	return fill == true
end

local function brightenColor(color: Color3, factor: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, math.max(0, s - 0.2), math.min(1, v + factor))
end

local function stopHeartbeatIfEmpty(): ()
	if heartbeatConnection and next(activeHighlights) == nil and next(activeMarkers) == nil then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

local function cleanupHighlight(character: Model): ()
	local data = activeHighlights[character]
	if not data then
		return
	end

	activeHighlights[character] = nil

	if data.highlight and data.highlight.Parent then
		data.highlight:Destroy()
	end

	stopHeartbeatIfEmpty()
end

local function cleanupMarker(attachment: Attachment): ()
	local data = activeMarkers[attachment]
	if not data then
		return
	end

	activeMarkers[attachment] = nil

	local cleanupThread = markerCleanupThreads[attachment]
	if cleanupThread then
		task.cancel(cleanupThread)
		markerCleanupThreads[attachment] = nil
	end

	if attachment.Parent then
		attachment:Destroy()
	end

	stopHeartbeatIfEmpty()
end

local function fadeOutMarker(_attachment: Attachment, billboard: BillboardGui): ()
	local container = billboard:FindFirstChild("Container") :: Frame?
	if not container then
		return
	end

	local uiScale = container:FindFirstChild("Scale") :: UIScale?
	if not uiScale then
		return
	end

	TweenService:Create(uiScale, MARKER_SHRINK_TWEEN_INFO, {
		Scale = 0,
	}):Play()
end

local function animateHighlightOut(highlight: Highlight, onComplete: (() -> ())?): ()
	local outTween = TweenService:Create(highlight, HIGHLIGHT_FADE_OUT_TWEEN_INFO, {
		FillTransparency = 1,
		OutlineTransparency = 1,
	})

	outTween.Completed:Once(function()
		if onComplete then
			onComplete()
		end
	end)

	outTween:Play()
end

local function updateHighlights(): ()
	local currentTime = os.clock()

	for character, data in activeHighlights do
		local elapsed = currentTime - data.startTime

		if elapsed >= HIGHLIGHT_DURATION then
			cleanupHighlight(character)
		elseif elapsed >= FADE_OUT_START then
			local highlight = data.highlight
			if highlight and highlight.Parent then
				if highlight.OutlineTransparency < 0.9 then
					animateHighlightOut(highlight, function()
						cleanupHighlight(character)
					end)
				end
			end
		end

		if not character.Parent then
			cleanupHighlight(character)
		end
	end

	for attachment, data in activeMarkers do
		local elapsed = currentTime - data.startTime

		if elapsed >= MARKER_DURATION then
			cleanupMarker(attachment)
		elseif elapsed >= MARKER_FADE_START and not data.fadingOut then
			data.fadingOut = true
			local gui = data.gui
			if gui and gui.Parent then
				fadeOutMarker(attachment, gui)
			end
		end

		if not attachment.Parent then
			cleanupMarker(attachment)
		end
	end

	stopHeartbeatIfEmpty()
end

local function ensureHeartbeatRunning(): ()
	if not heartbeatConnection then
		heartbeatConnection = RunService.Heartbeat:Connect(updateHighlights)
	end
end

local function createPingMarker(position: Vector3, senderName: string, isSpecial: boolean): ()
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain

	local markerColor = if isSpecial then SPECIAL_MARKER_COLOR else NORMAL_MARKER_COLOR

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PingMarker"
	billboard.Size = UDim2.fromOffset(80, 58)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.Adornee = attachment
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 500
	billboard.Parent = attachment

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.fromScale(1, 1)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.BackgroundTransparency = 1
	container.Parent = billboard

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "Scale"
	uiScale.Scale = 1
	uiScale.Parent = container

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "SenderName"
	nameLabel.Size = UDim2.new(1, 0, 0, 16)
	nameLabel.Position = UDim2.fromScale(0.5, 0)
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = string.upper(senderName)
	nameLabel.TextColor3 = markerColor
	nameLabel.TextTransparency = 1
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.TextStrokeTransparency = 1
	nameLabel.TextSize = 11
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = container

	local imageContainer = Instance.new("Frame")
	imageContainer.Name = "ImageContainer"
	imageContainer.Size = UDim2.fromOffset(22, 22)
	imageContainer.Position = UDim2.new(0.5, 0, 0, 22)
	imageContainer.AnchorPoint = Vector2.new(0.5, 0)
	imageContainer.BackgroundTransparency = 1
	imageContainer.Parent = container

	local image = Instance.new("ImageLabel")
	image.Name = "PingIcon"
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.Image = PING_MARKER_IMAGE
	image.ImageColor3 = markerColor
	image.ImageTransparency = 1
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = imageContainer

	activeMarkers[attachment] = {
		startTime = os.clock(),
		gui = billboard,
		fadingOut = false,
	}

	ensureHeartbeatRunning()

	local initialScale = 0.4
	imageContainer.Size = UDim2.fromOffset(22 * initialScale, 22 * initialScale)

	local scaleTween = TweenService:Create(imageContainer, MARKER_SCALE_TWEEN_INFO, {
		Size = UDim2.fromOffset(22, 22),
	})

	local imageFadeTween = TweenService:Create(image, MARKER_FADE_TWEEN_INFO, {
		ImageTransparency = 0,
	})

	local nameFadeTween = TweenService:Create(nameLabel, MARKER_FADE_TWEEN_INFO, {
		TextTransparency = 0,
		TextStrokeTransparency = 0.65,
	})

	scaleTween:Play()
	imageFadeTween:Play()
	nameFadeTween:Play()

	markerCleanupThreads[attachment] = task.delay(MARKER_DURATION + 1, destroyPingMarkerAttachment, attachment)
end

local function createHighlight(character: Model): Highlight?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	local existingOtherHighlight = character:FindFirstChildOfClass("Highlight")
	if existingOtherHighlight and existingOtherHighlight.Name ~= "PingHighlight" then
		existingOtherHighlight:Destroy()
	end

	local color = getHighlightColor()

	local highlight = Instance.new("Highlight")
	highlight.Name = "PingHighlight"
	highlight.Adornee = character
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.Parent = character

	activeHighlights[character] = {
		highlight = highlight,
		startTime = os.clock(),
	}

	ensureHeartbeatRunning()

	return highlight
end

local function animateHighlightIn(highlight: Highlight): ()
	local color = getHighlightColor()
	local brightColor = brightenColor(color, 0.3)

	highlight.OutlineColor = brightColor
	highlight.OutlineTransparency = 0
	highlight.FillTransparency = 1

	local flashTween = TweenService:Create(highlight, HIGHLIGHT_FLASH_TWEEN_INFO, {
		OutlineColor = color,
	})
	flashTween:Play()

	if isFillEnabled() then
		task.delay(0.1, function()
			if not highlight or not highlight.Parent then
				return
			end

			local fillTween = TweenService:Create(highlight, HIGHLIGHT_FILL_TWEEN_INFO, {
				FillTransparency = 0.8,
			})
			fillTween:Play()
		end)
	end
end

local function snapHighlightIn(highlight: Highlight): ()
	highlight.FillTransparency = if isFillEnabled() then 0.8 else 1
	highlight.OutlineTransparency = 0
end

local function applyHighlightToCharacter(character: Model): ()
	local existingData = activeHighlights[character]
	if existingData then
		existingData.startTime = os.clock()
		local highlight = existingData.highlight
		if highlight and highlight.Parent then
			highlight.FillTransparency = if isFillEnabled() then 0.8 else 1
			highlight.OutlineTransparency = 0
		end
		return
	end

	local highlight = createHighlight(character)
	if not highlight then
		return
	end

	if isAnimated() then
		animateHighlightIn(highlight)
	else
		snapHighlightIn(highlight)
	end
end

local function getPingTarget(): Vector3?
	local character = LocalPlayer.Character
	if not character then
		return nil
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end

	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	pingRaycastParams.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(ray.Origin, ray.Direction * 50000, pingRaycastParams)

	if result then
		return result.Position
	end

	return ray.Origin + ray.Direction * 50000
end

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean): ()
	if gameProcessedEvent then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton3 then
		local position = getPingTarget()
		if position then
			Network.Ping.sendPing(position)
		end
	end
end

local function onApplyHighlight(pingData: Network.PingData): ()
	createPingMarker(pingData.position, pingData.senderName, pingData.isSpecial)

	local sw = ServiceLocator.ScreenWatch()
	local isWatching = sw and typeof(sw.IsWatching) == "function" and sw:IsWatching()

	local ws = workspace
	for _, target in pingData.targets do
		local targetPlayer = Players:GetPlayerByUserId(target.userId)
		if targetPlayer == LocalPlayer and not isWatching then
			continue
		end
		if targetPlayer and targetPlayer.Character then
			applyHighlightToCharacter(targetPlayer.Character)
		else
			local character = ws:FindFirstChild(target.characterName)
			if character and character:IsA("Model") then
				applyHighlightToCharacter(character)
			end
		end
	end
end

local function onCharacterRemoving(character: Model): ()
	cleanupHighlight(character)
end

local function setupCharacterCleanup(): ()
	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer then
			trove:Connect(player.CharacterRemoving, onCharacterRemoving)
		end
	end

	trove:Connect(Players.PlayerAdded, function(player: Player)
		trove:Connect(player.CharacterRemoving, onCharacterRemoving)
	end)

	trove:Connect(Players.PlayerRemoving, function(player: Player)
		if player.Character then
			cleanupHighlight(player.Character)
		end
	end)
end

function PingService:init(): ()
end

function PingService:start(): ()
	SettingsService = LazyService.create(MainModule, "SettingsService")()

	trove = Trove.new()

	trove:Connect(UserInputService.InputBegan, onInputBegan)
	trove:Add(Network.Ping.onHighlightReceived(onApplyHighlight))

	setupCharacterCleanup()
end

function PingService:ApplyHighlightToPlayer(player: Player): ()
	if player.Character then
		applyHighlightToCharacter(player.Character)
	end
end

function PingService:ClearAllHighlights(): ()
	for character, _ in activeHighlights do
		cleanupHighlight(character)
	end
end

function PingService:ClearAllMarkers(): ()
	for attachment, _ in activeMarkers do
		cleanupMarker(attachment)
	end
end

function PingService:Cleanup(): ()
	for attachment, thread in markerCleanupThreads do
		task.cancel(thread)
		markerCleanupThreads[attachment] = nil
	end

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	if trove then
		trove:Destroy()
		trove = nil
	end

	self:ClearAllHighlights()
	self:ClearAllMarkers()
end

return PingService
