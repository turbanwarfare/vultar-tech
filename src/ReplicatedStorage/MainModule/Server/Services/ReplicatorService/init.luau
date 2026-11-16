--!strict
--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local Constants = require(MainModule.Shared.Config.Constants)
local Retry = require(MainModule.Shared.Utils.Async.Retry)

type ReplicationMapping = {
	Source: string,
	Destination: Instance,
}

type ReplicationStats = {
	TotalItems: number,
	Replicated: number,
	Skipped: number,
	Failed: number,
	Errors: { string },
}

local ReplicatorService = {}
ReplicatorService.Name = "ReplicatorService"

local mainModule: Instance? = nil
local isInitialized: boolean = false
local replicationComplete: boolean = false
local stats: ReplicationStats = {
	TotalItems = 0,
	Replicated = 0,
	Skipped = 0,
	Failed = 0,
	Errors = {},
}

local FOLDER_MAPPINGS: { ReplicationMapping } = {
	{ Source = "ServerStorage", Destination = ServerStorage },
	{ Source = "ServerScriptService", Destination = ServerScriptService },
	{ Source = "ReplicatedStorage", Destination = ReplicatedStorage },
	{ Source = "StarterGui", Destination = StarterGui },
	{ Source = "StarterPlayer/StarterCharacterScripts", Destination = StarterPlayer.StarterCharacterScripts },
	{ Source = "StarterPlayer/StarterPlayerScripts", Destination = StarterPlayer.StarterPlayerScripts },
}

local function getSourceFolder(path: string): Folder?
	if not mainModule then
		return nil
	end

	local parts = string.split(path, "/")
	local current: Instance = mainModule

	for _, part in parts do
		local child = current:FindFirstChild(part)
		if not child then
			return nil
		end
		current = child
	end

	if current:IsA("Folder") then
		return current
	end
	return nil
end

local function shouldSkipInstance(instance: Instance, destination: Instance): boolean
	local existing = destination:FindFirstChild(instance.Name)
	return existing ~= nil
end

local function cloneInstance(instance: Instance): Instance?
	local result = Retry.execute(function()
		return instance:Clone()
	end)

	if result.Success and result.Value then
		return result.Value
	end

	table.insert(stats.Errors, `Failed to clone {instance:GetFullName()}: {result.Error or "Unknown error"}`)
	return nil
end

local function replicateInstance(instance: Instance, destination: Instance): boolean
	if shouldSkipInstance(instance, destination) then
		stats.Skipped += 1
		return true
	end

	local cloned = cloneInstance(instance)
	if not cloned then
		stats.Failed += 1
		return false
	end

	local result = Retry.execute(function()
		cloned.Parent = destination
		return true
	end)

	if result.Success then
		stats.Replicated += 1
		return true
	end

	stats.Failed += 1
	table.insert(
		stats.Errors,
		`Failed to parent {instance.Name} to {destination:GetFullName()}: {result.Error or "Unknown error"}`
	)
	cloned:Destroy()
	return false
end

local function replicateFolder(sourceFolder: Folder, destination: Instance): ()
	local children = sourceFolder:GetChildren()
	local batchCount = 0

	for _, child in children do
		stats.TotalItems += 1
		replicateInstance(child, destination)

		batchCount += 1
		if batchCount >= Constants.REPLICATION.BATCH_SIZE then
			batchCount = 0
			task.wait(Constants.REPLICATION.YIELD_INTERVAL)
		end
	end
end

local function injectToExistingPlayers(): ()
	local starterGuiSource = getSourceFolder("StarterGui")
	if not starterGuiSource or #starterGuiSource:GetChildren() == 0 then
		return
	end

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			local playerGui = player:WaitForChild("PlayerGui", 10)
			if playerGui then
				for _, child in starterGuiSource:GetChildren() do
					if not playerGui:FindFirstChild(child.Name) then
						local cloned = child:Clone()
						if cloned then
							cloned.Parent = playerGui
						end
					end
				end
			end
		end)
	end
end

local function replicateAll(): boolean
	if not mainModule then
		table.insert(stats.Errors, "MainModule reference not set")
		return false
	end

	for _, mapping in FOLDER_MAPPINGS do
		local sourceFolder = getSourceFolder(mapping.Source)
		if sourceFolder and #sourceFolder:GetChildren() > 0 then
			replicateFolder(sourceFolder, mapping.Destination)
		end
	end

	injectToExistingPlayers()

	replicationComplete = true
	return stats.Failed == 0
end

function ReplicatorService:init(): ()
	isInitialized = true
end

function ReplicatorService:start(): () end

function ReplicatorService:SetMainModule(module: Instance): ()
	mainModule = module
end

function ReplicatorService:Replicate(): (boolean, ReplicationStats)
	if not isInitialized then
		self:init()
	end

	stats = {
		TotalItems = 0,
		Replicated = 0,
		Skipped = 0,
		Failed = 0,
		Errors = {},
	}

	local success = replicateAll()
	return success, stats
end

function ReplicatorService:IsComplete(): boolean
	return replicationComplete
end

function ReplicatorService:GetStats(): ReplicationStats
	return stats
end

return ReplicatorService
