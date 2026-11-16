--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local SessionStats = require(MainModule.Client.Components.SessionStats)
local Network = require(MainModule.Shared.Network)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)

local SessionStatsService = {}
SessionStatsService.Name = "SessionStatsService"

local isInitialized = false

local hudScope: any = nil
local hudGui: ScreenGui? = nil

local deployConnection: RBXScriptConnection? = nil

local function ensureHUDCreated(): ()
	if hudGui then
		return
	end

	hudScope = Fusion.scoped(Fusion)
	hudGui = SessionStats(hudScope)

	local playerGui = PlayerGuiHelper.waitForPlayerGui()
	if playerGui then
		hudGui.Parent = playerGui
	end
end

local function onDeployComplete(): ()
	ensureHUDCreated()
end

function SessionStatsService:init(): ()
	isInitialized = true
end

function SessionStatsService:start(): ()
	if not isInitialized then
		self:init()
	end

	deployConnection = Network.Deploy.onDeployComplete(onDeployComplete)
end

function SessionStatsService:Cleanup(): ()
	if deployConnection then
		deployConnection:Disconnect()
		deployConnection = nil
	end

	if hudScope then
		hudScope:doCleanup()
		hudScope = nil
		hudGui = nil
	end

	isInitialized = false
end

return SessionStatsService
