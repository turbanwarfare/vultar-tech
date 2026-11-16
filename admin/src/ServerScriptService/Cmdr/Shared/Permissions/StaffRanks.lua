local StaffRanks = {}

StaffRanks.Attribute = "StaffRank"

StaffRanks.Levels = {
	Mod = 1,
	Admin = 2,
	["Admin+"] = 3,
	Developer = 4,
}

StaffRanks.Names = { "Mod", "Admin", "Admin+", "Developer" }

StaffRanks.GroupLevels = {
	Mod = 1,
	Admin = 2,
	["Admin+"] = 3,
	Developer = 4,
	Help = 1,
	DefaultUtil = 1,
	DefaultAdmin = 1,
	DefaultDebug = 1,
}

function StaffRanks.GetLevel(player: Player): number
	return player:GetAttribute(StaffRanks.Attribute) or 0
end

function StaffRanks.GetName(level: number): string
	return StaffRanks.Names[level] or "Player"
end

function StaffRanks.GetRequiredLevel(group: string?): number
	return group and StaffRanks.GroupLevels[group] or StaffRanks.Levels.Developer
end

return StaffRanks
