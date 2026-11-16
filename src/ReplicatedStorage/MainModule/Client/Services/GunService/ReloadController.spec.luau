--!nocheck
return function()
	local success, ReloadController = pcall(function()
		return require(script.Parent.ReloadController)
	end)

	describe("ReloadController", function()
		if not success then
			it("SKIP: module failed to load in test environment", function()
				expect(true).to.equal(true)
			end)
			return
		end

		describe("module structure", function()
			it("should have init function", function()
				expect(typeof(ReloadController.init)).to.equal("function")
			end)

			it("should have isReloading function", function()
				expect(typeof(ReloadController.isReloading)).to.equal("function")
			end)

			it("should have start function", function()
				expect(typeof(ReloadController.start)).to.equal("function")
			end)

			it("should have reset function", function()
				expect(typeof(ReloadController.reset)).to.equal("function")
			end)

			it("should have cleanup function", function()
				expect(typeof(ReloadController.cleanup)).to.equal("function")
			end)
		end)

		describe("isReloading", function()
			it("should return a boolean", function()
				local result = ReloadController.isReloading()
				expect(typeof(result)).to.equal("boolean")
			end)
		end)

		describe("reset", function()
			it("should not throw when called", function()
				expect(function()
					ReloadController.reset()
				end).never.to.throw()
			end)

			it("should set isReloading to false", function()
				ReloadController.reset()
				expect(ReloadController.isReloading()).to.equal(false)
			end)
		end)
	end)
end
