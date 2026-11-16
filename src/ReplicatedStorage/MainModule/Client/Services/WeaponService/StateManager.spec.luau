--!nocheck
return function()
	local StateManager = require(script.Parent.StateManager)

	describe("StateManager", function()
		describe("createDefaultFlags", function()
			it("should return a table with all flags set to false", function()
				local flags = StateManager.createDefaultFlags()
				expect(flags.isFiring).to.equal(false)
				expect(flags.isSprinting).to.equal(false)
				expect(flags.isCrouching).to.equal(false)
				expect(flags.isZooming).to.equal(false)
				expect(flags.isSaluting).to.equal(false)
			end)

			it("should return a new table each time", function()
				local flags1 = StateManager.createDefaultFlags()
				local flags2 = StateManager.createDefaultFlags()
				expect(flags1).never.to.equal(flags2)
			end)
		end)

		describe("computeStateKey", function()
			it("should return empty string for default flags", function()
				local flags = StateManager.createDefaultFlags()
				expect(StateManager.computeStateKey(flags)).to.equal("")
			end)

			it("should return 'f' for firing only", function()
				local flags = StateManager.createDefaultFlags()
				flags.isFiring = true
				expect(StateManager.computeStateKey(flags)).to.equal("f")
			end)

			it("should return 's' for sprinting only", function()
				local flags = StateManager.createDefaultFlags()
				flags.isSprinting = true
				expect(StateManager.computeStateKey(flags)).to.equal("s")
			end)

			it("should return 'c' for crouching only", function()
				local flags = StateManager.createDefaultFlags()
				flags.isCrouching = true
				expect(StateManager.computeStateKey(flags)).to.equal("c")
			end)

			it("should return 'z' for zooming only", function()
				local flags = StateManager.createDefaultFlags()
				flags.isZooming = true
				expect(StateManager.computeStateKey(flags)).to.equal("z")
			end)

			it("should return 'e' for saluting only", function()
				local flags = StateManager.createDefaultFlags()
				flags.isSaluting = true
				expect(StateManager.computeStateKey(flags)).to.equal("e")
			end)

			it("should combine multiple flags in correct order", function()
				local flags = StateManager.createDefaultFlags()
				flags.isFiring = true
				flags.isSprinting = true
				flags.isCrouching = true
				expect(StateManager.computeStateKey(flags)).to.equal("fsc")
			end)

			it("should combine all flags", function()
				local flags = {
					isFiring = true,
					isSprinting = true,
					isCrouching = true,
					isZooming = true,
					isSaluting = true,
				}
				expect(StateManager.computeStateKey(flags)).to.equal("fscze")
			end)
		end)

		describe("computeState", function()
			local mockSpeeds = {
				Walk = 16,
				Sprint = 24,
				Crouch = 8,
				Zoom = 12,
			}

			it("should return Idle state for default flags", function()
				local flags = StateManager.createDefaultFlags()
				local result = StateManager.computeState(flags, mockSpeeds)
				expect(result.state).to.equal("Idle")
				expect(result.speed).to.equal(16)
			end)

			it("should return Sprinting state when sprinting", function()
				local flags = StateManager.createDefaultFlags()
				flags.isSprinting = true
				local result = StateManager.computeState(flags, mockSpeeds)
				expect(result.state).to.equal("Sprinting")
				expect(result.speed).to.equal(24)
			end)

			it("should return Crouching state when crouching", function()
				local flags = StateManager.createDefaultFlags()
				flags.isCrouching = true
				local result = StateManager.computeState(flags, mockSpeeds)
				expect(result.state).to.equal("Crouching")
				expect(result.speed).to.equal(8)
			end)

			it("should return Idle state with zoom speed when zooming", function()
				local flags = StateManager.createDefaultFlags()
				flags.isZooming = true
				local result = StateManager.computeState(flags, mockSpeeds)
				expect(result.state).to.equal("Idle")
				expect(result.speed).to.equal(12)
			end)

			it("should return Saluting state when saluting", function()
				local flags = StateManager.createDefaultFlags()
				flags.isSaluting = true
				local result = StateManager.computeState(flags, mockSpeeds)
				expect(result.state).to.equal("Saluting")
			end)

			it("should prioritize saluting over other states", function()
				local flags = {
					isFiring = true,
					isSprinting = true,
					isCrouching = false,
					isZooming = false,
					isSaluting = true,
				}
				local result = StateManager.computeState(flags, mockSpeeds)
				expect(result.state).to.equal("Saluting")
			end)

			it("should return Crouching when firing while crouching", function()
				local flags = StateManager.createDefaultFlags()
				flags.isFiring = true
				flags.isCrouching = true
				local result = StateManager.computeState(flags, mockSpeeds)
				expect(result.state).to.equal("Crouching")
				expect(result.speed).to.equal(8)
			end)

			it("should return Sprinting when firing while sprinting", function()
				local flags = StateManager.createDefaultFlags()
				flags.isFiring = true
				flags.isSprinting = true
				local result = StateManager.computeState(flags, mockSpeeds)
				expect(result.state).to.equal("Sprinting")
				expect(result.speed).to.equal(24)
			end)

			it("should return Idle with zoom speed when firing and zooming", function()
				local flags = StateManager.createDefaultFlags()
				flags.isFiring = true
				flags.isZooming = true
				local result = StateManager.computeState(flags, mockSpeeds)
				expect(result.state).to.equal("Idle")
				expect(result.speed).to.equal(12)
			end)

			it("should return animations table", function()
				local flags = StateManager.createDefaultFlags()
				local result = StateManager.computeState(flags, mockSpeeds)
				expect(result.animations).to.be.a("table")
				expect(result.animations.play).to.be.a("table")
				expect(result.animations.stop).to.be.a("table")
			end)

			it("should include Idle in play animations for default state", function()
				local flags = StateManager.createDefaultFlags()
				local result = StateManager.computeState(flags, mockSpeeds)
				expect(table.find(result.animations.play, "Idle")).to.be.ok()
			end)

			it("should include Sprint in play animations when sprinting", function()
				local flags = StateManager.createDefaultFlags()
				flags.isSprinting = true
				local result = StateManager.computeState(flags, mockSpeeds)
				expect(table.find(result.animations.play, "Sprint")).to.be.ok()
			end)

			it("should include Crouch in play animations when crouching", function()
				local flags = StateManager.createDefaultFlags()
				flags.isCrouching = true
				local result = StateManager.computeState(flags, mockSpeeds)
				expect(table.find(result.animations.play, "Crouch")).to.be.ok()
			end)

			it("should include Salute in play animations when saluting", function()
				local flags = StateManager.createDefaultFlags()
				flags.isSaluting = true
				local result = StateManager.computeState(flags, mockSpeeds)
				expect(table.find(result.animations.play, "Salute")).to.be.ok()
			end)

			it("should stop Sprint when idle", function()
				local flags = StateManager.createDefaultFlags()
				local result = StateManager.computeState(flags, mockSpeeds)
				expect(table.find(result.animations.stop, "Sprint")).to.be.ok()
			end)

			it("should stop Salute when not saluting", function()
				local flags = StateManager.createDefaultFlags()
				local result = StateManager.computeState(flags, mockSpeeds)
				expect(table.find(result.animations.stop, "Salute")).to.be.ok()
			end)
		end)

		describe("applyStartFiring", function()
			it("should set isFiring to true", function()
				local flags = StateManager.createDefaultFlags()
				local newFlags = StateManager.applyStartFiring(flags)
				expect(newFlags.isFiring).to.equal(true)
			end)

			it("should stop sprinting by default", function()
				local flags = StateManager.createDefaultFlags()
				flags.isSprinting = true
				local newFlags = StateManager.applyStartFiring(flags)
				expect(newFlags.isSprinting).to.equal(false)
			end)

			it("should keep sprinting if canSprintWhileFiring is true", function()
				local flags = StateManager.createDefaultFlags()
				flags.isSprinting = true
				local newFlags = StateManager.applyStartFiring(flags, true)
				expect(newFlags.isSprinting).to.equal(true)
			end)

			it("should not modify original flags", function()
				local flags = StateManager.createDefaultFlags()
				StateManager.applyStartFiring(flags)
				expect(flags.isFiring).to.equal(false)
			end)
		end)

		describe("applyStopFiring", function()
			it("should set isFiring to false", function()
				local flags = StateManager.createDefaultFlags()
				flags.isFiring = true
				local newFlags = StateManager.applyStopFiring(flags)
				expect(newFlags.isFiring).to.equal(false)
			end)

			it("should preserve other flags", function()
				local flags = StateManager.createDefaultFlags()
				flags.isFiring = true
				flags.isCrouching = true
				local newFlags = StateManager.applyStopFiring(flags)
				expect(newFlags.isCrouching).to.equal(true)
			end)
		end)

		describe("applyToggleSprint", function()
			it("should toggle sprint on", function()
				local flags = StateManager.createDefaultFlags()
				local newFlags = StateManager.applyToggleSprint(flags)
				expect(newFlags).to.be.ok()
				expect(newFlags.isSprinting).to.equal(true)
			end)

			it("should toggle sprint off", function()
				local flags = StateManager.createDefaultFlags()
				flags.isSprinting = true
				local newFlags = StateManager.applyToggleSprint(flags)
				expect(newFlags).to.be.ok()
				expect(newFlags.isSprinting).to.equal(false)
			end)

			it("should disable crouching when enabling sprint", function()
				local flags = StateManager.createDefaultFlags()
				flags.isCrouching = true
				local newFlags = StateManager.applyToggleSprint(flags)
				expect(newFlags).to.be.ok()
				expect(newFlags.isSprinting).to.equal(true)
				expect(newFlags.isCrouching).to.equal(false)
			end)

			it("should return nil if firing and cannot sprint while firing", function()
				local flags = StateManager.createDefaultFlags()
				flags.isFiring = true
				local newFlags = StateManager.applyToggleSprint(flags, false)
				expect(newFlags).to.equal(nil)
			end)

			it("should allow toggle if firing and can sprint while firing", function()
				local flags = StateManager.createDefaultFlags()
				flags.isFiring = true
				local newFlags = StateManager.applyToggleSprint(flags, true)
				expect(newFlags).to.be.ok()
				expect(newFlags.isSprinting).to.equal(true)
			end)
		end)

		describe("applyToggleCrouch", function()
			it("should toggle crouch on", function()
				local flags = StateManager.createDefaultFlags()
				local newFlags = StateManager.applyToggleCrouch(flags)
				expect(newFlags.isCrouching).to.equal(true)
			end)

			it("should toggle crouch off", function()
				local flags = StateManager.createDefaultFlags()
				flags.isCrouching = true
				local newFlags = StateManager.applyToggleCrouch(flags)
				expect(newFlags.isCrouching).to.equal(false)
			end)

			it("should disable sprinting when enabling crouch", function()
				local flags = StateManager.createDefaultFlags()
				flags.isSprinting = true
				local newFlags = StateManager.applyToggleCrouch(flags)
				expect(newFlags.isCrouching).to.equal(true)
				expect(newFlags.isSprinting).to.equal(false)
			end)
		end)

		describe("applyToggleZoom", function()
			it("should toggle zoom on", function()
				local flags = StateManager.createDefaultFlags()
				local newFlags = StateManager.applyToggleZoom(flags)
				expect(newFlags.isZooming).to.equal(true)
			end)

			it("should toggle zoom off", function()
				local flags = StateManager.createDefaultFlags()
				flags.isZooming = true
				local newFlags = StateManager.applyToggleZoom(flags)
				expect(newFlags.isZooming).to.equal(false)
			end)
		end)

		describe("applyStartSalute", function()
			it("should set saluting to true", function()
				local flags = StateManager.createDefaultFlags()
				local newFlags = StateManager.applyStartSalute(flags)
				expect(newFlags).to.be.ok()
				expect(newFlags.isSaluting).to.equal(true)
			end)

			it("should return nil if firing", function()
				local flags = StateManager.createDefaultFlags()
				flags.isFiring = true
				local newFlags = StateManager.applyStartSalute(flags)
				expect(newFlags).to.equal(nil)
			end)
		end)

		describe("applyStopSalute", function()
			it("should set saluting to false", function()
				local flags = StateManager.createDefaultFlags()
				flags.isSaluting = true
				local newFlags = StateManager.applyStopSalute(flags)
				expect(newFlags).to.be.ok()
				expect(newFlags.isSaluting).to.equal(false)
			end)

			it("should return nil if not saluting", function()
				local flags = StateManager.createDefaultFlags()
				local newFlags = StateManager.applyStopSalute(flags)
				expect(newFlags).to.equal(nil)
			end)
		end)

		describe("applyJump", function()
			it("should disable crouching when jumping", function()
				local flags = StateManager.createDefaultFlags()
				flags.isCrouching = true
				local newFlags = StateManager.applyJump(flags)
				expect(newFlags).to.be.ok()
				expect(newFlags.isCrouching).to.equal(false)
			end)

			it("should return nil if not crouching", function()
				local flags = StateManager.createDefaultFlags()
				local newFlags = StateManager.applyJump(flags)
				expect(newFlags).to.equal(nil)
			end)
		end)
	end)
end
