--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")

local GradientDriver = {}

local THROTTLE_INTERVAL = 1 / 30

local subscriberCount = 0
local heartbeatConnection: RBXScriptConnection? = nil
local currentOffset: number = 0
local registeredGradients: { UIGradient } = {}
local timeSinceUpdate: number = 0

local function startHeartbeat()
	if heartbeatConnection then
		return
	end

	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		currentOffset = (currentOffset + deltaTime * 0.25) % 2

		timeSinceUpdate += deltaTime
		if timeSinceUpdate < THROTTLE_INTERVAL then
			return
		end
		timeSinceUpdate = 0

		local count = #registeredGradients
		if count == 0 then
			return
		end
		debug.profilebegin("Chat::gradientDriver")

		local offsetVec = Vector2.new(currentOffset - 1, 0)

		for i = count, 1, -1 do
			local gradient = registeredGradients[i]
			if gradient.Parent then
				gradient.Offset = offsetVec
			else
				if i < count then
					registeredGradients[i] = registeredGradients[count]
				end
				registeredGradients[count] = nil
				count -= 1
			end
		end
		debug.profileend()
	end)
end

local function stopHeartbeat()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

function GradientDriver.subscribe(): () -> ()
	subscriberCount += 1

	if subscriberCount == 1 then
		startHeartbeat()
	end

	local unsubscribed = false
	return function()
		if not unsubscribed then
			unsubscribed = true
			subscriberCount -= 1

			if subscriberCount == 0 then
				stopHeartbeat()
			end
		end
	end
end

function GradientDriver.register(gradient: UIGradient): ()
	table.insert(registeredGradients, gradient)
end

function GradientDriver.getCurrentOffset(): number
	return currentOffset
end

function GradientDriver.destroy(): ()
	stopHeartbeat()
	table.clear(registeredGradients)
	subscriberCount = 0
	currentOffset = 0
end

return GradientDriver
