--!strict
--!native
--!optimize 2

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local BlurEffect = {}

local KNOWN_BLUR_NAMES = {
	"LoadingBlur",
	"LoadingServiceBlur",
	"WinScreenBlur",
	"MenuBlur",
	"DeployBlur",
}

local MAX_BLUR_LIFETIME = 30
local KNOWN_BLUR_SET: { [string]: boolean } = {}
for _, blurName in KNOWN_BLUR_NAMES do
	KNOWN_BLUR_SET[blurName] = true
end

export type BlurHandle = {
	instance: BlurEffect,
	tween: Tween?,
}

function BlurEffect.create(name: string, initialSize: number?): BlurEffect
	BlurEffect.forceRemove(name)

	local blur = Instance.new("BlurEffect")
	blur.Name = name
	blur.Size = initialSize or 0
	blur.Enabled = true
	blur.Parent = Lighting

	task.delay(MAX_BLUR_LIFETIME, function()
		if blur and blur.Parent then
			blur:Destroy()
		end
	end)

	return blur
end

function BlurEffect.tweenTo(
	blur: BlurEffect,
	targetSize: number,
	duration: number?,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?
): Tween
	local tweenInfo = TweenInfo.new(
		duration or 0.3,
		easingStyle or Enum.EasingStyle.Quad,
		easingDirection or Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(blur, tweenInfo, { Size = targetSize })
	tween:Play()

	return tween
end

function BlurEffect.fadeOutAndDestroy(blur: BlurEffect, duration: number?, onComplete: (() -> ())?): ()
	local fadeDuration = duration or 0.5
	local destroyed = false

	local function safeDestroy()
		if destroyed then
			return
		end
		destroyed = true
		if blur and blur.Parent then
			blur:Destroy()
		end
		if onComplete then
			onComplete()
		end
	end

	local tween = TweenService:Create(
		blur,
		TweenInfo.new(fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = 0 }
	)

	tween.Completed:Once(safeDestroy)
	tween:Play()

	task.delay(fadeDuration + 0.5, safeDestroy)
end

function BlurEffect.find(name: string): BlurEffect?
	local blur = Lighting:FindFirstChild(name)
	if blur and blur:IsA("BlurEffect") then
		return blur
	end
	return nil
end

function BlurEffect.forceRemove(name: string): ()
	local blur = Lighting:FindFirstChild(name)
	if blur and blur:IsA("BlurEffect") then
		blur:Destroy()
	end
end

function BlurEffect.getOrCreate(name: string, initialSize: number?): BlurEffect
	local existing = BlurEffect.find(name)
	if existing then
		return existing
	end

	return BlurEffect.create(name, initialSize)
end

function BlurEffect.cleanupAll(): ()
	for _, child in Lighting:GetChildren() do
		if child:IsA("BlurEffect") and KNOWN_BLUR_SET[child.Name] then
			child:Destroy()
		end
	end
end

function BlurEffect.cleanupAllBlurs(): ()
	local blur = Lighting:FindFirstChildWhichIsA("BlurEffect")
	while blur do
		blur:Destroy()
		blur = Lighting:FindFirstChildWhichIsA("BlurEffect")
	end
end

return BlurEffect
