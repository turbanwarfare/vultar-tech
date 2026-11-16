--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local ForceFieldService = {}
ForceFieldService.Name = "ForceFieldService"

local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local charConnections: { [Model]: { RBXScriptConnection } } = {}

local function cleanupCharacter(character: Model)
	local conns = charConnections[character]
	if conns then
		for _, conn in conns do
			conn:Disconnect()
		end
		charConnections[character] = nil
	end
end

local function onCharacterAdded(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("ForceField") then
			(child :: ForceField).Visible = false
		end
	end

	local conns: { RBXScriptConnection } = {}
	charConnections[character] = conns

	local childAddedConn = character.ChildAdded:Connect(function(child)
		if child:IsA("ForceField") then
			(child :: ForceField).Visible = false
		end
	end)
	table.insert(conns, childAddedConn)
end

local function onCharacterRemoving(character: Model)
	cleanupCharacter(character)
end

local function onPlayerAdded(player: Player)
	local conns: { RBXScriptConnection } = {}
	playerConnections[player] = conns

	if player.Character then
		onCharacterAdded(player.Character)
	end

	local charAddedConn = player.CharacterAdded:Connect(onCharacterAdded)
	local charRemovingConn = player.CharacterRemoving:Connect(onCharacterRemoving)

	table.insert(conns, charAddedConn)
	table.insert(conns, charRemovingConn)
end

local function onPlayerRemoving(player: Player)
	local conns = playerConnections[player]
	if conns then
		for _, conn in conns do
			conn:Disconnect()
		end
		playerConnections[player] = nil
	end

	if player.Character then
		cleanupCharacter(player.Character)
	end
end

function ForceFieldService:start()
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function ForceFieldService:init() end

return ForceFieldService
