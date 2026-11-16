--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MainModule = script.Parent.Parent.Parent
local AvatarService = require(MainModule.Server.Services.AvatarService)
local Network = require(MainModule.Shared.Network)
local GunStats = require(MainModule.Shared.Config.GunStats)
local CosmeticConfig = require(MainModule.Shared.Config.Cosmetics)
local Maps = require(MainModule.Shared.Config.Maps)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

local getScreenWatchService = LazyService.create(MainModule, "ScreenWatchService")
local getReconAntiMacroService = LazyService.create(MainModule, "ReconAntiMacroService")

type DeathData = Network.DeathData
type KillLogData = Network.KillLogData

local DeathService = {}
DeathService.Name = "DeathService"

local RESET_GUN_NAME = "YOURSELF"
local KILL_LOG_TTL = 120
local GUN_INDEX_TO_NAME = GunStats.GUN_INDEX_TO_NAME

local pendingDeathInfo: { [number]: {
	killerId: number,
	killerName: string,
	gunIndex: number,
	range: number,
	killerHealth: number,
	hasKillLog: boolean,
} } =
	{}

local recentKillLogs: { [number]: KillLogData } = {}
local recentKillLogTimes: { [number]: number } = {}
local recentAccuracyStats: { [number]: { accuracy: number, matchAccuracy: number } } = {}

local playerConnections: { [number]: { RBXScriptConnection } } = {}
local characterConnections: { [number]: { RBXScriptConnection } } = {}

local serviceConnections: { RBXScriptConnection } = {}
local isInitialized = false

local cosmeticService: any = nil

local function getPlayerCardInfo(player: Player): (string?, boolean)
	if not cosmeticService then
		return nil, false
	end

	local equipped = cosmeticService:GetEquippedItem(player, "PlayerCard")
	if not equipped or not equipped.imageId or equipped.imageId == "" then
		return nil, false
	end

	local item = CosmeticConfig.getItemById(equipped.id)
	local isAnimated = false
	if item then
		local resolved = CosmeticConfig.resolveItem(item)
		isAnimated = resolved.isAnimated == true
	end

	return equipped.imageId, isAnimated
end

local recentlyRespawned: { [number]: boolean } = {}

local function clearRespawnDebounce(userId: number): ()
	recentlyRespawned[userId] = nil
end

local function getGunName(gunIndex: number): string
	return GUN_INDEX_TO_NAME[gunIndex] or "Unknown"
end

local function clearCharacterConnections(userId: number): ()
	local conns = characterConnections[userId]
	if conns then
		for _, conn in conns do
			conn:Disconnect()
		end
		characterConnections[userId] = nil
	end
end

local onRespawnRequested: (player: Player) -> ()

local function onHumanoidDied(player: Player, humanoid: Humanoid): ()
	local currentCharacter = player.Character
	local diedCharacter = humanoid.Parent
	if currentCharacter and diedCharacter ~= currentCharacter then
		pendingDeathInfo[player.UserId] = nil
		return
	end

	local antiMacroSvc = getReconAntiMacroService()
	if antiMacroSvc then
		antiMacroSvc.ClearLockout(player)
	end

	local userId = player.UserId
	local storedInfo = pendingDeathInfo[userId]
	pendingDeathInfo[userId] = nil

	local deathData: DeathData

	if storedInfo then
		local killer = Players:GetPlayerByUserId(storedInfo.killerId)
		local playerCardImage: string? = nil
		local isAnimatedCard = false

		if killer then
			playerCardImage, isAnimatedCard = getPlayerCardInfo(killer)
		end

		deathData = {
			killerUserId = storedInfo.killerId,
			killerName = storedInfo.killerName,
			gunName = getGunName(storedInfo.gunIndex),
			range = storedInfo.range,
			killerHealth = storedInfo.killerHealth,
			playerCardImage = playerCardImage,
			isAnimatedCard = isAnimatedCard,
			wasReset = false,
			hasKillLog = storedInfo.hasKillLog,
		}
	else
		local playerCardImage, isAnimatedCard = getPlayerCardInfo(player)

		deathData = {
			killerUserId = player.UserId,
			killerName = player.Name,
			gunName = RESET_GUN_NAME,
			range = 0,
			killerHealth = 100,
			playerCardImage = playerCardImage,
			isAnimatedCard = isAnimatedCard,
			wasReset = true,
			hasKillLog = false,
		}
	end

	Network.Death.sendDeathData(player, deathData)

	local screenWatchService = getScreenWatchService()
	local isWatching = if screenWatchService and typeof(screenWatchService.IsWatcher) == "function" then screenWatchService:IsWatcher(player) else false

	if isWatching then
		local respawnDuration = Maps.getRespawnTime()
		task.delay(respawnDuration, function()
			if not player.Parent then
				return
			end

			local char = player.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					return
				end
			end
			onRespawnRequested(player)
		end)
	end
end

local function onCharacterAdded(player: Player, character: Model): ()
	local userId = player.UserId

	clearCharacterConnections(userId)

	local antiMacroSvc = getReconAntiMacroService()
	if antiMacroSvc then
		antiMacroSvc.ClearLockout(player)
	end

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end

	if player.Character ~= character then
		return
	end

	local conns: { RBXScriptConnection } = {}
	characterConnections[userId] = conns

	local deathHandled = false
	local function handleDeath()
		if deathHandled then
			return
		end
		deathHandled = true
		clearCharacterConnections(userId)
		onHumanoidDied(player, humanoid)
	end

	local diedConn: RBXScriptConnection
	diedConn = humanoid.Died:Connect(function()
		diedConn:Disconnect()
		handleDeath()
	end)
	table.insert(conns, diedConn)

	local healthConn: RBXScriptConnection
	healthConn = humanoid.HealthChanged:Connect(function(newHealth: number)
		if newHealth <= 0 then
			healthConn:Disconnect()
			handleDeath()
		end
	end)
	table.insert(conns, healthConn)
end

local function onPlayerAdded(player: Player): ()
	local userId = player.UserId
	playerConnections[userId] = {}

	local charAddedConn = player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	table.insert(playerConnections[userId], charAddedConn)

	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player): ()
	local userId = player.UserId

	clearCharacterConnections(userId)

	local antiMacroSvc = getReconAntiMacroService()
	if antiMacroSvc then
		antiMacroSvc.ClearPlayer(player)
	end

	pendingDeathInfo[userId] = nil
	recentlyRespawned[userId] = nil
	recentKillLogs[userId] = nil
	recentKillLogTimes[userId] = nil
	recentAccuracyStats[userId] = nil

	local connections = playerConnections[userId]
	if connections then
		for _, conn in connections do
			conn:Disconnect()
		end
		playerConnections[userId] = nil
	end
end

local function handleKillLogRequest(player: Player): KillLogData?
	return recentKillLogs[player.UserId]
end

onRespawnRequested = function(player: Player): ()
	if not player.Parent then
		return
	end

	local userId = player.UserId
	if recentlyRespawned[userId] then
		return
	end

	recentlyRespawned[userId] = true
	local success, err = pcall(function()
		AvatarService:LoadCharacter(player)
	end)
	if not success then
		warn("[DeathService] LoadCharacterAsync failed for " .. player.Name .. ":", err)
		pcall(function()
			player:LoadCharacter()
		end)
	end

	task.delay(2, clearRespawnDebounce, userId)
end

local function expireKillLog(userId: number, storedTime: number): ()
	if recentKillLogTimes[userId] == storedTime then
		recentKillLogs[userId] = nil
		recentKillLogTimes[userId] = nil
		recentAccuracyStats[userId] = nil
	end
end

function DeathService:SetDeathInfo(
	victimId: number,
	killerId: number,
	killerName: string,
	gunIndex: number,
	range: number,
	killerHealth: number,
	hitLog: { any }?,
	outgoingLog: { any }?
): ()
	local hasKillLog = (hitLog ~= nil and #hitLog > 0) or (outgoingLog ~= nil and #outgoingLog > 0)

	pendingDeathInfo[victimId] = {
		killerId = killerId,
		killerName = killerName,
		gunIndex = gunIndex,
		range = range,
		killerHealth = killerHealth,
		hasKillLog = hasKillLog,
	}

	if hasKillLog then
		local now = os.clock()
		recentKillLogs[victimId] = { hitLog = hitLog, outgoingLog = outgoingLog }
		recentKillLogTimes[victimId] = now

		local GunService = LazyService.create(MainModule, "GunService")()
		local matchFired, matchHit, killFired = 0, 0, 0
		if GunService and GunService.getAccuracyStats then
			matchFired, matchHit, killFired = GunService:getAccuracyStats(killerId)
		end

		local hits = hitLog and #hitLog or 0
		local accuracy = if killFired > 0 then math.clamp(hits / killFired, 0, 1) else 0
		local matchAccuracy = if matchFired > 0 then math.clamp(matchHit / matchFired, 0, 1) else 0

		recentAccuracyStats[victimId] = {
			accuracy = accuracy,
			matchAccuracy = matchAccuracy,
		}

		if GunService and GunService.resetKillShotsFired then
			GunService:resetKillShotsFired(killerId)
		end

		task.delay(KILL_LOG_TTL, expireKillLog, victimId, now)
	end
end

function DeathService:init(): ()
	Players.RespawnTime = 999999
	isInitialized = true
end

function DeathService:start(): ()
	if not isInitialized then
		self:init()
	end

	cosmeticService = LazyService.create(MainModule, "CosmeticService")()

	Network.Death.onRespawnReady(onRespawnRequested)
	Network.Death.onKillLogRequest(handleKillLogRequest)

	local rf = Instance.new("RemoteFunction")
	rf.Name = "GetAccuracyStats"
	rf.Parent = ReplicatedStorage
	rf.OnServerInvoke = function(player)
		return recentAccuracyStats[player.UserId]
	end

	table.insert(serviceConnections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(serviceConnections, Players.PlayerRemoving:Connect(onPlayerRemoving))

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

function DeathService:Cleanup(): ()
	for _, conn in serviceConnections do
		conn:Disconnect()
	end
	table.clear(serviceConnections)

	for _, conns in characterConnections do
		for _, conn in conns do
			conn:Disconnect()
		end
	end
	table.clear(characterConnections)

	for _, conns in playerConnections do
		for _, conn in conns do
			conn:Disconnect()
		end
	end
	table.clear(playerConnections)

	table.clear(pendingDeathInfo)
	table.clear(recentKillLogs)
	table.clear(recentKillLogTimes)
	table.clear(recentAccuracyStats)
end

return DeathService
