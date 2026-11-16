--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local Cache = require(script.Parent.Cache)

local SoundReplicator = {}

local playerByUserId: { [number]: Player } = {}
local localPlayer = Players.LocalPlayer
local connections: { RBXScriptConnection } = {}
local toolSoundCache: { [Tool]: Sound? } = {}

local function flushToolCacheForCharacter(character: Model): ()
	for tool in toolSoundCache do
		if tool:IsDescendantOf(character) then
			toolSoundCache[tool] = nil
		end
	end
end

local function watchPlayerCharacter(player: Player): ()
	if player == localPlayer then
		return
	end

	player.CharacterRemoving:Connect(flushToolCacheForCharacter)
end

local function setupPlayerTracking(): ()
	for _, player in Players:GetPlayers() do
		playerByUserId[player.UserId] = player
		watchPlayerCharacter(player)
	end

	table.insert(
		connections,
		Players.PlayerAdded:Connect(function(player)
			playerByUserId[player.UserId] = player
			watchPlayerCharacter(player)
		end)
	)

	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player)
			playerByUserId[player.UserId] = nil
			local char = player.Character
			if char then
				flushToolCacheForCharacter(char)
			end
		end)
	)
end

local function findFireSoundOnTool(tool: Tool): Sound?
	local cached = toolSoundCache[tool]
	if cached ~= nil then
		if cached.Parent then
			return cached
		end
		toolSoundCache[tool] = nil
	end

	local fireChild = tool:FindFirstChild("Fire", true)
	if fireChild and fireChild:IsA("Sound") then
		toolSoundCache[tool] = fireChild
		return fireChild
	end

	local fireSoundChild = tool:FindFirstChild("FireSound", true)
	if fireSoundChild and fireSoundChild:IsA("Sound") then
		toolSoundCache[tool] = fireSoundChild
		return fireSoundChild
	end

	return nil
end

local function getShooterFireSound(shooterId: number): Sound?
	if shooterId == localPlayer.UserId then
		return nil
	end

	local shooter = playerByUserId[shooterId]
	if not shooter then
		return nil
	end

	local character = shooter.Character
	if not character then
		return nil
	end

	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then
		return nil
	end

	return findFireSoundOnTool(tool)
end

function SoundReplicator.init(): ()
	setupPlayerTracking()
end

function SoundReplicator.playGunSound(shooterId: number, _gunIndex: number, _origin: Vector3): ()
	if not Cache.getWeaponSoundsEnabled() then
		return
	end

	local fireSound = getShooterFireSound(shooterId)
	if fireSound then
		fireSound:Play()
	end
end

function SoundReplicator.cleanup(): ()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	table.clear(playerByUserId)
	table.clear(toolSoundCache)
end

return SoundReplicator
