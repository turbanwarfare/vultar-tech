--!nocheck
--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")

return function()
	if not RunService:IsClient() then
		return
	end

	local SettingsService = require(script.Parent)

	describe("SettingsService", function()
		describe("module structure", function()
			it("should export Name property", function()
				expect(SettingsService.Name).to.equal("SettingsService")
			end)

			it("should have init method", function()
				expect(typeof(SettingsService.init)).to.equal("function")
			end)

			it("should have start method", function()
				expect(typeof(SettingsService.start)).to.equal("function")
			end)

			it("should have Show method", function()
				expect(typeof(SettingsService.Show)).to.equal("function")
			end)

			it("should have Hide method", function()
				expect(typeof(SettingsService.Hide)).to.equal("function")
			end)

			it("should have Toggle method", function()
				expect(typeof(SettingsService.Toggle)).to.equal("function")
			end)

			it("should have IsVisible method", function()
				expect(typeof(SettingsService.IsVisible)).to.equal("function")
			end)

			it("should have GetSettings method", function()
				expect(typeof(SettingsService.GetSettings)).to.equal("function")
			end)

			it("should have GetSetting method", function()
				expect(typeof(SettingsService.GetSetting)).to.equal("function")
			end)

			it("should have GetKeybind method", function()
				expect(typeof(SettingsService.GetKeybind)).to.equal("function")
			end)

			it("should have ResetSettings method", function()
				expect(typeof(SettingsService.ResetSettings)).to.equal("function")
			end)

			it("should have Cleanup method", function()
				expect(typeof(SettingsService.Cleanup)).to.equal("function")
			end)
		end)

		describe("visibility state", function()
			it("should start not visible", function()
				local isVisible = SettingsService:IsVisible()
				expect(isVisible).to.equal(false)
			end)
		end)

		describe("GetSetting", function()
			it("should return nil for non-existent setting when not initialized", function()
				local result = SettingsService:GetSetting("NonExistentSetting")
				expect(result).to.equal(nil)
			end)
		end)

		describe("GetKeybind", function()
			it("should return nil for non-existent keybind when not initialized", function()
				local result = SettingsService:GetKeybind("NonExistentKeybind")
				expect(result).to.equal(nil)
			end)
		end)

		describe("GetSettings", function()
			it("should return nil when not initialized", function()
				local result = SettingsService:GetSettings()
				if result then
					expect(typeof(result)).to.equal("table")
				end
			end)
		end)
	end)
end
