--!nocheck
local RunService = game:GetService("RunService")

return function()
	if not RunService:IsServer() then
		return
	end

	local LoadingScreenService = require(script.Parent)

	describe("LoadingScreenService", function()
		describe("module structure", function()
			it("should export Name property", function()
				expect(LoadingScreenService.Name).to.equal("LoadingScreenService")
			end)

			it("should have init method", function()
				expect(typeof(LoadingScreenService.init)).to.equal("function")
			end)

			it("should have start method", function()
				expect(typeof(LoadingScreenService.start)).to.equal("function")
			end)

			it("should have ShowForPlayer method", function()
				expect(typeof(LoadingScreenService.ShowForPlayer)).to.equal("function")
			end)

			it("should have HideForPlayer method", function()
				expect(typeof(LoadingScreenService.HideForPlayer)).to.equal("function")
			end)
		end)
	end)
end
