local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vultar = {}

function Vultar.GetService(name: string): any?
	local mainModule = ReplicatedStorage:FindFirstChild("MainModule")
	if not (mainModule and mainModule:IsA("ModuleScript")) then
		return nil
	end

	local ok, vultar = pcall(require, mainModule)
	if not ok or type(vultar) ~= "table" or type(vultar.GetService) ~= "function" then
		return nil
	end
	return vultar.GetService(name)
end

return Vultar
