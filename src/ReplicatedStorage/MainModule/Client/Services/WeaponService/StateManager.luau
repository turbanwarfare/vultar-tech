--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local WeaponConfig = require(MainModule.Shared.Config.Weapons.WeaponConfig)

type WeaponState = WeaponConfig.WeaponState
type SpeedConfig = WeaponConfig.SpeedConfig

export type StateFlags = {
	isFiring: boolean,
	isSprinting: boolean,
	isCrouching: boolean,
	isZooming: boolean,
	isSaluting: boolean,
}

export type StateResult = {
	state: WeaponState,
	speed: number,
	animations: {
		play: { string },
		stop: { string },
	},
}

local StateManager = {}

local DEFAULT_STATE_FLAGS: StateFlags = {
	isFiring = false,
	isSprinting = false,
	isCrouching = false,
	isZooming = false,
	isSaluting = false,
}

function StateManager.createDefaultFlags(): StateFlags
	return table.clone(DEFAULT_STATE_FLAGS)
end

function StateManager.computeStateKey(flags: StateFlags): string
	local f = flags.isFiring and "f" or ""
	local s = flags.isSprinting and "s" or ""
	local c = flags.isCrouching and "c" or ""
	local z = flags.isZooming and "z" or ""
	local e = flags.isSaluting and "e" or ""
	return f .. s .. c .. z .. e
end

function StateManager.computeState(flags: StateFlags, speeds: SpeedConfig): StateResult
	local play: { string } = {}
	local stop: { string } = {}
	local state: WeaponState
	local speed: number

	if flags.isSaluting then
		table.insert(play, "Salute")
	else
		table.insert(stop, "Salute")
	end

	if flags.isFiring then
		if flags.isCrouching then
			state = "Crouching"
			speed = speeds.Crouch
			table.insert(stop, "Sprint")
			table.insert(stop, "Idle")
			table.insert(play, "Crouch")
		elseif flags.isSprinting then
			state = "Sprinting"
			speed = speeds.Sprint
			table.insert(stop, "Idle")
			table.insert(stop, "Crouch")
			table.insert(play, "Sprint")
		elseif flags.isZooming then
			state = "Idle"
			speed = speeds.Zoom
			table.insert(stop, "Sprint")
			table.insert(stop, "Crouch")
			table.insert(play, "Idle")
		else
			state = "Idle"
			speed = speeds.Walk
			table.insert(stop, "Sprint")
			table.insert(stop, "Crouch")
			table.insert(play, "Idle")
		end
	elseif flags.isSprinting then
		state = "Sprinting"
		speed = speeds.Sprint
		table.insert(stop, "Idle")
		table.insert(stop, "Crouch")
		table.insert(play, "Sprint")
	elseif flags.isZooming then
		state = "Idle"
		speed = speeds.Zoom
		table.insert(stop, "Sprint")
		table.insert(stop, "Crouch")
		table.insert(play, "Idle")
	elseif flags.isCrouching then
		state = "Crouching"
		speed = speeds.Crouch
		table.insert(stop, "Sprint")
		table.insert(play, "Crouch")
		table.insert(play, "Idle")
	else
		state = "Idle"
		speed = speeds.Walk
		table.insert(stop, "Sprint")
		table.insert(stop, "Crouch")
		table.insert(play, "Idle")
	end

	if flags.isSaluting then
		state = "Saluting"
	end

	return {
		state = state,
		speed = speed,
		animations = {
			play = play,
			stop = stop,
		},
	}
end

function StateManager.applyStartFiring(flags: StateFlags, canSprintWhileFiring: boolean?): StateFlags
	local newFlags = table.clone(flags)
	newFlags.isFiring = true
	if not canSprintWhileFiring then
		newFlags.isSprinting = false
	end
	return newFlags
end

function StateManager.applyStopFiring(flags: StateFlags): StateFlags
	local newFlags = table.clone(flags)
	newFlags.isFiring = false
	return newFlags
end

function StateManager.applyToggleSprint(flags: StateFlags, canSprintWhileFiring: boolean?): StateFlags?
	if flags.isFiring and not canSprintWhileFiring then
		return nil
	end

	local newFlags = table.clone(flags)
	if newFlags.isSprinting then
		newFlags.isSprinting = false
	else
		newFlags.isSprinting = true
		newFlags.isCrouching = false
	end
	return newFlags
end

function StateManager.applyToggleCrouch(flags: StateFlags): StateFlags
	local newFlags = table.clone(flags)
	if newFlags.isCrouching then
		newFlags.isCrouching = false
	else
		newFlags.isCrouching = true
		newFlags.isSprinting = false
	end
	return newFlags
end

function StateManager.applyToggleZoom(flags: StateFlags): StateFlags
	local newFlags = table.clone(flags)
	newFlags.isZooming = not newFlags.isZooming
	return newFlags
end

function StateManager.applyStartSalute(flags: StateFlags): StateFlags?
	if flags.isFiring then
		return nil
	end

	local newFlags = table.clone(flags)
	newFlags.isSaluting = true
	return newFlags
end

function StateManager.applyStopSalute(flags: StateFlags): StateFlags?
	if not flags.isSaluting then
		return nil
	end

	local newFlags = table.clone(flags)
	newFlags.isSaluting = false
	return newFlags
end

function StateManager.applyJump(flags: StateFlags): StateFlags?
	if not flags.isCrouching then
		return nil
	end

	local newFlags = table.clone(flags)
	newFlags.isCrouching = false
	return newFlags
end

return StateManager
