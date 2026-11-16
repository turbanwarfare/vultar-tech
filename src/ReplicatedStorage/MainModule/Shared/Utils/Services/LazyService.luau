--!strict
--!native
--!optimize 2

local ServiceRegistry = require(script.Parent.ServiceRegistry)

local LazyService = {}

function LazyService.create(mainModule: Instance?, serviceName: string): () -> any
	local cached: any = nil
	return function(): any
		if not cached then
			cached = ServiceRegistry.get(serviceName)
			if not cached and mainModule then
				local success, Vultar = pcall(require, mainModule)
				if success and typeof(Vultar) == "table" and typeof(Vultar.GetService) == "function" then
					cached = Vultar.GetService(serviceName)
				end
			end
		end
		return cached
	end
end

return LazyService
