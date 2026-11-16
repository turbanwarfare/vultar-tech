--!strict
--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "VultarScreenWatch"
local LOAD_TIMEOUT = 120

local ScreenWatchService = {}
ScreenWatchService.Name = "ScreenWatchService"

local impl: any = nil

function ScreenWatchService:StartWatch(targetUserId: number): ()
	if impl then
		impl:StartWatch(targetUserId)
	end
end

function ScreenWatchService:StopWatch(): ()
	if impl then
		impl:StopWatch()
	end
end

function ScreenWatchService:IsWatching(): boolean
	return impl ~= nil and impl:IsWatching() == true
end

function ScreenWatchService:GetTargetUserId(): number
	return if impl then impl:GetTargetUserId() else 0
end

function ScreenWatchService:GetTargetPlayer(): Player?
	return if impl then impl:GetTargetPlayer() else nil
end

function ScreenWatchService:GetESPMode(): string
	return if impl then impl:GetESPMode() else "TEAM"
end

function ScreenWatchService:CycleESPMode(): ()
	if impl then
		impl:CycleESPMode()
	end
end

function ScreenWatchService:OpenSelectMenu(): ()
	if impl then
		impl:OpenSelectMenu()
	end
end

function ScreenWatchService:CloseSelectMenu(): ()
	if impl then
		impl:CloseSelectMenu()
	end
end

function ScreenWatchService:ExportLogs(): ()
	if impl then
		impl:ExportLogs()
	end
end

function ScreenWatchService:init(): () end

function ScreenWatchService:start(): ()
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, LOAD_TIMEOUT)
		if not folder then
			warn("[ScreenWatch] Client module never arrived from the server")
			return
		end
		local expected = folder:GetAttribute("DescendantCount")
		if type(expected) == "number" then
			local arrived = #folder:GetDescendants()
			if arrived < expected then
				local deadline = os.clock() + LOAD_TIMEOUT
				local added = folder.DescendantAdded:Connect(function()
					arrived += 1
				end)
				while arrived < expected and os.clock() < deadline do
					task.wait(0.1)
				end
				added:Disconnect()
			end
		end
		local clientModule = folder:WaitForChild("Client", 10)
		if not clientModule or not clientModule:IsA("ModuleScript") then
			warn("[ScreenWatch] Client module never arrived from the server")
			return
		end
		local ok, module = pcall(require, clientModule)
		if not ok then
			warn("[ScreenWatch] Failed to load client module:", module)
			return
		end
		local started, err = pcall(function()
			module:init()
			module:start()
		end)
		if not started then
			warn("[ScreenWatch] Client module failed to start:", err)
			return
		end
		impl = module
	end)
end

function ScreenWatchService:Cleanup(): ()
	local current = impl
	impl = nil
	if current then
		current:Cleanup()
	end
end

return ScreenWatchService
