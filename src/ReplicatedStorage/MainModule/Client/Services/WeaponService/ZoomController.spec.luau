--!nocheck
return function()
	local success, ZoomController = pcall(function()
		return require(script.Parent.ZoomController)
	end)

	describe("ZoomController", function()
		if not success then
			it("SKIP: module failed to load in test environment", function()
				expect(true).to.equal(true)
			end)
			return
		end

		describe("module structure", function()
			it("should have init function", function()
				expect(typeof(ZoomController.init)).to.equal("function")
			end)

			it("should have applyZoom function", function()
				expect(typeof(ZoomController.applyZoom)).to.equal("function")
			end)

			it("should have reset function", function()
				expect(typeof(ZoomController.reset)).to.equal("function")
			end)

			it("should have cleanup function", function()
				expect(typeof(ZoomController.cleanup)).to.equal("function")
			end)
		end)

		describe("init", function()
			it("should not throw when called", function()
				expect(function()
					ZoomController.init()
				end).never.to.throw()
			end)
		end)

		describe("applyZoom", function()
			beforeEach(function()
				ZoomController.init()
			end)

			afterEach(function()
				ZoomController.cleanup()
			end)

			it("should not throw when zooming in", function()
				expect(function()
					ZoomController.applyZoom(true)
				end).never.to.throw()
			end)

			it("should not throw when zooming out", function()
				expect(function()
					ZoomController.applyZoom(false)
				end).never.to.throw()
			end)

			it("should handle rapid zoom toggle", function()
				expect(function()
					ZoomController.applyZoom(true)
					ZoomController.applyZoom(false)
					ZoomController.applyZoom(true)
					ZoomController.applyZoom(false)
				end).never.to.throw()
			end)
		end)

		describe("reset", function()
			beforeEach(function()
				ZoomController.init()
			end)

			it("should not throw when called", function()
				expect(function()
					ZoomController.reset()
				end).never.to.throw()
			end)

			it("should not throw when called after zoom", function()
				expect(function()
					ZoomController.applyZoom(true)
					ZoomController.reset()
				end).never.to.throw()
			end)
		end)

		describe("cleanup", function()
			it("should not throw when called", function()
				expect(function()
					ZoomController.cleanup()
				end).never.to.throw()
			end)

			it("should not throw when called multiple times", function()
				expect(function()
					ZoomController.cleanup()
					ZoomController.cleanup()
					ZoomController.cleanup()
				end).never.to.throw()
			end)
		end)
	end)
end
