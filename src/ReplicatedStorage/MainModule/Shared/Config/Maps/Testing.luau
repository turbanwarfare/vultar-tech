--!strict
--!native
--!optimize 2

return {
	DT = {
		GameType = "DT",
		DefaultPoints = 0,
		Hardpoint = true,
		Domination = false,
		ClassSystem = true,
		RespawnTime = 5,
		Teams = {
			{
				Name = "Vultarians",
				DisplayName = "Vultarians",
				Faction = "Defenders",
				Color = BrickColor.new("Maroon"),
				AutoAssignable = false,
				Selectable = true,
				Order = 1,
			},
			{
				Name = "Initiates",
				DisplayName = "Initiates",
				Faction = "Defenders",
				Color = BrickColor.new("Bright red"),
				AutoAssignable = false,
				Selectable = false,
				Order = 2,
			},
			{
				Name = "Hostiles",
				DisplayName = "Hostiles",
				Faction = "Raiders",
				Color = BrickColor.new("Bright blue"),
				AutoAssignable = false,
				Selectable = true,
				Order = 3,
			},
			{
				Name = "Spectators",
				DisplayName = "Spectators",
				Faction = "Neutral",
				Color = BrickColor.new("Medium stone grey"),
				AutoAssignable = false,
				Selectable = true,
				Order = 4,
			},
			{
				Name = "Green",
				DisplayName = "Green",
				Faction = "Defenders",
				Color = BrickColor.new("Bright green"),
				AutoAssignable = false,
				Selectable = true,
				Order = 5,
			},
			{
				Name = "Yellow",
				DisplayName = "Yellow",
				Faction = "Raiders",
				Color = BrickColor.new("Bright yellow"),
				AutoAssignable = false,
				Selectable = true,
				Order = 6,
			},
		},
	},

	Raid = {
		GameType = "Raid",
		DefaultPoints = 0,
		Hardpoint = true,
		ClassSystem = true,
		RespawnTime = 5,
	},
	FeatureFlags = {
		ClassSystem = true,
		Nades = true,
		Roll = true,
	},
}
