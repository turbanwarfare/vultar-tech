--!strict
--!native
--!optimize 2

export type Service = {
	Name: string?,
	init: ((self: any) -> ())?,
	start: ((self: any) -> ())?,
	Cleanup: ((self: any) -> ())?,
	[string]: any,
}

export type ServiceState = {
	service: Service,
	initialized: boolean,
	started: boolean,
}

local ServiceRegistry = {}

local services: { [string]: ServiceState } = {}
local initOrder: { string } = {}

function ServiceRegistry.register(name: string, service: Service): ()
	if services[name] then
		warn("[ServiceRegistry] Service already registered:", name)
		return
	end

	services[name] = {
		service = service,
		initialized = false,
		started = false,
	}
	table.insert(initOrder, name)
end

function ServiceRegistry.get(name: string): Service?
	local state = services[name]
	if state then
		return state.service
	end
	return nil
end

function ServiceRegistry.getStrict(name: string): Service
	local state = services[name]
	if not state then
		error("[ServiceRegistry] Service not found: " .. name)
	end
	return state.service
end

function ServiceRegistry.isRegistered(name: string): boolean
	return services[name] ~= nil
end

function ServiceRegistry.isInitialized(name: string): boolean
	local state = services[name]
	return state ~= nil and state.initialized
end

function ServiceRegistry.isStarted(name: string): boolean
	local state = services[name]
	return state ~= nil and state.started
end

function ServiceRegistry.initService(name: string): boolean
	local state = services[name]
	if not state then
		warn("[ServiceRegistry] Cannot init unknown service:", name)
		return false
	end

	if state.initialized then
		return true
	end

	local service = state.service
	if service.init then
		local success, err = pcall(service.init, service)
		if not success then
			warn("[ServiceRegistry] Failed to init", name, ":", err)
			return false
		end
	end

	state.initialized = true
	return true
end

function ServiceRegistry.startService(name: string): boolean
	local state = services[name]
	if not state then
		warn("[ServiceRegistry] Cannot start unknown service:", name)
		return false
	end

	if state.started then
		return true
	end

	if not state.initialized then
		if not ServiceRegistry.initService(name) then
			return false
		end
	end

	local service = state.service
	if service.start then
		local success, err = pcall(service.start, service)
		if not success then
			warn("[ServiceRegistry] Failed to start", name, ":", err)
			return false
		end
	end

	state.started = true
	return true
end

function ServiceRegistry.cleanupService(name: string): boolean
	local state = services[name]
	if not state then
		return false
	end

	local service = state.service
	if service.Cleanup then
		local success, err = pcall(service.Cleanup, service)
		if not success then
			warn("[ServiceRegistry] Failed to cleanup", name, ":", err)
			return false
		end
	end

	state.initialized = false
	state.started = false
	return true
end

function ServiceRegistry.initAll(): ()
	for _, name in initOrder do
		ServiceRegistry.initService(name)
	end
end

function ServiceRegistry.startAll(): ()
	for _, name in initOrder do
		ServiceRegistry.startService(name)
	end
end

function ServiceRegistry.cleanupAll(): ()
	for i = #initOrder, 1, -1 do
		ServiceRegistry.cleanupService(initOrder[i])
	end
end

function ServiceRegistry.getRegisteredServices(): { string }
	local names = {}
	for name in services do
		table.insert(names, name)
	end
	return names
end

function ServiceRegistry.getServiceCount(): number
	return #initOrder
end

function ServiceRegistry.clear(): ()
	table.clear(services)
	table.clear(initOrder)
end

return ServiceRegistry
