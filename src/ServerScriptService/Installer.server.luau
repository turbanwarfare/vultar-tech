--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local InsertService = game:GetService("InsertService")

for _, child in ReplicatedStorage:GetChildren() do
	if child.Name == "MainModule" then
		child:Destroy()
	end
end

local MainModule: ModuleScript?

if RunService:IsStudio() then
	local localModule = ServerStorage:FindFirstChild("MainModule")
	if localModule then
		MainModule = localModule:Clone()
		MainModule.Parent = ReplicatedStorage
	end
else
	local success, model = pcall(function()
		return InsertService:LoadAsset(0)
	end)

	if success and model then
		local assetModule = model:FindFirstChild("MainModule")
		if assetModule then
			assetModule.Parent = ReplicatedStorage
			MainModule = assetModule :: ModuleScript
		end
		model:Destroy()
	end
end

if not MainModule then
	local marker = Instance.new("Folder")
	marker.Name = "MainModule"
	marker:SetAttribute("LoadError", "MainModule load failed")
	marker.Parent = ReplicatedStorage
	return
end

local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function(character)
		task.defer(character.Destroy, character)
	end)
end)

for _, player in Players:GetPlayers() do
	player.CharacterRemoving:Connect(function(character)
		task.defer(character.Destroy, character)
	end)
end

require(MainModule).Load()
