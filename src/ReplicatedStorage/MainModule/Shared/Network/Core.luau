--!strict
--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NetworkDebug = require(script.Parent.NetworkDebug)

local Core = {}

local REMOTES_FOLDER_NAME = "VultarRemotes"
local remotesFolder: Folder? = nil
local remoteEventCache: { [string]: RemoteEvent } = {}
local remoteFunctionCache: { [string]: RemoteFunction } = {}
local wrappedRemotes: { [string]: any } = {}

function Core.getRemotesFolder(): Folder
	if remotesFolder then
		return remotesFolder
	end

	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = REMOTES_FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		remotesFolder = folder :: Folder
	else
		local waitResult = ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME, 30)
		assert(waitResult, "Remotes folder not found")
		remotesFolder = waitResult :: Folder
	end

	return assert(remotesFolder, "Remotes folder failed to initialize") :: Folder
end

function Core.getOrCreateRemoteEvent(name: string): RemoteEvent
	local debugEnabled = NetworkDebug.isEnabled()

	if debugEnabled then
		local cached = wrappedRemotes["event_" .. name]
		if cached then
			return cached
		end
	end

	local cached = remoteEventCache[name]
	if cached and cached.Parent then
		if debugEnabled then
			local proxy = NetworkDebug.createEventProxy(name, cached)
			wrappedRemotes["event_" .. name] = proxy
			return proxy
		end
		return cached
	end

	local folder = Core.getRemotesFolder()

	if RunService:IsServer() then
		local remote = folder:FindFirstChild(name)
		if not remote then
			local newRemote = Instance.new("RemoteEvent")
			newRemote.Name = name
			newRemote.Parent = folder
			remote = newRemote
		end
		remoteEventCache[name] = remote :: RemoteEvent

		if debugEnabled then
			local proxy = NetworkDebug.createEventProxy(name, remote :: RemoteEvent)
			wrappedRemotes["event_" .. name] = proxy
			return proxy
		end
		return remote :: RemoteEvent
	else
		local remote = folder:FindFirstChild(name) :: RemoteEvent?
		if not remote then
			remote = folder:WaitForChild(name, 10) :: RemoteEvent
		end
		assert(remote, "RemoteEvent '" .. name .. "' not found after 10s timeout")
		remoteEventCache[name] = remote

		if debugEnabled then
			local proxy = NetworkDebug.createEventProxy(name, remote)
			wrappedRemotes["event_" .. name] = proxy
			return proxy
		end
		return remote
	end
end

function Core.getOrCreateUnreliableRemoteEvent(name: string): UnreliableRemoteEvent
	local debugEnabled = NetworkDebug.isEnabled()

	if debugEnabled then
		local cached = wrappedRemotes["event_" .. name]
		if cached then
			return cached
		end
	end

	local cached = remoteEventCache[name]
	if cached and cached.Parent then
		if debugEnabled then
			local proxy = NetworkDebug.createEventProxy(name, cached)
			wrappedRemotes["event_" .. name] = proxy
			return proxy
		end
		return cached
	end

	local folder = Core.getRemotesFolder()

	if RunService:IsServer() then
		local remote = folder:FindFirstChild(name)
		if not remote then
			local newRemote = Instance.new("UnreliableRemoteEvent")
			newRemote.Name = name
			newRemote.Parent = folder
			remote = newRemote
		end
		remoteEventCache[name] = remote :: UnreliableRemoteEvent

		if debugEnabled then
			local proxy = NetworkDebug.createEventProxy(name, remote :: UnreliableRemoteEvent)
			wrappedRemotes["event_" .. name] = proxy
			return proxy
		end
		return remote :: UnreliableRemoteEvent
	else
		local remote = folder:FindFirstChild(name) :: UnreliableRemoteEvent?
		if not remote then
			remote = folder:WaitForChild(name, 10) :: UnreliableRemoteEvent
		end
		assert(remote, "UnreliableRemoteEvent '" .. name .. "' not found after 10s timeout")
		remoteEventCache[name] = remote

		if debugEnabled then
			local proxy = NetworkDebug.createEventProxy(name, remote)
			wrappedRemotes["event_" .. name] = proxy
			return proxy
		end
		return remote
	end
end

function Core.getOrCreateRemoteFunction(name: string): RemoteFunction
	local debugEnabled = NetworkDebug.isEnabled()

	if debugEnabled then
		local cached = wrappedRemotes["func_" .. name]
		if cached then
			return cached
		end
	end

	local cached = remoteFunctionCache[name]
	if cached and cached.Parent then
		if debugEnabled then
			local proxy = NetworkDebug.createFunctionProxy(name, cached)
			wrappedRemotes["func_" .. name] = proxy
			return proxy
		end
		return cached
	end

	local folder = Core.getRemotesFolder()

	if RunService:IsServer() then
		local remote = folder:FindFirstChild(name)
		if not remote then
			local newRemote = Instance.new("RemoteFunction")
			newRemote.Name = name
			newRemote.Parent = folder
			remote = newRemote
		end
		remoteFunctionCache[name] = remote :: RemoteFunction

		if debugEnabled then
			local proxy = NetworkDebug.createFunctionProxy(name, remote :: RemoteFunction)
			wrappedRemotes["func_" .. name] = proxy
			return proxy
		end
		return remote :: RemoteFunction
	else
		local remote = folder:FindFirstChild(name) :: RemoteFunction?
		if not remote then
			remote = folder:WaitForChild(name, 10) :: RemoteFunction
		end
		assert(remote, "RemoteFunction '" .. name .. "' not found after 10s timeout")
		remoteFunctionCache[name] = remote

		if debugEnabled then
			local proxy = NetworkDebug.createFunctionProxy(name, remote)
			wrappedRemotes["func_" .. name] = proxy
			return proxy
		end
		return remote
	end
end

function Core.isServer(): boolean
	return RunService:IsServer()
end

function Core.isClient(): boolean
	return RunService:IsClient()
end

function Core.setDebug(enabled: boolean, logEachCall: boolean?): ()
	NetworkDebug.setEnabled(enabled, logEachCall)
	table.clear(wrappedRemotes)
end

function Core.getDebugStats(): { [string]: any }
	return NetworkDebug.getStats()
end

function Core.printDebugStats(): ()
	NetworkDebug.printStats()
end

function Core.resetDebugStats(): ()
	NetworkDebug.resetStats()
end

function Core.startPeriodicLogging(interval: number?): ()
	NetworkDebug.startPeriodicLogging(interval)
end

function Core.stopPeriodicLogging(): ()
	NetworkDebug.stopPeriodicLogging()
end

return Core
