--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local Cache = require(script.Parent.Cache)

export type ReloadCallbacks = {
	onAmmoChanged: (current: number) -> (),
	onReloadComplete: () -> (),
	stopFiring: () -> (),
}

local ReloadController = {}

local player = Players.LocalPlayer

local isReloading: boolean = false
local reloadTask: thread? = nil

local chargeSound: Sound? = nil
local fullChargeSound: Sound? = nil

function ReloadController.init(): ()
	chargeSound = Instance.new("Sound")
	chargeSound.SoundId = "rbxassetid://4499400560"
	chargeSound.Volume = 0.5
	chargeSound.Looped = true

	fullChargeSound = Instance.new("Sound")
	fullChargeSound.SoundId = "rbxassetid://9125644905"
	fullChargeSound.Volume = 0.7

	chargeSound.Parent = player.PlayerGui
	fullChargeSound.Parent = player.PlayerGui
end

local function stopReloadSounds(): ()
	if chargeSound and chargeSound.IsPlaying then
		chargeSound:Stop()
	end
end

local function playReloadStartSound(): ()
	if not Cache.getWeaponSoundsEnabled() then return end
	if chargeSound then
		chargeSound:Play()
	end
end

local function playReloadCompleteSound(): ()
	stopReloadSounds()
	if not Cache.getWeaponSoundsEnabled() then return end
	if fullChargeSound then
		fullChargeSound:Play()
	end
end

function ReloadController.isReloading(): boolean
	return isReloading
end

function ReloadController.start(
	currentAmmo: number,
	maxAmmo: number,
	rechargePerSecond: number,
	callbacks: ReloadCallbacks
): ()
	if isReloading then
		return
	end

	if currentAmmo >= maxAmmo then return end

	isReloading = true
	callbacks.stopFiring()
	playReloadStartSound()

	local rechargePerBullet = 1 / rechargePerSecond
	local ammo = currentAmmo

	if reloadTask then
		task.cancel(reloadTask)
		reloadTask = nil
	end

	reloadTask = task.spawn(function()
		while isReloading do
			task.wait(rechargePerBullet)

			if not isReloading then
				stopReloadSounds()
				break
			end

			ammo += 1
			callbacks.onAmmoChanged(ammo)

			if ammo >= maxAmmo then
				isReloading = false
				playReloadCompleteSound()
				callbacks.onReloadComplete()
				break
			end
		end
		reloadTask = nil
	end)
end

function ReloadController.reset(): boolean
	local wasReloading = isReloading
	isReloading = false
	stopReloadSounds()
	if reloadTask then
		task.cancel(reloadTask)
		reloadTask = nil
	end
	return wasReloading
end

function ReloadController.cleanup(): ()
	ReloadController.reset()

	if chargeSound then
		chargeSound:Destroy()
		chargeSound = nil
	end
	if fullChargeSound then
		fullChargeSound:Destroy()
		fullChargeSound = nil
	end
end

return ReloadController
