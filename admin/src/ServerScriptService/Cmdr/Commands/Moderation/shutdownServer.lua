local Players = game:GetService("Players")

local Package = script:FindFirstAncestor("Commands").Parent
local Config = require(Package.Config)
local Moderation = require(Package.Moderation)
local Notify = require(Package.Notify)

return function(context, countdown: number?): string
	if Moderation.IsShuttingDown() then
		return "This server is already shutting down."
	end
	Moderation.StartShutdown()

	local executor = context.Executor
	task.spawn(function()
		if countdown then
			for _, player in Players:GetPlayers() do
				Notify.Banner(player, { Title = "Shutting down", Subtitle = executor.DisplayName, Countdown = countdown })
			end
			task.wait(countdown)
		end
		for _, player in Players:GetPlayers() do
			player:Kick(Config.Messages.Shutdown)
		end
	end)

	return if countdown then `Shutting down in {countdown} seconds.` else "Shutting down."
end
