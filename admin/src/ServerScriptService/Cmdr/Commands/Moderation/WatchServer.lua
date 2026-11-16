local Players = game:GetService("Players")

local Cmdr = require(script:FindFirstAncestor("Commands").Parent.Library)

type Session = { watcher: Player, target: Player, connections: { RBXScriptConnection } }

local sessions: { [Player]: Session } = {}

local function endSession(watcher: Player)
	local session = sessions[watcher]
	if session then
		sessions[watcher] = nil
		for _, connection in session.connections do
			connection:Disconnect()
		end
	end
end

local function stopWatching(watcher: Player)
	endSession(watcher)
	watcher.ReplicationFocus = nil
	Cmdr.Dispatcher:SendEvent(watcher, "Watch", nil)
end

local function streamAround(session: Session, character: Model)
	if not workspace.StreamingEnabled then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root and sessions[session.watcher] == session then
		session.watcher.ReplicationFocus = root
		pcall(session.watcher.RequestStreamAroundAsync, session.watcher, root.Position, 5)
	end
end

Players.PlayerRemoving:Connect(function(player)
	endSession(player)
	for watcher, session in sessions do
		if session.target == player then
			stopWatching(watcher)
		end
	end
end)

return function(context, target: Player): string
	local watcher = context.Executor
	stopWatching(watcher)
	if target == watcher then
		return "Stopped watching."
	end

	local character = target.Character
	if not (character and character:FindFirstChild("HumanoidRootPart")) then
		return `{target.Name} doesn't have a character right now.`
	end

	local session = { watcher = watcher, target = target, connections = {} }
	sessions[watcher] = session
	table.insert(session.connections, target.CharacterAdded:Connect(function(newCharacter)
		streamAround(session, newCharacter)
	end))
	table.insert(session.connections, watcher.CharacterAdded:Connect(function()
		stopWatching(watcher)
	end))

	streamAround(session, character)
	if sessions[watcher] ~= session then
		return "Stopped watching."
	end
	context:SendEvent(watcher, "Watch", target)
	return `Watching {target.Name}. Use "watch me" to stop.`
end
