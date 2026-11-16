--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local SharedTypes = require(MainModule.Shared.Types)

export type TeamConfig = {
	Name: string,
	DisplayName: string?,
	Faction: Faction,
	Color: BrickColor,
	AutoAssignable: boolean?,
	Selectable: boolean?,
	Order: number?,
}

export type Faction = SharedTypes.Faction

export type GameMode = "DT" | "RAID" | "DEFAULT"

return nil
