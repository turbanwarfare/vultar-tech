--!strict
--!native
--!optimize 2

export type GunProperties = {
	Mode: string,
	GunImageId: number,
	FireRate: number,
	MaxAmmo: number,
	Range: number,
	RechargePerSecond: number,
	Spread: number?,
	SpreadPerfectRange: number?,
	SpreadStartRange: number?,
	BaseDamage: number?,
	HeadDamage: number?,
	HealAmount: number?,
	Pellets: number?,
	Chargeable: boolean?,
	ChargeTime: number?,
	MaxChargeMultiplier: number?,
	CanZoom: boolean?,
	InfiniteAmmo: boolean?,
	SourceTool: string?,
	SkinReferenceGun: string?,
	Animations: {
		Fire: number?,
		Sprint: number?,
		Idle: number?,
	},
	Sounds: {
		Fire: number?,
	}?,
	HolsterPart: string?,
	HolsterOffset: CFrame?,
}

local GunStats = {}

GunStats.Guns = {}
GunStats.Guns["H-82"] = require(script["H-82"])
GunStats.Guns["H-82 INF"] = require(script["H-82 INF"])
GunStats.Guns["H-22"] = require(script["H-22"])
GunStats.Guns["H-12"] = require(script["H-12"])
GunStats.Guns["H-41"] = require(script["H-41"])
GunStats.Guns["H-94"] = require(script["H-94"])
GunStats.Guns["H-94-DEV"] = require(script["H-94-DEV"])
GunStats.Guns["H-50"] = require(script["H-50"])
GunStats.Guns["BR-16"] = require(script["BR-16"])
GunStats.Guns["BR-22"] = require(script["BR-22"])
GunStats.Guns["BR-8"] = require(script["BR-8"])
GunStats.Guns["BR-40"] = require(script["BR-40"])
GunStats.Guns["BR-56"] = require(script["BR-56"])
GunStats.Guns["BR-50"] = require(script["BR-50"])
GunStats.Guns["Medi+"] = require(script["Medi+"])
GunStats.Guns["GPR"] = require(script["GPR"])


for _, statsTable in GunStats.Guns do
	if typeof(statsTable) == "table" then
		if typeof(statsTable.Animations) == "table" then
			table.freeze(statsTable.Animations)
		end
		if typeof(statsTable.Sounds) == "table" then
			table.freeze(statsTable.Sounds)
		end
		table.freeze(statsTable)
	end
end
table.freeze(GunStats.Guns)

function GunStats.get(gunName: string): GunProperties?
	if not GunStats.Guns then
		warn("GunStats.Guns is nil when get() called with:", gunName)
		return nil
	end
	return GunStats.Guns[gunName]
end

function GunStats.hasCustomAnimations(gunName: string): boolean
	local stats = GunStats.Guns[gunName]
	return stats ~= nil and stats.Animations ~= nil
end

GunStats.GUN_INDEX_TO_NAME = {
	[1] = "H-82",
	[2] = "BR-16",
	[3] = "Medi+",
	[4] = "H-22",
	[5] = "BR-56",
	[6] = "BR-22",
	[7] = "H-94",
	[8] = "H-41",
	[9] = "BR-40",
	[10] = "H-12",
	[11] = "H-50",
	[12] = "BR-50",
	[13] = "BR-8",
	[14] = "Sword",

	[15] = "H-94-DEV",
	[16] = "GPR",
	[17] = "Grenade",
}
table.freeze(GunStats.GUN_INDEX_TO_NAME)

GunStats.GUN_NAME_TO_INDEX = {} :: { [string]: number }
for index, name in GunStats.GUN_INDEX_TO_NAME do
	GunStats.GUN_NAME_TO_INDEX[name] = index
end
table.freeze(GunStats.GUN_NAME_TO_INDEX)

return table.freeze(GunStats)
