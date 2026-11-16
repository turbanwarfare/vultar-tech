--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Maps = require(MainModule.Shared.Config.Maps)

local MapScriptService = {}
MapScriptService.Name = "MapScriptService"

type MapScript = {
	Name: string,
	init: ((self: any) -> ())?,
	start: ((self: any) -> ())?,
	Cleanup: ((self: any) -> ())?,
}

local activeScript: MapScript? = nil
local mapName: string? = nil

local function findMapScriptsFolder(): Folder?
	local serverFolder = MainModule:FindFirstChild("Server")
	if not serverFolder then
		return nil
	end
	return serverFolder:FindFirstChild("MapScripts") :: Folder?
end

local function loadMapScript(name: string): MapScript?
	local folder = findMapScriptsFolder()
	if not folder then
		return nil
	end

	local mapFolder = folder:FindFirstChild(name)
	if not mapFolder then
		return nil
	end

	local initModule = if mapFolder:IsA("ModuleScript") then mapFolder else mapFolder:FindFirstChild("init")
	if not initModule or not initModule:IsA("ModuleScript") then
		return nil
	end

	local success, result = pcall(require, initModule)
	if not success then
		warn(`[MapScriptService] Failed to load {name}: {result}`)
		return nil
	end

	return result :: MapScript
end

function MapScriptService:init(): ()
	mapName = Maps.getMapName()
	if not mapName then
		return
	end

	activeScript = loadMapScript(mapName)
	if not activeScript then
		return
	end

	if activeScript.init then
		local success, err = pcall(activeScript.init :: any, activeScript)
		if not success then
			warn(`[MapScriptService] init failed for {mapName}: {err}`)
			activeScript = nil
		end
	end
end

function MapScriptService:start(): ()
	if not activeScript or not activeScript.start then
		return
	end

	local success, err = pcall(activeScript.start :: any, activeScript)
	if not success then
		warn(`[MapScriptService] start failed for {mapName}: {err}`)
	end
end

function MapScriptService:Cleanup(): ()
	if not activeScript or not activeScript.Cleanup then
		activeScript = nil
		return
	end

	local success, err = pcall(activeScript.Cleanup :: any, activeScript)
	if not success then
		warn(`[MapScriptService] cleanup failed for {mapName}: {err}`)
	end

	activeScript = nil
end

return MapScriptService
