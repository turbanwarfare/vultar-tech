local Players = game:GetService("Players")

local Config = require(script.Parent.Config)
local Filter = require(script.Parent.Filter)

local serverBans: { [number]: boolean } = {}
local shuttingDown = false

local Moderation = {}

function Moderation.FilterReasonAsync(executor: Player, reason: string?): (string?, string?)
	if not reason or not reason:match("%S") then
		return nil, nil
	end
	if (utf8.len(reason) or #reason) > Config.MaxTextLength then
		return nil, `Keep the reason under {Config.MaxTextLength} characters.`
	end

	local filtered = Filter.ForEveryoneAsync(reason, executor.UserId)
	if not filtered then
		return nil, "Couldn't filter the reason. Try again."
	end
	return filtered, nil
end

function Moderation.KickAsync(executor: Player, target: Player, message: string, filteredReason: string?)
	if filteredReason and Filter.CanSeeAsync(executor.UserId, target.UserId) then
		message ..= `\nReason: {filteredReason}`
	end
	target:Kick(message)
end

function Moderation.ServerBan(userId: number)
	serverBans[userId] = true
end

function Moderation.RemoveServerBan(userId: number): boolean
	local wasBanned = serverBans[userId] == true
	serverBans[userId] = nil
	return wasBanned
end

function Moderation.IsShuttingDown(): boolean
	return shuttingDown
end

function Moderation.StartShutdown()
	shuttingDown = true
end

function Moderation.Start()
	Players.PlayerAdded:Connect(function(player)
		if shuttingDown then
			player:Kick(Config.Messages.Shutdown)
		elseif serverBans[player.UserId] then
			player:Kick(Config.Messages.ServerBan)
		end
	end)
end

return Moderation
