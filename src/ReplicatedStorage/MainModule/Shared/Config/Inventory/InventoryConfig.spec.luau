--!nocheck
--!strict

local InventoryConfig = require(script.Parent.InventoryConfig)

return function()
	describe("InventoryConfig", function()
		describe("constants", function()
			it("should have MaxSlots defined", function()
				expect(InventoryConfig.MaxSlots).to.be.a("number")
				expect(InventoryConfig.MaxSlots).to.equal(9)
			end)

			it("should have UI constants defined", function()
				expect(InventoryConfig.SlotSize).to.be.a("number")
				expect(InventoryConfig.SlotGap).to.be.a("number")
				expect(InventoryConfig.BottomPadding).to.be.a("number")
			end)
		end)

		describe("DefaultState", function()
			it("should have empty items array", function()
				expect(InventoryConfig.DefaultState.Items).to.be.a("table")
				expect(#InventoryConfig.DefaultState.Items).to.equal(0)
			end)

			it("should have no equipped slot", function()
				expect(InventoryConfig.DefaultState.EquippedSlot).to.equal(nil)
			end)

			it("should have MaxSlots set", function()
				expect(InventoryConfig.DefaultState.MaxSlots).to.equal(9)
			end)
		end)

		describe("createDefaultState", function()
			it("should create state with empty items", function()
				local state = InventoryConfig.createDefaultState()
				expect(state.Items).to.be.a("table")
				expect(#state.Items).to.equal(0)
			end)

			it("should create state with no equipped slot", function()
				local state = InventoryConfig.createDefaultState()
				expect(state.EquippedSlot).to.equal(nil)
			end)

			it("should create state with correct max slots", function()
				local state = InventoryConfig.createDefaultState()
				expect(state.MaxSlots).to.equal(InventoryConfig.MaxSlots)
			end)

			it("should create a new table each time", function()
				local state1 = InventoryConfig.createDefaultState()
				local state2 = InventoryConfig.createDefaultState()
				expect(state1).never.to.equal(state2)
				expect(state1.Items).never.to.equal(state2.Items)
			end)
		end)

		describe("getNextAvailableSlot", function()
			it("should return 1 for empty inventory", function()
				local items = {}
				expect(InventoryConfig.getNextAvailableSlot(items)).to.equal(1)
			end)

			it("should return next available slot", function()
				local items = {
					{ Id = "1", Name = "Item1", Slot = 1 },
					{ Id = "2", Name = "Item2", Slot = 2 },
				}
				expect(InventoryConfig.getNextAvailableSlot(items :: any)).to.equal(3)
			end)

			it("should fill gaps in slots", function()
				local items = {
					{ Id = "1", Name = "Item1", Slot = 1 },
					{ Id = "3", Name = "Item3", Slot = 3 },
				}
				expect(InventoryConfig.getNextAvailableSlot(items :: any)).to.equal(2)
			end)

			it("should return nil when inventory is full", function()
				local items = {}
				for i = 1, InventoryConfig.MaxSlots do
					table.insert(items, { Id = tostring(i), Name = "Item" .. i, Slot = i })
				end
				expect(InventoryConfig.getNextAvailableSlot(items :: any)).to.equal(nil)
			end)
		end)

		describe("findItemBySlot", function()
			it("should find item at given slot", function()
				local items = {
					{ Id = "1", Name = "Item1", Slot = 1 },
					{ Id = "2", Name = "Item2", Slot = 3 },
				}
				local item = InventoryConfig.findItemBySlot(items :: any, 3)
				expect(item).to.be.ok()
				expect(item.Id).to.equal("2")
				expect(item.Name).to.equal("Item2")
			end)

			it("should return nil for empty slot", function()
				local items = {
					{ Id = "1", Name = "Item1", Slot = 1 },
				}
				local item = InventoryConfig.findItemBySlot(items :: any, 5)
				expect(item).to.equal(nil)
			end)

			it("should return nil for empty inventory", function()
				local items = {}
				local item = InventoryConfig.findItemBySlot(items :: any, 1)
				expect(item).to.equal(nil)
			end)
		end)

		describe("findItemById", function()
			it("should find item by id", function()
				local items = {
					{ Id = "abc123", Name = "Item1", Slot = 1 },
					{ Id = "def456", Name = "Item2", Slot = 2 },
				}
				local item = InventoryConfig.findItemById(items :: any, "def456")
				expect(item).to.be.ok()
				expect(item.Name).to.equal("Item2")
				expect(item.Slot).to.equal(2)
			end)

			it("should return nil for unknown id", function()
				local items = {
					{ Id = "abc123", Name = "Item1", Slot = 1 },
				}
				local item = InventoryConfig.findItemById(items :: any, "unknown")
				expect(item).to.equal(nil)
			end)

			it("should return nil for empty inventory", function()
				local items = {}
				local item = InventoryConfig.findItemById(items :: any, "any")
				expect(item).to.equal(nil)
			end)
		end)
	end)
end
