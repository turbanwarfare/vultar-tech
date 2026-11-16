--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local CratesConfig = require(MainModule.Shared.Config.Cosmetics.Crates)
local CrateAudio = require(script.Parent.CrateAudio)

type CrateRarity = CratesConfig.CrateRarity
type RevealTriggerOptions = {
	isDuplicate: boolean?,
	hasLegendaryEscalation: boolean?,
}

local RevealEffects = {}

local activeTweens: { Tween } = {}
local activeThreads: { thread } = {}
local activeSounds: { Sound } = {}
local activeInstances: { Instance } = {}

local rng = Random.new()

local GOLD_COLOR = CratesConfig.getRarityColor("Rare")
local WHITE_COLOR = Color3.fromRGB(255, 255, 255)

local function trackTween(tween: Tween): Tween
	table.insert(activeTweens, tween)
	tween.Completed:Once(function()
		local idx = table.find(activeTweens, tween)
		if idx then
			table.remove(activeTweens, idx)
		end
	end)
	return tween
end

local function trackInstance<T>(inst: T): T
	local anyInst = inst :: any
	table.insert(activeInstances, anyInst)
	anyInst.Destroying:Once(function()
		local idx = table.find(activeInstances, anyInst)
		if idx then
			table.remove(activeInstances, idx)
		end
	end)
	return inst
end

local function playSound(soundCfg: any, defaultVolume: number?): number
	local startTick = CrateAudio.play(soundCfg, defaultVolume)
	return startTick
end

local starburstTemplate: Frame = (function(): Frame
	local sb = Instance.new("Frame")
	sb.Name = "StarburstContainer"
	sb.Size = UDim2.fromScale(1, 1)
	sb.AnchorPoint = Vector2.new(0.5, 0.5)
	sb.BackgroundTransparency = 1
	sb.BorderSizePixel = 0
	sb.ZIndex = 32

	local core = Instance.new("Frame")
	core.Name = "StarburstCore"
	core.Size = UDim2.fromOffset(24, 24)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	core.BackgroundTransparency = 0.05
	core.BorderSizePixel = 0
	core.ZIndex = 34

	local coreCorner = Instance.new("UICorner")
	coreCorner.CornerRadius = UDim.new(1, 0)
	coreCorner.Parent = core
	core.Parent = sb

	local rayCount = 10
	local angleStep = (2 * math.pi) / rayCount
	for i = 1, rayCount do
		local angle = (i - 1) * angleStep
		local ray = Instance.new("Frame")
		ray.Name = "StarburstRay"
		ray.Size = UDim2.fromOffset(3, 30)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.BackgroundColor3 = GOLD_COLOR
		ray.BackgroundTransparency = 0.1
		ray.BorderSizePixel = 0
		ray.Rotation = math.deg(angle)
		ray.ZIndex = 33

		local rayCorner = Instance.new("UICorner")
		rayCorner.CornerRadius = UDim.new(1, 0)
		rayCorner.Parent = ray

		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, WHITE_COLOR),
			ColorSequenceKeypoint.new(0.35, GOLD_COLOR),
			ColorSequenceKeypoint.new(1, GOLD_COLOR),
		})
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Rotation = 90
		gradient.Parent = ray
		ray.Parent = sb
	end
	return sb
end)()

local lightPillarTemplate: Frame = (function(): Frame
	local lp = Instance.new("Frame")
	lp.Name = "LegendaryLightPillar"
	lp.Size = UDim2.fromOffset(340, 720)
	lp.AnchorPoint = Vector2.new(0.5, 1)
	lp.BackgroundTransparency = 1
	lp.BorderSizePixel = 0
	lp.ZIndex = 2
	lp.ClipsDescendants = false

	local outerBeam = Instance.new("Frame")
	outerBeam.Name = "OuterBeam"
	outerBeam.Size = UDim2.new(1, 0, 0, 40)
	outerBeam.Position = UDim2.fromScale(0.5, 1)
	outerBeam.AnchorPoint = Vector2.new(0.5, 1)
	outerBeam.BackgroundColor3 = Color3.fromRGB(255, 185, 0)
	outerBeam.BackgroundTransparency = 0.2
	outerBeam.BorderSizePixel = 0
	outerBeam.ZIndex = 2

	local outerGrad = Instance.new("UIGradient")
	outerGrad.Rotation = -90
	outerGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	outerGrad.Parent = outerBeam
	outerBeam.Parent = lp

	local innerCore = Instance.new("Frame")
	innerCore.Name = "InnerCore"
	innerCore.Size = UDim2.new(0.38, 0, 0, 40)
	innerCore.Position = UDim2.fromScale(0.5, 1)
	innerCore.AnchorPoint = Vector2.new(0.5, 1)
	innerCore.BackgroundColor3 = Color3.fromRGB(255, 235, 240)
	innerCore.BackgroundTransparency = 0.05
	innerCore.BorderSizePixel = 0
	innerCore.ZIndex = 3

	local innerGrad = Instance.new("UIGradient")
	innerGrad.Rotation = -90
	innerGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.0),
		NumberSequenceKeypoint.new(0.6, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	innerGrad.Parent = innerCore
	innerCore.Parent = lp
	return lp
end)()

local particleTemplate: Frame = (function(): Frame
	local pt = Instance.new("Frame")
	pt.Name = "RevealParticle"
	pt.Size = UDim2.fromOffset(12, 12)
	pt.Position = UDim2.fromScale(0.5, 0.5)
	pt.AnchorPoint = Vector2.new(0.5, 0.5)
	pt.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	pt.BorderSizePixel = 0
	pt.ZIndex = 35

	local ptCorner = Instance.new("UICorner")
	ptCorner.CornerRadius = UDim.new(1, 0)
	ptCorner.Parent = pt

	local ptStroke = Instance.new("UIStroke")
	ptStroke.Color = Color3.fromRGB(255, 255, 255)
	ptStroke.Thickness = 1
	ptStroke.Transparency = 0.3
	ptStroke.Parent = pt
	return pt
end)()

local vignetteFlashTemplate: Frame = (function(): Frame
	local vf = Instance.new("Frame")
	vf.Name = "VignetteFlash"
	vf.Size = UDim2.fromScale(1, 1)
	vf.BackgroundColor3 = GOLD_COLOR
	vf.BackgroundTransparency = 1
	vf.BorderSizePixel = 0
	vf.ZIndex = 25
	return vf
end)()

local function createTween(target: Instance, tweenInfo: TweenInfo, goals: { [string]: any }): Tween
	return TweenService:Create(target, tweenInfo, goals)
end

local function prepareVignetteFlash(overlayFrame: GuiObject, config: any): (Tween?, GuiObject?)
	local flashFrame = vignetteFlashTemplate:Clone()
	flashFrame.Parent = overlayFrame
	trackInstance(flashFrame)

	local peakTransparency = config.PeakTransparency or 0.75
	local flashDuration = config.Duration or 0.4

	local flashIn = TweenService:Create(
		flashFrame,
		TweenInfo.new(flashDuration * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = peakTransparency }
	)
	local flashOut =
		TweenService:Create(flashFrame, TweenInfo.new(flashDuration * 0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })

	trackTween(flashIn)
	trackTween(flashOut)

	flashIn.Completed:Once(function()
		flashOut:Play()
		flashOut.Completed:Once(function()
			flashFrame:Destroy()
		end)
	end)

	return flashIn, flashFrame
end

local function spawnParticleBurst(parentFrame: GuiObject, color: Color3, count: number, deferPlay: boolean?): { Tween }
	local particleTweens: { Tween } = {}
	for _ = 1, count do
		local particle = particleTemplate:Clone()
		particle.Size = UDim2.fromOffset(rng:NextInteger(8, 16), rng:NextInteger(8, 16))
		particle.Position = UDim2.fromScale(0.5, 0.5)
		particle.BackgroundColor3 = color
		particle.Parent = parentFrame
		trackInstance(particle)

		local angle = rng:NextNumber(0, math.pi * 2)
		local speed = rng:NextNumber(120, 260)
		local targetX = math.cos(angle) * speed
		local targetY = math.sin(angle) * speed

		local duration = rng:NextNumber(0.65, 0.95)
		local tween = createTween(particle, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, targetX, 0.5, targetY),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(3, 3),
		})
		trackTween(tween)
		table.insert(particleTweens, tween)

		if not deferPlay then
			tween:Play()
		end

		tween.Completed:Once(function()
			particle:Destroy()
		end)
	end
	return particleTweens
end

local function triggerRingPulse(
	parentFrame: GuiObject,
	color: Color3,
	startScale: number,
	endScale: number,
	duration: number,
	soundCfg: any?,
	deferPlay: boolean?
): (Tween, Tween, GuiObject)
	local ring = Instance.new("Frame")
	ring.Name = "RingPulse"
	ring.Size = UDim2.fromScale(startScale, startScale)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.BorderSizePixel = 0
	ring.ZIndex = 30

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 0)
	corner.Parent = ring

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Transparency = 0.05
	stroke.Parent = ring

	ring.Parent = parentFrame
	trackInstance(ring)

	local tween = TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(endScale, endScale),
	})
	local strokeTween = TweenService:Create(stroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Thickness = 0.5,
	})

	trackTween(tween)
	trackTween(strokeTween)

	if not deferPlay then
		tween:Play()
		strokeTween:Play()
		if soundCfg then
			playSound(soundCfg)
		end
	end

	tween.Completed:Once(function()
		ring:Destroy()
	end)

	return tween, strokeTween, ring
end

local function triggerStarburstFlash(
	parentFrame: GuiObject,
	color: Color3,
	rayCount: number,
	rayLength: number,
	rayThickness: number,
	duration: number,
	soundCfg: any?,
	deferPlay: boolean?
): (Tween, { Tween }, GuiObject)
	local container = starburstTemplate:Clone()
	container.Position = UDim2.fromScale(0.5, 0.42)
	container.ZIndex = 35
	container.ClipsDescendants = false
	container.Parent = parentFrame
	trackInstance(container)

	local core = container:FindFirstChild("StarburstCore") :: GuiObject
	local coreTween = TweenService:Create(core, TweenInfo.new(duration * 0.45, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(56, 56),
		BackgroundTransparency = 1,
	})
	trackTween(coreTween)

	local rayTweens: { Tween } = {}
	local angleStep = (2 * math.pi) / rayCount
	local baseOffset = rng:NextNumber(0, math.pi * 2)

	local rayIndex = 0
	for _, child in container:GetChildren() do
		if child.Name == "StarburstRay" and child:IsA("GuiObject") then
			rayIndex += 1
			if rayIndex > rayCount then
				child:Destroy()
				continue
			end

			local angle = (rayIndex - 1) * angleStep + baseOffset
			child.Rotation = math.deg(angle)
			child.Size = UDim2.fromOffset(rayThickness, 30)
			child.BackgroundColor3 = color

			local grad = child:FindFirstChildOfClass("UIGradient")
			if grad and color ~= GOLD_COLOR then
				grad.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
					ColorSequenceKeypoint.new(0.35, color),
					ColorSequenceKeypoint.new(1, color),
				})
			end

			local rayTween = TweenService:Create(child, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(rayThickness, rayLength),
				BackgroundTransparency = 1,
			})
			trackTween(rayTween)
			table.insert(rayTweens, rayTween)
		end
	end

	local rotTween = TweenService:Create(container, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Rotation = 35,
	})
	trackTween(rotTween)
	table.insert(rayTweens, rotTween)

	if not deferPlay then
		coreTween:Play()
		for _, rt in rayTweens do
			rt:Play()
		end
		if soundCfg then
			playSound(soundCfg)
		end
	end

	task.delay(duration, function()
		container:Destroy()
	end)

	return coreTween, rayTweens, container
end

local function triggerLightPillar(
	slotFrame: GuiObject,
	overlayFrame: GuiObject?,
	color: Color3,
	baseWidth: number,
	height: number,
	duration: number,
	soundCfg: any?,
	stingerCfg: any?,
	deferPlay: boolean?
): (Tween, Tween, GuiObject)
	local targetParent = overlayFrame or slotFrame.Parent or slotFrame
	local slotPos = slotFrame.AbsolutePosition
	local slotSize = slotFrame.AbsoluteSize
	local parentPos = (targetParent :: GuiObject).AbsolutePosition

	local posX = (slotPos.X - parentPos.X) + (slotSize.X / 2)
	local posY = (slotPos.Y - parentPos.Y) + slotSize.Y + 20

	local pillarContainer = lightPillarTemplate:Clone()
	pillarContainer.Size = UDim2.fromOffset(baseWidth, height)
	pillarContainer.Position = UDim2.fromOffset(posX, posY)
	pillarContainer.Parent = targetParent
	trackInstance(pillarContainer)

	local outerBeam = pillarContainer:FindFirstChild("OuterBeam") :: GuiObject
	local innerCore = pillarContainer:FindFirstChild("InnerCore") :: GuiObject
	outerBeam.BackgroundColor3 = color

	outerBeam.Size = UDim2.new(1, 0, 0, math.max(160, slotSize.Y * 0.6))
	innerCore.Size = UDim2.new(0.38, 0, 0, math.max(140, slotSize.Y * 0.55))

	local shootUpOuter =
		TweenService:Create(outerBeam, TweenInfo.new(duration * 0.28, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) })
	local shootUpInner =
		TweenService:Create(innerCore, TweenInfo.new(duration * 0.24, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.38, 0.95) })

	local fadeOuter =
		TweenService:Create(outerBeam, TweenInfo.new(duration * 0.48, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
	local fadeInner =
		TweenService:Create(innerCore, TweenInfo.new(duration * 0.52, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })

	trackTween(shootUpOuter)
	trackTween(shootUpInner)
	trackTween(fadeOuter)
	trackTween(fadeInner)

	if not deferPlay then
		shootUpOuter:Play()
		shootUpInner:Play()
		if soundCfg then
			CrateAudio.play(soundCfg, 1.0)
		end
		if stingerCfg then
			CrateAudio.play(stingerCfg, 0.85)
		end
	end

	task.delay(duration * 0.52, function()
		fadeOuter:Play()
		fadeInner:Play()
	end)

	shootUpOuter.Completed:Once(function()
		fadeOuter.Completed:Once(function()
			pillarContainer:Destroy()
		end)
	end)

	return shootUpOuter, shootUpInner, pillarContainer
end

local function triggerMythicVoidNova(
	slotFrame: GuiObject,
	overlayFrame: GuiObject?,
	_color: Color3,
	duration: number,
	soundsList: { any }?,
	deferPlay: boolean?
): { Tween }
	local targetParent = overlayFrame or slotFrame.Parent or slotFrame
	local slotPos = slotFrame.AbsolutePosition
	local slotSize = slotFrame.AbsoluteSize
	local parentPos = (targetParent :: GuiObject).AbsolutePosition

	local centerX = (slotPos.X - parentPos.X) + (slotSize.X / 2)
	local centerY = (slotPos.Y - parentPos.Y) + (slotSize.Y / 2)
	local bottomY = (slotPos.Y - parentPos.Y) + slotSize.Y + 20

	local mythicGrad = CratesConfig.RarityGradients.Mythic
	local initialTweens: { Tween } = {}

	if overlayFrame then
		local voidDim = Instance.new("Frame")
		voidDim.Name = "MythicVoidDim"
		voidDim.Size = UDim2.fromScale(1, 1)
		voidDim.Position = UDim2.fromScale(0, 0)
		voidDim.BackgroundColor3 = Color3.fromRGB(4, 4, 7)
		voidDim.BackgroundTransparency = 1
		voidDim.BorderSizePixel = 0
		voidDim.ZIndex = 1
		voidDim.Parent = overlayFrame
		trackInstance(voidDim)

		local dimIn =
			TweenService:Create(voidDim, TweenInfo.new(duration * 0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { BackgroundTransparency = 0.15 })
		local dimOut =
			TweenService:Create(voidDim, TweenInfo.new(duration * 0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
		trackTween(dimIn)
		trackTween(dimOut)
		table.insert(initialTweens, dimIn)

		if not deferPlay then
			dimIn:Play()
			if soundsList and #soundsList > 0 then
				CrateAudio.playAll(soundsList, 1.0)
			end
		end

		task.delay(duration * 0.45, function()
			dimOut:Play()
			dimOut.Completed:Once(function()
				voidDim:Destroy()
			end)
		end)
	end

	local baseWidth = 420
	local height = 840
	local pillarContainer = Instance.new("Frame")
	pillarContainer.Name = "MythicAscensionPillar"
	pillarContainer.Size = UDim2.fromOffset(baseWidth, height)
	pillarContainer.Position = UDim2.fromOffset(centerX, bottomY)
	pillarContainer.AnchorPoint = Vector2.new(0.5, 1)
	pillarContainer.BackgroundTransparency = 1
	pillarContainer.BorderSizePixel = 0
	pillarContainer.ZIndex = 2
	pillarContainer.ClipsDescendants = false
	pillarContainer.Parent = targetParent
	trackInstance(pillarContainer)

	local outerBeam = Instance.new("Frame")
	outerBeam.Name = "OuterBeam"
	outerBeam.Size = UDim2.new(1, 0, 0, 50)
	outerBeam.Position = UDim2.fromScale(0.5, 1)
	outerBeam.AnchorPoint = Vector2.new(0.5, 1)
	outerBeam.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	outerBeam.BackgroundTransparency = 0.15
	outerBeam.BorderSizePixel = 0
	outerBeam.ZIndex = 2

	if mythicGrad then
		local bgGrad = Instance.new("UIGradient")
		bgGrad.Color = mythicGrad
		bgGrad.Rotation = -90
		bgGrad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.5, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		})
		bgGrad.Parent = outerBeam
	end
	outerBeam.Parent = pillarContainer

	local innerCore = Instance.new("Frame")
	innerCore.Name = "InnerCore"
	innerCore.Size = UDim2.new(0.42, 0, 0, 50)
	innerCore.Position = UDim2.fromScale(0.5, 1)
	innerCore.AnchorPoint = Vector2.new(0.5, 1)
	innerCore.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	innerCore.BackgroundTransparency = 0.02
	innerCore.BorderSizePixel = 0
	innerCore.ZIndex = 3
	innerCore.Parent = pillarContainer

	local innerGrad = Instance.new("UIGradient")
	innerGrad.Rotation = -90
	innerGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.0),
		NumberSequenceKeypoint.new(0.7, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	innerGrad.Parent = innerCore

	local shootUpOuter =
		TweenService:Create(outerBeam, TweenInfo.new(duration * 0.38, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) })
	local shootUpInner =
		TweenService:Create(innerCore, TweenInfo.new(duration * 0.32, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.42, 0.95) })
	local fadeOuter =
		TweenService:Create(outerBeam, TweenInfo.new(duration * 0.62, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
	local fadeInner =
		TweenService:Create(innerCore, TweenInfo.new(duration * 0.68, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })

	trackTween(shootUpOuter)
	trackTween(shootUpInner)
	trackTween(fadeOuter)
	trackTween(fadeInner)
	table.insert(initialTweens, shootUpOuter)
	table.insert(initialTweens, shootUpInner)

	if not deferPlay then
		shootUpOuter:Play()
		shootUpInner:Play()
	end

	task.delay(duration * 0.38, function()
		fadeOuter:Play()
		fadeInner:Play()
	end)

	shootUpOuter.Completed:Once(function()
		fadeOuter.Completed:Once(function()
			pillarContainer:Destroy()
		end)
	end)

	for ringIdx = 1, 2 do
		local ringDelay = (ringIdx - 1) * 0.12
		task.delay(ringDelay, function()
			local ring = Instance.new("Frame")
			ring.Name = "MythicShockwaveRing_" .. tostring(ringIdx)
			ring.Size = UDim2.fromOffset(slotSize.X * 0.3, slotSize.X * 0.3)
			ring.Position = UDim2.fromOffset(centerX, centerY)
			ring.AnchorPoint = Vector2.new(0.5, 0.5)
			ring.BackgroundTransparency = 1
			ring.BorderSizePixel = 0
			ring.ZIndex = 8
			ring.Parent = targetParent
			trackInstance(ring)

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = ring

			local stroke = Instance.new("UIStroke")
			stroke.Thickness = if ringIdx == 1 then 3.5 else 2.0
			stroke.Color = WHITE_COLOR
			stroke.Transparency = 0.1
			if mythicGrad then
				local strokeGrad = Instance.new("UIGradient")
				strokeGrad.Color = mythicGrad
				strokeGrad.Rotation = 45 * ringIdx
				strokeGrad.Parent = stroke
			end
			stroke.Parent = ring

			local endDiameter = math.max(slotSize.X, slotSize.Y) * (2.2 + ringIdx * 0.4)
			local expandTween = createTween(
				ring,
				TweenInfo.new(duration * 0.65, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
				{ Size = UDim2.fromOffset(endDiameter, endDiameter) }
			)
			local fadeStrokeTween = createTween(stroke, TweenInfo.new(duration * 0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })

			trackTween(expandTween)
			trackTween(fadeStrokeTween)
			expandTween:Play()
			fadeStrokeTween:Play()

			expandTween.Completed:Once(function()
				ring:Destroy()
			end)
		end)
	end

	local flareContainer = Instance.new("Frame")
	flareContainer.Name = "MythicFlares"
	flareContainer.Size = UDim2.fromOffset(slotSize.X * 2.6, slotSize.X * 2.6)
	flareContainer.Position = UDim2.fromOffset(centerX, centerY)
	flareContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	flareContainer.BackgroundTransparency = 1
	flareContainer.BorderSizePixel = 0
	flareContainer.ZIndex = 7
	flareContainer.Parent = targetParent
	trackInstance(flareContainer)

	local flare1 = Instance.new("ImageLabel")
	flare1.Name = "FlareCW"
	flare1.Size = UDim2.fromScale(0.3, 0.3)
	flare1.Position = UDim2.fromScale(0.5, 0.5)
	flare1.AnchorPoint = Vector2.new(0.5, 0.5)
	flare1.BackgroundTransparency = 1
	flare1.Image = "rbxassetid://11037779268"
	flare1.ImageColor3 = Color3.fromRGB(255, 255, 255)
	flare1.ImageTransparency = 0.1
	flare1.ScaleType = Enum.ScaleType.Fit
	flare1.ZIndex = 7
	flare1.Parent = flareContainer

	local flare2 = Instance.new("ImageLabel")
	flare2.Name = "FlareCCW"
	flare2.Size = UDim2.fromScale(0.4, 0.4)
	flare2.Position = UDim2.fromScale(0.5, 0.5)
	flare2.AnchorPoint = Vector2.new(0.5, 0.5)
	flare2.BackgroundTransparency = 1
	flare2.Image = "rbxassetid://11037779268"
	flare2.ImageColor3 = Color3.fromRGB(255, 255, 255)
	flare2.ImageTransparency = 0.25
	flare2.ScaleType = Enum.ScaleType.Fit
	flare2.ZIndex = 7

	if mythicGrad then
		local flareGrad = Instance.new("UIGradient")
		flareGrad.Color = mythicGrad
		flareGrad.Rotation = 90
		flareGrad.Parent = flare2
	end
	flare2.Parent = flareContainer

	local rotTween1 = TweenService:Create(flare1, TweenInfo.new(duration * 0.8, Enum.EasingStyle.Linear), { Rotation = 180, Size = UDim2.fromScale(1.0, 1.0) })
	local rotTween2 = TweenService:Create(flare2, TweenInfo.new(duration * 0.8, Enum.EasingStyle.Linear), { Rotation = -180, Size = UDim2.fromScale(1.2, 1.2) })
	local fadeFlare1 = TweenService:Create(flare1, TweenInfo.new(duration * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { ImageTransparency = 1 })
	local fadeFlare2 = TweenService:Create(flare2, TweenInfo.new(duration * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { ImageTransparency = 1 })

	trackTween(rotTween1)
	trackTween(rotTween2)
	trackTween(fadeFlare1)
	trackTween(fadeFlare2)
	table.insert(initialTweens, rotTween1)
	table.insert(initialTweens, rotTween2)
	table.insert(initialTweens, fadeFlare1)
	table.insert(initialTweens, fadeFlare2)

	if not deferPlay then
		rotTween1:Play()
		rotTween2:Play()
		fadeFlare1:Play()
		fadeFlare2:Play()
	end

	fadeFlare1.Completed:Once(function()
		flareContainer:Destroy()
	end)

	return initialTweens
end

export type RevealTriggerOptions = {
	isDuplicate: boolean?,
	hasLegendaryEscalation: boolean?,
}

function RevealEffects.trigger(rarity: CrateRarity, slotInstance: GuiObject?, overlayFrame: GuiObject?, options: RevealTriggerOptions?)
	local effectCfg = (CratesConfig.EFFECTS :: any)[rarity]
	if not effectCfg then
		return
	end

	local rarityColor = CratesConfig.getRarityColor(rarity)
	local tweensToPlay: { Tween } = {}
	local soundToPlay: any = effectCfg.Sound
	local multiSoundsToPlay: { any }? = nil
	local stingerToPlay: any = nil

	if slotInstance then
		if rarity == "Uncommon" and effectCfg.RingPulse then
			local tween, strokeTween = triggerRingPulse(
				slotInstance,
				effectCfg.RingPulse.Color or rarityColor,
				effectCfg.RingPulse.StartScale or 0.85,
				effectCfg.RingPulse.EndScale or 1.35,
				effectCfg.RingPulse.Duration or 0.4,
				nil,
				true
			)
			table.insert(tweensToPlay, tween)
			table.insert(tweensToPlay, strokeTween)
		elseif rarity == "Rare" and effectCfg.Starburst then
			local coreTween, rayTweens = triggerStarburstFlash(
				slotInstance,
				rarityColor,
				effectCfg.Starburst.RayCount or 10,
				effectCfg.Starburst.RayLength or 180,
				effectCfg.Starburst.RayThickness or 3,
				effectCfg.Starburst.Duration or 0.35,
				nil,
				true
			)
			table.insert(tweensToPlay, coreTween)
			for _, rt in rayTweens do
				table.insert(tweensToPlay, rt)
			end

			if effectCfg.VignetteFlash and overlayFrame then
				local flashIn = prepareVignetteFlash(overlayFrame, effectCfg.VignetteFlash)
				if flashIn then
					table.insert(tweensToPlay, flashIn)
				end
			end

			if effectCfg.ParticleCount then
				local particleTweens = spawnParticleBurst(slotInstance, rarityColor, effectCfg.ParticleCount, true)
				for _, pt in particleTweens do
					table.insert(tweensToPlay, pt)
				end
			end
		elseif rarity == "Legendary" and effectCfg.LightPillar then
			local shootUpOuter, shootUpInner = triggerLightPillar(
				slotInstance,
				overlayFrame,
				rarityColor,
				effectCfg.LightPillar.BaseWidth or 360,
				effectCfg.LightPillar.Height or 760,
				effectCfg.LightPillar.Duration or 0.95,
				nil,
				nil,
				true
			)
			table.insert(tweensToPlay, shootUpOuter)
			table.insert(tweensToPlay, shootUpInner)

			if effectCfg.Sounds and typeof(effectCfg.Sounds) == "table" then
				multiSoundsToPlay = effectCfg.Sounds
				soundToPlay = nil
			elseif options and options.hasLegendaryEscalation then
				stingerToPlay = effectCfg.StingerLayer
					or (CratesConfig.BOX_ANIMATIONS.LegendaryOverlay.Sounds and CratesConfig.BOX_ANIMATIONS.LegendaryOverlay.Sounds.StingerLayer)
			end

			if effectCfg.ParticleCount then
				local particleTweens = spawnParticleBurst(slotInstance, rarityColor, effectCfg.ParticleCount, true)
				for _, pt in particleTweens do
					table.insert(tweensToPlay, pt)
				end
			end

			if effectCfg.ScreenShake and overlayFrame then
				local magnitude = effectCfg.ScreenShake.Magnitude or 5
				local shakeDuration = effectCfg.ScreenShake.Duration or 0.85
				local shakeThread = task.spawn(function()
					local startTime = os.clock()
					while (os.clock() - startTime) < shakeDuration do
						local elapsed = os.clock() - startTime
						local progress = math.clamp(elapsed / shakeDuration, 0, 1)
						local currentMag = magnitude * (1 - (progress * progress))
						local offsetX = rng:NextNumber(-currentMag, currentMag)
						local offsetY = rng:NextNumber(-currentMag, currentMag)
						overlayFrame.Position = UDim2.fromOffset(offsetX, offsetY)
						task.wait(0.02)
					end
					overlayFrame.Position = UDim2.fromScale(0, 0)
				end)
				table.insert(activeThreads, shakeThread)
			end
		elseif rarity == "Mythic" then
			local duration = (effectCfg.LightPillar and effectCfg.LightPillar.Duration) or 0.85
			local mythicTweens = triggerMythicVoidNova(slotInstance, overlayFrame, rarityColor, duration, nil, true)
			for _, mt in mythicTweens do
				table.insert(tweensToPlay, mt)
			end
			multiSoundsToPlay = effectCfg.Sounds
			soundToPlay = nil
		end
	else
		if effectCfg.Sounds and typeof(effectCfg.Sounds) == "table" then
			multiSoundsToPlay = effectCfg.Sounds
			soundToPlay = nil
		end
	end

	for _, tween in tweensToPlay do
		tween:Play()
	end

	if multiSoundsToPlay and #multiSoundsToPlay > 0 then
		CrateAudio.playAll(multiSoundsToPlay, if rarity == "Mythic" or rarity == "Legendary" then 1.0 else 0.8)
	elseif soundToPlay then
		playSound(soundToPlay, if rarity == "Mythic" or rarity == "Legendary" then 1.0 else 0.8)
	end

	if stingerToPlay then
		CrateAudio.play(stingerToPlay, 0.85)
	end

	if options and options.isDuplicate and CratesConfig.DUPLICATE_SOUND then
		task.spawn(playSound, CratesConfig.DUPLICATE_SOUND, 0.80)
	end
end

function RevealEffects.triggerVignetteFlash(targetFrame: GuiObject, color: Color3, duration: number?, peakTransparency: number?)
	local flashDuration = duration or 0.35
	local peakTrans = peakTransparency or 0.70

	local rootParent: Instance = targetFrame:FindFirstAncestorWhichIsA("ScreenGui") or targetFrame:FindFirstAncestor("Overlay") or targetFrame

	local flashFrame = Instance.new("Frame")
	flashFrame.Name = "FullScreenVignetteFlash"
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.Position = UDim2.fromScale(0, 0)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.ZIndex = 100
	flashFrame.Parent = rootParent
	trackInstance(flashFrame)

	local flashIn = TweenService:Create(
		flashFrame,
		TweenInfo.new(flashDuration * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = peakTrans }
	)
	local flashOut =
		TweenService:Create(flashFrame, TweenInfo.new(flashDuration * 0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })

	trackTween(flashIn)
	trackTween(flashOut)
	flashIn:Play()
	flashIn.Completed:Once(function()
		flashOut:Play()
		flashOut.Completed:Once(function()
			flashFrame:Destroy()
		end)
	end)
end

export type SeamBreachConfig = {
	color: Color3,
	width: number?,
	seamYScale: number?,
	maxBreachHeight: number?,
	glowBloomWidth: number?,
	glowBloomHeight: number?,
	beamWidth: number?,
	beamHeight: number?,
	beamDuration: number?,
	dimAlpha: number?,
}

export type SeamBreachController = {
	setAnticipation: (alpha: number, customYScale: number?) -> (),
	setBreachProgress: (progress: number, brightnessMult: number?, customYScale: number?, customGapHeight: number?) -> (),
	triggerBurst: (duration: number?, customYScale: number?) -> (),
	destroy: () -> (),
}

function RevealEffects.createSeamBreach(parent: GuiObject, config: SeamBreachConfig): SeamBreachController
	local color = config.color
	local width = config.width or 260
	local seamY = config.seamYScale or 0.46
	local maxH = config.maxBreachHeight or 16
	local bloomW = config.glowBloomWidth or 340
	local bloomH = config.glowBloomHeight or 75
	local beamW = config.beamWidth or 140
	local beamH = config.beamHeight or 420
	local beamDur = config.beamDuration or 0.40

	local seamContainer = Instance.new("Frame")
	seamContainer.Name = "SeamBreachContainer"
	seamContainer.Size = UDim2.fromOffset(width, 40)
	seamContainer.Position = UDim2.fromScale(0.5, seamY)
	seamContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	seamContainer.BackgroundTransparency = 1
	seamContainer.BorderSizePixel = 0
	seamContainer.ZIndex = 4
	seamContainer.ClipsDescendants = false
	seamContainer.Parent = parent
	trackInstance(seamContainer)

	local glowBloom = Instance.new("ImageLabel")
	glowBloom.Name = "SeamGlowBloom"
	glowBloom.Size = UDim2.fromOffset(bloomW, bloomH)
	glowBloom.Position = UDim2.fromScale(0.5, 0.5)
	glowBloom.AnchorPoint = Vector2.new(0.5, 0.5)
	glowBloom.BackgroundTransparency = 1
	glowBloom.Image = "rbxassetid://11037779268"
	glowBloom.ImageColor3 = color
	glowBloom.ImageTransparency = 1
	glowBloom.ScaleType = Enum.ScaleType.Fit
	glowBloom.ZIndex = 4
	glowBloom.Parent = seamContainer

	local outerGlow = Instance.new("Frame")
	outerGlow.Name = "SeamOuterGlow"
	outerGlow.Size = UDim2.fromOffset(width, 3)
	outerGlow.Position = UDim2.fromScale(0.5, 0.5)
	outerGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	outerGlow.BackgroundColor3 = color
	outerGlow.BackgroundTransparency = 1
	outerGlow.BorderSizePixel = 0
	outerGlow.ZIndex = 5

	local outerCorner = Instance.new("UICorner")
	outerCorner.CornerRadius = UDim.new(0.5, 0)
	outerCorner.Parent = outerGlow

	local outerGrad = Instance.new("UIGradient")
	outerGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.15),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.85, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	outerGrad.Parent = outerGlow
	outerGlow.Parent = seamContainer

	local coreLine = Instance.new("Frame")
	coreLine.Name = "SeamCoreLine"
	coreLine.Size = UDim2.fromOffset(width * 0.85, 2)
	coreLine.Position = UDim2.fromScale(0.5, 0.5)
	coreLine.AnchorPoint = Vector2.new(0.5, 0.5)
	coreLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	coreLine.BackgroundTransparency = 1
	coreLine.BorderSizePixel = 0
	coreLine.ZIndex = 6

	local coreCorner = Instance.new("UICorner")
	coreCorner.CornerRadius = UDim.new(0.5, 0)
	coreCorner.Parent = coreLine

	local coreGrad = Instance.new("UIGradient")
	coreGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0),
		NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	coreGrad.Parent = coreLine
	coreLine.Parent = seamContainer

	local isDestroyed = false

	local controller: SeamBreachController = {
		setAnticipation = function(alpha: number, customYScale: number?)
			if isDestroyed then
				return
			end
			local a = math.clamp(alpha, 0, 1)
			if customYScale then
				seamContainer.Position = UDim2.fromScale(0.5, customYScale)
			end
			outerGlow.BackgroundTransparency = 1 - (a * 0.65)
			coreLine.BackgroundTransparency = 1 - (a * 0.40)
			glowBloom.ImageTransparency = 1 - (a * 0.25)
			outerGlow.Size = UDim2.fromOffset(width, 3)
			coreLine.Size = UDim2.fromOffset(width * 0.85, 2)
		end,

		setBreachProgress = function(progress: number, brightnessMult: number?, customYScale: number?, customGapHeight: number?)
			if isDestroyed then
				return
			end
			local p = math.clamp(progress, 0, 1)
			local bMult = brightnessMult or 1.0

			if customYScale then
				seamContainer.Position = UDim2.fromScale(0.5, customYScale)
			end

			local curH = if customGapHeight then math.clamp(customGapHeight, 3, 160) else 3 + (maxH - 3) * p
			local curCoreH = math.max(2, curH * 0.45)
			outerGlow.Size = UDim2.fromOffset(width * (1 + 0.12 * p), curH)
			coreLine.Size = UDim2.fromOffset(width * (0.85 + 0.15 * p), curCoreH)

			local baseOuterTrans = 0.35 * (1 - p)
			local baseCoreTrans = 0.15 * (1 - p)
			local baseBloomTrans = 0.75 - (0.55 * p)

			outerGlow.BackgroundTransparency = math.clamp(1 - (1 - baseOuterTrans) * bMult, 0, 1)
			coreLine.BackgroundTransparency = math.clamp(1 - (1 - baseCoreTrans) * bMult, 0, 1)
			glowBloom.ImageTransparency = math.clamp(1 - (1 - baseBloomTrans) * bMult, 0, 1)

			local bloomScaleY = if customGapHeight then math.max(bloomH * (0.75 + 0.50 * p), curH * 1.4) else bloomH * (0.75 + 0.50 * p)
			glowBloom.Size = UDim2.fromOffset(bloomW * (0.85 + 0.25 * p), bloomScaleY)
		end,

		triggerBurst = function(dur: number?, customYScale: number?)
			if isDestroyed then
				return
			end
			local d = dur or beamDur

			if customYScale then
				seamContainer.Position = UDim2.fromScale(0.5, customYScale)
			end

			local fadeOuter = TweenService:Create(outerGlow, TweenInfo.new(d * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			})
			local fadeCore = TweenService:Create(coreLine, TweenInfo.new(d * 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			})
			local fadeBloom = TweenService:Create(glowBloom, TweenInfo.new(d * 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				ImageTransparency = 1,
			})
			trackTween(fadeOuter)
			trackTween(fadeCore)
			trackTween(fadeBloom)
			fadeOuter:Play()
			fadeCore:Play()
			fadeBloom:Play()

			local beamContainer = Instance.new("Frame")
			beamContainer.Name = "SeamBurstBeam"
			beamContainer.Size = UDim2.fromOffset(beamW, beamH)
			beamContainer.Position = UDim2.fromScale(0.5, 0.5)
			beamContainer.AnchorPoint = Vector2.new(0.5, 1)
			beamContainer.BackgroundTransparency = 1
			beamContainer.BorderSizePixel = 0
			beamContainer.ZIndex = 5
			beamContainer.ClipsDescendants = false
			beamContainer.Parent = seamContainer
			trackInstance(beamContainer)

			local outerBeam = Instance.new("Frame")
			outerBeam.Name = "OuterBeam"
			outerBeam.Size = UDim2.new(1, 0, 0, 20)
			outerBeam.Position = UDim2.fromScale(0.5, 1)
			outerBeam.AnchorPoint = Vector2.new(0.5, 1)
			outerBeam.BackgroundColor3 = color
			outerBeam.BackgroundTransparency = 0.2
			outerBeam.BorderSizePixel = 0
			outerBeam.ZIndex = 5

			local outerBeamGrad = Instance.new("UIGradient")
			outerBeamGrad.Rotation = -90
			outerBeamGrad.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.45, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			})
			outerBeamGrad.Parent = outerBeam
			outerBeam.Parent = beamContainer

			local innerBeamCore = Instance.new("Frame")
			innerBeamCore.Name = "InnerBeamCore"
			innerBeamCore.Size = UDim2.new(0.36, 0, 0, 20)
			innerBeamCore.Position = UDim2.fromScale(0.5, 1)
			innerBeamCore.AnchorPoint = Vector2.new(0.5, 1)
			innerBeamCore.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			innerBeamCore.BackgroundTransparency = 0.05
			innerBeamCore.BorderSizePixel = 0
			innerBeamCore.ZIndex = 6

			local innerBeamGrad = Instance.new("UIGradient")
			innerBeamGrad.Rotation = -90
			innerBeamGrad.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.0),
				NumberSequenceKeypoint.new(0.55, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			})
			innerBeamGrad.Parent = innerBeamCore
			innerBeamCore.Parent = beamContainer

			local shootOuter = TweenService:Create(outerBeam, TweenInfo.new(d * 0.45, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(1, 1),
			})
			local shootInner = TweenService:Create(innerBeamCore, TweenInfo.new(d * 0.40, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(0.36, 0.92),
			})
			local fadeOuterBeam = TweenService:Create(outerBeam, TweenInfo.new(d * 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
			})
			local fadeInnerBeam = TweenService:Create(innerBeamCore, TweenInfo.new(d * 0.60, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
			})

			trackTween(shootOuter)
			trackTween(shootInner)
			trackTween(fadeOuterBeam)
			trackTween(fadeInnerBeam)

			shootOuter:Play()
			shootInner:Play()

			task.delay(d * 0.35, function()
				fadeOuterBeam:Play()
				fadeInnerBeam:Play()
			end)

			shootOuter.Completed:Once(function()
				fadeOuterBeam.Completed:Once(function()
					beamContainer:Destroy()
				end)
			end)
		end,

		destroy = function()
			if isDestroyed then
				return
			end
			isDestroyed = true
			pcall(function()
				seamContainer:Destroy()
			end)
		end,
	}

	return controller
end

function RevealEffects.cleanup()
	for _, threadObj in activeThreads do
		pcall(task.cancel, threadObj)
	end
	table.clear(activeThreads)

	for _, tween in activeTweens do
		pcall(function()
			tween:Cancel()
		end)
	end
	table.clear(activeTweens)

	for _, sound in activeSounds do
		pcall(function()
			sound:Stop()
			sound:Destroy()
		end)
	end
	table.clear(activeSounds)

	for _, inst in activeInstances do
		pcall(function()
			inst:Destroy()
		end)
	end
	table.clear(activeInstances)
end

return RevealEffects
