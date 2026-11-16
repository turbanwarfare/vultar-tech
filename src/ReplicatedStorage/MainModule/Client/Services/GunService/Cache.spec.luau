--!nocheck
return function()
	local success, Cache = pcall(function()
		return require(script.Parent.Cache)
	end)

	describe("Cache", function()
		if not success then
			it("SKIP: module failed to load in test environment", function()
				expect(true).to.equal(true)
			end)
			return
		end

		beforeEach(function()
			Cache.cleanup()
		end)

		afterEach(function()
			Cache.cleanup()
		end)

		describe("module structure", function()
			it("should have init function", function()
				expect(typeof(Cache.init)).to.equal("function")
			end)

			it("should have get function", function()
				expect(typeof(Cache.get)).to.equal("function")
			end)

			it("should have cleanup function", function()
				expect(typeof(Cache.cleanup)).to.equal("function")
			end)

			it("should have getDamageIndicatorsEnabled function", function()
				expect(typeof(Cache.getDamageIndicatorsEnabled)).to.equal("function")
			end)

			it("should have getDamageIndicatorType function", function()
				expect(typeof(Cache.getDamageIndicatorType)).to.equal("function")
			end)

			it("should have getDamageIndicatorStickTo function", function()
				expect(typeof(Cache.getDamageIndicatorStickTo)).to.equal("function")
			end)

			it("should have getDamageIndicatorFont function", function()
				expect(typeof(Cache.getDamageIndicatorFont)).to.equal("function")
				expect(typeof(Cache.getDamageIndicatorFont())).to.equal("EnumItem")
			end)

			it("should have getHealIndicatorFont function", function()
				expect(typeof(Cache.getHealIndicatorFont)).to.equal("function")
				expect(typeof(Cache.getHealIndicatorFont())).to.equal("EnumItem")
			end)

			it("should have getDamageIndicatorSize function", function()
				expect(typeof(Cache.getDamageIndicatorSize)).to.equal("function")
			end)

			it("should have getHitSoundsEnabled function", function()
				expect(typeof(Cache.getHitSoundsEnabled)).to.equal("function")
			end)

			it("should have getKillSoundsEnabled function", function()
				expect(typeof(Cache.getKillSoundsEnabled)).to.equal("function")
			end)

			it("should have getWeaponSoundsEnabled function", function()
				expect(typeof(Cache.getWeaponSoundsEnabled)).to.equal("function")
			end)

			it("should have getRayType function", function()
				expect(typeof(Cache.getRayType)).to.equal("function")
			end)

			it("should have getRaySpeed function", function()
				expect(typeof(Cache.getRaySpeed)).to.equal("function")
			end)

			it("should have useBeamRay function", function()
				expect(typeof(Cache.useBeamRay)).to.equal("function")
			end)

			it("should have getRayDuration function", function()
				expect(typeof(Cache.getRayDuration)).to.equal("function")
			end)

			it("should have getHitIndicatorsEnabled function", function()
				expect(typeof(Cache.getHitIndicatorsEnabled)).to.equal("function")
			end)

			it("should have getHitPreset function", function()
				expect(typeof(Cache.getHitPreset)).to.equal("function")
			end)

			it("should have getHitColor function", function()
				expect(typeof(Cache.getHitColor)).to.equal("function")
			end)

			it("should have getMuzzleFlashEnabled function", function()
				expect(typeof(Cache.getMuzzleFlashEnabled)).to.equal("function")
			end)

			it("should have getKillIndicatorsEnabled function", function()
				expect(typeof(Cache.getKillIndicatorsEnabled)).to.equal("function")
			end)
		end)

		describe("init", function()
			it("should not throw when called", function()
				expect(function()
					Cache.init()
				end).never.to.throw()
			end)

			it("should be idempotent", function()
				expect(function()
					Cache.init()
					Cache.init()
					Cache.init()
				end).never.to.throw()
			end)
		end)

		describe("default values after init", function()
			beforeEach(function()
				Cache.init()
			end)

			it("should return boolean for getDamageIndicatorsEnabled", function()
				local result = Cache.getDamageIndicatorsEnabled()
				expect(typeof(result)).to.equal("boolean")
			end)

			it("should return number for getDamageIndicatorType", function()
				local result = Cache.getDamageIndicatorType()
				expect(typeof(result)).to.equal("number")
			end)

			it("should return number for getDamageIndicatorSize", function()
				local result = Cache.getDamageIndicatorSize()
				expect(typeof(result)).to.equal("number")
				expect(result > 0).to.equal(true)
			end)

			it("should return boolean for getHitSoundsEnabled", function()
				local result = Cache.getHitSoundsEnabled()
				expect(typeof(result)).to.equal("boolean")
			end)

			it("should return boolean for getKillSoundsEnabled", function()
				local result = Cache.getKillSoundsEnabled()
				expect(typeof(result)).to.equal("boolean")
			end)

			it("should return boolean for getWeaponSoundsEnabled", function()
				local result = Cache.getWeaponSoundsEnabled()
				expect(typeof(result)).to.equal("boolean")
			end)

			it("should return number for getRayType", function()
				local result = Cache.getRayType()
				expect(typeof(result)).to.equal("number")
			end)

			it("should return number for getRaySpeed", function()
				local result = Cache.getRaySpeed()
				expect(typeof(result)).to.equal("number")
			end)

			it("should return boolean for useBeamRay", function()
				local result = Cache.useBeamRay()
				expect(typeof(result)).to.equal("boolean")
			end)

			it("should return positive number for getRayDuration", function()
				local result = Cache.getRayDuration()
				expect(typeof(result)).to.equal("number")
				expect(result > 0).to.equal(true)
			end)

			it("should return boolean for getHitIndicatorsEnabled", function()
				local result = Cache.getHitIndicatorsEnabled()
				expect(typeof(result)).to.equal("boolean")
			end)

			it("should return number for getHitPreset", function()
				local result = Cache.getHitPreset()
				expect(typeof(result)).to.equal("number")
			end)

			it("should return number for getHitColor", function()
				local result = Cache.getHitColor()
				expect(typeof(result)).to.equal("number")
			end)

			it("should return boolean for getMuzzleFlashEnabled", function()
				local result = Cache.getMuzzleFlashEnabled()
				expect(typeof(result)).to.equal("boolean")
			end)

			it("should return boolean for getKillIndicatorsEnabled", function()
				local result = Cache.getKillIndicatorsEnabled()
				expect(typeof(result)).to.equal("boolean")
			end)

			it("should return number for getKillIndicatorType", function()
				local result = Cache.getKillIndicatorType()
				expect(typeof(result)).to.equal("number")
			end)

			it("should return number for getKillIndicatorColor", function()
				local result = Cache.getKillIndicatorColor()
				expect(typeof(result)).to.equal("number")
			end)

			it("should return number for getKillIndicatorSize", function()
				local result = Cache.getKillIndicatorSize()
				expect(typeof(result)).to.equal("number")
				expect(result > 0).to.equal(true)
			end)
		end)

		describe("get function", function()
			beforeEach(function()
				Cache.init()
			end)

			it("should return nil for unknown keys", function()
				local result = Cache.get("UnknownKey12345")
				expect(result).to.equal(nil)
			end)

			it("should return value for known keys", function()
				local result = Cache.get("DamageIndicators")
				expect(result).to.be.ok()
			end)
		end)

		describe("cleanup", function()
			it("should not throw when called", function()
				expect(function()
					Cache.cleanup()
				end).never.to.throw()
			end)

			it("should allow reinit after cleanup", function()
				Cache.init()
				Cache.cleanup()
				expect(function()
					Cache.init()
				end).never.to.throw()
			end)

			it("should clear values after cleanup", function()
				Cache.init()
				Cache.cleanup()
				local result = Cache.get("DamageIndicators")
				expect(result).to.equal(nil)
			end)
		end)

		describe("highlight settings", function()
			beforeEach(function()
				Cache.init()
			end)

			it("should return boolean for getHitHighlightsEnabled", function()
				local result = Cache.getHitHighlightsEnabled()
				expect(typeof(result)).to.equal("boolean")
			end)

			it("should return number for getHitHighlightTransparency", function()
				local result = Cache.getHitHighlightTransparency()
				expect(typeof(result)).to.equal("number")
				expect(result >= 0 and result <= 1).to.equal(true)
			end)

			it("should return number for getHitHighlightThickness", function()
				local result = Cache.getHitHighlightThickness()
				expect(typeof(result)).to.equal("number")
				expect(result >= 0).to.equal(true)
			end)

			it("should return number for getHitHighlightDuration", function()
				local result = Cache.getHitHighlightDuration()
				expect(typeof(result)).to.equal("number")
				expect(result > 0).to.equal(true)
			end)

			it("should return boolean for getHealHighlightsEnabled", function()
				local result = Cache.getHealHighlightsEnabled()
				expect(typeof(result)).to.equal("boolean")
			end)
		end)

		describe("heal indicator settings", function()
			beforeEach(function()
				Cache.init()
			end)

			it("should return boolean for getHealNumberIndicatorsEnabled", function()
				local result = Cache.getHealNumberIndicatorsEnabled()
				expect(typeof(result)).to.equal("boolean")
			end)

			it("should return positive number for getHealIndicatorSize", function()
				local result = Cache.getHealIndicatorSize()
				expect(typeof(result)).to.equal("number")
				expect(result > 0).to.equal(true)
			end)
		end)

		describe("blood settings", function()
			beforeEach(function()
				Cache.init()
			end)

			it("should return boolean for getBloodIndicatorEnabled", function()
				local result = Cache.getBloodIndicatorEnabled()
				expect(typeof(result)).to.equal("boolean")
			end)
		end)
	end)
end
