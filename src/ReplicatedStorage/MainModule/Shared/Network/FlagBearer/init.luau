--!strict
--!native
--!optimize 2

local Types = require(script.Types)

export type AbilityStatus = Types.AbilityStatus

local FlagBearerNetwork = {}

local NOOP_CONNECTION = { Disconnect = function() end }

function FlagBearerNetwork.sendState(player: Player, enabled: boolean): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.FlagBearer.State.Fire(player, enabled)
end

function FlagBearerNetwork.onStateReceived(callback: (enabled: boolean) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.FlagBearer.State.On(callback)
	return NOOP_CONNECTION
end

function FlagBearerNetwork.fireActivateAbility(abilityName: string): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.FlagBearer.ActivateAbility.Fire(abilityName)
end

function FlagBearerNetwork.onActivateAbility(callback: (player: Player, abilityName: string) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.FlagBearer.ActivateAbility.On(callback)
	return NOOP_CONNECTION
end

function FlagBearerNetwork.sendAbilityStatus(player: Player, status: AbilityStatus): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.FlagBearer.AbilityStatus.Fire(player, status :: any)
end

function FlagBearerNetwork.onAbilityStatus(callback: (status: AbilityStatus) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.FlagBearer.AbilityStatus.On(callback :: any)
	return NOOP_CONNECTION
end

function FlagBearerNetwork.sendHealVFX(player: Player, targetUserIds: { number }): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.FlagBearer.HealVFX.Fire(player, targetUserIds)
end

function FlagBearerNetwork.broadcastHealVFX(targetUserIds: { number }): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.FlagBearer.HealVFX.FireAll(targetUserIds)
end

function FlagBearerNetwork.onHealVFX(callback: (targetUserIds: { number }) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.FlagBearer.HealVFX.On(callback)
	return NOOP_CONNECTION
end

function FlagBearerNetwork.sendShieldSpawn(player: Player, ownerUserId: number, position: Vector3, isTeammate: boolean): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.FlagBearer.ShieldSpawn.Fire(player, ownerUserId, position, isTeammate)
end

function FlagBearerNetwork.broadcastShieldSpawn(ownerUserId: number, position: Vector3, isTeammate: boolean): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.FlagBearer.ShieldSpawn.FireAll(ownerUserId, position, isTeammate)
end

function FlagBearerNetwork.onShieldSpawn(callback: (ownerUserId: number, position: Vector3, isTeammate: boolean) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.FlagBearer.ShieldSpawn.On(callback)
	return NOOP_CONNECTION
end

function FlagBearerNetwork.sendShieldDestroy(player: Player, ownerUserId: number): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.FlagBearer.ShieldDestroy.Fire(player, ownerUserId)
end

function FlagBearerNetwork.broadcastShieldDestroy(ownerUserId: number): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.FlagBearer.ShieldDestroy.FireAll(ownerUserId)
end

function FlagBearerNetwork.onShieldDestroy(callback: (ownerUserId: number) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.FlagBearer.ShieldDestroy.On(callback)
	return NOOP_CONNECTION
end

function FlagBearerNetwork.fireShieldHit(ownerUserId: number, damage: number): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.FlagBearer.ShieldHit.Fire(ownerUserId, damage)
end

function FlagBearerNetwork.onShieldHit(callback: (player: Player, ownerUserId: number, damage: number) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.FlagBearer.ShieldHit.On(callback)
	return NOOP_CONNECTION
end

function FlagBearerNetwork.init(): ()
end

return FlagBearerNetwork
