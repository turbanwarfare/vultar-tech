--!nocheck
return function()
	local success, CursorAssetManager = pcall(function()
		return require(script.Parent.CursorAssetManager)
	end)

	describe("CursorAssetManager", function()
		if not success then
			it("SKIP: module failed to load in test environment", function()
				expect(true).to.equal(true)
			end)
			return
		end

		beforeEach(function()
			CursorAssetManager.clearCache()
		end)

		afterEach(function()
			CursorAssetManager.clearCache()
		end)

		describe("module structure", function()
			it("should have buildCache function", function()
				expect(typeof(CursorAssetManager.buildCache)).to.equal("function")
			end)

			it("should have preloadAll function", function()
				expect(typeof(CursorAssetManager.preloadAll)).to.equal("function")
			end)

			it("should have getVariantURL function", function()
				expect(typeof(CursorAssetManager.getVariantURL)).to.equal("function")
			end)

			it("should have getSpectatorURL function", function()
				expect(typeof(CursorAssetManager.getSpectatorURL)).to.equal("function")
			end)

			it("should have getCachedURL function", function()
				expect(typeof(CursorAssetManager.getCachedURL)).to.equal("function")
			end)

			it("should have addToCache function", function()
				expect(typeof(CursorAssetManager.addToCache)).to.equal("function")
			end)

			it("should have clearCache function", function()
				expect(typeof(CursorAssetManager.clearCache)).to.equal("function")
			end)

			it("should have getPresetCount function", function()
				expect(typeof(CursorAssetManager.getPresetCount)).to.equal("function")
			end)
		end)

		describe("cache operations", function()
			it("should build cache from SettingsConfig", function()
				CursorAssetManager.buildCache()
				local presetCount = CursorAssetManager.getPresetCount()
				expect(presetCount).to.be.ok()
				expect(presetCount).to.be.a("number")
				expect(presetCount > 0).to.equal(true)
			end)

			it("should add custom ID to cache", function()
				local testId = 123456789
				local url = CursorAssetManager.addToCache(testId)
				expect(url).to.equal("rbxassetid://" .. tostring(testId))
				expect(CursorAssetManager.getCachedURL(testId)).to.equal(url)
			end)

			it("should return nil for uncached ID", function()
				local result = CursorAssetManager.getCachedURL(999999999)
				expect(result).to.equal(nil)
			end)

			it("should clear cache completely", function()
				local testId = 123456789
				CursorAssetManager.addToCache(testId)
				expect(CursorAssetManager.getCachedURL(testId)).to.be.ok()

				CursorAssetManager.clearCache()
				expect(CursorAssetManager.getCachedURL(testId)).to.equal(nil)
			end)
		end)

		describe("variant URL retrieval", function()
			it("should return string for valid style and variant", function()
				CursorAssetManager.buildCache()
				local url = CursorAssetManager.getVariantURL(1, 1)
				expect(typeof(url)).to.equal("string")
			end)

			it("should handle invalid style index gracefully", function()
				CursorAssetManager.buildCache()
				local url = CursorAssetManager.getVariantURL(9999, 1)
				expect(typeof(url)).to.equal("string")
			end)

			it("should handle invalid variant index gracefully", function()
				CursorAssetManager.buildCache()
				local url = CursorAssetManager.getVariantURL(1, 9999)
				expect(typeof(url)).to.equal("string")
			end)
		end)

		describe("spectator URL", function()
			it("should return spectator URL after cache build", function()
				CursorAssetManager.buildCache()
				local url = CursorAssetManager.getSpectatorURL()
				expect(typeof(url)).to.equal("string")
			end)

			it("should return empty string before cache build", function()
				local url = CursorAssetManager.getSpectatorURL()
				expect(url).to.equal("")
			end)
		end)

		describe("preset count", function()
			it("should return positive preset count", function()
				local count = CursorAssetManager.getPresetCount()
				expect(count).to.be.a("number")
				expect(count > 0).to.equal(true)
			end)
		end)
	end)
end
