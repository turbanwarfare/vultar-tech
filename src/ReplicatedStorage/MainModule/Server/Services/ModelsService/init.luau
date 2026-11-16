--!strict
--!native
--!optimize 2

local InsertService = game:GetService("InsertService")

local MainModule = script.Parent.Parent.Parent

local ModelsService = {}
ModelsService.Name = "ModelsService"

local ASSET_ID = 89483598271775
local ModelsContainer: Instance? = nil
local Loaded = false

function ModelsService:init()
	local success, assetModel = pcall(function()
		return InsertService:LoadAsset(ASSET_ID)
	end)

	if not success or not assetModel then
		local existing = MainModule:FindFirstChild("Models")
		if existing then
			ModelsContainer = existing
			Loaded = true
			return
		end
		warn("[ModelsService] Failed to load models asset")
		return
	end

	local modelsSource: Instance = assetModel:FindFirstChild("MainModule")
		or assetModel:FindFirstChild("Models")
		or assetModel

	local modelsFolder = Instance.new("Folder")
	modelsFolder.Name = "Models"

	for _, child in modelsSource:GetChildren() do
		if child ~= modelsFolder and child.Name ~= "MainModule" then
			child.Parent = modelsFolder
		end
	end

	modelsFolder.Parent = MainModule
	task.defer(assetModel.Destroy, assetModel)

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

function ModelsService:LoadFolderInto(folderName: string, parent: Instance): { Model }
	local folder = self:GetFolder(folderName)
	if not folder then
		return {}
	end

	local clones = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			local clone = child:Clone()
			clone.Parent = parent
			table.insert(clones, clone)
		end
	end
	return clones
end

return ModelsService
