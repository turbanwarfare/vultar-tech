--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScreenWatch = {}

local FOLDER_NAME = "VultarScreenWatch"
local SERVICE_NAME = "ScreenWatchService"

local server = nil

function ScreenWatch.Init(mainModule: Instance): boolean
	if server then
		return true
	end

	require(script.Shared.Game).set(mainModule)

	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	script.Shared:Clone().Parent = folder
	script.Client:Clone().Parent = folder

	local ok, result = pcall(require, script.Server)
	if not ok then
		warn("[ScreenWatch] Server module failed to load:", result)
		return false
	end

	local registryOk, ServiceRegistry = pcall(require, mainModule.Shared.Utils.Services.ServiceRegistry)
	if registryOk and not ServiceRegistry.isRegistered(SERVICE_NAME) then
		ServiceRegistry.register(SERVICE_NAME, result)
	end

	local startOk, err = pcall(function()
		result:init()
		result:start()
	end)
	if not startOk then
		warn("[ScreenWatch] Server start failed:", err)
		return false
	end

	server = result
	folder:SetAttribute("DescendantCount", #folder:GetDescendants())
	folder.Parent = ReplicatedStorage
	return true
end

function ScreenWatch.GetServer()
	return server
end

return ScreenWatch
