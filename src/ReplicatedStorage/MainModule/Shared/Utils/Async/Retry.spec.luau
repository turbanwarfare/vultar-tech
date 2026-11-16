--!nocheck
return function()
	local Retry = require(script.Parent.Retry)

	describe("Retry", function()
		describe("successful execution", function()
			it("should return success on first attempt when function succeeds", function()
				local callCount = 0
				local result = Retry.execute(function()
					callCount += 1
					return "success"
				end)

				expect(result.Success).to.equal(true)
				expect(result.Value).to.equal("success")
				expect(result.Attempts).to.equal(1)
				expect(result.Error).to.equal(nil)
				expect(callCount).to.equal(1)
			end)

			it("should handle different return types", function()
				local numberResult = Retry.execute(function() return 42 end)
				expect(numberResult.Value).to.equal(42)

				local tableResult = Retry.execute(function() return { key = "value" } end)
				expect(tableResult.Value.key).to.equal("value")

				local boolResult = Retry.execute(function() return true end)
				expect(boolResult.Value).to.equal(true)

				local nilResult = Retry.execute(function() return nil end)
				expect(nilResult.Success).to.equal(true)
				expect(nilResult.Value).to.equal(nil)
			end)
		end)

		describe("retry behavior", function()
			it("should retry on failure and eventually succeed", function()
				local callCount = 0
				local result = Retry.execute(function()
					callCount += 1
					if callCount < 3 then
						error("temporary failure")
					end
					return "success after retries"
				end, {
					MaxAttempts = 5,
					InitialDelay = 0.01,
					MaxDelay = 0.1,
					BackoffMultiplier = 2,
				})

				expect(result.Success).to.equal(true)
				expect(result.Value).to.equal("success after retries")
				expect(result.Attempts).to.equal(3)
				expect(callCount).to.equal(3)
			end)

			it("should fail after max attempts exceeded", function()
				local callCount = 0
				local result = Retry.execute(function()
					callCount += 1
					error("permanent failure")
				end, {
					MaxAttempts = 3,
					InitialDelay = 0.01,
					MaxDelay = 0.1,
					BackoffMultiplier = 2,
				})

				expect(result.Success).to.equal(false)
				expect(result.Value).to.equal(nil)
				expect(result.Attempts).to.equal(3)
				expect(result.Error).to.be.ok()
				expect(callCount).to.equal(3)
			end)

			it("should respect MaxAttempts config", function()
				local callCount = 0
				Retry.execute(function()
					callCount += 1
					error("fail")
				end, { MaxAttempts = 7, InitialDelay = 0.001, MaxDelay = 0.01, BackoffMultiplier = 1 })

				expect(callCount).to.equal(7)
			end)
		end)

		describe("error handling", function()
			it("should capture error messages", function()
				local result = Retry.execute(function()
					error("specific error message")
				end, { MaxAttempts = 1, InitialDelay = 0.01, MaxDelay = 0.1, BackoffMultiplier = 2 })

				expect(result.Success).to.equal(false)
				expect(result.Error).to.be.ok()
				expect(string.find(result.Error :: string, "specific error message")).to.be.ok()
			end)

			it("should capture the last error when multiple retries fail", function()
				local callCount = 0
				local result = Retry.execute(function()
					callCount += 1
					error("error attempt " .. callCount)
				end, { MaxAttempts = 3, InitialDelay = 0.01, MaxDelay = 0.1, BackoffMultiplier = 2 })

				expect(result.Error).to.be.ok()
				expect(string.find(result.Error :: string, "error attempt 3")).to.be.ok()
			end)
		end)

		describe("default config", function()
			it("should use default config when none provided", function()
				local result = Retry.execute(function()
					return 42
				end)

				expect(result.Success).to.equal(true)
				expect(result.Value).to.equal(42)
			end)

			it("should use partial config with defaults for missing values", function()
				local callCount = 0
				local result = Retry.execute(function()
					callCount += 1
					if callCount < 2 then
						error("fail once")
					end
					return "ok"
				end, { MaxAttempts = 3 })

				expect(result.Success).to.equal(true)
				expect(result.Attempts).to.equal(2)
			end)
		end)

		describe("executeAsync", function()
			it("should behave identically to execute", function()
				local result = Retry.executeAsync(function()
					return "async result"
				end)

				expect(result.Success).to.equal(true)
				expect(result.Value).to.equal("async result")
				expect(result.Attempts).to.equal(1)
			end)

			it("should also support retries", function()
				local callCount = 0
				local result = Retry.executeAsync(function()
					callCount += 1
					if callCount < 2 then
						error("async fail")
					end
					return "async success"
				end, { MaxAttempts = 3, InitialDelay = 0.01, MaxDelay = 0.1, BackoffMultiplier = 2 })

				expect(result.Success).to.equal(true)
				expect(result.Attempts).to.equal(2)
			end)
		end)
	end)
end
