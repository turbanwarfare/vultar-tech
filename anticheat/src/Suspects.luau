--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local Auth = require(script.Parent.ScreenWatch.Auth)

local Suspects = {}

local remote: RemoteEvent? = nil
local screenWatchService = nil
local preBuffered: { [number]: number } = {}
local lastPushedCount = 0

local function isAuthorized(player: Player): boolean
	return Auth.isAuthorized(player)
end

function Suspects.init(vultar): ()
	screenWatchService = vultar.GetService("ScreenWatchService")

	local existing = ReplicatedStorage:FindFirstChild(Config.SuspectsRemoteName)
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
	else
		local event = Instance.new("RemoteEvent")
		event.Name = Config.SuspectsRemoteName
		event.Parent = ReplicatedStorage
		remote = event
	end

end

function Suspects.push(list): ()
	local event = remote
	if not event then
		return
	end
	if #list == 0 and lastPushedCount == 0 then
		return
	end
	lastPushedCount = #list
	for _, player in Players:GetPlayers() do
		if isAuthorized(player) then
			event:FireClient(player, list)
		end
	end
end

function Suspects.syncPreBuffer(list): ()
	local service = screenWatchService
	if not Config.PreBufferFlagged or not service or typeof(service.SetPreBuffer) ~= "function" then
		return
	end
	local now = os.clock()
	for _, suspect in list do
		if not preBuffered[suspect.userId] then
			pcall(service.SetPreBuffer, service, suspect.userId, true)
		end
		preBuffered[suspect.userId] = now
	end
	for userId, lastSeen in preBuffered do
		if now - lastSeen > Config.PreBufferGraceSeconds or not Players:GetPlayerByUserId(userId) then
			preBuffered[userId] = nil
			pcall(service.SetPreBuffer, service, userId, false)
		end
	end
end

function Suspects.destroy(): ()
	local service = screenWatchService
	if service and typeof(service.SetPreBuffer) == "function" then
		for userId in preBuffered do
			pcall(service.SetPreBuffer, service, userId, false)
		end
	end
	table.clear(preBuffered)
	if remote then
		remote:Destroy()
		remote = nil
	end
end

return Suspects
