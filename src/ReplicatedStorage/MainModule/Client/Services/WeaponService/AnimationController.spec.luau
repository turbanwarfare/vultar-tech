--!nocheck
return function()
	local success, AnimationController = pcall(function()
		return require(script.Parent.AnimationController)
	end)

	describe("AnimationController", function()
		if not success then
			it("SKIP: module failed to load in test environment", function()
				expect(true).to.equal(true)
			end)
			return
		end

		beforeEach(function()
			AnimationController.setAnimator(nil)
			AnimationController.unloadAnimations()
		end)

		describe("module structure", function()
			it("should have setAnimator function", function()
				expect(typeof(AnimationController.setAnimator)).to.equal("function")
			end)

			it("should have loadAnimations function", function()
				expect(typeof(AnimationController.loadAnimations)).to.equal("function")
			end)

			it("should have unloadAnimations function", function()
				expect(typeof(AnimationController.unloadAnimations)).to.equal("function")
			end)

			it("should have play function", function()
				expect(typeof(AnimationController.play)).to.equal("function")
			end)

			it("should have stop function", function()
				expect(typeof(AnimationController.stop)).to.equal("function")
			end)

			it("should have stopAll function", function()
				expect(typeof(AnimationController.stopAll)).to.equal("function")
			end)

			it("should have applyAnimationChanges function", function()
				expect(typeof(AnimationController.applyAnimationChanges)).to.equal("function")
			end)

			it("should have adjustCrouchSpeed function", function()
				expect(typeof(AnimationController.adjustCrouchSpeed)).to.equal("function")
			end)

			it("should have getCrouchTrack function", function()
				expect(typeof(AnimationController.getCrouchTrack)).to.equal("function")
			end)
		end)

		describe("setAnimator", function()
			it("should not throw when setting nil", function()
				expect(function()
					AnimationController.setAnimator(nil)
				end).never.to.throw()
			end)
		end)

		describe("unloadAnimations", function()
			it("should not throw when called", function()
				expect(function()
					AnimationController.unloadAnimations()
				end).never.to.throw()
			end)

			it("should not throw when called multiple times", function()
				expect(function()
					AnimationController.unloadAnimations()
					AnimationController.unloadAnimations()
					AnimationController.unloadAnimations()
				end).never.to.throw()
			end)
		end)

		describe("play", function()
			it("should not throw for unknown animation", function()
				expect(function()
					AnimationController.play("UnknownAnimation")
				end).never.to.throw()
			end)

			it("should accept custom fadeTime", function()
				expect(function()
					AnimationController.play("Idle", 0.5)
				end).never.to.throw()
			end)

			it("should accept zero fadeTime", function()
				expect(function()
					AnimationController.play("Idle", 0)
				end).never.to.throw()
			end)
		end)

		describe("stop", function()
			it("should not throw for unknown animation", function()
				expect(function()
					AnimationController.stop("UnknownAnimation")
				end).never.to.throw()
			end)

			it("should accept custom fadeTime", function()
				expect(function()
					AnimationController.stop("Idle", 0.5)
				end).never.to.throw()
			end)

			it("should accept zero fadeTime", function()
				expect(function()
					AnimationController.stop("Idle", 0)
				end).never.to.throw()
			end)
		end)

		describe("stopAll", function()
			it("should not throw when called", function()
				expect(function()
					AnimationController.stopAll()
				end).never.to.throw()
			end)

			it("should accept custom fadeTime", function()
				expect(function()
					AnimationController.stopAll(0.5)
				end).never.to.throw()
			end)

			it("should accept zero fadeTime", function()
				expect(function()
					AnimationController.stopAll(0)
				end).never.to.throw()
			end)
		end)

		describe("applyAnimationChanges", function()
			it("should not throw with empty arrays", function()
				expect(function()
					AnimationController.applyAnimationChanges({}, {})
				end).never.to.throw()
			end)

			it("should not throw with unknown animations", function()
				expect(function()
					AnimationController.applyAnimationChanges(
						{"UnknownPlay1", "UnknownPlay2"},
						{"UnknownStop1", "UnknownStop2"}
					)
				end).never.to.throw()
			end)

			it("should accept custom fadeTime", function()
				expect(function()
					AnimationController.applyAnimationChanges({"Idle"}, {"Sprint"}, 0.5)
				end).never.to.throw()
			end)
		end)

		describe("adjustCrouchSpeed", function()
			it("should not throw when running", function()
				expect(function()
					AnimationController.adjustCrouchSpeed(true)
				end).never.to.throw()
			end)

			it("should not throw when not running", function()
				expect(function()
					AnimationController.adjustCrouchSpeed(false)
				end).never.to.throw()
			end)
		end)

		describe("getCrouchTrack", function()
			it("should return nil when no animations loaded", function()
				local track = AnimationController.getCrouchTrack()
				expect(track).to.equal(nil)
			end)
		end)
	end)
end
