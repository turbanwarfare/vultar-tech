--!strict
--!native
--!optimize 2

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerInfoService = {}
ServerInfoService.Name = "ServerInfoService"

local REGION_ATTRIBUTE = "ServerRegion"
local GEOLOCATION_URL = "http://ip-api.com/json/?fields=city,regionName,country,countryCode"

local isInitialized = false

local FALLBACK_REGION = "Unknown"

local function detectRegion(): string
	local success, result = pcall(function()
		local response = HttpService:GetAsync(GEOLOCATION_URL)
		local data = HttpService:JSONDecode(response)

		local country = data.countryCode or data.country or ""
		local city = data.city or data.regionName or ""

		if country ~= "" and city ~= "" then
			return country .. ", " .. city
		elseif city ~= "" then
			return city
		elseif country ~= "" then
			return country
		end

		return FALLBACK_REGION
	end)

	if success and result then
		return result
	end

	return FALLBACK_REGION
end

function ServerInfoService:init(): ()
	local region = detectRegion()
	ReplicatedStorage:SetAttribute(REGION_ATTRIBUTE, region)
	isInitialized = true
end

function ServerInfoService:start(): ()
	if not isInitialized then
		self:init()
	end
end

function ServerInfoService:GetRegion(): string
	return ReplicatedStorage:GetAttribute(REGION_ATTRIBUTE) or FALLBACK_REGION
end

function ServerInfoService:Cleanup(): ()
	isInitialized = false
end

return ServerInfoService
