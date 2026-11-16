--!strict
--!native
--!optimize 2

export type TeamMember = {
	category: string,
	name: string,
	userId: number,
	extra: string,
	role: string,
}

export type Quote = {
	text: string,
	author: string,
}

export type Base = {
	name: string,
	version: string,
	gameId: number,
	loadingScreenId: string,
}

local rng = Random.new()

local Credits = {}

local DEFAULT_LOADING_SCREEN = "rbxassetid://138500941928925"

Credits.Bases = {
	{ name = "NOVA STATION", version = "DT", gameId = 118987827318205, loadingScreenId = "rbxassetid://132823017094075" },
	{ name = "ONYX CITADEL", version = "DT", gameId = 70983359460672, loadingScreenId = "rbxassetid://92173860852804" },
	{ name = "ONYX CITADEL", version = "DT", gameId = 115507985303109, loadingScreenId = "rbxassetid://92173860852804" },
	{ name = "ONYX CITADEL", version = "Raid", gameId = 94785875266022, loadingScreenId = "rbxassetid://92173860852804" },
	{ name = "SURREX ASSEMBLY", version = "DT", gameId = 106608091105526, loadingScreenId = "rbxassetid://71387099687698" },
	{ name = "SURREX ASSEMBLY", version = "Raid", gameId = 116265973320871, loadingScreenId = "rbxassetid://71387099687698" },
	{ name = "MATARO FORTRESS DISTRICT", version = "DT", gameId = 82023579765520, loadingScreenId = "rbxassetid://138500941928925" },
	{ name = "MATARO FORTRESS DISTRICT", version = "RAID", gameId = 90561638777409, loadingScreenId = "rbxassetid://138500941928925" },
	{ name = "OVERWATCH", version = "DT", gameId = 117954931852402, loadingScreenId = "rbxassetid://138500941928925" },
	{ name = "OVERWATCH", version = "RAID", gameId = 72495616647342, loadingScreenId = "rbxassetid://138500941928925" },
	{ name = "IRONWORKS", version = "RAID", gameId = 103242562426271, loadingScreenId = "rbxassetid://138500941928925" },
	{ name = "TESTING PLACE", version = "None", gameId = 134407518396463, loadingScreenId = "rbxassetid://138500941928925" },
} :: { Base }

Credits.Team = {
	{ category = "Director", name = "Director", userId = 1, extra = "", role = "Director" },
	{ category = "Scripting", name = "Developer", userId = 1, extra = "", role = "Programmer" },
} :: { TeamMember }

Credits.Quotes = {
	{ text = "Replace with your own quotes.", author = "Developer" },
} :: { Quote }

function Credits.getDirector(): TeamMember?
	for _, member in Credits.Team do
		if member.category == "Director" then
			return member
		end
	end
	return nil
end

function Credits.getTeamMembers(): { TeamMember }
	local members = {}
	for _, member in Credits.Team do
		if member.category ~= "Director" then
			table.insert(members, member)
		end
	end
	return members
end

function Credits.getRandomQuote(): Quote
	return Credits.Quotes[rng:NextInteger(1, #Credits.Quotes)]
end

function Credits.getLoadingScreenImage(): string
	local placeId = game.PlaceId
	for _, base in Credits.Bases do
		if base.gameId == placeId then
			return base.loadingScreenId
		end
	end
	return DEFAULT_LOADING_SCREEN
end

function Credits.getBaseName(): string?
	local placeId = game.PlaceId
	for _, base in Credits.Bases do
		if base.gameId == placeId then
			return base.name
		end
	end
	return nil
end

return Credits
