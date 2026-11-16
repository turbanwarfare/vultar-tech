--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Game = {}

local mainModule: Instance? = nil

function Game.set(instance: Instance): ()
	mainModule = instance
end

function Game.get(): Instance
	local current = mainModule
	if current then
		return current
	end
	local found = ReplicatedStorage:WaitForChild("MainModule", 30)
	assert(found, "[ScreenWatch] MainModule not found in ReplicatedStorage")
	mainModule = found
	return found
end

return Game
