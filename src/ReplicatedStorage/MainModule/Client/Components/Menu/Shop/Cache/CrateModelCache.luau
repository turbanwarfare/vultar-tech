--!strict
--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)

local CrateModelCache = {}

local modelCache: { [string]: Model } = {}

function CrateModelCache.isLoaded(): boolean
	local modelsService = ServiceLocator.Models()
	if modelsService then
		return modelsService:IsLoaded()
	end
	return MainModule:FindFirstChild("Models") ~= nil
end

function CrateModelCache.waitForLoaded(timeout: number?): boolean
	local modelsService = ServiceLocator.Models()
	if modelsService then
		return modelsService:WaitForLoaded(timeout)
	end
	local folder = MainModule:WaitForChild("Models", timeout or 5)
	return folder ~= nil
end

function CrateModelCache.onLoaded(callback: () -> ()): { Disconnect: () -> () }
	local modelsService = ServiceLocator.Models()
	if modelsService then
		return modelsService:OnLoaded(callback)
	end
	if MainModule:FindFirstChild("Models") then
		task.spawn(callback)
		return { Disconnect = function() end }
	end
	local thread = task.spawn(function()
		local folder = MainModule:WaitForChild("Models", 30)
		if folder then
			callback()
		end
	end)
	return {
		Disconnect = function()
			task.cancel(thread)
		end,
	}
end

function CrateModelCache.getModel(modelName: string): Model?
	local cached = modelCache[modelName]
	if cached and cached.Parent then
		return cached
	end

	local function checkCandidate(inst: Instance?): Model?
		if inst and inst:IsA("Model") then
			modelCache[modelName] = inst
			return inst
		end
		return nil
	end

	local modelsService = ServiceLocator.Models()
	if modelsService then
		local found = modelsService:FindModel(modelName)
		local foundModel = checkCandidate(found)
		if foundModel then
			return foundModel
		end
	end

	local foundInMain = MainModule:FindFirstChild(modelName, true)
	local model = checkCandidate(foundInMain)
	if model then
		return model
	end

	local foundInRep = ReplicatedStorage:FindFirstChild(modelName, true)
	local foundRepModel = checkCandidate(foundInRep)
	if foundRepModel then
		return foundRepModel
	end

	warn(string.format("[CrateModelCache] Model '%s' was NOT found in ModelsService, MainModule, or ReplicatedStorage!", modelName))
	return nil
end

function CrateModelCache.cloneModel(modelName: string): Model?
	local model = CrateModelCache.getModel(modelName)
	if model then
		return model:Clone()
	end
	return nil
end

function CrateModelCache.clearCache()
	table.clear(modelCache)
end

return CrateModelCache
