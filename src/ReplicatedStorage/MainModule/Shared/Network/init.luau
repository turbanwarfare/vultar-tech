--!strict
--!native
--!optimize 2

local SharedTypes = require(script.Parent.Types)
local PingTypes = require(script.Ping.Types)
local SettingsTypes = require(script.Settings.Types)
local ChatTypes = require(script.Chat.Types)
local StatsTypes = require(script.Stats.Types)
local InventoryTypes = require(script.Inventory.Types)
local TeamsTypes = require(script.Teams.Types)
local CosmeticTypes = require(script.Cosmetic.Types)
local DeathTypes = require(script.Death.Types)
local HardpointTypes = require(script.Hardpoint.Types)
local DiagnosticsTypes = require(script.Diagnostics.Types)
local EventCosmeticsTypes = require(script.EventCosmetics.Types)
local LoggingTypes = require(script.Logging.Types)
local PlayerActionTypes = require(script.PlayerAction.Types)
local GlobalStatsTypes = require(script.GlobalStats.Types)
local ClassTypes = require(script.Class.Types)
local FlagBearerTypes = require(script.FlagBearer.Types)
local PhaseTypes = require(script.Phase.Types)
local AvatarTypes = require(script.Avatar.Types)
local AimChamberTypes = require(script.AimChamber.Types)
local DominationTypes = require(script.Domination.Types)

local Network = {}

Network.Ping = require(script.Ping)
Network.Settings = require(script.Settings)
Network.Deploy = require(script.Deploy)
Network.Credits = require(script.Credits)
Network.Progress = require(script.Progress)
Network.Camera = require(script.Camera)
Network.Loading = require(script.Loading)
Network.Chat = require(script.Chat)
Network.Stats = require(script.Stats)
Network.Inventory = require(script.Inventory)
Network.Teams = require(script.Teams)
Network.Cosmetic = require(script.Cosmetic)
Network.Gun = require(script.Gun)
Network.Death = require(script.Death)
Network.Hardpoint = require(script.Hardpoint)
Network.Diagnostics = require(script.Diagnostics)
Network.EventCosmetics = require(script.EventCosmetics)
Network.Logging = require(script.Logging)
Network.PlayerAction = require(script.PlayerAction)
Network.GlobalStats = require(script.GlobalStats)
Network.Class = require(script.Class)
Network.FlagBearer = require(script.FlagBearer)
Network.Phase = require(script.Phase)
Network.Avatar = require(script.Avatar)
Network.Spar = require(script.Spar)
Network.AimChamber = require(script.AimChamber)
Network.Domination = require(script.Domination)
Network.Economy = require(script.Economy)
Network.Crate = require(script.Crate)

export type HighlightTarget = PingTypes.HighlightTarget
export type PingData = PingTypes.PingData
export type ExportResult = SettingsTypes.ExportResult
export type ImportResult = SettingsTypes.ImportResult
export type ChannelId = ChatTypes.ChannelId
export type ChatMessage = ChatTypes.ChatMessage
export type PlayerChatData = ChatTypes.PlayerChatData
export type PlayerStats = StatsTypes.PlayerStats
export type LeaderboardEntry = StatsTypes.LeaderboardEntry
export type LeaderboardResponse = StatsTypes.LeaderboardResponse
export type SortField = StatsTypes.SortField
export type InventoryItem = InventoryTypes.InventoryItem
export type InventoryState = InventoryTypes.InventoryState
export type InventoryUpdateData = InventoryTypes.InventoryUpdateData
export type TeamChoice = TeamsTypes.TeamChoice
export type TeamChangeResult = TeamsTypes.TeamChangeResult
export type CosmeticCategory = CosmeticTypes.Category
export type OwnedCosmetics = CosmeticTypes.OwnedCosmetics
export type EquippedCosmetics = CosmeticTypes.EquippedCosmetics
export type CosmeticState = CosmeticTypes.CosmeticState
export type HitLogEntry = DeathTypes.HitLogEntry
export type OutgoingHitEntry = DeathTypes.OutgoingHitEntry
export type KillLogData = DeathTypes.KillLogData
export type DeathData = DeathTypes.DeathData
export type HardpointState = HardpointTypes.HardpointState
export type HardpointAnnouncement = HardpointTypes.Announcement
export type HardpointOwner = HardpointTypes.Owner
export type ControlAction = HardpointTypes.ControlAction
export type ControlPayload = HardpointTypes.ControlPayload
export type TerminalPermissions = HardpointTypes.TerminalPermissions
export type TopPlayer = SharedTypes.TopPlayer
export type TeamTopPlayers = SharedTypes.TeamTopPlayers
export type VictoryData = SharedTypes.VictoryData
export type DiagnosticDump = DiagnosticsTypes.DiagnosticDump
export type DumpMetadata = DiagnosticsTypes.DumpMetadata
export type EventCosmeticData = EventCosmeticsTypes.EventCosmeticData
export type FacilityBanData = EventCosmeticsTypes.FacilityBanData
export type UserGameState = EventCosmeticsTypes.UserGameState
export type LogSubmitData = LoggingTypes.LogSubmitData
export type LogSubmitResult = LoggingTypes.LogSubmitResult
export type LogPlayer = LoggingTypes.LogPlayer
export type PlayerActionTrigger = PlayerActionTypes.PlayerActionTrigger
export type PlayerGlobalStats = GlobalStatsTypes.PlayerGlobalStats
export type ClassSelectResult = ClassTypes.ClassSelectResult
export type ClassSlotData = ClassTypes.ClassSlotData
export type ClassSlotsState = ClassTypes.ClassSlotsState
export type FlagBearerAbilityStatus = FlagBearerTypes.AbilityStatus
export type PhaseOwner = PhaseTypes.PhaseOwner
export type PhaseAnnouncementType = PhaseTypes.PhaseAnnouncementType
export type ConquestAction = PhaseTypes.ConquestAction
export type PhaseState = PhaseTypes.PhaseState
export type PhaseAnnouncement = PhaseTypes.PhaseAnnouncement
export type ConquestUpdate = PhaseTypes.ConquestUpdate
export type TrainMovementData = PhaseTypes.TrainMovementData
export type DoorStateData = PhaseTypes.DoorStateData
export type PhaseControlAction = PhaseTypes.PhaseControlAction
export type PhaseControlPayload = PhaseTypes.PhaseControlPayload
export type AvatarState = AvatarTypes.AvatarState
export type AimChamberConfigState = AimChamberTypes.AimChamberConfigState
export type AimChamberSettings = AimChamberTypes.AimChamberSettings
export type AimChamberMatchStartPayload = AimChamberTypes.AimChamberMatchStartPayload
export type AimChamberMatchTick = AimChamberTypes.AimChamberMatchTick
export type AimChamberDeathReason = AimChamberTypes.AimChamberDeathReason
export type AimChamberValidationPayload = AimChamberTypes.AimChamberValidationPayload
export type AimChamberMatchEndPayload = AimChamberTypes.AimChamberMatchEndPayload
export type AimChamberApplyResult = AimChamberTypes.AimChamberApplyResult
export type DominationOwner = DominationTypes.Owner
export type DominationPointState = DominationTypes.DominationPointState
export type DominationState = DominationTypes.DominationState
export type DominationAnnouncementType = DominationTypes.AnnouncementType
export type DominationAnnouncement = DominationTypes.Announcement
export type DominationControlAction = DominationTypes.ControlAction
export type DominationControlPayload = DominationTypes.ControlPayload

function Network.init(): ()
	Network.PlayerAction.init()
	Network.Gun.init()
end

return Network
