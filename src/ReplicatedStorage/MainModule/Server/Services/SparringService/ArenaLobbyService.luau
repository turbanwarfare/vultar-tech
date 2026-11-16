--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local NetworkCore = require(MainModule.Shared.Network.Core)
local ArenaService = require(script.Parent.ArenaService)

local ArenaLobbyService = {}

local ARENA_COUNT = 8
local broadcastQueued = false

local function getPlayersOnPads(arenaNumber: number): (Player?, Player?)
	local leftPlayer: Player? = nil
	local rightPlayer: Player? = nil

	local arenasFolder = workspace:FindFirstChild("Arenas")
	if not arenasFolder then
		return nil, nil
	end

	local arenaModel = arenasFolder:FindFirstChild(tostring(arenaNumber))
	if not arenaModel then
		return nil, nil
	end

	local decor = arenaModel:FindFirstChild("Decor")
	if not decor then
		return nil, nil
	end

	local leftPlayerModel = decor:FindFirstChild("LeftPlayer")
	local rightPlayerModel = decor:FindFirstChild("RightPlayer")
	local leftPad = leftPlayerModel and leftPlayerModel:FindFirstChild("Detection") :: BasePart?
	local rightPad = rightPlayerModel and rightPlayerModel:FindFirstChild("Detection") :: BasePart?

	if not leftPad or not rightPad then
		return nil, nil
	end

	local thresholdSq = 25

	for _, player in ipairs(game.Players:GetPlayers()) do
		local character = player.Character
		if not character then
			continue
		end
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			continue
		end

		local deltaL = hrp.Position - leftPad.Position
		if deltaL:Dot(deltaL) <= thresholdSq then
			leftPlayer = player
		end

		local deltaR = hrp.Position - rightPad.Position
		if deltaR:Dot(deltaR) <= thresholdSq then
			rightPlayer = player
		end
	end

	return leftPlayer, rightPlayer
end

local function buildLobbySnapshot(): { [number]: any }
	local snapshot = {}
	for i = 1, ARENA_COUNT do
		local isActive = ArenaService.isArenaActive(i)
		local leftPlayer, rightPlayer = getPlayersOnPads(i)

		local leftId = 0
		local leftName = ""
		local rightId = 0
		local rightName = ""

		if leftPlayer and leftPlayer.Parent then
			leftId = leftPlayer.UserId
			leftName = leftPlayer.Name
		end
		if rightPlayer and rightPlayer.Parent then
			rightId = rightPlayer.UserId
			rightName = rightPlayer.Name
		end

		snapshot[i] = {
			leftPlayerId = leftId,
			leftPlayerName = leftName,
			rightPlayerId = rightId,
			rightPlayerName = rightName,
			inMatch = isActive,
			selections = ArenaService.getSelections(i),
		}
	end
	return snapshot
end

function ArenaLobbyService.broadcastNow()
	local snapshot = buildLobbySnapshot()
	Network.Spar.broadcastLobbyState(snapshot)
end

function ArenaLobbyService.queueBroadcast()
	if broadcastQueued then
		return
	end
	broadcastQueued = true
	task.defer(function()
		broadcastQueued = false
		ArenaLobbyService.broadcastNow()
	end)
end

function ArenaLobbyService.handleJoinRequest(player: Player, arenaNumber: number)
	if arenaNumber < 1 or arenaNumber > ARENA_COUNT then
		return
	end

	if ArenaService.isArenaActive(arenaNumber) then
		return
	end

	local leftPlayer, rightPlayer = getPlayersOnPads(arenaNumber)
	if leftPlayer and rightPlayer then
		return
	end

	local arenasFolder = workspace:FindFirstChild("Arenas")
	if not arenasFolder then
		warn("[ArenaLobbyService] No Arenas folder in workspace")
		return
	end

	local arenaModel = arenasFolder:FindFirstChild(tostring(arenaNumber))
	if not arenaModel then
		warn("[ArenaLobbyService] Arena model", arenaNumber, "not found")
		return
	end

	local decor = arenaModel:FindFirstChild("Decor")
	if not decor then
		warn("[ArenaLobbyService] Decor not found in arena", arenaNumber)
		return
	end

	local teleportPart = decor:FindFirstChild("TeleportHere") :: BasePart?
	if not teleportPart then
		warn("[ArenaLobbyService] TeleportHere part not found in arena", arenaNumber)
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	hrp.CFrame = teleportPart.CFrame + Vector3.new(0, 3, 0)
end

function ArenaLobbyService.start()
	local lobbyStateRemote = NetworkCore.getOrCreateRemoteEvent("Spar_LobbyState")

	Network.Spar.onLobbyJoin(function(player: Player, arenaNumber: number)
		ArenaLobbyService.handleJoinRequest(player, arenaNumber)
	end)

	game.Players.PlayerAdded:Connect(function(player: Player)
		task.delay(1, function()
			if player.Parent then
				local snapshot = buildLobbySnapshot()
				lobbyStateRemote:FireClient(player, snapshot)
			end
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			ArenaLobbyService.broadcastNow()
		end
	end)
end

function ArenaLobbyService.cleanup() end

return ArenaLobbyService
