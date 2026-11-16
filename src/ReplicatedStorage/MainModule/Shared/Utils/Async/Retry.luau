--!strict
--!native
--!optimize 2

local Constants = require(script.Parent.Parent.Parent.Config.Constants)

type ResolvedRetryConfig = {
	MaxAttempts: number,
	InitialDelay: number,
	MaxDelay: number,
	BackoffMultiplier: number,
}

type RetryConfig = {
	MaxAttempts: number?,
	InitialDelay: number?,
	MaxDelay: number?,
	BackoffMultiplier: number?,
}

type RetryResult<T> = {
	Success: boolean,
	Value: T?,
	Error: string?,
	Attempts: number,
}

local Retry = {}

local function getConfig(config: RetryConfig?): ResolvedRetryConfig
	local defaults = Constants.RETRY
	local resolved: ResolvedRetryConfig = {
		MaxAttempts = defaults.MAX_ATTEMPTS,
		InitialDelay = defaults.INITIAL_DELAY,
		MaxDelay = defaults.MAX_DELAY,
		BackoffMultiplier = defaults.BACKOFF_MULTIPLIER,
	}

	if config then
		if config.MaxAttempts then
			resolved.MaxAttempts = config.MaxAttempts
		end
		if config.InitialDelay then
			resolved.InitialDelay = config.InitialDelay
		end
		if config.MaxDelay then
			resolved.MaxDelay = config.MaxDelay
		end
		if config.BackoffMultiplier then
			resolved.BackoffMultiplier = config.BackoffMultiplier
		end
	end

	return resolved
end

function Retry.execute<T>(fn: () -> T, config: RetryConfig?): RetryResult<T>
	local cfg = getConfig(config)
	local attempts = 0
	local delay = cfg.InitialDelay
	local lastError: string? = nil

	while attempts < cfg.MaxAttempts do
		attempts += 1

		local success, result = pcall(fn)
		if success then
			return {
				Success = true,
				Value = result,
				Error = nil,
				Attempts = attempts,
			}
		end

		lastError = tostring(result)

		if attempts < cfg.MaxAttempts then
			task.wait(delay)
			delay = math.min(delay * cfg.BackoffMultiplier, cfg.MaxDelay)
		end
	end

	return {
		Success = false,
		Value = nil,
		Error = lastError,
		Attempts = attempts,
	}
end

function Retry.executeAsync<T>(fn: () -> T, config: RetryConfig?): RetryResult<T>
	return Retry.execute(fn, config)
end

return Retry
