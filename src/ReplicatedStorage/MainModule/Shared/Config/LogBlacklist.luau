--!strict
--!native
--!optimize 2

local PLACE_IDS: { [number]: true } = {
	[134407518396463] = true,
}

local LogBlacklist = {}

function LogBlacklist.isBlocked(placeId: number?): boolean
	return PLACE_IDS[placeId or game.PlaceId] == true
end

return LogBlacklist
