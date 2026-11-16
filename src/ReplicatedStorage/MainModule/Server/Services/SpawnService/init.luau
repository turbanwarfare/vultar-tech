--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local MainModule = script.Parent.Parent.Parent
local Maps = require(MainModule.Shared.Config.Maps)
local ServiceTrove = require(MainModule.Shared.Utils.Services.ServiceTrove)

local SpawnService = {}
SpawnService.Name = "SpawnService"

local COLLISION_GROUP_PLAYER = "PlayerCharacter"
local COLLISION_GROUP_PAYLOAD = "Payload"

local payloadCollisionEnabled = false

local playerTroves: { [number]: ServiceTrove.ServiceTrove } = {}
local characterTroves: { [number]: ServiceTrove.ServiceTrove } = {}
local serviceTrove: ServiceTrove.ServiceTrove = nil :: any

local function setupCharacterParts(character: Model): ()
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			if payloadCollisionEnabled then
				descendant.CollisionGroup = COLLISION_GROUP_PLAYER
			end
			local accessory = descendant:FindFirstAncestorOfClass("Accessory")
			if accessory and descendant.Name == "Handle" then
				descendant.CanQuery = false
			end
		end
	end
end

local function getCharacterTrove(player: Player): ServiceTrove.ServiceTrove?
	local userId = player.UserId

	local existing = characterTroves[userId]
	if existing then
		existing:Destroy()
		characterTroves[userId] = nil
	end

	local playerTrove = playerTroves[userId]
	if not playerTrove then
		return nil
	end

	local charTrove = playerTrove:Extend()
	characterTroves[userId] = charTrove
	return charTrove
end

local function onCharacterAdded(player: Player, character: Model): ()
	local charTrove = getCharacterTrove(player)
	if not charTrove then
		return
	end

	setupCharacterParts(character)

	charTrove:Connect(character.DescendantAdded, function(descendant: Instance)
		if descendant:IsA("BasePart") then
			if payloadCollisionEnabled then
				descendant.CollisionGroup = COLLISION_GROUP_PLAYER
			end
			local accessory = descendant:FindFirstAncestorOfClass("Accessory")
			if accessory and descendant.Name == "Handle" then
				descendant.CanQuery = false
			end
		elseif descendant:IsA("Accessory") then
			local handle = descendant:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				if payloadCollisionEnabled then
					handle.CollisionGroup = COLLISION_GROUP_PLAYER
				end
				handle.CanQuery = false
			end
		end
	end)
end

local function onPlayerAdded(player: Player): ()
	local userId = player.UserId
	local trove = serviceTrove:Extend()
	playerTroves[userId] = trove

	trove:Connect(player.CharacterAdded, function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player): ()
	local userId = player.UserId

	characterTroves[userId] = nil

	local trove = playerTroves[userId]
	if trove then
		trove:Destroy()
		playerTroves[userId] = nil
	end
end

function SpawnService:init(): ()
	local mapConfig = Maps.getConfig()
	if mapConfig.RaidType ~= "Phase" then
		return
	end

	payloadCollisionEnabled = true
	PhysicsService:RegisterCollisionGroup(COLLISION_GROUP_PLAYER)
	PhysicsService:RegisterCollisionGroup(COLLISION_GROUP_PAYLOAD)
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP_PAYLOAD, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP_PAYLOAD, COLLISION_GROUP_PAYLOAD, false)
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP_PAYLOAD, COLLISION_GROUP_PLAYER, true)
end

function SpawnService:start(): ()
	serviceTrove = ServiceTrove.new()

	serviceTrove:Connect(Players.PlayerAdded, onPlayerAdded)
	serviceTrove:Connect(Players.PlayerRemoving, onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

function SpawnService:Cleanup(): ()
	if serviceTrove then
		serviceTrove:Destroy()
		serviceTrove = nil :: any
	end
	table.clear(playerTroves)
	table.clear(characterTroves)
end

return SpawnService
