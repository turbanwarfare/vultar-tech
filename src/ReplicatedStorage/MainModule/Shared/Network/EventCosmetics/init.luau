--!strict
--!native
--!optimize 2

local Types = require(script.Types)

export type EventCosmeticData = Types.EventCosmeticData
export type FacilityBanData = Types.FacilityBanData
export type RecordingPolicyData = Types.RecordingPolicyData
export type UserGameState = Types.UserGameState

local EventCosmeticsNetwork = {}

function EventCosmeticsNetwork.init(): ()
end

return EventCosmeticsNetwork
