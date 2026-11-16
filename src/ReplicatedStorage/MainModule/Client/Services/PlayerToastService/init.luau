--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local PlayerToast = require(MainModule.Client.Components.PlayerToast)
local PlayerGuiHelper = require(MainModule.Client.Utils.UI.PlayerGuiHelper)
local Network = require(MainModule.Shared.Network)

type ToastType = PlayerToast.ToastType
type ToastData = PlayerToast.ToastData

local PlayerToastService = {}
PlayerToastService.Name = "PlayerToastService"

local TOAST_DURATION = 3
local MAX_TOASTS = 5

local isInitialized = false
local hasDeployed = false
local toastRemovalThreads: { [string]: thread } = {}
local hudScope: any = nil
local hudGui: ScreenGui? = nil
local hudVisible: any = nil
local toastsState: any = nil
local connections: { RBXScriptConnection } = {}
local testConnection: RBXScriptConnection? = nil

local function generateId(): string
	return HttpService:GenerateGUID(false)
end

local function executeToastRemoval(toastId: string): ()
	toastRemovalThreads[toastId] = nil
	PlayerToastService:RemoveToast(toastId)
end

function PlayerToastService:AddToast(username: string, userId: number, toastType: ToastType): ()
	if not toastsState or not hasDeployed then
		return
	end

	local toast: ToastData = {
		id = generateId(),
		username = username,
		userId = userId,
		toastType = toastType,
		timestamp = os.clock(),
	}

	local currentToasts = Fusion.peek(toastsState)
	local newToasts = { toast }

	for i, t in currentToasts do
		if i < MAX_TOASTS then
			table.insert(newToasts, t)
		end
	end

	toastsState:set(newToasts)

	toastRemovalThreads[toast.id] = task.delay(TOAST_DURATION, executeToastRemoval, toast.id)
end

function PlayerToastService:RemoveToast(toastId: string): ()
	if not toastsState then
		return
	end

	local currentToasts = Fusion.peek(toastsState)
	local newToasts = {}

	for _, t in currentToasts do
		if t.id ~= toastId then
			table.insert(newToasts, t)
		end
	end

	toastsState:set(newToasts)
end

function PlayerToastService:ClearAll(): ()
	if toastsState then
		toastsState:set({})
	end
end

function PlayerToastService:StartTest(): ()
	if testConnection then
		return
	end

	local testUserId = 1
	local testUsername = "Player"
	local isJoin = true

	self:AddToast(testUsername, testUserId, "join")

	local elapsed = 0
	testConnection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 1 then
			elapsed = 0
			isJoin = not isJoin
			self:AddToast(testUsername, testUserId, if isJoin then "join" else "leave")
		end
	end)
end

function PlayerToastService:StopTest(): ()
	if testConnection then
		testConnection:Disconnect()
		testConnection = nil
	end
end

function PlayerToastService:init(): ()
	hudScope = Fusion.scoped(Fusion)
	hudVisible = hudScope:Value(false)
	toastsState = hudScope:Value({} :: { ToastData })

	hudGui = PlayerToast(hudScope, {
		Toasts = toastsState,
		Visible = hudVisible,
	})

	local playerGui = PlayerGuiHelper.waitForPlayerGui()
	if playerGui and hudGui then
		hudGui.Parent = playerGui
	end

	isInitialized = true
end

function PlayerToastService:start(): ()
	if not isInitialized then
		self:init()
	end

	table.insert(connections, Network.Deploy.onDeployComplete(function()
		hasDeployed = true
		if hudVisible then
			hudVisible:set(true)
		end
	end))

	table.insert(connections, Players.PlayerAdded:Connect(function(player)
		if player ~= LocalPlayer then
			self:AddToast(player.Name, player.UserId, "join")
		end
	end))

	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		if player ~= LocalPlayer then
			self:AddToast(player.Name, player.UserId, "leave")
		end
	end))
end

function PlayerToastService:Cleanup(): ()
	self:StopTest()

	for toastId, thread in toastRemovalThreads do
		task.cancel(thread)
		toastRemovalThreads[toastId] = nil
	end

	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)

	if hudScope then
		hudScope:doCleanup()
		hudScope = nil
		hudGui = nil
		hudVisible = nil
		toastsState = nil
	end

	isInitialized = false
	hasDeployed = false
end

return PlayerToastService
