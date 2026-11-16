--!strict
--!native
--!optimize 2

export type StoreHubKey = "StoreHub1" | "StoreHub2" | "StoreHub3"

export type StoreHubConfig = {
	key: StoreHubKey,
	displayName: string,
	placeId: number,
}

local StoreHubRedirects = {}

StoreHubRedirects.Hubs = {
	StoreHub1 = {
		key = "StoreHub1",
		displayName = "Vultarian Military Reserve Store Hub 1",
		placeId = 80704215497255,
	},
	StoreHub2 = {
		key = "StoreHub2",
		displayName = "Vultarian Military Reserve Store Hub 2",
		placeId = 87705431196007,
	},
	StoreHub3 = {
		key = "StoreHub3",
		displayName = "Vultarian Military Reserve Store Hub 3",
		placeId = 114787625554598,
	},
} :: { [StoreHubKey]: StoreHubConfig }

StoreHubRedirects.GamepassToHub = {
	-- Store Hub 1
	[1247672226] = "StoreHub1", -- Samurai Skin
	[1246942473] = "StoreHub1", -- Night Skin
	[1247160252] = "StoreHub1", -- EVA Skin
	[1244564660] = "StoreHub1", -- Glitch Skin
	[1244153905] = "StoreHub1", -- Tech Skin
	[1244086092] = "StoreHub1", -- Fantastique Skin
	[1244730528] = "StoreHub1", -- Green Skin
	[1247610102] = "StoreHub1", -- Moo Skin
	[1359198522] = "StoreHub1", -- Leaderboard Card [BEAMER]
	[1361198404] = "StoreHub1", -- Kill Card [BEAMER]
	[1361162389] = "StoreHub1", -- Chat Card [BEAMER]
	[1238504393] = "StoreHub1", -- Leaderboard Card [SPACE]
	[1238846277] = "StoreHub1", -- Kill Card [SPACE]
	[1236922347] = "StoreHub1", -- Chat Card [SPACE]
	[1236660263] = "StoreHub1", -- Leaderboard Card [VULTAR]
	[1236043264] = "StoreHub1", -- Kill Card [VULTAR]
	[1239632641] = "StoreHub1", -- Chat Card [VULTAR]
	[1235779773] = "StoreHub1", -- Leaderboard Card [NIGHT]
	[1236922343] = "StoreHub1", -- Kill Card [NIGHT]
	[1235891575] = "StoreHub1", -- Chat Card [NIGHT]
	[1239032133] = "StoreHub1", -- Leaderboard Card [BEAUTIFUL DEATH]
	[1236103064] = "StoreHub1", -- Kill Card [BEAUTIFUL DEATH]
	[1236732340] = "StoreHub1", -- Chat Card [BEAUTIFUL DEATH]
	[1236660259] = "StoreHub1", -- Leaderboard Card [BERSERK]
	[1239748541] = "StoreHub1", -- Kill Card [BERSERK]
	[1238918187] = "StoreHub1", -- Chat Card [BERSERK]
	[1237362014] = "StoreHub1", -- Leaderboard Card [MEOW]
	[1236095052] = "StoreHub1", -- Kill Card [MEOW]
	[1236630487] = "StoreHub1", -- Chat Card [MEOW]
	[1235811744] = "StoreHub1", -- Leaderboard Card [DUTY]
	[1236380555] = "StoreHub1", -- Kill Card [DUTY]
	[1236192933] = "StoreHub1", -- Chat Card [DUTY]
	[1239838537] = "StoreHub1", -- Leaderboard Card [GT3-R3]
	[1235869437] = "StoreHub1", -- Kill Card [GT3-R3]
	[1236077132] = "StoreHub1", -- Chat Card [GT3-R3]
	[1235909491] = "StoreHub1", -- Leaderboard Card [I SEE YOU]
	[1237690018] = "StoreHub1", -- Kill Card [I SEE YOU]
	[1237008139] = "StoreHub1", -- Chat Card [I SEE YOU]
	[1240036356] = "StoreHub1", -- Leaderboard Card [DEAD]
	[1236029291] = "StoreHub1", -- Kill Card [DEAD]
	[1235887458] = "StoreHub1", -- Chat Card [DEAD]
	[1235921441] = "StoreHub1", -- Leaderboard Card [LIT]
	[1236478410] = "StoreHub1", -- Kill Card [LIT]
	[1235779763] = "StoreHub1", -- Chat Card [LIT]
	[1235813570] = "StoreHub1", -- Leaderboard Card [APOC]
	[1236540304] = "StoreHub1", -- Kill Card [APOC]
	[1236236632] = "StoreHub1", -- Chat Card [APOC]
	[1235879483] = "StoreHub1", -- Leaderboard Card [CLOUD]
	[1236009220] = "StoreHub1", -- Kill Card [CLOUD]
	[1237573861] = "StoreHub1", -- Chat Card [CLOUD]

	-- Store Hub 2
	[1360700510] = "StoreHub2", -- MAGMA Skin
	[1359826580] = "StoreHub2", -- CLONES Skin
	[1367788971] = "StoreHub2", -- Leaderboard Card [ARC]
	[1367290989] = "StoreHub2", -- Kill Card [ARC]
	[1365959080] = "StoreHub2", -- Chat Card [ARC]
	[1359446565] = "StoreHub2", -- Leaderboard Card [VETTE]
	[1361516445] = "StoreHub2", -- Chat Card [VETTE]
	[1360892492] = "StoreHub2", -- Kill Card [VETTE]
	[1359564578] = "StoreHub2", -- Leaderboard Card [PUNISHER]
	[1358986594] = "StoreHub2", -- Chat Card [PUNISHER]
	[1359612586] = "StoreHub2", -- Kill Card [PUNISHER]
	[1359784609] = "StoreHub2", -- DIGI Skin
	[1359362616] = "StoreHub2", -- PUNISHED skin
	[1359594567] = "StoreHub2", -- BEAST Skin
	[1361186436] = "StoreHub2", -- Leaderboard Card [KOENIG]
	[1361390421] = "StoreHub2", -- Kill Card [KOENIG]
	[1360778436] = "StoreHub2", -- Chat Card [KOENIG]
	[1360084480] = "StoreHub2", -- Leaderboard Card [BYTE]
	[1359028546] = "StoreHub2", -- Kill Card [BYTE]
	[1360364507] = "StoreHub2", -- Chat Card [BYTE]
	[1360952442] = "StoreHub2", -- Leaderboard Card [PUNISHED]
	[1359900515] = "StoreHub2", -- Chat Card [PUNISHED]
	[1361024452] = "StoreHub2", -- Kill Card [PUNISHED]
	[1360202535] = "StoreHub2", -- COMMANDO skin
	[1360670451] = "StoreHub2", -- Leaderboard Card [COMMANDO]
	[1359742508] = "StoreHub2", -- Chat Card [COMMANDO]
	[1359990521] = "StoreHub2", -- Kill Card [COMMANDO]
	[1360850484] = "StoreHub2", -- FAR AWAY Skin
	[1358950584] = "StoreHub2", -- Leaderboard Card [FAR AWAY]
	[1361168428] = "StoreHub2", -- Chat Card [FAR AWAY]
	[1359864544] = "StoreHub2", -- Kill Card [FAR AWAY]
	[1360658525] = "StoreHub2", -- WAVES Skin
	[1359936534] = "StoreHub2", -- Kill Card [WAVES]
	[1359386573] = "StoreHub2", -- Chat Card [WAVES]
	[1358974601] = "StoreHub2", -- Leaderboard Card [WAVES]
	[1360760509] = "StoreHub2", -- VOLATIL Skin
	[1359260577] = "StoreHub2", -- Chat Card [VOLATIL]
	[1360592486] = "StoreHub2", -- Leaderboard Card [VOLATIL]
	[1360262530] = "StoreHub2", -- Kill Card [VOLATIL]
	[1360274538] = "StoreHub2", -- Chat Card [BEAST]
	[1361036464] = "StoreHub2", -- Leaderboard Card [BEAST]
	[1360622501] = "StoreHub2", -- Kill Card [BEAST]
	[1359326568] = "StoreHub2", -- Leaderboard Card [DIGI]
	[1360568489] = "StoreHub2", -- Chat Card [DIGI]
	[1359374533] = "StoreHub2", -- Kill Card [DIGI]

	-- Store Hub 3
	[1587664977] = "StoreHub3", -- MAXWELL Skin
	[1775680713] = "StoreHub3", -- TOXIC Skin
	[1777664253] = "StoreHub3", -- TOXIC Player Card
	[1763970361] = "StoreHub3", -- TOXIC Bundle
	[1669552042] = "StoreHub3", -- Cat Pack
	[1668505672] = "StoreHub3", -- Night Pack
	[1667984238] = "StoreHub3", -- Jack O Lantern Pack
	[1668611295] = "StoreHub3", -- Ghost Pack
	[1668409910] = "StoreHub3", -- Punished Pack
	[1873048751] = "StoreHub3", -- Vex Skin
	[1870713038] = "StoreHub3", -- Vex Player Card
	[1870445094] = "StoreHub3", -- Vex Bundle
	[1899231358] = "StoreHub3", -- Hello Kitty Skin
	[1903128749] = "StoreHub3", -- Hello Kitty Player Card
	[1902972726] = "StoreHub3", -- Hello Kitty Bundle
	[1931220905] = "StoreHub3", -- Freeze Bundle
	[1930998900] = "StoreHub3", -- Freeze Skin
	[1933394265] = "StoreHub3", -- Freeze Player Card
	[2061442665] = "StoreHub3",
	[2060795201] = "StoreHub3",
	[2062084566] = "StoreHub3",
	[1668136122] = "StoreHub3", -- Digi Pack
	[1668754369] = "StoreHub3", -- Volatil Pack
	[1668678595] = "StoreHub3", -- Commando Pack
	[1669004259] = "StoreHub3", -- Far Away Pack
	[1668318105] = "StoreHub3", -- Waves Pack
	[1668585575] = "StoreHub3", -- Beast Pack
	[1661788677] = "StoreHub3", -- Best Seller Bundle
	[1663742264] = "StoreHub3", -- Launch Bundle
	[1550488613] = "StoreHub3", -- JACK O LANTERN Skin
	[1550436788] = "StoreHub3", -- GHOST Skin
	[1550310725] = "StoreHub3", -- Kill Card [GHOST]
	[1550636270] = "StoreHub3", -- Leaderboard Card [GHOST]
	[1550410577] = "StoreHub3", -- Chat Card [GHOST]
	[1550262618] = "StoreHub3", -- Chat Card [JACK O LANTERN]
	[1550540402] = "StoreHub3", -- Leaderboard Card [JACK O LANTERN]
	[1550084668] = "StoreHub3", -- Kill Card [JACK O LANTERN]
} :: { [number]: StoreHubKey }

function StoreHubRedirects.getHubForGamepass(gamepassId: number): StoreHubConfig?
	local hubKey = StoreHubRedirects.GamepassToHub[gamepassId]
	if not hubKey then
		return nil
	end

	return StoreHubRedirects.Hubs[hubKey]
end

return StoreHubRedirects
