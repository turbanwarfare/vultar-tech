--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local ServiceTrove = require(MainModule.Shared.Utils.Services.ServiceTrove)

local SpatialQuery = {}

type CachedPlayerData = {
	humanoid: Humanoid,
	rootPart: BasePart,
}

local playerDataCache: { [Player]: CachedPlayerData? } = {}
local trove: ServiceTrove.ServiceTrove = nil :: any
local characterTroves: { [Player]: ServiceTrove.ServiceTrove } = {}

local PAYLOAD_TOUCH_EXPANSION = Vector3.one

local payloadOverlapParams = OverlapParams.new()
payloadOverlapParams.FilterType = Enum.RaycastFilterType.Include

local function cachePlayer(player: Player): ()
	local character = player.Character
	if not character then
		playerDataCache[player] = nil
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and rootPart then
		playerDataCache[player] = { humanoid = humanoid, rootPart = rootPart }
	else
		playerDataCache[player] = nil
	end
end

local function watchCharacter(player: Player): ()
	local existing = characterTroves[player]
	if existing then
		existing:Destroy()
	end
	local charTrove = trove:Extend()
	characterTroves[player] = charTrove
	charTrove:Connect(player.CharacterAdded, function()
		task.defer(cachePlayer, player)
	end)
	cachePlayer(player)
end

function SpatialQuery.init(): ()
	trove = ServiceTrove.new()

	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end

	trove:Connect(Players.PlayerAdded, function(player)
		watchCharacter(player)
	end)

	trove:Connect(Players.PlayerRemoving, function(player)
		playerDataCache[player] = nil
		local charTrove = characterTroves[player]
		if charTrove then
			charTrove:Destroy()
			characterTroves[player] = nil
		end
	end)
end

function SpatialQuery.cleanup(): ()
	if trove then
		trove:Destroy()
		trove = nil :: any
	end
	table.clear(characterTroves)
	table.clear(playerDataCache)
end

function SpatialQuery.iteratePlayerData(): { [Player]: CachedPlayerData? }
	return playerDataCache
end

function SpatialQuery.countFactionsNearPosition(
	position: Vector3,
	horizRange: number,
	vertRange: number,
	getPlayerFaction: (player: Player) -> string?,
	minVertRange: number?
): (number, number)
	debug.profilebegin("SpatialQuery::countFactions")
	local raiders = 0
	local defenders = 0
	local horizRangeSq = horizRange * horizRange

	for player, data in playerDataCache do
		if not data then continue end

		local humanoid = data.humanoid
		if not humanoid.Parent or humanoid.Health <= 0 then continue end

		local rootPart = data.rootPart
		if not rootPart.Parent then continue end

		local delta = rootPart.Position - position
		if minVertRange ~= nil then
			if delta.Y < minVertRange or delta.Y > vertRange then continue end
		else
			if math.abs(delta.Y) > vertRange then continue end
		end

		local horizDistSq = delta.X * delta.X + delta.Z * delta.Z
		if horizDistSq > horizRangeSq then continue end

		local faction = getPlayerFaction(player)
		if faction == "Raiders" then
			raiders += 1
		elseif faction == "Defenders" then
			defenders += 1
		end
	end

	debug.profileend()
	return raiders, defenders
end

function SpatialQuery.countFactionsOnParts(
	parts: { BasePart },
	getPlayerFaction: (player: Player) -> string?
): (number, number)
	debug.profilebegin("SpatialQuery::countFactionsOnParts")

	local charFilter: { Instance } = {}
	local charToPlayer: { [Instance]: Player } = {}

	for player, data in playerDataCache do
		if not data then continue end
		local humanoid = data.humanoid
		if not humanoid.Parent or humanoid.Health <= 0 then continue end
		local character = humanoid.Parent
		table.insert(charFilter, character)
		charToPlayer[character] = player
	end

	payloadOverlapParams.FilterDescendantsInstances = charFilter

	local raiders = 0
	local defenders = 0
	local counted: { [Player]: boolean } = {}

	for _, part in parts do
		local expandedSize = part.Size + PAYLOAD_TOUCH_EXPANSION
		for _, hit in workspace:GetPartBoundsInBox(part.CFrame, expandedSize, payloadOverlapParams) do
			local instance: Instance? = hit.Parent
			local player: Player? = nil
			while instance ~= nil do
				local found = charToPlayer[instance]
				if found then
					player = found
					break
				end
				instance = instance.Parent
			end
			if not player or counted[player] then continue end
			counted[player] = true
			local faction = getPlayerFaction(player)
			if faction == "Raiders" then
				raiders += 1
			elseif faction == "Defenders" then
				defenders += 1
			end
		end
	end

	debug.profileend()
	return raiders, defenders
end

function SpatialQuery.getPlayersNearPosition(
	position: Vector3,
	range: number,
	vertRange: number?,
	minVertRange: number?
): { Player }
	local result: { Player } = {}
	local rangeSq = range * range

	for player, data in playerDataCache do
		if not data then continue end

		local humanoid = data.humanoid
		if not humanoid.Parent or humanoid.Health <= 0 then continue end

		local rootPart = data.rootPart
		if not rootPart.Parent then continue end

		local delta = rootPart.Position - position
		if minVertRange ~= nil and vertRange ~= nil then
			if delta.Y < minVertRange or delta.Y > vertRange then continue end
			local horizDistSq = delta.X * delta.X + delta.Z * delta.Z
			if horizDistSq > rangeSq then continue end
		else
			if delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z > rangeSq then
				continue
			end
		end

		table.insert(result, player)
	end

	return result
end

return SpatialQuery
