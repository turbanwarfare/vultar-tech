--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")

local SKIP_REQUIREMENTS_IN_STUDIO = true
local skipRequirements = SKIP_REQUIREMENTS_IN_STUDIO and RunService:IsStudio()

export type CreditProduct = {
	ProductId: number,
	Credits: number,
	DisplayName: string,
}

export type PlayerMatchStats = {
	Kills: number,
	Damage: number,
	Heals: number,
	Captures: number,
}

local CREDIT_TIERS: { { Credits: number, DisplayName: string } } = {
	{ Credits = 100, DisplayName = "100 Credits" }, -- 100 robux
	{ Credits = 200, DisplayName = "200 Credits" }, -- 200 robux
	{ Credits = 500, DisplayName = "500 Credits" }, -- 475 robux
	{ Credits = 800, DisplayName = "800 Credits" }, -- 760 robux
	{ Credits = 1000, DisplayName = "1,000 Credits" }, -- 950 robux
	{ Credits = 1500, DisplayName = "1,500 Credits" }, -- 1,425 robux
	{ Credits = 5000, DisplayName = "5,000 Credits" }, -- 4,750 robux
	{ Credits = 10000, DisplayName = "10,000 Credits" }, -- 9,500 robux
}

local function creditPacks(productIds: { [number]: number }): { CreditProduct }
	local packs: { CreditProduct } = {}
	for _, tier in CREDIT_TIERS do
		local productId = productIds[tier.Credits]
		if productId then
			table.insert(packs, {
				ProductId = productId,
				Credits = tier.Credits,
				DisplayName = tier.DisplayName,
			})
		end
	end
	return packs
end

local CREDIT_PRODUCTS_BY_UNIVERSE: { [number]: { CreditProduct } } = {
	[9372097944] = creditPacks({ -- no new IDs yet
		[100] = 3712718418,
		[200] = 3723106429,
		[500] = 3712718470,
		[800] = 3723106461,
		[1000] = 3712718492,
		[1500] = 3723106495,
		[5000] = 3723106522,
		[10000] = 3712718529,
	}),
	[8136878028] = creditPacks({ -- Mataro
		[100] = 3722565086,
		[200] = 3723065681,
		[500] = 3722565138,
		[800] = 3723067273,
		[1000] = 3722565172,
		[1500] = 3723067460,
		[5000] = 3723067748,
		[10000] = 3722565235,
	}),
	[7785392259] = creditPacks({ -- Onyx
		[100] = 3722565665,
		[200] = 3723067988,
		[500] = 3722565718,
		[800] = 3723068044,
		[1000] = 3722565782,
		[1500] = 3723068094,
		[5000] = 3723068182,
		[10000] = 3722565839,
	}),
	[8796119295] = creditPacks({ -- Overwatch
		[100] = 3722566114,
		[200] = 3723068387,
		[500] = 3722566156,
		[800] = 3723068429,
		[1000] = 3722566198,
		[1500] = 3723068474,
		[5000] = 3723068523,
		[10000] = 3722566240,
	}),
	[7785447625] = creditPacks({ -- Surrex
		[100] = 3722566543,
		[200] = 3723069010,
		[500] = 3722566591,
		[800] = 3723069056,
		[1000] = 3722566647,
		[1500] = 3723069105,
		[5000] = 3723069167,
		[10000] = 3722566695,
	}),
	[9570321297] = creditPacks({ -- Nova
		[100] = 3722952471,
		[200] = 3723068611,
		[500] = 3722952508,
		[800] = 3723068652,
		[1000] = 3722952545,
		[1500] = 3723068716,
		[5000] = 3723068776,
		[10000] = 3722952576,
	}),
}

local CREDIT_PRODUCTS: { CreditProduct } = CREDIT_PRODUCTS_BY_UNIVERSE[game.GameId] or {}

local CREDIT_PRODUCTS_BY_ID: { [number]: CreditProduct } = {}
for _, prod in CREDIT_PRODUCTS do
	CREDIT_PRODUCTS_BY_ID[prod.ProductId] = prod
end

local WEIGHTS = {
	DAMAGE_WEIGHT = 0.1,
	HEALS_WEIGHT = 0.1,
	KILL_BONUS = 10,
	CAPTURE_BONUS = 25,
	MIN_WEIGHTED_SCORE = 200,
	FULL_WEIGHTED_SCORE = 700,
}

local REWARD_RULES = {
	LOSS_SHARE = 0.3,
	MIN_ATTENDANCE = 0.4,
	MIN_PERFORMANCE_SHARE = 0.5,
}

local MAP_REWARDS: { [string]: number } = {
	["Onyx"] = 180,
	["Surrex"] = 220,
	["Nova"] = 140,
	["Mataro"] = 300,
	["Overwatch"] = 220,
	["Pitgrounds"] = 180,
	["Silo"] = 90,
	["Testing"] = 100,
	["Ironworks"] = 180,
	["SparringArena"] = 0,
	["AimChamber"] = 0,
}

local DEFAULT_MAP_REWARD = 200

local function getCreditProduct(productId: number): CreditProduct?
	return CREDIT_PRODUCTS_BY_ID[productId]
end

local function getMapReward(mapName: string?): number
	if not mapName then
		return DEFAULT_MAP_REWARD
	end
	local reward = MAP_REWARDS[mapName]
	if reward ~= nil then
		return reward
	end
	return DEFAULT_MAP_REWARD
end

local function calculateParticipationScore(stats: PlayerMatchStats?): number
	if not stats then
		return 0
	end
	return (stats.Damage * WEIGHTS.DAMAGE_WEIGHT)
		+ (stats.Heals * WEIGHTS.HEALS_WEIGHT)
		+ (stats.Kills * WEIGHTS.KILL_BONUS)
		+ (stats.Captures * WEIGHTS.CAPTURE_BONUS)
end

local function calculateMatchReward(mapName: string?, isWinner: boolean, attendance: number, score: number): number
	if not skipRequirements and (attendance < REWARD_RULES.MIN_ATTENDANCE or score < WEIGHTS.MIN_WEIGHTED_SCORE) then
		return 0
	end
	local progress = (score - WEIGHTS.MIN_WEIGHTED_SCORE) / (WEIGHTS.FULL_WEIGHTED_SCORE - WEIGHTS.MIN_WEIGHTED_SCORE)
	local performance = REWARD_RULES.MIN_PERFORMANCE_SHARE + (1 - REWARD_RULES.MIN_PERFORMANCE_SHARE) * math.clamp(progress, 0, 1)
	local base = getMapReward(mapName) * (if isWinner then 1 else REWARD_RULES.LOSS_SHARE)
	return math.floor(base * math.min(attendance, 1) * performance + 1e-6)
end

local function isEligibleForReward(playerStats: PlayerMatchStats?, matchContributionScore: number?): boolean
	if skipRequirements then
		return true
	end
	if (matchContributionScore or 0) >= WEIGHTS.MIN_WEIGHTED_SCORE then
		return true
	end
	return calculateParticipationScore(playerStats) >= WEIGHTS.MIN_WEIGHTED_SCORE
end

return table.freeze({
	CREDIT_ICON = "rbxassetid://0",
	CREDIT_PRODUCTS = table.freeze(CREDIT_PRODUCTS),
	CREDIT_PRODUCTS_BY_ID = table.freeze(CREDIT_PRODUCTS_BY_ID),
	WEIGHTS = table.freeze(WEIGHTS),
	REWARD_RULES = table.freeze(REWARD_RULES),
	MAP_REWARDS = table.freeze(MAP_REWARDS),
	DEFAULT_MAP_REWARD = DEFAULT_MAP_REWARD,
	getCreditProduct = getCreditProduct,
	getMapReward = getMapReward,
	calculateParticipationScore = calculateParticipationScore,
	calculateMatchReward = calculateMatchReward,
	isEligibleForReward = isEligibleForReward,
})
