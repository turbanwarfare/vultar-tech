--!nocheck
return function()
	local ServiceRegistry = require(script.Parent.ServiceRegistry)
	local ServiceLocator = require(script.Parent.ServiceLocator)

	describe("ServiceLocator", function()
		beforeEach(function()
			ServiceRegistry.clear()
			ServiceLocator.clearCache()
		end)

		afterEach(function()
			ServiceRegistry.clear()
			ServiceLocator.clearCache()
		end)

		describe("module structure", function()
			it("should have Settings function", function()
				expect(typeof(ServiceLocator.Settings)).to.equal("function")
			end)

			it("should have Loading function", function()
				expect(typeof(ServiceLocator.Loading)).to.equal("function")
			end)

			it("should have Cursor function", function()
				expect(typeof(ServiceLocator.Cursor)).to.equal("function")
			end)

			it("should have get function", function()
				expect(typeof(ServiceLocator.get)).to.equal("function")
			end)

			it("should have callIfExists function", function()
				expect(typeof(ServiceLocator.callIfExists)).to.equal("function")
			end)

			it("should have isAvailable function", function()
				expect(typeof(ServiceLocator.isAvailable)).to.equal("function")
			end)

			it("should have clearCache function", function()
				expect(typeof(ServiceLocator.clearCache)).to.equal("function")
			end)
		end)

		describe("service lookup", function()
			it("should return nil for unregistered service", function()
				expect(ServiceLocator.Settings()).to.equal(nil)
			end)

			it("should return registered service", function()
				local mockSettings = { Name = "SettingsService", value = 42 }
				ServiceRegistry.register("SettingsService", mockSettings)
				local result = ServiceLocator.Settings()
				expect(result).to.equal(mockSettings)
			end)

			it("should cache service lookups", function()
				local mockSettings = { Name = "SettingsService", value = 42 }
				ServiceRegistry.register("SettingsService", mockSettings)
				local first = ServiceLocator.Settings()
				local second = ServiceLocator.Settings()
				expect(first).to.equal(second)
			end)

			it("should support generic get", function()
				local mockService = { Name = "CustomService" }
				ServiceRegistry.register("CustomService", mockService)
				local result = ServiceLocator.get("CustomService")
				expect(result).to.equal(mockService)
			end)
		end)

		describe("callIfExists", function()
			it("should return nil for non-existent service", function()
				local result = ServiceLocator.callIfExists("NonExistent", "SomeMethod")
				expect(result).to.equal(nil)
			end)

			it("should return nil for non-existent method", function()
				ServiceRegistry.register("TestService", { Name = "TestService" })
				local result = ServiceLocator.callIfExists("TestService", "NonExistentMethod")
				expect(result).to.equal(nil)
			end)

			it("should call method and return result", function()
				local mockService = {
					Name = "TestService",
					GetValue = function(_self)
						return 42
					end,
				}
				ServiceRegistry.register("TestService", mockService)
				local result = ServiceLocator.callIfExists("TestService", "GetValue")
				expect(result).to.equal(42)
			end)

			it("should pass arguments to method", function()
				local mockService = {
					Name = "TestService",
					Add = function(_self, a, b)
						return a + b
					end,
				}
				ServiceRegistry.register("TestService", mockService)
				local result = ServiceLocator.callIfExists("TestService", "Add", 5, 3)
				expect(result).to.equal(8)
			end)

			it("should return nil on method error", function()
				local mockService = {
					Name = "TestService",
					Throws = function()
						error("Test error")
					end,
				}
				ServiceRegistry.register("TestService", mockService)
				local result = ServiceLocator.callIfExists("TestService", "Throws")
				expect(result).to.equal(nil)
			end)
		end)

		describe("isAvailable", function()
			it("should return false for unregistered service", function()
				expect(ServiceLocator.isAvailable("NonExistent")).to.equal(false)
			end)

			it("should return false for registered but not started service", function()
				ServiceRegistry.register("TestService", { Name = "TestService" })
				expect(ServiceLocator.isAvailable("TestService")).to.equal(false)
			end)

			it("should return true for started service", function()
				ServiceRegistry.register("TestService", { Name = "TestService" })
				ServiceRegistry.startService("TestService")
				expect(ServiceLocator.isAvailable("TestService")).to.equal(true)
			end)
		end)

		describe("clearCache", function()
			it("should clear cached lookups", function()
				local mockService = { Name = "TestService", value = 1 }
				ServiceRegistry.register("TestService", mockService)
				ServiceLocator.get("TestService")

				ServiceLocator.clearCache()
				ServiceRegistry.clear()

				expect(ServiceLocator.get("TestService")).to.equal(nil)
			end)
		end)

		describe("all service shortcuts", function()
			local shortcuts = {
				{ "Settings", "SettingsService" },
				{ "Loading", "LoadingService" },
				{ "Cursor", "CursorService" },
				{ "Leaderboard", "LeaderboardService" },
				{ "Gun", "GunService" },
				{ "Weapon", "WeaponService" },
				{ "Chat", "ChatService" },
				{ "Ping", "PingService" },
				{ "Stats", "StatsService" },
				{ "Inventory", "InventoryService" },
				{ "Cosmetic", "CosmeticService" },
				{ "AnimatedCard", "AnimatedCardService" },
				{ "TeamChanger", "TeamChangerService" },
			}

			for _, pair in shortcuts do
				local shortcut, serviceName = pair[1], pair[2]
				it("should have " .. shortcut .. " shortcut for " .. serviceName, function()
					local mockService = { Name = serviceName }
					ServiceRegistry.register(serviceName, mockService)
					local result = (ServiceLocator :: any)[shortcut]()
					expect(result).to.equal(mockService)
				end)
			end
		end)
	end)
end
