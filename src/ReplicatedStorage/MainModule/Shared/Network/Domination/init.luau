--!strict
--!native
--!optimize 2

local Types = require(script.Types)

export type Owner = Types.Owner
export type DominationPointState = Types.DominationPointState
export type DominationState = Types.DominationState
export type AnnouncementType = Types.AnnouncementType
export type Announcement = Types.Announcement
export type ControlAction = Types.ControlAction
export type ControlPayload = Types.ControlPayload
export type TerminalPermissions = Types.TerminalPermissions
export type TopPlayer = Types.TopPlayer
export type TeamTopPlayers = Types.TeamTopPlayers
export type VictoryData = Types.VictoryData

local DominationNetwork = {}
local NOOP_CONNECTION = { Disconnect = function() end }

function DominationNetwork.broadcastUpdate(state: DominationState): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Domination.Update.FireAll(state)
end

local updateCallbacks: { (state: DominationState) -> () } = {}
local updateRegistered = false

function DominationNetwork.onUpdate(callback: (state: DominationState) -> ()): { Disconnect: () -> () }
	table.insert(updateCallbacks, callback)

	if not updateRegistered then
		updateRegistered = true
		local Blink = require(script.Parent.Generated.Client)
		Blink.Domination.Update.On(function(state: any)
			for _, cb in updateCallbacks do
				task.spawn(cb, state)
			end
		end)
	end

	return {
		Disconnect = function()
			local index = table.find(updateCallbacks, callback)
			if not index then return end
			local lastIndex = #updateCallbacks
			if index < lastIndex then
				updateCallbacks[index] = updateCallbacks[lastIndex]
			end
			updateCallbacks[lastIndex] = nil
		end,
	}
end

function DominationNetwork.broadcastAnnouncement(announcement: Announcement): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Domination.Announcement.FireAll(announcement)
end

function DominationNetwork.onAnnouncement(callback: (announcement: Announcement) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Domination.Announcement.On(callback)
	return NOOP_CONNECTION
end

function DominationNetwork.broadcastVictory(victoryData: Types.VictoryData): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Domination.Victory.FireAll(victoryData)
end

function DominationNetwork.onVictory(callback: (victoryData: Types.VictoryData) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Domination.Victory.On(callback)
	return NOOP_CONNECTION
end

function DominationNetwork.sendControl(payload: Types.ControlPayload): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Domination.Control.Fire(payload)
end

function DominationNetwork.onControl(callback: (player: Player, payload: Types.ControlPayload) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Domination.Control.On(callback)
	return NOOP_CONNECTION
end

function DominationNetwork.getPermissions(): Types.TerminalPermissions?
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Domination.GetPermissions.Invoke)
	if success then
		return result
	end
	return nil
end

function DominationNetwork.onGetPermissions(callback: (player: Player) -> Types.TerminalPermissions): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Domination.GetPermissions.On(callback)
	return NOOP_CONNECTION
end

function DominationNetwork.getState(): Types.DominationState?
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Domination.GetState.Invoke)
	if success then
		return result
	end
	return nil
end

function DominationNetwork.onGetState(callback: (player: Player) -> Types.DominationState): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Domination.GetState.On(callback)
	return NOOP_CONNECTION
end

function DominationNetwork.init(): ()
end

return DominationNetwork

