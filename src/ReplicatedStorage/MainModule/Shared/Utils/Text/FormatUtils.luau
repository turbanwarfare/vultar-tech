--!strict
--!native
--!optimize 2

local FormatUtils = {}

function FormatUtils.formatTimeMMSS(totalSeconds: number): string
	totalSeconds = math.max(0, totalSeconds)
	local minutes = totalSeconds // 60
	local seconds = math.floor(totalSeconds % 60)
	return string.format("%02d:%02d", minutes, seconds)
end

function FormatUtils.formatTimeHHMMSS(totalSeconds: number): string
	local hours = totalSeconds // 3600
	local minutes = (totalSeconds % 3600) // 60
	local seconds = math.floor(totalSeconds % 60)
	if hours > 0 then
		return string.format("%02d:%02d:%02d", hours, minutes, seconds)
	end
	return string.format("%02d:%02d", minutes, seconds)
end

function FormatUtils.formatNumber(n: number): string
	return tostring(math.floor(n))
end

function FormatUtils.formatNumberWithCommas(amount: number): string
	local formatted = tostring(math.max(0, math.floor(amount)))
	local iterations = 0
	repeat
		formatted, iterations = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until iterations == 0
	return formatted
end

return FormatUtils
