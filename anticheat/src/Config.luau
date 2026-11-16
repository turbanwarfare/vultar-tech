--!strict

local Config = {}

Config.SilentMode = true
Config.WebhookUrl = "REPLACE_WITH_YOUR_WEBHOOK_URL"
Config.WebhookFooter = "VULTARIAN DEFENSE INDUSTRIES"
Config.StaffChannel = "HICOM"
Config.AlertTag = "AC_ALERT"

Config.EvalInterval = 5
Config.AlertCooldown = 300
Config.TimeWindow = 120
Config.HitWindow = 60
Config.ShotWindow = 1200
Config.MinHitsForAlert = 10

Config.Lag = { MaxPingSeconds = 0.6, BurstGapSeconds = 0.004, PingCacheSeconds = 1 }
Config.Cluster = { MinHits = 12, MinVictims = 2, MinVictimSpeed = 6, MinDistance = 6, TightStuds = 0.12, HumanStuds = 0.6 }
Config.SilentAim = { BaseAngleDeg = 8, MinDistance = 8, ViolationsForFull = 4 }
Config.Switch = { MinAngleDeg = 25, MaxDegPerSec = 1800, EventsForFull = 3 }
Config.Headshot = { MinHits = 20, LowRatio = 0.5, HighRatio = 0.85 }
Config.Accuracy = { MinShots = 40, LowRatio = 0.65, HighRatio = 0.95 }

Config.AloneWeights = { silentAim = 0.8, cluster = 0.7, switch = 0.5, headshot = 0.3, accuracy = 0.3, wallHit = 0.9, wallTrack = 0.6, flick = 0.7 }
Config.CorroborationWeight = 0.35
Config.WatchThreshold = 0.35
Config.AlertThreshold = 0.6

Config.SuspectsPushInterval = 3
Config.SuspectsRemoteName = "VultarACSuspects"
Config.PreBufferFlagged = true
Config.PreBufferGraceSeconds = 60
Config.ExemptUserIds = {} :: { number }

Config.SightWindow = 300
Config.Sight = {
	Range = 250,
	FovDeg = 60,
	PassInterval = 0.2,
	PassRaycastBudget = 600,
	SeeThroughTransparency = 0.3,
	MinOccluderThickness = 0.5,
	StartMargin = 0.5,
	EndMargin = 1,
	MinLagSeconds = 0.03,
	MaxLagSeconds = 0.4,
	MaxSampleAge = 2,
	MaxSampleLead = 0.5,
	MaxCameraOffset = 20,
}
Config.WallHit = { StartMargin = 1, EndMargin = 1.5, MinThickness = 0.5, MaxEndpointError = 8, MaxOriginError = 4, HistorySlack = 0.15, EventGap = 2, EventsForFull = 3 }
Config.WallTrack = {
	ConeDeg = 3.5,
	MinDistance = 40,
	HiddenSeconds = 1.5,
	QuietSeconds = 3,
	MaxCheckAge = 0.5,
	LateralWindow = 0.5,
	MinLateralDegPerSec = 6,
	MaxGap = 0.2,
	MinSeconds = 1.2,
	MinTravelDeg = 8,
	PairCooldown = 6,
	EpisodesForFull = 3,
	MinEnemies = 2,
}
Config.Flick = { MinStartDeg = 10, OnTargetDeg = 2, MaxSeconds = 0.15, MaxPingSeconds = 0.4, EngagementGap = 3, SettleSeconds = 0.35, WindowSeconds = 1, EventsForFull = 3 }

return Config
