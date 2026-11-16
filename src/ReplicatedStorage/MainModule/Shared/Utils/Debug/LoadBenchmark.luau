--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")

local LoadBenchmark = {}

local ENABLED = false
local PRINT_IMMEDIATELY = true
local INDENT_CHAR = "  "

type TimingEntry = {
	name: string,
	startTime: number,
	endTime: number?,
	duration: number?,
	parent: string?,
	depth: number,
	children: { string },
	memory_start: number?,
	memory_end: number?,
	memory_delta: number?,
}

local timings: { [string]: TimingEntry } = {}
local timingOrder: { string } = {}
local activeStack: { string } = {}
local globalStartTime: number = 0
local marks: { { name: string, time: number, memory: number } } = {}

local side = if RunService:IsServer() then "[S]" else "[C]"

local function getMemoryMB(): number
	local success, memory = pcall(function()
		return gcinfo() / 1024
	end)
	return if success then memory else 0
end

local function getIndent(depth: number): string
	return string.rep(INDENT_CHAR, depth)
end

local function formatDuration(ms: number): string
	if ms < 0.001 then
		return string.format("%.3f μs", ms * 1000)
	elseif ms < 1 then
		return string.format("%.3f ms", ms)
	elseif ms < 1000 then
		return string.format("%.2f ms", ms)
	else
		return string.format("%.2f s", ms / 1000)
	end
end

local function formatMemory(mb: number): string
	if math.abs(mb) < 0.001 then
		return string.format("%.2f KB", mb * 1024)
	else
		return string.format("%.3f MB", mb)
	end
end

local function printImmediate(depth: number, icon: string, name: string, extra: string?)
	if not PRINT_IMMEDIATELY then
		return
	end
	local indent = getIndent(depth)
	local timestamp = string.format("[%.3f]", (os.clock() - globalStartTime) * 1000)
	local msg = string.format("%s %s %s%s %s", side, timestamp, indent, icon, name)
	if extra then
		msg = msg .. " " .. extra
	end
	print(msg)
end

function LoadBenchmark.init(): ()
	if not ENABLED then
		return
	end
	globalStartTime = os.clock()
	table.clear(timings)
	table.clear(timingOrder)
	table.clear(activeStack)
	table.clear(marks)

	local mem = getMemoryMB()
	print(string.format("\n%s ╔══════════════════════════════════════════════════════════════╗", side))
	print(string.format("%s ║           LOAD BENCHMARK STARTED                             ║", side))
	print(string.format("%s ║  Initial Memory: %-44s║", side, formatMemory(mem)))
	print(string.format("%s ╚══════════════════════════════════════════════════════════════╝\n", side))
end

function LoadBenchmark.start(name: string): ()
	if not ENABLED then
		return
	end

	if globalStartTime == 0 then
		LoadBenchmark.init()
	end

	local depth = #activeStack
	local parent = if depth > 0 then activeStack[depth] else nil
	local now = os.clock()
	local mem = getMemoryMB()

	local fullName = name
	if parent then
		fullName = parent .. "/" .. name
	end

	if timings[fullName] then
		local counter = 2
		while timings[fullName .. "_" .. counter] do
			counter += 1
		end
		fullName = fullName .. "_" .. counter
	end

	timings[fullName] = {
		name = name,
		startTime = now,
		endTime = nil,
		duration = nil,
		parent = parent,
		depth = depth,
		children = {},
		memory_start = mem,
		memory_end = nil,
		memory_delta = nil,
	}

	table.insert(timingOrder, fullName)

	if parent and timings[parent] then
		table.insert(timings[parent].children, fullName)
	end

	table.insert(activeStack, fullName)

	printImmediate(depth, "▶", name, string.format("(mem: %s)", formatMemory(mem)))
end

function LoadBenchmark.stop(name: string?): number
	if not ENABLED then
		return 0
	end

	local now = os.clock()
	local mem = getMemoryMB()

	if #activeStack == 0 then
		warn("[LoadBenchmark] stop() called with empty stack for:", name)
		return 0
	end

	local fullName = activeStack[#activeStack]
	local entry = timings[fullName]

	if not entry then
		warn("[LoadBenchmark] No timing entry found for:", fullName)
		table.remove(activeStack)
		return 0
	end

	if name and entry.name ~= name then
		warn(string.format("[LoadBenchmark] Mismatched stop: expected '%s', got '%s'", entry.name, name))
	end

	entry.endTime = now
	entry.duration = (now - entry.startTime) * 1000
	entry.memory_end = mem
	entry.memory_delta = mem - (entry.memory_start or 0)

	table.remove(activeStack)

	local durationStr = formatDuration(entry.duration :: number)
	local memDeltaStr = formatMemory(entry.memory_delta :: number)
	local memSign = if (entry.memory_delta :: number) >= 0 then "+" else ""

	printImmediate(entry.depth, "◀", entry.name, string.format("(%s, %s%s)", durationStr, memSign, memDeltaStr))

	return entry.duration :: number
end

function LoadBenchmark.mark(name: string): ()
	if not ENABLED then
		return
	end

	local now = os.clock()
	local mem = getMemoryMB()
	local elapsed = (now - globalStartTime) * 1000

	table.insert(marks, {
		name = name,
		time = elapsed,
		memory = mem,
	})

	local depth = #activeStack
	printImmediate(depth, "●", "MARK: " .. name, string.format("(%.2f ms total, mem: %s)", elapsed, formatMemory(mem)))
end

function LoadBenchmark.measure(name: string, fn: () -> ()): number
	LoadBenchmark.start(name)
	local success, err: any = pcall(fn)
	local duration = LoadBenchmark.stop(name)
	if not success then
		warn("[LoadBenchmark] Error in", name, ":", err)
	end
	return duration
end

function LoadBenchmark.measureAsync(name: string, fn: () -> ()): number
	LoadBenchmark.start(name)
	local success, err: any = pcall(fn)
	local duration = LoadBenchmark.stop(name)
	if not success then
		warn("[LoadBenchmark] Error in", name, ":", err)
	end
	return duration
end

function LoadBenchmark.checkpoint(name: string): ()
	if not ENABLED then
		return
	end

	local now = os.clock()
	local mem = getMemoryMB()
	local elapsed = (now - globalStartTime) * 1000

	print(string.format("%s ┌─────────────────────────────────────────────────────────────┐", side))
	print(string.format("%s │ CHECKPOINT: %-48s│", side, name))
	print(string.format("%s │ Time: %-53s│", side, string.format("%.2f ms since start", elapsed)))
	print(string.format("%s │ Memory: %-51s│", side, formatMemory(mem)))
	print(string.format("%s └─────────────────────────────────────────────────────────────┘", side))
end

function LoadBenchmark.detail(message: string): ()
	if not ENABLED then
		return
	end

	local depth = #activeStack
	local now = os.clock()
	local elapsed = (now - globalStartTime) * 1000

	printImmediate(depth + 1, "·", message, string.format("[%.2f ms]", elapsed))
end

function LoadBenchmark.printReport(): ()
	if not ENABLED then
		return
	end

	local totalTime = (os.clock() - globalStartTime) * 1000
	local finalMem = getMemoryMB()

	print(string.format("\n%s ╔══════════════════════════════════════════════════════════════╗", side))
	print(string.format("%s ║                    LOAD BENCHMARK REPORT                     ║", side))
	print(string.format("%s ╠══════════════════════════════════════════════════════════════╣", side))
	print(string.format("%s ║ Total Load Time: %-43s║", side, formatDuration(totalTime)))
	print(string.format("%s ║ Final Memory: %-46s║", side, formatMemory(finalMem)))
	print(string.format("%s ╠══════════════════════════════════════════════════════════════╣", side))
	print(string.format("%s ║                      TIMING BREAKDOWN                        ║", side))
	print(string.format("%s ╠══════════════════════════════════════════════════════════════╣", side))

	local rootTimings: { TimingEntry } = {}
	for _, fullName in timingOrder do
		local entry = timings[fullName]
		if entry and not entry.parent then
			table.insert(rootTimings, entry)
		end
	end

	local function printEntry(entry: TimingEntry, depth: number)
		local indent = getIndent(depth)
		local duration = entry.duration or 0
		local pct = if totalTime > 0 then (duration / totalTime) * 100 else 0
		local memDelta = entry.memory_delta or 0
		local memSign = if memDelta >= 0 then "+" else ""

		local barLen = math.min(pct // 5, 10)
		local bar = string.rep("█", barLen) .. string.rep("░", 10 - barLen)

		print(string.format("%s ║ %s%-25s %10s %5.1f%% %s %s%s ║",
			side,
			indent,
			if #entry.name > 25 - #indent then string.sub(entry.name, 1, 22 - #indent) .. "..." else entry.name,
			formatDuration(duration),
			pct,
			bar,
			memSign,
			formatMemory(memDelta)
		))

		for _, childName in entry.children do
			local child = timings[childName]
			if child then
				printEntry(child, depth + 1)
			end
		end
	end

	for _, entry in rootTimings do
		printEntry(entry, 0)
	end

	if #marks > 0 then
		print(string.format("%s ╠══════════════════════════════════════════════════════════════╣", side))
		print(string.format("%s ║                        CHECKPOINTS                           ║", side))
		print(string.format("%s ╠══════════════════════════════════════════════════════════════╣", side))

		for _, mark in marks do
			print(string.format("%s ║ ● %-40s %15s ║", side, mark.name, formatDuration(mark.time)))
		end
	end

	print(string.format("%s ╠══════════════════════════════════════════════════════════════╣", side))
	print(string.format("%s ║                      SLOWEST OPERATIONS                      ║", side))
	print(string.format("%s ╠══════════════════════════════════════════════════════════════╣", side))

	local sortedTimings: { TimingEntry } = {}
	for _, entry in timings do
		if entry.duration then
			table.insert(sortedTimings, entry)
		end
	end
	table.sort(sortedTimings, function(a, b)
		return (a.duration or 0) > (b.duration or 0)
	end)

	for i = 1, math.min(10, #sortedTimings) do
		local entry = sortedTimings[i]
		local pct = if totalTime > 0 then ((entry.duration or 0) / totalTime) * 100 else 0
		print(string.format("%s ║ %2d. %-35s %10s (%5.1f%%) ║",
			side, i,
			if #entry.name > 35 then string.sub(entry.name, 1, 32) .. "..." else entry.name,
			formatDuration(entry.duration or 0),
			pct
		))
	end

	print(string.format("%s ╚══════════════════════════════════════════════════════════════╝\n", side))
end

function LoadBenchmark.isEnabled(): boolean
	return ENABLED
end

function LoadBenchmark.setEnabled(enabled: boolean): ()
	ENABLED = enabled
end

return LoadBenchmark
