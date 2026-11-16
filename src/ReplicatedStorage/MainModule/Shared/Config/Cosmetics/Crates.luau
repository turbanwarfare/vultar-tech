--!strict
--!native
--!optimize 2

export type CrateRarity = "Common" | "Uncommon" | "Rare" | "Legendary" | "Mythic"

export type CrateDrop = {
	category: "GunSkin" | "PlayerCard",
	id: string,
	skinId: string?,
	weaponName: string?,
	packName: string?,
	unlocks: { string }?,
	rarity: CrateRarity,
	isFeatured: boolean?,
	preview: boolean?,
}

export type ClassPack = {
	name: string,
	guns: { string },
}

export type CrateOdds = {
	rarity: CrateRarity,
	chance: number,
}

export type CrateConfig = {
	id: string,
	name: string,
	rarity: CrateRarity,
	price: number,
	modelName: string,
	odds: { CrateOdds },
	drops: { CrateDrop },
	visible: boolean?,
	jackpotSkinId: string?,
	jackpotWeaponName: string?,
	badge: string?,
	subtitle: string?,
	accentColor: Color3?,
	yawAngleDeg: number?,
	cameraElevationDeg: number?,
	paddingMultiplier: number?,
}

export type RollResult = {
	category: "GunSkin" | "PlayerCard",
	id: string,
	skinId: string?,
	weaponName: string?,
	packName: string?,
	rarity: CrateRarity,
	isDuplicate: boolean,
	refundAmount: number?,
}

export type CrateOpenResponse = {
	success: boolean,
	results: { RollResult }?,
	totalCost: number?,
	totalRefund: number?,
	newBalance: number?,
	error: string?,
}

local Crates = {}

Crates.QUANTITY_OPTIONS = { 1, 3, 5, 8, 10 }
Crates.PLACEHOLDER_ANIM_SECONDS = 0.95
Crates.BOX_ANIM_DURATION = 0.95
Crates.DUPLICATE_REFUND_PENALTY = 0.6
Crates.DUPLICATE_CONVERSION_RATE = 1 - Crates.DUPLICATE_REFUND_PENALTY
Crates.DUPLICATE_SOUND = {
	AssetId = "rbxassetid://137214707166921",
	Volume = 0.80,
	PlaybackSpeed = 1.0,
}
Crates.MAX_DISPLAY_SLOTS = 3
Crates.SKIP_KEYBIND = Enum.KeyCode.F
Crates.STAGGER_REVEAL_DELAY = 0.25
Crates.HOLD_REVEAL_SECONDS = 2.5
Crates.SMOKE_EFFECT_PLACEHOLDER = ""

Crates.BOX_ANIMATIONS = {
	Common = {
		TotalDuration = 0.95,
		Beat1_Settle = {
			Duration = 0.25,
			DipDistance = 0.85,
			EmblemPeakTransparency = 0.10,
			EmblemRestTransparency = 0.70,
		},
		Beat2_LidPop = {
			Duration = 0.35,
			LiftDistance = 0.40,
			EasingStyle = Enum.EasingStyle.Quad,
			EasingDirection = Enum.EasingDirection.Out,
		},
		Beat3_Reveal = {
			Duration = 0.35,
			ClearLiftDistance = 1.8,
			FadeLid = true,
			GlowDuration = 0.35,
		},
		SeamBreach = {
			SeamWidth = 260,
			SeamYScale = 0.452,
			DimAlpha = 0.50,
			MaxBreachHeight = 16,
			GlowBloomWidth = 340,
			GlowBloomHeight = 75,
			BeamWidth = 140,
			BeamHeight = 420,
			BeamDuration = 0.40,
			VignetteDuration = 0.35,
			VignettePeakTransparency = 0.80,
		},
		Sounds = {
			ChargeUp = { AssetId = "rbxassetid://119091876232528", Volume = 0.65, PlaybackSpeed = 1.0 },
			LidPop = { AssetId = "rbxassetid://74574444991136", Volume = 0.75, PlaybackSpeed = 1.0 },
			Reveal = { AssetId = "rbxassetid://93793342329453", Volume = 0.80, PlaybackSpeed = 1.0 },
		},
	},

	Uncommon = {
		TotalDuration = 0.95,
		Beat1_Settle = {
			Duration = 0.25,
			DipDistance = 0.85,
			EmblemPeakTransparency = 0.10,
			EmblemRestTransparency = 0.70,
		},
		Beat2_LidPop = {
			Duration = 0.35,
			LiftDistance = 0.40,
			EasingStyle = Enum.EasingStyle.Quad,
			EasingDirection = Enum.EasingDirection.Out,
		},
		Beat3_Reveal = {
			Duration = 0.35,
			ClearLiftDistance = 1.8,
			FadeLid = true,
			GlowDuration = 0.35,
		},
		SeamBreach = {
			SeamWidth = 260,
			SeamYScale = 0.452,
			DimAlpha = 0.50,
			MaxBreachHeight = 16,
			GlowBloomWidth = 340,
			GlowBloomHeight = 75,
			BeamWidth = 140,
			BeamHeight = 420,
			BeamDuration = 0.40,
			VignetteDuration = 0.35,
			VignettePeakTransparency = 0.80,
		},
		Sounds = {
			ChargeUp = { AssetId = "rbxassetid://119091876232528", Volume = 0.65, PlaybackSpeed = 1.0 },
			LidPop = { AssetId = "rbxassetid://74574444991136", Volume = 0.75, PlaybackSpeed = 1.0 },
			Reveal = { AssetId = "rbxassetid://93793342329453", Volume = 0.80, PlaybackSpeed = 1.0 },
		},
	},

	Rare = {
		TotalDuration = 1.48,
		Beat0_Shake = {
			Pulse1_Duration = 0.10,
			Pulse1_AngleDeg = 1.2,
			Pulse2_Duration = 0.12,
			Pulse2_AngleDeg = 2.4,
			Pause = 0.06,
		},
		Beat1_Settle = {
			Duration = 0.25,
			DipDistance = 1.15,
			EmblemPeakTransparency = 0.05,
			EmblemRestTransparency = 0.70,
		},
		Beat2_LidPop = {
			CrackDuration = 0.08,
			CrackTiltDeg = 4.5,
			CrackHold = 0.16,
			Duration = 0.36,
			MaxSwingAngle = 78.0,
			LiftDistance = 0.65,
			EasingStyle = Enum.EasingStyle.Quad,
			EasingDirection = Enum.EasingDirection.Out,
		},
		Beat3_Reveal = {
			Duration = 0.35,
			ClearLiftDistance = 2.40,
			FinalSwingAngle = 92.0,
			FadeLid = true,
			GlowDuration = 0.35,
		},
		SeamBreach = {
			SeamWidth = 360,
			SeamYScale = 0.452,
			DimAlpha = 0.55,
			MaxBreachHeight = 20,
			GlowBloomWidth = 460,
			GlowBloomHeight = 90,
			BeamWidth = 200,
			BeamHeight = 480,
			BeamDuration = 0.42,
			VignetteDuration = 0.38,
			VignettePeakTransparency = 0.75,
		},
		Sounds = {
			AnticipationShake = { AssetId = "rbxassetid://72500887678395", Volume = 0.65, PlaybackSpeed = 1.0 },
			ChargeUp = { AssetId = "rbxassetid://127659074743226", Volume = 0.75, PlaybackSpeed = 1.0 },
			LidPop = { AssetId = "rbxassetid://74574444991136", Volume = 0.80, PlaybackSpeed = 1.0 },
			Reveal = { AssetId = "rbxassetid://93793342329453", Volume = 0.80, PlaybackSpeed = 1.0 },
		},
	},

	Legendary = {
		TotalDuration = 1.48,
		Beat0_Shake = {
			Pulse1_Duration = 0.10,
			Pulse1_AngleDeg = 1.2,
			Pulse2_Duration = 0.12,
			Pulse2_AngleDeg = 2.4,
			Pause = 0.06,
		},
		Beat1_Settle = {
			Duration = 0.25,
			DipDistance = 1.15,
			EmblemPeakTransparency = 0.05,
			EmblemRestTransparency = 0.70,
		},
		Beat2_LidPop = {
			CrackDuration = 0.08,
			CrackTiltDeg = 4.5,
			CrackHold = 0.16,
			Duration = 0.36,
			MaxSwingAngle = 78.0,
			LiftDistance = 0.65,
			EasingStyle = Enum.EasingStyle.Quad,
			EasingDirection = Enum.EasingDirection.Out,
		},
		Beat3_Reveal = {
			Duration = 0.35,
			ClearLiftDistance = 2.40,
			FinalSwingAngle = 92.0,
			FadeLid = true,
			GlowDuration = 0.35,
		},
		SeamBreach = {
			SeamWidth = 360,
			SeamYScale = 0.452,
			DimAlpha = 0.65,
			MaxBreachHeight = 22,
			GlowBloomWidth = 460,
			GlowBloomHeight = 100,
			BeamWidth = 220,
			BeamHeight = 520,
			BeamDuration = 0.45,
			VignetteDuration = 0.40,
			VignettePeakTransparency = 0.60,
		},
		Sounds = {
			AnticipationShake = { AssetId = "rbxassetid://72500887678395", Volume = 0.65, PlaybackSpeed = 1.0 },
			ChargeUp = { AssetId = "rbxassetid://127659074743226", Volume = 0.75, PlaybackSpeed = 1.0 },
			LidPop = { AssetId = "rbxassetid://74574444991136", Volume = 0.80, PlaybackSpeed = 1.0 },
			Reveal = { AssetId = "rbxassetid://93793342329453", Volume = 0.80, PlaybackSpeed = 1.0 },
		},
	},

	RareOverlay = {
		Color = Color3.fromRGB(51, 84, 231),
		StutterFlicker = {
			Duration = 0.12,
			FlickerCount = 3,
			MinAlpha = 0.25,
			MaxAlpha = 1.0,
		},
		SeamBreach = {
			SeamWidth = 280,
			SeamYScale = 0.452,
			DimAlpha = 0.65,
			MaxBreachHeight = 22,
			GlowBloomWidth = 390,
			GlowBloomHeight = 90,
			BeamWidth = 185,
			BeamHeight = 490,
			BeamDuration = 0.45,
			VignetteDuration = 0.40,
			VignettePeakTransparency = 0.55,
		},
		Sounds = {
			EscalationCharge = { AssetId = "", Volume = 0.75 },
		},
	},

	LegendaryOverlay = {
		Color = Color3.fromRGB(195, 214, 25),
		DimDuration = 0.22,
		DimTransparency = 0.30,
		EmblemFlashColor = Color3.fromRGB(195, 214, 25),
		EmblemFlashHold = 0.25,
		LidEmphasisExtraLift = 0.15,
		PreJerkDistance = 0.05,
		PreJerkDuration = 0.08,
		HeldJerkPause = 0.12,
		GlowColor = Color3.fromRGB(195, 214, 25),
		GlowDuration = 0.35,
		StutterFlicker = {
			Duration = 0.15,
			FlickerCount = 4,
			MinAlpha = 0.15,
			MaxAlpha = 1.0,
		},
		SeamBreach = {
			SeamWidth = 320,
			SeamYScale = 0.452,
			DimAlpha = 0.85,
			MaxBreachHeight = 28,
			GlowBloomWidth = 460,
			GlowBloomHeight = 115,
			BeamWidth = 240,
			BeamHeight = 560,
			BeamDuration = 0.50,
			VignetteDuration = 0.45,
			VignettePeakTransparency = 0.40,
		},
		Sounds = {
			EscalationCharge = { AssetId = "", Volume = 0.85 },
			StingerLayer = { AssetId = "rbxassetid://105406797322536", Volume = 0.85, PlaybackSpeed = 1.0, TimePosition = 1.63 },
		},
	},
}

Crates.EFFECTS = {
	Common = {
		Ripple = true,
	},
	Uncommon = {
		Ripple = true,
		RingPulse = {
			StartScale = 0.85,
			EndScale = 1.35,
			Duration = 0.4,
		},
		Sound = {
			AssetId = "rbxassetid://102771574969417",
			Volume = 0.75,
			PlaybackSpeed = 1.0,
		},
	},
	Rare = {
		ParticleCount = 24,
		Starburst = {
			RayCount = 10,
			RayLength = 180,
			RayThickness = 3,
			Duration = 0.85,
		},
		VignetteFlash = {
			PeakTransparency = 0.82,
			Duration = 0.65,
		},
		Sound = {
			AssetId = "rbxassetid://132689858015056",
			Volume = 0.85,
			PlaybackSpeed = 1.0,
			TimePosition = 0.95,
		},
	},
	Legendary = {
		DarkenOverlay = {
			Duration = 0.85,
			Transparency = 0.40,
		},
		LightPillar = {
			BaseWidth = 360,
			Height = 760,
			Duration = 0.95,
		},
		ParticleCount = 32,
		ScreenShake = {
			Magnitude = 5,
			Duration = 0.85,
		},
		SlowRevealDelay = 0.5,
		Sounds = {
			{
				AssetId = "rbxassetid://105406797322536",
				Volume = 0.95,
				PlaybackSpeed = 1.0,
				TimePosition = 1.63,
			},
			{
				AssetId = "rbxassetid://111519265351354",
				Volume = 0.80,
				PlaybackSpeed = 1.0,
				TimePosition = 1.70,
			},
		},
		Sound = {
			AssetId = "rbxassetid://105406797322536",
			Volume = 0.95,
			PlaybackSpeed = 1.0,
			TimePosition = 1.63,
		},
		StingerLayer = {
			AssetId = "rbxassetid://111519265351354",
			Volume = 0.80,
			PlaybackSpeed = 1.0,
			TimePosition = 1.70,
		},
	},
	Mythic = {
		DarkenOverlay = {
			Duration = 0.85,
			Transparency = 0.20,
		},
		LightPillar = {
			BaseWidth = 420,
			Height = 840,
			Duration = 0.85,
		},
		ParticleCount = 40,
		ScreenShake = {
			Magnitude = 6,
			Duration = 0.45,
		},
		SlowRevealDelay = 0.85,
		Sounds = {
			{
				AssetId = "rbxassetid://113203917006664",
				Volume = 0.95,
				PlaybackSpeed = 1.0,
			},
			{
				AssetId = "rbxassetid://80641899029934",
				Volume = 0.90,
				PlaybackSpeed = 1.0,
			},
		},
	},
}

Crates.BOX_ANIMATIONS.Mythic = Crates.BOX_ANIMATIONS.Legendary

Crates.RarityOrder = { "Common", "Uncommon", "Rare", "Legendary", "Mythic" } :: { CrateRarity }

Crates.RarityColors = {
	Common = Color3.fromRGB(160, 165, 180),
	Uncommon = Color3.fromRGB(27, 145, 62),
	Rare = Color3.fromRGB(51, 84, 231),
	Legendary = Color3.fromRGB(195, 214, 25),
	Mythic = Color3.fromRGB(255, 45, 65),
} :: { [CrateRarity]: Color3 }

Crates.RarityLabels = {
	Common = "COMMON",
	Uncommon = "UNCOMMON",
	Rare = "RARE",
	Legendary = "LEGENDARY",
	Mythic = "MYTHIC",
} :: { [CrateRarity]: string }

Crates.RarityGradients = {
	Common = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(29, 30, 32)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 165, 180)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(29, 30, 32)),
	}),
	Uncommon = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(5, 26, 11)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(27, 145, 62)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 26, 11)),
	}),
	Rare = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(9, 15, 42)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(51, 84, 231)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(9, 15, 42)),
	}),
	Legendary = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 39, 5)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(195, 214, 25)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 39, 5)),
	}),
	Mythic = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 8, 14)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 45, 65)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 8, 14)),
	}),
}

Crates.CategoryLabels = {
	GunSkin = "GUN SKIN",
	PlayerCard = "PLAYER CARD",
}

function Crates.createPackDrops(skinId: string, packs: { ClassPack }, rarity: CrateRarity, options: { isFeatured: boolean?, preview: boolean? }?): { CrateDrop }
	local drops: { CrateDrop } = {}
	for _, pack in packs do
		local unlocks: { string } = {}
		for _, gun in pack.guns do
			table.insert(unlocks, `{skinId}:{gun}`)
		end
		table.insert(drops, {
			category = "GunSkin",
			id = `{skinId}:{pack.name}`,
			skinId = skinId,
			weaponName = pack.guns[1],
			packName = `{pack.name} Pack`,
			unlocks = unlocks,
			rarity = rarity,
			isFeatured = options and options.isFeatured,
			preview = options and options.preview,
		})
	end
	return drops
end

local ASSAULT_PACKS: { ClassPack } = {
	{ name = "Assault", guns = { "H-82", "BR-16" } },
	{ name = "Pistol", guns = { "H-12", "BR-8" } },
}

local CLASS_PACKS: { ClassPack } = {
	{ name = "Shocktrooper", guns = { "H-41", "BR-40" } },
	{ name = "Devastator", guns = { "H-94", "BR-56" } },
	{ name = "Flag Bearer", guns = { "H-22", "BR-22" } },
	{ name = "Recon", guns = { "H-50", "BR-50" } },
}

local function concat<T>(...: { T }): { T }
	local result: { T } = {}
	for _, list in { ... } do
		for _, item in list do
			table.insert(result, item)
		end
	end
	return result
end

local ALL_PACKS: { ClassPack } = concat(ASSAULT_PACKS, CLASS_PACKS)

local COMMON_DROPS: { CrateDrop } = {
	{ category = "GunSkin", id = "HelloKitty", rarity = "Legendary", isFeatured = true, preview = true },
	{ category = "GunSkin", id = "Samurai", rarity = "Rare", preview = true },
	{ category = "PlayerCard", id = "Vex_PlayerCard", rarity = "Rare", preview = true },
	{ category = "PlayerCard", id = "Vultar_PlayerCard", rarity = "Rare" },
	{ category = "GunSkin", id = "Digi", rarity = "Uncommon" },
	{ category = "GunSkin", id = "Clones", rarity = "Uncommon" },
	{ category = "GunSkin", id = "Magma", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Byte_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Beamer_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Cloud_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Space_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Punisher_PlayerCard", rarity = "Uncommon" },
	{ category = "GunSkin", id = "Moo", rarity = "Common" },
	{ category = "GunSkin", id = "EVA", rarity = "Common" },
	{ category = "GunSkin", id = "Night", rarity = "Common" },
	{ category = "GunSkin", id = "Tech", rarity = "Common" },
	{ category = "PlayerCard", id = "Waves_PlayerCard", rarity = "Common" },
	{ category = "PlayerCard", id = "Arc_PlayerCard", rarity = "Common" },
	{ category = "PlayerCard", id = "Vette_PlayerCard", rarity = "Common" },
	{ category = "PlayerCard", id = "Apocolypse_PlayerCard", rarity = "Common" },
	{ category = "PlayerCard", id = "ISeeYou_PlayerCard", rarity = "Common" },
	{ category = "PlayerCard", id = "Commando_PlayerCard", rarity = "Common" },
	{ category = "PlayerCard", id = "Punished_PlayerCard", rarity = "Common" },
}

local UNCOMMON_DROPS: { CrateDrop } = {
	{ category = "GunSkin", id = "Freeze", rarity = "Legendary", isFeatured = true, preview = true },
	{ category = "PlayerCard", id = "Night_Animated_PlayerCard", rarity = "Legendary", preview = true },
	{ category = "GunSkin", id = "Volatil", rarity = "Rare", preview = true },
	{ category = "PlayerCard", id = "Beast_PlayerCard", rarity = "Rare", preview = true },
	{ category = "PlayerCard", id = "Berserk_PlayerCard", rarity = "Rare", preview = true },
	{ category = "GunSkin", id = "Samurai", rarity = "Rare" },
	{ category = "GunSkin", id = "Magma", rarity = "Uncommon" },
	{ category = "GunSkin", id = "Glitch", rarity = "Uncommon" },
	{ category = "GunSkin", id = "Clones", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Koenig_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Digi_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "GT3RS_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Beamer_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Byte_PlayerCard", rarity = "Uncommon" },
	{ category = "GunSkin", id = "Green", rarity = "Common" },
	{ category = "GunSkin", id = "Night", rarity = "Common" },
	{ category = "GunSkin", id = "Tech", rarity = "Common" },
	{ category = "GunSkin", id = "EVA", rarity = "Common" },
	{ category = "PlayerCard", id = "Commando_PlayerCard", rarity = "Common" },
	{ category = "PlayerCard", id = "Night_PlayerCard", rarity = "Common" },
	{ category = "PlayerCard", id = "Lit_PlayerCard", rarity = "Common" },
	{ category = "PlayerCard", id = "Waves_PlayerCard", rarity = "Common" },
	{ category = "PlayerCard", id = "Apocolypse_PlayerCard", rarity = "Common" },
	{ category = "PlayerCard", id = "FarAway_PlayerCard", rarity = "Common" },
}
-- Hi
local ELITE_DROPS: { CrateDrop } = {
	{ category = "PlayerCard", id = "Freeze_PlayerCard", rarity = "Legendary", isFeatured = true, preview = true },
	{ category = "GunSkin", id = "PixelGun", rarity = "Legendary", preview = true },
	{ category = "GunSkin", id = "Beast", rarity = "Rare", preview = true },
	{ category = "PlayerCard", id = "Toxic_PlayerCard", rarity = "Rare", preview = true },
	{ category = "PlayerCard", id = "PixelGun_PlayerCard", rarity = "Rare" },
	{ category = "GunSkin", id = "Volatil", rarity = "Rare" },
	{ category = "PlayerCard", id = "Vex_PlayerCard", rarity = "Rare" },
	{ category = "GunSkin", id = "Punished", rarity = "Uncommon" },
	{ category = "GunSkin", id = "Waves", rarity = "Uncommon" },
	{ category = "GunSkin", id = "Commando", rarity = "Uncommon" },
	{ category = "GunSkin", id = "Digi", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Space_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Cloud_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Punisher_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Volatil_PlayerCard", rarity = "Uncommon" },
	{ category = "GunSkin", id = "Tech", rarity = "Common" },
	{ category = "GunSkin", id = "Fantastique", rarity = "Common" },
	{ category = "GunSkin", id = "Far Away", rarity = "Common" },
	{ category = "GunSkin", id = "Moo", rarity = "Common" },
	{ category = "PlayerCard", id = "Punished_PlayerCard", rarity = "Common" },
	{ category = "PlayerCard", id = "Meow_PlayerCard", rarity = "Common" },
	{ category = "PlayerCard", id = "Dead_PlayerCard", rarity = "Common" },
	{ category = "PlayerCard", id = "Duty_PlayerCard", rarity = "Common" },
	{ category = "PlayerCard", id = "Lit_PlayerCard", rarity = "Common" },
}

local LEGENDARY_DROPS: { CrateDrop } = {
	{ category = "GunSkin", id = "Freeze", rarity = "Legendary", isFeatured = true, preview = true },
	{ category = "PlayerCard", id = "Cloud_Animated_PlayerCard", rarity = "Legendary", preview = true },
	{ category = "PlayerCard", id = "Volatil_Animated_PlayerCard", rarity = "Legendary", preview = true },
	{ category = "GunSkin", id = "Toxic", rarity = "Rare", preview = true },
	{ category = "GunSkin", id = "Vex", rarity = "Rare", preview = true },
	{ category = "PlayerCard", id = "BeautifulDeath_PlayerCard", rarity = "Rare", preview = true },
	{ category = "GunSkin", id = "Beast", rarity = "Rare" },
	{ category = "PlayerCard", id = "Vultar_PlayerCard", rarity = "Rare" },
	{ category = "PlayerCard", id = "Regal_PlayerCard", rarity = "Rare" },
	{ category = "GunSkin", id = "Glitch", rarity = "Uncommon" },
	{ category = "GunSkin", id = "Digi", rarity = "Uncommon" },
	{ category = "GunSkin", id = "Commando", rarity = "Uncommon" },
	{ category = "GunSkin", id = "Magma", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Volatil_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Byte_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "GT3RS_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Space_PlayerCard", rarity = "Uncommon" },
}

local MYTHIC_DROPS: { CrateDrop } = {
	{ category = "GunSkin", id = "Maxwell", rarity = "Legendary", isFeatured = true, preview = true },
	{ category = "PlayerCard", id = "HelloKitty_PlayerCard", rarity = "Legendary", preview = true },
	{ category = "GunSkin", id = "Vex", rarity = "Rare", preview = true },
	{ category = "GunSkin", id = "Toxic", rarity = "Rare", preview = true },
	{ category = "PlayerCard", id = "Beast_PlayerCard", rarity = "Rare", preview = true },
	{ category = "PlayerCard", id = "Berserk_PlayerCard", rarity = "Rare" },
	{ category = "PlayerCard", id = "BeautifulDeath_PlayerCard", rarity = "Rare" },
	{ category = "PlayerCard", id = "Toxic_PlayerCard", rarity = "Rare" },
	{ category = "GunSkin", id = "Punished", rarity = "Uncommon" },
	{ category = "GunSkin", id = "Commando", rarity = "Uncommon" },
	{ category = "GunSkin", id = "Waves", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Koenig_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Punisher_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Digi_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "GT3RS_PlayerCard", rarity = "Uncommon" },
	{ category = "PlayerCard", id = "Volatil_PlayerCard", rarity = "Uncommon" },
}

local function withMythic(skinId: string, packs: { ClassPack }, rest: { CrateDrop }): { CrateDrop }
	local drops = Crates.createPackDrops(skinId, packs, "Mythic", { isFeatured = true, preview = true })
	for _, drop in rest do
		table.insert(drops, drop)
	end
	return drops
end

local function withFullSets(skinIds: { string }, rest: { CrateDrop }): { CrateDrop }
	local drops: { CrateDrop } = {}
	for i, skinId in skinIds do
		table.insert(drops, {
			category = "GunSkin",
			id = skinId,
			rarity = "Mythic",
			isFeatured = i == 1,
			preview = true,
		})
	end
	for _, drop in rest do
		table.insert(drops, drop)
	end
	return drops
end

Crates.All = {
	{
		id = "Standard",
		name = "Field Cache",
		rarity = "Common",
		price = 400,
		modelName = "Common",
		jackpotSkinId = "HelloKitty",
		jackpotWeaponName = "H-82",
		badge = nil,
		subtitle = "Standard issue from frontline supply drops",
		accentColor = Color3.fromRGB(160, 165, 180),
		odds = {
			{ rarity = "Common", chance = 72 },
			{ rarity = "Uncommon", chance = 21 },
			{ rarity = "Rare", chance = 6 },
			{ rarity = "Legendary", chance = 1 },
		},

		drops = COMMON_DROPS,
	},

	{
		id = "Skin",
		name = "Armory Crate",
		rarity = "Uncommon",
		price = 800,
		modelName = "Uncommon",
		jackpotSkinId = "Freeze",
		jackpotWeaponName = "H-82",
		badge = nil,
		subtitle = "Finishes pulled from the Vultar armory",
		accentColor = Color3.fromRGB(27, 145, 62),
		odds = {
			{ rarity = "Common", chance = 55 },
			{ rarity = "Uncommon", chance = 30 },
			{ rarity = "Rare", chance = 11 },
			{ rarity = "Legendary", chance = 4 },
		},

		drops = UNCOMMON_DROPS,
	},

	{
		id = "Elite",
		name = "Elite Cache",
		rarity = "Rare",
		price = 1600,
		modelName = "Rare",
		jackpotSkinId = "Freeze",
		jackpotWeaponName = "H-50",
		subtitle = "Guinea packs for every class",
		accentColor = Color3.fromRGB(51, 84, 231),
		odds = {
			{ rarity = "Common", chance = 40 },
			{ rarity = "Uncommon", chance = 32 },
			{ rarity = "Rare", chance = 16 },
			{ rarity = "Legendary", chance = 8 },
			{ rarity = "Mythic", chance = 4 },
		},

		drops = withMythic("Guinea", ALL_PACKS, ELITE_DROPS),
	},

	{
		id = "Legendary",
		name = "Legendary Vault",
		rarity = "Legendary",
		price = 2500,
		modelName = "Legendary",
		jackpotSkinId = "Freeze",
		jackpotWeaponName = "H-82",
		subtitle = "The full Regal skin in one pull",
		accentColor = Color3.fromRGB(195, 214, 25),
		yawAngleDeg = 152,
		cameraElevationDeg = 12,
		paddingMultiplier = 0.85,
		odds = {
			{ rarity = "Uncommon", chance = 32 },
			{ rarity = "Rare", chance = 45 },
			{ rarity = "Legendary", chance = 20 },
			{ rarity = "Mythic", chance = 3 },
		},

		drops = withFullSets({ "Regal" }, LEGENDARY_DROPS),
	},

	{
		id = "Mythic",
		name = "MYTHIC",
		rarity = "Mythic",
		price = 4000,
		modelName = "MythicCrate",
		jackpotSkinId = "Guinea",
		jackpotWeaponName = "H-82",
		subtitle = "Every Capybara and Racoon skin in one pull",
		accentColor = Color3.fromRGB(255, 45, 65),
		yawAngleDeg = 152,
		cameraElevationDeg = 12,
		paddingMultiplier = 0.85,
		odds = {
			{ rarity = "Uncommon", chance = 32.5 },
			{ rarity = "Rare", chance = 40 },
			{ rarity = "Legendary", chance = 22.5 },
			{ rarity = "Mythic", chance = 5 },
		},

		drops = withFullSets({ "Capybara", "Racoon" }, MYTHIC_DROPS),
	},
} :: { CrateConfig }

local cratesById: { [string]: CrateConfig } = {}
for _, crate in Crates.All do
	cratesById[crate.id] = crate
end

function Crates.getAllCrates(): { CrateConfig }
	local visible: { CrateConfig } = {}
	for _, crate in Crates.All do
		if crate.visible ~= false then
			table.insert(visible, crate)
		end
	end
	return visible
end

function Crates.getCrateById(id: string): CrateConfig?
	return cratesById[id]
end

function Crates.getRarityColor(rarity: CrateRarity): Color3
	return Crates.RarityColors[rarity] or Crates.RarityColors.Common
end

function Crates.getDropsByRarity(crate: CrateConfig, rarity: CrateRarity): { CrateDrop }
	local matches: { CrateDrop } = {}
	for _, drop in crate.drops do
		if drop.rarity == rarity then
			table.insert(matches, drop)
		end
	end
	return matches
end

function Crates.getDropCount(crate: CrateConfig, rarity: CrateRarity): number
	local count = 0
	for _, drop in crate.drops do
		if drop.rarity == rarity then
			count += 1
		end
	end
	return count
end

function Crates.getChance(crate: CrateConfig, rarity: CrateRarity): number
	for _, entry in crate.odds do
		if entry.rarity == rarity then
			return entry.chance
		end
	end
	return 0
end

function Crates.getItemChance(crate: CrateConfig, drop: CrateDrop): (number, number)
	local tierChance = Crates.getChance(crate, drop.rarity)
	local count = Crates.getDropCount(crate, drop.rarity)
	local perItem = if count > 0 then tierChance / count else 0
	return tierChance, perItem
end

Crates.ROUNDING_NOTICE = "Probabilities are rounded; total of displayed individual probabilities may not equal 100%."

function Crates.formatChance(chance: number): string
	return string.format("%.5g%%", chance)
end

function Crates.isChanceRounded(chance: number): boolean
	return tonumber(string.format("%.5g", chance)) ~= chance
end

function Crates.hasRoundedChances(crate: CrateConfig): boolean
	for _, entry in crate.odds do
		local count = Crates.getDropCount(crate, entry.rarity)
		if Crates.isChanceRounded(entry.chance) or (count > 0 and Crates.isChanceRounded(entry.chance / count)) then
			return true
		end
	end
	return false
end

function Crates.duplicateNotice(): string
	return `Duplicate item drops are automatically converted to Credits at {math.round(Crates.DUPLICATE_CONVERSION_RATE * 100)}% of the crate's price.`
end

function Crates.getPreviewDrops(crate: CrateConfig): { CrateDrop }
	local previews: { CrateDrop } = {}
	local featured: CrateDrop? = nil

	for _, drop in crate.drops do
		if drop.isFeatured and not featured then
			featured = drop
		end
	end

	if featured then
		table.insert(previews, featured)
	end

	for _, drop in crate.drops do
		if drop ~= featured and drop.preview then
			table.insert(previews, drop)
		end
	end

	if #previews == 0 then
		for _, drop in crate.drops do
			if drop.rarity == "Legendary" or drop.rarity == "Rare" then
				table.insert(previews, drop)
				if #previews >= 5 then
					break
				end
			end
		end
	end

	if #previews > 5 then
		local capped: { CrateDrop } = {}
		for i = 1, 5 do
			table.insert(capped, previews[i])
		end
		previews = capped
	end

	return previews
end

return Crates
