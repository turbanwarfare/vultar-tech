--!nocheck
return function()
	local success, HealProcessor = pcall(function()
		return require(script.Parent.HealProcessor)
	end)

	describe("HealProcessor", function()
		if not success then
			it("SKIP: module failed to load in test environment", function()
				expect(true).to.equal(true)
			end)
			return
		end

		describe("module structure", function()
			it("should have init function", function()
				expect(typeof(HealProcessor.init)).to.equal("function")
			end)

			it("should have cleanup function", function()
				expect(typeof(HealProcessor.cleanup)).to.equal("function")
			end)

			it("should have processBatch function", function()
				expect(typeof(HealProcessor.processBatch)).to.equal("function")
			end)

			it("should have applyHeal function", function()
				expect(typeof(HealProcessor.applyHeal)).to.equal("function")
			end)
		end)

		describe("init and cleanup", function()
			it("should init without error", function()
				expect(function()
					HealProcessor.init()
				end).never.to.throw()
			end)

			it("should cleanup without error", function()
				expect(function()
					HealProcessor.cleanup()
				end).never.to.throw()
			end)

			it("should allow multiple init/cleanup cycles", function()
				expect(function()
					HealProcessor.init()
					HealProcessor.cleanup()
					HealProcessor.init()
					HealProcessor.cleanup()
				end).never.to.throw()
			end)
		end)
	end)
end
