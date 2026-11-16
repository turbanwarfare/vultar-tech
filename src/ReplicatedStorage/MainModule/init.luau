--!strict
--!native
--!optimize 2
--#selene: allow(global_usage)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ServiceRegistry = require(script.Shared.Utils.Services.ServiceRegistry)
local Profile = require(script.Shared.Utils.Debug.Profile)
local Maps = require(script.Shared.Config.Maps)
local FeatureFlags = require(script.Shared.Config.FeatureFlags)

local Vultar = {}

Vultar.Version = "__COMMIT_HASH__"
Vultar.IsServer = RunService:IsServer()
Vultar.IsClient = RunService:IsClient()
Vultar.IsLoaded = false

local services: { [string]: any } = {}
local isLoading: boolean = false
local disabledServicesSet: { [string]: boolean } = {}

local function hasClassSystem(): boolean
	return FeatureFlags.isEnabled("ClassSystem")
end

local function isHardpointMap(): boolean
	return Maps.isHardpointMap() == true
end

local SERVICE_GATES: { [string]: () -> boolean } = {
	PhaseService = Maps.isPhaseMap,
	PhaseHUDService = Maps.isPhaseMap,
	PhaseControlsService = Maps.isPhaseMap,
	HardpointService = isHardpointMap,
	TerminalService = isHardpointMap,
	TerminalControlsService = isHardpointMap,
	DominationService = Maps.isDominationMap,
	DominationHUDService = Maps.isDominationMap,
	DominationControlsService = Maps.isDominationMap,
	SparringService = Maps.isSparMode,
	AimChamberService = Maps.isAimMode,
	FlagBearerService = hasClassSystem,
	ClassSelectionService = hasClassSystem,
}

local function isGatedOff(serviceName: string): boolean
	local gate = SERVICE_GATES[serviceName]
	return gate ~= nil and not gate()
end

local loadHealth = {
	servicesLoaded = 0,
	servicesFailed = 0,
	servicesTotal = 0,
	failedServices = {} :: { string },
	initFailed = {} :: { string },
	startFailed = {} :: { string },
	replicationSuccess = true,
	adminLoaded = nil :: boolean?,
	criticalError = nil :: string?,
}

local LoadBenchmark: any = nil

local function getBenchmark(): any
	if LoadBenchmark then
		return LoadBenchmark
	end
	local success, result = pcall(require, script.Shared.Utils.Debug.LoadBenchmark)
	if success then
		LoadBenchmark = result
		return result
	end
	return nil
end

local function bench_start(name: string)
	local b = getBenchmark()
	if b then
		b.start(name)
	end
end

local function bench_stop(name: string?)
	local b = getBenchmark()
	if b then
		b.stop(name)
	end
end

local function bench_detail(msg: string)
	local b = getBenchmark()
	if b then
		b.detail(msg)
	end
end

local function bench_mark(name: string)
	local b = getBenchmark()
	if b then
		b.mark(name)
	end
end

local function bench_checkpoint(name: string)
	local b = getBenchmark()
	if b then
		b.checkpoint(name)
	end
end

local function bench_report()
	local b = getBenchmark()
	if b then
		b.printReport()
	end
end

local function getShared(): Folder
	return script:WaitForChild("Shared", 5) :: Folder
end

local function getServer(): Folder?
	if not Vultar.IsServer then
		return nil
	end
	return script:FindFirstChild("Server") :: Folder?
end

local function getClient(): Folder?
	if not Vultar.IsClient then
		return nil
	end
	return script:FindFirstChild("Client") :: Folder?
end

local function safeRequire(moduleScript: ModuleScript, moduleName: string?): (boolean, any)
	local maxAttempts = 5
	local delay = 0.1
	local name = moduleName or moduleScript.Name

	for attempt = 1, maxAttempts do
		bench_detail(string.format("require attempt %d/%d for %s", attempt, maxAttempts, name))
		local success, result = pcall(require, moduleScript)
		if success then
			bench_detail(string.format("require SUCCESS for %s", name))
			return true, result
		end

		bench_detail(string.format("require FAILED for %s: %s", name, result))
		if attempt < maxAttempts then
			bench_detail(string.format("waiting %.2fs before retry", delay))
			task.wait(delay)
			delay = math.min(delay * 2, 5)
		else
			return false, result
		end
	end

	return false, "Max attempts reached"
end

local function collectServiceModules(folder: Folder): { { module: ModuleScript, name: string } }
	bench_start("collectServiceModules:" .. folder.Name)
	local modules: { { module: ModuleScript, name: string } } = {}
	local servicesFolder = folder:FindFirstChild("Services")
	if not servicesFolder then
		bench_detail("No Services folder found in " .. folder.Name)
		bench_stop()
		return modules
	end

	bench_detail(string.format("Found Services folder with %d children", #servicesFolder:GetChildren()))

	for _, child in servicesFolder:GetChildren() do
		local moduleToLoad: ModuleScript? = nil
		local serviceName = child.Name

		if child:IsA("ModuleScript") and not child.Name:match("%.spec$") then
			moduleToLoad = child
			bench_detail(string.format("Found ModuleScript service: %s", serviceName))
		elseif child:IsA("Folder") then
			local initModule = child:FindFirstChild("init")
			if initModule and initModule:IsA("ModuleScript") then
				moduleToLoad = initModule
				bench_detail(string.format("Found Folder service with init: %s", serviceName))
			else
				bench_detail(string.format("Folder %s has no init module, skipping", serviceName))
			end
		else
			bench_detail(string.format("Skipping non-service child: %s (%s)", child.Name, child.ClassName))
		end

		if moduleToLoad and not disabledServicesSet[serviceName] and not isGatedOff(serviceName) then
			table.insert(modules, { module = moduleToLoad, name = serviceName })
		elseif moduleToLoad and disabledServicesSet[serviceName] then
			bench_detail(string.format("Skipping disabled service: %s", serviceName))
		end
	end

	bench_detail(string.format("Collected %d service modules", #modules))
	bench_stop()
	return modules
end

local function loadServicesParallel(folder: Folder): ()
	bench_start("loadServicesParallel:" .. folder.Name)

	local moduleInfos = collectServiceModules(folder)
	if #moduleInfos == 0 then
		bench_detail("No modules to load")
		bench_stop()
		return
	end

	bench_checkpoint("Starting parallel service require")

	local loadedServices: { { service: any, name: string, loadTime: number } } = {}
	local completed = 0
	local total = #moduleInfos
	loadHealth.servicesTotal += total

	bench_start("Phase1:RequireServices")
	for _, info in moduleInfos do
		task.spawn(function()
			local startTime = os.clock()
			bench_start("require:" .. info.name)
			local success, result = safeRequire(info.module, info.name)
			bench_stop()
			local loadTime = (os.clock() - startTime) * 1000

			if success and result then
				local service = result
				local name: string = if typeof(service.Name) == "string" then service.Name else info.name
				table.insert(loadedServices, { service = service, name = name, loadTime = loadTime })
				bench_detail(string.format("Service %s required in %.2f ms", name, loadTime))
				loadHealth.servicesLoaded += 1
			else
				bench_detail(string.format("FAILED to require %s: %s", info.name, result))
				warn(`[Vultar] FAILED to require service: {info.name} - {result}`)
				loadHealth.servicesFailed += 1
				table.insert(loadHealth.failedServices, info.name)
			end
			completed += 1
		end)
	end

	bench_detail(string.format("Spawned %d require tasks, waiting for completion", total))
	local waitStart = os.clock()
	while completed < total do
		task.wait()
	end
	local waitTime = (os.clock() - waitStart) * 1000
	bench_detail(string.format("All requires completed, wait loop took %.2f ms", waitTime))
	bench_stop()

	bench_checkpoint("Starting service init() calls")

	bench_start("Phase2:InitServices")
	local initCompleted = 0
	local initTotal = 0

	for _, data in loadedServices do
		services[data.name] = data.service
		ServiceRegistry.register(data.name, data.service)
		bench_detail(string.format("Registered service: %s", data.name))

		if typeof(data.service.init) == "function" then
			initTotal += 1
			Profile.begin("Vultar::init::" .. data.name)
			task.spawn(function()
				local initStart = os.clock()
				bench_start("init:" .. data.name)
				local success, err = pcall(data.service.init, data.service)
				bench_stop()
				local initTime = (os.clock() - initStart) * 1000

				if success then
					bench_detail(string.format("init() for %s completed in %.2f ms", data.name, initTime))
				else
					bench_detail(string.format("init() for %s FAILED in %.2f ms: %s", data.name, initTime, err))
					warn(`[Vultar] init() FAILED for service: {data.name} - {err}`)
					table.insert(loadHealth.initFailed, data.name)
				end
				initCompleted += 1
			end)
			Profile.stop()
		else
			bench_detail(string.format("Service %s has no init() function", data.name))
			initCompleted += 1
			initTotal += 1
		end
	end

	bench_detail(string.format("Spawned %d init tasks, waiting for completion", initTotal))
	waitStart = os.clock()
	while initCompleted < #loadedServices do
		task.wait()
	end
	waitTime = (os.clock() - waitStart) * 1000
	bench_detail(string.format("All init() completed, wait loop took %.2f ms", waitTime))
	bench_stop()

	bench_stop()
end

local function loadServices(folder: Folder): ()
	loadServicesParallel(folder)
end

local function startServices(): ()
	bench_start("startServices")
	local startCompleted = 0
	local totalServices = 0

	bench_start("Phase3:StartServices")
	for serviceName, service in services do
		totalServices += 1
		if typeof(service.start) == "function" then
			Profile.begin("Vultar::start::" .. serviceName)
			task.spawn(function()
				local startTime = os.clock()
				bench_start("start:" .. serviceName)
				local success, err = pcall(service.start, service)
				bench_stop()
				local elapsed = (os.clock() - startTime) * 1000

				if success then
					bench_detail(string.format("start() for %s completed in %.2f ms", serviceName, elapsed))
				else
					warn(`[Vultar] start() FAILED for: {serviceName} - {err}`)
					bench_detail(string.format("start() for %s FAILED in %.2f ms: %s", serviceName, elapsed, err))
					table.insert(loadHealth.startFailed, serviceName)
				end
				startCompleted += 1
			end)
			Profile.stop()
		else
			bench_detail(string.format("Service %s has no start() function", serviceName))
			startCompleted += 1
		end
	end

	bench_detail(string.format("Spawned %d start tasks, waiting for completion", totalServices))
	local waitStart = os.clock()
	while startCompleted < totalServices do
		task.wait()
	end
	local waitTime = (os.clock() - waitStart) * 1000
	bench_detail(string.format("All start() completed, wait loop took %.2f ms", waitTime))
	bench_stop()
	bench_stop()
end

local function replicateFiles(): boolean
	bench_start("replicateFiles")
	if not Vultar.IsServer then
		bench_detail("Not server, skipping replication")
		bench_stop()
		return true
	end

	local ReplicatorService = services["ReplicatorService"]
	if not ReplicatorService then
		bench_detail("ReplicatorService not found!")
		warn("[Vultar] ReplicatorService not found - replication skipped")
		loadHealth.replicationSuccess = false
		bench_stop()
		return false
	end

	bench_detail("Setting MainModule reference")
	ReplicatorService:SetMainModule(script)

	bench_start("Replicate")
	local success, stats = ReplicatorService:Replicate()
	bench_stop()

	loadHealth.replicationSuccess = success
	if not success then
		warn(`[Vultar] Replication FAILED - {stats.Failed} items failed`)
		for _, err in stats.Errors or {} do
			warn(`[Vultar] Replication error: {err}`)
		end
	end

	bench_detail(string.format("Replication %s", if success then "SUCCESS" else "FAILED"))
	bench_stop()
	return success
end

local function setupForClients(): ()
	bench_start("setupForClients")
	if not Vultar.IsServer then
		bench_detail("Not server, skipping")
		bench_stop()
		return
	end

	local serverFolder = script:FindFirstChild("Server")
	if serverFolder then
		bench_detail("Destroying Server folder for client security")
		bench_start("DestroyServerFolder")
		serverFolder:Destroy()
		bench_stop()
	else
		bench_detail("No Server folder to destroy")
	end

	bench_stop()
end

local function setLoadError(message: string)
	loadHealth.criticalError = message
	if Vultar.IsServer then
		script:SetAttribute("LoadError", message)
		script:SetAttribute("Ready", false)
	end
end

local function getHealthSummary(): string
	local issues = {}
	if loadHealth.servicesFailed > 0 then
		table.insert(issues, `{loadHealth.servicesFailed} services failed to load`)
	end
	if #loadHealth.initFailed > 0 then
		table.insert(issues, `{#loadHealth.initFailed} services failed init()`)
	end
	if #loadHealth.startFailed > 0 then
		table.insert(issues, `{#loadHealth.startFailed} services failed start()`)
	end
	if not loadHealth.replicationSuccess then
		table.insert(issues, "replication failed")
	end
	if loadHealth.adminLoaded == false then
		table.insert(issues, "admin failed to load/init")
	end
	if #issues == 0 then
		return "healthy"
	end
	return table.concat(issues, ", ")
end

local function loadCmdr(): boolean
	bench_start("LoadCmdr")
	local CMDR_ASSET_ID = 0
	local target: any = CMDR_ASSET_ID
	local sourceDesc = `Asset ID: {CMDR_ASSET_ID}`

	if RunService:IsStudio() then
		local localCmdr = ServerStorage:FindFirstChild("AdminModule")
		if localCmdr then
			target = localCmdr
			sourceDesc = `local instance ({localCmdr:GetFullName()})`
		end
	end

	local ok, cmdr = pcall(require, target)
	if not ok or typeof(cmdr) ~= "table" or typeof(cmdr.Init) ~= "function" then
		warn(`[Vultar] [CMDR LOADER] Couldn't load Cmdr from {sourceDesc}: {cmdr}`)
		bench_stop()
		loadHealth.adminLoaded = false
		return false
	end

	local initOk, initResult = pcall(cmdr.Init)
	if not initOk or initResult ~= true then
		warn(`[Vultar] [CMDR LOADER] Cmdr Init() failed from {sourceDesc}: {initResult}`)
		bench_stop()
		loadHealth.adminLoaded = false
		return false
	end

	print(`[Vultar] [CMDR LOADER] Cmdr loaded from {sourceDesc}`)
	bench_stop()
	loadHealth.adminLoaded = true
	return true
end

local ANTICHEAT_ASSET_ID = 0

local function loadAntiCheat(): ()
	local target: any = ANTICHEAT_ASSET_ID
	if RunService:IsStudio() then
		local localModule = ServerStorage:FindFirstChild("AntiCheatModule")
		if localModule then
			target = localModule
		end
	end
	if target == 0 then
		return
	end

	local ok, antiCheat = pcall(require, target)
	if not ok or typeof(antiCheat) ~= "table" or typeof(antiCheat.Init) ~= "function" then
		warn(`[Vultar] [AC LOADER] Couldn't load the anti-cheat module: {antiCheat}`)
		return
	end

	local initOk, initResult = pcall(antiCheat.Init, script)
	if not initOk or initResult ~= true then
		warn(`[Vultar] [AC LOADER] Anti-cheat Init() failed: {initResult}`)
		return
	end
	Vultar.AntiCheat = antiCheat
end

local OWN_HIGHLIGHT_NAMES: { [string]: true } = {
	TeamESPHighlight = true,
	PingHighlight = true,
	SpawnHighlight = true,
}

local function removeMapHighlights(): ()
	local removed = 0
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("Highlight") and not OWN_HIGHLIGHT_NAMES[descendant.Name] then
			print(`[Vultar] Removing Highlight {descendant:GetFullName()}`)
			descendant:Destroy()
			removed += 1
		end
	end
	if removed > 0 then
		print(`[Vultar] Removed {removed} Highlight(s) from workspace`)
	end
end

export type LoadConfig = {
	disabledServices: { string }?,
}

function Vultar.Load(config: LoadConfig?): boolean
	if Vultar.IsLoaded or isLoading then
		return Vultar.IsLoaded
	end

	if Vultar.IsServer then
		local existingModule = ReplicatedStorage:FindFirstChild("MainModule")
		if existingModule and existingModule ~= script then
			setLoadError("Duplicate MainModule detected")
			return false
		end
	end

	table.clear(disabledServicesSet)
	if config and config.disabledServices then
		for _, name in config.disabledServices do
			disabledServicesSet[name] = true
		end
	end

	isLoading = true

	loadHealth = {
		servicesLoaded = 0,
		servicesFailed = 0,
		servicesTotal = 0,
		failedServices = {},
		initFailed = {},
		startFailed = {},
		replicationSuccess = true,
		adminLoaded = nil,
		criticalError = nil,
	}

	local b = getBenchmark()
	if b then
		b.init()
	end

	bench_start("Vultar.Load")

	print(`[Vultar] Git head: {Vultar.Version}`)
	bench_mark("Version printed")

	if Vultar.IsServer then
		task.spawn(loadCmdr)
		task.spawn(removeMapHighlights)
	end

	if Vultar.IsClient then
		bench_start("AssetPreloaderSpawn")
		task.spawn(function()
			bench_start("AssetPreloader")
			local success, AssetPreloader = pcall(require, script.Shared.Utils.Loading.AssetPreloader)
			if success and AssetPreloader then
				bench_detail("AssetPreloader module loaded")
				bench_start("preloadCriticalAssets")
				AssetPreloader.preloadCriticalAssets()
				bench_stop()
			else
				bench_detail("AssetPreloader not found or failed to load")
			end
			bench_stop()
		end)
		bench_stop()
	end

	bench_checkpoint("Loading server services")
	local serverFolder = getServer()
	if Vultar.IsServer and serverFolder then
		bench_start("RequireBlinkServer")
		pcall(require, script.Shared.Network.Generated.Server)
		bench_stop()
		bench_start("LoadServerServices")
		loadServices(serverFolder)
		bench_stop()
	end

	bench_checkpoint("Setting up for clients")
	if Vultar.IsServer then
		setupForClients()
	end

	bench_checkpoint("Loading client services")
	local clientFolder = getClient()
	if Vultar.IsClient and clientFolder then
		pcall(require, script.Shared.Network.Generated.Client)
		bench_start("LoadClientServices")
		loadServices(clientFolder)
		bench_stop()
	end

	bench_checkpoint("Replicating files")
	if Vultar.IsServer then
		replicateFiles()
	end

	bench_checkpoint("Starting all services")
	startServices()

	if Vultar.IsServer then
		task.spawn(loadAntiCheat)
	end

	local healthSummary = getHealthSummary()
	local loadSuccessful = loadHealth.criticalError == nil

	if Vultar.IsServer then
		if healthSummary == "healthy" then
			print(`[Vultar] Load complete - all services healthy ({loadHealth.servicesLoaded}/{loadHealth.servicesTotal} services)`)
		else
			warn(`[Vultar] Load complete with issues: {healthSummary}`)
			script:SetAttribute("LoadWarnings", healthSummary)
		end
	end

	Vultar.IsLoaded = true
	isLoading = false

	if Vultar.IsServer then
		if loadSuccessful then
			script:SetAttribute("Ready", true)
			script:SetAttribute("LoadHealth", healthSummary)
		else
			setLoadError(loadHealth.criticalError or "Unknown critical error")
		end
	end

	bench_stop()
	bench_mark("Load complete")
	bench_report()

	return loadSuccessful
end

function Vultar.GetService(serviceName: string): any?
	return services[serviceName]
end

function Vultar.GetHealth(): {
	servicesLoaded: number,
	servicesFailed: number,
	servicesTotal: number,
	failedServices: { string },
	initFailed: { string },
	startFailed: { string },
	replicationSuccess: boolean,
	adminLoaded: boolean?,
	criticalError: string?,
}
	return loadHealth
end

function Vultar.GetService(name: string): any?
	return ServiceRegistry.get(name)
end

function Vultar.GetShared(): Folder
	return getShared()
end

function Vultar.GetConstants(): any
	local shared = getShared()
	local lib = shared:FindFirstChild("Lib")
	if lib then
		local constants = lib:FindFirstChild("Constants")
		if constants and constants:IsA("ModuleScript") then
			local success, result = safeRequire(constants, "Constants")
			if success then
				return result
			end
		end
	end
	return nil
end

local function getNetworkCore(): any?
	local shared = getShared()
	local network = shared:FindFirstChild("Network")
	if not network then
		return nil
	end
	local core = network:FindFirstChild("Core")
	if not core or not core:IsA("ModuleScript") then
		return nil
	end
	local success, result = safeRequire(core, "Network.Core")
	if success then
		return result
	end
	return nil
end

function Vultar.DebugNetwork(enable: boolean?, logEachCall: boolean?): ()
	local core = getNetworkCore()
	if not core then
		return
	end
	core.setDebug(enable ~= false, logEachCall or false)
	if enable ~= false then
		core.printDebugStats()
	end
end

function Vultar.StartNetworkLogging(interval: number?): ()
	local core = getNetworkCore()
	if not core then
		return
	end
	core.setDebug(true, true)
	core.startPeriodicLogging(interval)
end

function Vultar.StopNetworkLogging(): ()
	local core = getNetworkCore()
	if not core then
		return
	end
	core.stopPeriodicLogging()
	core.setDebug(false, false)
end

return Vultar
