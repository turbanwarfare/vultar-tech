--!nocheck
--!strict

local TableMerge = require(script.Parent.TableMerge)

return function()
	describe("TableMerge", function()
		describe("mergeWithDefaults", function()
			it("should return defaults when data is nil", function()
				local defaults = {
					Settings = { a = 1, b = 2 },
					Other = { c = 3 },
				}

				local result = TableMerge.mergeWithDefaults(nil, defaults)

				expect(result.Settings.a).to.equal(1)
				expect(result.Settings.b).to.equal(2)
				expect(result.Other.c).to.equal(3)
			end)

			it("should return defaults when data is not a table", function()
				local defaults = { Settings = { a = 1 } }

				local result = TableMerge.mergeWithDefaults("invalid", defaults)

				expect(result.Settings.a).to.equal(1)
			end)

			it("should merge matching sections", function()
				local defaults = {
					Settings = { a = 1, b = 2 },
				}
				local data = {
					Settings = { a = 100 },
				}

				local result = TableMerge.mergeWithDefaults(data, defaults)

				expect(result.Settings.a).to.equal(100)
				expect(result.Settings.b).to.equal(2)
			end)

			it("should only merge values with matching types", function()
				local defaults = {
					Settings = { count = 10, name = "default" },
				}
				local data = {
					Settings = { count = "wrong type", name = "custom" },
				}

				local result = TableMerge.mergeWithDefaults(data, defaults)

				expect(result.Settings.count).to.equal(10)
				expect(result.Settings.name).to.equal("custom")
			end)

			it("should not modify the original defaults", function()
				local defaults = {
					Settings = { value = 1 },
				}
				local data = {
					Settings = { value = 999 },
				}

				TableMerge.mergeWithDefaults(data, defaults)

				expect(defaults.Settings.value).to.equal(1)
			end)

			it("should handle nested sections", function()
				local defaults = {
					Settings = { a = 1 },
					Keybinds = { jump = "Space" },
					Cosmetics = { hat = "none" },
				}
				local data = {
					Settings = { a = 5 },
					Keybinds = { jump = "W" },
				}

				local result = TableMerge.mergeWithDefaults(data, defaults)

				expect(result.Settings.a).to.equal(5)
				expect(result.Keybinds.jump).to.equal("W")
				expect(result.Cosmetics.hat).to.equal("none")
			end)
		end)

		describe("shallowMerge", function()
			it("should return copy of target when source is nil", function()
				local target = { a = 1, b = 2 }

				local result = TableMerge.shallowMerge(target, nil)

				expect(result.a).to.equal(1)
				expect(result.b).to.equal(2)
				expect(result).never.to.equal(target)
			end)

			it("should merge source values into target", function()
				local target = { a = 1, b = 2 }
				local source = { b = 20, c = 30 }

				local result = TableMerge.shallowMerge(target, source)

				expect(result.a).to.equal(1)
				expect(result.b).to.equal(20)
				expect(result.c).to.equal(30)
			end)

			it("should not modify original target", function()
				local target = { a = 1 }
				local source = { a = 999 }

				TableMerge.shallowMerge(target, source)

				expect(target.a).to.equal(1)
			end)
		end)
	end)
end
