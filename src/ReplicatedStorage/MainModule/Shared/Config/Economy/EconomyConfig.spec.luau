--!nocheck
return function()
	local EconomyConfig = require(script.Parent.EconomyConfig)
	local reward = EconomyConfig.calculateMatchReward
	local onyx = EconomyConfig.getMapReward("Onyx")
	local lossShare = EconomyConfig.REWARD_RULES.LOSS_SHARE
	local minPerformance = EconomyConfig.REWARD_RULES.MIN_PERFORMANCE_SHARE

	describe("calculateMatchReward", function()
		it("pays the full map reward for a full-length strong win", function()
			expect(reward("Onyx", true, 1, 700)).to.equal(onyx)
		end)

		it("pays losers a share", function()
			expect(reward("Onyx", false, 1, 700)).to.equal(math.floor(onyx * lossShare + 1e-6))
		end)

		it("pays nothing to late joiners or idle players", function()
			expect(reward("Onyx", true, 0.25, 1000)).to.equal(0)
			expect(reward("Onyx", true, 1, 150)).to.equal(0)
		end)

		it("does not lose a credit to floating point just under a whole number", function()
			expect(reward("Onyx", true, 1 - 1e-9, 700)).to.equal(onyx)
			expect(reward("Testing", true, 1 - 1e-9, 700)).to.equal(EconomyConfig.getMapReward("Testing"))
		end)

		it("scales with attendance and performance", function()
			expect(reward("Onyx", true, 0.5, 200)).to.equal(math.floor(onyx * 0.5 * minPerformance + 1e-6))
			expect(reward("Onyx", true, 0.5, 700)).to.equal(math.floor(onyx * 0.5 + 1e-6))
		end)
	end)
end
