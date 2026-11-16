--!nocheck
--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")

return function()
	if not RunService:IsServer() then
		return
	end

	local SettingsService = require(script.Parent)
	local MainModule = script.Parent.Parent.Parent.Parent
	local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)

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

			it("should have GetPlayerSettings method", function()
				expect(typeof(SettingsService.GetPlayerSettings)).to.equal("function")
			end)

			it("should have SetPlayerSetting method", function()
				expect(typeof(SettingsService.SetPlayerSetting)).to.equal("function")
			end)
		end)

		describe("GetPlayerSettings", function()
			it("should return nil for non-existent player", function()
				local mockPlayer = {
					UserId = 999999999,
				}

				local result = SettingsService:GetPlayerSettings(mockPlayer :: any)
				expect(result).to.equal(nil)
			end)
		end)

		describe("SetPlayerSetting", function()
			it("should return false for non-existent player", function()
				local mockPlayer = {
					UserId = 999999999,
				}

				local result = SettingsService:SetPlayerSetting(mockPlayer :: any, "Materials", true)
				expect(result).to.equal(false)
			end)

			it("should return false for invalid setting key", function()
				local mockPlayer = {
					UserId = 999999998,
				}

				local result = SettingsService:SetPlayerSetting(mockPlayer :: any, "InvalidSettingKey", true)
				expect(result).to.equal(false)
			end)
		end)

		describe("default settings validation", function()
			it("should use SettingsConfig for default values", function()
				expect(SettingsConfig.DefaultSettings).to.be.ok()
				expect(SettingsConfig.DefaultSettings.Settings).to.be.ok()
				expect(SettingsConfig.DefaultSettings.Keybinds).to.be.ok()
			end)
		end)
	end)
end
