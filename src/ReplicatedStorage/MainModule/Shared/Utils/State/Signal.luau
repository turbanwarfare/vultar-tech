--!strict
--!native
--!optimize 2

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

type ConnectionInternal = {
	callback: (...any) -> (),
	connected: boolean,
	index: number,
}

type SignalInternal = {
	connections: { ConnectionInternal },
	connectionCount: number,
	destroyed: boolean,
}

local Signal = {}

local function createConnection(signal: SignalInternal, callback: (...any) -> ()): Connection
	signal.connectionCount += 1
	local internal: ConnectionInternal = {
		callback = callback,
		connected = true,
		index = signal.connectionCount,
	}
	signal.connections[signal.connectionCount] = internal

	local connection = {}

	function connection:Disconnect()
		if not internal.connected then
			return
		end
		internal.connected = false

		local index = internal.index
		local lastIndex = signal.connectionCount
		if index < lastIndex then
			local lastConn = signal.connections[lastIndex]
			signal.connections[index] = lastConn
			lastConn.index = index
		end
		signal.connections[lastIndex] = nil
		signal.connectionCount -= 1
	end

	return setmetatable(connection, {
		__index = function(_, key)
			if key == "Connected" then
				return internal.connected
			end
			return nil
		end,
	}) :: any
end

function Signal.new<T...>(): Signal<T...>
	local internal: SignalInternal = {
		connections = {},
		connectionCount = 0,
		destroyed = false,
	}

	local signal = {}

	function signal:Connect(callback: (T...) -> ()): Connection
		if internal.destroyed then
			error("Cannot connect to destroyed signal")
		end
		return createConnection(internal, callback :: any)
	end

	function signal:Once(callback: (T...) -> ()): Connection
		if internal.destroyed then
			error("Cannot connect to destroyed signal")
		end

		local connection: Connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			callback(...)
		end :: any)
		return connection
	end

	function signal:Fire(...: T...)
		if internal.destroyed then
			return
		end

		for i = 1, internal.connectionCount do
			local conn = internal.connections[i]
			if conn and conn.connected then
				task.spawn(conn.callback, ...)
			end
		end
	end

	function signal:Wait(): T...
		if internal.destroyed then
			error("Cannot wait on destroyed signal")
		end

		local thread = coroutine.running()
		local connection: Connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			task.spawn(thread, ...)
		end :: any)
		return coroutine.yield()
	end

	function signal:DisconnectAll()
		for i = 1, internal.connectionCount do
			local conn = internal.connections[i]
			if conn then
				conn.connected = false
			end
			internal.connections[i] = nil
		end
		internal.connectionCount = 0
	end

	function signal:Destroy()
		self:DisconnectAll()
		internal.destroyed = true
	end

	return signal :: any
end

return Signal
