--!strict
--!native
--!optimize 2

local TAU = math.pi * 2

local GAP = 2
local FOV = 70
local VIEW_DIST = 50
local PART_PER_UNIT = 3

local CENTER = CFrame.new(0, 0, -VIEW_DIST)
local EXTERIOR_RADIUS = VIEW_DIST * math.tan(math.rad(FOV / 2))
local G_OFFSET = GAP / (2 * EXTERIOR_RADIUS)
local EX_OFFSET = -TAU / 4 + G_OFFSET

return {
	TAU = TAU,
	GAP = GAP,
	FOV = FOV,
	VIEW_DIST = VIEW_DIST,
	PART_PER_UNIT = PART_PER_UNIT,
	CENTER = CENTER,
	EXTERIOR_RADIUS = EXTERIOR_RADIUS,
	G_OFFSET = G_OFFSET,
	EX_OFFSET = EX_OFFSET,
}
