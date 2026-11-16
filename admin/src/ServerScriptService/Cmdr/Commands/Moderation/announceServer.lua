local Players = game:GetService("Players")

local Package = script:FindFirstAncestor("Commands").Parent
local Config = require(Package.Config)
local Filter = require(Package.Filter)
local Notify = require(Package.Notify)
local Ranks = require(Package.Ranks)

return function(context, message: string): string
	local executor = context.Executor
	if not message:match("%S") then
		return "Type a message to announce."
	end
	if (utf8.len(message) or #message) > Config.MaxTextLength then
		return `Keep it under {Config.MaxTextLength} characters.`
	end

	local filtered = Filter.ForEveryoneAsync(message, executor.UserId)
	if not filtered then
		return "Couldn't filter your message. Try again."
	end

	local banner = {
		Title = Ranks.GetName(Ranks.Get(executor)),
		Subtitle = executor.DisplayName,
		Text = filtered,
		Icon = "avatar",
		UserId = executor.UserId,
	}
	local hidden = Filter.ForEachViewerAsync(executor.UserId, Players:GetPlayers(), function(player)
		Notify.Banner(player, banner)
	end)

	if hidden > 0 then
		return `Announced. {hidden} player(s) can't see it because of their chat settings.`
	end
	return "Announced."
end
