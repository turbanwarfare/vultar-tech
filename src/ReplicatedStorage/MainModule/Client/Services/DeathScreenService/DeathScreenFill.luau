--!strict

export type Killer = {
	userId: number,
	name: string,
	avatarImage: string,
	teamName: string,
	faction: string,
	teamColor: Color3,
	gunName: string,
	gunImage: string,
	range: number,
	health: number,
}

export type RowLabels = {
	gunName: TextLabel,
	gunImage: ImageLabel,
	damage: TextLabel,
	playerName: TextLabel,
	bodyPart: TextLabel?,
}

export type Hit = {
	gunName: string,
	gunImage: string,
	damage: number,
	playerName: string,
	bodyPart: string,
	headshot: boolean,
}

export type ReportLabels = {
	receivedSummary: TextLabel,
	totalTaken: TextLabel,
	dealtSummary: TextLabel,
	accuracy: TextLabel,
	matchAccuracy: TextLabel,
}

export type ReportTotals = {
	hitsTaken: number,
	damageTaken: number,
	hitsDealt: number,
	damageDealt: number,
	accuracy: number?,
	matchAccuracy: number?,
}

export type KillerLabels = {
	avatar: ImageLabel,
	killerName: TextLabel,
	teamIcon: ImageLabel,
	team: TextLabel,
	gunImage: ImageLabel,
	gun: TextLabel,
	studs: TextLabel,
	hp: TextLabel,
}

export type CardLabels = {
	box: GuiObject,
	static: ImageLabel,
}

local DeathScreenFill = {}

local function round(value: number): number
	return math.round(value)
end

local function percentText(label: string, fraction: number?): string
	if not fraction then
		return label .. ": --"
	end
	return label .. ": " .. string.format("%.1f%%", fraction * 100)
end

function DeathScreenFill.killer(labels: KillerLabels, killer: Killer): ()
	labels.avatar.Image = killer.avatarImage
	labels.killerName.Text = string.upper(killer.name)

	local isDefender = killer.faction == "Defenders"
	local factionColor = if isDefender then Color3.fromRGB(220, 70, 70) else Color3.fromRGB(80, 140, 220)
	labels.teamIcon.Image = if isDefender then "rbxassetid://98751546690059" else "rbxassetid://0"
	labels.team.TextColor3 = factionColor

	local avatarStroke = labels.avatar:FindFirstChildOfClass("UIStroke")
	if avatarStroke then
		avatarStroke.Color = factionColor
	end

	labels.team.Text = string.upper(killer.teamName)
	labels.gunImage.Image = killer.gunImage
	labels.gunImage.Visible = killer.gunImage ~= ""
	labels.gun.Text = killer.gunName
	labels.studs.Text = math.floor(killer.range) .. " STUDS"
	labels.hp.Text = math.floor(killer.health) .. " HP"
end

function DeathScreenFill.card(labels: CardLabels, image: string?, animated: boolean): ()
	local source = image or ""
	local hasCard = source ~= "" and not animated
	labels.box.Visible = hasCard
	labels.static.Image = if hasCard then source else ""
	labels.static.Visible = hasCard
end

function DeathScreenFill.respawnTimer(timeLabel: TextLabel, secondsLeft: number): ()
	timeLabel.Text = string.format("%.1fS", secondsLeft)
end

function DeathScreenFill.receivedRow(labels: RowLabels, hit: Hit): ()
	labels.gunName.Text = hit.gunName
	labels.gunImage.Image = hit.gunImage
	labels.damage.Text = tostring(round(hit.damage))
	labels.playerName.Text = hit.playerName
end

function DeathScreenFill.dealtRow(labels: RowLabels, hit: Hit): ()
	labels.gunName.Text = hit.gunName
	labels.gunImage.Image = hit.gunImage
	labels.damage.Text = tostring(round(hit.damage))
	labels.playerName.Text = hit.playerName
	if labels.bodyPart then
		labels.bodyPart.Text = string.upper(hit.bodyPart)
	end
end

function DeathScreenFill.reportTotals(labels: ReportLabels, totals: ReportTotals): ()
	labels.receivedSummary.Text = totals.hitsTaken .. " HITS · " .. round(totals.damageTaken) .. " DMG"
	labels.totalTaken.Text = tostring(round(totals.damageTaken))
	labels.dealtSummary.Text = totals.hitsDealt .. " HITS · " .. round(totals.damageDealt) .. " DMG"
	labels.accuracy.Text = percentText("ACCURACY", totals.accuracy)
	labels.matchAccuracy.Text = percentText("MATCH ACCURACY", totals.matchAccuracy)
end

return DeathScreenFill
