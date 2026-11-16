--!nocheck
--!strict

local Signal = require(script.Parent.Signal)

return function()
	describe("Signal", function()
		describe("new", function()
			it("should create a new signal", function()
				local signal = Signal.new()
				expect(signal).to.be.ok()
				expect(signal.Connect).to.be.a("function")
				expect(signal.Fire).to.be.a("function")
				signal:Destroy()
			end)
		end)

		describe("Connect", function()
			it("should connect a callback", function()
				local signal = Signal.new()
				local called = false

				signal:Connect(function()
					called = true
				end)

				signal:Fire()
				task.wait()

				expect(called).to.equal(true)
				signal:Destroy()
			end)

			it("should pass arguments to callback", function()
				local signal = Signal.new()
				local receivedA, receivedB = nil, nil

				signal:Connect(function(a, b)
					receivedA = a
					receivedB = b
				end)

				signal:Fire(42, "hello")
				task.wait()

				expect(receivedA).to.equal(42)
				expect(receivedB).to.equal("hello")
				signal:Destroy()
			end)

			it("should support multiple connections", function()
				local signal = Signal.new()
				local count = 0

				signal:Connect(function()
					count = count + 1
				end)

				signal:Connect(function()
					count = count + 1
				end)

				signal:Fire()
				task.wait()

				expect(count).to.equal(2)
				signal:Destroy()
			end)

			it("should return a connection object", function()
				local signal = Signal.new()
				local connection = signal:Connect(function() end)

				expect(connection).to.be.ok()
				expect(connection.Disconnect).to.be.a("function")
				expect(connection.Connected).to.equal(true)

				signal:Destroy()
			end)
		end)

		describe("Disconnect", function()
			it("should disconnect a callback", function()
				local signal = Signal.new()
				local called = false

				local connection = signal:Connect(function()
					called = true
				end)

				connection:Disconnect()
				signal:Fire()
				task.wait()

				expect(called).to.equal(false)
				expect(connection.Connected).to.equal(false)
				signal:Destroy()
			end)

			it("should handle multiple disconnects safely", function()
				local signal = Signal.new()
				local connection = signal:Connect(function() end)

				connection:Disconnect()
				connection:Disconnect()

				expect(connection.Connected).to.equal(false)
				signal:Destroy()
			end)
		end)

		describe("Once", function()
			it("should only fire once", function()
				local signal = Signal.new()
				local count = 0

				signal:Once(function()
					count = count + 1
				end)

				signal:Fire()
				task.wait()
				signal:Fire()
				task.wait()

				expect(count).to.equal(1)
				signal:Destroy()
			end)
		end)

		describe("DisconnectAll", function()
			it("should disconnect all connections", function()
				local signal = Signal.new()
				local count = 0

				signal:Connect(function()
					count = count + 1
				end)

				signal:Connect(function()
					count = count + 1
				end)

				signal:DisconnectAll()
				signal:Fire()
				task.wait()

				expect(count).to.equal(0)
				signal:Destroy()
			end)
		end)

		describe("Destroy", function()
			it("should prevent new connections after destroy", function()
				local signal = Signal.new()
				signal:Destroy()

				expect(function()
					signal:Connect(function() end)
				end).to.throw()
			end)

			it("should not fire after destroy", function()
				local signal = Signal.new()
				local called = false

				signal:Connect(function()
					called = true
				end)

				signal:Destroy()
				signal:Fire()
				task.wait()

				expect(called).to.equal(false)
			end)
		end)
	end)
end
