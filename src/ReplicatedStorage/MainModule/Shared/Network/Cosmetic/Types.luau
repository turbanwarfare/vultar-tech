--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local CosmeticConfig = require(MainModule.Shared.Config.Cosmetics)

export type Category = CosmeticConfig.Category

export type OwnedCosmetics = {
	[Category]: { string },
}

export type EquippedCosmetics = {
	PlayerCard: string?,
	GunSkin: string?,
	GunSkins: { [string]: string }?,
	ChatGradient: string?,
}

export type CosmeticState = {
	owned: OwnedCosmetics,
	equipped: EquippedCosmetics,
}

return nil
