--!strict
--!native
--!optimize 2

local ServiceRegistry = require(script.Parent.ServiceRegistry)

local ServiceLocator = {}

local serviceCache: { [string]: any } = {}

local function getCached(name: string): any?
	if serviceCache[name] then
		return serviceCache[name]
	end

	local service = ServiceRegistry.get(name)
	if service then
		serviceCache[name] = service
	end
	return service
end

function ServiceLocator.Settings(): any?
	return getCached("SettingsService")
end

function ServiceLocator.Loading(): any?
	return getCached("LoadingService")
end

function ServiceLocator.Cursor(): any?
	return getCached("CursorService")
end

function ServiceLocator.Leaderboard(): any?
	return getCached("LeaderboardService")
end

function ServiceLocator.Gun(): any?
	return getCached("GunService")
end

function ServiceLocator.Weapon(): any?
	return getCached("WeaponService")
end

function ServiceLocator.Chat(): any?
	return getCached("ChatService")
end

function ServiceLocator.Ping(): any?
	return getCached("PingService")
end

function ServiceLocator.Stats(): any?
	return getCached("StatsService")
end

function ServiceLocator.Economy(): any?
	return getCached("EconomyService")
end

function ServiceLocator.Inventory(): any?
	return getCached("InventoryService")
end

function ServiceLocator.Cosmetic(): any?
	return getCached("CosmeticService")
end

function ServiceLocator.AnimatedCard(): any?
	return getCached("AnimatedCardService")
end

function ServiceLocator.TeamChanger(): any?
	return getCached("TeamChangerService")
end

function ServiceLocator.StatsHUD(): any?
	return getCached("StatsHUDService")
end

function ServiceLocator.PlayerToast(): any?
	return getCached("PlayerToastService")
end

function ServiceLocator.HurtScreen(): any?
	return getCached("HurtScreenService")
end

function ServiceLocator.Movement(): any?
	return getCached("MovementService")
end

function ServiceLocator.PingNotification(): any?
	return getCached("PingNotificationService")
end

function ServiceLocator.KillFeed(): any?
	return getCached("KillFeedService")
end

function ServiceLocator.ScreenWatch(): any?
	return getCached("ScreenWatchService")
end

function ServiceLocator.TeamESP(): any?
	return getCached("TeamESPService")
end

function ServiceLocator.TeamESPOverhead(): any?
	return getCached("TeamESPOverheadService")
end

function ServiceLocator.Models(): any?
	return getCached("ModelsService")
end

function ServiceLocator.get(name: string): any?
	return getCached(name)
end

function ServiceLocator.callIfExists(serviceName: string, methodName: string, ...: any): any?
	local service = getCached(serviceName)
	if not service then
		return nil
	end

	local method = service[methodName]
	if not method or typeof(method) ~= "function" then
		return nil
	end

	local success, result = pcall(method, service, ...)
	if success then
		return result
	end
	return nil
end

function ServiceLocator.isAvailable(name: string): boolean
	return ServiceRegistry.isStarted(name)
end

function ServiceLocator.clearCache(): ()
	table.clear(serviceCache)
end

return ServiceLocator
