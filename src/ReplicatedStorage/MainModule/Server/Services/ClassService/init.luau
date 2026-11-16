--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local AvatarService = require(MainModule.Server.Services.AvatarService)
local ClassConfig = require(MainModule.Shared.Config.Classes.ClassConfig)
local Network = require(MainModule.Shared.Network)
local FeatureFlags = require(MainModule.Shared.Config.FeatureFlags)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

type ClassName = ClassConfig.ClassName
type ClassWeapons = ClassConfig.ClassWeapons

local ClassService = {}
ClassService.Name = "ClassService"

local teamService: any = nil
local flagBearerService: any = nil

local playerClass: { [number]: string } = {}
local playerTeamKey: { [number]: string } = {}

local teamSlotData: { [string]: { [string]: { players: { Player } } } } = {
	Defenders = {},
	Raiders = {},
}

local serviceConnections: { RBXScriptConnection } = {}
local playerConnections: { [number]: { RBXScriptConnection } } = {}

local function getTeamKey(faction: string?): string
	if faction == "Defenders" then
		return "Defenders"
	end
	return "Raiders"
end

local function getPlayerUsernames(players: { Player }): { string }
	local usernames: { string } = {}
	for _, p in players do
		table.insert(usernames, p.Name)
	end
	return usernames
end

local function getSlotsState(teamKey: string): Network.ClassSlotsState
	local result: Network.ClassSlotsState = {}
	local teamData = teamSlotData[teamKey]

	for className, def in ClassConfig.Classes do
		local slotData = teamData[className]
		local players = if slotData then slotData.players else {}

		result[className] = {
			current = #players,
			max = def.MaxSlots,
			players = getPlayerUsernames(players),
		}
	end

	return result
end

local function removePlayerFromSlot(player: Player, teamKey: string, slotName: string): ()
	local teamData = teamSlotData[teamKey]
	local slotData = teamData[slotName]
	if not slotData then
		return
	end

	for i, p in slotData.players do
		if p == player then
			local lastIndex = #slotData.players
			if i < lastIndex then
				slotData.players[i] = slotData.players[lastIndex]
			end
			slotData.players[lastIndex] = nil
			break
		end
	end
end

local function addPlayerToSlot(player: Player, teamKey: string, slotName: string): ()
	local teamData = teamSlotData[teamKey]
	local slotData = teamData[slotName]
	if not slotData then
		teamData[slotName] = { players = {} }
		slotData = teamData[slotName]
	end
	table.insert(slotData.players, player)
end

local function isSlotAvailable(teamKey: string, slotName: string, maxSlots: number): boolean
	if maxSlots == -1 then
		return true
	end

	local teamData = teamSlotData[teamKey]
	local slotData = teamData[slotName]
	if not slotData then
		return true
	end

	return #slotData.players < maxSlots
end

local function setClassAttribute(player: Player, className: string?): ()
	local character = player.Character
	if not character then
		return
	end
	character:SetAttribute("PlayerClass", className)
end

local function applyClassHealth(player: Player, character: Model): ()
	if player:GetAttribute("InDuel") then
		return
	end

	local className = playerClass[player.UserId]
	character:SetAttribute("PlayerClass", className)

	if not className then
		return
	end

	local classDef = ClassConfig.get(className :: ClassName)
	if not classDef or not classDef.Health then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	humanoid.MaxHealth = classDef.Health
	humanoid.Health = classDef.Health
end

local function updateSpecialAbilities(player: Player, className: string?): ()
	if flagBearerService then
		flagBearerService:SetPlayerFlagBearer(player, className == "FlagBearer")
	end
end

local function releaseSlot(player: Player, teamKey: string): ()
	local currentClass = playerClass[player.UserId]
	if not currentClass then
		return
	end

	removePlayerFromSlot(player, teamKey, currentClass)
	updateSpecialAbilities(player, nil)
end

local function respawnPlayer(player: Player): ()
	task.spawn(function()
		AvatarService:LoadCharacter(player)
	end)
end

local CLASS_SELECT_COOLDOWN = 1
local classSelectCooldowns: { [number]: number } = {}

local function trySelectClass(player: Player, className: string): Network.ClassSelectResult
	local now = os.clock()
	local userId = player.UserId
	local lastSelect = classSelectCooldowns[userId]
	if lastSelect and (now - lastSelect) < CLASS_SELECT_COOLDOWN then
		return { success = false, error = "Please wait before switching classes" }
	end

	local faction = teamService:GetPlayerFaction(player)

	if not faction or faction == "Neutral" then
		return { success = false, error = "Invalid team" }
	end

	local teamKey = getTeamKey(faction)

	local classDef = ClassConfig.get(className :: ClassName)
	if not classDef then
		return { success = false, error = "Unknown class" }
	end

	if not isSlotAvailable(teamKey, className, classDef.MaxSlots) then
		return { success = false, error = "Slot full" }
	end

	releaseSlot(player, teamKey)
	addPlayerToSlot(player, teamKey, className)

	playerClass[player.UserId] = className
	playerTeamKey[player.UserId] = teamKey

	setClassAttribute(player, className)
	updateSpecialAbilities(player, className)

	Network.Class.broadcastSlotsUpdate(teamKey, getSlotsState(teamKey))

	respawnPlayer(player)

	classSelectCooldowns[userId] = now

	return { success = true, className = className }
end

function ClassService:init(): ()
	for teamKey in teamSlotData do
		for className in ClassConfig.Classes do
			teamSlotData[teamKey][className] = { players = {} }
		end
	end
end

function ClassService:start(): ()
	teamService = LazyService.create(MainModule, "TeamService")()
	flagBearerService = LazyService.create(MainModule, "FlagBearerService")()

	if not FeatureFlags.isEnabled("ClassSystem") then
		return
	end

	Network.Class.onSelectClass(function(player, className)
		return trySelectClass(player, className)
	end)

	Network.Class.onGetSlotsState(function(player)
		local faction = teamService:GetPlayerFaction(player)
		local teamKey = getTeamKey(faction)
		return getSlotsState(teamKey)
	end)

	Network.Class.onGetPlayerClass(function(player)
		return playerClass[player.UserId]
	end)

	local function releasePlayerClass(player: Player): ()
		local oldTeamKey = playerTeamKey[player.UserId]
		if not oldTeamKey then
			return
		end

		releaseSlot(player, oldTeamKey)
		Network.Class.broadcastSlotsUpdate(oldTeamKey, getSlotsState(oldTeamKey))

		playerClass[player.UserId] = nil
		playerTeamKey[player.UserId] = nil
		setClassAttribute(player, nil)
	end

	local function assignDefaultClass(player: Player): ()
		local faction = teamService:GetPlayerFaction(player)
		if not faction or faction == "Neutral" then
			return
		end

		local teamKey = getTeamKey(faction)
		addPlayerToSlot(player, teamKey, "Assault")
		playerClass[player.UserId] = "Assault"
		playerTeamKey[player.UserId] = teamKey
		setClassAttribute(player, "Assault")
		Network.Class.broadcastSlotsUpdate(teamKey, getSlotsState(teamKey))
	end

	local function onPlayerAdded(player: Player): ()
		local userId = player.UserId
		local conns: { RBXScriptConnection } = {}
		playerConnections[userId] = conns

		table.insert(
			conns,
			player.CharacterAdded:Connect(function(character)
				task.defer(applyClassHealth, player, character)
			end)
		)

		table.insert(
			conns,
			player:GetPropertyChangedSignal("Team"):Connect(function()
				if player:GetAttribute("InDuel") then
					return
				end
				releasePlayerClass(player)
				assignDefaultClass(player)
				respawnPlayer(player)
			end)
		)

		if player.Team and not playerClass[userId] then
			assignDefaultClass(player)
		end
	end

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	table.insert(serviceConnections, Players.PlayerAdded:Connect(onPlayerAdded))

	table.insert(
		serviceConnections,
		Players.PlayerRemoving:Connect(function(player)
			local userId = player.UserId

			local conns = playerConnections[userId]
			if conns then
				for _, conn in conns do
					conn:Disconnect()
				end
				playerConnections[userId] = nil
			end

			releasePlayerClass(player)
			classSelectCooldowns[userId] = nil
		end)
	)
end

function ClassService:GetPlayerClass(player: Player): string?
	return playerClass[player.UserId]
end

function ClassService:SetPlayerClass(player: Player, className: string): boolean
	local result = trySelectClass(player, className)
	return result.success
end

function ClassService:GetWeaponsForPlayer(player: Player): { string }
	local className = playerClass[player.UserId] or "Assault"
	local faction = teamService:GetPlayerFaction(player)
	if not faction then
		return {}
	end
	local weapons = ClassConfig.getWeaponsForFaction(className :: ClassName, faction)
	if not weapons then
		return {}
	end

	local result: { string } = {}
	if weapons.Primary then
		table.insert(result, weapons.Primary)
	end
	if weapons.Healing then
		table.insert(result, weapons.Healing)
	end
	if weapons.Secondary then
		table.insert(result, weapons.Secondary)
	end

	return result
end

function ClassService:GetPlayerHealth(player: Player): number
	local className = playerClass[player.UserId]
	if not className then
		return 100
	end

	local classDef = ClassConfig.get(className :: ClassName)
	if not classDef then
		return 100
	end

	return classDef.Health or 100
end

function ClassService:Cleanup(): ()
	for _, conn in serviceConnections do
		conn:Disconnect()
	end
	table.clear(serviceConnections)

	for _, conns in playerConnections do
		for _, conn in conns do
			conn:Disconnect()
		end
	end
	table.clear(playerConnections)

	table.clear(playerClass)
	table.clear(playerTeamKey)
	table.clear(classSelectCooldowns)

	for _, factionSlots in teamSlotData do
		table.clear(factionSlots)
	end
end

return ClassService
