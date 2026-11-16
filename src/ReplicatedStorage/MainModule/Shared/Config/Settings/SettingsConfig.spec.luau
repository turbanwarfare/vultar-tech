--!nocheck
--!strict
--!native
--!optimize 2

return function()
	local SettingsConfig = require(script.Parent.SettingsConfig)

	describe("SettingsConfig", function()
		describe("module structure", function()
			it("should export API_BASE_URL", function()
				expect(SettingsConfig.API_BASE_URL).to.be.a("string")
				expect(#SettingsConfig.API_BASE_URL > 0).to.equal(true)
			end)

			it("should export DATASTORE_NAME", function()
				expect(SettingsConfig.DATASTORE_NAME).to.be.a("string")
				expect(#SettingsConfig.DATASTORE_NAME > 0).to.equal(true)
			end)

			it("should export KEYBINDS_BLACKLIST_SET", function()
				expect(SettingsConfig.KEYBINDS_BLACKLIST_SET).to.be.a("table")
			end)

			it("should export DefaultSettings", function()
				expect(SettingsConfig.DefaultSettings).to.be.a("table")
			end)

			it("should export Categories", function()
				expect(SettingsConfig.Categories).to.be.a("table")
				expect(#SettingsConfig.Categories > 0).to.equal(true)
			end)

			it("should export KeybindDescriptions", function()
				expect(SettingsConfig.KeybindDescriptions).to.be.a("table")
			end)

			it("should export Rules", function()
				expect(SettingsConfig.Rules).to.be.a("table")
				expect(#SettingsConfig.Rules > 0).to.equal(true)
			end)
		end)

		describe("KEYBINDS_BLACKLIST_SET", function()
			it("should contain number keys", function()
				expect(SettingsConfig.KEYBINDS_BLACKLIST_SET[Enum.KeyCode.One]).to.equal(true)
				expect(SettingsConfig.KEYBINDS_BLACKLIST_SET[Enum.KeyCode.Zero]).to.equal(true)
			end)

			it("should contain movement keys", function()
				expect(SettingsConfig.KEYBINDS_BLACKLIST_SET[Enum.KeyCode.W]).to.equal(true)
				expect(SettingsConfig.KEYBINDS_BLACKLIST_SET[Enum.KeyCode.A]).to.equal(true)
				expect(SettingsConfig.KEYBINDS_BLACKLIST_SET[Enum.KeyCode.S]).to.equal(true)
				expect(SettingsConfig.KEYBINDS_BLACKLIST_SET[Enum.KeyCode.D]).to.equal(true)
			end)

			it("should only contain EnumItem keys with boolean values", function()
				for keyCode, value in SettingsConfig.KEYBINDS_BLACKLIST_SET do
					expect(typeof(keyCode)).to.equal("EnumItem")
					expect(value).to.equal(true)
				end
			end)
		end)

		describe("DefaultSettings", function()
			it("should have Settings section", function()
				expect(SettingsConfig.DefaultSettings.Settings).to.be.a("table")
			end)

			it("should have Keybinds section", function()
				expect(SettingsConfig.DefaultSettings.Keybinds).to.be.a("table")
			end)

			it("should have Cosmetics section", function()
				expect(SettingsConfig.DefaultSettings.Cosmetics).to.be.a("table")
			end)

			it("should have Global section", function()
				expect(SettingsConfig.DefaultSettings.Global).to.be.a("table")
			end)

			describe("Settings defaults", function()
				it("should have boolean settings", function()
					local settings = SettingsConfig.DefaultSettings.Settings
					expect(typeof(settings.Materials)).to.equal("boolean")
					expect(typeof(settings.Particles)).to.equal("boolean")
					expect(typeof(settings.Shaders)).to.equal("boolean")
					expect(typeof(settings.Shadows)).to.equal("boolean")
				end)

				it("should have number settings", function()
					local settings = SettingsConfig.DefaultSettings.Settings
					expect(typeof(settings.Time)).to.equal("number")
					expect(typeof(settings.CursorStyle)).to.equal("number")
				end)
			end)

			describe("Keybinds defaults", function()
				it("should have all required keybinds", function()
					local keybinds = SettingsConfig.DefaultSettings.Keybinds
					expect(keybinds.Sprint).to.be.ok()
					expect(keybinds.Crouch).to.be.ok()
					expect(keybinds.Reload).to.be.ok()
					expect(keybinds.Menu).to.be.ok()
				end)

				it("should have string values for keybinds", function()
					for _, value in SettingsConfig.DefaultSettings.Keybinds do
						expect(typeof(value)).to.equal("string")
						expect(#value > 0).to.equal(true)
					end
				end)
			end)

			describe("Global defaults", function()
				it("should have stats initialized to zero", function()
					local global = SettingsConfig.DefaultSettings.Global
					expect(global.Kills).to.equal(0)
					expect(global.Damage).to.equal(0)
					expect(global.Heals).to.equal(0)
					expect(global.GamesPlayed).to.equal(0)
				end)
			end)
		end)

		describe("Categories", function()
			it("should have valid category structure", function()
				for _, category in SettingsConfig.Categories do
					expect(category.name).to.be.a("string")
					expect(category.settings).to.be.a("table")
				end
			end)

			it("should have valid setting definitions", function()
				for _, category in SettingsConfig.Categories do
					for _, setting in category.settings do
						expect(setting.key).to.be.a("string")
						expect(setting.label).to.be.a("string")
						expect(setting.order).to.be.a("number")
						expect(setting.type).to.be.a("string")
						expect(setting.description).to.be.a("string")
						if setting.children then
							for _, child in setting.children do
								expect(child.label).to.be.a("string")
							end
						end
					end
				end
			end)

			it("should have settings that exist in DefaultSettings", function()
				for _, category in SettingsConfig.Categories do
					for _, setting in category.settings do
						local defaultValue = SettingsConfig.DefaultSettings.Settings[setting.key]
						expect(defaultValue ~= nil).to.equal(true)
					end
				end
			end)

			it("should have valid setting types", function()
				local validTypes = { Boolean = true, Pick = true, Slider = true, TypeIn = true, Dropdown = true, CursorPick = true, Expandable = true, HitmarkerPick = true, CursorHistoryInput = true, CursorHistoryGrid = true, FontPick = true }
				for _, category in SettingsConfig.Categories do
					for _, setting in category.settings do
						expect(validTypes[setting.type]).to.equal(true)
					end
				end
			end)

			it("should have options for Pick type settings", function()
				for _, category in SettingsConfig.Categories do
					for _, setting in category.settings do
						if setting.type == "Pick" then
							expect(setting.options).to.be.a("table")
							expect(#setting.options >= 2).to.equal(true)
						end
					end
				end
			end)
		end)

		describe("KeybindDescriptions", function()
			it("should have descriptions for all default keybinds", function()
				for keybindName in SettingsConfig.DefaultSettings.Keybinds do
					local description = SettingsConfig.KeybindDescriptions[keybindName]
					expect(description).to.be.a("string")
					expect(#description > 0).to.equal(true)
				end
			end)
		end)

		describe("Rules", function()
			it("should contain string rules", function()
				for _, rule in SettingsConfig.Rules do
					expect(typeof(rule)).to.equal("string")
					expect(#rule > 0).to.equal(true)
				end
			end)

			it("should have at least one rule", function()
				expect(#SettingsConfig.Rules >= 1).to.equal(true)
			end)
		end)
	end)
end
