--!strict
--!native
--!optimize 2

local HttpService = game:GetService("HttpService")

export type Profile = {
	credits: number,
	unlocks: { string },
}

export type CrateOpenRequest = {
	txId: string,
	crateId: string,
	amount: number,
	cost: number,
	refund: number,
	unlocks: { string },
}

export type CrateOpenError = "insufficient" | "unavailable"

local VultarApi = {}

local BASE_URL = "REPLACE_WITH_YOUR_API_URL"
local SECRET_NAME = "GameApiKey"
local MAX_ATTEMPTS = 3

local authHeader: any = nil
local authUnavailable = false

local function getAuthHeader(): any
	if authHeader ~= nil or authUnavailable then
		return authHeader
	end

	local ok, secret = pcall(function()
		return HttpService:GetSecret(SECRET_NAME)
	end)
	if not ok then
		authUnavailable = true
		warn(`[VultarApi] Experience secret "{SECRET_NAME}" is missing; credits and crates are disabled`)
		return nil
	end

	authHeader = secret:AddPrefix("Bearer ")
	return authHeader
end

function VultarApi.isAvailable(): boolean
	return getAuthHeader() ~= nil
end

local function request(method: string, path: string, body: { [string]: any }?): (number, any)
	local auth = getAuthHeader()
	if auth == nil then
		return 0, nil
	end

	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = BASE_URL .. path,
			Method = method,
			Headers = {
				Authorization = auth,
				["Content-Type"] = "application/json",
			} :: any,
			Body = if body then HttpService:JSONEncode(body) else nil,
		})
	end)
	if not ok then
		warn(`[VultarApi] {method} {path} failed: {response}`)
		return 0, nil
	end

	local decodedOk, decoded = pcall(function()
		return HttpService:JSONDecode(response.Body)
	end)
	return response.StatusCode, if decodedOk then decoded else nil
end

local function requestWithRetry(method: string, path: string, body: { [string]: any }?): (number, any)
	local status, data = 0, nil
	for attempt = 1, MAX_ATTEMPTS do
		status, data = request(method, path, body)
		local retryable = status == 0 or status == 429 or status >= 500
		if not retryable or authUnavailable then
			break
		end
		if attempt < MAX_ATTEMPTS then
			task.wait(attempt)
		end
	end
	return status, data
end

local function readCredits(status: number, data: any): number?
	if status == 200 and typeof(data) == "table" and typeof(data.credits) == "number" then
		return data.credits
	end
	return nil
end

local function failureReason(status: number, data: any): string
	if status == 0 then
		return "no response from API"
	end
	if typeof(data) == "table" and typeof(data.error) == "string" then
		return `{data.error} (HTTP {status})`
	end
	return `HTTP {status}`
end

function VultarApi.getProfile(userId: number): Profile?
	local status, data = requestWithRetry("GET", `/v1/players/{userId}`)
	if status ~= 200 or typeof(data) ~= "table" or typeof(data.credits) ~= "number" or typeof(data.unlocks) ~= "table" then
		warn(`[VultarApi] Could not load profile for {userId} (HTTP {status})`)
		return nil
	end

	local unlocks: { string } = {}
	for _, itemId in data.unlocks do
		if typeof(itemId) == "string" then
			table.insert(unlocks, itemId)
		end
	end

	return { credits = data.credits, unlocks = unlocks }
end

function VultarApi.recordPurchase(userId: number, purchaseId: string, credits: number, productId: number): (number?, string?)
	local status, data = requestWithRetry("POST", `/v1/players/{userId}/purchase`, {
		txId = purchaseId,
		credits = credits,
		productId = productId,
	})
	local balance = readCredits(status, data)
	if balance then
		return balance, nil
	end
	warn(`[VultarApi] Purchase {purchaseId} for {userId} not recorded (HTTP {status})`)
	return nil, failureReason(status, data)
end

export type MatchRewardRequest = {
	txId: string,
	credits: number,
	map: string,
	win: boolean,
	private: boolean,
}

function VultarApi.recordMatchReward(userId: number, rewardRequest: MatchRewardRequest): (number?, string?)
	local status, data = requestWithRetry("POST", `/v1/players/{userId}/match-reward`, rewardRequest :: any)
	local balance = readCredits(status, data)
	if balance then
		return balance, nil
	end
	if status ~= 403 then
		warn(`[VultarApi] Match reward {rewardRequest.txId} for {userId} not recorded (HTTP {status})`)
	end
	return nil, failureReason(status, data)
end

function VultarApi.openCrate(userId: number, crateRequest: CrateOpenRequest): (number?, CrateOpenError?)
	local status, data = requestWithRetry("POST", `/v1/players/{userId}/crate-open`, crateRequest :: any)
	local balance = readCredits(status, data)
	if balance then
		return balance, nil
	end
	if status == 409 then
		return nil, "insufficient" :: CrateOpenError
	end
	warn(`[VultarApi] Crate open {crateRequest.txId} for {userId} failed (HTTP {status})`)
	return nil, "unavailable" :: CrateOpenError
end

return VultarApi
