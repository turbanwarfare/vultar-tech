--!strict
--!native
--!optimize 2

export type ClassName = "Assault" | "Shocktrooper" | "Devastator" | "FlagBearer" | "Recon"

export type ClassWeapons = {
	Primary: string,
	Secondary: string?,
	Healing: string?,
}

export type ClassDefinition = {
	Name: ClassName,
	DisplayName: string,
	MaxSlots: number,
	DefenderWeapons: ClassWeapons,
	RaiderWeapons: ClassWeapons,
	Health: number?,
	IconId: number,
}

local ClassConfig = {}

ClassConfig.Classes = {
	Assault = {
		Name = "Assault",
		DisplayName = "ASSAULT",
		MaxSlots = -1,
		DefenderWeapons = { Primary = "H-82", Secondary = "H-12", Healing = "Medi+" },
		RaiderWeapons = { Primary = "BR-16", Secondary = "BR-8", Healing = "Medi+" },
		IconId = 0,

	},
	Shocktrooper = {
		Name = "Shocktrooper",
		DisplayName = "SHOCKTROOPER",
		MaxSlots = 2,
		DefenderWeapons = { Primary = "H-41", Secondary = "H-22", Healing = "Medi+" },
		RaiderWeapons = { Primary = "BR-40", Secondary = "BR-22", Healing = "Medi+" },
		IconId = 0,

	},
	Devastator = {
		Name = "Devastator",
		DisplayName = "DEVASTATOR",
		MaxSlots = 1,
		DefenderWeapons = { Primary = "H-94", Secondary = "H-12", Healing = "Medi+" },
		RaiderWeapons = { Primary = "BR-56", Secondary = "BR-8", Healing = "Medi+" },
		IconId = 0,

	},
	FlagBearer = {
		Name = "FlagBearer",
		DisplayName = "FLAG BEARER",
		MaxSlots = 1,
		DefenderWeapons = { Primary = "H-22" },
		RaiderWeapons = { Primary = "BR-22" },
		Health = 120,
		IconId = 0,

	},
	Recon = {
		Name = "Recon",
		DisplayName = "RECON",
		MaxSlots = 1,
		DefenderWeapons = { Primary = "H-50", Secondary = "H-12", Healing = "Medi+" },
		RaiderWeapons = { Primary = "BR-50", Secondary = "BR-8", Healing = "Medi+" },
		IconId = 0,

	},
} :: { [ClassName]: ClassDefinition }

local classByName: { [ClassName]: ClassDefinition } = table.clone(ClassConfig.Classes)

ClassConfig.ClassOrder = { "Assault", "Shocktrooper", "Devastator", "FlagBearer", "Recon" } :: { ClassName }

function ClassConfig.get(name: ClassName): ClassDefinition?
	return classByName[name]
end

function ClassConfig.isUnlimited(name: ClassName): boolean
	local def = classByName[name]
	return def ~= nil and def.MaxSlots == -1
end

function ClassConfig.getWeaponsForFaction(name: ClassName, faction: string): ClassWeapons?
	local def = classByName[name]
	if not def then
		return nil
	end
	return if faction == "Defenders" then def.DefenderWeapons else def.RaiderWeapons
end

return ClassConfig
