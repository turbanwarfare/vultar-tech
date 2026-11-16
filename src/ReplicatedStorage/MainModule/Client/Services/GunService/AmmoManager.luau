--!strict
--!native
--!optimize 2

export type AmmoState = {
	current: number,
	max: number,
	gunIndex: number,
}

export type AmmoCallbacks = {
	onAmmoChanged: (current: number) -> (),
}

local MainModule = script.Parent.Parent.Parent.Parent
local GunStats = require(MainModule.Shared.Config.GunStats)

local AmmoManager = {}

local toolAmmo: { [string]: number } = {}
local backgroundRechargeTasks: { [string]: thread } = {}

local GUN_NAME_TO_INDEX = GunStats.GUN_NAME_TO_INDEX

function AmmoManager.getGunIndex(toolName: string): number
	return GUN_NAME_TO_INDEX[toolName] or 1
end

function AmmoManager.getStoredAmmo(toolName: string, maxAmmo: number): number
	local stored = toolAmmo[toolName]
	if stored ~= nil then
		return stored
	end
	return maxAmmo
end

function AmmoManager.storeAmmo(toolName: string, ammo: number): ()
	toolAmmo[toolName] = ammo
end

function AmmoManager.clearStoredAmmo(): ()
	table.clear(toolAmmo)
end

function AmmoManager.isBackgroundRecharging(toolName: string): boolean
	return backgroundRechargeTasks[toolName] ~= nil
end

function AmmoManager.cancelBackgroundRecharge(toolName: string?): ()
	if toolName then
		local task_thread = backgroundRechargeTasks[toolName]
		if task_thread then
			task.cancel(task_thread)
			backgroundRechargeTasks[toolName] = nil
		end
	else
		for name, task_thread in backgroundRechargeTasks do
			task.cancel(task_thread)
			backgroundRechargeTasks[name] = nil
		end
	end
end

function AmmoManager.startBackgroundRecharge(toolName: string, maxAmmo: number, rechargeRate: number): ()
	if backgroundRechargeTasks[toolName] then
		task.cancel(backgroundRechargeTasks[toolName])
	end

	backgroundRechargeTasks[toolName] = task.spawn(function()
		while toolAmmo[toolName] ~= nil and toolAmmo[toolName] < maxAmmo do
			task.wait(1 / rechargeRate)
			if toolAmmo[toolName] ~= nil and toolAmmo[toolName] < maxAmmo then
				toolAmmo[toolName] = toolAmmo[toolName] + 1
			end
		end

		backgroundRechargeTasks[toolName] = nil
	end)
end

function AmmoManager.cleanup(): ()
	AmmoManager.cancelBackgroundRecharge()
	AmmoManager.clearStoredAmmo()
end

return AmmoManager
