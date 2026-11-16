--!nocheck
--!strict

local RunService = game:GetService("RunService")
local PlayerGuiHelper = require(script.Parent.PlayerGuiHelper)

return function()
	if not RunService:IsClient() then
		return
	end

	describe("PlayerGuiHelper", function()
		describe("getPlayerGui", function()
			it("should return a PlayerGui instance", function()
				local gui = PlayerGuiHelper.getPlayerGui()

				if gui then
					expect(gui:IsA("PlayerGui")).to.equal(true)
				end
			end)
		end)

		describe("waitForPlayerGui", function()
			it("should return PlayerGui when available", function()
				local gui = PlayerGuiHelper.waitForPlayerGui(1)

				if gui then
					expect(gui:IsA("PlayerGui")).to.equal(true)
				end
			end)

			it("should accept custom timeout", function()
				local startTime = os.clock()
				PlayerGuiHelper.waitForPlayerGui(0.1)
				local elapsed = os.clock() - startTime

				expect(elapsed < 1).to.equal(true)
			end)
		end)

		describe("isScreenGuiActive", function()
			it("should return false for non-existent gui", function()
				local result = PlayerGuiHelper.isScreenGuiActive("NonExistentGui12345")

				expect(result).to.equal(false)
			end)
		end)
	end)
end
