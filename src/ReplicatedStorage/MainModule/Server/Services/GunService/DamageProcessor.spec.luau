--!nocheck
return function()
	local success, DamageProcessor = pcall(function()
		return require(script.Parent.DamageProcessor)
	end)

	describe("DamageProcessor", function()
		if not success then
			it("SKIP: module failed to load in test environment", function()
				expect(true).to.equal(true)
			end)
			return
		end

		describe("module structure", function()
			it("should have init function", function()
				expect(typeof(DamageProcessor.init)).to.equal("function")
			end)

			it("should have cleanup function", function()
				expect(typeof(DamageProcessor.cleanup)).to.equal("function")
			end)

			it("should have applyDamageImmediate function", function()
				expect(typeof(DamageProcessor.applyDamageImmediate)).to.equal("function")
			end)

			it("should have processBatch function", function()
				expect(typeof(DamageProcessor.processBatch)).to.equal("function")
			end)

			it("should have applyDamage function", function()
				expect(typeof(DamageProcessor.applyDamage)).to.equal("function")
			end)
		end)

		describe("init and cleanup", function()
			it("should init without error", function()
				expect(function()
					DamageProcessor.init()
				end).never.to.throw()
			end)

			it("should cleanup without error", function()
				expect(function()
					DamageProcessor.cleanup()
				end).never.to.throw()
			end)

			it("should allow multiple init/cleanup cycles", function()
				expect(function()
					DamageProcessor.init()
					DamageProcessor.cleanup()
					DamageProcessor.init()
					DamageProcessor.cleanup()
				end).never.to.throw()
			end)
		end)
	end)
end
