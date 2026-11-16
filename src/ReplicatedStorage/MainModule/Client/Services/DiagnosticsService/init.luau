--!strict
--!native
--!optimize 2

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)

type DiagnosticDump = Network.DiagnosticDump

local DiagnosticsService = {}
DiagnosticsService.Name = "DiagnosticsService"

local LocalPlayer = Players.LocalPlayer
local SAMPLE_FRAMES = 120
local MEMORY_SAMPLE_INTERVAL = 20

local isCollecting = false
local dumpRequestedConnection: RBXScriptConnection? = nil

local function getDeviceInfo(): {
	platform: string,
	osVersion: string?,
	deviceType: string,
	memoryMb: number?,
	cpuCores: number?,
	graphicsCard: string?,
}
	local platform = "Unknown"
	local deviceType = "Unknown"

	local success, inputType = pcall(function()
		return UserInputService:GetPlatform()
	end)

	if success then
		local platformStr = tostring(inputType)
		if string.find(platformStr, "Windows") then
			platform = "Windows"
			deviceType = "Desktop"
		elseif string.find(platformStr, "OSX") then
			platform = "macOS"
			deviceType = "Desktop"
		elseif string.find(platformStr, "IOS") then
			platform = "iOS"
			deviceType = "Mobile"
		elseif string.find(platformStr, "Android") then
			platform = "Android"
			deviceType = "Mobile"
		elseif string.find(platformStr, "Xbox") then
			platform = "Xbox"
			deviceType = "Console"
		elseif string.find(platformStr, "PS") then
			platform = "PlayStation"
			deviceType = "Console"
		else
			platform = platformStr
		end
	end

	local memoryMb: number? = nil
	local memSuccess, mem = pcall(function()
		return Stats:GetTotalMemoryUsageMb()
	end)
	if memSuccess then
		memoryMb = mem
	end

	return {
		platform = platform,
		osVersion = nil,
		deviceType = deviceType,
		memoryMb = memoryMb,
		cpuCores = nil,
		graphicsCard = nil,
	}
end

local function getMemorySnapshot(): {
	timestamp: number,
	totalMb: number,
	scriptsMb: number?,
	physicsMb: number?,
	instancesMb: number?,
	graphicsMb: number?,
}
	local totalMb = 0
	local success, mem = pcall(function()
		return Stats:GetTotalMemoryUsageMb()
	end)
	if success then
		totalMb = mem
	end

	return {
		timestamp = os.time(),
		totalMb = totalMb,
		scriptsMb = nil,
		physicsMb = nil,
		instancesMb = nil,
		graphicsMb = nil,
	}
end

local function getWorldSnapshot(): {
	totalInstances: number,
	partCount: number,
	meshPartCount: number?,
	scriptCount: number?,
	connectionCount: number?,
	activeHumanoids: number?,
	activeAnimations: number?,
	physicsBodyCount: number?,
}
	local totalInstances = 0
	local partCount = 0
	local meshPartCount = 0
	local scriptCount = 0
	local humanoidCount = 0

	local function countInstances(parent: Instance)
		for _, child in parent:GetChildren() do
			totalInstances += 1
			if child:IsA("BasePart") then
				partCount += 1
				if child:IsA("MeshPart") then
					meshPartCount += 1
				end
			elseif child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
				scriptCount += 1
			elseif child:IsA("Humanoid") then
				humanoidCount += 1
			end
			countInstances(child)
		end
	end

	pcall(countInstances, workspace)

	return {
		totalInstances = totalInstances,
		partCount = partCount,
		meshPartCount = meshPartCount,
		scriptCount = scriptCount,
		connectionCount = nil,
		activeHumanoids = humanoidCount,
		activeAnimations = nil,
		physicsBodyCount = nil,
	}
end

local function calculateAggregateStats(frames: { { timestamp: number, deltaTime: number, fps: number, heartbeatTime: number, renderTime: number?, physicsTime: number? } }): {
	avgFps: number,
	minFps: number,
	maxFps: number,
	p1Fps: number,
	p5Fps: number,
	avgFrameTime: number,
	maxFrameTime: number,
	frameDrops: number,
	stutterCount: number,
}
	if #frames == 0 then
		return {
			avgFps = 0,
			minFps = 0,
			maxFps = 0,
			p1Fps = 0,
			p5Fps = 0,
			avgFrameTime = 0,
			maxFrameTime = 0,
			frameDrops = 0,
			stutterCount = 0,
		}
	end

	local fpsValues: { number } = {}
	local frameTimeValues: { number } = {}
	local frameDrops = 0
	local stutterCount = 0

	for _, frame in frames do
		table.insert(fpsValues, frame.fps)
		table.insert(frameTimeValues, frame.deltaTime)

		if frame.fps < 30 then
			frameDrops += 1
		end
		if frame.deltaTime > 0.05 then
			stutterCount += 1
		end
	end

	table.sort(fpsValues)

	local totalFps = 0
	local totalFrameTime = 0
	local maxFrameTime = 0

	for _, fps in fpsValues do
		totalFps += fps
	end

	for _, ft in frameTimeValues do
		totalFrameTime += ft
		if ft > maxFrameTime then
			maxFrameTime = ft
		end
	end

	local count = #fpsValues
	local p1Index = math.max(1, math.floor(count * 0.01))
	local p5Index = math.max(1, math.floor(count * 0.05))

	return {
		avgFps = totalFps / count,
		minFps = fpsValues[1],
		maxFps = fpsValues[count],
		p1Fps = fpsValues[p1Index],
		p5Fps = fpsValues[p5Index],
		avgFrameTime = totalFrameTime / count,
		maxFrameTime = maxFrameTime,
		frameDrops = frameDrops,
		stutterCount = stutterCount,
	}
end

local function collectDiagnostics(): DiagnosticDump
	local frames: { { timestamp: number, deltaTime: number, fps: number, heartbeatTime: number, renderTime: number?, physicsTime: number? } } = {}
	local memorySnapshots: { { timestamp: number, totalMb: number, scriptsMb: number?, physicsMb: number?, instancesMb: number?, graphicsMb: number? } } = {}
	local events: { { timestamp: number, eventType: string, severity: string, message: string, stackTrace: string? } } = {}

	local frameCount = 0
	local lastMemorySample = 0

	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		debug.profilebegin("DiagnosticsService::heartbeat")
		frameCount += 1

		local fps = if deltaTime > 0 then 1 / deltaTime else 0

		table.insert(frames, {
			timestamp = os.time(),
			deltaTime = deltaTime,
			fps = fps,
			heartbeatTime = deltaTime,
			renderTime = nil,
			physicsTime = nil,
		})

		if frameCount - lastMemorySample >= MEMORY_SAMPLE_INTERVAL then
			lastMemorySample = frameCount
			table.insert(memorySnapshots, getMemorySnapshot())
		end

		if frameCount >= SAMPLE_FRAMES then
			connection:Disconnect()
		end
		debug.profileend()
	end)

	local startTime = os.clock()
	while frameCount < SAMPLE_FRAMES and (os.clock() - startTime) < 10 do
		task.wait()
	end

	if connection.Connected then
		connection:Disconnect()
	end

	local deviceInfo = getDeviceInfo()
	local worldSnapshot = getWorldSnapshot()
	local aggregateStats = calculateAggregateStats(frames)

	local dump = {
		meta = {
			dumpId = HttpService:GenerateGUID(false),
			playerId = LocalPlayer.UserId,
			playerName = LocalPlayer.Name,
			requesterId = 0,
			requesterName = "",
			targetId = LocalPlayer.UserId,
			targetName = LocalPlayer.Name,
			serverId = "",
			placeId = game.PlaceId,
			placeVersion = game.PlaceVersion,
			serverUptime = 0,
			timestamp = os.time(),
		},
		device = deviceInfo,
		frames = frames,
		aggregates = aggregateStats,
		memory = memorySnapshots,
		snapshot = worldSnapshot,
		events = events,
		networkStats = {
			pingMs = nil,
			dataReceived = nil,
			dataSent = nil,
		},
	}

	return dump :: any
end

local function onDumpRequested(): ()
	if isCollecting then
		return
	end

	isCollecting = true

	task.spawn(function()		local dump = collectDiagnostics()
		Network.Diagnostics.submitDump(dump)
		isCollecting = false
	end)
end

function DiagnosticsService:init(): ()
end

function DiagnosticsService:start(): ()
	dumpRequestedConnection = Network.Diagnostics.onDumpRequested(onDumpRequested)
end

function DiagnosticsService:IsCollecting(): boolean
	return isCollecting
end

function DiagnosticsService:Cleanup(): ()
	if dumpRequestedConnection then
		dumpRequestedConnection:Disconnect()
		dumpRequestedConnection = nil
	end
	isCollecting = false
end

return DiagnosticsService
