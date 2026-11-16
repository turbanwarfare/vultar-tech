--!nocheck
--!strict

local StatsConfig = require(script.Parent.StatsConfig)

return function()
	describe("StatsConfig", function()
		describe("StatTypes", function()
			it("should contain all stat types", function()
				expect(#StatsConfig.StatTypes).to.equal(4)
				expect(table.find(StatsConfig.StatTypes, "Kills")).to.be.ok()
				expect(table.find(StatsConfig.StatTypes, "Damage")).to.be.ok()
				expect(table.find(StatsConfig.StatTypes, "Heals")).to.be.ok()
				expect(table.find(StatsConfig.StatTypes, "Captures")).to.be.ok()
			end)
		end)

		describe("DefaultStats", function()
			it("should have all stats set to zero", function()
				expect(StatsConfig.DefaultStats.Kills).to.equal(0)
				expect(StatsConfig.DefaultStats.Damage).to.equal(0)
				expect(StatsConfig.DefaultStats.Heals).to.equal(0)
				expect(StatsConfig.DefaultStats.Captures).to.equal(0)
			end)
		end)

		describe("createDefaultStats", function()
			it("should create stats with all zeros", function()
				local stats = StatsConfig.createDefaultStats()
				expect(stats.Kills).to.equal(0)
				expect(stats.Damage).to.equal(0)
				expect(stats.Heals).to.equal(0)
				expect(stats.Captures).to.equal(0)
			end)

			it("should create a new table each time", function()
				local stats1 = StatsConfig.createDefaultStats()
				local stats2 = StatsConfig.createDefaultStats()
				expect(stats1).never.to.equal(stats2)
			end)

			it("should not be affected when original is modified", function()
				local stats = StatsConfig.createDefaultStats()
				stats.Kills = 100

				local newStats = StatsConfig.createDefaultStats()
				expect(newStats.Kills).to.equal(0)
			end)
		end)

		describe("getTotal", function()
			it("should return sum of all stats", function()
				local stats = {
					Kills = 10,
					Damage = 500,
					Heals = 200,
					Captures = 5,
				}
				expect(StatsConfig.getTotal(stats)).to.equal(715)
			end)

			it("should return zero for default stats", function()
				local stats = StatsConfig.createDefaultStats()
				expect(StatsConfig.getTotal(stats)).to.equal(0)
			end)

			it("should handle large numbers", function()
				local stats = {
					Kills = 1000000,
					Damage = 2000000,
					Heals = 3000000,
					Captures = 4000000,
				}
				expect(StatsConfig.getTotal(stats)).to.equal(10000000)
			end)
		end)

		describe("isValidStatType", function()
			it("should return true for valid stat types", function()
				expect(StatsConfig.isValidStatType("Kills")).to.equal(true)
				expect(StatsConfig.isValidStatType("Damage")).to.equal(true)
				expect(StatsConfig.isValidStatType("Heals")).to.equal(true)
				expect(StatsConfig.isValidStatType("Captures")).to.equal(true)
			end)

			it("should return false for invalid stat types", function()
				expect(StatsConfig.isValidStatType("InvalidStat")).to.equal(false)
				expect(StatsConfig.isValidStatType("kills")).to.equal(false)
				expect(StatsConfig.isValidStatType("")).to.equal(false)
				expect(StatsConfig.isValidStatType("Total")).to.equal(false)
			end)
		end)
	end)
end
