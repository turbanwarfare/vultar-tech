--!strict
--!native
--!optimize 2

export type PoolConfig<T> = {
	factory: () -> T,
	maxSize: number?,
	onReset: ((item: T) -> ())?,
	onDestroy: ((item: T) -> ())?,
}

export type ObjectPool<T> = {
	get: (self: ObjectPool<T>) -> T,
	returnToPool: (self: ObjectPool<T>, item: T) -> (),
	preWarm: (self: ObjectPool<T>, count: number) -> (),
	getSize: (self: ObjectPool<T>) -> number,
	clear: (self: ObjectPool<T>) -> (),
}

local DEFAULT_MAX_SIZE = 100

local ObjectPool = {}

function ObjectPool.new<T>(config: PoolConfig<T>): ObjectPool<T>
	local items: { T } = {}
	local itemCount = 0
	local maxSize = config.maxSize or DEFAULT_MAX_SIZE
	local factory = config.factory
	local onReset = config.onReset
	local onDestroy = config.onDestroy

	local poolInstance = {}

	function poolInstance.get(_self: ObjectPool<T>): T
		if itemCount > 0 then
			local item = items[itemCount]
			items[itemCount] = nil :: any
			itemCount -= 1
			return item
		end

		return factory()
	end

	function poolInstance.returnToPool(_self: ObjectPool<T>, item: T): ()
		if onReset then
			onReset(item)
		end

		if itemCount < maxSize then
			itemCount += 1
			items[itemCount] = item
		elseif onDestroy then
			onDestroy(item)
		end
	end

	function poolInstance.preWarm(_self: ObjectPool<T>, count: number): ()
		local toCreate = math.min(count, maxSize - itemCount)
		for _ = 1, toCreate do
			local item = factory()
			if onReset then
				onReset(item)
			end
			itemCount += 1
			items[itemCount] = item
		end
	end

	function poolInstance.getSize(_self: ObjectPool<T>): number
		return itemCount
	end

	function poolInstance.clear(_self: ObjectPool<T>): ()
		if onDestroy then
			for i = 1, itemCount do
				onDestroy(items[i])
			end
		end
		table.clear(items)
		itemCount = 0
	end

	return poolInstance
end

return ObjectPool
