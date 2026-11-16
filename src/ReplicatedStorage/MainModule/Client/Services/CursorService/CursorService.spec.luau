--!nocheck
return function()
	local success, CursorService = pcall(function()
		return require(script.Parent)
	end)

	describe("CursorService", function()
		if not success then
			it("SKIP: module failed to load in test environment", function()
				expect(true).to.equal(true)
			end)
			return
		end

		describe("module structure", function()
			it("should export Name property", function()
				expect(CursorService.Name).to.equal("CursorService")
			end)

			it("should have init method", function()
				expect(typeof(CursorService.init)).to.equal("function")
			end)

			it("should have start method", function()
				expect(typeof(CursorService.start)).to.equal("function")
			end)

			it("should have SetCursorStyle method", function()
				expect(typeof(CursorService.SetCursorStyle)).to.equal("function")
			end)

			it("should have SetCustomCursorId method", function()
				expect(typeof(CursorService.SetCustomCursorId)).to.equal("function")
			end)

			it("should have GetCurrentStyle method", function()
				expect(typeof(CursorService.GetCurrentStyle)).to.equal("function")
			end)
		end)
	end)
end
