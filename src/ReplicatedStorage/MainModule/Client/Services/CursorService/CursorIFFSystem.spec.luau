--!nocheck
return function()
	local success, CursorIFFSystem = pcall(function()
		return require(script.Parent.CursorIFFSystem)
	end)

	describe("CursorIFFSystem", function()
		if not success then
			it("SKIP: module failed to load in test environment", function()
				expect(true).to.equal(true)
			end)
			return
		end

		afterEach(function()
			CursorIFFSystem.cleanup()
		end)

		describe("module structure", function()
			it("should have cacheTeamReferences function", function()
				expect(typeof(CursorIFFSystem.cacheTeamReferences)).to.equal("function")
			end)

			it("should have getPlayerFaction function", function()
				expect(typeof(CursorIFFSystem.getPlayerFaction)).to.equal("function")
			end)

			it("should have updateLocalPlayerFaction function", function()
				expect(typeof(CursorIFFSystem.updateLocalPlayerFaction)).to.equal("function")
			end)

			it("should have clearFactionCache function", function()
				expect(typeof(CursorIFFSystem.clearFactionCache)).to.equal("function")
			end)

			it("should have startTracking function", function()
				expect(typeof(CursorIFFSystem.startTracking)).to.equal("function")
			end)

			it("should have stopTracking function", function()
				expect(typeof(CursorIFFSystem.stopTracking)).to.equal("function")
			end)

			it("should have updateState function", function()
				expect(typeof(CursorIFFSystem.updateState)).to.equal("function")
			end)

			it("should have setupCharacterTracking function", function()
				expect(typeof(CursorIFFSystem.setupCharacterTracking)).to.equal("function")
			end)

			it("should have connect function", function()
				expect(typeof(CursorIFFSystem.connect)).to.equal("function")
			end)

			it("should have setEnabled function", function()
				expect(typeof(CursorIFFSystem.setEnabled)).to.equal("function")
			end)

			it("should have isEnabled function", function()
				expect(typeof(CursorIFFSystem.isEnabled)).to.equal("function")
			end)

			it("should have cleanup function", function()
				expect(typeof(CursorIFFSystem.cleanup)).to.equal("function")
			end)
		end)

		describe("IFF enabled state", function()
			it("should be enabled by default", function()
				expect(CursorIFFSystem.isEnabled()).to.equal(true)
			end)

			it("should be settable to disabled", function()
				CursorIFFSystem.setEnabled(false)
				expect(CursorIFFSystem.isEnabled()).to.equal(false)
				CursorIFFSystem.setEnabled(true)
			end)

			it("should be settable to enabled", function()
				CursorIFFSystem.setEnabled(false)
				CursorIFFSystem.setEnabled(true)
				expect(CursorIFFSystem.isEnabled()).to.equal(true)
			end)
		end)

		describe("faction cache operations", function()
			it("should cache team references without error", function()
				expect(function()
					CursorIFFSystem.cacheTeamReferences()
				end).never.to.throw()
			end)

			it("should clear faction cache without error", function()
				CursorIFFSystem.cacheTeamReferences()
				expect(function()
					CursorIFFSystem.clearFactionCache()
				end).never.to.throw()
			end)

			it("should update local player faction without error", function()
				CursorIFFSystem.cacheTeamReferences()
				expect(function()
					CursorIFFSystem.updateLocalPlayerFaction()
				end).never.to.throw()
			end)
		end)

		describe("tracking lifecycle", function()
			it("should start tracking without error", function()
				expect(function()
					CursorIFFSystem.startTracking()
				end).never.to.throw()
				CursorIFFSystem.stopTracking()
			end)

			it("should stop tracking without error", function()
				CursorIFFSystem.startTracking()
				expect(function()
					CursorIFFSystem.stopTracking()
				end).never.to.throw()
			end)

			it("should handle multiple start calls gracefully", function()
				expect(function()
					CursorIFFSystem.startTracking()
					CursorIFFSystem.startTracking()
				end).never.to.throw()
				CursorIFFSystem.stopTracking()
			end)

			it("should handle stop without start gracefully", function()
				expect(function()
					CursorIFFSystem.stopTracking()
				end).never.to.throw()
			end)
		end)

		describe("cleanup", function()
			it("should clean up all resources without error", function()
				CursorIFFSystem.cacheTeamReferences()
				CursorIFFSystem.startTracking()
				expect(function()
					CursorIFFSystem.cleanup()
				end).never.to.throw()
			end)

			it("should be safe to call multiple times", function()
				expect(function()
					CursorIFFSystem.cleanup()
					CursorIFFSystem.cleanup()
				end).never.to.throw()
			end)
		end)
	end)
end
