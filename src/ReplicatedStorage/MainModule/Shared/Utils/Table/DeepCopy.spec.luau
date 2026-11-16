--!nocheck
--!strict

local DeepCopy = require(script.Parent.DeepCopy)

return function()
	describe("DeepCopy", function()
		describe("copy", function()
			it("should return primitives unchanged", function()
				expect(DeepCopy.copy(42)).to.equal(42)
				expect(DeepCopy.copy("hello")).to.equal("hello")
				expect(DeepCopy.copy(true)).to.equal(true)
				expect(DeepCopy.copy(nil)).to.equal(nil)
			end)

			it("should create a shallow copy of flat tables", function()
				local original = { a = 1, b = 2, c = 3 }
				local copied = DeepCopy.copy(original)

				expect(copied).to.be.a("table")
				expect(copied).never.to.equal(original)
				expect(copied.a).to.equal(1)
				expect(copied.b).to.equal(2)
				expect(copied.c).to.equal(3)
			end)

			it("should create a deep copy of nested tables", function()
				local original = {
					level1 = {
						level2 = {
							value = "deep",
						},
					},
				}
				local copied = DeepCopy.copy(original)

				expect(copied.level1).never.to.equal(original.level1)
				expect(copied.level1.level2).never.to.equal(original.level1.level2)
				expect(copied.level1.level2.value).to.equal("deep")
			end)

			it("should not affect original when copy is modified", function()
				local original = { nested = { value = 1 } }
				local copied = DeepCopy.copy(original)

				copied.nested.value = 999

				expect(original.nested.value).to.equal(1)
				expect(copied.nested.value).to.equal(999)
			end)

			it("should handle empty tables", function()
				local original = {}
				local copied = DeepCopy.copy(original)

				expect(copied).to.be.a("table")
				expect(copied).never.to.equal(original)
				expect(next(copied)).to.equal(nil)
			end)

			it("should handle arrays", function()
				local original = { 1, 2, 3, { 4, 5 } }
				local copied = DeepCopy.copy(original)

				expect(copied[1]).to.equal(1)
				expect(copied[2]).to.equal(2)
				expect(copied[3]).to.equal(3)
				expect(copied[4]).to.be.a("table")
				expect(copied[4]).never.to.equal(original[4])
				expect(copied[4][1]).to.equal(4)
			end)
		end)
	end)
end
