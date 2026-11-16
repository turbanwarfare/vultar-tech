--!strict

export type CardLabels = {
	title: TextLabel,
	loadout: TextLabel,
	players: TextLabel,
	slotCount: TextLabel,
}

export type ClassCard = {
	className: string,
	displayName: string,
	primary: string,
	secondary: string?,
	healing: string?,
	players: { string },
	current: number,
	max: number,
	isUnlimited: boolean,
	isFull: boolean,
	isYourClass: boolean,
}

export type PanelLabels = {
	title: TextLabel,
	health: TextLabel,
	gunName: TextLabel,
	mode: TextLabel,
	damage: TextLabel,
	fireRate: TextLabel,
	range: TextLabel,
	accuracy: TextLabel,
	magazine: TextLabel,
	secondaryName: TextLabel,
	secondaryDetail: TextLabel,
	healingName: TextLabel,
	healingDetail: TextLabel,
}

export type Weapon = {
	name: string,
	mode: string,
	damage: number,
	headDamage: number,
	roundsPerSecond: number,
	range: number,
	spread: number,
	accuracy: number,
	magazine: number,
	healPerSecond: number,
}

export type ClassDetails = {
	className: string,
	displayName: string,
	health: number,
	primary: Weapon,
	secondary: Weapon?,
	healing: Weapon?,
}

local LoadoutFill = {}

local function round(value: number): number
	return math.round(value)
end

local function accuracyWord(accuracy: number): string
	if accuracy >= 0.8 then
		return "HIGH"
	elseif accuracy >= 0.5 then
		return "MEDIUM"
	end
	return "LOW"
end

local function damageText(weapon: Weapon): string
	return round(weapon.damage) .. " / " .. round(weapon.headDamage) .. " HEAD"
end

local function escapeRichText(text: string): string
	return (string.gsub(text, "[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }))
end

function LoadoutFill.faction(label: TextLabel, faction: string): ()
	label.Text = if faction == "Defenders" then "DEFENDERS" else "HOSTILES"
end

function LoadoutFill.classCard(labels: CardLabels, card: ClassCard): ()
	labels.title.Text = card.displayName

	if card.className == "FlagBearer" then
		labels.loadout.Text = string.upper(card.primary) .. " · SHIELD · HEAL"
	else
		local weapons = { string.upper(card.primary) }
		if card.secondary then
			table.insert(weapons, string.upper(card.secondary))
		end
		if card.healing then
			table.insert(weapons, string.upper(card.healing))
		end
		labels.loadout.Text = table.concat(weapons, " · ")
	end

	if #card.players == 0 then
		labels.players.Text = "OPEN"
	elseif card.isUnlimited then
		labels.players.Text = #card.players .. (if #card.players == 1 then " PLAYER" else " PLAYERS")
	else
		labels.players.Text = table.concat(card.players, ", ")
	end

	labels.slotCount.Text = if card.isUnlimited then card.current .. "/∞" else card.current .. "/" .. card.max
end

function LoadoutFill.classDetails(labels: PanelLabels, details: ClassDetails): ()
	local primary = details.primary

	labels.title.Text = details.displayName
	labels.health.Text = round(details.health) .. " HP"
	labels.gunName.Text = primary.name
	labels.mode.Text = string.upper(primary.mode)
	labels.damage.Text = damageText(primary)
	labels.fireRate.Text = round(primary.roundsPerSecond) .. " RND/S"
	labels.range.Text = round(primary.range) .. " STUDS"
	labels.accuracy.Text = accuracyWord(primary.accuracy)
	labels.magazine.Text = round(primary.magazine) .. " RND"

	local secondary = details.secondary
	if secondary then
		labels.secondaryName.Text = secondary.name
		labels.secondaryDetail.Text = damageText(secondary) .. " · " .. string.upper(secondary.mode)
	end

	local healing = details.healing
	if healing then
		labels.healingName.Text = string.upper(healing.name)
		labels.healingDetail.Text = round(healing.healPerSecond) .. " HP/S · " .. round(healing.range) .. " STUDS"
	end
end

function LoadoutFill.deployError(hint: TextLabel, message: string): ()
	hint.Text = '<font color="#ff6467">' .. escapeRichText(string.upper(message)) .. "</font>"
end

return LoadoutFill
