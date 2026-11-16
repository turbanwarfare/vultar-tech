--!strict
--!native
--!optimize 2

local HttpService = game:GetService("HttpService")

local MainModule = script.Parent.Parent.Parent.Parent
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)

local APIClient = {}

local API_KEY = "REPLACE_WITH_YOUR_API_KEY"
local BASE_URL = "REPLACE_WITH_YOUR_API_URL"

local API_ENABLE = true

local fetchErrorLogged: { [number]: boolean } = {}
local pushErrorLogged: { [number]: boolean } = {}

local function httpRequest(options: {
	Url: string,
	Method: string,
	Body: string?,
	Headers: { [string]: string }?,
}): { Success: boolean, Body: string?, StatusCode: number?, Error: string? }
	local success, response = pcall(function()
		return HttpService:RequestAsync(options)
	end)

	if success and response then
		return {
			Success = response.Success,
			Body = response.Body,
			StatusCode = response.StatusCode,
		}
	end

	return { Success = false, Error = tostring(response) }
end

function APIClient.fetch(userId: number): SettingsConfig.SettingsTemplate?
	if not API_ENABLE then
		return nil
	end
	local response = httpRequest({
		Url = `{BASE_URL}/api/roblox/state/{userId}`,
		Method = "GET",
		Headers = {
			["Content-Type"] = "application/json",
			["Accept"] = "application/json",
			["x-api-key"] = API_KEY,
		},
	})

	if not response.Success then
		if not fetchErrorLogged[userId] and response.StatusCode ~= 404 then
			fetchErrorLogged[userId] = true
			warn(`[APIClient] Failed to fetch state for user {userId}: {response.Error or "Unknown error"}`)
		end
		return nil
	end

	if response.StatusCode == 404 then
		return nil
	end

	if response.StatusCode ~= 200 then
		if not fetchErrorLogged[userId] then
			fetchErrorLogged[userId] = true
			warn(`[APIClient] Fetch returned status {response.StatusCode} for user {userId}`)
		end
		return nil
	end

	if not response.Body then
		if not fetchErrorLogged[userId] then
			fetchErrorLogged[userId] = true
			warn(`[APIClient] Fetch returned empty body for user {userId}`)
		end
		return nil
	end

	local decodeSuccess, data = pcall(function()
		return HttpService:JSONDecode(response.Body :: string)
	end)

	if not decodeSuccess then
		if not fetchErrorLogged[userId] then
			fetchErrorLogged[userId] = true
			warn(`[APIClient] Failed to decode state JSON for user {userId}`)
		end
		return nil
	end

	if type(data) ~= "table" or type(data.state) ~= "table" then
		if not fetchErrorLogged[userId] then
			fetchErrorLogged[userId] = true
			warn(`[APIClient] Invalid state data format for user {userId}`)
		end
		return nil
	end

	return data.state :: SettingsConfig.SettingsTemplate
end

function APIClient.push(userId: number, data: SettingsConfig.SettingsTemplate): boolean
	if not API_ENABLE then
		return true
	end
	local wrapped = {
		state = data,
	}

	local encodeSuccess, body = pcall(function()
		return HttpService:JSONEncode(wrapped)
	end)

	if not encodeSuccess then
		if not pushErrorLogged[userId] then
			pushErrorLogged[userId] = true
			warn(`[APIClient] Failed to encode state JSON for user {userId}`)
		end
		return false
	end

	local response = httpRequest({
		Url = `{BASE_URL}/api/roblox/state/{userId}/update`,
		Method = "PUT",
		Body = body,
		Headers = {
			["Content-Type"] = "application/json",
			["Accept"] = "application/json",
			["x-api-key"] = API_KEY,
		},
	})

	if not response.Success then
		if not pushErrorLogged[userId] then
			pushErrorLogged[userId] = true
			warn(`[APIClient] Failed to push state for user {userId}: {response.Error or "Unknown error"}`)
		end
		return false
	end

	if response.StatusCode and response.StatusCode >= 400 then
		if not pushErrorLogged[userId] then
			pushErrorLogged[userId] = true
			warn(`[APIClient] Push returned error status {response.StatusCode} for user {userId}`)
		end
		return false
	end

	return true
end

function APIClient.exportSettings(userId: number, settingsData: { [string]: any }): (boolean, string?)
	if not API_ENABLE then
		return false, nil
	end
	local settingsJson = HttpService:JSONEncode(settingsData)
	local body = HttpService:JSONEncode({
		userId = userId,
		settings = settingsJson,
	})

	local response = httpRequest({
		Url = `{BASE_URL}/api/roblox/settings/sharing/upload`,
		Method = "POST",
		Body = body,
		Headers = {
			["Content-Type"] = "application/json",
			["Accept"] = "application/json",
			["x-api-key"] = API_KEY,
		},
	})

	if response.Success and (response.StatusCode == 200 or response.StatusCode == 201) and response.Body then
		local decodeSuccess, data = pcall(function()
			return HttpService:JSONDecode(response.Body :: string)
		end)

		if decodeSuccess and type(data) == "table" and data.code then
			return true, data.code
		end
	end

	warn(`[APIClient] exportSettings failed - status: {response.StatusCode}, body: {response.Body or response.Error}`)
	return false, nil
end

function APIClient.importSettings(code: string): (boolean, { [string]: any }?)
	if not API_ENABLE then
		return false, nil
	end
	local body = HttpService:JSONEncode({ code = code })

	local response = httpRequest({
		Url = `{BASE_URL}/api/roblox/settings/sharing`,
		Method = "POST",
		Body = body,
		Headers = {
			["Content-Type"] = "application/json",
			["Accept"] = "application/json",
			["x-api-key"] = API_KEY,
		},
	})

	if response.Success and response.StatusCode == 200 and response.Body then
		local decodeSuccess, data = pcall(function()
			return HttpService:JSONDecode(response.Body :: string)
		end)

		if decodeSuccess and type(data) == "table" and data.settings then
			local settingsDecodeSuccess, settingsData = pcall(function()
				return HttpService:JSONDecode(data.settings)
			end)

			if settingsDecodeSuccess and type(settingsData) == "table" then
				return true, settingsData
			end
		end
	end

	warn(`[APIClient] importSettings failed - status: {response.StatusCode}, body: {response.Body or response.Error}`)
	return false, nil
end

function APIClient.clearErrorState(userId: number): ()
	fetchErrorLogged[userId] = nil
	pushErrorLogged[userId] = nil
end

return APIClient
