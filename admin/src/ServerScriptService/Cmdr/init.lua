local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Package = {}

local initialized = false

local function giveClient(player: Player)
	local playerGui = player:WaitForChild("PlayerGui", 30)
	if not playerGui then
		return
	end

	local holder = Instance.new("ScreenGui")
	holder.Name = "CmdrClient"
	holder.ResetOnSpawn = false
	script.Client:Clone().Parent = holder
	holder.Parent = playerGui
end

function Package.Init(): boolean
	if initialized then
		return true
	end
	initialized = true

	if not (script:IsDescendantOf(ServerScriptService) or script:IsDescendantOf(ServerStorage)) then
		pcall(function()
			script.Parent = ServerStorage
		end)
	end

	local Cmdr = require(script.Library)
	local Moderation = require(script.Moderation)
	local Ranks = require(script.Ranks)

	Cmdr.Registry:RegisterHooksIn(script.Shared)
	Cmdr.Registry:RegisterDefaultCommands()
	Cmdr.Registry:RegisterCommandsIn(script.Commands)

	Cmdr._remoteFunction.OnServerInvoke = function(player: Player, text: any, options: any)
		if Ranks.Get(player) == 0 then
			return "You don't have permission to use Cmdr."
		end
		if typeof(text) ~= "string" or #text > 10000 then
			return "Input too long"
		end
		return Cmdr.Dispatcher:EvaluateAndRun(text, player, if typeof(options) == "table" then options else nil)
	end

	Ranks.Start()
	Moderation.Start()

	Players.PlayerAdded:Connect(giveClient)
	for _, player in Players:GetPlayers() do
		task.spawn(giveClient, player)
	end

	return true
end

return Package
