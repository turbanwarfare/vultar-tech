--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Maps = require(MainModule.Shared.Config.Maps)

local AimChamberLink = {}

local manager: any = nil
local checked = false

local function getManager(): any
	if not checked then
		checked = true
		if Maps.isAimMode() then
			manager = require(MainModule.Server.Services.AimChamberService.AimChamberMatchManager)
		end
	end
	return manager
end

function AimChamberLink.isPlayerInAiMode(player: Player): boolean
	local current = getManager()
	return current ~= nil and current.isPlayerInAiMode(player) == true
end

function AimChamberLink.hasActiveMatch(player: Player): boolean
	local current = getManager()
	return current ~= nil and current.hasActiveMatch(player) == true
end

function AimChamberLink.recordPlayerShot(player: Player, count: number): ()
	local current = getManager()
	if current then
		current.recordPlayerShot(player, count)
	end
end

function AimChamberLink.recordPlayerHit(player: Player, count: number): ()
	local current = getManager()
	if current then
		current.recordPlayerHit(player, count)
	end
end

return AimChamberLink
