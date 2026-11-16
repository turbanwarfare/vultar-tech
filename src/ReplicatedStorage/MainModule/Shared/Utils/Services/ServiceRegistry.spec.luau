--!nocheck
return function()
	local ServiceRegistry = require(script.Parent.ServiceRegistry)

	describe("ServiceRegistry", function()
		beforeEach(function()
			ServiceRegistry.clear()
		end)

		afterEach(function()
			ServiceRegistry.clear()
		end)

		describe("module structure", function()
			it("should have register function", function()
				expect(typeof(ServiceRegistry.register)).to.equal("function")
			end)

			it("should have get function", function()
				expect(typeof(ServiceRegistry.get)).to.equal("function")
			end)

			it("should have getStrict function", function()
				expect(typeof(ServiceRegistry.getStrict)).to.equal("function")
			end)

			it("should have isRegistered function", function()
				expect(typeof(ServiceRegistry.isRegistered)).to.equal("function")
			end)

			it("should have isInitialized function", function()
				expect(typeof(ServiceRegistry.isInitialized)).to.equal("function")
			end)

			it("should have isStarted function", function()
				expect(typeof(ServiceRegistry.isStarted)).to.equal("function")
			end)

			it("should have initService function", function()
				expect(typeof(ServiceRegistry.initService)).to.equal("function")
			end)

			it("should have startService function", function()
				expect(typeof(ServiceRegistry.startService)).to.equal("function")
			end)

			it("should have cleanupService function", function()
				expect(typeof(ServiceRegistry.cleanupService)).to.equal("function")
			end)

			it("should have initAll function", function()
				expect(typeof(ServiceRegistry.initAll)).to.equal("function")
			end)

			it("should have startAll function", function()
				expect(typeof(ServiceRegistry.startAll)).to.equal("function")
			end)

			it("should have cleanupAll function", function()
				expect(typeof(ServiceRegistry.cleanupAll)).to.equal("function")
			end)

			it("should have clear function", function()
				expect(typeof(ServiceRegistry.clear)).to.equal("function")
			end)
		end)

		describe("registration", function()
			it("should register a service", function()
				local mockService = { Name = "TestService" }
				ServiceRegistry.register("TestService", mockService)
				expect(ServiceRegistry.isRegistered("TestService")).to.equal(true)
			end)

			it("should return registered service via get", function()
				local mockService = { Name = "TestService" }
				ServiceRegistry.register("TestService", mockService)
				local retrieved = ServiceRegistry.get("TestService")
				expect(retrieved).to.equal(mockService)
			end)

			it("should return nil for unregistered service via get", function()
				local retrieved = ServiceRegistry.get("NonExistent")
				expect(retrieved).to.equal(nil)
			end)

			it("should error for unregistered service via getStrict", function()
				expect(function()
					ServiceRegistry.getStrict("NonExistent")
				end).to.throw()
			end)

			it("should not register duplicate services", function()
				local mockService1 = { Name = "TestService", value = 1 }
				local mockService2 = { Name = "TestService", value = 2 }
				ServiceRegistry.register("TestService", mockService1)
				ServiceRegistry.register("TestService", mockService2)
				local retrieved = ServiceRegistry.get("TestService")
				expect((retrieved :: any).value).to.equal(1)
			end)

			it("should track service count", function()
				expect(ServiceRegistry.getServiceCount()).to.equal(0)
				ServiceRegistry.register("Service1", { Name = "Service1" })
				expect(ServiceRegistry.getServiceCount()).to.equal(1)
				ServiceRegistry.register("Service2", { Name = "Service2" })
				expect(ServiceRegistry.getServiceCount()).to.equal(2)
			end)

			it("should list registered services", function()
				ServiceRegistry.register("ServiceA", { Name = "ServiceA" })
				ServiceRegistry.register("ServiceB", { Name = "ServiceB" })
				local names = ServiceRegistry.getRegisteredServices()
				expect(#names).to.equal(2)
			end)
		end)

		describe("initialization", function()
			it("should not be initialized before init called", function()
				ServiceRegistry.register("TestService", { Name = "TestService" })
				expect(ServiceRegistry.isInitialized("TestService")).to.equal(false)
			end)

			it("should be initialized after init called", function()
				local initCalled = false
				local mockService = {
					Name = "TestService",
					init = function()
						initCalled = true
					end,
				}
				ServiceRegistry.register("TestService", mockService)
				ServiceRegistry.initService("TestService")
				expect(ServiceRegistry.isInitialized("TestService")).to.equal(true)
				expect(initCalled).to.equal(true)
			end)

			it("should handle service without init method", function()
				ServiceRegistry.register("TestService", { Name = "TestService" })
				local result = ServiceRegistry.initService("TestService")
				expect(result).to.equal(true)
				expect(ServiceRegistry.isInitialized("TestService")).to.equal(true)
			end)

			it("should not re-init already initialized service", function()
				local initCount = 0
				local mockService = {
					Name = "TestService",
					init = function()
						initCount = initCount + 1
					end,
				}
				ServiceRegistry.register("TestService", mockService)
				ServiceRegistry.initService("TestService")
				ServiceRegistry.initService("TestService")
				expect(initCount).to.equal(1)
			end)
		end)

		describe("starting", function()
			it("should not be started before start called", function()
				ServiceRegistry.register("TestService", { Name = "TestService" })
				expect(ServiceRegistry.isStarted("TestService")).to.equal(false)
			end)

			it("should be started after start called", function()
				local startCalled = false
				local mockService = {
					Name = "TestService",
					start = function()
						startCalled = true
					end,
				}
				ServiceRegistry.register("TestService", mockService)
				ServiceRegistry.startService("TestService")
				expect(ServiceRegistry.isStarted("TestService")).to.equal(true)
				expect(startCalled).to.equal(true)
			end)

			it("should auto-init when starting uninitialized service", function()
				local initCalled = false
				local startCalled = false
				local mockService = {
					Name = "TestService",
					init = function()
						initCalled = true
					end,
					start = function()
						startCalled = true
					end,
				}
				ServiceRegistry.register("TestService", mockService)
				ServiceRegistry.startService("TestService")
				expect(initCalled).to.equal(true)
				expect(startCalled).to.equal(true)
			end)
		end)

		describe("cleanup", function()
			it("should call Cleanup method", function()
				local cleanupCalled = false
				local mockService = {
					Name = "TestService",
					Cleanup = function()
						cleanupCalled = true
					end,
				}
				ServiceRegistry.register("TestService", mockService)
				ServiceRegistry.startService("TestService")
				ServiceRegistry.cleanupService("TestService")
				expect(cleanupCalled).to.equal(true)
			end)

			it("should reset initialized state after cleanup", function()
				ServiceRegistry.register("TestService", { Name = "TestService" })
				ServiceRegistry.initService("TestService")
				expect(ServiceRegistry.isInitialized("TestService")).to.equal(true)
				ServiceRegistry.cleanupService("TestService")
				expect(ServiceRegistry.isInitialized("TestService")).to.equal(false)
			end)

			it("should reset started state after cleanup", function()
				ServiceRegistry.register("TestService", { Name = "TestService" })
				ServiceRegistry.startService("TestService")
				expect(ServiceRegistry.isStarted("TestService")).to.equal(true)
				ServiceRegistry.cleanupService("TestService")
				expect(ServiceRegistry.isStarted("TestService")).to.equal(false)
			end)
		end)

		describe("batch operations", function()
			it("should init all services", function()
				local initCount = 0
				local createMock = function(name)
					return {
						Name = name,
						init = function()
							initCount = initCount + 1
						end,
					}
				end
				ServiceRegistry.register("Service1", createMock("Service1"))
				ServiceRegistry.register("Service2", createMock("Service2"))
				ServiceRegistry.register("Service3", createMock("Service3"))
				ServiceRegistry.initAll()
				expect(initCount).to.equal(3)
			end)

			it("should start all services", function()
				local startCount = 0
				local createMock = function(name)
					return {
						Name = name,
						start = function()
							startCount = startCount + 1
						end,
					}
				end
				ServiceRegistry.register("Service1", createMock("Service1"))
				ServiceRegistry.register("Service2", createMock("Service2"))
				ServiceRegistry.startAll()
				expect(startCount).to.equal(2)
			end)

			it("should cleanup all services", function()
				local cleanupCount = 0
				local createMock = function(name)
					return {
						Name = name,
						Cleanup = function()
							cleanupCount = cleanupCount + 1
						end,
					}
				end
				ServiceRegistry.register("Service1", createMock("Service1"))
				ServiceRegistry.register("Service2", createMock("Service2"))
				ServiceRegistry.startAll()
				ServiceRegistry.cleanupAll()
				expect(cleanupCount).to.equal(2)
			end)
		end)

		describe("clear", function()
			it("should remove all services", function()
				ServiceRegistry.register("Service1", { Name = "Service1" })
				ServiceRegistry.register("Service2", { Name = "Service2" })
				expect(ServiceRegistry.getServiceCount()).to.equal(2)
				ServiceRegistry.clear()
				expect(ServiceRegistry.getServiceCount()).to.equal(0)
			end)

			it("should make previously registered services unavailable", function()
				ServiceRegistry.register("TestService", { Name = "TestService" })
				ServiceRegistry.clear()
				expect(ServiceRegistry.get("TestService")).to.equal(nil)
			end)
		end)
	end)
end
