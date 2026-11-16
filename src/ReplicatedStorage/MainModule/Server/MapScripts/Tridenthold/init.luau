--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local TeamsService = game:GetService("Teams")

local Tridenthold = {}
Tridenthold.Name = "Tridenthold"

local MG_GROUP_ID = 0
local FG_GROUP_ID = 0
local RG_GROUP_ID = 0
local DT_GROUP_ID = 0
local CH_GROUP_ID = 0

local connections: { RBXScriptConnection } = {}

local function rankIn(player: Player, groupId: number): number
	local ok, rank = pcall(function()
		return player:GetRankInGroupAsync(groupId)
	end)
	return if ok and typeof(rank) == "number" then rank else 0
end

local function baseTeam(rank: number): string?
	if rank == 255 then
		return "Imperator"
	elseif rank == 252 then
		return "Supreme General"
	elseif rank == 250 then
		return "General"
	elseif rank == 200 then
		return "Colonel"
	elseif rank >= 80 and rank <= 100 then
		return "Officer"
	elseif rank >= 10 and rank <= 60 then
		return "Vultarian"
	end
	return nil
end

local function teamNameFor(player: Player): string
	local mr = rankIn(player, MG_GROUP_ID)
	local fr = rankIn(player, FG_GROUP_ID)
	local rr = rankIn(player, RG_GROUP_ID)
	local dt = rankIn(player, DT_GROUP_ID)
	local ch = rankIn(player, CH_GROUP_ID)

	if fr == 100 or fr == 110 or fr == 120 then
		return "Initiate"
	end
	if mr == 255 then
		return "Imperator"
	end
	if mr == 252 then
		return "Supreme General"
	end
	if fr == 200 then
		return "Director"
	end
	if fr == 230 then
		return "Overseer"
	end
	if rr > 0 then
		return "Royal Guard"
	end
	if dt > 0 then
		return "Dreadtrooper"
	end
	if ch > 0 then
		return "Chaplain"
	end

	local base = baseTeam(mr)
	if fr == 170 and (base == "Officer" or base == "Vultarian") then
		return "Head Instructor"
	end
	if (fr == 150 or fr == 160) and base == "Vultarian" then
		return "Instructor"
	end
	return base or "Initiate"
end

local function assignTeam(player: Player): ()
	local team = TeamsService:FindFirstChild(teamNameFor(player)) :: Team?
	if team and player.Parent == Players then
		player.Team = team
	end
end

function Tridenthold:init(): () end

function Tridenthold:start(): ()
	for _, player in Players:GetPlayers() do
		task.spawn(assignTeam, player)
	end

	table.insert(connections, Players.PlayerAdded:Connect(assignTeam))
end

function Tridenthold:Cleanup(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

return Tridenthold
