--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MainModule = nil

local startTime = os.clock()
while os.clock() - startTime <= 60 do
	for _, child in ReplicatedStorage:GetChildren() do
		if child.Name == "MainModule" and child:IsA("ModuleScript") then
			if child:GetAttribute("Ready") then
				MainModule = child
				break
			elseif child:GetAttribute("LoadError") then
				warn("[Vultar Client] Server reported a load error:", child:GetAttribute("LoadError"))
				return
			end
		end
	end
	
	if MainModule then
		break
	end
	task.wait(0.5)
end

if not MainModule or not MainModule:GetAttribute("Ready") then
	warn("[Vultar Client] Timed out waiting for MainModule to be Ready")
	return
end

require(MainModule).Load()
MainModule:SetAttribute("ClientReady", true)