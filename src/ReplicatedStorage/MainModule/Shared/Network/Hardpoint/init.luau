--!strict
--!native
--!optimize 2

local Types = require(script.Types)

export type Owner = Types.Owner
export type HardpointState = Types.HardpointState
export type AnnouncementType = Types.AnnouncementType
export type Announcement = Types.Announcement
export type ControlAction = Types.ControlAction
export type ControlPayload = Types.ControlPayload
export type TerminalPermissions = Types.TerminalPermissions
export type TopPlayer = Types.TopPlayer
export type TeamTopPlayers = Types.TeamTopPlayers
export type VictoryData = Types.VictoryData

local HardpointNetwork = {}
local NOOP_CONNECTION = { Disconnect = function() end }

function HardpointNetwork.broadcastUpdate(state: HardpointState): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Hardpoint.Update.FireAll(state)
end

local updateCallbacks: { (state: HardpointState) -> () } = {}
local updateRegistered = false

function HardpointNetwork.onUpdate(callback: (state: HardpointState) -> ()): { Disconnect: () -> () }
	table.insert(updateCallbacks, callback)

	if not updateRegistered then
		updateRegistered = true
		local Blink = require(script.Parent.Generated.Client)
		Blink.Hardpoint.Update.On(function(state: any)
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

function HardpointNetwork.broadcastAnnouncement(announcement: Announcement): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Hardpoint.Announcement.FireAll(announcement)
end

function HardpointNetwork.onAnnouncement(callback: (announcement: Announcement) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Hardpoint.Announcement.On(callback)
	return NOOP_CONNECTION
end

function HardpointNetwork.broadcastTerminalVisual(pointName: string, action: string, color: Color3?): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Hardpoint.TerminalVisual.FireAll(pointName, action, color)
end

function HardpointNetwork.onTerminalVisual(callback: (pointName: string, action: string, color: Color3?) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Hardpoint.TerminalVisual.On(callback)
	return NOOP_CONNECTION
end

function HardpointNetwork.sendControl(payload: Types.ControlPayload): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Hardpoint.Control.Fire(payload)
end

function HardpointNetwork.onControl(callback: (player: Player, payload: Types.ControlPayload) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Hardpoint.Control.On(callback)
	return NOOP_CONNECTION
end

function HardpointNetwork.getPermissions(): Types.TerminalPermissions?
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Hardpoint.GetPermissions.Invoke)
	if success then
		return result
	end
	return nil
end

function HardpointNetwork.onGetPermissions(callback: (player: Player) -> Types.TerminalPermissions): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Hardpoint.GetPermissions.On(callback)
	return NOOP_CONNECTION
end

function HardpointNetwork.getState(): Types.HardpointState?
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Hardpoint.GetState.Invoke)
	if success then
		return result
	end
	return nil
end

function HardpointNetwork.onGetState(callback: (player: Player) -> Types.HardpointState): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Hardpoint.GetState.On(callback)
	return NOOP_CONNECTION
end

function HardpointNetwork.broadcastVictory(victoryData: Types.VictoryData): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Hardpoint.Victory.FireAll(victoryData)
end

function HardpointNetwork.onVictory(callback: (victoryData: Types.VictoryData) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Hardpoint.Victory.On(callback)
	return NOOP_CONNECTION
end

function HardpointNetwork.init(): ()
end

return HardpointNetwork
