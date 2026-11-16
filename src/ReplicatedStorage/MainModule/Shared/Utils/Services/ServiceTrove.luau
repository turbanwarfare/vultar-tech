--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Trove = require(Packages:WaitForChild("Trove", 5))

export type ServiceTrove = typeof(Trove.new())

local ServiceTrove = {}

function ServiceTrove.new(): ServiceTrove
	return Trove.new()
end

function ServiceTrove.wrap(existingCleanup: (() -> ())?): (ServiceTrove, () -> ())
	local trove = Trove.new()

	local function cleanup()
		trove:Destroy()
		if existingCleanup then
			existingCleanup()
		end
	end

	return trove, cleanup
end

function ServiceTrove.spawnTracked(trove: ServiceTrove, fn: () -> ()): thread
	local t = task.spawn(fn)
	trove:Add(t)
	return t
end

function ServiceTrove.delayTracked(trove: ServiceTrove, delayTime: number, fn: () -> ()): thread
	local t = task.delay(delayTime, fn)
	trove:Add(t)
	return t
end

return ServiceTrove
