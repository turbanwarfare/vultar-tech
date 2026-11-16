--!nonstrict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Constants = require(MainModule.Shared.Config.Constants)

export type UniformSetting = {
	key: string,
	label: string,
	controlType: "Boolean" | "Pick",
	options: { string }?,
	visibleWhen: string?,
}

export type UniformVariantOption = {
	key: string,
	variantName: string,
	shirtId: number?,
	pantId: number?,
	minRank: number?,
}

export type UniformVariant = {
	key: string,
	variantName: string,
	groupId: number,
	divisionName: string,
	accentColor: Color3,
	shirtId: number?,
	pantId: number?,
	settings: { UniformSetting }?,
	variants: { UniformVariantOption }?,
}

local NOOBIC_SETTINGS: { UniformSetting } = {
	{
		key = "noobicSkinColor",
		label = "Noobic Skin Color",
		controlType = "Boolean",
		options = nil,
		visibleWhen = nil,
	},
	{
		key = "torsoColor",
		label = "Torso Color",
		controlType = "Pick",
		options = { "Blue", "Red", "Green" },
		visibleWhen = "noobicSkinColor",
	},
}

local ALL_UNIFORMS: { UniformVariant } = {
	{
		key = "VULTAR",
		variantName = "Vultarians",
		groupId = Constants.GROUPS.VULTAR,
		divisionName = "Imperium of Vultar",
		accentColor = Color3.fromRGB(100, 13, 13),
		variants = {
			{
				key = "PVT",
				variantName = "Private",
				shirtId = 125441213302774,
				pantId = 132762889359485,
				minRank = Constants.RANKS["PRIVATE"],
			},
			{
				key = "PFC",
				variantName = "Private First Class",
				shirtId = 93739664002348,
				pantId = 132762889359485,
				minRank = Constants.RANKS["PRIVATE_FIRST_CLASS"],
			},
			{
				key = "LCPL",
				variantName = "Lance Corporal",
				shirtId = 122160311480993,
				pantId = 109284688039040,
				minRank = Constants.RANKS["LANCE_CORPORAL"],
			},
			{
				key = "CPL",
				variantName = "Corporal",
				shirtId = 79546583368848,
				pantId = 109284688039040,
				minRank = Constants.RANKS["CORPORAL"],
			},
			{
				key = "SGT",
				variantName = "Sergeant",
				shirtId = 111146512203354,
				pantId = 95691257158056,
				minRank = Constants.RANKS["SERGEANT"],
			},
			{
				key = "WO",
				variantName = "Warrant Officer",
				shirtId = 81945231759350,
				pantId = 135009166786543,
				minRank = Constants.RANKS["WARRANT_OFFICER"],
			},
			{
				key = "LT",
				variantName = "Lieutenant",
				shirtId = 96237734962121,
				pantId = 116596140846174,
				minRank = Constants.RANKS["LIEUTENANT"],
			},
			{
				key = "CPT",
				variantName = "Captain",
				shirtId = 118523818941017,
				pantId = 116596140846174,
				minRank = Constants.RANKS["CAPTAIN"],
			},
			{
				key = "MJR",
				variantName = "Major",
				shirtId = 71807612450991,
				pantId = 113705050568268,
				minRank = Constants.RANKS["MAJOR"],
			},
			{
				key = "COL",
				variantName = "Colonel",
				shirtId = 93435740259958,
				pantId = 139483160847233,
				minRank = Constants.RANKS["COLONEL"],
			},
		},
	},
	{
		key = "VIA",
		variantName = "Initiates",
		groupId = Constants.GROUPS.VIA,
		divisionName = "Vultarian Initiate Academy",
		accentColor = Color3.fromRGB(66, 66, 66),
		variants = {
			{
				key = "STAGE 1",
				variantName = "Stage 1",
				shirtId = 136928452053496,
				pantId = 132762889359485,
				minRank = Constants.VIA_RANKS["STAGE_1"],
			},
			{
				key = "STAGE 2",
				variantName = "Stage 2",
				shirtId = 121831029187348,
				pantId = 132762889359485,
				minRank = Constants.VIA_RANKS["STAGE_2"],
			},
			{
				key = "STAGE 3",
				variantName = "Stage 3",
				shirtId = 71223737327692,
				pantId = 132762889359485,
				minRank = Constants.VIA_RANKS["STAGE_3"],
			},
		},
	},
	{
		key = "3ND",
		variantName = "Standard",
		groupId = Constants.GROUPS.THREE_ND,
		divisionName = "3rd Noob Division",
		accentColor = Color3.fromRGB(60, 100, 180),
		shirtId = 120652975851128,
		pantId = 140234621381267,
		settings = NOOBIC_SETTINGS,
	},
	{
		key = "5NSO",
		variantName = "Standard",
		groupId = Constants.GROUPS.FIVE_NSO,
		divisionName = "5NSO",
		accentColor = Color3.fromRGB(80, 140, 80),
		shirtId = 78446891053155,
		pantId = 89455153318532,
		settings = NOOBIC_SETTINGS,
	},
	{
		key = "CBRN_SF",
		variantName = "Special Forces",
		groupId = Constants.GROUPS.CBRN_SF,
		divisionName = "CBRN Special Forces",
		accentColor = Color3.fromRGB(0, 180, 120),
		variants = {
			{ key = "GAMMA", variantName = "Gamma", shirtId = 17633636990, pantId = 17633646229 },
			{ key = "ALPHA", variantName = "Alpha", shirtId = 17633630603, pantId = 17633646229 },
			{ key = "DELTA", variantName = "Delta", shirtId = 17633642176, pantId = 17633646229 },
			{ key = "ECHO", variantName = "Echo", shirtId = 17633633738, pantId = 17633646229 },
		},
	},
	{
		key = "CBRN_HAZMAT",
		variantName = "Hazmat",
		groupId = Constants.GROUPS.CBRN,
		divisionName = "CBRN",
		accentColor = Color3.fromRGB(180, 150, 0),
		shirtId = 5573200009,
		pantId = 5573220573,
	},
	{
		key = "RC",
		variantName = "Standard",
		groupId = Constants.GROUPS.RC,
		divisionName = "Republic Commandos",
		accentColor = Color3.fromRGB(200, 200, 200),
		shirtId = 136816870491337,
		pantId = 129513826683472,
	},
	{
		key = "GAR",
		variantName = "Standard",
		groupId = Constants.GROUPS.GAR,
		divisionName = "Grand Army of the Republic",
		accentColor = Color3.fromRGB(200, 180, 60),
		shirtId = 16332460580,
		pantId = 16332517831,
	},
	{
		key = "ASC",
		variantName = "Standard",
		groupId = Constants.GROUPS.ASC,
		divisionName = "Aeternus Security Corp.",
		accentColor = Color3.fromRGB(180, 60, 60),
		shirtId = 135222230991008,
		pantId = 84982285863342,
		settings = NOOBIC_SETTINGS,
	},
	{
		key = "ANRO",
		variantName = "Formals",
		groupId = Constants.GROUPS.ANRO,
		divisionName = "[ANRO] Advanced Noobic Reactor Operations",
		accentColor = Color3.fromRGB(100, 60, 180),
		shirtId = 116054452397403,
		pantId = 128737311684086,
		settings = NOOBIC_SETTINGS,
	},
	{
		key = "ANROSOC",
		variantName = "Combats",
		groupId = Constants.GROUPS.ANROSOC,
		divisionName = "ANRO Special Operations Command",
		accentColor = Color3.fromRGB(100, 60, 180),
		shirtId = 82288014084955,
		pantId = 140081219816908,
		settings = NOOBIC_SETTINGS,
	},
}

local uniformByKey: { [string]: UniformVariant } = {}
for _, uniform in ALL_UNIFORMS do
	uniformByKey[uniform.key] = uniform
end

local function getClothingIds(uniformKey: string, variantKey: string?): (number?, number?)
	local uniform = uniformByKey[uniformKey]
	if not uniform then
		return nil, nil
	end
	if uniform.variants and variantKey then
		for _, v in uniform.variants do
			if v.key == variantKey then
				return v.shirtId, v.pantId
			end
		end
		return nil, nil
	end
	return uniform.shirtId, uniform.pantId
end

return {
	All = ALL_UNIFORMS,
	byKey = uniformByKey,
	getClothingIds = getClothingIds,
}
