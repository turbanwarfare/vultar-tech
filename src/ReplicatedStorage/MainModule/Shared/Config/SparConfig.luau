--!strict
--!native
--!optimize 2

local SparConfig = {}

SparConfig.PLACE_ID = 106589413108827

SparConfig.COUNTDOWN_DURATION = 5
SparConfig.LOADOUT_APPLY_DELAY = 0.1
SparConfig.LOBBY_RESPAWN_DELAY = 3
SparConfig.NEXT_ROUND_DELAY = 2.5
SparConfig.MATCH_TIMEOUT = 10
SparConfig.ABANDON_CHECK_WINDOW = 2
SparConfig.PERIODIC_CLEANUP_INTERVAL = 30
SparConfig.PAD_DISTANCE_THRESHOLD_SQ = 25
SparConfig.PAD_CHECK_INTERVAL = 0.1

SparConfig.TRANSITION_FADE_DURATION = 0.5
SparConfig.ForcefieldDuration = 3
SparConfig.DEFAULT_FORCEFIELD_DURATION = "3"
SparConfig.FORCEFIELD_OPTIONS = { "1", "2", "3", "4", "5" }

SparConfig.RANDOM_MAP_OPTION = "RANDOM"
SparConfig.ACTUAL_MAP_NAMES = { "MQC", "CQCCover", "CQCStump", "LQC", "MQCCover", "LQC Baseplate", "MQC Baseplate", "CQC Baseplate" }
SparConfig.MAP_NAMES = { "RANDOM", "MQC", "CQCCover", "CQCStump", "LQC", "MQCCover", "LQC Baseplate", "MQC Baseplate", "CQC Baseplate" }
SparConfig.GUN_NAMES = { "H-82", "H-82 INF", "H-12", "H-22", "H-41", "H-50", "H-94", "Sword", "GPR" }

SparConfig.DEFAULT_MAP = "MQC"
SparConfig.DEFAULT_GUN = "H-82"
SparConfig.DEFAULT_HEALTH = "100"
SparConfig.DEFAULT_ROUNDS = "1"
SparConfig.DEFAULT_VERSUS = true
SparConfig.ALLOW_SOLO_MODE = false

SparConfig.WIN_RANK_MAX_DISTANCE = 200
SparConfig.DATA_VERSION = "_vTESTING"
SparConfig.BYPASS_USER_IDS = {} :: { number }

SparConfig.ViacomWhitelist = {} :: { number }
SparConfig.ADMIN_PANEL_WHITELIST = {} :: { number }

SparConfig.VIACOM_AUDIT_LOG_MAX = 500
SparConfig.VIACOM_MATCH_INDEX_PAGE_SIZE = 50
SparConfig.VIACOM_MAX_PER_PLAYER_MATCHES = 200

SparConfig.KILL_FARM_WINDOW_SECONDS = 604800
SparConfig.KILL_FARM_MIN_MATCHES_TO_SCORE = 5
SparConfig.KILL_FARM_ALERT_COOLDOWN = 3600

SparConfig.KILL_FARM_VOLUME_MATCH_BASELINE = 20
SparConfig.KILL_FARM_MUTUAL_ROUND_BASELINE = 100

SparConfig.KILL_FARM_POP_AVG_ROUND_DURATION = 45
SparConfig.KILL_FARM_POP_STDDEV_ROUND_DURATION = 20

SparConfig.KILL_FARM_W_VOLUME = 0.35
SparConfig.KILL_FARM_W_SKEW = 0.45
SparConfig.KILL_FARM_W_MUTUAL = 0.45
SparConfig.KILL_FARM_W_SPEED = 0.20
SparConfig.KILL_FARM_W_DPK = 0.00

SparConfig.KILL_FARM_FEEDING_THRESHOLD = 0.55
SparConfig.KILL_FARM_MUTUAL_THRESHOLD = 0.55

SparConfig.KILL_FARM_SINGLE_MATCH_ROUND_THRESHOLD = 15
SparConfig.KILL_FARM_SINGLE_MATCH_SKEW_THRESHOLD = 0.60
SparConfig.KILL_FARM_SINGLE_MATCH_SPEED_THRESHOLD = 20
SparConfig.KILL_FARM_SINGLE_MATCH_ALERT_COOLDOWN = 1800

SparConfig.KILL_FARM_INSTANT_POP_AVG_ROUND_DURATION = 12
SparConfig.KILL_FARM_INSTANT_POP_STDDEV_ROUND_DURATION = 6
SparConfig.KILL_FARM_SINGLE_MATCH_INSTANT_SPEED_THRESHOLD = 5

SparConfig.HEALTH_OPTIONS = {
	"50",
	"100",
	"150",
	"200",
	"300",
	"500",
	"750",
	"1000",
	"1500",
	"2000",
	"3000",
	"5000",
	"7500",
	"10000",
	"15000",
	"20000",
	"25000",
	"50000",
	"75000",
	"100000",
	"150000",
	"200000",
	"250000",
}

SparConfig.ROUNDS_OPTIONS = {
	"1",
	"3",
	"5",
	"7",
	"10",
	"15",
	"20",
	"25",
	"30",
	"40",
	"50",
	"60",
	"75",
	"100",
	"125",
	"150",
	"175",
	"200",
}

SparConfig.MAX_CUSTOM_HEALTH = 250000
SparConfig.MAX_CUSTOM_ROUNDS = 200

SparConfig.V2_TOOLS_ASSET_ID = 108343605674626

SparConfig.MAP_POSITIONS = {
	Vector3.new(0, 50, 0),
	Vector3.new(600, 50, 0),
	Vector3.new(0, 50, 600),
	Vector3.new(600, 50, 600),
	Vector3.new(-600, 50, 0),
	Vector3.new(0, 50, -600),
	Vector3.new(-600, 50, -600),
	Vector3.new(600, 50, -600),
	Vector3.new(-600, 50, 600),
	Vector3.new(1200, 50, 0),
} :: { Vector3 }

SparConfig.MAP_IMAGES = {
	["RANDOM"] = "rbxassetid://134880308929198",
	["CQCCover"] = "rbxassetid://99770742830127",
	["CQCStump"] = "rbxassetid://104749720254204",
	["LQC"] = "rbxassetid://123301899618441",
	["MQC"] = "rbxassetid://123795244827924",
	["MQCCover"] = "rbxassetid://81239546930338",
	["LQC Baseplate"] = "rbxassetid://76596325246518",
	["MQC Baseplate"] = "rbxassetid://125896635933739",
	["CQC Baseplate"] = "rbxassetid://137851507323781",
} :: { [string]: string }

SparConfig.GUN_ICONS = {
	["H-82"] = "rbxassetid://114037166217547",
	["H-82 INF"] = "rbxassetid://114037166217547",
	["H-12"] = "rbxassetid://102998024319858",
	["H-22"] = "rbxassetid://121248159079541",
	["H-41"] = "rbxassetid://121612272092351",
	["H-50"] = "rbxassetid://85019502268004",
	["H-94"] = "rbxassetid://123078399540323",
	["Sword"] = "rbxassetid://10820063259",
	["GPR"] = "rbxassetid://114037166217547",
} :: { [string]: string }

SparConfig.LEADERBOARD_CATEGORIES = {
	"AllTimeWins",
	"AllTimeKills",
	"AllTimeDamage",
	"WeeklyKills",
	"WeeklyWins",
	"MonthlyWins",
} :: { string }

SparConfig.LEADERBOARD_STAT_MAP = {
	["AllTimeWins"] = "AllTime.GamesWon",
	["AllTimeKills"] = "AllTime.1v1Kills",
	["AllTimeDamage"] = "AllTime.Damage",
	["WeeklyKills"] = "LastWeek.1v1Kills",
	["WeeklyWins"] = "LastWeek.GamesWon",
	["MonthlyWins"] = "LastMonth.GamesWon",
} :: { [string]: string }

SparConfig.STATS_DEFAULT = {
	Kills = 0,
	Damage = 0,
	MatchesPlayed = 0,
	MatchesLost = 0,
	MatchesWon = 0,
	RoundWins = 0,
	RoundLosses = 0,
	Streak = 0,
} :: { [string]: number }

SparConfig.TITLE_THRESHOLDS = {
	{ Wins = 0, Name = "UNPROVEN", Color = Color3.fromRGB(160, 160, 160) },
	{ Wins = 50, Name = "PROVEN", Color = Color3.fromRGB(0, 170, 255) },
	{ Wins = 100, Name = "ADEPT", Color = Color3.fromRGB(0, 255, 127) },
	{ Wins = 300, Name = "VICTOR", Color = Color3.fromRGB(255, 215, 0) },
	{ Wins = 700, Name = "CHOSEN", Color = Color3.fromRGB(255, 127, 0) },
	{ Wins = 1250, Name = "SENTINEL", Color = Color3.fromRGB(255, 0, 0) },
	{ Wins = 2000, Name = "PARAGON", Color = Color3.fromRGB(139, 0, 255) },
	{ Wins = 4000, Name = "WARLORD", Color = Color3.fromRGB(255, 0, 255) },
	{ Wins = 6000, Name = "IMMORTAL", Color = Color3.fromRGB(255, 255, 255) },
	{ Wins = 8000, Name = "ETERNAL", Color = Color3.fromRGB(0, 255, 255) },
	{ Wins = 10000, Name = "CHAMPION", Color = Color3.fromRGB(255, 215, 0) },
} :: { { Wins: number, Name: string, Color: Color3 } }

SparConfig.LeaderboardParts = {
	["AllTimeWinsBoard"] = {
		Stat = "Wins",
		Scope = "AllTime",
		Label = "WINS LEADERBOARD",
		Face = Enum.NormalId.Right,
		PixelsPerStud = 36,
		MinimumScore = {
			AllTime = 25,
			Monthly = 10,
			Daily = 1,
		},
	},
	["AllTimeKillsBoard"] = {
		Stat = "Kills",
		Scope = "AllTime",
		Label = "KILLS LEADERBOARD",
		Face = Enum.NormalId.Right,
		PixelsPerStud = 36,
		MinimumScore = {
			AllTime = 100,
			Monthly = 40,
			Daily = 1,
		},
	},
	["AllTimeDamageBoard"] = {
		Stat = "Damage",
		Scope = "AllTime",
		Label = "DAMAGE LEADERBOARD",
		Face = Enum.NormalId.Right,
		PixelsPerStud = 36,
		MinimumScore = {
			AllTime = 25000,
			Monthly = 10000,
			Daily = 100,
		},
	},
	["AllTimeWinsBoard2"] = {
		Stat = "Wins",
		Scope = "AllTime",
		Label = "WINS LEADERBOARD",
		Face = Enum.NormalId.Right,
		PixelsPerStud = 36,
		MinimumScore = {
			AllTime = 25,
			Monthly = 10,
			Daily = 1,
		},
	},
	["AllTimeKillsBoard2"] = {
		Stat = "Kills",
		Scope = "AllTime",
		Label = "KILLS LEADERBOARD",
		Face = Enum.NormalId.Right,
		PixelsPerStud = 36,
		MinimumScore = {
			AllTime = 100,
			Monthly = 40,
			Daily = 1,
		},
	},
	["AllTimeDamageBoard2"] = {
		Stat = "Damage",
		Scope = "AllTime",
		Label = "DAMAGE LEADERBOARD",
		Face = Enum.NormalId.Right,
		PixelsPerStud = 36,
		MinimumScore = {
			AllTime = 25000,
			Monthly = 10000,
			Daily = 100,
		},
	},
}

return SparConfig
