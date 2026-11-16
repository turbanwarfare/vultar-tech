--!nocheck
return function()
	local ReplicatorService = require(script.Parent)

	describe("ReplicatorService", function()
		beforeEach(function()
			ReplicatorService:init()
		end)

		describe("state management", function()
			it("should start not complete", function()
				expect(ReplicatorService:IsComplete()).to.equal(false)
			end)

			it("should return valid stats structure", function()
				local stats = ReplicatorService:GetStats()
				expect(stats).to.be.ok()
				expect(type(stats.TotalItems)).to.equal("number")
				expect(type(stats.Replicated)).to.equal("number")
				expect(type(stats.Skipped)).to.equal("number")
				expect(type(stats.Failed)).to.equal("number")
				expect(type(stats.Errors)).to.equal("table")
			end)

			it("should initialize stats to zero", function()
				local stats = ReplicatorService:GetStats()
				expect(stats.TotalItems).to.equal(0)
				expect(stats.Replicated).to.equal(0)
				expect(stats.Skipped).to.equal(0)
				expect(stats.Failed).to.equal(0)
				expect(#stats.Errors).to.equal(0)
			end)
		end)

		describe("lifecycle", function()
			it("should have all required methods", function()
				expect(type(ReplicatorService.init)).to.equal("function")
				expect(type(ReplicatorService.start)).to.equal("function")
				expect(type(ReplicatorService.SetMainModule)).to.equal("function")
				expect(type(ReplicatorService.Replicate)).to.equal("function")
				expect(type(ReplicatorService.IsComplete)).to.equal("function")
				expect(type(ReplicatorService.GetStats)).to.equal("function")
			end)

			it("should not throw when init is called multiple times", function()
				expect(function()
					ReplicatorService:init()
					ReplicatorService:init()
					ReplicatorService:init()
				end).never.to.throw()
			end)

			it("should not throw when start is called", function()
				expect(function()
					ReplicatorService:start()
				end).never.to.throw()
			end)
		end)

		describe("replication without module", function()
			it("should handle replication without MainModule gracefully", function()
				local success, stats = ReplicatorService:Replicate()
				expect(type(success)).to.equal("boolean")
				expect(stats).to.be.ok()
			end)

			it("should reset stats on each replication call", function()
				ReplicatorService:Replicate()

				ReplicatorService:Replicate()
				local stats2 = ReplicatorService:GetStats()

				expect(stats2.TotalItems).to.equal(0)
			end)
		end)

		describe("SetMainModule", function()
			it("should accept an Instance", function()
				local folder = Instance.new("Folder")
				expect(function()
					ReplicatorService:SetMainModule(folder)
				end).never.to.throw()
				folder:Destroy()
			end)
		end)

		describe("replication with mock module", function()
			it("should handle empty source folders", function()
				local mockModule = Instance.new("Folder")
				mockModule.Name = "MockMainModule"

				local serverStorage = Instance.new("Folder")
				serverStorage.Name = "ServerStorage"
				serverStorage.Parent = mockModule

				ReplicatorService:SetMainModule(mockModule)
				local success, stats = ReplicatorService:Replicate()

				expect(type(success)).to.equal("boolean")
				expect(stats.TotalItems).to.equal(0)

				mockModule:Destroy()
			end)

			it("should track items in source folders", function()
				local mockModule = Instance.new("Folder")
				mockModule.Name = "MockMainModule"

				local serverStorage = Instance.new("Folder")
				serverStorage.Name = "ServerStorage"
				serverStorage.Parent = mockModule

				local testScript = Instance.new("ModuleScript")
				testScript.Name = "TestModule"
				testScript.Parent = serverStorage

				ReplicatorService:SetMainModule(mockModule)
				local _, stats = ReplicatorService:Replicate()

				expect(stats.TotalItems).to.be.ok()

				mockModule:Destroy()
			end)
		end)
	end)
end
