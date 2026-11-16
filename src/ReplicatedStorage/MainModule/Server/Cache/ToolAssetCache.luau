--!strict
--!native
--!optimize 2

local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MainModule = script.Parent.Parent.Parent
local Constants = require(MainModule.Shared.Config.Constants)
local Retry = require(MainModule.Shared.Utils.Async.Retry)

local TOOLS_ASSET_ID = Constants.ASSETS.TOOLS_ID

local cachedAsset: Instance? = nil
local inFlightLoad = false
local loadCompletedBindable = Instance.new("BindableEvent")

local ToolAssetCache = {}

local RETRY_CONFIG = {
	MaxAttempts = 5,
	InitialDelay = 1,
	MaxDelay = 10,
	BackoffMultiplier = 2,
}

local function findLocalToolsAsset(): Instance?
	local ssTools = ServerStorage:FindFirstChild("Tools")
	if ssTools then
		return ssTools
	end

	local rsTools = ReplicatedStorage:FindFirstChild("Tools")
	if rsTools then
		return rsTools
	end

	local ssSkins = ServerStorage:FindFirstChild("Skins")
	if ssSkins and ssSkins.Parent then
		return ssSkins.Parent
	end

	return nil
end

function ToolAssetCache.loadAsset(): (boolean, Instance?, string?)
	if cachedAsset and cachedAsset.Parent ~= nil then
		return true, cachedAsset, nil
	end

	if inFlightLoad then
		while inFlightLoad do
			loadCompletedBindable.Event:Wait()
		end

		if cachedAsset and cachedAsset.Parent ~= nil then
			return true, cachedAsset, nil
		end
	end

	local localAsset = findLocalToolsAsset()
	if localAsset then
		cachedAsset = localAsset
		return true, cachedAsset, nil
	end

	inFlightLoad = true

	local result = Retry.execute(function()
		return InsertService:LoadAsset(TOOLS_ASSET_ID)
	end, RETRY_CONFIG)

	inFlightLoad = false

	if result.Success and result.Value then
		local loadedModel = result.Value :: Instance
		cachedAsset = loadedModel

		if RunService:IsServer() then
			pcall(function()
				local cacheFolder = ServerStorage:FindFirstChild("VultarAssetCache")
				if not cacheFolder then
					cacheFolder = Instance.new("Folder")
					cacheFolder.Name = "VultarAssetCache"
					cacheFolder.Parent = ServerStorage
				end
				loadedModel.Parent = cacheFolder
			end)
		end

		loadCompletedBindable:Fire()
		return true, cachedAsset, nil
	else
		loadCompletedBindable:Fire()
		local err = result.Error or "Unknown error loading tools asset"
		warn(`[ToolAssetCache] Failed to load tools asset ({TOOLS_ASSET_ID}) after {result.Attempts} attempts: {err}`)
		return false, nil, err
	end
end

function ToolAssetCache.getToolsFolder(): Folder?
	local success, asset = ToolAssetCache.loadAsset()
	if not success or not asset then
		return nil
	end

	local toolsFolder = asset:FindFirstChild("Tools", true)
	if toolsFolder and toolsFolder:IsA("Folder") then
		return toolsFolder
	end

	return nil
end

function ToolAssetCache.getSkinsFolder(): Folder?
	local success, asset = ToolAssetCache.loadAsset()
	if not success or not asset then
		return nil
	end

	local skinsFolder = asset:FindFirstChild("Skins", true)
	if skinsFolder and skinsFolder:IsA("Folder") then
		return skinsFolder
	end

	return nil
end

function ToolAssetCache.isLoaded(): boolean
	return cachedAsset ~= nil and cachedAsset.Parent ~= nil
end

function ToolAssetCache.clearCache(): ()
	if cachedAsset then
		pcall(function()
			cachedAsset:Destroy()
		end)
		cachedAsset = nil
	end
end

return ToolAssetCache
