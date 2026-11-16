--!nocheck
return function()
	local Crates = require(script.Parent.Crates)
	local CosmeticConfig = require(script.Parent)

	describe("Crates", function()
		it("should have odds that sum to 100 for every crate", function()
			for _, crate in Crates.All do
				local total = 0
				for _, odd in crate.odds do
					total += odd.chance
				end
				expect(math.abs(total - 100) < 0.001).to.equal(true)
			end
		end)

		it("should have at least one drop for every rarity in its odds", function()
			for _, crate in Crates.All do
				for _, odd in crate.odds do
					expect(#Crates.getDropsByRarity(crate, odd.rarity) > 0).to.equal(true)
				end
			end
		end)

		it("should only drop cosmetics that exist", function()
			for _, crate in Crates.All do
				for _, drop in crate.drops do
					local baseId = string.match(drop.id, "^([^:]+)") or drop.id
					expect(CosmeticConfig.getItemById(baseId)).to.be.ok()
				end
			end
		end)

		it("should have per-item chances that sum to 100 for every crate", function()
			for _, crate in Crates.All do
				local total = 0
				for _, drop in crate.drops do
					local _, perItem = Crates.getItemChance(crate, drop)
					total += perItem
				end
				expect(math.abs(total - 100) < 0.001).to.equal(true)
			end
		end)

		it("should format chances with five significant digits", function()
			expect(Crates.formatChance(12.5)).to.equal("12.5%")
			expect(Crates.formatChance(2)).to.equal("2%")
			expect(Crates.formatChance(1 / 3)).to.equal("0.33333%")
			expect(Crates.isChanceRounded(12.5)).to.equal(false)
			expect(Crates.isChanceRounded(1 / 3)).to.equal(true)
		end)

		it("should give both faction guns in every class pack", function()
			for _, crate in Crates.All do
				for _, drop in crate.drops do
					if drop.unlocks then
						expect(#drop.unlocks).to.equal(2)
						expect(string.match(drop.unlocks[1], ":H%-")).to.be.ok()
						expect(string.match(drop.unlocks[2], ":BR%-")).to.be.ok()
					end
				end
			end
		end)
	end)
end
