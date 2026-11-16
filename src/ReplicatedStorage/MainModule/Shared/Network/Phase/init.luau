--!strict
--!native
--!optimize 2

local Types = require(script.Types)

export type PhaseOwner = Types.PhaseOwner
export type PhaseAnnouncementType = Types.PhaseAnnouncementType
export type ConquestAction = Types.ConquestAction
export type PhaseState = Types.PhaseState
export type PhaseAnnouncement = Types.PhaseAnnouncement
export type ConquestUpdate = Types.ConquestUpdate
export type TrainMovementData = Types.TrainMovementData
export type DoorStateData = Types.DoorStateData
export type TopPlayer = Types.TopPlayer
export type TeamTopPlayers = Types.TeamTopPlayers
export type VictoryData = Types.VictoryData
export type PhaseControlAction = Types.PhaseControlAction
export type PhaseControlPayload = Types.PhaseControlPayload

local PhaseNetwork = {}
local NOOP_CONNECTION = { Disconnect = function() end }

local updateListeners: { (state: PhaseState) -> () } = {}
local updateBlinkRegistered = false

function PhaseNetwork.broadcastUpdate(state: PhaseState): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Phase.Update.FireAll(state)
end

function PhaseNetwork.onUpdate(callback: (state: PhaseState) -> ()): { Disconnect: () -> () }
	table.insert(updateListeners, callback)

	if not updateBlinkRegistered then
		updateBlinkRegistered = true
		local Blink = require(script.Parent.Generated.Client)
		Blink.Phase.Update.On(function(state: PhaseState)
			for _, listener in updateListeners do
				task.spawn(listener, state)
			end
		end)
	end

	return {
		Disconnect = function()
			for i, listener in updateListeners do
				if listener == callback then
					local lastIdx = #updateListeners
					if i < lastIdx then
						updateListeners[i] = updateListeners[lastIdx]
					end
					updateListeners[lastIdx] = nil
					break
				end
			end
		end,
	}
end

function PhaseNetwork.broadcastAnnouncement(announcement: PhaseAnnouncement): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Phase.Announcement.FireAll(announcement)
end

function PhaseNetwork.onAnnouncement(callback: (announcement: PhaseAnnouncement) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Phase.Announcement.On(callback)
	return NOOP_CONNECTION
end

function PhaseNetwork.broadcastVictory(victoryData: VictoryData): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Phase.Victory.FireAll(victoryData)
end

function PhaseNetwork.onVictory(callback: (victoryData: VictoryData) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Phase.Victory.On(callback)
	return NOOP_CONNECTION
end

function PhaseNetwork.broadcastConquestUi(update: ConquestUpdate): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Phase.ConquestUi.FireAll(update)
end

function PhaseNetwork.onConquestUi(callback: (update: ConquestUpdate) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Phase.ConquestUi.On(callback)
	return NOOP_CONNECTION
end

function PhaseNetwork.broadcastPayloadProgress(progress: number, max: number, netPower: number): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Phase.PayloadProgress.FireAll(progress, max, netPower)
end

function PhaseNetwork.onPayloadProgress(callback: (progress: number, max: number, netPower: number) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Phase.PayloadProgress.On(callback)
	return NOOP_CONNECTION
end

function PhaseNetwork.broadcastTrainMovement(data: TrainMovementData): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Phase.TrainMovement.FireAll(data)
end

function PhaseNetwork.onTrainMovement(callback: (data: TrainMovementData) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Phase.TrainMovement.On(callback)
	return NOOP_CONNECTION
end

function PhaseNetwork.broadcastDoorState(data: DoorStateData): ()
	local Blink = require(script.Parent.Generated.Server)
	Blink.Phase.DoorState.FireAll(data)
end

function PhaseNetwork.onDoorState(callback: (data: DoorStateData) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Client)
	Blink.Phase.DoorState.On(callback)
	return NOOP_CONNECTION
end

function PhaseNetwork.sendControl(payload: PhaseControlPayload): ()
	local Blink = require(script.Parent.Generated.Client)
	Blink.Phase.Control.Fire(payload)
end

function PhaseNetwork.onControl(callback: (player: Player, payload: PhaseControlPayload) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Phase.Control.On(callback)
	return NOOP_CONNECTION
end

function PhaseNetwork.getState(): PhaseState?
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Phase.GetState.Invoke)
	if success then
		return result
	end
	return nil
end

function PhaseNetwork.onGetState(callback: (player: Player) -> PhaseState): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Phase.GetState.On(callback)
	return NOOP_CONNECTION
end

function PhaseNetwork.getPermissions(): { HasAccess: boolean, IsPrivateServer: boolean, IsOwner: boolean }?
	local Blink = require(script.Parent.Generated.Client)
	local success, result = pcall(Blink.Phase.GetPermissions.Invoke)
	if success then
		return result
	end
	return nil
end

function PhaseNetwork.onGetPermissions(callback: (player: Player) -> { HasAccess: boolean, IsPrivateServer: boolean, IsOwner: boolean }): { Disconnect: () -> () }
	local Blink = require(script.Parent.Generated.Server)
	Blink.Phase.GetPermissions.On(callback)
	return NOOP_CONNECTION
end

function PhaseNetwork.init(): ()
end

return PhaseNetwork
