--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local Core = require(MainModule.Shared.Network.Core)

local DEFAULT_DAMAGE = 100
local DEFAULT_COOLDOWN = 1
local DEFAULT_DEATH_MESSAGE = "fell into the void"

local SPECIAL_USER_IDS: { [number]: boolean } = {}

local SPECIAL_DEATH_MESSAGE = "got hit by an missile"

local REMOTE_NAMES = {
	ENVIRONMENTAL_KILL = "EnvironmentalKill",
}

local EnvironmentalKillEvent: RemoteEvent = Core.getOrCreateRemoteEvent(REMOTE_NAMES.ENVIRONMENTAL_KILL)

local KillBrickController = {}

local connections: { RBXScriptConnection } = {}
local playerCooldowns: { [Player]: { [BasePart]: number } } = {}
local deathConnections: { [Player]: RBXScriptConnection } = {}

local function onKillBrickDeath(player: Player, message: string): ()
	EnvironmentalKillEvent:FireAllClients({
		killerName = player.Name,
		killerUserId = player.UserId,
		killerTeam = if player.Team then player.Team.Name else "Spectators",
		message = message,
		victimName = "",
		victimUserId = 0,
		victimTeam = "",
	})
end

local function cleanupDeathConnection(player: Player): ()
	local conn = deathConnections[player]
	if conn then
		conn:Disconnect()
		deathConnections[player] = nil
	end
end

local function setupPlayer(player: Player): ()
	player.CharacterAdded:Connect(function()
		cleanupDeathConnection(player)
		playerCooldowns[player] = nil
	end)
end

function KillBrickController.init(): ()
	local folder = workspace:FindFirstChild("KillBricks")
	if not folder then
		return
	end

	for _, part in folder:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end

		local deathMessage: string = (part:GetAttribute("DeathMessage") :: string?) or DEFAULT_DEATH_MESSAGE

		table.insert(
			connections,
			part.Touched:Connect(function(hit: BasePart)
				local character = hit.Parent :: Model?
				if not character then
					return
				end

				local player = Players:GetPlayerFromCharacter(character)
				if not player then
					return
				end

				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if not humanoid or humanoid.Health <= 0 then
					return
				end

				local now = os.clock()
				local cooldown = (part:GetAttribute("Cooldown") :: number?) or DEFAULT_COOLDOWN

				local cooldownMap = playerCooldowns[player]
				if not cooldownMap then
					cooldownMap = {}
					playerCooldowns[player] = cooldownMap
				end

				local lastHit = cooldownMap[part]
				if lastHit and (now - lastHit) < cooldown then
					return
				end
				cooldownMap[part] = now

				local damage = (part:GetAttribute("Damage") :: number?) or DEFAULT_DAMAGE

				local finalMessage = deathMessage
				if SPECIAL_USER_IDS[player.UserId] then
					finalMessage = SPECIAL_DEATH_MESSAGE
				end

				local healthBefore = humanoid.Health
				humanoid:TakeDamage(damage)

				if humanoid.Health <= 0 and healthBefore > 0 then
					cleanupDeathConnection(player)
					onKillBrickDeath(player, finalMessage)
				elseif humanoid.Health > 0 and not deathConnections[player] then
					local capturedMessage = finalMessage
					local capturedHumanoid = humanoid

					deathConnections[player] = capturedHumanoid.Died:Connect(function()
						if player.Character and player.Character:FindFirstChildOfClass("Humanoid") == capturedHumanoid then
							onKillBrickDeath(player, capturedMessage)
						end
						cleanupDeathConnection(player)
					end)
				end
			end)
		)
	end

	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end

	table.insert(connections, Players.PlayerAdded:Connect(setupPlayer))

	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			playerCooldowns[player] = nil
			cleanupDeathConnection(player)
		end)
	)
end

function KillBrickController.cleanup(): ()
	for _, conn in connections do
		conn:Disconnect()
	end
	for _, conn in deathConnections do
		conn:Disconnect()
	end
	table.clear(connections)
	table.clear(deathConnections)
	table.clear(playerCooldowns)
end

return KillBrickController
