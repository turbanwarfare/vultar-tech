--!strict
--!native
--!optimize 2

export type Category = "PlayerCard" | "GunSkin" | "ChatGradient"

export type GradientConfig = {
	colors: { Color3 },
	rotation: number?,
}

export type CollectionConfig = {
	name: string,
	imageId: string,
	season: string?,
	isNew: boolean?,
	textColor: Color3?,
	purchaseGradient: GradientConfig?,
	visible: boolean?,
}

export type ItemConfig = {
	id: string,
	collection: string?,
	category: Category,
	gamepassIds: { number },
	purchaseGamepassId: number,
	name: string?,
	imageId: string?,
	season: string?,
	isNew: boolean?,
	isAnimated: boolean?,
	textColor: Color3?,
	visible: boolean?,
	customCheck: ((player: Player) -> boolean)?,
	gradientColors: { Color3 }?,
	gradientSpeed: number?,
}

export type ResolvedCosmetic = {
	id: string,
	name: string,
	category: Category,
	gamepassIds: { number },
	purchaseGamepassId: number,
	imageId: string,
	season: string?,
	isNew: boolean,
	isAnimated: boolean,
	textColor: Color3,
	visible: boolean,
	purchaseGradient: GradientConfig?,
	customCheck: ((player: Player) -> boolean)?,
	gradientColors: { Color3 }?,
	gradientSpeed: number?,
}

export type OwnedCosmetics = {
	[Category]: { string },
}

return nil
