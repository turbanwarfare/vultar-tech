--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

export type CachedPlayer = {
	player: Player,
	name: string,
	lowerName: string,
	displayName: string,
	lowerDisplayName: string,
	userId: number,
}

local PlayerCache = {}

local cachedList: { CachedPlayer } = {}
local byLowerName: { [string]: CachedPlayer } = {}
local byLowerDisplayName: { [string]: CachedPlayer } = {}
local byUserId: { [number]: CachedPlayer } = {}
local listIndexByUserId: { [number]: number } = {}
local listDirty = false
local initialized = false
local connections: { RBXScriptConnection } = {}

local function createEntry(player: Player): CachedPlayer
	return {
		player = player,
		name = player.Name,
		lowerName = string.lower(player.Name),
		displayName = player.DisplayName,
		lowerDisplayName = string.lower(player.DisplayName),
		userId = player.UserId,
	}
end

local function sortList()
	table.sort(cachedList, function(a, b)
		return a.lowerName < b.lowerName
	end)
	listDirty = false
end

local function addPlayer(player: Player)
	if byUserId[player.UserId] then
		return
	end

	local entry = createEntry(player)
	table.insert(cachedList, entry)
	listIndexByUserId[entry.userId] = #cachedList
	byLowerName[entry.lowerName] = entry
	byLowerDisplayName[entry.lowerDisplayName] = entry
	byUserId[entry.userId] = entry
	listDirty = true
end

local function removePlayer(player: Player)
	local entry = byUserId[player.UserId]
	if not entry then
		return
	end

	byLowerName[entry.lowerName] = nil
	if byLowerDisplayName[entry.lowerDisplayName] == entry then
		byLowerDisplayName[entry.lowerDisplayName] = nil
	end
	byUserId[entry.userId] = nil

	local index = listIndexByUserId[player.UserId]
	if index then
		local lastIndex = #cachedList
		if index < lastIndex then
			local lastEntry = cachedList[lastIndex]
			cachedList[index] = lastEntry
			listIndexByUserId[lastEntry.userId] = index
		end
		cachedList[lastIndex] = nil
		listIndexByUserId[player.UserId] = nil
		listDirty = true
	end
end

local function ensureSorted()
	if listDirty then
		sortList()
	end
end

local function init()
	if initialized then
		return
	end
	initialized = true

	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
	sortList()

	table.insert(connections, Players.PlayerAdded:Connect(addPlayer))
	table.insert(connections, Players.PlayerRemoving:Connect(removePlayer))
end

function PlayerCache.getByExactName(name: string): CachedPlayer?
	init()
	local lower = string.lower(name)
	return byLowerName[lower] or byLowerDisplayName[lower]
end

function PlayerCache.getByUserId(userId: number): CachedPlayer?
	init()
	return byUserId[userId]
end

function PlayerCache.findByPrefix(partial: string): (CachedPlayer?, string?)
	init()
	if not partial or #partial == 0 then
		return nil, nil
	end

	local lowerPartial = string.lower(partial)
	local partialLen = #lowerPartial

	local exactName = byLowerName[lowerPartial]
	if exactName then
		return exactName, exactName.name
	end

	local exactDisplay = byLowerDisplayName[lowerPartial]
	if exactDisplay then
		return exactDisplay, exactDisplay.displayName
	end

	ensureSorted()

	for _, entry in cachedList do
		if string.sub(entry.lowerName, 1, partialLen) == lowerPartial then
			return entry, entry.name
		end
		if string.sub(entry.lowerDisplayName, 1, partialLen) == lowerPartial then
			return entry, entry.displayName
		end
	end

	return nil, nil
end

function PlayerCache.findByPartial(partial: string): CachedPlayer?
	init()
	if not partial or #partial == 0 then
		return nil
	end

	local lowerPartial = string.lower(partial)

	local exactName = byLowerName[lowerPartial]
	if exactName then
		return exactName
	end

	local exactDisplay = byLowerDisplayName[lowerPartial]
	if exactDisplay then
		return exactDisplay
	end

	ensureSorted()

	for _, entry in cachedList do
		if string.find(entry.lowerName, lowerPartial, 1, true) then
			return entry
		end
		if string.find(entry.lowerDisplayName, lowerPartial, 1, true) then
			return entry
		end
	end

	return nil
end

function PlayerCache.findByUniquePrefix(partial: string): (CachedPlayer?, string?)
	init()
	if not partial or #partial == 0 then
		return nil, nil
	end

	local lowerPartial = string.lower(partial)
	local partialLen = #lowerPartial

	local exactName = byLowerName[lowerPartial]
	if exactName then
		return exactName, exactName.name
	end

	local exactDisplay = byLowerDisplayName[lowerPartial]
	if exactDisplay then
		return exactDisplay, exactDisplay.displayName
	end

	ensureSorted()

	local matchedEntry: CachedPlayer? = nil
	local matchedName: string? = nil

	for _, entry in cachedList do
		local nameMatches = string.sub(entry.lowerName, 1, partialLen) == lowerPartial
		local displayMatches = string.sub(entry.lowerDisplayName, 1, partialLen) == lowerPartial

		if nameMatches or displayMatches then
			if matchedEntry ~= nil then
				return nil, nil
			end
			matchedEntry = entry
			matchedName = if nameMatches then entry.name else entry.displayName
		end
	end

	return matchedEntry, matchedName
end

function PlayerCache.getAll(): { CachedPlayer }
	init()
	ensureSorted()
	return cachedList
end

function PlayerCache.getCount(): number
	init()
	return #cachedList
end

function PlayerCache.cleanup(): ()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	table.clear(cachedList)
	table.clear(byLowerName)
	table.clear(byLowerDisplayName)
	table.clear(byUserId)
	table.clear(listIndexByUserId)
	initialized = false
end

init()

return PlayerCache
