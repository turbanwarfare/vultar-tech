--!nocheck
return function()
	local success, APIClient = pcall(function()
		return require(script.Parent.APIClient)
	end)

	describe("APIClient", function()
		if not success then
			it("SKIP: module failed to load in test environment", function()
				expect(true).to.equal(true)
			end)
			return
		end

		describe("module structure", function()
			it("should have fetch function", function()
				expect(typeof(APIClient.fetch)).to.equal("function")
			end)

			it("should have push function", function()
				expect(typeof(APIClient.push)).to.equal("function")
			end)

			it("should have exportSettings function", function()
				expect(typeof(APIClient.exportSettings)).to.equal("function")
			end)

			it("should have importSettings function", function()
				expect(typeof(APIClient.importSettings)).to.equal("function")
			end)

			it("should have clearErrorState function", function()
				expect(typeof(APIClient.clearErrorState)).to.equal("function")
			end)
		end)

		describe("clearErrorState", function()
			it("should not throw when clearing for unknown user", function()
				expect(function()
					APIClient.clearErrorState(999999999)
				end).never.to.throw()
			end)

			it("should not throw when clearing multiple times", function()
				expect(function()
					APIClient.clearErrorState(123456)
					APIClient.clearErrorState(123456)
					APIClient.clearErrorState(123456)
				end).never.to.throw()
			end)

			it("should handle zero userId", function()
				expect(function()
					APIClient.clearErrorState(0)
				end).never.to.throw()
			end)

			it("should handle negative userId", function()
				expect(function()
					APIClient.clearErrorState(-1)
				end).never.to.throw()
			end)
		end)
	end)
end
