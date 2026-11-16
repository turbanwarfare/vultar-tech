--!strict
--!native
--!optimize 2

local Profile = {}

export type Slow = {
	name: string,
	ms: number,
}

local HISTORY_SIZE = 32

local names: { string } = table.create(HISTORY_SIZE, "")
local stamps: { number } = table.create(HISTORY_SIZE, -math.huge)
local durations: { number } = table.create(HISTORY_SIZE, -1)
local cursor = HISTORY_SIZE

local openIndex: { number } = {}
local openStamp: { number } = {}
local depth = 0

local function finish(ok: boolean, ...: any): ...any
	Profile.stop()
	if not ok then
		error((...), 0)
	end
	return ...
end

function Profile.begin(name: string): ()
	local started = os.clock()
	cursor = cursor % HISTORY_SIZE + 1
	names[cursor] = name
	stamps[cursor] = started
	durations[cursor] = -1
	depth += 1
	openIndex[depth] = cursor
	openStamp[depth] = started
	debug.profilebegin(name)
end

function Profile.stop(): ()
	debug.profileend()
	if depth > 0 then
		local index = openIndex[depth]
		if stamps[index] == openStamp[depth] then
			durations[index] = os.clock() - openStamp[depth]
		end
		depth -= 1
	end
end

function Profile.run<A..., R...>(name: string, fn: (A...) -> R..., ...: A...): R...
	Profile.begin(name)
	return finish(pcall(fn, ...))
end

function Profile.wrap<A..., R...>(name: string, fn: (A...) -> R...): (A...) -> R...
	return function(...: A...): R...
		return Profile.run(name, fn, ...)
	end
end

function Profile.recent(now: number, window: number, limit: number): { string }
	local result: { string } = {}
	local seen: { [string]: true } = {}
	local index = cursor
	for _ = 1, HISTORY_SIZE do
		if now - stamps[index] > window or #result >= limit then
			break
		end
		local name = names[index]
		if not seen[name] then
			seen[name] = true
			table.insert(result, name)
		end
		index = (index - 2) % HISTORY_SIZE + 1
	end
	return result
end

function Profile.slowest(now: number, window: number, limit: number): { Slow }
	local longest: { [string]: number } = {}
	for index = 1, HISTORY_SIZE do
		local length = durations[index]
		if length >= 0 and now - stamps[index] <= window then
			local name = names[index]
			local best = longest[name]
			if best == nil or length > best then
				longest[name] = length
			end
		end
	end

	local result: { Slow } = {}
	for name, length in longest do
		table.insert(result, { name = name, ms = length * 1000 })
	end
	table.sort(result, function(a: Slow, b: Slow): boolean
		return a.ms > b.ms
	end)
	for index = #result, limit + 1, -1 do
		result[index] = nil
	end
	return result
end

return Profile
