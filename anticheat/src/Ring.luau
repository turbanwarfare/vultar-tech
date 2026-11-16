--!strict

local Ring = {}
Ring.__index = Ring

export type Ring<T> = typeof(setmetatable({} :: { items: { T }, capacity: number, head: number, count: number }, Ring))

function Ring.new<T>(capacity: number): Ring<T>
	return setmetatable({ items = table.create(capacity), capacity = capacity, head = 0, count = 0 }, Ring)
end

function Ring.push<T>(self: Ring<T>, item: T): ()
	self.head = self.head % self.capacity + 1
	self.items[self.head] = item
	if self.count < self.capacity then
		self.count += 1
	end
end

function Ring.get<T>(self: Ring<T>, index: number): T
	return self.items[(self.head - self.count + index - 1) % self.capacity + 1]
end

function Ring.clear<T>(self: Ring<T>): ()
	table.clear(self.items)
	self.head = 0
	self.count = 0
end

return Ring
