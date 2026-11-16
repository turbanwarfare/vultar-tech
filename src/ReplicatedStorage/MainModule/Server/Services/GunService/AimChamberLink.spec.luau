--!nocheck
return function()
	local AimChamberLink = require(script.Parent.AimChamberLink)

	describe("AimChamberLink outside the aim map", function()
		it("reports no aim mode and no match without loading the aim chamber", function()
			expect(AimChamberLink.isPlayerInAiMode(nil)).to.equal(false)
			expect(AimChamberLink.hasActiveMatch(nil)).to.equal(false)
		end)

		it("ignores shot and hit records", function()
			expect(function()
				AimChamberLink.recordPlayerShot(nil, 3)
				AimChamberLink.recordPlayerHit(nil, 1)
			end).never.to.throw()
		end)
	end)
end
