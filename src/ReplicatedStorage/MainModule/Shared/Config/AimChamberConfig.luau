--!strict
--!native
--!optimize 2

local SparConfig = require(script.Parent.SparConfig)
local Constants = require(script.Parent.Constants)

local AimChamberConfig = {}

export type AimChamberSettings = {
	IsAiMode: boolean,
	MaxZombies: number,
	MaxZombiesEnabled: boolean,
	ZombieSpeed: number,
	ZombieDamageEnabled: boolean,
	ZombieDamageAmount: number,
	ZombieSpawnRate: number,
	ZombieDodgeInterval: number,
	ZombieCrouchChance: number,
	AssessmentValidation: boolean,
	SelectedGun: string,

	MinEngageDistance: number,
	MaxEngageDistance: number,
	ApproachSpeedMultiplier: number,
	StrafeSpeedMultiplier: number,
	StrafeHoldMin: number,
	StrafeHoldMax: number,
	StrafeApproachAngle: number,
	StrafeFlipIntervalMin: number,
	StrafeFlipIntervalMax: number,
	JukeChance: number,
	JukeSpeedMultiplier: number,
	MovementJitter: number,
	OrbitDirectionBias: number,
	ZombieJumpPower: number,
	OrbitJumpChance: number,
	JumpCooldown: number,
	JukeJumpChance: number,
	BunnyHopEnabled: boolean,
	BunnyHopChainChance: number,
	BunnyHopSpeedMultiplier: number,
	BunnyHopMaxChain: number,

	ApproachJukeChance: number,

	MaxOrbitDuration: number,
	CommitSpeedMultiplier: number,
	SeparationMaxForce: number,

	ApproachJumpChance: number,
	ApproachCrouchChance: number,
	CloseRangeJumpChance: number,
	DecisionTimeStaggerMax: number,

	SpawnRateRampEnabled: boolean,
	SpawnRateRampStartRate: number,
	SpawnRateRampDuration: number,

	AiDifficulty: string?,
	AiNpcAccuracy: number?,
	AiRounds: number?,
	AiHealth: number?,
	AiMovementProfile: string?,
	AiWeapon: string?,
}

export type AimChamberGunRule = {
	AllowedGuns: { string },
	DefaultGun: string,
	Locked: boolean,
}

export type AimChamberPreset = {
	Id: string,
	DisplayName: string,
	Settings: AimChamberSettings,
	Locked: boolean,
	GunRule: AimChamberGunRule,
}

export type AimChamberDeathReason = "Zombie" | "EndOnTouch" | "LeftMidMatch"

export type AimChamberRunRecord = {
	RecordId: string,
	UserId: number,
	PlayerName: string,
	DisplayName: string,
	PresetId: string,
	Settings: AimChamberSettings,
	GunName: string,
	AiWeapon: string?,
	DeathReason: AimChamberDeathReason,
	ElapsedTime: number,
	Timestamp: number,
	ServerTimestamp: number,
	CountsForValidation: boolean,
	AvatarUrl: string,
}

export type AimChamberValidationPayload = {
	PlayerName: string,
	UserId: number,
	AvatarUrl: string,
	PresetId: string,
	Settings: AimChamberSettings,
	GunName: string,
	FormattedDateTime: string,
	DeathReason: AimChamberDeathReason,
	ElapsedTime: number,
	ZombieSpawnRate: number,
}

export type AiMovementProfile = {
	SpinChance: number,
	BunnyhopChance: number,
	StrafeChance: number,
	RandomJumpChance: number,
	FreezeChance: number,
	CrouchChance: number,
	ComboWeighting: number,
}

export type AiDifficultyConfig = {
	Accuracy: number,
	HitChance: number?,
	MovementProfile: AiMovementProfile,
}

export type AiConfig = {
	Difficulties: { [string]: AiDifficultyConfig },
}

local AIM_CHAMBER_GUN_NAMES: { string } = {}
for _, name in SparConfig.GUN_NAMES do
	table.insert(AIM_CHAMBER_GUN_NAMES, name)
end

AimChamberConfig.GUN_NAMES = AIM_CHAMBER_GUN_NAMES

AimChamberConfig.GUN_ICONS = SparConfig.GUN_ICONS

AimChamberConfig.RecorderAccessUserIds = {} :: { number }

AimChamberConfig.GROUPS = {
	VIA = Constants.GROUPS.VIA,
	VULTAR = Constants.GROUPS.VULTAR,
}

AimChamberConfig.VIA_RANKS = Constants.VIA_RANKS

AimChamberConfig.STAGE_2_RANK = Constants.VIA_RANKS.STAGE_2

AimChamberConfig.CLAMP_RANGES = {
	MaxZombies = { Min = 1, Max = 50 },
	ZombieSpeed = { Min = 1, Max = 30 },
	ZombieDamageAmount = { Min = 1, Max = 500 },
	ZombieSpawnRate = { Min = 0.5, Max = 20 },
	ZombieDodgeInterval = { Min = 0.5, Max = 15 },
	ZombieCrouchChance = { Min = 0, Max = 1 },

	MinEngageDistance = { Min = 1, Max = 50 },
	MaxEngageDistance = { Min = 2, Max = 100 },
	ApproachSpeedMultiplier = { Min = 0.1, Max = 3 },
	StrafeSpeedMultiplier = { Min = 0.1, Max = 3 },
	StrafeHoldMin = { Min = 0.1, Max = 5 },
	StrafeHoldMax = { Min = 0.1, Max = 5 },
	StrafeApproachAngle = { Min = 30, Max = 90 },
	StrafeFlipIntervalMin = { Min = 0.2, Max = 3 },
	StrafeFlipIntervalMax = { Min = 0.2, Max = 3 },
	JukeChance = { Min = 0, Max = 1 },
	JukeSpeedMultiplier = { Min = 0.5, Max = 5 },
	MovementJitter = { Min = 0, Max = 1 },
	OrbitDirectionBias = { Min = 0, Max = 1 },
	ZombieJumpPower = { Min = 0, Max = 150 },
	OrbitJumpChance = { Min = 0, Max = 1 },
	JumpCooldown = { Min = 0.1, Max = 10 },
	JukeJumpChance = { Min = 0, Max = 1 },
	BunnyHopChainChance = { Min = 0, Max = 1 },
	BunnyHopSpeedMultiplier = { Min = 0.5, Max = 3 },
	BunnyHopMaxChain = { Min = 1, Max = 10 },

	ApproachJukeChance = { Min = 0, Max = 1 },

	MaxOrbitDuration = { Min = 0.5, Max = 15 },
	CommitSpeedMultiplier = { Min = 0.5, Max = 3 },
	SeparationMaxForce = { Min = 0, Max = 15 },

	ApproachJumpChance = { Min = 0, Max = 1 },
	ApproachCrouchChance = { Min = 0, Max = 1 },
	CloseRangeJumpChance = { Min = 0, Max = 1 },
	DecisionTimeStaggerMax = { Min = 0, Max = 2 },

	SpawnRateRampStartRate = { Min = 0.1, Max = 20 },
	SpawnRateRampDuration = { Min = 5, Max = 300 },

	AiNpcAccuracy = { Min = 0.1, Max = 3.0 },
	AiRounds = { Min = 1, Max = 10 },
	AiHealth = { Min = 10, Max = 10000 },
}

AimChamberConfig.TIMER_TICK_RATE = 0.5

AimChamberConfig.SPAWN_RATE_FORMAT = "%.1f ZOMBIES/SEC"

AimChamberConfig.ZOMBIE_AI = {
	HOP_ARC_HEIGHT = 3,
	HOP_DURATION = 0.4,
	HOP_COOLDOWN = 0.2,
	CROUCH_DURATION = 0.6,
	CROUCH_SCALE = 0.6,
	DAMAGE_COOLDOWN = 0.5,
	SPAWN_OFFSET_RADIUS = 30,
	DESPAWN_DISTANCE = 200,
	ANIMATION_BLEND_TIME = 0.15,
	TARGET_RANGE = 10,
	DAMAGE_COOLDOWN_VAL = 0.5,
	UPDATE_TICK_RATE = 0.05,
	SPAWN_JITTER = 3,
	SPAWN_HEIGHT = 5,
	APPROACH_JUKE_ANGLE = 80,
	ORBIT_LOOK_AHEAD_ANGLE = 25,
	SEPARATION_RADIUS = 6,
	COMMIT_SEPARATION_FORCE = 1.5,
	ORBIT_CHANCE = 0.3,
	CORPSE_DURATION = 0.5,
}

AimChamberConfig.AI_PRESET_CONSTANTS = {
	UPDATE_TICK_RATE = 1 / 60,
	SHOOT_INTERVAL_MIN = 0.55,
	SHOOT_INTERVAL_MAX = 1.1,
	FREEZE_SHOOT_INTERVAL_MIN = 0.35,
	FREEZE_SHOOT_INTERVAL_MAX = 0.65,
	FREEZE_MIN_DURATION = 0.15,
	FREEZE_MAX_DURATION = 0.35,
	AIM_LERP_ALPHA = 0.25,
	BEAM_RAY_DURATION = 0.075,
	ORBIT_DISTANCE_MIN = 14,
	ORBIT_DISTANCE_MAX = 22,
	ORBIT_WALK_SPEED = 14,
	DECISION_TICK_MIN = 0.55,
	DECISION_TICK_MAX = 1.2,
	JUMP_INTERVAL_MIN = 0.45,
	JUMP_INTERVAL_MAX = 1.4,
	JUMP_POWER = 52,
	CROUCH_DURATION_MIN = 0.4,
	CROUCH_DURATION_MAX = 1.1,
	CROUCH_HIP_REDUCTION = 1.0,
	CROUCH_ANIM_ID = "rbxassetid://101785625813335",
	SPAWN_HEIGHT_OFFSET = 5,
	SPAWN_JITTER = 3,
	SPAWN_RADIUS = 22,
	NPC_ASSET_NAME = "Training Bot",
	GUN_ASSET_NAME = "BR-16",
	CORPSE_DURATION = 0.5,
	COMBO_MAX_EASY = 2,
	COMBO_MAX_HARD = 4,
	BR16_IDLE_ANIM_ID = 96896749029991,
	BR16_BASE_DAMAGE = 14,
	BR16_FIRE_RATE = 0.1,
	SPAWN_FORCEFIELD_DURATION = 3.0,
}

AimChamberConfig.AI_CONFIG = {
	Difficulties = {
		EASY = {
			Accuracy = 1.3,
			MovementProfile = {
				SpinChance = 0.55,
				BunnyhopChance = 0.55,
				StrafeChance = 0.75,
				RandomJumpChance = 0.40,
				FreezeChance = 0.20,
				CrouchChance = 0.25,
				ComboWeighting = 0.45,
			},
		},
		HARD = {
			Accuracy = 0.0,
			HitChance = 0.75,
			MovementProfile = {
				SpinChance = 0.85,
				BunnyhopChance = 0.80,
				StrafeChance = 0.95,
				RandomJumpChance = 0.85,
				FreezeChance = 0.10,
				CrouchChance = 0.60,
				ComboWeighting = 0.95,
			},
		},
	},
} :: AiConfig

AimChamberConfig.AI_DIFFICULTY_NAMES = { "EASY", "HARD" }
AimChamberConfig.DEFAULT_AI_DIFFICULTY = "EASY"

AimChamberConfig.MOVEMENT_PROFILES = { "TIER 1", "TIER 2", "TIER 3", "TIER 4", "TIER 5", "RANDOM" }
AimChamberConfig.DEFAULT_MOVEMENT_PROFILE = "TIER 1"

AimChamberConfig.AI_TIER_OVERRIDES = {
	["TIER 3"] = {
		DECISION_TICK_MIN = 0.30,
		DECISION_TICK_MAX = 0.70,
		FLIP_MIN_EASY = 0.45,
		FLIP_MAX_EASY = 1.0,
		FLIP_MIN_HARD = 0.20,
		FLIP_MAX_HARD = 0.50,
		ORBIT_WALK_SPEED_MULTIPLIER = 1.25,
		COMBO_MAX_EASY = 3,
		COMBO_MAX_HARD = 4,
		PATH_SPEED_MULTIPLIER = 1.1,
		JUMP_INTERVAL_MIN = 0.70,
		JUMP_INTERVAL_MAX = 1.80,
		ALLOW_JUMP_DURING_PATH = true,
		PATH_JUMP_CHANCE = 0.68,
	},
	["TIER 4"] = {
		DECISION_TICK_MIN = 0.12,
		DECISION_TICK_MAX = 0.30,
		FLIP_MIN_EASY = 0.12,
		FLIP_MAX_EASY = 0.35,
		FLIP_MIN_HARD = 0.10,
		FLIP_MAX_HARD = 0.28,
		ORBIT_WALK_SPEED_MULTIPLIER = 1.65,
		COMBO_MAX_EASY = 4,
		COMBO_MAX_HARD = 4,
		PATH_SPEED_MULTIPLIER = 1.35,
		JUMP_INTERVAL_MIN = 0.50,
		JUMP_INTERVAL_MAX = 1.30,
		ALLOW_JUMP_DURING_PATH = true,
		PATH_JUMP_CHANCE = 0.78,
		AIM_LERP_ALPHA = 0.35,
	},
	["TIER 5"] = {
		DECISION_TICK_MIN = 0.10,
		DECISION_TICK_MAX = 0.25,
		FLIP_MIN_EASY = 0.10,
		FLIP_MAX_EASY = 0.30,
		FLIP_MIN_HARD = 0.08,
		FLIP_MAX_HARD = 0.22,
		ORBIT_WALK_SPEED_MULTIPLIER = 1.70,
		COMBO_MAX_EASY = 4,
		COMBO_MAX_HARD = 4,
		PATH_SPEED_MULTIPLIER = 1.40,
		JUMP_INTERVAL_MIN = 0.45,
		JUMP_INTERVAL_MAX = 1.20,
		ALLOW_JUMP_DURING_PATH = true,
		PATH_JUMP_CHANCE = 0.80,
		AIM_LERP_ALPHA = 0.40,
		CURSOR_EVASION_ENABLED = true,
		CURSOR_AIM_DOT_THRESHOLD = 0.93,
		CURSOR_EVASION_COOLDOWN = 0.55,
		CURSOR_EVASION_DURATION = 0.40,
		CURSOR_EVASION_SPEED_MULT = 1.0,
		CURSOR_EVASION_DISTANCE = 7.5,
		CURSOR_EVASION_JUMP_CHANCE = 0.55,
	},
}

AimChamberConfig.DATASTORE = {
	SETTINGS_STORE = "AimChamberSettingsV1",
	SETTINGS_KEY_PREFIX = "Settings_",
	RUN_RECORDS_STORE = "AimChamberRunRecordsV1",
	RUN_RECORDS_KEY_PREFIX = "Runs_",
	RUN_TIME_INDEX_STORE = "AimChamberRunTimeIndexV1",
	MAX_STORED_RUNS = 200,
	LEADERBOARD_TIME_STORE = "Aim_TimeV1",
}

AimChamberConfig.WEBHOOK = {

	RATE_LIMIT_WINDOW = 10,
	RATE_LIMIT_MAX = 3,
	FOOTER_TEXT = "VULTARIAN DEFENSE INDUSTRIES",
	USERNAME = "Vultarian Aim Trainer",
}

AimChamberConfig.RATE_LIMITS = {
	REQUEST_OPEN_CONFIG = 1,
	APPLY_CONFIG = 2,
	REQUEST_START_MATCH = 3,
	EXPORT_MOVEMENT = 30,
}

AimChamberConfig.ANOMALY_THRESHOLDS = {
	SUSPICIOUSLY_SHORT_TIME = 2,
	REPEATED_REJECTION_WINDOW = 10,
	REPEATED_REJECTION_MAX = 5,
}

AimChamberConfig.HONEYPOT_TAG = "AimChamberHoneypot"

AimChamberConfig.LeaderboardParts = {
	["AllTimeMostTime"] = {
		Stat = "Time",
		Scope = "AllTime",
		Label = "ASSESSMENT TIME LEADERBOARD",
		Face = Enum.NormalId.Right,
		PixelsPerStud = 60,
	},
}

AimChamberConfig.WORKSPACE_PARTS = {
	CONFIG_PART = "ConfigPart",
	START_PART = "StartPart",
	END_ON_TOUCH = "EndOnTouch",
	INTERACTABLE_FOLDER = "InteractableParts",
	ZOMBIE_SPAWNS_FOLDER = "AimChamberZombieSpawns",
	PLAYER_SPAWN = "AimChamberPlayerSpawn",
	PLAYER_RETURN_SPAWN = "AimChamberReturnSpawn",
}

AimChamberConfig.PROMPTS = {
	CONFIG_TEXT = "CONFIGURE",
	CONFIG_ACTION = "OPEN AIMCHAMBER SETTINGS",
	CONFIG_HOLD = 0,
	CONFIG_DISTANCE = 10,
	START_TEXT = "START",
	START_ACTION = "START AIMCHAMBER MATCH",
	START_HOLD = 0.5,
	START_DISTANCE = 10,
}

local FULL_GUN_ROSTER: AimChamberGunRule = {
	AllowedGuns = AIM_CHAMBER_GUN_NAMES,
	DefaultGun = "H-82",
	Locked = false,
}

local ASSESSMENT_GUN_RULE: AimChamberGunRule = {
	AllowedGuns = { "H-82" },
	DefaultGun = "H-82",
	Locked = true,
}

local AI_GUN_RULE: AimChamberGunRule = {
	AllowedGuns = { "H-82" },
	DefaultGun = "H-82",
	Locked = true,
}

AimChamberConfig.TIER_AVATAR_CONFIG = {
	["TIER 1"] = {
		UserId = 1,
		ForceShirt = nil,
		ForcePants = nil,
		ForceHat = 105051835194265,
		IgnoreHats = false,
		IgnoreHair = false,
		IgnoreAccessories = false,
	},
	["TIER 2"] = {
		UserId = 1,
		ForceShirt = nil,
		ForcePants = nil,
		ForceHat = 105051835194265,
		IgnoreHats = false,
		IgnoreHair = false,
		IgnoreAccessories = false,
	},
	["TIER 3"] = {
		UserId = 1,
		ForceShirt = nil,
		ForcePants = nil,
		ForceHat = 105051835194265,
		IgnoreHats = false,
		IgnoreHair = false,
		IgnoreAccessories = false,
	},
	["TIER 4"] = {
		UserId = 1,
		ForceShirt = nil,
		ForcePants = nil,
		ForceHat = 105051835194265,
		IgnoreHats = false,
		IgnoreHair = false,
		IgnoreAccessories = false,
	},
	["TIER 5"] = {
		UserId = 1,
		ForceShirt = nil,
		ForcePants = nil,
		ForceHat = 105051835194265,
		IgnoreHats = false,
		IgnoreHair = false,
		IgnoreAccessories = false,
	},
}

AimChamberConfig.PRESETS = {
	NORMAL = {
		Id = "NORMAL",
		DisplayName = "NORMAL",
		Settings = {
			IsAiMode = false,
			MaxZombies = 25,
			MaxZombiesEnabled = true,
			ZombieSpeed = 8,
			ZombieDamageEnabled = true,
			ZombieDamageAmount = 25,
			ZombieSpawnRate = 1.5,
			ZombieDodgeInterval = 4,
			ZombieCrouchChance = 0.15,
			AssessmentValidation = false,
			SelectedGun = "H-82",

			MinEngageDistance = 8,
			MaxEngageDistance = 16,
			ApproachSpeedMultiplier = 1.0,
			StrafeSpeedMultiplier = 0.6,
			StrafeHoldMin = 0.6,
			StrafeHoldMax = 1.4,
			StrafeApproachAngle = 55,
			StrafeFlipIntervalMin = 0.5,
			StrafeFlipIntervalMax = 1.1,
			JukeChance = 0.08,
			JukeSpeedMultiplier = 1.5,
			MovementJitter = 0.15,
			OrbitDirectionBias = 0.5,
			ZombieJumpPower = 50,
			OrbitJumpChance = 0.4,
			JumpCooldown = 0.9,
			JukeJumpChance = 0.35,
			BunnyHopEnabled = true,
			BunnyHopChainChance = 0.4,
			BunnyHopSpeedMultiplier = 1.2,
			BunnyHopMaxChain = 2,

			ApproachJukeChance = 0.06,

			MaxOrbitDuration = 3.5,
			CommitSpeedMultiplier = 1.1,
			SeparationMaxForce = 4.0,

			ApproachJumpChance = 0.45,
			ApproachCrouchChance = 0.25,
			CloseRangeJumpChance = 0.3,
			DecisionTimeStaggerMax = 0.4,

			SpawnRateRampEnabled = true,
			SpawnRateRampStartRate = 0.5,
			SpawnRateRampDuration = 250,

			AiDifficulty = nil,
			AiNpcAccuracy = nil,
		},
		Locked = false,
		GunRule = FULL_GUN_ROSTER,
	} :: AimChamberPreset,

	ASSESSMENT = {
		Id = "ASSESSMENT",
		DisplayName = "ASSESSMENT",
		Settings = {
			IsAiMode = false,
			MaxZombies = 25,
			MaxZombiesEnabled = true,
			ZombieSpeed = 8,
			ZombieDamageEnabled = true,
			ZombieDamageAmount = 25,
			ZombieSpawnRate = 2.0,
			ZombieDodgeInterval = 4,
			ZombieCrouchChance = 0.15,
			AssessmentValidation = true,
			SelectedGun = "H-82",

			MinEngageDistance = 8,
			MaxEngageDistance = 16,
			ApproachSpeedMultiplier = 1.0,
			StrafeSpeedMultiplier = 0.6,
			StrafeHoldMin = 0.6,
			StrafeHoldMax = 1.4,
			StrafeApproachAngle = 55,
			StrafeFlipIntervalMin = 0.5,
			StrafeFlipIntervalMax = 1.1,
			JukeChance = 0.08,
			JukeSpeedMultiplier = 1.5,
			MovementJitter = 0.15,
			OrbitDirectionBias = 0.5,
			ZombieJumpPower = 50,
			OrbitJumpChance = 0.4,
			JumpCooldown = 0.9,
			JukeJumpChance = 0.35,
			BunnyHopEnabled = true,
			BunnyHopChainChance = 0.4,
			BunnyHopSpeedMultiplier = 1.2,
			BunnyHopMaxChain = 2,

			ApproachJukeChance = 0.06,

			MaxOrbitDuration = 3.5,
			CommitSpeedMultiplier = 1.1,
			SeparationMaxForce = 4.0,

			ApproachJumpChance = 0.45,
			ApproachCrouchChance = 0.25,
			CloseRangeJumpChance = 0.3,
			DecisionTimeStaggerMax = 0.4,

			SpawnRateRampEnabled = true,
			SpawnRateRampStartRate = 0.5,
			SpawnRateRampDuration = 250,

			AiDifficulty = nil,
			AiNpcAccuracy = nil,
		},
		Locked = true,
		GunRule = ASSESSMENT_GUN_RULE,
	} :: AimChamberPreset,

	HARDCORE = {
		Id = "HARDCORE",
		DisplayName = "HARDCORE",
		Settings = {
			IsAiMode = false,
			MaxZombies = 15,
			MaxZombiesEnabled = false,
			ZombieSpeed = 12,
			ZombieDamageEnabled = true,
			ZombieDamageAmount = 50,
			ZombieSpawnRate = 3.5,
			ZombieDodgeInterval = 1.5,
			ZombieCrouchChance = 0.45,
			AssessmentValidation = false,
			SelectedGun = "H-82",

			MinEngageDistance = 15,
			MaxEngageDistance = 35,
			ApproachSpeedMultiplier = 1.1,
			StrafeSpeedMultiplier = 0.9,
			StrafeHoldMin = 0.4,
			StrafeHoldMax = 1.0,
			StrafeApproachAngle = 75,
			StrafeFlipIntervalMin = 0.3,
			StrafeFlipIntervalMax = 0.7,
			JukeChance = 0.28,
			JukeSpeedMultiplier = 2.2,
			MovementJitter = 0.2,
			OrbitDirectionBias = 0.5,
			ZombieJumpPower = 60,
			OrbitJumpChance = 0.6,
			JumpCooldown = 0.5,
			JukeJumpChance = 0.55,
			BunnyHopEnabled = true,
			BunnyHopChainChance = 0.6,
			BunnyHopSpeedMultiplier = 1.3,
			BunnyHopMaxChain = 3,

			ApproachJukeChance = 0.16,

			MaxOrbitDuration = 1.5,
			CommitSpeedMultiplier = 1.25,
			SeparationMaxForce = 5.0,

			ApproachJumpChance = 0.65,
			ApproachCrouchChance = 0.45,
			CloseRangeJumpChance = 0.4,
			DecisionTimeStaggerMax = 0.4,

			SpawnRateRampEnabled = true,
			SpawnRateRampStartRate = 0.75,
			SpawnRateRampDuration = 150,

			AiDifficulty = nil,
			AiNpcAccuracy = nil,
			AiWeapon = "H-82",
		},
		Locked = false,
		GunRule = FULL_GUN_ROSTER,
	} :: AimChamberPreset,

	AI = {
		Id = "AI",
		DisplayName = "AI",
		Settings = {
			IsAiMode = true,
			MaxZombies = 1,
			MaxZombiesEnabled = false,
			ZombieSpeed = 14,
			ZombieDamageEnabled = true,
			ZombieDamageAmount = 14,
			ZombieSpawnRate = 1,
			ZombieDodgeInterval = 4,
			ZombieCrouchChance = 0,
			AssessmentValidation = false,
			SelectedGun = "H-82",

			MinEngageDistance = 14,
			MaxEngageDistance = 22,
			ApproachSpeedMultiplier = 1.0,
			StrafeSpeedMultiplier = 0.9,
			StrafeHoldMin = 0.55,
			StrafeHoldMax = 1.2,
			StrafeApproachAngle = 70,
			StrafeFlipIntervalMin = 0.35,
			StrafeFlipIntervalMax = 0.85,
			JukeChance = 0.2,
			JukeSpeedMultiplier = 1.8,
			MovementJitter = 0.15,
			OrbitDirectionBias = 0.5,
			ZombieJumpPower = 52,
			OrbitJumpChance = 0.5,
			JumpCooldown = 0.5,
			JukeJumpChance = 0.4,
			BunnyHopEnabled = true,
			BunnyHopChainChance = 0.55,
			BunnyHopSpeedMultiplier = 1.2,
			BunnyHopMaxChain = 3,

			ApproachJukeChance = 0.1,

			MaxOrbitDuration = 3.0,
			CommitSpeedMultiplier = 1.1,
			SeparationMaxForce = 0,

			ApproachJumpChance = 0.5,
			ApproachCrouchChance = 0,
			CloseRangeJumpChance = 0,
			DecisionTimeStaggerMax = 0.3,

			SpawnRateRampEnabled = false,
			SpawnRateRampStartRate = 1,
			SpawnRateRampDuration = 60,
			AiDifficulty = "NORMAL",
			AiNpcAccuracy = 1.0,
			AiWeapon = "H-82",
			AiRounds = 3,
			AiHealth = 100,
		},
		Locked = false,
		GunRule = AI_GUN_RULE,
	} :: AimChamberPreset,
} :: { [string]: AimChamberPreset }

AimChamberConfig.PRESET_ORDER = { "NORMAL", "ASSESSMENT", "HARDCORE", "AI" }

AimChamberConfig.DEFAULT_PRESET = "NORMAL"

function AimChamberConfig.getPreset(presetId: string): AimChamberPreset?
	return AimChamberConfig.PRESETS[presetId]
end

function AimChamberConfig.getDefaultSettings(): AimChamberSettings
	local preset = AimChamberConfig.PRESETS[AimChamberConfig.DEFAULT_PRESET]
	return table.clone(preset.Settings)
end

function AimChamberConfig.clampValue(field: string, value: number): number
	local range = AimChamberConfig.CLAMP_RANGES[field]
	if not range then
		return value
	end
	return math.clamp(value, range.Min, range.Max)
end

function AimChamberConfig.isGunAllowed(presetId: string, gunName: string): boolean
	local preset = AimChamberConfig.PRESETS[presetId]
	if not preset then
		return false
	end
	for _, allowed in preset.GunRule.AllowedGuns do
		if allowed == gunName then
			return true
		end
	end
	return false
end

function AimChamberConfig.formatSpawnRate(rate: number): string
	return string.format(AimChamberConfig.SPAWN_RATE_FORMAT, rate)
end

function AimChamberConfig.formatElapsedTime(seconds: number): string
	local mins = seconds // 60
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", mins, secs)
end

function AimChamberConfig.getAiDifficultyConfig(difficulty: string): AiDifficultyConfig
	local cfg = AimChamberConfig.AI_CONFIG.Difficulties[difficulty]
	if cfg then
		return cfg
	end
	return AimChamberConfig.AI_CONFIG.Difficulties[AimChamberConfig.DEFAULT_AI_DIFFICULTY]
end

return AimChamberConfig
