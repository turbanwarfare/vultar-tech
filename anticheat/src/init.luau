--!nonstrict

local Players = game:GetService("Players")

local Config = require(script.Config)
local Signals = require(script.Signals)
local Alerts = require(script.Alerts)
local Suspects = require(script.Suspects)
local Sight = require(script.Sight)
local ScreenWatch = require(script.ScreenWatch)

local AntiCheat = {}
AntiCheat.Version = "0.1.0"

local states = {}
local latest = {}
local connections = {}
local threads = {}
local exempt: { [number]: boolean } = {}
for _, userId in Config.ExemptUserIds do
	exempt[userId] = true
end

local function getState(userId: number)
	local state = states[userId]
	if not state then
		state = Signals.newState()
		states[userId] = state
	end
	return state
end

local function onHit(attacker: Player, targetId: number, offset: Vector3, bodyPart: number, head: boolean, gunIndex: number, origin: Vector3?, shotTarget: Vector3?, clientFrameMs: number?): ()
	Sight.noteFired(attacker)
	if targetId == 0 or exempt[attacker.UserId] then
		return
	end
	local state = getState(attacker.UserId)
	Signals.recordHit(state, attacker, {
		targetId = targetId,
		offset = offset,
		bodyPart = bodyPart,
		head = head == true,
		gunIndex = gunIndex,
		origin = origin,
		shotTarget = shotTarget,
		clientFrameMs = clientFrameMs,
	})
	local victim = Players:GetPlayerByUserId(targetId)
	if victim then
		Sight.noteHit(attacker, victim)
		if Sight.isWallHit(attacker, victim, origin, shotTarget) then
			Signals.recordWallHit(state)
		end
	end
end

local function onShot(player: Player, _gunIndex: number, origin: Vector3, target: Vector3): ()
	Sight.noteFired(player)
	if exempt[player.UserId] then
		return
	end
	Signals.recordShot(getState(player.UserId), origin, target)
end

local function evaluateAll(): ()
	for _, player in Players:GetPlayers() do
		local state = states[player.UserId]
		if state then
			local ok, result = pcall(Signals.evaluate, state)
			if ok then
				latest[player.UserId] = result
				if result then
					Alerts.maybeAlert(player, result)
				end
			else
				warn("[AC] evaluate failed for", player.Name, result)
			end
		end
	end
end

function AntiCheat.GetSuspects()
	local list = {}
	for userId, result in latest do
		if result.eligible and result.score >= Config.WatchThreshold then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				table.insert(list, {
					userId = userId,
					name = player.Name,
					score = result.score,
					reason = Alerts.describe(result),
				})
			end
		end
	end
	table.sort(list, function(a, b)
		return a.score > b.score
	end)
	return list
end

function AntiCheat.GetReport(userId: number)
	return latest[userId]
end

function AntiCheat.TestWebhook(player: Player): boolean
	return Alerts.test(player)
end

function AntiCheat.Init(mainModule: Instance): boolean
	if #connections > 0 then
		return true
	end

	local ok, vultar = pcall(require, mainModule)
	if not ok or typeof(vultar) ~= "table" or typeof(vultar.GetService) ~= "function" then
		warn("[AC] Init needs the MainModule instance:", vultar)
		return false
	end

	if not ScreenWatch.Init(mainModule) then
		warn("[AC] ScreenWatch failed to start; continuing without it")
	end

	local gunService = vultar.GetService("GunService")
	if not gunService or not gunService.HitObserved or not gunService.ShotObserved then
		warn("[AC] GunService.HitObserved / ShotObserved missing - update MainModule first")
		return false
	end

	Alerts.init(vultar, mainModule)
	Sight.init(mainModule, vultar, {
		wallTrack = function(viewer: Player, enemy: Player)
			if not exempt[viewer.UserId] then
				Signals.recordWallTrack(getState(viewer.UserId), enemy.UserId)
			end
		end,
		flick = function(attacker: Player, _victim: Player)
			if not exempt[attacker.UserId] then
				Signals.recordFlick(getState(attacker.UserId))
			end
		end,
	})
	if not Config.SilentMode then
		Suspects.init(vultar)
	end

	table.insert(connections, gunService.HitObserved:Connect(onHit))
	table.insert(connections, gunService.ShotObserved:Connect(onShot))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		states[player.UserId] = nil
		latest[player.UserId] = nil
		Alerts.clear(player.UserId)
		Sight.clear(player)
	end))

	table.insert(threads, task.spawn(function()
		while true do
			task.wait(Config.EvalInterval)
			evaluateAll()
		end
	end))
	if not Config.SilentMode then
		table.insert(threads, task.spawn(function()
			while true do
				task.wait(Config.SuspectsPushInterval)
				local suspects = AntiCheat.GetSuspects()
				Suspects.push(suspects)
				Suspects.syncPreBuffer(suspects)
			end
		end))
	end

	print(string.format("[AC] Vultar AntiCheat %s loaded (%s)", AntiCheat.Version, if Config.SilentMode then "silent mode" else "live"))
	return true
end

function AntiCheat.Stop(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for _, thread in threads do
		task.cancel(thread)
	end
	table.clear(threads)
	Suspects.destroy()
	Sight.stop()
	table.clear(states)
	table.clear(latest)
end

return AntiCheat
