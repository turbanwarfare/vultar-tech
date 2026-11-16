--!strict
--!native
--!optimize 2

local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local MainModule = script.Parent.Parent.Parent.Parent
local AvatarService = require(MainModule.Server.Services.AvatarService)
local SparConfig = require(MainModule.Shared.Config.SparConfig)
local Network = require(MainModule.Shared.Network)
local Signal = require(MainModule.Shared.Utils.State.Signal)

local InventoryService = require(MainModule.Server.Services.InventoryService)

export type ArenaSelections = {
	map: string,
	gun: string,
	health: string,
	rounds: string,
	showVersusGUI: boolean,
	instantRespawn: boolean,
	leftPlayer: Player?,
	rightPlayer: Player?,
}

export type PreparedMap = {
	mapName: string,
	model: Model,
	spawn1: SpawnLocation,
	spawn2: SpawnLocation,
}

export type RoundInfo = {
	player1: Player,
	player2: Player,
	player1Wins: number,
	player2Wins: number,
	totalRounds: number,
	currentRound: number,
	mapName: string,
	gunName: string,
	healthName: string,
	showVersusGUI: boolean,
	instantRespawn: boolean,
	map: Model?,
	roundResolved: boolean,
	forcefieldDuration: number,
	isRandomMap: boolean?,
}

export type MatchData = {
	player1: Player,
	player2: Player,
	map: Model?,
	arena: number,
	ended: boolean,
	_cleanupDone: boolean,
	guiRefs: { ScreenGui },
	player1MaxHealth: number,
	player2MaxHealth: number,
	roundInfo: RoundInfo,
	phase: "transition" | "playing",
	timerThread: thread?,
	diedConnections: { RBXScriptConnection },
	charAddedConnections: { RBXScriptConnection },
	isSuddenDeath: boolean,
	StartTime: number,
	EndTime: number?,
	revealedRound: number,
	resolvedRound: number,
	GameType: string,
	MatchId: string,
	_exitMatchTriggered: boolean?,
	enderName: string?,
	isRandomMap: boolean?,
	nextPreparedMap: PreparedMap?,
}

local ArenaMatchService = {}

local activeMatches: { [number]: MatchData } = {}
local roundData: { [number]: RoundInfo } = {}
local arenaSpawns: { [number]: { vultarianSpawn: SpawnLocation, hostileSpawn: SpawnLocation } } = {}

local matchEnded = Signal.new()
local damageDealt = Signal.new()
local playerKilled = Signal.new()
local playerRemovingConnection: RBXScriptConnection? = nil
local ArenaService: any = nil
local isShuttingDown = false
local rng = Random.new()

game:BindToClose(function()
	isShuttingDown = true
end)

function ArenaMatchService.setArenaService(service: any)
	ArenaService = service
end

local function applyHealth(player: Player, healthName: string)
	if not player.Parent then
		return
	end
	if not player.Character then
		return
	end
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local healthValue = tonumber(healthName) or 100
	humanoid.MaxHealth = healthValue
	humanoid.Health = healthValue
end

local function giveGun(player: Player, gunName: string, healthName: string)
	if not player.Parent then
		return
	end

	InventoryService:ClearInventory(player)

	local success, _ = pcall(function()
		return InventoryService:GiveTool(player, gunName)
	end)
	if not success then
		warn("[ArenaMatchService] Failed to give tool:", gunName, "to", player.Name)
	end

	applyHealth(player, healthName)
end

local function setRespawnLocation(player: Player, spawnPoint: SpawnLocation?)
	if player and spawnPoint then
		player.RespawnLocation = spawnPoint
	end
end

local function respawnAndWait(player: Player)
	if player and player.Parent then
		local thread = coroutine.running()
		local conn: RBXScriptConnection
		conn = player.CharacterAdded:Connect(function()
			if conn then
				conn:Disconnect()
			end
			task.spawn(thread)
		end)

		task.spawn(function()
			pcall(function()
				AvatarService:LoadCharacter(player)
			end)
		end)

		local timeoutThread = task.delay(5, function()
			if conn and conn.Connected then
				conn:Disconnect()
				task.spawn(thread)
			end
		end)

		coroutine.yield()
		if timeoutThread then
			task.cancel(timeoutThread)
		end
	end
end

local function resetPlayerState(player: Player, shouldRespawn: boolean, instantRespawn: boolean?)
	if not player then
		return
	end
	player:SetAttribute("InDuel", false)

	local spectatorTeam = Teams:FindFirstChild("Spectators") :: Team?

	if player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.MaxHealth = 100
			humanoid.Health = 100
		end
	end

	if shouldRespawn then
		local delayTime = if instantRespawn then 0 else SparConfig.LOBBY_RESPAWN_DELAY
		task.spawn(function()
			if delayTime > 0 then
				task.wait(delayTime)
			end
			if player and player.Parent then
				if spectatorTeam then
					player.Team = spectatorTeam
				end
				AvatarService:LoadCharacter(player)
			end
		end)
	else
		if spectatorTeam and player.Parent then
			player.Team = spectatorTeam
		end
	end
end

local function findSpawns(map: Model): (SpawnLocation?, SpawnLocation?)
	local spawn1 = map:FindFirstChild("1Middle") :: SpawnLocation?
	local spawn2 = map:FindFirstChild("2Middle") :: SpawnLocation?
	return spawn1, spawn2
end

local function isRandomMapSelection(mapName: string?): boolean
	if not mapName then
		return false
	end
	return string.lower(mapName) == "random"
end

local function pickRandomMapName(excludeMapName: string?): string
	local maps = SparConfig.ACTUAL_MAP_NAMES or SparConfig.MAP_NAMES
	local validMaps: { string } = {}
	for _, m in maps do
		if not isRandomMapSelection(m) then
			table.insert(validMaps, m)
		end
	end
	if #validMaps == 0 then
		return SparConfig.DEFAULT_MAP or "MQC"
	end
	if #validMaps == 1 then
		return validMaps[1]
	end
	local candidates: { string } = {}
	for _, m in validMaps do
		if m ~= excludeMapName then
			table.insert(candidates, m)
		end
	end
	if #candidates == 0 then
		candidates = validMaps
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

local function prepareMapInstance(mapName: string, arenaNumber: number): PreparedMap?
	local mapsFolder = ReplicatedStorage:FindFirstChild("Maps") :: Folder?
	if not mapsFolder then
		warn("[ArenaMatchService] ReplicatedStorage.Maps folder missing")
		return nil
	end

	local originalMap = mapsFolder:FindFirstChild(mapName) :: Model?
	if not originalMap then
		warn("[ArenaMatchService] Original map model missing in Maps folder:", mapName)
		return nil
	end

	local clonedMap = originalMap:Clone()
	clonedMap.Name = mapName .. "_Arena" .. arenaNumber .. "_" .. os.time()
	local targetPos = SparConfig.MAP_POSITIONS[arenaNumber] or Vector3.new(0, 50, 0)
	clonedMap:PivotTo(CFrame.new(targetPos))

	local spawn1, spawn2 = findSpawns(clonedMap)
	if not (spawn1 and spawn2) then
		warn("[ArenaMatchService] Spawn points missing in cloned map:", mapName)
		clonedMap:Destroy()
		return nil
	end

	spawn1.Duration = 0
	spawn2.Duration = 0

	return {
		mapName = mapName,
		model = clonedMap,
		spawn1 = spawn1,
		spawn2 = spawn2,
	}
end

local function applySpawnProtection(player: Player, arenaNumber: number)
	local md = activeMatches[arenaNumber]
	if md and md.phase == "playing" then
		return
	end

	if not player or not player.Character then
		return
	end

	local character = player.Character
	if not character:IsDescendantOf(workspace) then
		pcall(function()
			character.AncestryChanged:Wait()
		end)
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		pcall(function()
			character:WaitForChild("HumanoidRootPart", 2)
		end)
	end

	local rinfo = md and md.roundInfo
	local ffDuration = (rinfo and rinfo.forcefieldDuration) or SparConfig.ForcefieldDuration

	for _, child in character:GetChildren() do
		if child:IsA("ForceField") or child.Name == "SpawnHighlight" then
			child:Destroy()
		end
	end

	local ff = Instance.new("ForceField")
	ff.Name = "SparSpawnForceField"
	ff.Visible = false
	ff.Parent = character

	local hl = Instance.new("Highlight")
	hl.Name = "SpawnHighlight"
	hl.FillColor = Color3.fromRGB(255, 0, 0)
	hl.OutlineColor = Color3.fromRGB(255, 0, 0)
	hl.FillTransparency = 0.5
	hl.OutlineTransparency = 0
	CollectionService:AddTag(hl, "SpawnHighlight")
	hl.Parent = character

	task.delay(ffDuration, function()
		if character and character.Parent then
			local leftoverFF = character:FindFirstChild("SparSpawnForceField")
			if leftoverFF then
				leftoverFF:Destroy()
			end
			local leftoverHL = character:FindFirstChild("SpawnHighlight")
			if leftoverHL then
				leftoverHL:Destroy()
			end
		end
	end)
end

local function assignTeams(player1: Player, player2: Player)
	local vultarianTeam = Teams:FindFirstChild("Vultarians") :: Team?
	local hostileTeam = Teams:FindFirstChild("Hostiles") :: Team?
	if vultarianTeam then
		player1.Team = vultarianTeam
	end
	if player2 ~= player1 then
		if hostileTeam then
			player2.Team = hostileTeam
		end
	end
end

local function teleportToSpawns(player1: Player, player2: Player, spawn1: SpawnLocation, spawn2: SpawnLocation)
	if player1.Character then
		player1.Character:PivotTo(CFrame.new(spawn1.Position + Vector3.new(0, 5, 0)))
	end
	if player2 ~= player1 then
		if player2.Character then
			player2.Character:PivotTo(CFrame.new(spawn2.Position + Vector3.new(0, 5, 0)))
		end
	end
end

local function disconnectMatchConnections(matchData: MatchData)
	for _, conn in matchData.diedConnections do
		conn:Disconnect()
	end
	for _, conn in matchData.charAddedConnections do
		conn:Disconnect()
	end
	table.clear(matchData.diedConnections)
	table.clear(matchData.charAddedConnections)
end

local function wireDeathConnection(matchData: MatchData, arenaNumber: number, player: Player)
	local function connectDied(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 3) :: Humanoid
		if not humanoid then
			return
		end

		local lastHealth = humanoid.Health
		local healthConn = humanoid.HealthChanged:Connect(function(newHealth)
			local md = activeMatches[arenaNumber]
			if md and md.phase == "playing" and not md.ended then
				local diff = lastHealth - newHealth
				if diff > 0 then
					local attacker = if player == md.player1 then md.player2 else md.player1
					damageDealt:Fire(attacker, diff)
				end
			end
			lastHealth = newHealth
		end)
		table.insert(matchData.diedConnections, healthConn)

		local diedConn = humanoid.Died:Connect(function()
			local md = activeMatches[arenaNumber]
			if not md or md._cleanupDone then
				return
			end
			if md.phase ~= "playing" or md.ended then
				return
			end

			if md.resolutionPending then
				return
			end
			md.resolutionPending = true

			task.delay(0.15, function()
				local currentMd = activeMatches[arenaNumber]
				if not currentMd or currentMd._cleanupDone or currentMd.phase ~= "playing" or currentMd.ended then
					return
				end

				local rinfo = currentMd.roundInfo
				local winner: Player? = nil
				local loser: Player? = nil
				local isMutualRoundWin = false

				local p1Char = rinfo.player1.Character
				local p2Char = rinfo.player2.Character
				local p1Hum = p1Char and p1Char:FindFirstChildOfClass("Humanoid")
				local p2Hum = p2Char and p2Char:FindFirstChildOfClass("Humanoid")
				local p1Dead = not p1Hum or p1Hum.Health <= 0
				local p2Dead = not p2Hum or p2Hum.Health <= 0

				if p1Dead and p2Dead then
					winner = nil
					loser = nil
					isMutualRoundWin = true
				elseif p1Dead then
					winner = rinfo.player2
					loser = rinfo.player1
				elseif p2Dead then
					winner = rinfo.player1
					loser = rinfo.player2
				end

				if rinfo.player1 == rinfo.player2 then
					winner = rinfo.player1
					loser = rinfo.player1
					isMutualRoundWin = false
				end

				if isMutualRoundWin then
					playerKilled:Fire(rinfo.player1, rinfo.player2)
					if rinfo.player1 ~= rinfo.player2 then
						playerKilled:Fire(rinfo.player2, rinfo.player1)
					end
				elseif winner then
					playerKilled:Fire(winner, loser)
				end

				ArenaMatchService.endMatch(arenaNumber, winner, loser, isMutualRoundWin)
			end)
		end)

		table.insert(matchData.diedConnections, diedConn)
	end

	if player.Character then
		connectDied(player.Character)
	end

	local charAddedConn = player.CharacterAdded:Connect(function(newCharacter: Model)
		local md = activeMatches[arenaNumber]
		if not md or md._cleanupDone then
			return
		end
		connectDied(newCharacter)

		if md.phase == "transition" then
			task.spawn(function()
				local rinfo = md.roundInfo
				local spawnData = arenaSpawns[arenaNumber]
				if rinfo and spawnData then
					local spawnLoc = if player == md.player1 then spawnData.vultarianSpawn else spawnData.hostileSpawn
					task.wait(0.1)
					if player.Parent and player.Character == newCharacter then
						newCharacter:PivotTo(CFrame.new(spawnLoc.Position + Vector3.new(0, 5, 0)))
						giveGun(player, rinfo.gunName, rinfo.healthName)
						applySpawnProtection(player, arenaNumber)
					end
				end
			end)
		end
	end)

	local charRemovingConn = player.CharacterRemoving:Connect(function(_char)
		local md = activeMatches[arenaNumber]
		if not md or md._cleanupDone then
			return
		end
		if md.phase ~= "playing" or md.ended then
			return
		end

		local rinfo = md.roundInfo
		local winner: Player? = nil
		local loser: Player? = player

		local p1Char = rinfo.player1.Character
		local p2Char = rinfo.player2.Character
		local p1Hum = if player == rinfo.player1 then nil else (p1Char and p1Char:FindFirstChildOfClass("Humanoid"))
		local p2Hum = if player == rinfo.player2 then nil else (p2Char and p2Char:FindFirstChildOfClass("Humanoid"))
		local p1Dead = (player == rinfo.player1) or not p1Hum or p1Hum.Health <= 0
		local p2Dead = (player == rinfo.player2) or not p2Hum or p2Hum.Health <= 0

		if p1Dead and p2Dead then
			winner = nil
			loser = nil
		elseif player == rinfo.player1 then
			winner = rinfo.player2
			loser = rinfo.player1
		else
			winner = rinfo.player1
			loser = rinfo.player2
		end

		if rinfo.player1 == rinfo.player2 then
			winner = rinfo.player1
			loser = rinfo.player1
		end

		ArenaMatchService.endMatch(arenaNumber, winner, loser)
	end)

	table.insert(matchData.charAddedConnections, charAddedConn)
	table.insert(matchData.diedConnections, charRemovingConn)
end

function ArenaMatchService.startMatch(selections: ArenaSelections, arenaNumber: number)
	if not ArenaService then
		warn("[ArenaMatchService] ArenaService not injected")
		return
	end

	if not selections then
		return
	end
	local player1 = selections.leftPlayer
	local player2 = selections.rightPlayer
	if not (player1 and player2) then
		return
	end
	if not (player1.Parent and player2.Parent) then
		return
	end

	local rawMapName = selections.map
	local gunName = selections.gun
	local healthName = selections.health
	local rounds = math.max(tonumber(selections.rounds) or 1, 1)
	local showVersusGUI = selections.showVersusGUI ~= false

	if not rawMapName or not gunName or not healthName then
		warn("[ArenaMatchService] startMatch: nil selections for arena", arenaNumber, "— map=", rawMapName, "gun=", gunName, "health=", healthName)
		ArenaService.resetArena(arenaNumber)
		return
	end

	local isRandom = isRandomMapSelection(rawMapName)
	local isMultiRoundRandom = isRandom and (rounds > 1)
	local activeMapName = rawMapName

	if isRandom then
		activeMapName = pickRandomMapName(nil)
	end

	local initialPrepared = prepareMapInstance(activeMapName, arenaNumber)
	if not initialPrepared then
		warn("[ArenaMatchService] Failed to prepare map:", activeMapName)
		ArenaService.resetArena(arenaNumber)
		return
	end

	local clonedMap = initialPrepared.model
	clonedMap.Parent = workspace
	local spawn1, spawn2 = initialPrepared.spawn1, initialPrepared.spawn2

	arenaSpawns[arenaNumber] = { vultarianSpawn = spawn1, hostileSpawn = spawn2 }

	player1:SetAttribute("InDuel", true)
	if player2 ~= player1 then
		player2:SetAttribute("InDuel", true)
	end

	assignTeams(player1, player2)
	setRespawnLocation(player1, spawn1)
	if player2 ~= player1 then
		setRespawnLocation(player2, spawn2)
	end

	local rinfo: RoundInfo = {
		player1 = player1,
		player2 = player2,
		player1Wins = 0,
		player2Wins = 0,
		totalRounds = rounds,
		currentRound = 1,
		mapName = activeMapName,
		gunName = gunName,
		healthName = healthName,
		showVersusGUI = showVersusGUI,
		instantRespawn = selections.instantRespawn == true,
		map = clonedMap,
		roundResolved = false,
		forcefieldDuration = tonumber(selections.forcefield) or tonumber(SparConfig.DEFAULT_FORCEFIELD_DURATION) or 3,
		isRandomMap = isMultiRoundRandom,
	}
	roundData[arenaNumber] = rinfo
	spawn1.Duration = 0
	spawn2.Duration = 0

	local matchData: MatchData = {
		player1 = player1,
		player2 = player2,
		map = clonedMap,
		arena = arenaNumber,
		ended = false,
		_cleanupDone = false,
		guiRefs = {},
		player1MaxHealth = tonumber(healthName) or 100,
		player2MaxHealth = tonumber(healthName) or 100,
		roundInfo = rinfo,
		phase = "transition",
		timerThread = nil,
		diedConnections = {},
		charAddedConnections = {},
		isSuddenDeath = false,
		StartTime = os.time(),
		EndTime = nil,
		revealedRound = 0,
		resolvedRound = 0,
		GameType = "Spar",
		MatchId = HttpService:GenerateGUID(false),
		isRandomMap = isMultiRoundRandom,
		nextPreparedMap = nil,
	}
	activeMatches[arenaNumber] = matchData

	if isMultiRoundRandom then
		local nextMapName = pickRandomMapName(activeMapName)
		task.spawn(function()
			local prep = prepareMapInstance(nextMapName, arenaNumber)
			local currentMd = activeMatches[arenaNumber]
			if prep and currentMd and not currentMd._cleanupDone then
				currentMd.nextPreparedMap = prep
			elseif prep then
				prep.model:Destroy()
			end
		end)
	end

	wireDeathConnection(matchData, arenaNumber, player1)
	if player2 ~= player1 then
		wireDeathConnection(matchData, arenaNumber, player2)
	end

	local revealAt = -1

	if RunService:IsServer() then
		Network.Spar.fireMatchStarted(
			player1,
			arenaNumber,
			activeMapName,
			gunName,
			healthName,
			rounds,
			showVersusGUI,
			player1.UserId,
			player2.UserId,
			revealAt,
			rinfo.forcefieldDuration
		)
		if player2 ~= player1 then
			Network.Spar.fireMatchStarted(
				player2,
				arenaNumber,
				activeMapName,
				gunName,
				healthName,
				rounds,
				showVersusGUI,
				player1.UserId,
				player2.UserId,
				revealAt,
				rinfo.forcefieldDuration
			)
		end
	end

	local statusData = HttpService:JSONEncode({
		p1 = player1.Name,
		p2 = player2.Name,
		map = activeMapName,
		round = 1,
		totalRounds = rounds,
		p1Wins = 0,
		p2Wins = 0,
		inMatch = true,
		isSuddenDeath = false,
	})
	Network.Spar.broadcastArenaStatus(arenaNumber, "matchStart", statusData)

	task.delay(SparConfig.LOADOUT_APPLY_DELAY, function()
		local md = activeMatches[arenaNumber]
		if not md or md._cleanupDone then
			return
		end

		Network.Spar.fireSuppressDeathScreen(player1, true)
		if player2 ~= player1 then
			Network.Spar.fireSuppressDeathScreen(player2, true)
		end

		local p1Done, p2Done = false, false
		task.spawn(function()
			respawnAndWait(player1)
			p1Done = true
		end)
		if player2 ~= player1 then
			task.spawn(function()
				respawnAndWait(player2)
				p2Done = true
			end)
		else
			p2Done = true
		end

		local waited = 0
		while (not p1Done or not p2Done) and waited < 6 do
			task.wait(0.1)
			waited += 0.1
		end

		if (not p1Done or not p2Done) and waited >= 6 then
			warn("[ArenaMatchService] LoadCharacter timed out during startMatch transition. Cleaning up match.")
			ArenaMatchService.cleanupMatch(arenaNumber)
			return
		end

		Network.Spar.fireSuppressDeathScreen(player1, false)
		if player2 ~= player1 then
			Network.Spar.fireSuppressDeathScreen(player2, false)
		end

		local md2 = activeMatches[arenaNumber]
		if not md2 or md2._cleanupDone then
			return
		end

		teleportToSpawns(player1, player2, spawn1, spawn2)
		giveGun(player1, gunName, healthName)
		applySpawnProtection(player1, arenaNumber)
		if player2 ~= player1 then
			giveGun(player2, gunName, healthName)
			applySpawnProtection(player2, arenaNumber)
		end
		-- Wait for characters to spawn and loadout to apply, then start the exact forcefield timer
		local exactRevealAt = workspace:GetServerTimeNow() + rinfo.forcefieldDuration
		Network.Spar.broadcastArenaStatus(arenaNumber, "matchRevealAt", tostring(exactRevealAt))

		local expectedRound = rinfo.currentRound
		task.delay(rinfo.forcefieldDuration, function()
			local mdCheck = activeMatches[arenaNumber]
			if mdCheck and not mdCheck._cleanupDone and mdCheck.phase == "transition" then
				ArenaMatchService.revealArena(arenaNumber, mdCheck.player1, expectedRound)
			end
		end)
	end)

	ArenaService.setArenaActive(arenaNumber)
end

local function advanceRound(arenaNumber: number, roundWinner: Player?)
	local matchData = activeMatches[arenaNumber]
	if not matchData then
		return
	end
	local rinfo = matchData.roundInfo
	if not rinfo then
		return
	end

	local allRoundsPlayed = false
	local isSuddenDeath = matchData.isSuddenDeath or false
	if rinfo.player1Wins >= rinfo.totalRounds or rinfo.player2Wins >= rinfo.totalRounds then
		allRoundsPlayed = true
	end

	if allRoundsPlayed then
		if matchData.timerThread then
			task.cancel(matchData.timerThread)
			matchData.timerThread = nil
		end

		local isMutualMatchWin = (rinfo.player1Wins >= rinfo.totalRounds and rinfo.player2Wins >= rinfo.totalRounds)
			and (rinfo.player1Wins == rinfo.player2Wins)

		if isMutualMatchWin then
			matchEnded:Fire(arenaNumber, nil, nil, true)
		else
			local winner = if rinfo.player1Wins > rinfo.player2Wins then rinfo.player1 elseif rinfo.player2Wins > rinfo.player1Wins then rinfo.player2 else nil
			local loser = if winner == rinfo.player1 then rinfo.player2 elseif winner == rinfo.player2 then rinfo.player1 else nil
			matchEnded:Fire(arenaNumber, winner, loser, false)
		end
		return
	end

	local isMatchPoint = false

	rinfo.currentRound += 1
	matchData.ended = false
	matchData.phase = "transition"
	matchData.resolutionPending = false

	local spawns = arenaSpawns[arenaNumber]
	local healthName = rinfo.healthName
	local gunName = rinfo.gunName
	local isInstantRespawn = rinfo.instantRespawn

	local upcomingRoundMapName = rinfo.mapName
	if matchData.isRandomMap then
		upcomingRoundMapName = (matchData.nextPreparedMap and matchData.nextPreparedMap.mapName) or pickRandomMapName(rinfo.mapName)
	end

	if spawns then
		spawns.vultarianSpawn.Duration = 0
		spawns.hostileSpawn.Duration = 0
	end

	local statusData = HttpService:JSONEncode({
		p1 = rinfo.player1.Name,
		p2 = rinfo.player2.Name,
		round = rinfo.currentRound,
		totalRounds = rinfo.totalRounds,
		p1Wins = rinfo.player1Wins,
		p2Wins = rinfo.player2Wins,
		map = upcomingRoundMapName,
		isSuddenDeath = isSuddenDeath,
	})

	local nextRoundDelay = if isInstantRespawn then 0.8 else SparConfig.NEXT_ROUND_DELAY
	local revealAt = -1

	Network.Spar.broadcastArenaStatus(arenaNumber, "roundUpdate", statusData)

	if RunService:IsServer() then
		local winnerUserId = if roundWinner then roundWinner.UserId else nil
		Network.Spar.fireRoundTransition(
			rinfo.player1,
			arenaNumber,
			rinfo.currentRound,
			rinfo.totalRounds,
			winnerUserId,
			isMatchPoint,
			isSuddenDeath,
			revealAt,
			rinfo.forcefieldDuration
		)
		if rinfo.player2 ~= rinfo.player1 then
			Network.Spar.fireRoundTransition(
				rinfo.player2,
				arenaNumber,
				rinfo.currentRound,
				rinfo.totalRounds,
				winnerUserId,
				isMatchPoint,
				isSuddenDeath,
				revealAt,
				rinfo.forcefieldDuration
			)
		end
	end

	task.delay(nextRoundDelay, function()
		local md = activeMatches[arenaNumber]
		if not md or md._cleanupDone then
			return
		end

		if md.isRandomMap then
			local nextPrep = md.nextPreparedMap
			local newMapName: string
			local newMapModel: Model
			local newSpawn1: SpawnLocation
			local newSpawn2: SpawnLocation

			if nextPrep and nextPrep.model then
				newMapName = nextPrep.mapName
				newMapModel = nextPrep.model
				newSpawn1 = nextPrep.spawn1
				newSpawn2 = nextPrep.spawn2
				md.nextPreparedMap = nil
			else
				newMapName = pickRandomMapName(rinfo.mapName)
				local fallbackPrep = prepareMapInstance(newMapName, arenaNumber)
				if fallbackPrep then
					newMapModel = fallbackPrep.model
					newSpawn1 = fallbackPrep.spawn1
					newSpawn2 = fallbackPrep.spawn2
				else
					warn("[ArenaMatchService] Fallback prepareMapInstance failed for:", newMapName)
					newMapName = rinfo.mapName
					newMapModel = (rinfo.map or md.map) :: Model
					newSpawn1 = spawns.vultarianSpawn
					newSpawn2 = spawns.hostileSpawn
				end
			end

			local oldMap = rinfo.map
			if oldMap and oldMap ~= newMapModel then
				task.spawn(function()
					oldMap.Parent = nil
					task.wait(1)
					if oldMap.Parent == nil then
						oldMap:Destroy()
					end
				end)
			end

			newMapModel.Parent = workspace
			rinfo.map = newMapModel
			rinfo.mapName = newMapName
			md.map = newMapModel

			arenaSpawns[arenaNumber] = { vultarianSpawn = newSpawn1, hostileSpawn = newSpawn2 }
			setRespawnLocation(rinfo.player1, newSpawn1)
			if rinfo.player2 ~= rinfo.player1 then
				setRespawnLocation(rinfo.player2, newSpawn2)
			end
			spawns = arenaSpawns[arenaNumber]

			if spawns then
				spawns.vultarianSpawn.Duration = 0
				spawns.hostileSpawn.Duration = 0
			end

			local nextUpcoming = pickRandomMapName(newMapName)
			task.spawn(function()
				local prep = prepareMapInstance(nextUpcoming, arenaNumber)
				local currentMd = activeMatches[arenaNumber]
				if prep and currentMd and not currentMd._cleanupDone then
					currentMd.nextPreparedMap = prep
				elseif prep then
					prep.model:Destroy()
				end
			end)
		end

		Network.Spar.fireSuppressDeathScreen(rinfo.player1, true)
		if rinfo.player2 ~= rinfo.player1 then
			Network.Spar.fireSuppressDeathScreen(rinfo.player2, true)
		end

		local p1Done, p2Done = false, false
		task.spawn(function()
			respawnAndWait(rinfo.player1)
			p1Done = true
		end)
		if rinfo.player2 ~= rinfo.player1 then
			task.spawn(function()
				respawnAndWait(rinfo.player2)
				p2Done = true
			end)
		else
			p2Done = true
		end

		local waited = 0
		while (not p1Done or not p2Done) and waited < 6 do
			task.wait(0.1)
			waited += 0.1
		end

		if (not p1Done or not p2Done) and waited >= 6 then
			warn("[ArenaMatchService] LoadCharacter timed out during round transition. Cleaning up match.")
			ArenaMatchService.cleanupMatch(arenaNumber)
			return
		end

		Network.Spar.fireSuppressDeathScreen(rinfo.player1, false)
		if rinfo.player2 ~= rinfo.player1 then
			Network.Spar.fireSuppressDeathScreen(rinfo.player2, false)
		end

		local md2 = activeMatches[arenaNumber]
		if not md2 or md2._cleanupDone then
			return
		end

		if spawns then
			teleportToSpawns(rinfo.player1, rinfo.player2, spawns.vultarianSpawn, spawns.hostileSpawn)
		end

		giveGun(rinfo.player1, gunName, healthName)
		applySpawnProtection(rinfo.player1, arenaNumber)
		if rinfo.player2 ~= rinfo.player1 then
			giveGun(rinfo.player2, gunName, healthName)
			applySpawnProtection(rinfo.player2, arenaNumber)
		end
		-- Wait for characters to spawn and loadout to apply, then start exact forcefield timer
		local exactRevealAt = workspace:GetServerTimeNow() + rinfo.forcefieldDuration
		Network.Spar.broadcastArenaStatus(arenaNumber, "matchRevealAt", tostring(exactRevealAt))

		local expectedRound = rinfo.currentRound
		task.delay(rinfo.forcefieldDuration, function()
			local mdCheck = activeMatches[arenaNumber]
			if mdCheck and not mdCheck._cleanupDone and mdCheck.phase == "transition" then
				ArenaMatchService.revealArena(arenaNumber, mdCheck.player1, expectedRound)
			end
		end)
	end)
end

function ArenaMatchService.endMatch(arenaNumber: number, winner: Player?, _loser: Player?, isMutualRoundWin: boolean?)
	local matchData = activeMatches[arenaNumber]
	if not matchData then
		return
	end

	local rinfo = matchData.roundInfo
	if not rinfo then
		return
	end

	if matchData.resolvedRound == rinfo.currentRound then
		return
	end

	matchData.resolvedRound = rinfo.currentRound
	matchData.ended = true
	rinfo.roundResolved = true

	if isMutualRoundWin then
		rinfo.player1Wins += 1
		rinfo.player2Wins += 1
	else
		if winner and winner == rinfo.player1 then
			rinfo.player1Wins += 1
		elseif winner and winner == rinfo.player2 then
			rinfo.player2Wins += 1
		end
	end

	local statusData = HttpService:JSONEncode({
		p1 = rinfo.player1.Name,
		p2 = rinfo.player2.Name,
		round = rinfo.currentRound,
		totalRounds = rinfo.totalRounds,
		p1Wins = rinfo.player1Wins,
		p2Wins = rinfo.player2Wins,
		isSuddenDeath = matchData.isSuddenDeath,
	})
	Network.Spar.broadcastArenaStatus(arenaNumber, "roundUpdate", statusData)

	Network.Spar.fireSuppressDeathScreen(matchData.player1, true)
	if matchData.player2 ~= matchData.player1 then
		Network.Spar.fireSuppressDeathScreen(matchData.player2, true)
	end

	advanceRound(arenaNumber, winner)
end

function ArenaMatchService.revealArena(arenaNumber: number, player: Player, roundNumber: number)
	local md = activeMatches[arenaNumber]
	if not md or md._cleanupDone or md.ended then
		return
	end

	local rinfo = md.roundInfo
	if not rinfo then
		return
	end

	if roundNumber ~= rinfo.currentRound then
		return
	end

	if md.revealedRound == roundNumber then
		return
	end
	md.revealedRound = roundNumber

	if md.player1 ~= player and md.player2 ~= player then
		return
	end

	rinfo.roundResolved = false

	local p1Char = md.player1.Character
	local p2Char = md.player2.Character
	local p1Hum = p1Char and p1Char:FindFirstChildOfClass("Humanoid")
	local p2Hum = p2Char and p2Char:FindFirstChildOfClass("Humanoid")
	local p1Dead = (md.player1.Parent == nil) or not p1Char or not p1Hum or (p1Hum.Health <= 0)
	local p2Dead = (md.player2.Parent == nil) or not p2Char or not p2Hum or (p2Hum.Health <= 0)

	if p1Dead or p2Dead then
		local winner: Player? = nil
		local loser: Player? = nil
		if p1Dead and p2Dead then
			winner = nil
			loser = nil
		elseif p1Dead then
			winner = md.player2
			loser = md.player1
		else
			winner = md.player1
			loser = md.player2
		end
		ArenaMatchService.endMatch(arenaNumber, winner, loser)
		return
	end

	local function removeProtection(p: Player?)
		if p and p.Character then
			for _, child in p.Character:GetChildren() do
				if child:IsA("ForceField") then
					child:Destroy()
				end
			end
			local hl = p.Character:FindFirstChild("SpawnHighlight")
			if hl then
				hl:Destroy()
			end
		end
	end

	removeProtection(md.player1)
	if md.player2 ~= md.player1 then
		removeProtection(md.player2)
	end

	md.phase = "playing"
end

function ArenaMatchService.cleanupMatch(arenaNumber: number, winner: Player?, loser: Player?)
	if not ArenaService then
		warn("[ArenaMatchService] ArenaService not injected")
		return
	end

	local matchData = activeMatches[arenaNumber]
	if not matchData or matchData._cleanupDone then
		return
	end
	matchData._cleanupDone = true

	disconnectMatchConnections(matchData)

	if matchData.timerThread then
		task.cancel(matchData.timerThread)
		matchData.timerThread = nil
	end

	for _, gui in matchData.guiRefs do
		if gui and gui.Parent then
			gui:Destroy()
		end
	end

	local isInstantRespawn = false
	if matchData.roundInfo and matchData.roundInfo.instantRespawn then
		isInstantRespawn = true
	end

	for _, player in { matchData.player1, matchData.player2 } do
		if player and player.Parent then
			resetPlayerState(player, true, isInstantRespawn)
			task.spawn(function()
				task.wait(SparConfig.LOBBY_RESPAWN_DELAY + 0.5)
				if player and player.Parent then
					Network.Spar.fireSuppressDeathScreen(player, false)
				end
			end)
		end
	end

	local matchEndPayload = HttpService:JSONEncode({
		winner = winner and winner.Name or "",
		loser = loser and loser.Name or "",
		player1Id = matchData.player1.UserId,
		player2Id = matchData.player2.UserId,
		enderName = matchData.enderName,
	})

	Network.Spar.broadcastArenaStatus(arenaNumber, "matchEnd", matchEndPayload)

	if matchData.nextPreparedMap and matchData.nextPreparedMap.model then
		matchData.nextPreparedMap.model:Destroy()
		matchData.nextPreparedMap = nil
	end

	activeMatches[arenaNumber] = nil
	roundData[arenaNumber] = nil
	arenaSpawns[arenaNumber] = nil

	task.delay(SparConfig.LOBBY_RESPAWN_DELAY + 1, function()
		if matchData.map and matchData.map.Parent then
			matchData.map:Destroy()
		end
		if matchData.nextPreparedMap and matchData.nextPreparedMap.model then
			matchData.nextPreparedMap.model:Destroy()
			matchData.nextPreparedMap = nil
		end
	end)

	task.delay(0.5, function()
		ArenaService.resetArena(arenaNumber)
	end)
end

function ArenaMatchService.start()
	playerRemovingConnection = game.Players.PlayerRemoving:Connect(function(player)
		if isShuttingDown then
			return
		end

		for arenaNumber, matchData in pairs(activeMatches) do
			if matchData.player1 == player or matchData.player2 == player then
				local winner: Player? = if matchData.player1 == player then matchData.player2 else matchData.player1
				if winner == player then
					winner = nil
				end

				if winner and (winner.Parent == nil or matchData.phase == "transition") then
					winner = nil
				end

				if not matchData.ended and not matchData._cleanupDone then
					if matchData.roundInfo and winner then
						if winner == matchData.roundInfo.player1 then
							matchData.roundInfo.player1Wins = matchData.roundInfo.totalRounds - 1
						elseif winner == matchData.roundInfo.player2 then
							matchData.roundInfo.player2Wins = matchData.roundInfo.totalRounds - 1
						end
						ArenaMatchService.endMatch(arenaNumber, winner, player)
					else
						ArenaMatchService.cleanupMatch(arenaNumber)
					end
				end
			end
		end
	end)
end

function ArenaMatchService.cleanup()
	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end

	for _arenaNumber, matchData in activeMatches do
		disconnectMatchConnections(matchData)
		if matchData.timerThread then
			task.cancel(matchData.timerThread)
			matchData.timerThread = nil
		end
	end
	table.clear(activeMatches)
	table.clear(roundData)
	table.clear(arenaSpawns)
end

function ArenaMatchService.setOnMatchEnded(callback: (arenaNumber: number, winner: Player, loser: Player) -> ())
	matchEnded:Connect(callback)
end

function ArenaMatchService.setOnDamageDealt(callback: (attacker: Player, damage: number) -> ())
	damageDealt:Connect(callback)
end

function ArenaMatchService.setOnPlayerKilled(callback: (killer: Player, victim: Player) -> ())
	playerKilled:Connect(callback)
end

function ArenaMatchService.getActiveMatch(arenaNumber: number): MatchData?
	return activeMatches[arenaNumber]
end

function ArenaMatchService.handleExitMatch(player: Player, arenaNumber: number)
	local matchData = activeMatches[arenaNumber]
	if not matchData or matchData.ended or matchData._cleanupDone then
		return
	end

	if matchData.player1 ~= player and matchData.player2 ~= player then
		return
	end

	if matchData._exitMatchTriggered then
		return
	end
	matchData._exitMatchTriggered = true

	local rinfo = matchData.roundInfo
	local winner = nil
	local loser = nil

	if rinfo then
		if rinfo.player1Wins > rinfo.player2Wins then
			winner = matchData.player1
			loser = matchData.player2
		elseif rinfo.player2Wins > rinfo.player1Wins then
			winner = matchData.player2
			loser = matchData.player1
		end
	end

	matchData.enderName = player.Name

	matchEnded:Fire(arenaNumber, winner, loser)
end

return ArenaMatchService
