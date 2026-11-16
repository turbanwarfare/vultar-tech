--!strict
--!native
--!optimize 2

local HttpService = game:GetService("HttpService")

local MainModule = script.Parent.Parent.Parent.Parent
local Types = require(MainModule.Shared.Network.EventCosmetics.Types)

export type EventCosmeticData = Types.EventCosmeticData
export type FacilityBanData = Types.FacilityBanData
export type RecordingPolicyData = Types.RecordingPolicyData
export type UserGameState = Types.UserGameState

local EventCosmeticsAPI = {}

local API_BASE_URL = "REPLACE_WITH_YOUR_API_URL"
local API_KEY = "REPLACE_WITH_YOUR_API_KEY"
local CACHE_DURATION = 300
local MAX_CACHE_SIZE = 200

local cosmeticsCache: { [string]: { data: EventCosmeticData?, timestamp: number } } = {}
local cacheOrder: { string } = {}

local function request(options: {
	Url: string,
	Method: string,
	Body: string?,
	Headers: { [string]: string },
}): { Success: boolean, Body: string?, StatusCode: number? }?
	local success, result = pcall(function()
		return HttpService:RequestAsync(options)
	end)

	if not success then
		return nil
	end

	return result
end

local function evictEntry(): ()
	local count = #cacheOrder
	if count > 0 then
		local evictedId = cacheOrder[1]
		if count > 1 then
			cacheOrder[1] = cacheOrder[count]
		end
		cacheOrder[count] = nil
		if evictedId then
			cosmeticsCache[evictedId] = nil
		end
	end
end

function EventCosmeticsAPI.getEventCosmetics(userId: number): EventCosmeticData?
	local userIdStr = tostring(userId)
	local cached = cosmeticsCache[userIdStr]
	if cached and (os.time() - cached.timestamp) < CACHE_DURATION then
		return cached.data
	end

	local response = request({
		Url = API_BASE_URL .. "/api/roblox/events/cosmetics/" .. userIdStr,
		Method = "GET",
		Headers = {
			["Content-Type"] = "application/json",
			["Accept"] = "application/json",
			["x-api-key"] = API_KEY,
			["Cache-Control"] = "no-cache",
		},
	})

	if response and response.Success and response.Body then
		local success, data = pcall(function()
			return HttpService:JSONDecode(response.Body)
		end)

		if success and data then
			if not cosmeticsCache[userIdStr] then
				if #cacheOrder >= MAX_CACHE_SIZE then
					evictEntry()
				end
				table.insert(cacheOrder, userIdStr)
			end
			cosmeticsCache[userIdStr] = {
				data = data :: EventCosmeticData,
				timestamp = os.time(),
			}
			return data :: EventCosmeticData
		end
	end

	return nil
end

function EventCosmeticsAPI.getUserGameState(userId: number): UserGameState?
	local userIdStr = tostring(userId)

	local response = request({
		Url = API_BASE_URL .. "/api/roblox/user/" .. userIdStr .. "/user-game-state",
		Method = "GET",
		Headers = {
			["Content-Type"] = "application/json",
			["Accept"] = "application/json",
			["x-api-key"] = API_KEY,
		},
	})

	if response and response.Success and response.Body then
		local success, data = pcall(function()
			return HttpService:JSONDecode(response.Body)
		end)

		if success and data then
			return data :: UserGameState
		end
	end

	return nil
end

function EventCosmeticsAPI.clearCache(userId: number): ()
	local userIdStr = tostring(userId)
	cosmeticsCache[userIdStr] = nil
	local count = #cacheOrder
	for i = count, 1, -1 do
		if cacheOrder[i] == userIdStr then
			if i < count then
				cacheOrder[i] = cacheOrder[count]
			end
			cacheOrder[count] = nil
			break
		end
	end
end

return EventCosmeticsAPI
