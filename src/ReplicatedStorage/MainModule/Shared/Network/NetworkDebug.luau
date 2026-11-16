--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")

local NetworkDebug = {}

local DEBUG_ENABLED = false
local DEBUG_LOG_EACH_CALL = false
local DEBUG_INTERVAL = 1

type DebugStats = {
	calls: number,
	totalBytes: number,
	lastCall: number,
	callsPerSecond: number,
	callHistory: { number },
}

local debugStats: { [string]: DebugStats } = {}
local debugStartTime = 0
local debugConnection: RBXScriptConnection? = nil

local function estimateSize(value: any): number
	local valueType = typeof(value)
	if valueType == "nil" then
		return 1
	elseif valueType == "boolean" then
		return 1
	elseif valueType == "number" then
		return 8
	elseif valueType == "string" then
		return #(value :: string) + 4
	elseif valueType == "Vector3" then
		return 24
	elseif valueType == "Vector2" then
		return 16
	elseif valueType == "CFrame" then
		return 48
	elseif valueType == "Color3" then
		return 12
	elseif valueType == "UDim2" then
		return 16
	elseif valueType == "Instance" then
		return 8
	elseif valueType == "table" then
		local size = 8
		for k, v in value :: { [any]: any } do
			size += estimateSize(k) + estimateSize(v)
		end
		return size
	else
		return 16
	end
end

function NetworkDebug.estimateArgsSize(...: any): number
	local total = 0
	local argCount = select("#", ...)
	local args = { ... }
	for i = 1, argCount do
		total += estimateSize(args[i])
	end
	return total
end

function NetworkDebug.estimateSize(value: any): number
	return estimateSize(value)
end

local function getOrCreateStats(name: string): DebugStats
	if not debugStats[name] then
		debugStats[name] = {
			calls = 0,
			totalBytes = 0,
			lastCall = 0,
			callsPerSecond = 0,
			callHistory = {},
		}
	end
	return debugStats[name]
end

function NetworkDebug.recordCall(name: string, direction: string, bytes: number)
	if not DEBUG_ENABLED then
		return
	end

	local stats = getOrCreateStats(name)
	local now = os.clock()

	stats.calls += 1
	stats.totalBytes += bytes
	stats.lastCall = now

	table.insert(stats.callHistory, now)
	while #stats.callHistory > 0 and stats.callHistory[1] < now - 1 do
		table.move(stats.callHistory, 2, #stats.callHistory, 1)
		stats.callHistory[#stats.callHistory] = nil
	end
	stats.callsPerSecond = #stats.callHistory

	if DEBUG_LOG_EACH_CALL then
		local side = if RunService:IsServer() then "[S]" else "[C]"
		print(string.format("%s [NET] %s %s | %d bytes | %.1f/s", side, direction, name, bytes, stats.callsPerSecond))
	end
end

local function formatBytes(bytes: number): string
	if bytes < 1024 then
		return string.format("%d B", bytes)
	elseif bytes < 1024 * 1024 then
		return string.format("%.1f KB", bytes / 1024)
	else
		return string.format("%.2f MB", bytes / (1024 * 1024))
	end
end

function NetworkDebug.isEnabled(): boolean
	return DEBUG_ENABLED
end

function NetworkDebug.setEnabled(enabled: boolean, logEachCall: boolean?): ()
	DEBUG_ENABLED = enabled
	DEBUG_LOG_EACH_CALL = logEachCall or false

	if enabled then
		debugStartTime = os.clock()
		print("[NET DEBUG] Network debugging ENABLED")
	else
		print("[NET DEBUG] Network debugging DISABLED")
	end
end

function NetworkDebug.getStats(): { [string]: DebugStats }
	return debugStats
end

function NetworkDebug.printStats(): ()
	local elapsed = os.clock() - debugStartTime
	local side = if RunService:IsServer() then "SERVER" else "CLIENT"

	print("\n========== NETWORK DEBUG STATS (" .. side .. ") ==========")
	print(string.format("Elapsed: %.1f seconds", elapsed))
	print("")

	local sorted: { { name: string, stats: DebugStats } } = {}
	for name, stats in debugStats do
		table.insert(sorted, { name = name, stats = stats })
	end
	table.sort(sorted, function(a, b)
		return a.stats.calls > b.stats.calls
	end)

	local totalCalls = 0
	local totalBytes = 0

	print(string.format("%-30s %10s %12s %10s", "REMOTE", "CALLS", "DATA", "RATE/s"))
	print(string.rep("-", 65))

	for _, entry in sorted do
		local name = entry.name
		local stats = entry.stats
		totalCalls += stats.calls
		totalBytes += stats.totalBytes

		print(string.format(
			"%-30s %10d %12s %10.1f",
			if #name > 30 then string.sub(name, 1, 27) .. "..." else name,
			stats.calls,
			formatBytes(stats.totalBytes),
			stats.callsPerSecond
		))
	end

	print(string.rep("-", 65))
	print(string.format("%-30s %10d %12s", "TOTAL", totalCalls, formatBytes(totalBytes)))
	print(string.format("Average: %.1f calls/sec, %s/sec", totalCalls / math.max(elapsed, 1), formatBytes(totalBytes / math.max(elapsed, 1))))
	print("=======================================================\n")
end

function NetworkDebug.resetStats(): ()
	table.clear(debugStats)
	debugStartTime = os.clock()
	print("[NET DEBUG] Stats reset")
end

function NetworkDebug.startPeriodicLogging(interval: number?): ()
	if debugConnection then
		debugConnection:Disconnect()
	end

	local logInterval = interval or DEBUG_INTERVAL
	local lastLog = os.clock()

	debugConnection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastLog >= logInterval then
			lastLog = now
			NetworkDebug.printStats()
		end
	end)

	print("[NET DEBUG] Periodic logging started (every " .. logInterval .. "s)")
end

function NetworkDebug.stopPeriodicLogging(): ()
	if debugConnection then
		debugConnection:Disconnect()
		debugConnection = nil
		print("[NET DEBUG] Periodic logging stopped")
	end
end

function NetworkDebug.createEventProxy(name: string, remote: RemoteEvent): any
	local proxy = {}
	local proxyMeta = {}

	proxyMeta.__index = function(_self, key)
		local original = (remote :: any)[key]
		if typeof(original) == "function" then
			if key == "FireServer" then
				return function(_s, ...)
					local bytes = NetworkDebug.estimateArgsSize(...)
					NetworkDebug.recordCall(name, "→ SEND", bytes)
					return remote:FireServer(...)
				end
			elseif key == "FireClient" then
				return function(_s, player: Player, ...)
					local bytes = NetworkDebug.estimateArgsSize(...)
					NetworkDebug.recordCall(name, "→ " .. player.Name, bytes)
					return remote:FireClient(player, ...)
				end
			elseif key == "FireAllClients" then
				return function(_s, ...)
					local bytes = NetworkDebug.estimateArgsSize(...)
					NetworkDebug.recordCall(name, "→ ALL", bytes)
					return remote:FireAllClients(...)
				end
			end
		end
		return original
	end

	proxyMeta.__newindex = function(_self, key, value)
		(remote :: any)[key] = value
	end

	setmetatable(proxy, proxyMeta)
	return proxy
end

function NetworkDebug.createFunctionProxy(name: string, remote: RemoteFunction): any
	local proxy = {}
	local proxyMeta = {}

	proxyMeta.__index = function(_self, key)
		local original = (remote :: any)[key]
		if typeof(original) == "function" then
			if key == "InvokeServer" then
				return function(_s, ...)
					local bytes = NetworkDebug.estimateArgsSize(...)
					NetworkDebug.recordCall(name, "→ INVOKE", bytes)
					local result = remote:InvokeServer(...)
					local resultBytes = NetworkDebug.estimateSize(result)
					NetworkDebug.recordCall(name, "← RESULT", resultBytes)
					return result
				end
			elseif key == "InvokeClient" then
				return function(_s, player: Player, ...)
					local bytes = NetworkDebug.estimateArgsSize(...)
					NetworkDebug.recordCall(name, "→ INVOKE " .. player.Name, bytes)
					local result = remote:InvokeClient(player, ...)
					local resultBytes = NetworkDebug.estimateSize(result)
					NetworkDebug.recordCall(name, "← RESULT", resultBytes)
					return result
				end
			end
		end
		return original
	end

	proxyMeta.__newindex = function(_self, key, value)
		if key == "OnServerInvoke" then
			(remote :: any).OnServerInvoke = function(player: Player, ...)
				local bytes = NetworkDebug.estimateArgsSize(...)
				NetworkDebug.recordCall(name, "← RECV " .. player.Name, bytes)
				local result = value(player, ...)
				local resultBytes = NetworkDebug.estimateSize(result)
				NetworkDebug.recordCall(name, "→ REPLY", resultBytes)
				return result
			end
		elseif key == "OnClientInvoke" then
			(remote :: any).OnClientInvoke = function(...)
				local bytes = NetworkDebug.estimateArgsSize(...)
				NetworkDebug.recordCall(name, "← RECV", bytes)
				local result = value(...)
				local resultBytes = NetworkDebug.estimateSize(result)
				NetworkDebug.recordCall(name, "→ REPLY", resultBytes)
				return result
			end
		else
			(remote :: any)[key] = value
		end
	end

	setmetatable(proxy, proxyMeta)
	return proxy
end

return NetworkDebug
