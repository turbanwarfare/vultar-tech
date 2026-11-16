--!nocheck
--!strict

local ObjectPool = require(script.Parent.ObjectPool)

return function()
	describe("ObjectPool", function()
		describe("new", function()
			it("should create a pool with factory function", function()
				local createCount = 0
				local pool = ObjectPool.new({
					factory = function()
						createCount += 1
						return { id = createCount }
					end,
				})

				expect(pool).to.be.ok()
				expect(pool.get).to.be.ok()
				expect(pool.returnToPool).to.be.ok()
			end)
		end)

		describe("get", function()
			it("should create new item when pool is empty", function()
				local createCount = 0
				local pool = ObjectPool.new({
					factory = function()
						createCount += 1
						return { id = createCount }
					end,
				})

				local item = pool:get()
				expect(item.id).to.equal(1)
				expect(createCount).to.equal(1)
			end)

			it("should return pooled item when available", function()
				local createCount = 0
				local pool = ObjectPool.new({
					factory = function()
						createCount += 1
						return { id = createCount }
					end,
				})

				local item1 = pool:get()
				pool:returnToPool(item1)
				local item2 = pool:get()

				expect(item2).to.equal(item1)
				expect(createCount).to.equal(1)
			end)
		end)

		describe("returnToPool", function()
			it("should call onReset when returning item", function()
				local resetCount = 0
				local pool = ObjectPool.new({
					factory = function()
						return { value = 1 }
					end,
					onReset = function(item)
						resetCount += 1
						item.value = 0
					end,
				})

				local item = pool:get()
				item.value = 42
				pool:returnToPool(item)

				expect(resetCount).to.equal(1)
				expect(item.value).to.equal(0)
			end)

			it("should respect maxSize limit", function()
				local destroyCount = 0
				local pool = ObjectPool.new({
					factory = function()
						return {}
					end,
					maxSize = 2,
					onDestroy = function()
						destroyCount += 1
					end,
				})

				local items = {}
				for i = 1, 5 do
					items[i] = pool:get()
				end

				for _, item in items do
					pool:returnToPool(item)
				end

				expect(pool:getSize()).to.equal(2)
				expect(destroyCount).to.equal(3)
			end)
		end)

		describe("preWarm", function()
			it("should pre-create items up to count", function()
				local createCount = 0
				local pool = ObjectPool.new({
					factory = function()
						createCount += 1
						return { id = createCount }
					end,
					maxSize = 10,
				})

				pool:preWarm(5)

				expect(pool:getSize()).to.equal(5)
				expect(createCount).to.equal(5)
			end)

			it("should not exceed maxSize", function()
				local pool = ObjectPool.new({
					factory = function()
						return {}
					end,
					maxSize = 3,
				})

				pool:preWarm(10)

				expect(pool:getSize()).to.equal(3)
			end)
		end)

		describe("clear", function()
			it("should destroy all pooled items", function()
				local destroyCount = 0
				local pool = ObjectPool.new({
					factory = function()
						return {}
					end,
					onDestroy = function()
						destroyCount += 1
					end,
				})

				pool:preWarm(5)
				pool:clear()

				expect(pool:getSize()).to.equal(0)
				expect(destroyCount).to.equal(5)
			end)
		end)

		describe("getSize", function()
			it("should return current pool size", function()
				local pool = ObjectPool.new({
					factory = function()
						return {}
					end,
				})

				expect(pool:getSize()).to.equal(0)

				local item = pool:get()
				expect(pool:getSize()).to.equal(0)

				pool:returnToPool(item)
				expect(pool:getSize()).to.equal(1)
			end)
		end)
	end)
end
