--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local PingTypes = require(MainModule.Shared.Network.Ping.Types)
local Constants = require(MainModule.Shared.Config.Constants)
local RankCache = require(MainModule.Server.Cache.RankCache)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

type HighlightTarget = PingTypes.HighlightTarget
type PingData = PingTypes.PingData

local PingService = {}
PingService.Name = "PingService"

local COOLDOWN = 1.5
local HIGHLIGHT_RADIUS = 10
local HIGHLIGHT_RADIUS_SQ = HIGHLIGHT_RADIUS * HIGHLIGHT_RADIUS
local HIGHLIGHT_DURATION = 5
local PINGED_IMMUNITY_DURATION = 3

local PRIORITY_PING_GROUPS = {
	{ groupId = Constants.GROUPS.VULTAR, minRank = 60 },
	{ groupId = Constants.GROUPS.VWC, minRank = 0 },
}

local WALL_CHECK_ORIGIN_OFFSET = 0.5

local playerCooldowns: { [Player]: number } = {}
local pingedImmunity: { [Player]: number } = {}
local serviceConnections: { RBXScriptConnection } = {}
local TeamService: any = nil
local ScreenWatchService: any = nil

local wallCheckParams = RaycastParams.new()
wallCheckParams.FilterType = Enum.RaycastFilterType.Exclude
wallCheckParams.IgnoreWater = true

local function isSpecialPlayer(player: Player): boolean
	for _, groupInfo in PRIORITY_PING_GROUPS do
		if RankCache.isInGroup(player, groupInfo.groupId, groupInfo.minRank) then
			return true
		end
	end
	return false
end

local function isOnCooldown(player: Player): boolean
	local lastPing = playerCooldowns[player]
	if not lastPing then
		return false
	end
	return (os.clock() - lastPing) < COOLDOWN
end

local function setCooldown(player: Player): ()
	playerCooldowns[player] = os.clock()
end

local function isImmuneToPing(player: Player): boolean
	local immuneUntil = pingedImmunity[player]
	if not immuneUntil then
		return false
	end
	return os.clock() < immuneUntil
end

local function setPingedImmunity(player: Player): ()
	pingedImmunity[player] = os.clock() + HIGHLIGHT_DURATION + PINGED_IMMUNITY_DURATION
end

local function getEnemiesAtPosition(pinger: Player, position: Vector3): { Player }
	local enemies: { Player } = {}
	local teamSvc = TeamService

	if not teamSvc then
		return enemies
	end

	local characterFilter: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(characterFilter, p.Character)
		end
	end
	wallCheckParams.FilterDescendantsInstances = characterFilter

	for _, player in Players:GetPlayers() do
		if player == pinger then
			continue
		end

		if isImmuneToPing(player) then
			continue
		end

		local character = player.Character
		if not character then
			continue
		end

		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			continue
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end

		local toTarget = hrp.Position - position
		if toTarget.X * toTarget.X + toTarget.Y * toTarget.Y + toTarget.Z * toTarget.Z > HIGHLIGHT_RADIUS_SQ then
			continue
		end

		local dist = toTarget.Magnitude
		if dist > 1 then
			local dir = toTarget / dist
			local rayOrigin = position + dir * WALL_CHECK_ORIGIN_OFFSET
			local rayResult = workspace:Raycast(rayOrigin, dir * (dist - WALL_CHECK_ORIGIN_OFFSET), wallCheckParams)
			if rayResult then
				continue
			end
		end

		local areAllies = teamSvc:AreAllies(pinger, player)
		if areAllies then
			continue
		end

		local pingerFaction = teamSvc:GetPlayerFaction(pinger)
		local targetFaction = teamSvc:GetPlayerFaction(player)
		if pingerFaction == "Neutral" or targetFaction == "Neutral" then
			continue
		end

		table.insert(enemies, player)
	end

	return enemies
end

local function buildHighlightTargets(enemies: { Player }): { HighlightTarget }
	local targets: { HighlightTarget } = {}

	for _, enemy in enemies do
		local character = enemy.Character
		if character then
			table.insert(targets, {
				userId = enemy.UserId,
				characterName = character.Name,
			})
		end
	end

	return targets
end

local function onPing(player: Player, position: Vector3): ()
	if typeof(position) ~= "Vector3" then
		return
	end

	if isOnCooldown(player) then
		return
	end

	setCooldown(player)

	local enemies = getEnemiesAtPosition(player, position)
	local targets = buildHighlightTargets(enemies)

	local isSpecial = isSpecialPlayer(player)

	local pingData: PingData = {
		position = position,
		senderName = player.DisplayName,
		isSpecial = isSpecial,
		targets = targets,
	}

	local teamSvc = TeamService
	local screenWatchSvc = ScreenWatchService

	local function isEligibleRecipient(p: Player): boolean
		return p == player or (teamSvc ~= nil and teamSvc:AreAllies(player, p))
	end

	for _, recipient in Players:GetPlayers() do
		local effectivePlayer = recipient
		if screenWatchSvc and typeof(screenWatchSvc.GetTargetForWatcher) == "function" then
			local watchedTarget = screenWatchSvc:GetTargetForWatcher(recipient)
			if watchedTarget then
				effectivePlayer = watchedTarget
			end
		end

		if isEligibleRecipient(effectivePlayer) then
			Network.Ping.sendHighlight(recipient, pingData)
		end
	end

	for _, enemy in enemies do
		setPingedImmunity(enemy)
		Network.Ping.notifyPinged(enemy, player.DisplayName, HIGHLIGHT_DURATION)

		if screenWatchSvc and typeof(screenWatchSvc.GetWatchersForPlayer) == "function" then
			local watchers = screenWatchSvc:GetWatchersForPlayer(enemy)
			for _, watcher in watchers do
				Network.Ping.notifyPinged(watcher, player.DisplayName, HIGHLIGHT_DURATION)
			end
		end
	end
end

local function onPlayerRemoving(player: Player): ()
	playerCooldowns[player] = nil
	pingedImmunity[player] = nil
end

function PingService:init(): ()
end

function PingService:start(): ()
	TeamService = LazyService.create(MainModule, "TeamService")()
	ScreenWatchService = LazyService.create(MainModule, "ScreenWatchService")()

	Network.Ping.onPingReceived(onPing)
	table.insert(serviceConnections, Players.PlayerRemoving:Connect(onPlayerRemoving))
end

function PingService:Cleanup(): ()
	for _, conn in serviceConnections do
		conn:Disconnect()
	end
	table.clear(serviceConnections)
	table.clear(playerCooldowns)
	table.clear(pingedImmunity)
end

return PingService
