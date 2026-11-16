--!nocheck
return function()
	local TableUtils = require(script.Parent.TableUtils)

	describe("TableUtils", function()
		describe("cloneAndSort", function()
			it("should return a new sorted array", function()
				local source = {3, 1, 4, 1, 5}
				local result = TableUtils.cloneAndSort(source, function(a, b)
					return a < b
				end)
				expect(result[1]).to.equal(1)
				expect(result[2]).to.equal(1)
				expect(result[3]).to.equal(3)
				expect(result[4]).to.equal(4)
				expect(result[5]).to.equal(5)
			end)

			it("should not modify original array", function()
				local source = {3, 1, 4}
				TableUtils.cloneAndSort(source, function(a, b) return a < b end)
				expect(source[1]).to.equal(3)
				expect(source[2]).to.equal(1)
				expect(source[3]).to.equal(4)
			end)

			it("should handle empty array", function()
				local source = {}
				local result = TableUtils.cloneAndSort(source, function(a, b) return a < b end)
				expect(#result).to.equal(0)
			end)

			it("should handle single element array", function()
				local source = {42}
				local result = TableUtils.cloneAndSort(source, function(a, b) return a < b end)
				expect(#result).to.equal(1)
				expect(result[1]).to.equal(42)
			end)

			it("should support descending sort", function()
				local source = {1, 5, 3}
				local result = TableUtils.cloneAndSort(source, function(a, b)
					return a > b
				end)
				expect(result[1]).to.equal(5)
				expect(result[2]).to.equal(3)
				expect(result[3]).to.equal(1)
			end)
		end)

		describe("sortByKey", function()
			it("should sort by key ascending", function()
				local source = {
					{name = "c", value = 3},
					{name = "a", value = 1},
					{name = "b", value = 2},
				}
				local result = TableUtils.sortByKey(source, "value", false)
				expect(result[1].value).to.equal(1)
				expect(result[2].value).to.equal(2)
				expect(result[3].value).to.equal(3)
			end)

			it("should sort by key descending", function()
				local source = {
					{name = "c", value = 3},
					{name = "a", value = 1},
					{name = "b", value = 2},
				}
				local result = TableUtils.sortByKey(source, "value", true)
				expect(result[1].value).to.equal(3)
				expect(result[2].value).to.equal(2)
				expect(result[3].value).to.equal(1)
			end)

			it("should not modify original array", function()
				local source = {
					{value = 3},
					{value = 1},
				}
				TableUtils.sortByKey(source, "value", false)
				expect(source[1].value).to.equal(3)
				expect(source[2].value).to.equal(1)
			end)

			it("should handle empty array", function()
				local result = TableUtils.sortByKey({}, "value", false)
				expect(#result).to.equal(0)
			end)

			it("should sort by string key", function()
				local source = {
					{name = "charlie"},
					{name = "alpha"},
					{name = "bravo"},
				}
				local result = TableUtils.sortByKey(source, "name", false)
				expect(result[1].name).to.equal("alpha")
				expect(result[2].name).to.equal("bravo")
				expect(result[3].name).to.equal("charlie")
			end)
		end)

		describe("find", function()
			it("should find matching item", function()
				local source = {1, 2, 3, 4, 5}
				local result = TableUtils.find(source, function(item)
					return item == 3
				end)
				expect(result).to.equal(3)
			end)

			it("should return first match", function()
				local source = {
					{id = 1, name = "a"},
					{id = 2, name = "b"},
					{id = 2, name = "c"},
				}
				local result = TableUtils.find(source, function(item)
					return item.id == 2
				end)
				expect(result.name).to.equal("b")
			end)

			it("should return nil when no match found", function()
				local source = {1, 2, 3}
				local result = TableUtils.find(source, function(item)
					return item == 99
				end)
				expect(result).to.equal(nil)
			end)

			it("should return nil for empty array", function()
				local result = TableUtils.find({}, function()
					return true
				end)
				expect(result).to.equal(nil)
			end)
		end)

		describe("filter", function()
			it("should filter items matching predicate", function()
				local source = {1, 2, 3, 4, 5}
				local result = TableUtils.filter(source, function(item)
					return item > 2
				end)
				expect(#result).to.equal(3)
				expect(result[1]).to.equal(3)
				expect(result[2]).to.equal(4)
				expect(result[3]).to.equal(5)
			end)

			it("should return empty array when no matches", function()
				local source = {1, 2, 3}
				local result = TableUtils.filter(source, function(item)
					return item > 100
				end)
				expect(#result).to.equal(0)
			end)

			it("should return all items when all match", function()
				local source = {1, 2, 3}
				local result = TableUtils.filter(source, function()
					return true
				end)
				expect(#result).to.equal(3)
			end)

			it("should not modify original array", function()
				local source = {1, 2, 3}
				TableUtils.filter(source, function(item) return item > 1 end)
				expect(#source).to.equal(3)
			end)

			it("should handle empty array", function()
				local result = TableUtils.filter({}, function() return true end)
				expect(#result).to.equal(0)
			end)

			it("should filter objects", function()
				local source = {
					{active = true, name = "a"},
					{active = false, name = "b"},
					{active = true, name = "c"},
				}
				local result = TableUtils.filter(source, function(item)
					return item.active
				end)
				expect(#result).to.equal(2)
				expect(result[1].name).to.equal("a")
				expect(result[2].name).to.equal("c")
			end)
		end)

		describe("map", function()
			it("should transform each item", function()
				local source = {1, 2, 3}
				local result = TableUtils.map(source, function(item)
					return item * 2
				end)
				expect(result[1]).to.equal(2)
				expect(result[2]).to.equal(4)
				expect(result[3]).to.equal(6)
			end)

			it("should not modify original array", function()
				local source = {1, 2, 3}
				TableUtils.map(source, function(item) return item * 2 end)
				expect(source[1]).to.equal(1)
				expect(source[2]).to.equal(2)
				expect(source[3]).to.equal(3)
			end)

			it("should handle empty array", function()
				local result = TableUtils.map({}, function(item) return item end)
				expect(#result).to.equal(0)
			end)

			it("should extract property", function()
				local source = {
					{name = "a", value = 1},
					{name = "b", value = 2},
				}
				local result = TableUtils.map(source, function(item)
					return item.name
				end)
				expect(result[1]).to.equal("a")
				expect(result[2]).to.equal("b")
			end)

			it("should support type transformation", function()
				local source = {1, 2, 3}
				local result = TableUtils.map(source, function(item)
					return tostring(item)
				end)
				expect(result[1]).to.equal("1")
				expect(result[2]).to.equal("2")
				expect(result[3]).to.equal("3")
			end)
		end)

		describe("keyBy", function()
			it("should create lookup table by key", function()
				local source = {
					{id = 1, name = "a"},
					{id = 2, name = "b"},
					{id = 3, name = "c"},
				}
				local result = TableUtils.keyBy(source, "id")
				expect(result[1].name).to.equal("a")
				expect(result[2].name).to.equal("b")
				expect(result[3].name).to.equal("c")
			end)

			it("should handle string keys", function()
				local source = {
					{code = "alpha", value = 1},
					{code = "bravo", value = 2},
				}
				local result = TableUtils.keyBy(source, "code")
				expect(result.alpha.value).to.equal(1)
				expect(result.bravo.value).to.equal(2)
			end)

			it("should overwrite duplicates", function()
				local source = {
					{id = 1, name = "first"},
					{id = 1, name = "second"},
				}
				local result = TableUtils.keyBy(source, "id")
				expect(result[1].name).to.equal("second")
			end)

			it("should skip items with nil key", function()
				local source = {
					{id = 1, name = "a"},
					{name = "b"},
					{id = 3, name = "c"},
				}
				local result = TableUtils.keyBy(source, "id")
				expect(result[1]).to.be.ok()
				expect(result[3]).to.be.ok()
			end)

			it("should handle empty array", function()
				local result = TableUtils.keyBy({}, "id")
				expect(TableUtils.isEmpty(result)).to.equal(true)
			end)
		end)

		describe("isEmpty", function()
			it("should return true for empty table", function()
				expect(TableUtils.isEmpty({})).to.equal(true)
			end)

			it("should return false for array with items", function()
				expect(TableUtils.isEmpty({1, 2, 3})).to.equal(false)
			end)

			it("should return false for dictionary with items", function()
				expect(TableUtils.isEmpty({key = "value"})).to.equal(false)
			end)

			it("should return true for table cleared with table.clear", function()
				local t = {1, 2, 3}
				table.clear(t)
				expect(TableUtils.isEmpty(t)).to.equal(true)
			end)
		end)

		describe("count", function()
			it("should return 0 for empty table", function()
				expect(TableUtils.count({})).to.equal(0)
			end)

			it("should count array items", function()
				expect(TableUtils.count({1, 2, 3, 4, 5})).to.equal(5)
			end)

			it("should count dictionary items", function()
				expect(TableUtils.count({a = 1, b = 2, c = 3})).to.equal(3)
			end)

			it("should count mixed table items", function()
				local t = {1, 2, 3, key = "value"}
				expect(TableUtils.count(t)).to.equal(4)
			end)
		end)
	end)
end
