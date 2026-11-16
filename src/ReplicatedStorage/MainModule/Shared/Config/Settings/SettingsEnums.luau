--!strict
--!native
--!optimize 2

local SettingsEnums = {}

local function createEnum<T>(values: { string }): T & { [number]: string }
	local enum: { [string | number]: string | number } = {}
	for i, name in values do
		enum[name] = i
		enum[i] = name
	end
	return enum :: any
end

SettingsEnums.Time = createEnum({
	"Day",
	"Night",
})

SettingsEnums.CursorStyle = createEnum({
	"SMG",
	"RCl",
	"Cross",
})

SettingsEnums.Color = createEnum({
	"White",
	"Yellow",
	"Red",
	"Green",
	"Orange",
	"Blue",
})

SettingsEnums.HitmarkerRotation = createEnum({
	"Left",
	"Right",
	"Static",
	"Random",
})

SettingsEnums.HitmarkerSpeed = createEnum({
	"Slow",
	"Normal",
	"Fast",
})

SettingsEnums.KillFeedPosition = createEnum({
	"Left",
	"Middle",
	"Right",
})

SettingsEnums.Holsters = createEnum({
	"All",
	"Self",
	"None",
})

SettingsEnums.TeamESPOverhead = createEnum({
	"Condensed",
	"Detailed",
})

SettingsEnums.TeamESPBehaviour = createEnum({
	"Both",
	"Overhead GUI",
	"Character",
})

SettingsEnums.OOCIndicatorPosition = createEnum({
	"TeamESP",
	"Torso",
})

SettingsEnums.NotificationPosition = createEnum({
	"Bottom",
	"Top",
})

SettingsEnums.DamageIndicatorType = createEnum({
	"Expand",
	"Stack",
})

SettingsEnums.StickTo = createEnum({
	"Player",
	"Cursor",
	"Static",
})

SettingsEnums.HealIndicatorType = createEnum({
	"Expand",
	"Stack",
})

SettingsEnums.KillIndicatorType = createEnum({
	"Circle",
	"Hitmarker",
	"Skull",
})

SettingsEnums.RayType = createEnum({
	"Part",
	"Beam",
})

SettingsEnums.RayMaterial = createEnum({
	"Neon",
	"Plastic",
})

SettingsEnums.RaySpeed = createEnum({
	"Slow",
	"Default",
	"Fast",
})

SettingsEnums.PreviewPosition = createEnum({
	"Bottom",
	"Right",
})

SettingsEnums.HurtScreenType = createEnum({
	"Screen",
	"Border",
})

SettingsEnums.ShiftLockMode = createEnum({
	"Locked",
	"Free",
})

SettingsEnums.LeaderboardSize = createEnum({
	"Default",
	"Small",
})

SettingsEnums.LeaderboardType = createEnum({
	"Center",
	"Side",
})

return SettingsEnums
