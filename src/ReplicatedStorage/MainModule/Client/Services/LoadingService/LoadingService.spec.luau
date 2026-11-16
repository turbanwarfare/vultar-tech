--!nocheck
return function()
	local LoadingService = require(script.Parent)

	describe("LoadingService", function()
		afterEach(function()
			if LoadingService:IsActive() then
				pcall(function()
					LoadingService:Hide()
				end)
			end
		end)

		describe("state management", function()
			it("should start inactive", function()
				expect(LoadingService:IsActive()).to.equal(false)
			end)

			it("should start with zero progress", function()
				expect(LoadingService:GetProgress()).to.equal(0)
			end)

			it("should track progress correctly", function()
				LoadingService:SetProgress(0.5, "Testing")
				expect(LoadingService:GetProgress()).to.equal(0.5)
			end)

			it("should clamp progress between 0 and 1", function()
				LoadingService:SetProgress(-0.5, "Negative")
				expect(LoadingService:GetProgress()).to.equal(0)

				LoadingService:SetProgress(1.5, "Over")
				expect(LoadingService:GetProgress()).to.equal(1)
			end)

			it("should update progress incrementally", function()
				LoadingService:SetProgress(0.25)
				expect(LoadingService:GetProgress()).to.equal(0.25)

				LoadingService:SetProgress(0.5)
				expect(LoadingService:GetProgress()).to.equal(0.5)

				LoadingService:SetProgress(0.75)
				expect(LoadingService:GetProgress()).to.equal(0.75)

				LoadingService:SetProgress(1)
				expect(LoadingService:GetProgress()).to.equal(1)
			end)
		end)

		describe("lifecycle", function()
			it("should have all required methods", function()
				expect(type(LoadingService.init)).to.equal("function")
				expect(type(LoadingService.start)).to.equal("function")
				expect(type(LoadingService.Show)).to.equal("function")
				expect(type(LoadingService.Hide)).to.equal("function")
				expect(type(LoadingService.SetProgress)).to.equal("function")
				expect(type(LoadingService.IsActive)).to.equal("function")
				expect(type(LoadingService.GetProgress)).to.equal("function")
				expect(type(LoadingService.WaitForComplete)).to.equal("function")
			end)

			it("should not throw when init is called", function()
				expect(function()
					LoadingService:init()
				end).never.to.throw()
			end)

			it("should not throw when start is called", function()
				expect(function()
					LoadingService:start()
				end).never.to.throw()
			end)
		end)

		describe("progress simulation", function()
			it("should handle rapid progress updates", function()
				for i = 1, 100 do
					LoadingService:SetProgress(i / 100)
				end
				expect(LoadingService:GetProgress()).to.equal(1)
			end)

			it("should handle progress with step names", function()
				local steps = {
					{ 0.1, "Loading assets" },
					{ 0.3, "Initializing services" },
					{ 0.5, "Setting up game" },
					{ 0.8, "Final preparations" },
					{ 1.0, "Complete" },
				}

				for _, step in steps do
					LoadingService:SetProgress(step[1], step[2])
					expect(LoadingService:GetProgress()).to.equal(step[1])
				end
			end)

			it("should handle nil step name without error", function()
				expect(function()
					LoadingService:SetProgress(0.5, nil)
				end).never.to.throw()
				expect(LoadingService:GetProgress()).to.equal(0.5)
			end)
		end)
	end)
end
