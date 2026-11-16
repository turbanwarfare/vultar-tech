--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent

local ModelsService = {}
ModelsService.Name = "ModelsService"

local WAIT_TIMEOUT = 30
local ModelsContainer: Instance? = nil
local Loaded = false

function ModelsService:init()
	local modelsFolder = MainModule:WaitForChild("Models", WAIT_TIMEOUT)
	if not modelsFolder then
		warn("[ModelsService] Models folder not found - server may have failed to load")
		return
	end

	ModelsContainer = modelsFolder
	Loaded = true
end

function ModelsService:start()
end

function ModelsService:IsLoaded(): boolean
	return Loaded
end

function ModelsService:GetContainer(): Instance?
	return ModelsContainer
end

function ModelsService:Find(name: string): Instance?
	if not ModelsContainer then
		return nil
	end
	return ModelsContainer:FindFirstChild(name, true)
end

function ModelsService:FindModel(name: string): Model?
	local found = self:Find(name)
	if found and found:IsA("Model") then
		return found
	end
	return nil
end

function ModelsService:Clone(name: string): Model?
	local model = self:FindModel(name)
	if model then
		return model:Clone()
	end
	return nil
end

function ModelsService:CloneInto(name: string, parent: Instance): Model?
	local clone = self:Clone(name)
	if clone then
		clone.Parent = parent
	end
	return clone
end

function ModelsService:GetFolder(name: string): Folder?
	if not ModelsContainer then
		return nil
	end
	local folder = ModelsContainer:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	return nil
end

function ModelsService:GetAllFromFolder(folderName: string): { Model }
	local folder = self:GetFolder(folderName)
	if not folder then
		return {}
	end

	local models = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			table.insert(models, child)
		end
	end
	return models
end

return ModelsService
