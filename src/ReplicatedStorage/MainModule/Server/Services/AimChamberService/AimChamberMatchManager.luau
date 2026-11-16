--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local Workspace = workspace

local MainModule = script.Parent.Parent.Parent.Parent
local AvatarService = require(MainModule.Server.Services.AvatarService)
local AimChamberConfig = require(MainModule.Shared.Config.AimChamberConfig)
local Network = require(MainModule.Shared.Network)
local AimChamberConfigManager = require(script.Parent.AimChamberConfigManager)
local AimChamberZombieAI = require(script.Parent.AimChamberZombieAI)
local AimChamberNpcAI = require(script.Parent.AimChamberNpcAI)
local AimChamberRecordService = require(script.Parent.AimChamberRecordService)
local AimChamberLeaderboardService = require(script.Parent.AimChamberLeaderboardService)
local InventoryService = require(MainModule.Server.Services.InventoryService)
local TeamService = require(MainModule.Server.Services.TeamService)

type AimChamberSettings = AimChamberConfig.AimChamberSettings
type AimChamberDeathReason = AimChamberConfig.AimChamberDeathReason

type MatchState = {
	Player: Player,
	Settings: AimChamberSettings,
	PresetId: string,
	StartTime: number,
	StartTimestamp: number,
	IsActive: boolean,
	TimerThread: thread?,
	ZombieManager: AimChamberZombieAI.ZombieManager?,
	NpcManager: AimChamberNpcAI.NpcManager?,
	DiedConnection: RBXScriptConnection?,
	EndOnTouchConnection: RBXScriptConnection?,
	CharacterRemovedConnection: RBXScriptConnection?,
	ForceFieldCleanupConnection: RBXScriptConnection?,
	PingSum: number,
	PingCount: number,
	MaxPingSpike: number,
	BigPingSpikesCount: number,
	OriginalTeam: Team?,
	AiRound: number?,
	AiPlayerWins: number?,
	AiNpcWins: number?,
	PlayerShotsFired: number?,
	PlayerShotsHit: number?,
	BotShotsFired: number?,
	BotShotsHit: number?,
	PlayerKills: number?,
}

local AimChamberMatchManager = {}

local activeMatches: { [Player]: MatchState } = {}
local playerRemovingConn: RBXScriptConnection? = nil

local function getInteractableParts(): Folder?
	return Workspace:FindFirstChild(AimChamberConfig.WORKSPACE_PARTS.INTERACTABLE_FOLDER) :: Folder?
end

local function getEndOnTouchPart(): BasePart?
	local folder = getInteractableParts()
	if not folder then
		return nil
	end
	return folder:FindFirstChild(AimChamberConfig.WORKSPACE_PARTS.END_ON_TOUCH) :: BasePart?
end

local function getPlayerSpawn(): BasePart?
	return Workspace:FindFirstChild(AimChamberConfig.WORKSPACE_PARTS.PLAYER_SPAWN) :: BasePart?
end

local function getReturnSpawn(): BasePart?
	return Workspace:FindFirstChild(AimChamberConfig.WORKSPACE_PARTS.PLAYER_RETURN_SPAWN) :: BasePart?
end

local function getZombieSpawnPoints(): { BasePart }
	local spawnFolder = Workspace:FindFirstChild(AimChamberConfig.WORKSPACE_PARTS.ZOMBIE_SPAWNS_FOLDER)
	if not spawnFolder then
		return {}
	end
	local points: { BasePart } = {}
	for _, child in spawnFolder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(points, child)
		end
	end
	return points
end

local function teleportPlayer(player: Player, targetPart: BasePart?): ()
	if not targetPart then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end
	rootPart.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
end

local function setInfiniteAmmo(player: Player, enabled: boolean): ()
	local character = player.Character
	if character then
		character:SetAttribute("AimChamberInfiniteAmmo", if enabled then true else nil)
	end
	player:SetAttribute("AimChamberInfiniteAmmo", if enabled then true else nil)
end

function AimChamberMatchManager.hasActiveMatch(player: Player): boolean
	local match = activeMatches[player]
	return match ~= nil and match.IsActive
end

function AimChamberMatchManager.isPlayerInAiMode(player: Player): boolean
	local match = activeMatches[player]
	return match ~= nil and match.IsActive and match.Settings.IsAiMode == true
end

local function endMatch(player: Player, deathReason: AimChamberDeathReason): ()
	local match = activeMatches[player]
	if not match or not match.IsActive then
		return
	end

	match.IsActive = false

	if match.TimerThread then
		task.cancel(match.TimerThread)
		match.TimerThread = nil
	end

	if match.ZombieManager then
		AimChamberZombieAI.stop(match.ZombieManager)
		match.ZombieManager = nil
	end

	if match.NpcManager then
		AimChamberNpcAI.stop(match.NpcManager)
		match.NpcManager = nil
	end

	if match.DiedConnection then
		match.DiedConnection:Disconnect()
		match.DiedConnection = nil
	end

	if match.EndOnTouchConnection then
		match.EndOnTouchConnection:Disconnect()
		match.EndOnTouchConnection = nil
	end

	if match.CharacterRemovedConnection then
		match.CharacterRemovedConnection:Disconnect()
		match.CharacterRemovedConnection = nil
	end

	if match.ForceFieldCleanupConnection then
		match.ForceFieldCleanupConnection:Disconnect()
		match.ForceFieldCleanupConnection = nil
	end

	setInfiniteAmmo(player, false)
	InventoryService:ClearInventory(player)

	local elapsedTime = os.clock() - match.StartTime

	local record = AimChamberRecordService.buildRunRecord(
		player,
		match.PresetId,
		match.Settings,
		deathReason,
		elapsedTime,
		match.StartTimestamp
	)

	task.spawn(AimChamberRecordService.saveRunRecord, record)
	task.spawn(AimChamberRecordService.checkAnomalies, player, record)

	local didPlayerWin = match.Settings.IsAiMode and (match.AiPlayerWins or 0) >= (match.Settings.AiRounds or 3)
	if deathReason == "LeftMidMatch" then
		didPlayerWin = false
	end
	
	local winnerName = "None"
	if match.Settings.IsAiMode then
		winnerName = if didPlayerWin then player.Name else "Training Bot"
	else
		winnerName = player.Name
	end

	local accuracy = 0
	if match.PlayerShotsFired and match.PlayerShotsFired > 0 then
		accuracy = (match.PlayerShotsHit or 0) / match.PlayerShotsFired
	end

	local historyRecord = {
		MatchId = record.RecordId,
		IsAiMode = match.Settings.IsAiMode,
		PresetId = match.PresetId,
		Difficulty = if match.Settings.IsAiMode then (match.Settings.AiDifficulty or "EASY") else match.PresetId,
		ElapsedTime = elapsedTime,
		Timestamp = match.StartTimestamp,
		WinnerName = winnerName,
		PlayerKills = if match.Settings.IsAiMode then (match.AiPlayerWins or 0) else (match.PlayerKills or 0),
		BotKills = if match.Settings.IsAiMode then (match.AiNpcWins or 0) else 0,
		Accuracy = accuracy,
		ShotsFired = match.PlayerShotsFired or 0,
		ShotsHit = match.PlayerShotsHit or 0,
		GunName = match.Settings.SelectedGun or "H-82",
		LeftMatch = deathReason == "LeftMidMatch",
	}

	task.spawn(function()
		local history = AimChamberRecordService.getPlayerHistory(player)
		local newHistory = { historyRecord }
		for i = 1, math.min(#history, 19) do
			table.insert(newHistory, history[i])
		end
		AimChamberRecordService.savePlayerHistory(player, newHistory)
	end)
	
	if match.Settings.AssessmentValidation and deathReason ~= "LeftMidMatch" then
		AimChamberLeaderboardService.IncrementTime(player, elapsedTime)
	end

	if player.Parent then
		local showAssessmentUI = match.Settings.AssessmentValidation and deathReason ~= "LeftMidMatch"
		local validation = nil

		if showAssessmentUI then
			validation = AimChamberRecordService.buildValidationPayload(player, record, match)
		end

		Network.AimChamber.fireMatchEnded(player, {
			DeathReason = deathReason,
			ElapsedTime = elapsedTime,
			ShowAssessmentUI = showAssessmentUI,
			Validation = validation,
			IsAiMode = match.Settings.IsAiMode,
			DidWin = didPlayerWin,
		})
	end

	if player.Parent then
		player:SetAttribute("InAimChamberMatch", nil)
		player:SetAttribute("AimChamberSelectedGun", nil)
		player:SetAttribute("AimChamberIsAiMode", nil)

		local teamToSet = match.OriginalTeam
		if not teamToSet or not teamToSet.Parent then
			teamToSet = TeamService:GetTeam("Spectators")
		end
		if teamToSet then
			player.Team = teamToSet
		end

		task.spawn(function()
			local charAdded = false
			local conn
			conn = player.CharacterAdded:Once(function()
				charAdded = true
			end)

			pcall(function()
				AvatarService:LoadCharacter(player)
			end)

			local startWait = os.clock()
			while not charAdded and (os.clock() - startWait) < 3 do
				task.wait(0.1)
			end
			
			if conn and not charAdded then
				conn:Disconnect()
			end

			if player.Parent then
				teleportPlayer(player, getReturnSpawn())
			end
		end)
	end

	activeMatches[player] = nil
end

local function handleRoundEnd(player: Player, winner: string)
	local match = activeMatches[player]
	if not match or not match.IsActive then
		return
	end

	if winner == "Player" then
		match.AiPlayerWins = (match.AiPlayerWins or 0) + 1
	elseif winner == "NPC" then
		match.AiNpcWins = (match.AiNpcWins or 0) + 1
	end

	local maxRounds = match.Settings.AiRounds or 3
	local targetWins = maxRounds

	if (match.AiPlayerWins or 0) >= targetWins or (match.AiNpcWins or 0) >= targetWins then
		endMatch(player, winner == "Player" and "Zombie" or "Zombie")
		return
	end

	if match.DiedConnection then
		match.DiedConnection:Disconnect()
		match.DiedConnection = nil
	end

	if match.CharacterRemovedConnection then
		match.CharacterRemovedConnection:Disconnect()
		match.CharacterRemovedConnection = nil
	end

	local charAdded = false
	local conn
	conn = player.CharacterAdded:Once(function()
		charAdded = true
	end)

	pcall(function()
		AvatarService:LoadCharacter(player)
	end)

	local startWait = os.clock()
	while not charAdded and (os.clock() - startWait) < 3 do
		task.wait(0.1)
	end
	
	if conn and not charAdded then
		conn:Disconnect()
	end

	if not player.Parent then
		endMatch(player, "LeftMidMatch")
		return
	end

	local pChar = player.Character
	if not pChar then
		endMatch(player, "LeftMidMatch")
		return
	end
	local pHum = pChar:WaitForChild("Humanoid", 3)
	if pHum then
		pHum.MaxHealth = match.Settings.AiHealth or 100
		pHum.Health = match.Settings.AiHealth or 100
	end
	
	for _, v in pChar:GetChildren() do
		if v:IsA("ForceField") then
			v:Destroy()
		end
	end

	setInfiniteAmmo(player, true)

	match.DiedConnection = pHum.Died:Connect(function()
		if match.Settings.IsAiMode then
			handleRoundEnd(player, "NPC")
		else
			endMatch(player, "Zombie")
		end
	end)

	match.CharacterRemovedConnection = player.CharacterRemoving:Connect(function()
		if match.IsActive then
			endMatch(player, "Zombie")
		end
	end)

	teleportPlayer(player, getPlayerSpawn())

	if match.ForceFieldCleanupConnection then
		match.ForceFieldCleanupConnection:Disconnect()
		match.ForceFieldCleanupConnection = nil
	end

	match.ForceFieldCleanupConnection = pChar.ChildAdded:Connect(function(child)
		if child:IsA("ForceField") and child.Name ~= "SpawnForceField" then
			child:Destroy()
		end
	end)

	if match.NpcManager then
		AimChamberNpcAI.reset(match.NpcManager)
	end

	local duration = AimChamberConfig.AI_PRESET_CONSTANTS.SPAWN_FORCEFIELD_DURATION
	if duration > 0 and pChar and match.Settings.IsAiMode then
		local botModel = if match.NpcManager and match.NpcManager.Npc then match.NpcManager.Npc.Model else nil
		AimChamberNpcAI.applySynchronizedProtection(pChar, botModel, duration)
	end
	
	match.AiRound = (match.AiRound or 1) + 1
end

function AimChamberMatchManager.recordPlayerShot(player: Player, count: number)
	local match = activeMatches[player]
	if match and match.IsActive then
		match.PlayerShotsFired = (match.PlayerShotsFired or 0) + count
	end
end

function AimChamberMatchManager.recordPlayerHit(player: Player, count: number)
	local match = activeMatches[player]
	if match and match.IsActive then
		match.PlayerShotsHit = (match.PlayerShotsHit or 0) + count
	end
end

function AimChamberMatchManager.recordBotShot(player: Player)
	local match = activeMatches[player]
	if match and match.IsActive then
		match.BotShotsFired = (match.BotShotsFired or 0) + 1
	end
end

function AimChamberMatchManager.recordBotHit(player: Player)
	local match = activeMatches[player]
	if match and match.IsActive then
		match.BotShotsHit = (match.BotShotsHit or 0) + 1
	end
end

function AimChamberMatchManager.startMatch(player: Player): (boolean, string?)
	if AimChamberMatchManager.hasActiveMatch(player) then
		return false, "Match already active"
	end

	local settings = AimChamberConfigManager.getMatchSnapshot(player)
	local presetId = AimChamberConfigManager.getPlayerPreset(player)

	local match: MatchState = {
		Player = player,
		Settings = settings,
		PresetId = presetId,
		StartTime = os.clock(),
		StartTimestamp = os.time(),
		IsActive = true,
		PingSum = 0,
		PingCount = 0,
		MaxPingSpike = 0,
		BigPingSpikesCount = 0,
		TimerThread = nil,
		ZombieManager = nil,
		NpcManager = nil,
		DiedConnection = nil,
		EndOnTouchConnection = nil,
		CharacterRemovedConnection = nil,
		OriginalTeam = player.Team,
		PlayerShotsFired = 0,
		PlayerShotsHit = 0,
		BotShotsFired = 0,
		BotShotsHit = 0,
		PlayerKills = 0,
	}

	activeMatches[player] = match

	player:SetAttribute("InAimChamberMatch", true)
	player:SetAttribute("AimChamberSelectedGun", settings.SelectedGun)
	if settings.IsAiMode then
		player:SetAttribute("AimChamberIsAiMode", true)
	else
		player:SetAttribute("AimChamberIsAiMode", nil)
	end

	local vultariansTeam = TeamService:GetTeam("Vultarians")
	if vultariansTeam then
		player.Team = vultariansTeam
	end

	local charAdded = false
	local conn
	conn = player.CharacterAdded:Once(function()
		charAdded = true
	end)

	pcall(function()
		AvatarService:LoadCharacter(player)
	end)

	local startWait = os.clock()
	while not charAdded and (os.clock() - startWait) < 3 do
		task.wait(0.1)
	end
	
	if conn and not charAdded then
		conn:Disconnect()
	end

	local character = player.Character
	if not character then
		return false, "Failed to load character"
	end

	teleportPlayer(player, getPlayerSpawn())
	
	if match.ForceFieldCleanupConnection then
		match.ForceFieldCleanupConnection:Disconnect()
		match.ForceFieldCleanupConnection = nil
	end

	match.ForceFieldCleanupConnection = character.ChildAdded:Connect(function(child)
		if child:IsA("ForceField") and child.Name ~= "SpawnForceField" then
			child:Destroy()
		end
	end)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false, "Character has no humanoid"
	end

	setInfiniteAmmo(player, true)

	humanoid.MaxHealth = if settings.IsAiMode then settings.AiHealth or 100 else 100
	humanoid.Health = humanoid.MaxHealth

	match.DiedConnection = humanoid.Died:Connect(function()
		if settings.IsAiMode then
			handleRoundEnd(player, "NPC")
		else
			endMatch(player, "Zombie")
		end
	end)

	match.CharacterRemovedConnection = player.CharacterRemoving:Connect(function()
		if match.IsActive then
			endMatch(player, "Zombie")
		end
	end)

	local endOnTouchPart = getEndOnTouchPart()
	if endOnTouchPart then
		match.EndOnTouchConnection = endOnTouchPart.Touched:Connect(function(hit: BasePart)
			if not match.IsActive then
				return
			end
			local hitModel = hit:FindFirstAncestorOfClass("Model")
			if hitModel == player.Character then
				endMatch(player, "EndOnTouch")
			end
		end)
	end

	local spawnPoints = getZombieSpawnPoints()

	if settings.IsAiMode then
		local difficulty = AimChamberConfigManager.getAiDifficulty(player)
		local npcManager = AimChamberNpcAI.createManager(settings, difficulty, player, spawnPoints)

		npcManager.OnPlayerDamaged = function(damage: number)
			if not match.IsActive then
				return
			end
			local char = player.Character
			if not char or char:FindFirstChildOfClass("ForceField") then
				return
			end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hum then
				return
			end
			hum:TakeDamage(damage)
		end

		npcManager.OnNpcKilled = function()
			if not match.IsActive then
				return
			end
			handleRoundEnd(player, "Player")
		end

		match.NpcManager = npcManager
		AimChamberNpcAI.start(npcManager)

		local duration = AimChamberConfig.AI_PRESET_CONSTANTS.SPAWN_FORCEFIELD_DURATION
		if duration > 0 and character then
			local botModel = if npcManager.Npc then npcManager.Npc.Model else nil
			AimChamberNpcAI.applySynchronizedProtection(character, botModel, duration)
		end
	else
		local zombieManager = AimChamberZombieAI.createManager(settings, player, spawnPoints)

		zombieManager.OnPlayerDamaged = function(damage: number)
			if not match.IsActive then
				return
			end
			local char = player.Character
			if not char or char:FindFirstChildOfClass("ForceField") then
				return
			end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hum then
				return
			end
			hum:TakeDamage(damage)
		end

		zombieManager.OnZombieKilled = function()
			if not match.IsActive then
				return
			end
			match.PlayerKills = (match.PlayerKills or 0) + 1
		end

		match.ZombieManager = zombieManager
		AimChamberZombieAI.start(zombieManager)
	end

	local tickRate = AimChamberConfig.TIMER_TICK_RATE
	match.TimerThread = task.spawn(function()
		while match.IsActive do
			if player.Parent then
				local ping = player:GetNetworkPing()
				match.PingSum += ping
				match.PingCount += 1
				if ping > match.MaxPingSpike then
					match.MaxPingSpike = ping
				end
				if ping > 0.400 then
					match.BigPingSpikesCount += 1
				end
			end
			local elapsed = os.clock() - match.StartTime
			if player.Parent then
				Network.AimChamber.fireMatchTick(player, {
					ElapsedTime = elapsed,
					PlayerKills = match.AiPlayerWins or 0,
					BotKills = match.AiNpcWins or 0,
					PlayerShotsFired = match.PlayerShotsFired or 0,
					PlayerShotsHit = match.PlayerShotsHit or 0,
					BotShotsFired = match.BotShotsFired or 0,
					BotShotsHit = match.BotShotsHit or 0,
				})
			end
			task.wait(tickRate)
		end
	end)

	Network.AimChamber.fireMatchStarted(player, {
		Settings = settings,
		PresetId = presetId,
		GunName = settings.SelectedGun,
	})

	return true, nil
end

function AimChamberMatchManager.endMatchForPlayer(player: Player, reason: AimChamberDeathReason): ()
	endMatch(player, reason)
end

function AimChamberMatchManager.start(): ()
	playerRemovingConn = Players.PlayerRemoving:Connect(function(player: Player)
		if AimChamberMatchManager.hasActiveMatch(player) then
			endMatch(player, "LeftMidMatch")
		end
	end)
end

function AimChamberMatchManager.cleanup(): ()
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end

	for player in activeMatches do
		endMatch(player, "LeftMidMatch")
	end
	table.clear(activeMatches)
end

AimChamberNpcAI.setMatchManager(AimChamberMatchManager)

return AimChamberMatchManager
