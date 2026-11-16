local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local CAN_SEE_CACHE_TIME = 60

local canSeeCache: { [string]: { allowed: boolean, at: number } } = {}

local Filter = {}

function Filter.ForEveryoneAsync(text: string, fromUserId: number): string?
	local cleaned = text:gsub("%c", " ")
	local ok, result = pcall(function()
		local filterResult = TextService:FilterStringAsync(cleaned, fromUserId, Enum.TextFilterContext.PublicChat)
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		warn(`[Cmdr] Couldn't filter text from {fromUserId}: {result}`)
		return nil
	end
	return result
end

function Filter.CanSeeAsync(fromUserId: number, toUserId: number): boolean
	if fromUserId == toUserId then
		return true
	end

	local key = `{fromUserId}:{toUserId}`
	local cached = canSeeCache[key]
	if cached and os.clock() - cached.at < CAN_SEE_CACHE_TIME then
		return cached.allowed
	end

	local ok, canChat = pcall(TextChatService.CanUserChatAsync, TextChatService, toUserId)
	if not ok then
		return false
	end

	local allowed = canChat == true
	if allowed then
		local pairOk, canPair = pcall(TextChatService.CanUsersChatAsync, TextChatService, fromUserId, toUserId)
		if not pairOk then
			return false
		end
		allowed = canPair == true
	end

	canSeeCache[key] = { allowed = allowed, at = os.clock() }
	return allowed
end

function Filter.ForEachViewerAsync(fromUserId: number, players: { Player }, show: (Player) -> ()): number
	local remaining = #players
	local hidden = 0
	local finished = Instance.new("BindableEvent")

	for _, player in players do
		task.spawn(function()
			if Filter.CanSeeAsync(fromUserId, player.UserId) then
				pcall(show, player)
			else
				hidden += 1
			end
			remaining -= 1
			if remaining == 0 then
				finished:Fire()
			end
		end)
	end

	if remaining > 0 then
		finished.Event:Wait()
	end
	finished:Destroy()
	return hidden
end

return Filter
